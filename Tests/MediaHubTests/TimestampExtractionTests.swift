//
//  TimestampExtractionTests.swift
//  MediaHubTests
//
//  Tests for timestamp extraction (EXIF DateTimeOriginal → mtime fallback)
//

import XCTest
@testable import MediaHub

final class TimestampExtractionTests: XCTestCase {
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
    
    func testExtractModificationDate() throws {
        // Create a test file
        let testFile = tempDirectory.appendingPathComponent("test.jpg")
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)
        
        // Extract modification date
        let result = try TimestampExtractor.extractModificationDate(from: testFile.path)
        
        // Verify result is a valid date
        XCTAssertNotNil(result)
        XCTAssertTrue(result <= Date())
    }
    
    func testExtractTimestampFallsBackToModificationDate() throws {
        // Create a test file without EXIF
        let testFile = tempDirectory.appendingPathComponent("test.txt")
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)
        
        // Extract timestamp (should fallback to mtime)
        let result = try TimestampExtractor.extractTimestamp(from: testFile.path)
        
        // Verify result uses filesystem modification date
        XCTAssertEqual(result.source, .filesystemModificationDate)
        XCTAssertNotNil(result.date)
    }
    
    func testExtractTimestampDeterminism() throws {
        // Create a test file
        let testFile = tempDirectory.appendingPathComponent("test.jpg")
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)
        
        // Extract timestamp multiple times
        let result1 = try TimestampExtractor.extractTimestamp(from: testFile.path)
        let result2 = try TimestampExtractor.extractTimestamp(from: testFile.path)
        
        // Verify results are identical (deterministic)
        XCTAssertEqual(result1.date, result2.date)
        XCTAssertEqual(result1.source, result2.source)
    }
    
    func testExtractTimestampFromNonExistentFile() {
        // Try to extract from non-existent file
        let nonExistentFile = tempDirectory.appendingPathComponent("nonexistent.jpg")
        
        XCTAssertThrowsError(try TimestampExtractor.extractTimestamp(from: nonExistentFile.path)) { error in
            XCTAssertTrue(error is TimestampExtractionError)
        }
    }
}
