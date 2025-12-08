//
//  LogManager.swift
//  Scribe
//
//  Created by Kami on 04/02/2025.
//

import Foundation
import os

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

    private var autoLoggers: [String: Logger] = [:]
    private var autoLoggerOrder: [String] = []

    private let dateFormatter: DateFormatter

    // State protected by logQueue
    private var _minimumLevel: LogLevel
    private var _configuration: LogConfiguration
    private var sinks: [LogSubscription: @Sendable (String) -> ()] = [:]
    private var streamContinuations: [LogSubscription: AsyncStream<String>.Continuation] = [:]

    // Serial queue for thread-safe state access
    private let logQueue: DispatchQueue

    private init() {
        subsystem = Bundle.main.bundleIdentifier ?? "com.kamidevs.scribe"
        dateFormatter = DateFormatter()

        _configuration = .default
        dateFormatter.dateFormat = _configuration.dateFormat

        _minimumLevel = .debug

        logQueue = DispatchQueue(label: "\(subsystem).logging", qos: .utility)

        applyAutoCacheLimit(_configuration.autoLoggerCacheLimit)
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
            self.applyAutoCacheLimit(cfg.autoLoggerCacheLimit)
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
    /// - Parameters:
    ///   - categories: Specific categories of log messages to receive. If `nil`, the callback is triggered for all
    /// formatted messages.
    ///   - callback: Closure called with each formatted log line.
    /// - Returns: A `LogSubscription` that can be used to remove this specific sink later.
    @discardableResult
    public func addSink(
        categories: Set<LogCategory>? = nil,
        _ callback: @Sendable @escaping (String) -> ()
    ) -> LogSubscription {
        let subscription = LogSubscription(categories: categories)

        logQueue.async {
            self.sinks[subscription] = callback
        }

        return subscription
    }

    /// Removes a specific sink by its identifier.
    ///
    /// - Parameter id: The `SinkID` returned when the sink was added.
    public func removeSink(_ id: LogSubscription) {
        logQueue.async {
            self.sinks[id] = nil
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

    // MARK: - Streaming

    /// Creates and returns a stream to recieve formatted log messages.
    ///
    /// Similar to sinks, these are useful for capturing logs in tests, writing to files, or forwarding to remote
    /// services.
    /// - Parameter categories: Specific categories of log messages to receive. If `nil`, the continuation is triggered
    /// for all formatted messages.
    /// - Returns: An AsyncStream that will stream formatted log messages.
    public func stream(categories: Set<LogCategory>? = nil) -> AsyncStream<String> {
        AsyncStream { continuation in
            let id = LogSubscription(categories: categories)

            logQueue.async {
                self.streamContinuations[id] = continuation
            }

            continuation.onTermination = { @Sendable _ in
                self.logQueue.async {
                    self.streamContinuations.removeValue(forKey: id)
                }
            }
        }
    }

    /// The number of cached `Logger` instances keyed by category.
    public var loggerCacheCount: Int {
        logQueue.sync { loggersByCategory.count + autoLoggers.count }
    }

    /// Clears all cached `Logger` instances, useful to prevent unbounded growth when using many dynamic categories.
    ///
    /// - Parameter completion: Optional callback invoked after the cache has been cleared.
    public func clearLoggerCache(completion: (@Sendable () -> ())? = nil) {
        logQueue.async {
            self.loggersByCategory.removeAll()
            self.autoLoggers.removeAll()
            self.autoLoggerOrder.removeAll()
            completion?()
        }
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
                let tsComponent = cfg.includeTimestamp ? self.dateFormatter.string(from: now) : nil
                var parts: [String] = []
                if let tsComponent {
                    parts.append(tsComponent)
                }

                if cfg.includeEmoji {
                    parts.append(level.emoji)
                }

                if cfg.includeShortCode {
                    parts.append("[\(level.shortCode)]")
                }

                parts.append("[\(category.name)]")
                parts.append(message)

                if cfg.includeFileAndLineNumber {
                    let fileName = (file as NSString).lastPathComponent
                    parts.append("— \(fileName):\(line)")
                }

                formatted = parts.joined(separator: " ")
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

            self.dispatch(formatted, category: category)
        }
    }

    private func dispatch(_ message: String, category: LogCategory) {
        for (subscription, callback) in sinks where subscription.categories?.contains(category) ?? true {
            callback(message)
        }

        for (subscription, continuation) in streamContinuations
            where subscription.categories?.contains(category) ?? true {
            continuation.yield(message)
        }
    }

    private func getLogger(for category: LogCategory) -> Logger {
        category.isAutoGenerated ? getAutoLogger(for: category) : getCustomLogger(for: category)
    }

    private func getCustomLogger(for category: LogCategory) -> Logger {
        if let logger = loggersByCategory[category] {
            return logger
        }

        let logger = Logger(subsystem: subsystem, category: category.name)
        loggersByCategory[category] = logger
        return logger
    }

    /// Returns or creates an auto-generated logger while maintaining LRU eviction.
    private func getAutoLogger(for category: LogCategory) -> Logger {
        let key = category.name

        if let cached = autoLoggers[key] {
            promoteAutoLoggerKey(key)
            return cached
        }

        let logger = Logger(subsystem: subsystem, category: key)
        autoLoggers[key] = logger
        autoLoggerOrder.append(key)
        enforceAutoLoggerLimit(_configuration.autoLoggerCacheLimit)
        return logger
    }

    private func promoteAutoLoggerKey(_ key: String) {
        if let idx = autoLoggerOrder.firstIndex(of: key) {
            autoLoggerOrder.remove(at: idx)
            autoLoggerOrder.append(key)
        }
    }

    private func enforceAutoLoggerLimit(_ limit: Int?) {
        guard let limit else { return }
        trimAutoLoggerCache(to: limit)
    }

    private func applyAutoCacheLimit(_ limit: Int?) {
        guard let limit else { return }
        trimAutoLoggerCache(to: limit)
    }

    private func trimAutoLoggerCache(to limit: Int) {
        while autoLoggerOrder.count > limit {
            let evictKey = autoLoggerOrder.removeFirst()
            autoLoggers.removeValue(forKey: evictKey)
        }
    }
}
