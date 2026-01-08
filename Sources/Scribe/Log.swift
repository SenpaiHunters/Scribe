//
//  Log.swift
//  Scribe
//
//  Created by Kai Azim on 2026-01-08.
//

/// Logging interface providing convenient methods for all log levels.
///
/// Use the methods on this struct to log messages throughout your category.
/// This is useful if you want to use a shared logger specifically for a class, struct or enum where writing `category:
/// ...` in `Log.<method>` would be repetitive.
/// Similar to ``Log``, Each method automatically captures source location metadata (file, function, line).
///
/// ```swift
/// let log = Log(category: .init("Auth"))
/// log.info("User signed in")
/// log.error("User session expired")
/// log.debug("New user registered")
/// ```
///
/// It is recommended to use this alongside the `@Scribable` macro, which automatically creates the `Log` for you.
/// You can use is as shown below:
///
/// ```swift
/// @Scribable
/// struct TokenManager {
///     func test() {
///        log.success("New token generated")
///     }
/// }
/// ```
///
@frozen
public struct Log: Sendable {
    /// The shared `LogManager` instance used by all logging methods.
    public static var logger: LogManager { LogManager.shared }
    public let category: LogCategory

    public init(category: LogCategory) {
        self.category = category
    }

    // MARK: - Debug & Development

    /// Logs a debug message for development and troubleshooting.
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - function: The calling function (auto-captured).
    ///   - file: The source file path (auto-captured).
    ///   - line: The source line number (auto-captured).
    public func debug(_ message: String, function: String = #function, file: String = #file, line: Int = #line) {
        log(message, level: .debug, category: category, function: function, file: file, line: line)
    }

    /// Logs a trace message for detailed execution flow tracking.
    ///
    /// Use for granular debugging that's typically too verbose for regular debug builds.
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - function: The calling function (auto-captured).
    ///   - file: The source file path (auto-captured).
    ///   - line: The source line number (auto-captured).
    public func trace(_ message: String, function: String = #function, file: String = #file, line: Int = #line) {
        log(message, level: .trace, category: category, function: function, file: file, line: line)
    }

    /// Logs a print-level message as a structured replacement for `Swift.print()`.
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - function: The calling function (auto-captured).
    ///   - file: The source file path (auto-captured).
    ///   - line: The source line number (auto-captured).
    public func print(_ message: String, function: String = #function, file: String = #file, line: Int = #line) {
        log(message, level: .print, category: category, function: function, file: file, line: line)
    }

    // MARK: - General Information

    /// Logs an informational message about general app state or events.
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - function: The calling function (auto-captured).
    ///   - file: The source file path (auto-captured).
    ///   - line: The source line number (auto-captured).
    public func info(_ message: String, function: String = #function, file: String = #file, line: Int = #line) {
        log(message, level: .info, category: category, function: function, file: file, line: line)
    }

    /// Logs a notice about a notable but non-critical event.
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - function: The calling function (auto-captured).
    ///   - file: The source file path (auto-captured).
    ///   - line: The source line number (auto-captured).
    public func notice(_ message: String, function: String = #function, file: String = #file, line: Int = #line) {
        log(message, level: .notice, category: category, function: function, file: file, line: line)
    }

    // MARK: - Warnings & Errors

    /// Logs a warning about a potential issue that doesn't prevent operation.
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - function: The calling function (auto-captured).
    ///   - file: The source file path (auto-captured).
    ///   - line: The source line number (auto-captured).
    public func warn(_ message: String, function: String = #function, file: String = #file, line: Int = #line) {
        log(message, level: .warning, category: category, function: function, file: file, line: line)
    }

    /// Logs an error that occurred but was handled.
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - function: The calling function (auto-captured).
    ///   - file: The source file path (auto-captured).
    ///   - line: The source line number (auto-captured).
    public func error(_ message: String, function: String = #function, file: String = #file, line: Int = #line) {
        log(message, level: .error, category: category, function: function, file: file, line: line)
    }

    /// Logs a fatal error that may cause app termination or severe malfunction.
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - function: The calling function (auto-captured).
    ///   - file: The source file path (auto-captured).
    ///   - line: The source line number (auto-captured).
    public func fatal(_ message: String, function: String = #function, file: String = #file, line: Int = #line) {
        log(message, level: .fatal, category: category, function: function, file: file, line: line)
    }

    // MARK: - Success & Completion

    /// Logs a successful operation or outcome.
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - function: The calling function (auto-captured).
    ///   - file: The source file path (auto-captured).
    ///   - line: The source line number (auto-captured).
    public func success(_ message: String, function: String = #function, file: String = #file, line: Int = #line) {
        log(message, level: .success, category: category, function: function, file: file, line: line)
    }

    /// Logs task or operation completion.
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - function: The calling function (auto-captured).
    ///   - file: The source file path (auto-captured).
    ///   - line: The source line number (auto-captured).
    public func done(_ message: String, function: String = #function, file: String = #file, line: Int = #line) {
        log(message, level: .done, category: category, function: function, file: file, line: line)
    }

    // MARK: - Network Operations

    /// Logs network-related activity.
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - function: The calling function (auto-captured).
    ///   - file: The source file path (auto-captured).
    ///   - line: The source line number (auto-captured).
    public func network(_ message: String, function: String = #function, file: String = #file, line: Int = #line) {
        log(message, level: .network, category: category, function: function, file: file, line: line)
    }

    /// Logs API call activity (requests, responses, errors).
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - function: The calling function (auto-captured).
    ///   - file: The source file path (auto-captured).
    ///   - line: The source line number (auto-captured).
    public func api(_ message: String, function: String = #function, file: String = #file, line: Int = #line) {
        log(message, level: .api, category: category, function: function, file: file, line: line)
    }

    // MARK: - Security & Authentication

    /// Logs security-related events (encryption, permissions, access control).
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - function: The calling function (auto-captured).
    ///   - file: The source file path (auto-captured).
    ///   - line: The source line number (auto-captured).
    public func security(_ message: String, function: String = #function, file: String = #file, line: Int = #line) {
        log(message, level: .security, category: category, function: function, file: file, line: line)
    }

    /// Logs authentication events (login, logout, token refresh).
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - function: The calling function (auto-captured).
    ///   - file: The source file path (auto-captured).
    ///   - line: The source line number (auto-captured).
    public func auth(_ message: String, function: String = #function, file: String = #file, line: Int = #line) {
        log(message, level: .auth, category: category, function: function, file: file, line: line)
    }

    // MARK: - Performance & Analytics

    /// Logs performance metrics (timing, memory, resource usage).
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - function: The calling function (auto-captured).
    ///   - file: The source file path (auto-captured).
    ///   - line: The source line number (auto-captured).
    public func metric(_ message: String, function: String = #function, file: String = #file, line: Int = #line) {
        log(message, level: .metric, category: category, function: function, file: file, line: line)
    }

    /// Logs analytics events (user behavior, feature usage).
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - function: The calling function (auto-captured).
    ///   - file: The source file path (auto-captured).
    ///   - line: The source line number (auto-captured).
    public func analytics(_ message: String, function: String = #function, file: String = #file, line: Int = #line) {
        log(message, level: .analytics, category: category, function: function, file: file, line: line)
    }

    // MARK: - UI & User Interaction

    /// Logs UI events (view lifecycle, layout, rendering).
    ///
    /// - Parameters:
    ///   - message: The message to log.

    ///   - function: The calling function (auto-captured).
    ///   - file: The source file path (auto-captured).
    ///   - line: The source line number (auto-captured).
    public func ui(
        _ message: String,
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        log(message, level: .ui, category: category, function: function, file: file, line: line)
    }

    /// Logs user actions (taps, gestures, input).
    ///
    /// - Parameters:
    ///   - message: The message to log.

    ///   - function: The calling function (auto-captured).
    ///   - file: The source file path (auto-captured).
    ///   - line: The source line number (auto-captured).
    public func user(_ message: String, function: String = #function, file: String = #file, line: Int = #line) {
        log(message, level: .user, category: category, function: function, file: file, line: line)
    }

    // MARK: - Database & Storage

    /// Logs database operations (queries, transactions, migrations).
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - function: The calling function (auto-captured).
    ///   - file: The source file path (auto-captured).
    ///   - line: The source line number (auto-captured).
    public func database(_ message: String, function: String = #function, file: String = #file, line: Int = #line) {
        log(message, level: .database, category: category, function: function, file: file, line: line)
    }

    /// Logs storage operations (file I/O, cache, persistence).
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - function: The calling function (auto-captured).
    ///   - file: The source file path (auto-captured).
    ///   - line: The source line number (auto-captured).
    public func storage(_ message: String, function: String = #function, file: String = #file, line: Int = #line) {
        log(message, level: .storage, category: category, function: function, file: file, line: line)
    }

    private func log(
        _ message: String, level: LogLevel, category: LogCategory, function: String, file: String, line: Int
    ) {
        Log.logger.log(message, level: level, category: category, file: file, function: function, line: line)
    }
}
