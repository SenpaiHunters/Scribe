//
//  LogManager.swift
//  Scribe
//
//  Created by Kami on 04/02/2025.
//

import Foundation
import os

// MARK: - LogConfiguration

/// Configuration options for the logging system.
///
/// Use this struct to customize log formatting, category filtering, and timestamp display.
///
/// ```swift
/// let config = LogConfiguration(
///     enabledCategories: ["NetworkLayer", "APIService"],
///     includeTimestamp: true,
///     dateFormat: "HH:mm:ss"
/// )
/// LogManager.shared.setConfiguration(config)
/// ```
public struct LogConfiguration: Sendable {
    /// Categories to include in logging output. `nil` allows all categories.
    public var enabledCategories: Set<LogCategory>?

    /// Custom formatter closure for complete control over log line format.
    public var formatter: (@Sendable (FormatterContext) -> String)?

    /// Provides all contextual information needed by a custom log formatter.
    public struct FormatterContext: Sendable {
        public let level: LogLevel
        public let category: LogCategory
        public let message: String
        public let file: String
        public let line: Int
        public let timestamp: Date
    }

    /// Whether to include timestamps in log output. Default is `true`.
    public var includeTimestamp: Bool

    /// Date format string for timestamps. Default is `"yyyy-MM-dd HH:mm:ss.SSSZ"`.
    public var dateFormat: String

    /// Creates a new log configuration.
    ///
    /// - Parameters:
    ///   - enabledCategories: Categories to include. Pass `nil` to allow all categories.
    ///   - formatter: Custom formatter closure. Pass `nil` to use the default format.
    ///   - includeTimestamp: Whether to include timestamps. Default is `true`.
    ///   - dateFormat: Timestamp format string. Default is `"yyyy-MM-dd HH:mm:ss.SSSZ"`.
    public init(
        enabledCategories: Set<LogCategory>? = nil,
        formatter: (@Sendable (FormatterContext) -> String)? = nil,
        includeTimestamp: Bool = true,
        dateFormat: String = "yyyy-MM-dd HH:mm:ss.SSSZ"
    ) {
        self.enabledCategories = enabledCategories
        self.formatter = formatter
        self.includeTimestamp = includeTimestamp
        self.dateFormat = dateFormat
    }

    /// Default configuration with timestamps enabled and all categories allowed.
    public static var `default`: LogConfiguration { LogConfiguration() }
}

// MARK: - SinkID

/// Unique identifier for a registered log sink, used for removal.
public struct SinkID: Hashable, Sendable {
    fileprivate let id: UUID

    fileprivate init() {
        id = UUID()
    }
}

// MARK: - LogManager

/// Central logging manager that handles log routing, filtering, and output.
///
/// Access the shared instance via `LogManager.shared` or through `Log.logger`.
/// Configure minimum log levels, category filters, and custom formatters to control output.
///
/// ```swift
/// // Set minimum level
/// LogManager.shared.minimumLevel = .info
///
/// // Add a sink for test capture
/// let sinkID = LogManager.shared.addSink { line in
///     print("Captured:", line)
/// }
///
/// // Remove specific sink when done
/// LogManager.shared.removeSink(sinkID)
/// ```
public final class LogManager: @unchecked Sendable {
    /// Shared singleton instance.
    public static let shared = LogManager()
    private let subsystem: String
    private var loggersByCategory: [LogCategory: Logger] = [:]

    private let dateFormatter: DateFormatter

    // State protected by logQueue
    private var _minimumLevel: LogLevel
    private var _configuration: LogConfiguration
    private var sinks: [(id: SinkID, handler: @Sendable (String) -> ())] = []

    // Serial queue for thread-safe state access
    private let logQueue: DispatchQueue

    private init() {
        subsystem = Bundle.main.bundleIdentifier ?? "com.kamidevs.scribe"
        dateFormatter = DateFormatter()

        _configuration = .default
        dateFormatter.dateFormat = _configuration.dateFormat

        _minimumLevel = .debug

        logQueue = DispatchQueue(label: "\(subsystem).logging", qos: .utility)
    }

    // MARK: - Synchronous Accessors

    /// The minimum log level threshold. Messages below this level are ignored.
    ///
    /// This property is thread-safe for both reading and writing.
    public var minimumLevel: LogLevel {
        get { logQueue.sync { _minimumLevel } }
        set { logQueue.async { self._minimumLevel = newValue } }
    }

    /// Current logging configuration.
    ///
    /// This property is thread-safe for both reading and writing.
    /// For bulk configuration changes, prefer `setConfiguration(_:)`.
    public var configuration: LogConfiguration {
        get { logQueue.sync { _configuration } }
        set { setConfiguration(newValue) }
    }

    // MARK: - Async Configuration Methods

    /// Sets the logging configuration asynchronously.
    ///
    /// - Parameter cfg: The new configuration to apply.
    public func setConfiguration(_ cfg: LogConfiguration) {
        logQueue.async {
            self._configuration = cfg
            self.dateFormatter.dateFormat = cfg.dateFormat
        }
    }

    /// Retrieves the current configuration asynchronously.
    ///
    /// - Parameter completion: Closure called with the current configuration.
    public func getConfiguration(_ completion: @escaping @Sendable (LogConfiguration) -> ()) {
        logQueue.async {
            completion(self._configuration)
        }
    }

    /// Sets the minimum log level asynchronously.
    ///
    /// - Parameter level: The minimum level for log messages to be processed.
    public func setMinimumLevel(_ level: LogLevel) {
        logQueue.async {
            self._minimumLevel = level
        }
    }

    /// Retrieves the current minimum log level asynchronously.
    ///
    /// - Parameter completion: Closure called with the current minimum level.
    public func getMinimumLevel(_ completion: @escaping @Sendable (LogLevel) -> ()) {
        logQueue.async {
            completion(self._minimumLevel)
        }
    }

    // MARK: - Sinks

    /// Adds a sink to receive formatted log messages.
    ///
    /// Sinks are useful for capturing logs in tests, writing to files, or forwarding to remote services.
    ///
    /// - Parameter sink: Closure called with each formatted log line.
    /// - Returns: A `SinkID` that can be used to remove this specific sink later.
    @discardableResult
    public func addSink(_ sink: @Sendable @escaping (String) -> ()) -> SinkID {
        let sinkID = SinkID()
        logQueue.async {
            self.sinks.append((id: sinkID, handler: sink))
        }
        return sinkID
    }

    /// Removes a specific sink by its identifier.
    ///
    /// - Parameter id: The `SinkID` returned when the sink was added.
    public func removeSink(_ id: SinkID) {
        logQueue.async {
            self.sinks.removeAll { $0.id == id }
        }
    }

    /// Removes all registered sinks.
    public func removeAllSinks() {
        logQueue.async {
            self.sinks.removeAll()
        }
    }

    /// The number of currently registered sinks.
    public var sinkCount: Int {
        logQueue.sync { sinks.count }
    }

    // MARK: - Logging

    /// Logs a message with the specified level and metadata.
    ///
    /// This method is called by the `Log` static helpers. You generally don't need to call it directly.
    ///
    /// - Parameters:
    ///   - message: The log message content.
    ///   - level: The severity/type of the log message.
    ///   - category: A category string for filtering and grouping logs.
    ///   - file: Source file path (automatically captured).
    ///   - function: Source function name (automatically captured).
    ///   - line: Source line number (automatically captured).
    public func log(
        _ message: String,
        level: LogLevel,
        category: LogCategory,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        logQueue.async {
            let logger = self.getLogger(for: category)
            let cfg = self._configuration
            let minLevel = self._minimumLevel

            guard level >= minLevel else { return }
            if let enabled = cfg.enabledCategories, !enabled.contains(category) {
                return
            }

            let now = Date()
            let formatted: String
            if let custom = cfg.formatter {
                formatted = custom(
                    LogConfiguration.FormatterContext(
                        level: level,
                        category: category,
                        message: message,
                        file: file,
                        line: line,
                        timestamp: now
                    )
                )
            } else {
                let ts = cfg.includeTimestamp ? (self.dateFormatter.string(from: now) + " ") : ""
                let fileName = (file as NSString).lastPathComponent
                formatted = "\(ts)\(level.emoji) [\(level.shortCode)] [\(category.name)] \(message) — \(fileName):\(line)"
            }

            switch level.osLogType {
            case .fault:
                logger.fault("\(formatted, privacy: .public)")
            case .error:
                logger.error("\(formatted, privacy: .public)")
            case .debug:
                logger.debug("\(formatted, privacy: .public)")
            case .info:
                logger.info("\(formatted, privacy: .public)")
            default:
                logger.log("\(formatted, privacy: .public)")
            }

            for (_, handler) in self.sinks {
                handler(formatted)
            }
        }
    }

    private func getLogger(for category: LogCategory) -> Logger {
        if let logger = loggersByCategory[category] {
            return logger
        }

        let logger = Logger(subsystem: subsystem, category: category.name)
        loggersByCategory[category] = logger
        return logger
    }
}
