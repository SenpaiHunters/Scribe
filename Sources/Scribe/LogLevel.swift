//
//  LogLevel.swift
//  Scribe
//
//  Created by Kami on 04/02/2025.
//

import Foundation
import os

/// Represents the severity and domain of a log message.
///
/// Log levels are organized into families for logical grouping and include
/// emoji indicators, short codes, and OS log type mappings.
///
/// ```swift
/// // Compare levels
/// if currentLevel >= .warning { ... }
///
/// // Filter by family
/// let networkLevels = LogLevel.levels(in: .networking)
///
/// // Parse from string
/// let level = LogLevel.parse("ERR") // Returns .error
/// ```
public enum LogLevel: Int, Comparable, Sendable, CaseIterable, CustomStringConvertible {
    // MARK: - Debug & Development

    /// 🔬 Detailed debugging for tracing execution flow.
    case trace = 0

    /// 🔍 Debug information for development.
    case debug = 1

    /// 📝 Standard print replacement with structured output.
    case print = 2

    // MARK: - General Information

    /// ℹ️ General informational messages.
    case info = 10

    /// 📢 Notable events worth attention.
    case notice = 11

    // MARK: - Warnings & Errors

    /// ⚠️ Warning about potential issues.
    case warning = 20

    /// ❌ Error that was handled.
    case error = 21

    /// 💥 Fatal error causing severe malfunction.
    case fatal = 22

    // MARK: - Success & Completion

    /// ✅ Successful operation.
    case success = 30

    /// ✨ Task or operation completion.
    case done = 31

    // MARK: - Network Operations

    /// 🌐 Network-related activity.
    case network = 40

    /// 🚀 API call activity.
    case api = 41

    // MARK: - Security & Authentication

    /// 🔒 Security-related events.
    case security = 50

    /// 🔑 Authentication events.
    case auth = 51

    // MARK: - Performance & Analytics

    /// 📊 Performance metrics.
    case metric = 60

    /// 📈 Analytics events.
    case analytics = 61

    // MARK: - UI & User Interaction

    /// 🎨 UI events.
    case ui = 70

    /// 👤 User actions.
    case user = 71

    // MARK: - Database & Storage

    /// 💾 Database operations.
    case database = 80

    /// 📦 Storage operations.
    case storage = 81

    // MARK: - Display Properties

    /// Emoji indicator for this log level.
    public var emoji: String {
        switch self {
        case .trace: "🔬"
        case .debug: "🔍"
        case .print: "📝"
        case .info: "ℹ️"
        case .notice: "📢"
        case .warning: "⚠️"
        case .error: "❌"
        case .fatal: "💥"
        case .success: "✅"
        case .done: "✨"
        case .network: "🌐"
        case .api: "🚀"
        case .security: "🔒"
        case .auth: "🔑"
        case .metric: "📊"
        case .analytics: "📈"
        case .ui: "🎨"
        case .user: "👤"
        case .database: "💾"
        case .storage: "📦"
        }
    }

    /// Human-readable name for this log level.
    public var name: String {
        switch self {
        case .trace: "trace"
        case .debug: "debug"
        case .print: "print"
        case .info: "info"
        case .notice: "notice"
        case .warning: "warning"
        case .error: "error"
        case .fatal: "fatal"
        case .success: "success"
        case .done: "done"
        case .network: "network"
        case .api: "api"
        case .security: "security"
        case .auth: "auth"
        case .metric: "metric"
        case .analytics: "analytics"
        case .ui: "ui"
        case .user: "user"
        case .database: "database"
        case .storage: "storage"
        }
    }

    /// Three-character code for compact display.
    public var shortCode: String {
        switch self {
        case .trace: "TRC"
        case .debug: "DBG"
        case .print: "PRT"
        case .info: "INF"
        case .notice: "NTC"
        case .warning: "WRN"
        case .error: "ERR"
        case .fatal: "FTL"
        case .success: "SUC"
        case .done: "DON"
        case .network: "NET"
        case .api: "API"
        case .security: "SEC"
        case .auth: "AUT"
        case .metric: "MET"
        case .analytics: "ANL"
        case .ui: "UI "
        case .user: "USR"
        case .database: "DB "
        case .storage: "STO"
        }
    }

    /// String description showing emoji and uppercase name.
    public var description: String {
        "\(emoji) \(name.uppercased())"
    }

    // MARK: - Families

    /// Logical grouping of related log levels.
    public enum Family: String, Sendable, CaseIterable {
        case development
        case general
        case problems
        case success
        case networking
        case security
        case performance
        case ui
        case data
    }

    /// The family this log level belongs to.
    public var family: Family {
        switch self {
        case .trace,
             .debug,
             .print: .development
        case .info,
             .notice: .general
        case .warning,
             .error,
             .fatal: .problems
        case .success,
             .done: .success
        case .network,
             .api: .networking
        case .security,
             .auth: .security
        case .metric,
             .analytics: .performance
        case .ui,
             .user: .ui
        case .database,
             .storage: .data
        }
    }

    // MARK: - Predefined Sets

    /// Error and fatal levels.
    public static let allSevere: Set<LogLevel> = [.error, .fatal]

    /// Warning level only.
    public static let allWarnings: Set<LogLevel> = [.warning]

    /// All problem levels (warnings, errors, fatal).
    public static let allProblems: Set<LogLevel> = allSevere.union(allWarnings)

    /// Success and done levels.
    public static let allSuccess: Set<LogLevel> = [.success, .done]

    /// Network and API levels.
    public static let allNetwork: Set<LogLevel> = [.network, .api]

    /// Security and auth levels.
    public static let allSecurity: Set<LogLevel> = [.security, .auth]

    /// Metric and analytics levels.
    public static let allPerformance: Set<LogLevel> = [.metric, .analytics]

    /// UI and user levels.
    public static let allUI: Set<LogLevel> = [.ui, .user]

    /// Database and storage levels.
    public static let allData: Set<LogLevel> = [.database, .storage]

    /// Verbose levels typically filtered in production (trace, debug, print).
    public static let noisyLevels: Set<LogLevel> = [.trace, .debug, .print]

    // MARK: - Comparison

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    // MARK: - Helpers

    /// Returns all log levels at or above the specified minimum.
    ///
    /// - Parameter minimum: The minimum level threshold.
    /// - Returns: Array of levels sorted by raw value.
    public static func levels(minimum: LogLevel) -> [LogLevel] {
        allCases.filter { $0.rawValue >= minimum.rawValue }.sorted { $0.rawValue < $1.rawValue }
    }

    /// Returns all log levels in the specified family.
    ///
    /// - Parameter family: The family to filter by.
    /// - Returns: Array of levels sorted by raw value.
    public static func levels(in family: Family) -> [LogLevel] {
        allCases.filter { $0.family == family }.sorted { $0.rawValue < $1.rawValue }
    }

    /// Returns all available families.
    ///
    /// - Returns: Array of all family cases.
    public static func families() -> [Family] {
        Family.allCases
    }

    /// Parses a string into a `LogLevel`.
    ///
    /// Accepts level names (e.g., "error"), short codes (e.g., "ERR"), or emojis (e.g., "❌").
    ///
    /// - Parameter string: The string to parse.
    /// - Returns: The matching `LogLevel`, or `nil` if no match found.
    public static func parse(_ string: String) -> LogLevel? {
        let s = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let exact = allCases.first(where: { $0.name == s }) { return exact }
        if let short = allCases.first(where: { $0.shortCode.lowercased() == s }) { return short }
        if let emojiMatch = allCases.first(where: { $0.emoji == string }) { return emojiMatch }
        return nil
    }

    // MARK: - OS Integration

    /// Maps this log level to the appropriate `OSLogType`.
    public var osLogType: OSLogType {
        switch self {
        case .trace,
             .debug,
             .print: .debug
        case .info,
             .notice,
             .success,
             .done: .info
        case .warning,
             .network,
             .api,
             .security,
             .auth,
             .metric,
             .analytics,
             .ui,
             .user,
             .database,
             .storage: .default
        case .error: .error
        case .fatal: .fault
        }
    }
}
