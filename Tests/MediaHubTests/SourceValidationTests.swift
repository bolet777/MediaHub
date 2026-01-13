//
//  SourceValidationTests.swift
//  MediaHubTests
//
//  Tests for Source validation and accessibility
//

import XCTest
@testable import MediaHub

final class SourceValidationTests: XCTestCase {
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    func testValidatePathExists() {
        let existingPath = tempDirectory.path
        let result = SourceValidator.validatePathExists(existingPath)
        
        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.errors.isEmpty)
    }
    
    func testValidatePathNotExists() {
        let nonExistentPath = "/nonexistent/path/\(UUID().uuidString)"
        let result = SourceValidator.validatePathExists(nonExistentPath)
        
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errors.count, 1)
        if case .pathNotFound(let path) = result.errors[0] {
            XCTAssertEqual(path, nonExistentPath)
        } else {
            XCTFail("Expected pathNotFound error")
        }
    }
    
    func testValidateReadPermissions() {
        let readablePath = tempDirectory.path
        let result = SourceValidator.validateReadPermissions(readablePath)
        
        XCTAssertTrue(result.isValid)
    }
    
    func testValidateSourceType() {
        let folderResult = SourceValidator.validateSourceType(.folder)
        XCTAssertTrue(folderResult.isValid)
        
        // Note: Only .folder is supported in P1, so other types would fail
        // but we don't have other types defined yet
    }
    
    func testValidateIsDirectory() {
        let directoryPath = tempDirectory.path
        let result = SourceValidator.validateIsDirectory(directoryPath)
        
        XCTAssertTrue(result.isValid)
    }
    
    func testValidateIsDirectoryWithFile() throws {
        let fileURL = tempDirectory.appendingPathComponent("test.txt")
        try "test".write(to: fileURL, atomically: true, encoding: .utf8)
        
        let result = SourceValidator.validateIsDirectory(fileURL.path)
        
        XCTAssertFalse(result.isValid)
        if case .notADirectory(let path) = result.errors[0] {
            XCTAssertEqual(path, fileURL.path)
        } else {
            XCTFail("Expected notADirectory error")
        }
    }
    
    func testValidateBeforeAttachment() throws {
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: tempDirectory.path
        )
        
        let result = SourceValidator.validateBeforeAttachment(
            source: source,
            type: .folder
        )
        
        XCTAssertTrue(result.isValid)
    }
    
    func testValidateBeforeAttachmentInvalidPath() {
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: "/nonexistent/path"
        )
        
        let result = SourceValidator.validateBeforeAttachment(
            source: source,
            type: .folder
        )
        
        XCTAssertFalse(result.isValid)
    }
    
    func testValidateDuringDetection() throws {
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: tempDirectory.path
        )
        
        let result = SourceValidator.validateDuringDetection(source)
        
        XCTAssertTrue(result.isValid)
    }
    
    func testValidateDuringDetectionInaccessible() {
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: "/nonexistent/path"
        )
        
        let result = SourceValidator.validateDuringDetection(source)
        
        XCTAssertFalse(result.isValid)
    }
    
    func testGenerateErrorMessage() {
        let errors: [SourceValidationError] = [
            .pathNotFound("/test/path"),
            .permissionDenied("/test/path")
        ]
        
        let message = SourceValidator.generateErrorMessage(from: errors)
        
        XCTAssertFalse(message.isEmpty)
        XCTAssertTrue(message.contains("path"))
    }
}
