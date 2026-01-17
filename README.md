## Scribe Logging

A lightweight, thread-safe logging package for Swift apps using os.log under the hood.  
Designed for clarity, ergonomics, and performance — without encryption.  
Supports granular log levels, category filtering, custom formatting, and pluggable sinks.

## Features

- Clear log levels with emoji-first output; short codes are opt-in
- Reusable `LogCategory` type to avoid stringly-typed categories
- Per-category `Logger` instances for Console/Xcode filtering
- Thread-safe, async logging via a dedicated queue
- os.log integration with sensible OSLogType mapping
- Category filtering through configuration (`Set<LogCategory>`)
- Customizable formatter using `LogConfiguration.FormatterContext`
- Pluggable sinks for mirroring logs (e.g., tests, files, remote endpoints)
- Minimal API for everyday logging via static `Log` helpers

## Installation

Install via SPM from `https://github.com/SenpaiHunters/Scribe.git`

```swift
.package(url: "https://github.com/SenpaiHunters/Scribe.git", branch: "main")
```

Then import in your source files:

```swift
import Scribe
```

## Quick Start

```swift
import Scribe

// Define reusable categories once
extension LogCategory {
    static let app = LogCategory("App")
    static let auth = LogCategory("Auth")
    static let network = LogCategory("NetworkLayer")
    static let apiService = LogCategory("APIService")
    static let profile = LogCategory("Profile")
}

// Set minimum level (messages below this level are ignored)
LogManager.shared.minimumLevel = .debug

// Optional: restrict logging to specific categories
let config = LogConfiguration(enabledCategories: [.network, .apiService])
LogManager.shared.configuration = config

// Optional: add a sink (e.g., for tests or file mirroring)
LogManager.shared.addSink { line in
    print("SINK:", line)
}

// Log messages anywhere in your app
Log.debug("Bootstrapping app", category: .app)
Log.info("User signed in", category: .auth)
Log.warn("Slow response", category: .network)
Log.error("Failed to decode payload", category: .apiService)
Log.success("Profile updated", category: .profile)
```

## API Overview

### LogLevel

Represents message severity and domain.

- **Families**: development, general, problems, success, networking, security, performance, ui, data
- **Helpers**:
  - `LogLevel.parse("ERR")` → `.error`
  - `LogLevel.levels(minimum: .info)` — all levels at or above info
  - `LogLevel.levels(in: .networking)` — levels in a family
  - `LogLevel.families()` — all family cases
- **Display**:
  - `level.emoji` (e.g., "⚠️")
  - `level.shortCode` (e.g., "WRN")
  - `level.name` (e.g., "warning")
- **Predefined sets**:
  - `LogLevel.allSevere` — error, fatal
  - `LogLevel.allProblems` — warning, error, fatal
  - `LogLevel.noisyLevels` — trace, debug, print
- **OS integration**:
  - `level.osLogType` maps to OSLogType

### LogCategory

Lightweight wrapper for reusable, strongly typed categories.

- Defaults to `LogCategory(#fileID)` when you omit the `category` parameter.
- Extend it once and reuse everywhere to avoid typo-prone string literals:

```swift
extension LogCategory {
    static let apiService = LogCategory("APIService")
    static let storage = LogCategory("Storage")
}
```

- Each category maps to its own `Logger` instance under the same subsystem, so Console and Xcode show first-class category filters without extra configuration.

### @Loggable Macro

Automatically generates a `log` property for classes, structs, and enums.

```swift
@Loggable
struct TokenManager {
    func refresh() {
        log.info("Refreshing token")
    }
}
```

**Options:**
- `@Loggable` — uses the type name as the category
- `@Loggable("CustomName")` — uses a custom category name
- `@Loggable(category: .network)` — uses an existing `LogCategory`
- `@Loggable(style: .static)` — generates a static `log` property instead of instance

### LogManager

Core logger with configuration and sinks.

- **Properties**:
  - `LogManager.shared` — singleton instance
  - `minimumLevel: LogLevel` — threshold (read/write)
  - `configuration: LogConfiguration` — formatting and filtering (read/write)
  - `sinkCount: Int` — number of registered sinks
  - `loggerCacheCount: Int` — number of cached `Logger` instances
- **Methods**:
  - `log(_:level:category:file:function:line:)` — core logging method
  - `setMinimumLevel(_:)` — async level setter
  - `getMinimumLevel(_:)` — async level getter with completion handler
  - `setConfiguration(_:)` — async configuration setter
  - `getConfiguration(_:)` — async configuration getter with completion handler
  - `addSink(categories:_:) -> LogSubscription` — register a sink with optional category filter, returns ID for removal
  - `removeSink(_:)` — remove a specific sink by ID
  - `removeAllSinks()` — remove all sinks
  - `stream(categories:) -> AsyncStream<String>` — create an async stream of log messages with optional category filter
  - `clearLoggerCache(completion:)` — clear cached `Logger` instances

### LogConfiguration

Configuration struct for customizing log output.

- `enabledCategories: Set<LogCategory>?` — categories to include; `nil` allows all
- `formatter: ((LogConfiguration.FormatterContext) -> String)?` — custom formatter
- `includeTimestamp: Bool` — include timestamps (default: `true`)
- `includeEmoji: Bool` — include level emoji (default: `true`)
- `includeShortCode: Bool` — include level short code like `[DBG]` (default: `false`)
- `includeFileAndLineNumber: Bool` — include source file and line number (default: `true`)
- `autoLoggerCacheLimit: Int?` — limit cached auto-generated `Logger` instances (e.g., `#fileID`); `nil` means unbounded; default is 100
- `dateFormat: String` — timestamp format (default: `"yyyy-MM-dd HH:mm:ss.SSSZ"`)

**FormatterContext fields:**

- `level: LogLevel`
- `category: LogCategory`
- `message: String`
- `file: String`
- `line: Int`
- `timestamp: Date`

**Default formatter output:**

```text
[timestamp] [emoji] [Category] Message — File.swift:123
```

**Example:**

```text
2025-11-28 10:15:30.123+1000 🔍 [App] Bootstrapping app — AppDelegate.swift:42
```

### Log

Ergonomic static helpers that auto-fill file/function/line:

- **Development**: `Log.trace`, `Log.debug`, `Log.print`
- **Info**: `Log.info`, `Log.notice`
- **Problems**: `Log.warn`, `Log.error`, `Log.fatal`
- **Success**: `Log.success`, `Log.done`
- **Networking**: `Log.network`, `Log.api`
- **Security**: `Log.security`, `Log.auth`
- **Performance**: `Log.metric`, `Log.analytics`
- **UI & User**: `Log.ui`, `Log.user`
- **Data**: `Log.database`, `Log.storage`

**Usage:**

```swift
extension LogCategory {
    static let apiService = LogCategory("APIService")
    static let perf = LogCategory("Perf")
    static let ui = LogCategory("UI")
}

Log.api("GET /v1/profile", category: .apiService)
Log.metric("Home render time: 34ms", category: .perf)
Log.user("Tapped Purchase", category: .ui)
```

## Configuration

### Setting Minimum Level

```swift
// Only log messages at info level or higher
LogManager.shared.minimumLevel = .info
```

### Category Filtering

Restrict logging to specific categories:

```swift
extension LogCategory {
    static let networkLayer = LogCategory("NetworkLayer")
    static let auth = LogCategory("Auth")
    static let apiService = LogCategory("APIService")
}

let config = LogConfiguration(enabledCategories: [.networkLayer, .auth, .apiService])
LogManager.shared.configuration = config
```

To allow all categories:

```swift
let config = LogConfiguration(enabledCategories: nil)
LogManager.shared.configuration = config
```

**Console/Xcode filtering:** Each `LogCategory` uses its own `Logger` under the shared subsystem (bundle identifier by default). In Console.app or Xcode, filter by `subsystem=<your bundle id>` and `category=<LogCategory name>` to zero in on specific modules.

### Custom Formatting

Provide your own formatter for complete control over log output. The formatter receives a single `FormatterContext`, so you don't need to juggle multiple parameters:

```swift
let config = LogConfiguration(
    formatter: { context in
        let fileName = (context.file as NSString).lastPathComponent
        return "[\(context.level.shortCode)] [\(context.category.name)] \(context.message) (\(fileName):\(context.line))"
    }
)
LogManager.shared.configuration = config
```

### Toggle Emojis or Short Codes

- Default: emojis on, short codes off.
- Turn off emojis:

```swift
let config = LogConfiguration(includeEmoji: false)
LogManager.shared.configuration = config
```

- Turn on short codes (and optionally keep emojis):

```swift
let config = LogConfiguration(includeEmoji: true, includeShortCode: true)
LogManager.shared.configuration = config
```

### Disable Timestamps

```swift
let config = LogConfiguration(includeTimestamp: false)
LogManager.shared.configuration = config
```

### Custom Date Format

```swift
let config = LogConfiguration(dateFormat: "HH:mm:ss")
LogManager.shared.configuration = config
```

### Logger Cache Control

- Cap cached auto-generated `Logger` instances (e.g., `#fileID`) to avoid unbounded growth:

```swift
let config = LogConfiguration(autoLoggerCacheLimit: 50)
LogManager.shared.configuration = config
```

- Clear both auto-generated and custom logger caches (for long-running sessions or tests):

```swift
LogManager.shared.clearLoggerCache()
```

- Notes:
  - Auto-generated categories (`#fileID`) are cached with a default limit of 100. When the limit is reached, the least recently used loggers are removed first.
  - Custom categories you define (e.g., `LogCategory("APIService")`) are cached permanently and not removed.

### Combined Configuration

```swift
let config = LogConfiguration(
    enabledCategories: [.init("App"), .init("Network")],
    includeTimestamp: true,
    dateFormat: "HH:mm:ss.SSS"
)
LogManager.shared.configuration = config
```

## Sinks

Sinks receive formatted log lines and can forward them to files, remote endpoints, or test assertions.

### Adding a Sink

```swift
let sinkID = LogManager.shared.addSink { line in
    // Write to file
    FileAppender.shared.append(line)
    
    // Or send to remote service
    RemoteLogger.shared.enqueue(line)
}
```

### Removing a Specific Sink

```swift
// Store the ID when adding
let sinkID = LogManager.shared.addSink { line in
    print("Captured:", line)
}

// Remove later
LogManager.shared.removeSink(sinkID)
```

### Removing All Sinks

```swift
LogManager.shared.removeAllSinks()
```

### Checking Sink Count

```swift
let count = LogManager.shared.sinkCount
```

### Streaming

For async/await, use `stream()` instead of callbacks:

```swift
let stream = LogManager.shared.stream()

Task {
    for await line in stream {
        print("Log:", line)
    }
}
```

## Threading and Performance

- Logging occurs on a dedicated utility queue to minimize call-site blocking.
- `os_log` defers formatting efficiently and integrates with Console.app.
- Use `minimumLevel` to reduce overhead in production.
- All configuration access is thread-safe.
- Each `LogCategory` gets its own `Logger`, so Console/Xcode filtering by category works out of the box.

## Best Practices

- Use the `@Loggable` macro to automatically generate a `log` property for your types.
- Use categories to group logs by module or feature (e.g., `LogCategory("APIService")`, `LogCategory("Storage")`).
- Raise `minimumLevel` in production (e.g., `.info` or `.warning`).
- Avoid logging PII or secrets; this package does not perform encryption or redaction.
- Add a sink for test environments to assert on log output.
- Use `removeSink(_:)` to clean up sinks when they're no longer needed.

## Example Integration

```swift
extension LogCategory {
    static let app = LogCategory("App")
}

@Loggable
final class APIService {
    func fetchProfile() {
        log.api("GET /v1/profile")
        // ... network call ...
        log.debug("Decoded Profile(id: 123)")
    }
}

@main
struct MyApp: App {
    init() {
        // Configure logging
        LogManager.shared.minimumLevel = .info
        
        let config = LogConfiguration(
            enabledCategories: [.app, APIService.logCategory],
            includeTimestamp: true
        )
        LogManager.shared.configuration = config
        
        Log.info("App launched", category: .app)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

## Testing with Sinks

```swift
func testLogging() {
    let expectation = XCTestExpectation(description: "Log captured")
    
    let sinkID = LogManager.shared.addSink { line in
        XCTAssertTrue(line.contains("Test message"))
        expectation.fulfill()
    }
    
    Log.info("Test message", category: .init("Test"))
    
    wait(for: [expectation], timeout: 2.0)
    LogManager.shared.removeSink(sinkID)
}
```

## License

Scribe is released under **BSD 3-Clause License.** See the [LICENSE](LICENSE) file in the repository for the full license text.
