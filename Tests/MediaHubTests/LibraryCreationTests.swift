//
//  LibraryCreationTests.swift
//  MediaHubTests
//
//  Tests for library creation workflows (P1)
//

import XCTest
@testable import MediaHub

final class LibraryCreationTests: XCTestCase {
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        // Create a temporary directory for each test
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MediaHubTests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
    }
    
    override func tearDown() {
        // Clean up temporary directory
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        super.tearDown()
    }
    
    // MARK: - Scenario 1: Create Library in Empty Folder
    
    func testCreateLibraryInEmptyFolder() throws {
        // Given: An empty directory exists
        let libraryPath = tempDirectory.appendingPathComponent("TestLibrary").path
        
        // When: A user creates a new MediaHub library at that location
        let creator = LibraryCreator()
        let expectation = XCTestExpectation(description: "Library creation completes")
        var result: Result<LibraryMetadata, LibraryCreationError>?
        
        creator.createLibrary(at: libraryPath) { creationResult in
            result = creationResult
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Then: The library structure is created and can be opened
        guard case .success(let metadata) = result else {
            XCTFail("Library creation should succeed")
            return
        }
        
        // Verify library structure
        let libraryRootURL = URL(fileURLWithPath: libraryPath)
        XCTAssertTrue(
            LibraryStructureValidator.isLibraryStructure(at: libraryRootURL),
            "Library structure should be valid"
        )
        
        // Verify metadata file exists
        let metadataFileURL = LibraryStructureCreator.metadataFileURL(for: libraryRootURL)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: metadataFileURL.path),
            "Metadata file should exist"
        )
        
        // Verify metadata content
        XCTAssertTrue(
            LibraryIdentifierGenerator.isValid(metadata.libraryId),
            "Library identifier should be a valid UUID"
        )
        
        // Verify timestamp is valid ISO-8601
        let formatter = ISO8601DateFormatter()
        XCTAssertNotNil(
            formatter.date(from: metadata.createdAt),
            "Created timestamp should be valid ISO-8601"
        )
        
        // Verify library can be opened
        let opener = LibraryOpener()
        let openedLibrary = try opener.openLibrary(at: libraryPath)
        XCTAssertEqual(
            openedLibrary.metadata.libraryId,
            metadata.libraryId,
            "Opened library should have same identifier"
        )
    }
    
    // MARK: - Scenario 5: Prevent Creating Inside Existing Library
    
    func testPreventCreatingInsideExistingLibrary() throws {
        // Given: A MediaHub library already exists at a location
        let libraryPath = tempDirectory.appendingPathComponent("ExistingLibrary").path
        let creator = LibraryCreator()
        
        // Create first library
        let firstExpectation = XCTestExpectation(description: "First library creation")
        var firstResult: Result<LibraryMetadata, LibraryCreationError>?
        
        creator.createLibrary(at: libraryPath) { result in
            firstResult = result
            firstExpectation.fulfill()
        }
        
        wait(for: [firstExpectation], timeout: 5.0)
        
        guard case .success = firstResult else {
            XCTFail("First library creation should succeed")
            return
        }
        
        // When: A user attempts to create a new library at that location
        let secondExpectation = XCTestExpectation(description: "Second library creation attempt")
        var secondResult: Result<LibraryMetadata, LibraryCreationError>?
        
        creator.createLibrary(at: libraryPath) { result in
            secondResult = result
            secondExpectation.fulfill()
        }
        
        wait(for: [secondExpectation], timeout: 5.0)
        
        // Then: The system detects the existing library and offers to open/attach it
        guard case .failure(let error) = secondResult else {
            XCTFail("Creating library inside existing library should fail")
            return
        }
        
        // Verify error is appropriate
        switch error {
        case .existingLibraryFound, .userCancelled:
            break // Expected error types
        default:
            XCTFail("Error should indicate existing library found or user cancelled, got: \(error)")
        }
        
        // Verify no duplicate structure was created
        // Read metadata to verify it's still the original
        let originalMetadata = try LibraryMetadataReader.readMetadata(from: libraryPath)
        guard case .success(let firstMetadata) = firstResult else {
            XCTFail("Should have first metadata")
            return
        }
        
        XCTAssertEqual(
            originalMetadata.libraryId,
            firstMetadata.libraryId,
            "Library identifier should remain unchanged"
        )
    }
    
    // MARK: - Additional Creation Tests
    
    func testCreateLibraryInNonEmptyDirectoryWithConfirmation() throws {
        // Given: A non-empty directory exists
        let libraryPath = tempDirectory.appendingPathComponent("NonEmptyLibrary").path
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: libraryPath),
            withIntermediateDirectories: true
        )
        
        // Add a file to make it non-empty
        let testFileURL = URL(fileURLWithPath: libraryPath).appendingPathComponent("test.txt")
        try "test content".write(to: testFileURL, atomically: true, encoding: .utf8)
        
        // When: User confirms creation in non-empty directory
        let confirmationHandler = TestConfirmationHandler(shouldConfirm: true)
        let creator = LibraryCreator(confirmationHandler: confirmationHandler)
        
        let expectation = XCTestExpectation(description: "Library creation in non-empty directory")
        var result: Result<LibraryMetadata, LibraryCreationError>?
        
        creator.createLibrary(at: libraryPath) { creationResult in
            result = creationResult
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Then: Library is created successfully
        guard case .success = result else {
            XCTFail("Library creation should succeed with confirmation")
            return
        }
        
        // Verify library structure exists
        let libraryRootURL = URL(fileURLWithPath: libraryPath)
        XCTAssertTrue(
            LibraryStructureValidator.isLibraryStructure(at: libraryRootURL),
            "Library structure should be created"
        )
        
        // Verify original file still exists
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: testFileURL.path),
            "Original file should still exist"
        )
    }
    
    func testCreateLibraryInNonEmptyDirectoryWithoutConfirmation() throws {
        // Given: A non-empty directory exists
        let libraryPath = tempDirectory.appendingPathComponent("NonEmptyLibrary2").path
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: libraryPath),
            withIntermediateDirectories: true
        )
        
        // Add a file to make it non-empty
        let testFileURL = URL(fileURLWithPath: libraryPath).appendingPathComponent("test.txt")
        try "test content".write(to: testFileURL, atomically: true, encoding: .utf8)
        
        // When: User cancels creation in non-empty directory
        let confirmationHandler = TestConfirmationHandler(shouldConfirm: false)
        let creator = LibraryCreator(confirmationHandler: confirmationHandler)
        
        let expectation = XCTestExpectation(description: "Library creation cancelled")
        var result: Result<LibraryMetadata, LibraryCreationError>?
        
        creator.createLibrary(at: libraryPath) { creationResult in
            result = creationResult
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Then: Creation is cancelled
        guard case .failure(let error) = result else {
            XCTFail("Library creation should be cancelled")
            return
        }
        
        // Verify error is user cancelled
        switch error {
        case .userCancelled:
            break // Expected error type
        default:
            XCTFail("Error should indicate user cancelled, got: \(error)")
        }
        
        // Verify library structure was NOT created
        let libraryRootURL = URL(fileURLWithPath: libraryPath)
        XCTAssertFalse(
            LibraryStructureValidator.isLibraryStructure(at: libraryRootURL),
            "Library structure should NOT be created"
        )
    }
    
    func testCreateLibraryInNonExistentDirectory() throws {
        // Given: A path that doesn't exist (but parent exists)
        // Create parent directory first
        let parentURL = tempDirectory.appendingPathComponent("NewDirectory")
        try FileManager.default.createDirectory(
            at: parentURL,
            withIntermediateDirectories: true
        )
        
        let libraryPath = parentURL
            .appendingPathComponent("TestLibrary")
            .path
        
        // When: User creates library at non-existent path
        let creator = LibraryCreator()
        let expectation = XCTestExpectation(description: "Library creation at new path")
        var result: Result<LibraryMetadata, LibraryCreationError>?
        
        creator.createLibrary(at: libraryPath) { creationResult in
            result = creationResult
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Then: Library is created successfully
        guard case .success(let metadata) = result else {
            XCTFail("Library creation should succeed for non-existent path")
            return
        }
        
        // Verify library structure exists
        let libraryRootURL = URL(fileURLWithPath: libraryPath)
        XCTAssertTrue(
            LibraryStructureValidator.isLibraryStructure(at: libraryRootURL),
            "Library structure should be created"
        )
        
        XCTAssertEqual(
            metadata.rootPath,
            libraryPath,
            "Metadata should contain correct root path"
        )
    }
}

// MARK: - Test Helpers

private class TestConfirmationHandler: LibraryCreationConfirmationHandler {
    let shouldConfirm: Bool
    
    init(shouldConfirm: Bool) {
        self.shouldConfirm = shouldConfirm
    }
    
    func requestConfirmationForNonEmptyDirectory(
        at path: String,
        completion: @escaping (Bool) -> Void
    ) {
        completion(shouldConfirm)
    }
    
    func requestConfirmationForExistingLibrary(
        at path: String,
        completion: @escaping (Bool) -> Void
    ) {
        completion(shouldConfirm)
    }
}
