//
//  ProgressTests.swift
//  MediaHubTests
//
//  Tests for progress reporting and cancellation support
//

import XCTest
@testable import MediaHub

final class ProgressTests: XCTestCase {
    
    // MARK: - CancellationToken Thread Safety Tests
    
    func testCancellationTokenThreadSafety() {
        let token = CancellationToken()
        let expectation = XCTestExpectation(description: "All threads complete")
        expectation.expectedFulfillmentCount = 10 // 5 cancel threads + 5 check threads
        
        // Spawn multiple threads calling cancel() concurrently
        for _ in 0..<5 {
            DispatchQueue.global().async {
                token.cancel()
                expectation.fulfill()
            }
        }
        
        // Spawn multiple threads checking isCanceled concurrently
        for _ in 0..<5 {
            DispatchQueue.global().async {
                _ = token.isCanceled
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify isCanceled eventually becomes true after cancel() calls
        XCTAssertTrue(token.isCanceled, "isCanceled should be true after cancel() calls")
    }
    
    func testCancellationTokenIdempotence() {
        let token = CancellationToken()
        
        // Initially not canceled
        XCTAssertFalse(token.isCanceled, "Token should not be canceled initially")
        
        // Call cancel() multiple times
        token.cancel()
        XCTAssertTrue(token.isCanceled, "isCanceled should be true after first cancel() call")
        
        token.cancel()
        XCTAssertTrue(token.isCanceled, "isCanceled should remain true after second cancel() call")
        
        token.cancel()
        XCTAssertTrue(token.isCanceled, "isCanceled should remain true after third cancel() call")
        
        // Verify multiple calls have same effect as single call (idempotent)
        XCTAssertTrue(token.isCanceled, "Multiple cancel() calls should have same effect as single call")
    }
}
