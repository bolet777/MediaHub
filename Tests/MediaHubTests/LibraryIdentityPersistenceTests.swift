//
//  LibraryIdentityPersistenceTests.swift
//  MediaHubTests
//
//  Tests for library identity persistence across moves and renames (P1)
//

import XCTest
@testable import MediaHub

final class LibraryIdentityPersistenceTests: XCTestCase {
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
    
    // MARK: - Scenario 3: Move/Rename Library and Re-open (Identity Persistence)
    
    func testLibraryIdentityPersistsAfterMove() throws {
        // Given: A MediaHub library exists at path A
        let originalPath = tempDirectory.appendingPathComponent("OriginalLibrary").path
        let creator = LibraryCreator()
        
        let createExpectation = XCTestExpectation(description: "Library creation")
        var createResult: Result<LibraryMetadata, LibraryCreationError>?
        
        creator.createLibrary(at: originalPath) { result in
            createResult = result
            createExpectation.fulfill()
        }
        
        wait(for: [createExpectation], timeout: 5.0)
        
        guard case .success(let originalMetadata) = createResult else {
            XCTFail("Library creation should succeed")
            return
        }
        
        let originalIdentifier = originalMetadata.libraryId
        
        // Open library to register it
        let opener = LibraryOpener()
        _ = try opener.openLibrary(at: originalPath)
        
        // When: The library is moved to path B
        let newPath = tempDirectory.appendingPathComponent("MovedLibrary").path
        try FileManager.default.moveItem(
            atPath: originalPath,
            toPath: newPath
        )
        
        // Update registry with new path
        let registry = opener.getActiveLibraryManager().getRegistry()
        registry.register(identifier: originalIdentifier, path: newPath)
        
        // And reopened at new location
        let reopenedLibrary = try opener.openLibrary(at: newPath)
        
        // Then: The library maintains its unique identifier
        XCTAssertEqual(
            reopenedLibrary.metadata.libraryId,
            originalIdentifier,
            "Library identifier should remain unchanged after move"
        )
        
        // Verify identifier-based lookup works
        let locatedPath = LibraryIdentifierLocator(
            registry: registry,
            knownLocations: [newPath]
        ).locate(identifier: originalIdentifier)
        
        XCTAssertEqual(
            locatedPath,
            newPath,
            "Identifier-based lookup should find library at new path"
        )
        
        // Verify identity validation passes
        let isValid = try LibraryIdentityPersistenceValidator.validatePersistence(
            originalPath: originalPath,
            newPath: newPath
        )
        
        XCTAssertTrue(
            isValid,
            "Identity validation should pass after move"
        )
    }
    
    func testLibraryIdentityPersistsAfterRename() throws {
        // Given: A MediaHub library exists
        let originalPath = tempDirectory.appendingPathComponent("OriginalName").path
        let creator = LibraryCreator()
        
        let createExpectation = XCTestExpectation(description: "Library creation")
        var createResult: Result<LibraryMetadata, LibraryCreationError>?
        
        creator.createLibrary(at: originalPath) { result in
            createResult = result
            createExpectation.fulfill()
        }
        
        wait(for: [createExpectation], timeout: 5.0)
        
        guard case .success(let originalMetadata) = createResult else {
            XCTFail("Library creation should succeed")
            return
        }
        
        let originalIdentifier = originalMetadata.libraryId
        
        // Open library to register it
        let opener = LibraryOpener()
        _ = try opener.openLibrary(at: originalPath)
        
        // When: The library directory is renamed
        let renamedPath = tempDirectory.appendingPathComponent("RenamedLibrary").path
        try FileManager.default.moveItem(
            atPath: originalPath,
            toPath: renamedPath
        )
        
        // Update registry with new path
        let registry = opener.getActiveLibraryManager().getRegistry()
        registry.register(identifier: originalIdentifier, path: renamedPath)
        
        // And reopened at new path
        let reopenedLibrary = try opener.openLibrary(at: renamedPath)
        
        // Then: The library maintains its unique identifier
        XCTAssertEqual(
            reopenedLibrary.metadata.libraryId,
            originalIdentifier,
            "Library identifier should remain unchanged after rename"
        )
        
        // Verify library can be opened by identifier
        let libraryByIdentifier = try opener.openLibrary(identifier: originalIdentifier)
        XCTAssertEqual(
            libraryByIdentifier.metadata.libraryId,
            originalIdentifier,
            "Library should be openable by identifier after rename"
        )
    }
    
    func testPathChangeDetection() throws {
        // Given: A library exists
        let libraryPath = tempDirectory.appendingPathComponent("TestLibrary").path
        let creator = LibraryCreator()
        
        let createExpectation = XCTestExpectation(description: "Library creation")
        var createResult: Result<LibraryMetadata, LibraryCreationError>?
        
        creator.createLibrary(at: libraryPath) { result in
            createResult = result
            createExpectation.fulfill()
        }
        
        wait(for: [createExpectation], timeout: 5.0)
        
        guard case .success(let metadata) = createResult else {
            XCTFail("Library creation should succeed")
            return
        }
        
        // When: Library is at correct path
        let pathChanged = LibraryPathChangeDetector.detectPathChange(in: metadata)
        
        // Then: Path change is not detected
        XCTAssertFalse(
            pathChanged,
            "Path change should not be detected when library is at correct path"
        )
        
        // When: Library is moved
        let newPath = tempDirectory.appendingPathComponent("MovedLibrary").path
        try FileManager.default.moveItem(
            atPath: libraryPath,
            toPath: newPath
        )
        
        // Then: Path change is detected (metadata still points to old path)
        let pathChangedAfterMove = LibraryPathChangeDetector.detectPathChange(in: metadata)
        XCTAssertTrue(
            pathChangedAfterMove,
            "Path change should be detected after library is moved"
        )
    }
    
    func testPathMatchesIdentifier() throws {
        // Given: A library exists
        let libraryPath = tempDirectory.appendingPathComponent("TestLibrary").path
        let creator = LibraryCreator()
        
        let createExpectation = XCTestExpectation(description: "Library creation")
        var createResult: Result<LibraryMetadata, LibraryCreationError>?
        
        creator.createLibrary(at: libraryPath) { result in
            createResult = result
            createExpectation.fulfill()
        }
        
        wait(for: [createExpectation], timeout: 5.0)
        
        guard case .success(let metadata) = createResult else {
            XCTFail("Library creation should succeed")
            return
        }
        
        // When: Checking if path matches identifier
        let matches = LibraryPathChangeDetector.pathMatchesIdentifier(
            path: libraryPath,
            identifier: metadata.libraryId
        )
        
        // Then: Path matches identifier
        XCTAssertTrue(
            matches,
            "Path should match identifier for correct library"
        )
        
        // Verify non-matching identifier returns false
        let nonMatchingId = LibraryIdentifierGenerator.generate()
        let doesNotMatch = LibraryPathChangeDetector.pathMatchesIdentifier(
            path: libraryPath,
            identifier: nonMatchingId
        )
        
        XCTAssertFalse(
            doesNotMatch,
            "Path should not match non-matching identifier"
        )
    }
    
    func testRegistryPathUpdate() throws {
        // Given: A library registered in registry
        let libraryPath = tempDirectory.appendingPathComponent("TestLibrary").path
        let creator = LibraryCreator()
        
        let createExpectation = XCTestExpectation(description: "Library creation")
        var createResult: Result<LibraryMetadata, LibraryCreationError>?
        
        creator.createLibrary(at: libraryPath) { result in
            createResult = result
            createExpectation.fulfill()
        }
        
        wait(for: [createExpectation], timeout: 5.0)
        
        guard case .success(let metadata) = createResult else {
            XCTFail("Library creation should succeed")
            return
        }
        
        let opener = LibraryOpener()
        _ = try opener.openLibrary(at: libraryPath)
        let registry = opener.getActiveLibraryManager().getRegistry()
        
        // When: Library path changes
        let newPath = tempDirectory.appendingPathComponent("MovedLibrary").path
        try FileManager.default.moveItem(atPath: libraryPath, toPath: newPath)
        
        LibraryPathReferenceUpdater.updatePath(
            in: registry,
            identifier: metadata.libraryId,
            newPath: newPath
        )
        
        // Then: Registry is updated
        let registeredPath = registry.path(for: metadata.libraryId)
        XCTAssertEqual(
            registeredPath,
            newPath,
            "Registry should contain new path"
        )
        
        let registeredIdentifier = registry.identifier(for: newPath)
        XCTAssertEqual(
            registeredIdentifier,
            metadata.libraryId,
            "Registry should map new path to identifier"
        )
    }
}
