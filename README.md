## Scribe Logging

A lightweight, thread-safe logging package for Swift apps using os.log under the hood.  
Designed for clarity, ergonomics, and performance — without encryption.  
Supports granular log levels, category filtering, custom formatting, and pluggable sinks.

## Features

- Clear, expressive log levels with emojis and short codes
- Thread-safe, async logging via a dedicated queue
- os.log integration with sensible OSLogType mapping
- Category filtering through configuration
- Customizable formatter with timestamps and file/line info
- Pluggable sinks for mirroring logs (e.g., tests, files, remote endpoints)
- Minimal API for everyday logging via static `Log` helpers

## Installation

Install via SPM from `https://github.com/SenpaiHunters/Scribe.git`

```swift
.package(url: "https://github.com/SenpaiHunters/Scribe.git", from: "1.0.0")
```

Then import in your source files:

```swift
import Scribe
```

## Quick Start

```swift
import Scribe

// Set minimum level (messages below this level are ignored)
LogManager.shared.minimumLevel = .debug

// Optional: restrict logging to specific categories
let config = LogConfiguration(enabledCategories: ["NetworkLayer", "APIService"])
LogManager.shared.configuration = config

// Optional: add a sink (e.g., for tests or file mirroring)
LogManager.shared.addSink { line in
    print("SINK:", line)
}

// Log messages anywhere in your app
Log.debug("Bootstrapping app", category: "App")
Log.info("User signed in", category: "Auth")
Log.warn("Slow response", category: "NetworkLayer")
Log.error("Failed to decode payload", category: "APIService")
Log.success("Profile updated", category: "Profile")
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

### LogManager

Core logger with configuration and sinks.

- **Properties**:
  - `LogManager.shared` — singleton instance
  - `minimumLevel: LogLevel` — threshold (read/write)
  - `configuration: LogConfiguration` — formatting and filtering (read/write)
  - `sinkCount: Int` — number of registered sinks
- **Methods**:
  - `log(_:level:category:file:function:line:)` — core logging method
  - `setMinimumLevel(_:)` — async level setter
  - `setConfiguration(_:)` — async configuration setter
  - `addSink(_:) -> SinkID` — register a sink, returns ID for removal
  - `removeSink(_:)` — remove a specific sink by ID
  - `removeAllSinks()` — remove all sinks

### LogConfiguration

Configuration struct for customizing log output.

- `enabledCategories: Set<String>?` — categories to include; `nil` allows all
- `formatter: ((LogLevel, String, String, String, Int, Date) -> String)?` — custom formatter
- `includeTimestamp: Bool` — include timestamps (default: `true`)
- `dateFormat: String` — timestamp format (default: `"yyyy-MM-dd HH:mm:ss.SSSZ"`)

**Default formatter output:**

```
[timestamp] [emoji] [SHORT] [Category] Message — File.swift:123
```

**Example:**

```
2025-11-28 10:15:30.123+1000 🔍 [DBG] [App] Bootstrapping app — AppDelegate.swift:42
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
Log.api("GET /v1/profile", category: "APIService")
Log.metric("Home render time: 34ms", category: "Perf")
Log.user("Tapped Purchase", category: "UI")
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
let config = LogConfiguration(enabledCategories: ["NetworkLayer", "Auth", "APIService"])
LogManager.shared.configuration = config
```

To allow all categories:

```swift
let config = LogConfiguration(enabledCategories: nil)
LogManager.shared.configuration = config
```

### Custom Formatting

Provide your own formatter for complete control over log output:

```swift
let config = LogConfiguration(
    formatter: { level, category, message, file, line, timestamp in
        let fileName = (file as NSString).lastPathComponent
        return "[\(level.shortCode)] \(category): \(message) (\(fileName):\(line))"
    }
)
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

### Combined Configuration

```swift
let config = LogConfiguration(
    enabledCategories: ["App", "Network"],
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

## Threading and Performance

- Logging occurs on a dedicated utility queue to minimize call-site blocking.
- `os_log` defers formatting efficiently and integrates with Console.app.
- Use `minimumLevel` to reduce overhead in production.
- All configuration access is thread-safe.

## Best Practices

- Use categories to group logs by module or feature (e.g., "APIService", "Storage").
- Raise `minimumLevel` in production (e.g., `.info` or `.warning`).
- Avoid logging PII or secrets; this package does not perform encryption or redaction.
- Add a sink for test environments to assert on log output.
- Use `removeSink(_:)` to clean up sinks when they're no longer needed.

## Example Integration

```swift
final class APIService {
    func fetchProfile() {
        Log.api("GET /v1/profile", category: "APIService")
        // ... network call ...
        Log.debug("Decoded Profile(id: 123)", category: "APIService")
    }
}

@main
struct MyApp: App {
    init() {
        // Configure logging
        LogManager.shared.minimumLevel = .info
        
        let config = LogConfiguration(
            enabledCategories: ["App", "APIService"],
            includeTimestamp: true
        )
        LogManager.shared.configuration = config
        
        Log.info("App launched", category: "App")
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
    
    Log.info("Test message", category: "Test")
    
    wait(for: [expectation], timeout: 2.0)
    LogManager.shared.removeSink(sinkID)
}
```

## License

Scribe is released under **BSD 3-Clause License.** See the [LICENSE](LICENSE) file in the repository for the full license text.
