//
//  Log.swift
//  Scribe
//
//  Created by Kami on 04/02/2025.
//

import Foundation

/// Static logging interface providing convenient methods for all log levels.
///
/// Use the static methods on this enum to log messages throughout your application.
/// Each method automatically captures source location metadata (file, function, line).
///
/// ```swift
/// Log.info("User signed in", category: .init("Auth"))
/// Log.error("Failed to fetch data", category: .init("Network"))
/// Log.debug("Processing item \(item.id)")
/// ```
///
/// The `category` parameter defaults to the file ID where the log was called,
/// but you can specify custom categories for better filtering and organization.
@frozen
public enum Log: Sendable {
    /// The shared `LogManager` instance used by all logging methods.
    public static var logger: LogManager { LogManager.shared }

    // MARK: - Debug & Development

    /// Logs a debug message for development and troubleshooting.
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - category: Category for filtering. Defaults to the calling file.
    ///   - function: The calling function (auto-captured).
    ///   - file: The source file path (auto-captured).
    ///   - line: The source line number (auto-captured).
    public static func debug(
        _ message: String,
        category: LogCategory? = nil,
        fileID: String = #fileID,
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        log(message, level: .debug, category: category, fileID: fileID, function: function, file: file, line: line)
    }

    /// Logs a trace message for detailed execution flow tracking.
    ///
    /// Use for granular debugging that's typically too verbose for regular debug builds.
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - category: Category for filtering. Defaults to the calling file.
    ///   - function: The calling function (auto-captured).
    ///   - file: The source file path (auto-captured).
    ///   - line: The source line number (auto-captured).
    public static func trace(
        _ message: String,
        category: LogCategory? = nil,
        fileID: String = #fileID,
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        log(message, level: .trace, category: category, fileID: fileID, function: function, file: file, line: line)
    }

    /// Logs a print-level message as a structured replacement for `Swift.print()`.
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - category: Category for filtering. Defaults to the calling file.
    ///   - function: The calling function (auto-captured).
    ///   - file: The source file path (auto-captured).
    ///   - line: The source line number (auto-captured).
    public static func print(
        _ message: String,
        category: LogCategory? = nil,
        fileID: String = #fileID,
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        log(message, level: .print, category: category, fileID: fileID, function: function, file: file, line: line)
    }

    // MARK: - General Information

    /// Logs an informational message about general app state or events.
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - category: Category for filtering. Defaults to the calling file.
    ///   - function: The calling function (auto-captured).
    ///   - file: The source file path (auto-captured).
    ///   - line: The source line number (auto-captured).
    public static func info(
        _ message: String,
        category: LogCategory? = nil,
        fileID: String = #fileID,
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        log(message, level: .info, category: category, fileID: fileID, function: function, file: file, line: line)
    }

    /// Logs a notice about a notable but non-critical event.
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - category: Category for filtering. Defaults to the calling file.
    ///   - function: The calling function (auto-captured).
    ///   - file: The source file path (auto-captured).
    ///   - line: The source line number (auto-captured).
    public static func notice(
        _ message: String,
        category: LogCategory? = nil,
        fileID: String = #fileID,
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        log(message, level: .notice, category: category, fileID: fileID, function: function, file: file, line: line)
    }

    // MARK: - Warnings & Errors

    /// Logs a warning about a potential issue that doesn't prevent operation.
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - category: Category for filtering. Defaults to the calling file.
    ///   - function: The calling function (auto-captured).
    ///   - file: The source file path (auto-captured).
    ///   - line: The source line number (auto-captured).
    public static func warn(
        _ message: String,
        category: LogCategory? = nil,
        fileID: String = #fileID,
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        log(message, level: .warning, category: category, fileID: fileID, function: function, file: file, line: line)
    }

    /// Logs an error that occurred but was handled.
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - category: Category for filtering. Defaults to the calling file.
    ///   - function: The calling function (auto-captured).
    ///   - file: The source file path (auto-captured).
    ///   - line: The source line number (auto-captured).
    public static func error(
        _ message: String,
        category: LogCategory? = nil,
        fileID: String = #fileID,
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        log(message, level: .error, category: category, fileID: fileID, function: function, file: file, line: line)
    }

    /// Logs a fatal error that may cause app termination or severe malfunction.
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - category: Category for filtering. Defaults to the calling file.
    ///   - function: The calling function (auto-captured).
    ///   - file: The source file path (auto-captured).
    ///   - line: The source line number (auto-captured).
    public static func fatal(
        _ message: String,
        category: LogCategory? = nil,
        fileID: String = #fileID,
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        log(message, level: .fatal, category: category, fileID: fileID, function: function, file: file, line: line)
    }

    // MARK: - Success & Completion

    /// Logs a successful operation or outcome.
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - category: Category for filtering. Defaults to the calling file.
    ///   - function: The calling function (auto-captured).
    ///   - file: The source file path (auto-captured).
    ///   - line: The source line number (auto-captured).
    public static func success(
        _ message: String,
        category: LogCategory? = nil,
        fileID: String = #fileID,
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        log(message, level: .success, category: category, fileID: fileID, function: function, file: file, line: line)
    }

    /// Logs task or operation completion.
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - category: Category for filtering. Defaults to the calling file.
    ///   - function: The calling function (auto-captured).
    ///   - file: The source file path (auto-captured).
    ///   - line: The source line number (auto-captured).
    public static func done(
        _ message: String,
        category: LogCategory? = nil,
        fileID: String = #fileID,
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        log(message, level: .done, category: category, fileID: fileID, function: function, file: file, line: line)
    }

    // MARK: - Network Operations

    /// Logs network-related activity.
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - category: Category for filtering. Defaults to the calling file.
    ///   - function: The calling function (auto-captured).
    ///   - file: The source file path (auto-captured).
    ///   - line: The source line number (auto-captured).
    public static func network(
        _ message: String,
        category: LogCategory? = nil,
        fileID: String = #fileID,
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        log(message, level: .network, category: category, fileID: fileID, function: function, file: file, line: line)
    }

    /// Logs API call activity (requests, responses, errors).
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - category: Category for filtering. Defaults to the calling file.
    ///   - function: The calling function (auto-captured).
    ///   - file: The source file path (auto-captured).
    ///   - line: The source line number (auto-captured).
    public static func api(
        _ message: String,
        category: LogCategory? = nil,
        fileID: String = #fileID,
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        log(message, level: .api, category: category, fileID: fileID, function: function, file: file, line: line)
    }

    // MARK: - Security & Authentication

    /// Logs security-related events (encryption, permissions, access control).
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - category: Category for filtering. Defaults to the calling file.
    ///   - function: The calling function (auto-captured).
    ///   - file: The source file path (auto-captured).
    ///   - line: The source line number (auto-captured).
    public static func security(
        _ message: String,
        category: LogCategory? = nil,
        fileID: String = #fileID,
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        log(message, level: .security, category: category, fileID: fileID, function: function, file: file, line: line)
    }

    /// Logs authentication events (login, logout, token refresh).
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - category: Category for filtering. Defaults to the calling file.
    ///   - function: The calling function (auto-captured).
    ///   - file: The source file path (auto-captured).
    ///   - line: The source line number (auto-captured).
    public static func auth(
        _ message: String,
        category: LogCategory? = nil,
        fileID: String = #fileID,
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        log(message, level: .auth, category: category, fileID: fileID, function: function, file: file, line: line)
    }

    // MARK: - Performance & Analytics

    /// Logs performance metrics (timing, memory, resource usage).
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - category: Category for filtering. Defaults to the calling file.
    ///   - function: The calling function (auto-captured).
    ///   - file: The source file path (auto-captured).
    ///   - line: The source line number (auto-captured).
    public static func metric(
        _ message: String,
        category: LogCategory? = nil,
        fileID: String = #fileID,
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        log(message, level: .metric, category: category, fileID: fileID, function: function, file: file, line: line)
    }

    /// Logs analytics events (user behavior, feature usage).
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - category: Category for filtering. Defaults to the calling file.
    ///   - function: The calling function (auto-captured).
    ///   - file: The source file path (auto-captured).
    ///   - line: The source line number (auto-captured).
    public static func analytics(
        _ message: String,
        category: LogCategory? = nil,
        fileID: String = #fileID,
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        log(message, level: .analytics, category: category, fileID: fileID, function: function, file: file, line: line)
    }

    // MARK: - UI & User Interaction

    /// Logs UI events (view lifecycle, layout, rendering).
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - category: Category for filtering. Defaults to the calling file.
    ///   - function: The calling function (auto-captured).
    ///   - file: The source file path (auto-captured).
    ///   - line: The source line number (auto-captured).
    public static func ui(
        _ message: String,
        category: LogCategory? = nil,
        fileID: String = #fileID,
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        log(message, level: .ui, category: category, fileID: fileID, function: function, file: file, line: line)
    }

    /// Logs user actions (taps, gestures, input).
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - category: Category for filtering. Defaults to the calling file.
    ///   - function: The calling function (auto-captured).
    ///   - file: The source file path (auto-captured).
    ///   - line: The source line number (auto-captured).
    public static func user(
        _ message: String,
        category: LogCategory? = nil,
        fileID: String = #fileID,
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        log(message, level: .user, category: category, fileID: fileID, function: function, file: file, line: line)
    }

    // MARK: - Database & Storage

    /// Logs database operations (queries, transactions, migrations).
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - category: Category for filtering. Defaults to the calling file.
    ///   - function: The calling function (auto-captured).
    ///   - file: The source file path (auto-captured).
    ///   - line: The source line number (auto-captured).
    public static func database(
        _ message: String,
        category: LogCategory? = nil,
        fileID: String = #fileID,
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        log(message, level: .database, category: category, fileID: fileID, function: function, file: file, line: line)
    }

    /// Logs storage operations (file I/O, cache, persistence).
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - category: Category for filtering. Defaults to the calling file.
    ///   - function: The calling function (auto-captured).
    ///   - file: The source file path (auto-captured).
    ///   - line: The source line number (auto-captured).
    public static func storage(
        _ message: String,
        category: LogCategory? = nil,
        fileID: String = #fileID,
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        log(message, level: .storage, category: category, fileID: fileID, function: function, file: file, line: line)
    }

    private static func log(
        _ message: String,
        level: LogLevel,
        category: LogCategory?,
        fileID: String,
        function: String,
        file: String,
        line: Int
    ) {
        let resolvedCategory = category ?? LogCategory(fileID, isAutoGenerated: true)
        logger.log(message, level: level, category: resolvedCategory, file: file, function: function, line: line)
    }
}
