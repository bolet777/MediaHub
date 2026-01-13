//
//  DestinationMappingTests.swift
//  MediaHubTests
//
//  Tests for destination path mapping (Year/Month organization)
//

import XCTest
@testable import MediaHub

final class DestinationMappingTests: XCTestCase {
    var libraryRootURL: URL!
    
    override func setUp() {
        super.setUp()
        libraryRootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: libraryRootURL, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: libraryRootURL)
        super.tearDown()
    }
    
    func testGenerateYearMonthPath() {
        // Test January 2024 (1704067200 is actually 2023-12-31, use 1704153600 for 2024-01-01)
        let date1 = Date(timeIntervalSince1970: 1704153600) // 2024-01-01 00:00:00 UTC
        let path1 = DestinationMapper.generateYearMonthPath(from: date1)
        XCTAssertEqual(path1, "2024/01")
        
        // Test November 2024
        let date2 = Date(timeIntervalSince1970: 1733011200) // 2024-11-30
        let path2 = DestinationMapper.generateYearMonthPath(from: date2)
        XCTAssertEqual(path2, "2024/11")
        
        // Test December 2024
        let date3 = Date(timeIntervalSince1970: 1735689600) // 2024-12-31
        let path3 = DestinationMapper.generateYearMonthPath(from: date3)
        XCTAssertEqual(path3, "2024/12")
    }
    
    func testMapDestination() throws {
        // Create a candidate item
        let candidate = CandidateMediaItem(
            path: "/test/path/IMG_1234.jpg",
            size: 1024,
            modificationDate: "2024-01-12T10:30:00Z",
            fileName: "IMG_1234.jpg"
        )
        
        // Create timestamp (January 2024)
        let timestamp = Date(timeIntervalSince1970: 1705066200) // 2024-01-12 10:30:00
        
        // Map destination
        let result = try DestinationMapper.mapDestination(
            for: candidate,
            timestamp: timestamp,
            libraryRootURL: libraryRootURL
        )
        
        // Verify result
        XCTAssertEqual(result.yearMonthPath, "2024/01")
        XCTAssertEqual(result.relativePath, "2024/01/IMG_1234.jpg")
        XCTAssertEqual(result.destinationURL.lastPathComponent, "IMG_1234.jpg")
    }
    
    func testMapDestinationDeterminism() throws {
        // Create a candidate item
        let candidate = CandidateMediaItem(
            path: "/test/path/IMG_1234.jpg",
            size: 1024,
            modificationDate: "2026-01-12T10:30:00Z",
            fileName: "IMG_1234.jpg"
        )
        
        // Create timestamp
        let timestamp = Date(timeIntervalSince1970: 1705066200)
        
        // Map destination multiple times
        let result1 = try DestinationMapper.mapDestination(
            for: candidate,
            timestamp: timestamp,
            libraryRootURL: libraryRootURL
        )
        let result2 = try DestinationMapper.mapDestination(
            for: candidate,
            timestamp: timestamp,
            libraryRootURL: libraryRootURL
        )
        
        // Verify results are identical (deterministic)
        XCTAssertEqual(result1.relativePath, result2.relativePath)
        XCTAssertEqual(result1.yearMonthPath, result2.yearMonthPath)
    }
    
    func testSanitizeFileName() {
        // Test normal filename
        let normal = DestinationMapper.sanitizeFileName("IMG_1234.jpg")
        XCTAssertEqual(normal, "IMG_1234.jpg")
        
        // Test filename with invalid characters
        let withSlash = DestinationMapper.sanitizeFileName("IMG/1234.jpg")
        XCTAssertEqual(withSlash, "IMG_1234.jpg")
        
        // Test empty filename
        let empty = DestinationMapper.sanitizeFileName("")
        XCTAssertEqual(empty, "unnamed")
    }
    
    func testPathExists() {
        // Create a test file
        let testFile = libraryRootURL.appendingPathComponent("test.jpg")
        try? "test".write(to: testFile, atomically: true, encoding: .utf8)
        
        // Check if path exists
        XCTAssertTrue(DestinationMapper.pathExists(at: testFile))
        
        // Check non-existent path
        let nonExistent = libraryRootURL.appendingPathComponent("nonexistent.jpg")
        XCTAssertFalse(DestinationMapper.pathExists(at: nonExistent))
    }
}
