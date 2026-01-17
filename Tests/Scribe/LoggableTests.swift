import XCTest
@testable import Scribe

// MARK: - LoggableClass

@Loggable
final class LoggableClass {
    func doWork() { log.info("LoggableClass working") }
}

// MARK: - LoggableStruct

@Loggable
struct LoggableStruct {
    func doWork() { log.info("LoggableStruct working") }
}

// MARK: - LoggableEnum

@Loggable
enum LoggableEnum {
    case one
    func doWork() { log.info("LoggableEnum working") }
}

// MARK: - LoggableCustomName

@Loggable("CustomName")
final class LoggableCustomName {
    func doWork() { log.info("LoggableCustomName working") }
}

// MARK: - LoggablePassedCategory

@Loggable(category: .passedInCategory)
final class LoggablePassedCategory {
    func doWork() { log.info("LoggablePassedCategory working") }
}

// MARK: - LoggableClassStatic

@Loggable(style: .static)
final class LoggableClassStatic {
    static func doWork() { log.info("LoggableClassStatic working") }
}

// MARK: - LoggableMacroTests

final class LoggableMacroTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Log.logger.setMinimumLevel(.debug)
        Log.logger.setConfiguration(.default)
        Log.logger.removeAllSinks()
    }

    func testLoggableClass() {
        XCTAssertEqual(LoggableClass._logCategory.name, "LoggableClass")
        XCTAssertEqual(LoggableClass().log.category.name, "LoggableClass")
    }

    func testLoggableStruct() {
        XCTAssertEqual(LoggableStruct._logCategory.name, "LoggableStruct")
        XCTAssertEqual(LoggableStruct().log.category.name, "LoggableStruct")
    }

    func testLoggableEnum() {
        XCTAssertEqual(LoggableEnum._logCategory.name, "LoggableEnum")
        XCTAssertEqual(LoggableEnum.one.log.category.name, "LoggableEnum")
    }

    func testLoggableStaticStyle() {
        XCTAssertEqual(LoggableClassStatic._logCategory.name, "LoggableClassStatic")
        XCTAssertEqual(LoggableClassStatic.log.category.name, "LoggableClassStatic")
    }

    func testLoggableCustomName() {
        XCTAssertEqual(LoggableCustomName._logCategory.name, "CustomName")
        XCTAssertEqual(LoggableCustomName().log.category.name, "CustomName")
    }

    func testLoggablePassedCategory() {
        XCTAssertEqual(LoggablePassedCategory._logCategory.name, "PassedInCategory")
        XCTAssertEqual(LoggablePassedCategory().log.category.name, "PassedInCategory")
    }

    func testLoggableActuallyLogs() {
        let expectation = XCTestExpectation(description: "Log received")

        Log.logger.addSink { message in
            if message.contains("LoggableClass working"), message.contains("[LoggableClass]") {
                expectation.fulfill()
            }
        }

        LoggableClass().doWork()

        wait(for: [expectation], timeout: 2.0)
    }
}
