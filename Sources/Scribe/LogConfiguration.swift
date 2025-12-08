//
//  LogConfiguration.swift
//  Scribe
//
//  Created by Kami on 08/12/2025.
//

import Foundation

/// Configuration options for the logging system.
///
/// Use this struct to customize log formatting, category filtering, and timestamp display.
public struct LogConfiguration: Sendable {
    /// Categories to include in logging output. `nil` allows all categories.
    public var enabledCategories: Set<LogCategory>?

    /// Custom formatter closure for complete control over log line format.
    public var formatter: (@Sendable (FormatterContext) -> String)?

    /// Whether to include timestamps in log output. Default is `true`.
    ///
    /// This flag only affects the built-in formatter. When a custom formatter is provided,
    /// the formatter is responsible for rendering any timestamp.
    public var includeTimestamp: Bool

    /// Whether to include the level emoji in log output. Default is `true`.
    ///
    /// Only used by the built-in formatter.
    public var includeEmoji: Bool

    /// Whether to include the level short code (e.g., `[DBG]`) in log output. Default is `false`.
    ///
    /// Only used by the built-in formatter.
    public var includeShortCode: Bool

    /// Maximum number of cached auto-generated `Logger` instances (e.g., categories from `#fileID`). `nil` means
    /// unbounded. Default is 100.
    public var autoLoggerCacheLimit: Int?

    /// Date format string for timestamps. Default is `"yyyy-MM-dd HH:mm:ss.SSSZ"`.
    ///
    /// Only used by the built-in formatter.
    public var dateFormat: String

    /// Provides all contextual information needed by a custom log formatter.
    public struct FormatterContext: Sendable {
        public let level: LogLevel
        public let category: LogCategory
        public let message: String
        public let file: String
        public let line: Int
        public let timestamp: Date
    }

    /// Creates a configuration that uses the built-in formatter options.
    ///
    /// - Parameters:
    ///   - enabledCategories: Categories to include. Pass `nil` to allow all categories.
    ///   - includeTimestamp: Whether to include timestamps. Default is `true`.
    ///   - includeEmoji: Whether to include the level emoji. Default is `true`.
    ///   - includeShortCode: Whether to include the level short code. Default is `false`.
    ///   - autoLoggerCacheLimit: Maximum cached auto-generated `Logger` instances. Pass `nil` for no limit. Default is
    /// 100.
    ///   - dateFormat: Timestamp format string. Default is `"yyyy-MM-dd HH:mm:ss.SSSZ"`.
    public init(
        enabledCategories: Set<LogCategory>? = nil,
        includeTimestamp: Bool = true,
        includeEmoji: Bool = true,
        includeShortCode: Bool = false,
        autoLoggerCacheLimit: Int? = 100,
        dateFormat: String = "yyyy-MM-dd HH:mm:ss.SSSZ"
    ) {
        self.enabledCategories = enabledCategories
        self.formatter = nil
        self.includeTimestamp = includeTimestamp
        self.includeEmoji = includeEmoji
        self.includeShortCode = includeShortCode
        self.autoLoggerCacheLimit = autoLoggerCacheLimit
        self.dateFormat = dateFormat
    }

    /// Creates a configuration that uses a custom formatter closure.
    ///
    /// The built-in formatting toggles (timestamps, emoji, short codes) are ignored when a custom formatter is set.
    ///
    /// - Parameters:
    ///   - enabledCategories: Categories to include. Pass `nil` to allow all categories.
    ///   - formatter: Custom formatter closure used to build the final log line.
    ///   - autoLoggerCacheLimit: Maximum cached auto-generated `Logger` instances. Pass `nil` for no limit. Default is
    /// 100.
    ///   - dateFormat: Timestamp format string supplied for convenience to formatter users. Default is
    /// `"yyyy-MM-dd HH:mm:ss.SSSZ"`.
    public init(
        enabledCategories: Set<LogCategory>? = nil,
        formatter: @escaping @Sendable (FormatterContext) -> String,
        autoLoggerCacheLimit: Int? = 100,
        dateFormat: String = "yyyy-MM-dd HH:mm:ss.SSSZ"
    ) {
        self.enabledCategories = enabledCategories
        self.formatter = formatter
        self.includeTimestamp = true
        self.includeEmoji = true
        self.includeShortCode = false
        self.autoLoggerCacheLimit = autoLoggerCacheLimit
        self.dateFormat = dateFormat
    }

    /// Default configuration with timestamps enabled and all categories allowed.
    public static var `default`: LogConfiguration { LogConfiguration() }
}
