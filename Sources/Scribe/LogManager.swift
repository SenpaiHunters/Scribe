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

    /// Whether to include the level emoji in log output. Default is `true`.
    public var includeEmoji: Bool

    /// Whether to include the level short code (e.g., `[DBG]`) in log output. Default is `false`.
    public var includeShortCode: Bool

    /// Maximum number of cached auto-generated `Logger` instances (e.g., categories from `#fileID`). `nil` means
    /// unbounded. Default is 100.
    public var autoLoggerCacheLimit: Int?

    /// Date format string for timestamps. Default is `"yyyy-MM-dd HH:mm:ss.SSSZ"`.
    public var dateFormat: String

    /// Creates a new log configuration.
    ///
    /// - Parameters:
    ///   - enabledCategories: Categories to include. Pass `nil` to allow all categories.
    ///   - formatter: Custom formatter closure. Pass `nil` to use the default format.
    ///   - includeTimestamp: Whether to include timestamps. Default is `true`.
    ///   - includeEmoji: Whether to include the level emoji. Default is `true`.
    ///   - includeShortCode: Whether to include the level short code. Default is `false`.
    ///   - autoLoggerCacheLimit: Maximum cached auto-generated `Logger` instances. Pass `nil` for no limit. Default is
    /// 100.
    ///   - dateFormat: Timestamp format string. Default is `"yyyy-MM-dd HH:mm:ss.SSSZ"`.
    public init(
        enabledCategories: Set<LogCategory>? = nil,
        formatter: (@Sendable (FormatterContext) -> String)? = nil,
        includeTimestamp: Bool = true,
        includeEmoji: Bool = true,
        includeShortCode: Bool = false,
        autoLoggerCacheLimit: Int? = 100,
        dateFormat: String = "yyyy-MM-dd HH:mm:ss.SSSZ"
    ) {
        self.enabledCategories = enabledCategories
        self.formatter = formatter
        self.includeTimestamp = includeTimestamp
        self.includeEmoji = includeEmoji
        self.includeShortCode = includeShortCode
        self.autoLoggerCacheLimit = autoLoggerCacheLimit
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
    private final class CachedLogger: NSObject {
        let logger: Logger
        let key: String

        init(logger: Logger, key: String) {
            self.logger = logger
            self.key = key
        }
    }

    private final class AutoLoggerCacheDelegate: NSObject, NSCacheDelegate {
        weak var owner: LogManager?

        func cache(_ cache: NSCache<AnyObject, AnyObject>, willEvictObject obj: Any) {
            guard let cached = obj as? CachedLogger else { return }
            owner?.handleAutoEviction(forKey: cached.key)
        }
    }

    /// Shared singleton instance.
    public static let shared = LogManager()
    private let subsystem: String
    private var loggersByCategory: [LogCategory: Logger] = [:]

    private let autoLoggerCache: NSCache<NSString, CachedLogger>
    private let autoLoggerCacheDelegate: AutoLoggerCacheDelegate
    private var autoLoggerKeys: Set<String> = []
    private var autoLoggerOrder: [String] = []

    private let dateFormatter: DateFormatter

    // State protected by logQueue
    private var _minimumLevel: LogLevel
    private var _configuration: LogConfiguration
    private var sinks: [SinkID: @Sendable (String) -> ()] = [:]
    private var streamContinuations: [UUID: AsyncStream<String>.Continuation] = [:]

    // Serial queue for thread-safe state access
    private let logQueue: DispatchQueue

    private init() {
        subsystem = Bundle.main.bundleIdentifier ?? "com.kamidevs.scribe"
        dateFormatter = DateFormatter()

        autoLoggerCache = NSCache<NSString, CachedLogger>()
        autoLoggerCacheDelegate = AutoLoggerCacheDelegate()

        _configuration = .default
        dateFormatter.dateFormat = _configuration.dateFormat

        _minimumLevel = .debug

        logQueue = DispatchQueue(label: "\(subsystem).logging", qos: .utility)

        autoLoggerCacheDelegate.owner = self
        autoLoggerCache.delegate = autoLoggerCacheDelegate
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
    /// - Parameter sink: Closure called with each formatted log line.
    /// - Returns: A `SinkID` that can be used to remove this specific sink later.
    @discardableResult
    public func addSink(_ callback: @Sendable @escaping (String) -> ()) -> SinkID {
        let sinkID = SinkID()
        logQueue.async {
            self.sinks[sinkID] = callback
        }
        return sinkID
    }

    /// Removes a specific sink by its identifier.
    ///
    /// - Parameter id: The `SinkID` returned when the sink was added.
    public func removeSink(_ id: SinkID) {
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
    /// Similar to sinks, these are useful for capturing logs in tests, writing to files, or forwarding to remote services.
    /// - Returns: An AsyncStream that will stream formatted log messages.
    public func stream() -> AsyncStream<String> {
        AsyncStream { continuation in
            let id = UUID()
            
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
        logQueue.sync { loggersByCategory.count + autoLoggerKeys.count }
    }

    /// Clears all cached `Logger` instances, useful to prevent unbounded growth when using many dynamic categories.
    ///
    /// - Parameter completion: Optional callback invoked after the cache has been cleared.
    public func clearLoggerCache(completion: (@Sendable () -> ())? = nil) {
        logQueue.async {
            self.loggersByCategory.removeAll()
            self.autoLoggerCache.removeAllObjects()
            self.autoLoggerKeys.removeAll()
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
                let fileName = (file as NSString).lastPathComponent
                formatted = "\(parts.joined(separator: " ")) — \(fileName):\(line)"
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

            self.dispatch(formatted)
        }
    }
    
    private func dispatch(_ message: String) {
        for handler in sinks.values {
            handler(message)
        }
        
        for continuation in streamContinuations.values {
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

    private func getAutoLogger(for category: LogCategory) -> Logger {
        let key = category.name
        let nsKey = key as NSString

        if let cached = autoLoggerCache.object(forKey: nsKey) {
            promoteAutoLoggerKey(key)
            return cached.logger
        }

        let logger = Logger(subsystem: subsystem, category: key)
        let cached = CachedLogger(logger: logger, key: key)
        autoLoggerCache.setObject(cached, forKey: nsKey)
        autoLoggerKeys.insert(key)
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
        applyAutoCacheLimit(limit)
        while autoLoggerOrder.count > limit {
            let evictKey = autoLoggerOrder.removeFirst()
            autoLoggerKeys.remove(evictKey)
            autoLoggerCache.removeObject(forKey: evictKey as NSString)
        }
    }

    private func applyAutoCacheLimit(_ limit: Int?) {
        if let limit {
            autoLoggerCache.countLimit = limit
        } else {
            autoLoggerCache.countLimit = 0
        }
    }

    fileprivate func handleAutoEviction(forKey key: String) {
        logQueue.async {
            self.autoLoggerKeys.remove(key)
            if let idx = self.autoLoggerOrder.firstIndex(of: key) {
                self.autoLoggerOrder.remove(at: idx)
            }
        }
    }
}
