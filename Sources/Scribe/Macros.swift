//
//  Macros.swift
//  Scribe
//
//  Created by Kai Azim on 2026-01-07.
//

#if $Macros && hasAttribute(attached)

    /// A style of log to be added via the macro.
    public enum LogStyle {
        /// Makes the `log` a static property.
        case `static`

        /// Makes the `log` an instance property.
        case instance
    }

    /// Defines and implements a log and a category.
    ///
    /// This macro helps to implement log helpers to ease the use of Scribe across your project.
    ///
    /// # Usage
    ///
    /// The `@Loggable` macro allows a type to automatically provide:
    /// - a `Log` instance
    /// - a `LogCategory` instance
    /// specific to that type.
    ///
    /// Why is this useful?
    /// Normally, you would need to define a `LogCategory` for each type and pass it into every log statement.
    /// It's easy to forget to create or use the correct category, which can lead to inconsistent logging.
    /// `@Loggable` solves this by automatically generating the appropriate category for you,
    /// ensuring that every log statement is correctly categorized.
    ///
    /// Example before using `@Loggable`:
    /// ```swift
    /// final class Updater {
    ///     func fetchLatestInfo() {
    ///         Log.info("Checking for updates...", category: .updater)
    ///         // ...
    ///         Log.info("Finished for updates!", category: .updater)
    ///     }
    ///
    ///     func installUpdate() {
    ///         Log.info("Installing update...", category: .updater)
    ///         // ...
    ///         Log.info("Installed update, ready to relaunch!", category: .updater)
    ///     }
    /// }
    ///
    /// extension LogCategory {
    ///     static let updater = LogCategory("Updater")
    /// }
    /// ```
    ///
    /// With `@Loggable`:
    /// ```swift
    /// @Loggable
    /// final class Updater {
    ///     func fetchLatestInfo() {
    ///         log.info("Checking for updates...")
    ///         // ...
    ///         log.info("Finished for updates!")
    ///     }
    ///
    ///     func installUpdate() {
    ///         log.info("Installing update...")
    ///         // ...
    ///         log.info("Installed update, ready to relaunch!")
    ///     }
    /// }
    /// ```
    ///
    /// Using this macro gives you a cleaner, safer workflow:
    /// - No need to manually define a `LogCategory`
    /// - You won’t forget to add the correct category
    /// - Every log statement automatically uses the right category for the type
    ///
    /// # Log Styles
    ///
    /// This macro attaches two or three properties to the given type depending on the used log style:
    ///
    /// **Static Log Style**
    ///
    /// Usage: `@Loggable(style: .static)`
    ///
    /// - A static property with the name `log` is exposed, of type `Log`.
    /// - A static property with the name `logCategory` is exposed, of type `LogCategory`. This category is used in the
    /// Log to help categorize this type.
    ///
    /// ## Instance Log Style
    ///
    /// Usage: `@Loggable(style: .instance)` or simply `@Loggable`
    ///
    /// - An instance property with the name `log` is exposed, of type `Log`. This is actually just a computed variable
    /// for the static property defined below:
    /// - A private, static property with the name `_log` is exposed, of type `Log`. Expect this to work in the same way
    /// that the static log style defines `log`, just that it is private. This is used to store a single, shared
    /// instance across all instances of this type.
    /// - A static property with the name `logCategory` is exposed, of type `LogCategory`. This category is used in the
    /// Log to help categorize this type.
    ///
    /// # Naming
    ///
    /// By default, the `@Loggable` macro uses the type’s name as the log category.
    /// If you’d like to override this, you can provide a custom name as the macro’s first argument.
    ///
    /// For example, applying `@Loggable("Network")` to a type named `NetworkManager`
    /// will create a `LogCategory` named `Network` instead of `NetworkManager`.
    ///
    @attached(member, names: named(log), named(_log), named(logCategory))
    public macro Loggable(
        _ name: StaticString? = nil,
        category: LogCategory? = nil,
        style: LogStyle = .instance
    ) = #externalMacro(
        module: "ScribeMacros",
        type: "LoggableMacro"
    )
#endif
