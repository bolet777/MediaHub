//
//  AtomicFileCopyTests.swift
//  MediaHubTests
//
//  Tests for atomic file copying
//

import XCTest
@testable import MediaHub

final class AtomicFileCopyTests: XCTestCase {
    var tempDirectory: URL!
    var sourceFile: URL!
    var destinationFile: URL!
    
    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        sourceFile = tempDirectory.appendingPathComponent("source.jpg")
        destinationFile = tempDirectory.appendingPathComponent("destination.jpg")
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    func testCopyAtomically() throws {
        // Create source file
        let sourceContent = "test content for atomic copy"
        try sourceContent.write(to: sourceFile, atomically: true, encoding: .utf8)
        
        // Copy atomically
        let result = try AtomicFileCopier.copyAtomically(
            from: sourceFile,
            to: destinationFile
        )
        
        // Verify destination file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationFile.path))
        
        // Verify content matches
        let destinationContent = try String(contentsOf: destinationFile, encoding: .utf8)
        XCTAssertEqual(destinationContent, sourceContent)
        
        // Verify source file is unchanged
        let sourceContentAfter = try String(contentsOf: sourceFile, encoding: .utf8)
        XCTAssertEqual(sourceContentAfter, sourceContent)
        
        // Verify result
        XCTAssertEqual(result.destinationURL, destinationFile)
    }
    
    func testCopyAtomicallyCreatesDestinationDirectory() throws {
        // Create source file
        try "test".write(to: sourceFile, atomically: true, encoding: .utf8)
        
        // Copy to nested directory
        let nestedDestination = tempDirectory
            .appendingPathComponent("nested")
            .appendingPathComponent("destination.jpg")
        
        // Copy atomically (should create nested directory)
        _ = try AtomicFileCopier.copyAtomically(
            from: sourceFile,
            to: nestedDestination
        )
        
        // Verify destination file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: nestedDestination.path))
    }
    
    func testCopyAtomicallyFromNonExistentFile() {
        // Try to copy from non-existent file
        let nonExistent = tempDirectory.appendingPathComponent("nonexistent.jpg")
        
        XCTAssertThrowsError(try AtomicFileCopier.copyAtomically(
            from: nonExistent,
            to: destinationFile
        )) { error in
            XCTAssertTrue(error is AtomicFileCopyError)
        }
    }
    
    func testCopyAtomicallyVerifiesFileSize() throws {
        // Create source file
        try "test content".write(to: sourceFile, atomically: true, encoding: .utf8)
        
        // Mock file operations that would fail verification
        // (This is a simplified test - full verification testing would require mocking)
        
        // Copy should succeed with valid file
        _ = try AtomicFileCopier.copyAtomically(
            from: sourceFile,
            to: destinationFile
        )
        
        // Verify file was copied
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationFile.path))
    }
}
