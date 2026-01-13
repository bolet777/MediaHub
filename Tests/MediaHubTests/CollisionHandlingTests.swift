//
//  CollisionHandlingTests.swift
//  MediaHubTests
//
//  Tests for collision detection and policy handling
//

import XCTest
@testable import MediaHub

final class CollisionHandlingTests: XCTestCase {
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    func testDetectCollisionNoCollision() {
        // Create destination URL
        let destinationURL = tempDirectory.appendingPathComponent("test.jpg")
        
        // Detect collision (should be none)
        let result = CollisionHandler.detectCollision(at: destinationURL)
        
        if case .noCollision = result {
            // Expected
        } else {
            XCTFail("Expected no collision")
        }
    }
    
    func testDetectCollisionWithExistingFile() throws {
        // Create an existing file
        let destinationURL = tempDirectory.appendingPathComponent("test.jpg")
        try "existing".write(to: destinationURL, atomically: true, encoding: .utf8)
        
        // Detect collision
        let result = CollisionHandler.detectCollision(at: destinationURL)
        
        if case .collision(let existingPath, let isDirectory) = result {
            XCTAssertEqual(existingPath, destinationURL)
            XCTAssertFalse(isDirectory)
        } else {
            XCTFail("Expected collision")
        }
    }
    
    func testHandleCollisionRenamePolicy() throws {
        // Create an existing file
        let destinationURL = tempDirectory.appendingPathComponent("test.jpg")
        try "existing".write(to: destinationURL, atomically: true, encoding: .utf8)
        
        // Detect collision
        let collision = CollisionHandler.detectCollision(at: destinationURL)
        
        // Handle with rename policy
        let result = CollisionHandler.handleCollision(
            collision,
            policy: .rename,
            originalDestinationURL: destinationURL,
            originalFileName: "test.jpg"
        )
        
        // Verify result is proceed with renamed URL
        if case .proceed(let renamedURL) = result {
            XCTAssertNotEqual(renamedURL, destinationURL)
            XCTAssertTrue(renamedURL.lastPathComponent.contains("test"))
            XCTAssertTrue(renamedURL.lastPathComponent.contains("(1)"))
        } else {
            XCTFail("Expected proceed with renamed URL")
        }
    }
    
    func testHandleCollisionSkipPolicy() throws {
        // Create an existing file
        let destinationURL = tempDirectory.appendingPathComponent("test.jpg")
        try "existing".write(to: destinationURL, atomically: true, encoding: .utf8)
        
        // Detect collision
        let collision = CollisionHandler.detectCollision(at: destinationURL)
        
        // Handle with skip policy
        let result = CollisionHandler.handleCollision(
            collision,
            policy: .skip,
            originalDestinationURL: destinationURL,
            originalFileName: "test.jpg"
        )
        
        // Verify result is skip
        if case .skip(let reason) = result {
            XCTAssertNotNil(reason)
        } else {
            XCTFail("Expected skip")
        }
    }
    
    func testHandleCollisionErrorPolicy() throws {
        // Create an existing file
        let destinationURL = tempDirectory.appendingPathComponent("test.jpg")
        try "existing".write(to: destinationURL, atomically: true, encoding: .utf8)
        
        // Detect collision
        let collision = CollisionHandler.detectCollision(at: destinationURL)
        
        // Handle with error policy
        let result = CollisionHandler.handleCollision(
            collision,
            policy: .error,
            originalDestinationURL: destinationURL,
            originalFileName: "test.jpg"
        )
        
        // Verify result is error
        if case .error(let error) = result {
            XCTAssertTrue(error is CollisionHandlingError)
        } else {
            XCTFail("Expected error")
        }
    }
    
    func testRenamePolicyGeneratesUniqueNames() throws {
        // Create multiple existing files
        let baseURL = tempDirectory.appendingPathComponent("test.jpg")
        try "existing1".write(to: baseURL, atomically: true, encoding: .utf8)
        
        let renamed1 = tempDirectory.appendingPathComponent("test (1).jpg")
        try "existing2".write(to: renamed1, atomically: true, encoding: .utf8)
        
        // Generate unique filename
        let existingPaths = Set([baseURL, renamed1])
        let uniqueURL = CollisionHandler.generateUniqueFilename(
            for: baseURL,
            avoiding: existingPaths
        )
        
        // Verify unique URL is generated
        XCTAssertNotNil(uniqueURL)
        XCTAssertEqual(uniqueURL?.lastPathComponent, "test (2).jpg")
    }
}
