//
//  DurationMeasurementTests.swift
//  MediaHubTests
//
//  Tests for duration measurement helper
//

import XCTest
@testable import MediaHub

final class DurationMeasurementTests: XCTestCase {
    
    // MARK: - Basic Measurement Tests
    
    func testMeasureNonThrowingOperation() {
        let result = DurationMeasurement.measure {
            // Simple operation that takes some time
            Thread.sleep(forTimeInterval: 0.01) // 10ms
            return 42
        }
        
        XCTAssertEqual(result.result, 42)
        XCTAssertNotNil(result.durationSeconds, "Duration should be present for measured operation")
        XCTAssertGreaterThan(result.durationSeconds!, 0.0, "Duration should be greater than 0")
        // Allow some tolerance for timing (should be at least 0.01 seconds, but allow for system overhead)
        XCTAssertGreaterThanOrEqual(result.durationSeconds!, 0.005, "Duration should be at least 5ms")
    }
    
    func testMeasureFastOperation() {
        let result = DurationMeasurement.measure {
            // Very fast operation
            return "fast"
        }
        
        XCTAssertEqual(result.result, "fast")
        XCTAssertNotNil(result.durationSeconds, "Duration should be present even for fast operations")
        XCTAssertGreaterThanOrEqual(result.durationSeconds!, 0.0, "Duration should be non-negative")
        // Fast operations may have very small durations, but should still be measured
    }
    
    func testMeasureThrowingOperationSuccess() {
        // Use non-throwing version since operation doesn't throw
        let result = DurationMeasurement.measure {
            Thread.sleep(forTimeInterval: 0.01)
            return "success"
        }
        
        XCTAssertEqual(result.result, "success")
        XCTAssertNotNil(result.durationSeconds)
        XCTAssertGreaterThan(result.durationSeconds!, 0.0)
    }
    
    func testMeasureThrowingOperationError() {
        enum TestError: Error {
            case testFailure
        }
        
        XCTAssertThrowsError(try DurationMeasurement.measure {
            throw TestError.testFailure
        }) { error in
            // Verify original error is preserved
            guard case TestError.testFailure = error else {
                XCTFail("Expected TestError.testFailure, got \(error)")
                return
            }
        }
    }
    
    func testMeasureOperationWithCustomError() {
        enum CustomError: Error, Equatable {
            case custom(String)
        }
        
        XCTAssertThrowsError(try DurationMeasurement.measure {
            throw CustomError.custom("test message")
        }) { error in
            guard case CustomError.custom(let message) = error else {
                XCTFail("Expected CustomError.custom, got \(error)")
                return
            }
            XCTAssertEqual(message, "test message", "Error message should be preserved")
        }
    }
    
    // MARK: - Error Preservation Tests
    
    func testErrorTypePreserved() {
        enum ErrorType1: Error {
            case error1
        }
        enum ErrorType2: Error {
            case error2
        }
        
        // Test ErrorType1
        XCTAssertThrowsError(try DurationMeasurement.measure {
            throw ErrorType1.error1
        }) { error in
            XCTAssertTrue(error is ErrorType1, "Error type should be preserved")
            XCTAssertFalse(error is ErrorType2, "Error should not be converted to different type")
        }
        
        // Test ErrorType2
        XCTAssertThrowsError(try DurationMeasurement.measure {
            throw ErrorType2.error2
        }) { error in
            XCTAssertTrue(error is ErrorType2, "Error type should be preserved")
            XCTAssertFalse(error is ErrorType1, "Error should not be converted to different type")
        }
    }
    
    func testErrorMessagePreserved() {
        struct DetailedError: Error, Equatable {
            let message: String
            let code: Int
        }
        
        let originalError = DetailedError(message: "Original message", code: 42)
        
        XCTAssertThrowsError(try DurationMeasurement.measure {
            throw originalError
        }) { error in
            guard let detailedError = error as? DetailedError else {
                XCTFail("Expected DetailedError, got \(error)")
                return
            }
            XCTAssertEqual(detailedError, originalError, "Error should be preserved exactly")
            XCTAssertEqual(detailedError.message, "Original message")
            XCTAssertEqual(detailedError.code, 42)
        }
    }
    
    // MARK: - Duration Characteristics Tests
    
    func testDurationIsInformational() {
        // Run same operation multiple times - durations may vary
        // We do NOT assert equality across runs (duration is informational)
        let durations = (0..<5).map { _ in
            DurationMeasurement.measure {
                Thread.sleep(forTimeInterval: 0.01)
                return "result"
            }.durationSeconds!
        }
        
        // All durations should be present and positive
        for duration in durations {
            XCTAssertGreaterThan(duration, 0.0, "All durations should be positive")
        }
        
        // But we do NOT assert they are equal (duration may vary)
        // This test just verifies they are all reasonable values
    }
    
    func testDurationForLongerOperation() {
        let result = DurationMeasurement.measure {
            Thread.sleep(forTimeInterval: 0.1) // 100ms
            return "long"
        }
        
        XCTAssertEqual(result.result, "long")
        XCTAssertNotNil(result.durationSeconds)
        XCTAssertGreaterThanOrEqual(result.durationSeconds!, 0.09, "Duration should be at least 90ms for 100ms sleep")
        // Allow some tolerance, but should be close to 0.1 seconds
    }
    
    // MARK: - Edge Cases
    
    func testMeasureVoidResult() {
        var executed = false
        let result = DurationMeasurement.measure {
            executed = true
        }
        
        XCTAssertTrue(executed, "Operation should be executed")
        XCTAssertNotNil(result.durationSeconds)
        XCTAssertGreaterThanOrEqual(result.durationSeconds!, 0.0)
    }
    
    func testMeasureWithReturnValue() {
        let result = DurationMeasurement.measure {
            return [1, 2, 3]
        }
        
        XCTAssertEqual(result.result, [1, 2, 3])
        XCTAssertNotNil(result.durationSeconds)
    }
    
    func testMeasureWithComplexResult() {
        struct ComplexResult: Equatable {
            let value: Int
            let data: [String]
        }
        
        let result = DurationMeasurement.measure {
            return ComplexResult(value: 42, data: ["a", "b", "c"])
        }
        
        XCTAssertEqual(result.result, ComplexResult(value: 42, data: ["a", "b", "c"]))
        XCTAssertNotNil(result.durationSeconds)
    }
    
    // MARK: - Best-Effort Behavior
    
    func testMeasurementDoesNotAffectResult() {
        // Verify that measurement wrapper does not modify operation results
        let expectedResult = "test result"
        let result = DurationMeasurement.measure {
            return expectedResult
        }
        
        XCTAssertEqual(result.result, expectedResult, "Result should be unchanged by measurement")
    }
    
    func testMeasurementDoesNotAffectError() {
        // Verify that measurement wrapper does not modify errors
        struct TestError: Error, Equatable {
            let message: String
        }
        
        let originalError = TestError(message: "original")
        
        XCTAssertThrowsError(try DurationMeasurement.measure {
            throw originalError
        }) { error in
            guard let testError = error as? TestError else {
                XCTFail("Expected TestError")
                return
            }
            XCTAssertEqual(testError, originalError, "Error should be unchanged by measurement")
        }
    }
}
