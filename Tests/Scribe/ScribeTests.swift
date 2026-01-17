import XCTest
@testable @_spi(Internals) import Scribe

final class ScribeTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Reset to default state before each test
        Log.logger.setMinimumLevel(.debug)
        Log.logger.setConfiguration(.default)
        Log.logger.removeAllSinks()

        let clearExpectation = XCTestExpectation(description: "Logger cache cleared")
        Log.logger.clearLoggerCache {
            clearExpectation.fulfill()
        }
        wait(for: [clearExpectation], timeout: 1.0)
    }

    func testBasicLogging() throws {
        // Test basic logging functionality
        Log.info("Test info message")
        Log.debug("Test debug message")
        Log.error("Test error message")
        Log.success("Test success message")

        // Test logging with security levels
        Log.security("Test security message")
        Log.auth("Test auth message")
        Log.user("Test user message")

        // Test network logging
        Log.network("Test network message")
        Log.api("Test API message")

        // Test database logging
        Log.database("Test database message")
        Log.storage("Test storage message")

        // If we get here without deadlock, the test passes
        XCTAssertTrue(true)
    }

    func testConcurrentLogging() throws {
        let expectation = XCTestExpectation(description: "Concurrent logging completes")
        expectation.expectedFulfillmentCount = 10

        // Test logging from multiple threads simultaneously
        for i in 0 ..< 10 {
            DispatchQueue.global(qos: .background).async {
                Log.info("Background thread message \(i)")
                Log.debug("Debug from thread \(i)")
                Log.error("Error from thread \(i)")
                Log.network("Network call from thread \(i)")
                Log.security("Security event from thread \(i)")
                expectation.fulfill()
            }
        }

        // Also test from main thread
        Log.info("Main thread message")
        Log.success("Main thread success")

        wait(for: [expectation], timeout: 5.0)
    }

    func testLogLevels() throws {
        // Test setting minimum log level
        Log.logger.setMinimumLevel(.info)

        // These should be logged (>= info level)
        Log.info("This should be logged")
        Log.error("This should be logged")
        Log.fatal("This should be logged")

        // These should be filtered out (< info level)
        Log.debug("This should be filtered")
        Log.trace("This should be filtered")

        // Reset to debug level
        Log.logger.setMinimumLevel(.debug)

        XCTAssertTrue(true)
    }

    func testConfiguration() throws {
        // Test configuration changes with actual API
        let config = LogConfiguration(
            enabledCategories: [.test],
            includeTimestamp: true,
            dateFormat: "HH:mm:ss"
        )

        Log.logger.setConfiguration(config)

        Log.info("Test message with new configuration", category: .test)

        XCTAssertTrue(true)
    }

    func testCustomFormatter() throws {
        let expectation = XCTestExpectation(description: "Custom formatter called")

        let config = LogConfiguration(
            formatter: { context in
                expectation.fulfill()
                return "[\(context.level.shortCode)] \(context.category): \(context.message)"
            }
        )

        Log.logger.setConfiguration(config)
        Log.info("Test with custom formatter", category: .test)

        wait(for: [expectation], timeout: 2.0)
    }

    func testSinks() throws {
        let expectation = XCTestExpectation(description: "Sink received log")

        final class MessageCapture: @unchecked Sendable {
            var message: String?
        }
        let capture = MessageCapture()

        Log.logger.addSink { message in
            capture.message = message
            expectation.fulfill()
        }

        Log.info("Sink test message")

        wait(for: [expectation], timeout: 2.0)
        XCTAssertNotNil(capture.message)
        XCTAssertTrue(capture.message?.contains("Sink test message") ?? false)
    }

    func testSinksWithCategoryFilter() throws {
        let allowedExpectation = XCTestExpectation(description: "Allowed category logged")
        let blockedExpectation = XCTestExpectation(description: "Blocked category not logged")
        blockedExpectation.isInverted = true

        final class MessageCapture: @unchecked Sendable {
            var message: String?
        }
        let capture = MessageCapture()

        Log.logger.addSink(categories: [.testAllowed]) { message in
            capture.message = message

            if message.contains("[AllowedCategory]") {
                allowedExpectation.fulfill()
            }
            if message.contains("[BlockedCategory]") {
                blockedExpectation.fulfill()
            }
        }

        Log.info("Sink test message allowed", category: .testAllowed)
        Log.info("Sink test message blocked", category: .testBlocked)

        wait(for: [allowedExpectation, blockedExpectation], timeout: 2.0)
        XCTAssertNotNil(capture.message)
        XCTAssertTrue(capture.message?.contains("Sink test message allowed") ?? false)
    }

    func testStreams() throws {
        let expectation = XCTestExpectation(description: "Sink received log")

        final class MessageCapture: @unchecked Sendable {
            var message: String?
        }
        let capture = MessageCapture()

        Task {
            for await message in Log.logger.stream() {
                capture.message = message
                expectation.fulfill()
            }
        }

        Task {
            // Wait for the stream to start
            try? await Task.sleep(for: .milliseconds(500))

            Log.info("Sink test message")
        }

        wait(for: [expectation], timeout: 2.0)
        XCTAssertNotNil(capture.message)
        XCTAssertTrue(capture.message?.contains("Sink test message") ?? false)
    }

    func testStreamsWithCategoryFilter() throws {
        let allowedExpectation = XCTestExpectation(description: "Allowed category logged")
        let blockedExpectation = XCTestExpectation(description: "Blocked category not logged")
        blockedExpectation.isInverted = true

        final class MessageCapture: @unchecked Sendable {
            var message: String?
        }
        let capture = MessageCapture()

        Task {
            for await message in Log.logger.stream(categories: [.testAllowed]) {
                capture.message = message

                if message.contains("[AllowedCategory]") {
                    allowedExpectation.fulfill()
                }
                if message.contains("[BlockedCategory]") {
                    blockedExpectation.fulfill()
                }
            }
        }

        Task {
            // Wait for the stream to start
            try? await Task.sleep(for: .milliseconds(500))

            Log.info("Sink test message allowed", category: .testAllowed)
            Log.info("Sink test message blocked", category: .testBlocked)
        }

        wait(for: [allowedExpectation, blockedExpectation], timeout: 2.0)
        XCTAssertNotNil(capture.message)
        XCTAssertTrue(capture.message?.contains("Sink test message allowed") ?? false)
    }

    func testCategoryFiltering() throws {
        let allowedExpectation = XCTestExpectation(description: "Allowed category logged")
        let blockedExpectation = XCTestExpectation(description: "Blocked category not logged")
        blockedExpectation.isInverted = true

        Log.logger.addSink { message in
            if message.contains("[AllowedCategory]") {
                allowedExpectation.fulfill()
            }
            if message.contains("[BlockedCategory]") {
                blockedExpectation.fulfill()
            }
        }

        let config = LogConfiguration(enabledCategories: [.testAllowed])
        Log.logger.setConfiguration(config)

        Log.info("This should appear", category: .testAllowed)
        Log.info("This should not appear", category: .testBlocked)

        wait(for: [allowedExpectation, blockedExpectation], timeout: 2.0)
    }

    func testLogLevelProperties() throws {
        // Test LogLevel properties
        XCTAssertEqual(LogLevel.error.emoji, "❌")
        XCTAssertEqual(LogLevel.warning.shortCode, "WRN")
        XCTAssertEqual(LogLevel.info.name, "info")
        XCTAssertEqual(LogLevel.network.family, .networking)
    }

    func testLogLevelParsing() throws {
        XCTAssertEqual(LogLevel.parse("error"), .error)
        XCTAssertEqual(LogLevel.parse("ERR"), .error)
        XCTAssertEqual(LogLevel.parse("❌"), .error)
        XCTAssertNil(LogLevel.parse("invalid"))
    }

    func testLogLevelComparison() throws {
        XCTAssertTrue(LogLevel.error > LogLevel.debug)
        XCTAssertTrue(LogLevel.trace < LogLevel.info)
        XCTAssertTrue(LogLevel.warning >= LogLevel.warning)
    }

    func testLogLevelSets() throws {
        XCTAssertTrue(LogLevel.allSevere.contains(.error))
        XCTAssertTrue(LogLevel.allSevere.contains(.fatal))
        XCTAssertFalse(LogLevel.allSevere.contains(.warning))

        XCTAssertTrue(LogLevel.allProblems.contains(.warning))
        XCTAssertTrue(LogLevel.allProblems.contains(.error))

        XCTAssertTrue(LogLevel.noisyLevels.contains(.trace))
        XCTAssertTrue(LogLevel.noisyLevels.contains(.debug))
    }

    func testLogLevelHelpers() throws {
        let infoAndAbove = LogLevel.levels(minimum: .info)
        XCTAssertFalse(infoAndAbove.contains(.debug))
        XCTAssertTrue(infoAndAbove.contains(.info))
        XCTAssertTrue(infoAndAbove.contains(.error))

        let networkLevels = LogLevel.levels(in: .networking)
        XCTAssertTrue(networkLevels.contains(.network))
        XCTAssertTrue(networkLevels.contains(.api))
        XCTAssertEqual(networkLevels.count, 2)
    }

    func testLoggerCacheEvictionAndClear() throws {
        let logExpectation = XCTestExpectation(description: "Logs processed with eviction")
        logExpectation.expectedFulfillmentCount = 3

        let sinkID = Log.logger.addSink { _ in
            logExpectation.fulfill()
        }

        let configApplied = XCTestExpectation(description: "Configuration applied")
        Log.logger.setConfiguration(LogConfiguration(autoLoggerCacheLimit: 2))
        Log.logger.getConfiguration { cfg in
            if cfg.autoLoggerCacheLimit == 2 {
                configApplied.fulfill()
            }
        }

        wait(for: [configApplied], timeout: 1.0)

        Log.info("Evict one", category: .evictOneAuto)
        Log.info("Evict two", category: .evictTwoAuto)
        Log.info("Evict three", category: .evictThreeAuto)

        wait(for: [logExpectation], timeout: 2.0)

        XCTAssertEqual(Log.logger.loggerCacheCount, 2)

        let cleared = XCTestExpectation(description: "Cache cleared")
        Log.logger.clearLoggerCache {
            cleared.fulfill()
        }
        wait(for: [cleared], timeout: 1.0)
        XCTAssertEqual(Log.logger.loggerCacheCount, 0)

        Log.logger.removeSink(sinkID)
    }

    func testAutoCategoryNameIsSanitizedToFileName() throws {
        let expectation = XCTestExpectation(description: "Auto category sanitized")

        let sinkID = Log.logger.addSink { line in
            if line.contains("[FontLibrary.swift]") {
                XCTAssertFalse(line.contains("Scribe/FontLibrary.swift"))
                expectation.fulfill()
            }
        }

        Log.info("Test auto category", category: .init("Scribe/FontLibrary.swift", isAutoGenerated: true))

        wait(for: [expectation], timeout: 1.0)
        Log.logger.removeSink(sinkID)
    }

    func testDefaultCategoryUsesCallerFile() throws {
        let expectation = XCTestExpectation(description: "Default category uses caller file")

        let sinkID = Log.logger.addSink { line in
            if line.contains("[ScribeTests.swift]") {
                expectation.fulfill()
            }
        }

        Log.info("Default category should be caller file")

        wait(for: [expectation], timeout: 1.0)
        Log.logger.removeSink(sinkID)
    }
}
