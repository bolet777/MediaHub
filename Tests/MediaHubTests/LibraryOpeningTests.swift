//
//  LibraryOpeningTests.swift
//  MediaHubTests
//
//  Tests for library opening and attachment workflows (P1)
//

import XCTest
@testable import MediaHub

final class LibraryOpeningTests: XCTestCase {
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
    
    // MARK: - Scenario 2: Attach/Open Existing Library by Path
    
    func testOpenExistingLibraryByPath() throws {
        // Given: A MediaHub library exists on disk
        let libraryPath = tempDirectory.appendingPathComponent("TestLibrary").path
        let creator = LibraryCreator()
        
        let createExpectation = XCTestExpectation(description: "Library creation")
        var createResult: Result<LibraryMetadata, LibraryCreationError>?
        
        creator.createLibrary(at: libraryPath) { result in
            createResult = result
            createExpectation.fulfill()
        }
        
        wait(for: [createExpectation], timeout: 5.0)
        
        guard case .success(let createdMetadata) = createResult else {
            XCTFail("Library creation should succeed")
            return
        }
        
        // When: A user opens the library by specifying its path
        let opener = LibraryOpener()
        let openedLibrary = try opener.openLibrary(at: libraryPath)
        
        // Then: The library is recognized and opened successfully
        XCTAssertEqual(
            openedLibrary.metadata.libraryId,
            createdMetadata.libraryId,
            "Opened library should have same identifier as created library"
        )
        
        XCTAssertEqual(
            openedLibrary.rootURL.path,
            libraryPath,
            "Opened library should have correct root path"
        )
        
        XCTAssertFalse(
            openedLibrary.isLegacy,
            "Newly created library should not be legacy"
        )
        
        // Verify library is set as active
        let activeLibrary = opener.getActiveLibraryManager().getActive()
        XCTAssertNotNil(
            activeLibrary,
            "Active library should be set"
        )
        
        XCTAssertEqual(
            activeLibrary?.metadata.libraryId,
            createdMetadata.libraryId,
            "Active library should match opened library"
        )
        
        // Verify library can be used for subsequent operations
        let validationResult = LibraryValidator.validate(at: libraryPath)
        guard case .valid = validationResult else {
            XCTFail("Opened library should be valid")
            return
        }
    }
    
    func testOpenLibraryByIdentifier() throws {
        // Given: A MediaHub library exists on disk
        let libraryPath = tempDirectory.appendingPathComponent("TestLibrary").path
        let creator = LibraryCreator()
        
        let createExpectation = XCTestExpectation(description: "Library creation")
        var createResult: Result<LibraryMetadata, LibraryCreationError>?
        
        creator.createLibrary(at: libraryPath) { result in
            createResult = result
            createExpectation.fulfill()
        }
        
        wait(for: [createExpectation], timeout: 5.0)
        
        guard case .success(let createdMetadata) = createResult else {
            XCTFail("Library creation should succeed")
            return
        }
        
        // Open library by path first to register it
        let opener = LibraryOpener()
        _ = try opener.openLibrary(at: libraryPath)
        
        // When: User opens library by identifier
        let openedLibrary = try opener.openLibrary(identifier: createdMetadata.libraryId)
        
        // Then: Library is opened successfully
        XCTAssertEqual(
            openedLibrary.metadata.libraryId,
            createdMetadata.libraryId,
            "Opened library should have same identifier"
        )
        
        XCTAssertEqual(
            openedLibrary.rootURL.path,
            libraryPath,
            "Opened library should have correct root path"
        )
    }
    
    func testOpenLibraryByIdentifierNotFound() throws {
        // Given: A library identifier that doesn't exist
        let nonExistentId = LibraryIdentifierGenerator.generate()
        
        // When: User attempts to open library by identifier
        let opener = LibraryOpener()
        
        // Then: Error is thrown
        XCTAssertThrowsError(
            try opener.openLibrary(identifier: nonExistentId),
            "Should throw error for non-existent identifier"
        ) { error in
            guard let openingError = error as? LibraryOpeningError else {
                XCTFail("Error should be LibraryOpeningError")
                return
            }
            
            // Verify error is identifier not found
            switch openingError {
            case .identifierNotFound:
                break // Expected error type
            default:
                XCTFail("Error should indicate identifier not found, got: \(openingError)")
            }
        }
    }
    
    func testLibraryPathDetection() throws {
        // Given: A MediaHub library exists
        let libraryPath = tempDirectory.appendingPathComponent("TestLibrary").path
        let creator = LibraryCreator()
        
        let createExpectation = XCTestExpectation(description: "Library creation")
        var createResult: Result<LibraryMetadata, LibraryCreationError>?
        
        creator.createLibrary(at: libraryPath) { result in
            createResult = result
            createExpectation.fulfill()
        }
        
        wait(for: [createExpectation], timeout: 5.0)
        
        guard case .success = createResult else {
            XCTFail("Library creation should succeed")
            return
        }
        
        // When: Checking if path contains a library
        let isLibrary = LibraryPathDetector.detect(at: libraryPath)
        
        // Then: Library is detected
        XCTAssertTrue(
            isLibrary,
            "Library should be detected at path"
        )
        
        // Verify non-library directory is not detected
        let nonLibraryPath = tempDirectory.appendingPathComponent("NotALibrary").path
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: nonLibraryPath),
            withIntermediateDirectories: true
        )
        
        let isNotLibrary = LibraryPathDetector.detect(at: nonLibraryPath)
        XCTAssertFalse(
            isNotLibrary,
            "Non-library directory should not be detected"
        )
    }
    
    func testOpenLibraryWithInvalidPath() throws {
        // Given: An invalid path (doesn't exist)
        let invalidPath = tempDirectory.appendingPathComponent("NonExistent").path
        
        // When: User attempts to open library at invalid path
        let opener = LibraryOpener()
        
        // Then: Error is thrown
        XCTAssertThrowsError(
            try opener.openLibrary(at: invalidPath),
            "Should throw error for invalid path"
        ) { error in
            guard let openingError = error as? LibraryOpeningError else {
                XCTFail("Error should be LibraryOpeningError")
                return
            }
            
            // Check error type using pattern matching
            switch openingError {
            case .libraryNotFound, .structureInvalid:
                break // Expected error types
            default:
                XCTFail("Error should indicate library not found or invalid structure, got: \(openingError)")
            }
        }
    }
}
