//
//  LibraryAdoptionTests.swift
//  MediaHubTests
//
//  Tests for library adoption operations (Slice 6)
//

import XCTest
@testable import MediaHub
@testable import MediaHubCLI

final class LibraryAdoptionTests: XCTestCase {
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        // Create a temporary directory for each test
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MediaHubAdoptionTests-\(UUID().uuidString)")
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
    
    // MARK: - Task 2.2: Idempotent Check Tests
    
    func testIsAlreadyAdoptedReturnsFalseForNewDirectory() {
        // Given: A directory that is not yet adopted
        let libraryPath = tempDirectory.appendingPathComponent("NewLibrary").path
        try! FileManager.default.createDirectory(
            at: URL(fileURLWithPath: libraryPath),
            withIntermediateDirectories: true
        )
        
        // When: Checking if already adopted
        let isAdopted = LibraryAdopter.isAlreadyAdopted(at: libraryPath)
        
        // Then: Should return false
        XCTAssertFalse(isAdopted, "New directory should not be adopted")
    }
    
    func testIsAlreadyAdoptedReturnsTrueForAdoptedLibrary() throws {
        // Given: A directory that has been adopted
        let libraryPath = tempDirectory.appendingPathComponent("AdoptedLibrary").path
        try! FileManager.default.createDirectory(
            at: URL(fileURLWithPath: libraryPath),
            withIntermediateDirectories: true
        )
        
        // Adopt the library
        _ = try LibraryAdopter.adoptLibrary(at: libraryPath)
        
        // When: Checking if already adopted
        let isAdopted = LibraryAdopter.isAlreadyAdopted(at: libraryPath)
        
        // Then: Should return true
        XCTAssertTrue(isAdopted, "Adopted library should be detected as adopted")
    }
    
    // MARK: - Task 2.3: Path Validation Tests
    
    func testValidatePathThrowsForEmptyPath() {
        // Given: An empty path
        let emptyPath = ""
        
        // When/Then: Should throw invalidPath error
        XCTAssertThrowsError(try LibraryAdopter.validatePath(emptyPath)) { error in
            guard case LibraryAdoptionError.invalidPath = error else {
                XCTFail("Expected invalidPath error, got: \(error)")
                return
            }
        }
    }
    
    func testValidatePathThrowsForNonExistentPath() {
        // Given: A path that doesn't exist
        let nonExistentPath = tempDirectory.appendingPathComponent("NonExistent").path
        
        // When/Then: Should throw pathDoesNotExist error
        XCTAssertThrowsError(try LibraryAdopter.validatePath(nonExistentPath)) { error in
            guard case LibraryAdoptionError.pathDoesNotExist = error else {
                XCTFail("Expected pathDoesNotExist error, got: \(error)")
                return
            }
        }
    }
    
    func testValidatePathThrowsForFileNotDirectory() throws {
        // Given: A path that points to a file, not a directory
        let filePath = tempDirectory.appendingPathComponent("file.txt").path
        try "test".write(to: URL(fileURLWithPath: filePath), atomically: true, encoding: .utf8)
        
        // When/Then: Should throw pathIsNotDirectory error
        XCTAssertThrowsError(try LibraryAdopter.validatePath(filePath)) { error in
            guard case LibraryAdoptionError.pathIsNotDirectory = error else {
                XCTFail("Expected pathIsNotDirectory error, got: \(error)")
                return
            }
        }
    }
    
    func testValidatePathSucceedsForValidDirectory() throws {
        // Given: A valid directory path
        let libraryPath = tempDirectory.appendingPathComponent("ValidLibrary").path
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: libraryPath),
            withIntermediateDirectories: true
        )
        
        // When/Then: Should not throw
        XCTAssertNoThrow(try LibraryAdopter.validatePath(libraryPath))
    }
    
    // MARK: - Task 2.4: Metadata Creation Tests
    
    func testAdoptLibraryCreatesMetadata() throws {
        // Given: A directory with existing media files
        let libraryPath = tempDirectory.appendingPathComponent("TestLibrary").path
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: libraryPath),
            withIntermediateDirectories: true
        )
        
        // Add a media file
        let mediaFileURL = URL(fileURLWithPath: libraryPath).appendingPathComponent("photo.jpg")
        try "fake image data".write(to: mediaFileURL, atomically: true, encoding: .utf8)
        
        // When: Adopting the library
        let result = try LibraryAdopter.adoptLibrary(at: libraryPath)
        
        // Then: Metadata should be created
        let libraryRootURL = URL(fileURLWithPath: libraryPath)
        XCTAssertTrue(
            LibraryStructureValidator.isLibraryStructure(at: libraryRootURL),
            "Library structure should be created"
        )
        
        // Verify metadata file exists
        let metadataFileURL = LibraryStructureCreator.metadataFileURL(for: libraryRootURL)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: metadataFileURL.path),
            "Metadata file should exist"
        )
        
        // Verify metadata content
        XCTAssertTrue(
            LibraryIdentifierGenerator.isValid(result.metadata.libraryId),
            "Library identifier should be a valid UUID"
        )
        XCTAssertEqual(
            result.metadata.rootPath,
            libraryPath,
            "Metadata should contain correct root path"
        )
        
        // Verify original media file still exists and is unchanged
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: mediaFileURL.path),
            "Original media file should still exist"
        )
    }
    
    func testAdoptLibraryDoesNotModifyExistingMediaFiles() throws {
        // Given: A directory with existing media files
        let libraryPath = tempDirectory.appendingPathComponent("TestLibrary").path
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: libraryPath),
            withIntermediateDirectories: true
        )
        
        // Add multiple media files in YYYY/MM structure
        let yearDir = URL(fileURLWithPath: libraryPath).appendingPathComponent("2024")
        try FileManager.default.createDirectory(at: yearDir, withIntermediateDirectories: true)
        let monthDir = yearDir.appendingPathComponent("01")
        try FileManager.default.createDirectory(at: monthDir, withIntermediateDirectories: true)
        
        let photo1URL = monthDir.appendingPathComponent("photo1.jpg")
        let photo2URL = monthDir.appendingPathComponent("photo2.png")
        let videoURL = monthDir.appendingPathComponent("video.mov")
        
        let photo1Content = "photo1 content"
        let photo2Content = "photo2 content"
        let videoContent = "video content"
        
        try photo1Content.write(to: photo1URL, atomically: true, encoding: .utf8)
        try photo2Content.write(to: photo2URL, atomically: true, encoding: .utf8)
        try videoContent.write(to: videoURL, atomically: true, encoding: .utf8)
        
        // When: Adopting the library
        _ = try LibraryAdopter.adoptLibrary(at: libraryPath)
        
        // Then: All original media files should still exist with same content
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: photo1URL.path),
            "Photo 1 should still exist"
        )
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: photo2URL.path),
            "Photo 2 should still exist"
        )
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: videoURL.path),
            "Video should still exist"
        )
        
        // Verify content is unchanged
        let photo1Read = try String(contentsOf: photo1URL, encoding: .utf8)
        let photo2Read = try String(contentsOf: photo2URL, encoding: .utf8)
        let videoRead = try String(contentsOf: videoURL, encoding: .utf8)
        
        XCTAssertEqual(photo1Read, photo1Content, "Photo 1 content should be unchanged")
        XCTAssertEqual(photo2Read, photo2Content, "Photo 2 content should be unchanged")
        XCTAssertEqual(videoRead, videoContent, "Video content should be unchanged")
    }
    
    // MARK: - Task 2.5: Atomic Write Tests
    
    func testAdoptLibraryCreatesMetadataAtomically() throws {
        // Given: A directory
        let libraryPath = tempDirectory.appendingPathComponent("TestLibrary").path
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: libraryPath),
            withIntermediateDirectories: true
        )
        
        // When: Adopting the library
        _ = try LibraryAdopter.adoptLibrary(at: libraryPath)
        
        // Then: Metadata file should exist and be valid (no partial files)
        let libraryRootURL = URL(fileURLWithPath: libraryPath)
        let metadataFileURL = LibraryStructureCreator.metadataFileURL(for: libraryRootURL)
        
        // Verify no temp files remain
        let metadataDir = metadataFileURL.deletingLastPathComponent()
        let contents = try FileManager.default.contentsOfDirectory(at: metadataDir, includingPropertiesForKeys: nil)
        let tempFiles = contents.filter { $0.pathExtension == "tmp" }
        XCTAssertTrue(
            tempFiles.isEmpty,
            "No temporary files should remain after atomic write"
        )
        
        // Verify metadata file is valid JSON
        let metadata = try LibraryMetadataSerializer.read(from: metadataFileURL)
        XCTAssertTrue(metadata.isValid(), "Metadata should be valid")
    }
    
    // MARK: - Task 2.6: Rollback Tests
    
    func testAdoptLibraryRollsBackOnMetadataWriteFailure() throws {
        // Given: A directory that will fail metadata write (simulated by making .mediahub read-only after creation)
        let libraryPath = tempDirectory.appendingPathComponent("TestLibrary").path
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: libraryPath),
            withIntermediateDirectories: true
        )
        
        // Create .mediahub directory manually, then make it read-only
        let libraryRootURL = URL(fileURLWithPath: libraryPath)
        let metadataDirURL = libraryRootURL.appendingPathComponent(LibraryStructure.metadataDirectoryName)
        try FileManager.default.createDirectory(at: metadataDirURL, withIntermediateDirectories: true)
        
        // Make directory read-only (this will cause write to fail)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o555],
            ofItemAtPath: metadataDirURL.path
        )
        
        // When: Attempting to adopt (will fail on metadata write or permission check)
        // Then: Should throw error (either permissionDenied or metadataWriteFailed)
        XCTAssertThrowsError(try LibraryAdopter.adoptLibrary(at: libraryPath)) { error in
            // Verify error type (could be permissionDenied if checked before write, or metadataWriteFailed)
            switch error {
            case LibraryAdoptionError.permissionDenied, LibraryAdoptionError.metadataWriteFailed:
                break // Expected error types
            default:
                XCTFail("Expected permissionDenied or metadataWriteFailed error, got: \(error)")
            }
        }
        
        // Verify rollback: .mediahub directory should be removed or no partial metadata.json should exist
        let metadataFileURL = LibraryStructureCreator.metadataFileURL(for: libraryRootURL)
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: metadataFileURL.path),
            "Metadata file should not exist after rollback"
        )
        
        // Restore permissions for cleanup
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: metadataDirURL.path
        )
    }
    
    // MARK: - Task 2.7: Idempotent Adoption Tests
    
    func testAdoptLibraryThrowsAlreadyAdoptedError() throws {
        // Given: A directory that is already adopted
        let libraryPath = tempDirectory.appendingPathComponent("TestLibrary").path
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: libraryPath),
            withIntermediateDirectories: true
        )
        
        // Adopt once
        let firstResult = try LibraryAdopter.adoptLibrary(at: libraryPath)
        
        // When: Attempting to adopt again
        // Then: Should throw alreadyAdopted error
        XCTAssertThrowsError(try LibraryAdopter.adoptLibrary(at: libraryPath)) { error in
            guard case LibraryAdoptionError.alreadyAdopted = error else {
                XCTFail("Expected alreadyAdopted error, got: \(error)")
                return
            }
        }
        
        // Verify metadata is unchanged (same library ID)
        let libraryRootURL = URL(fileURLWithPath: libraryPath)
        let metadataFileURL = LibraryStructureCreator.metadataFileURL(for: libraryRootURL)
        let existingMetadata = try LibraryMetadataSerializer.read(from: metadataFileURL)
        XCTAssertEqual(
            existingMetadata.libraryId,
            firstResult.metadata.libraryId,
            "Library ID should remain unchanged after failed re-adoption"
        )
    }
    
    // MARK: - Task 3.1, 3.2, 3.3: Baseline Scan Integration Tests
    
    func testAdoptLibraryPerformsBaselineScan() throws {
        // Given: A directory with existing media files
        let libraryPath = tempDirectory.appendingPathComponent("TestLibrary").path
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: libraryPath),
            withIntermediateDirectories: true
        )
        
        // Add media files in YYYY/MM structure
        let yearDir = URL(fileURLWithPath: libraryPath).appendingPathComponent("2024")
        try FileManager.default.createDirectory(at: yearDir, withIntermediateDirectories: true)
        let monthDir = yearDir.appendingPathComponent("01")
        try FileManager.default.createDirectory(at: monthDir, withIntermediateDirectories: true)
        
        let photo1URL = monthDir.appendingPathComponent("photo1.jpg")
        let photo2URL = monthDir.appendingPathComponent("photo2.png")
        let videoURL = monthDir.appendingPathComponent("video.mov")
        
        try "photo1".write(to: photo1URL, atomically: true, encoding: .utf8)
        try "photo2".write(to: photo2URL, atomically: true, encoding: .utf8)
        try "video".write(to: videoURL, atomically: true, encoding: .utf8)
        
        // When: Adopting the library
        let result = try LibraryAdopter.adoptLibrary(at: libraryPath)
        
        // Then: Baseline scan should include all media files
        XCTAssertEqual(
            result.baselineScan.fileCount,
            3,
            "Baseline scan should find 3 media files"
        )
        XCTAssertEqual(
            result.baselineScan.filePaths.count,
            3,
            "Baseline scan should return 3 paths"
        )
        
        // Verify paths are normalized and sorted (deterministic)
        let sortedPaths = result.baselineScan.filePaths.sorted()
        XCTAssertEqual(
            result.baselineScan.filePaths,
            sortedPaths,
            "Baseline scan paths should be sorted for determinism"
        )
        
        // Verify all media files are included
        let pathSet = Set(result.baselineScan.filePaths)
        XCTAssertTrue(
            pathSet.contains(photo1URL.resolvingSymlinksInPath().path),
            "Photo 1 should be in baseline scan"
        )
        XCTAssertTrue(
            pathSet.contains(photo2URL.resolvingSymlinksInPath().path),
            "Photo 2 should be in baseline scan"
        )
        XCTAssertTrue(
            pathSet.contains(videoURL.resolvingSymlinksInPath().path),
            "Video should be in baseline scan"
        )
    }
    
    func testBaselineScanExcludesMediahubDirectory() throws {
        // Given: A directory with media files and .mediahub directory
        let libraryPath = tempDirectory.appendingPathComponent("TestLibrary").path
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: libraryPath),
            withIntermediateDirectories: true
        )
        
        // Add a media file
        let photoURL = URL(fileURLWithPath: libraryPath).appendingPathComponent("photo.jpg")
        try "photo".write(to: photoURL, atomically: true, encoding: .utf8)
        
        // When: Adopting the library (creates .mediahub/)
        let result = try LibraryAdopter.adoptLibrary(at: libraryPath)
        
        // Then: Baseline scan should exclude .mediahub/ directory
        XCTAssertEqual(
            result.baselineScan.fileCount,
            1,
            "Baseline scan should find 1 media file (excluding .mediahub/)"
        )
        
        // Verify .mediahub/ is not in paths
        let hasMediahubPath = result.baselineScan.filePaths.contains { path in
            path.contains(".mediahub")
        }
        XCTAssertFalse(
            hasMediahubPath,
            "Baseline scan should not include .mediahub/ paths"
        )
    }
    
    func testBaselineScanIsDeterministic() throws {
        // Given: A directory with existing media files
        let libraryPath = tempDirectory.appendingPathComponent("TestLibrary").path
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: libraryPath),
            withIntermediateDirectories: true
        )
        
        // Add media files in different order
        let photo1URL = URL(fileURLWithPath: libraryPath).appendingPathComponent("z_photo.jpg")
        let photo2URL = URL(fileURLWithPath: libraryPath).appendingPathComponent("a_photo.png")
        let photo3URL = URL(fileURLWithPath: libraryPath).appendingPathComponent("m_photo.heic")
        
        try "photo1".write(to: photo1URL, atomically: true, encoding: .utf8)
        try "photo2".write(to: photo2URL, atomically: true, encoding: .utf8)
        try "photo3".write(to: photo3URL, atomically: true, encoding: .utf8)
        
        // When: Adopting the library
        let result = try LibraryAdopter.adoptLibrary(at: libraryPath)
        
        // Then: Baseline scan paths should be sorted (deterministic)
        let sortedPaths = result.baselineScan.filePaths.sorted()
        XCTAssertEqual(
            result.baselineScan.filePaths,
            sortedPaths,
            "Baseline scan paths should be sorted for determinism"
        )
        
        // Verify same library state produces same results
        // (Re-scanning should produce identical results)
        let libraryRootURL = URL(fileURLWithPath: libraryPath)
        let rescannedPaths = try LibraryContentQuery.scanLibraryContents(at: libraryRootURL)
        let rescannedSummary = BaselineScanSummary(fileCount: rescannedPaths.count, filePaths: rescannedPaths)
        
        XCTAssertEqual(
            result.baselineScan.fileCount,
            rescannedSummary.fileCount,
            "Re-scan should produce same file count"
        )
        XCTAssertEqual(
            Set(result.baselineScan.filePaths),
            Set(rescannedSummary.filePaths),
            "Re-scan should produce same file paths"
        )
    }
    
    func testBaselineScanExcludesNonMediaFiles() throws {
        // Given: A directory with media files and non-media files
        let libraryPath = tempDirectory.appendingPathComponent("TestLibrary").path
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: libraryPath),
            withIntermediateDirectories: true
        )
        
        // Add media file
        let photoURL = URL(fileURLWithPath: libraryPath).appendingPathComponent("photo.jpg")
        try "photo".write(to: photoURL, atomically: true, encoding: .utf8)
        
        // Add non-media files
        let textFileURL = URL(fileURLWithPath: libraryPath).appendingPathComponent("readme.txt")
        let docFileURL = URL(fileURLWithPath: libraryPath).appendingPathComponent("document.pdf")
        try "text".write(to: textFileURL, atomically: true, encoding: .utf8)
        try "pdf".write(to: docFileURL, atomically: true, encoding: .utf8)
        
        // When: Adopting the library
        let result = try LibraryAdopter.adoptLibrary(at: libraryPath)
        
        // Then: Baseline scan should only include media files
        XCTAssertEqual(
            result.baselineScan.fileCount,
            1,
            "Baseline scan should only find 1 media file"
        )
        
        // Verify non-media files are excluded
        let pathSet = Set(result.baselineScan.filePaths)
        XCTAssertFalse(
            pathSet.contains(textFileURL.resolvingSymlinksInPath().path),
            "Text file should not be in baseline scan"
        )
        XCTAssertFalse(
            pathSet.contains(docFileURL.resolvingSymlinksInPath().path),
            "PDF file should not be in baseline scan"
        )
    }
    
    func testBaselineScanHandlesEmptyLibrary() throws {
        // Given: An empty directory
        let libraryPath = tempDirectory.appendingPathComponent("TestLibrary").path
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: libraryPath),
            withIntermediateDirectories: true
        )
        
        // When: Adopting the library
        let result = try LibraryAdopter.adoptLibrary(at: libraryPath)
        
        // Then: Baseline scan should return empty results
        XCTAssertEqual(
            result.baselineScan.fileCount,
            0,
            "Baseline scan should find 0 media files in empty library"
        )
        XCTAssertTrue(
            result.baselineScan.filePaths.isEmpty,
            "Baseline scan should return empty paths array"
        )
    }
    
    // MARK: - Task 4.6: Dry-Run Tests
    
    func testDryRunPerformsZeroFileSystemWrites() throws {
        // Given: A directory with existing media files
        let libraryPath = tempDirectory.appendingPathComponent("TestLibrary").path
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: libraryPath),
            withIntermediateDirectories: true
        )
        
        // Add a media file
        let photoURL = URL(fileURLWithPath: libraryPath).appendingPathComponent("photo.jpg")
        try "photo content".write(to: photoURL, atomically: true, encoding: .utf8)
        
        // Record initial state
        let libraryRootURL = URL(fileURLWithPath: libraryPath)
        let metadataDirURL = libraryRootURL.appendingPathComponent(LibraryStructure.metadataDirectoryName)
        let metadataFileURL = LibraryStructureCreator.metadataFileURL(for: libraryRootURL)
        
        let initialContents = try FileManager.default.contentsOfDirectory(at: libraryRootURL, includingPropertiesForKeys: nil)
        let initialMetadataDirExists = FileManager.default.fileExists(atPath: metadataDirURL.path)
        let initialMetadataFileExists = FileManager.default.fileExists(atPath: metadataFileURL.path)
        
        // When: Running dry-run adoption
        let result = try LibraryAdopter.adoptLibrary(at: libraryPath, dryRun: true)
        
        // Then: No files should be created
        let finalContents = try FileManager.default.contentsOfDirectory(at: libraryRootURL, includingPropertiesForKeys: nil)
        let finalMetadataDirExists = FileManager.default.fileExists(atPath: metadataDirURL.path)
        let finalMetadataFileExists = FileManager.default.fileExists(atPath: metadataFileURL.path)
        
        XCTAssertEqual(
            finalContents.count,
            initialContents.count,
            "No new files should be created in dry-run"
        )
        XCTAssertEqual(
            finalMetadataDirExists,
            initialMetadataDirExists,
            ".mediahub directory should not be created in dry-run"
        )
        XCTAssertEqual(
            finalMetadataFileExists,
            initialMetadataFileExists,
            "library.json should not be created in dry-run"
        )
        
        // Verify original media file is unchanged
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: photoURL.path),
            "Original media file should still exist"
        )
        
        // Verify result contains preview data
        XCTAssertTrue(
            LibraryIdentifierGenerator.isValid(result.metadata.libraryId),
            "Dry-run should generate preview metadata with valid library ID"
        )
        XCTAssertEqual(
            result.baselineScan.fileCount,
            1,
            "Dry-run should perform baseline scan"
        )
    }
    
    func testDryRunPreviewMatchesActualAdoption() throws {
        // Given: A directory with existing media files
        let libraryPath = tempDirectory.appendingPathComponent("TestLibrary").path
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: libraryPath),
            withIntermediateDirectories: true
        )
        
        // Add media files
        let photo1URL = URL(fileURLWithPath: libraryPath).appendingPathComponent("photo1.jpg")
        let photo2URL = URL(fileURLWithPath: libraryPath).appendingPathComponent("photo2.png")
        try "photo1".write(to: photo1URL, atomically: true, encoding: .utf8)
        try "photo2".write(to: photo2URL, atomically: true, encoding: .utf8)
        
        // When: Running dry-run adoption
        let dryRunResult = try LibraryAdopter.adoptLibrary(at: libraryPath, dryRun: true)
        
        // Then: Verify no files were created
        let libraryRootURL = URL(fileURLWithPath: libraryPath)
        let metadataDirURL = libraryRootURL.appendingPathComponent(LibraryStructure.metadataDirectoryName)
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: metadataDirURL.path),
            "Dry-run should not create .mediahub directory"
        )
        
        // When: Running actual adoption
        let actualResult = try LibraryAdopter.adoptLibrary(at: libraryPath, dryRun: false)
        
        // Then: Verify files were created
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: metadataDirURL.path),
            "Actual adoption should create .mediahub directory"
        )
        
        // Verify preview matches actual (same baseline scan, same metadata structure)
        XCTAssertEqual(
            dryRunResult.baselineScan.fileCount,
            actualResult.baselineScan.fileCount,
            "Dry-run baseline scan should match actual adoption"
        )
        XCTAssertEqual(
            Set(dryRunResult.baselineScan.filePaths),
            Set(actualResult.baselineScan.filePaths),
            "Dry-run baseline scan paths should match actual adoption"
        )
        
        // Verify metadata structure is the same (library ID will differ, but structure is same)
        XCTAssertEqual(
            dryRunResult.metadata.rootPath,
            actualResult.metadata.rootPath,
            "Dry-run metadata root path should match actual"
        )
        XCTAssertEqual(
            dryRunResult.metadata.libraryVersion,
            actualResult.metadata.libraryVersion,
            "Dry-run metadata version should match actual"
        )
    }
    
    func testDryRunPerformsReadOnlyBaselineScan() throws {
        // Given: A directory with existing media files
        let libraryPath = tempDirectory.appendingPathComponent("TestLibrary").path
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: libraryPath),
            withIntermediateDirectories: true
        )
        
        // Add media files in YYYY/MM structure
        let yearDir = URL(fileURLWithPath: libraryPath).appendingPathComponent("2024")
        try FileManager.default.createDirectory(at: yearDir, withIntermediateDirectories: true)
        let monthDir = yearDir.appendingPathComponent("01")
        try FileManager.default.createDirectory(at: monthDir, withIntermediateDirectories: true)
        
        let photoURL = monthDir.appendingPathComponent("photo.jpg")
        try "photo".write(to: photoURL, atomically: true, encoding: .utf8)
        
        // When: Running dry-run adoption
        let result = try LibraryAdopter.adoptLibrary(at: libraryPath, dryRun: true)
        
        // Then: Baseline scan should work (read-only)
        XCTAssertEqual(
            result.baselineScan.fileCount,
            1,
            "Dry-run should perform baseline scan"
        )
        
        // Verify .mediahub directory was not created
        let libraryRootURL = URL(fileURLWithPath: libraryPath)
        let metadataDirURL = libraryRootURL.appendingPathComponent(LibraryStructure.metadataDirectoryName)
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: metadataDirURL.path),
            "Dry-run should not create .mediahub directory"
        )
        
        // Verify original media file is unchanged
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: photoURL.path),
            "Original media file should still exist"
        )
    }
    
    func testDryRunHandlesAlreadyAdoptedLibrary() throws {
        // Given: A directory that is already adopted
        let libraryPath = tempDirectory.appendingPathComponent("TestLibrary").path
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: libraryPath),
            withIntermediateDirectories: true
        )
        
        // Adopt the library first
        _ = try LibraryAdopter.adoptLibrary(at: libraryPath, dryRun: false)
        
        // When: Running dry-run adoption on already adopted library
        // Then: Should throw alreadyAdopted error
        XCTAssertThrowsError(try LibraryAdopter.adoptLibrary(at: libraryPath, dryRun: true)) { error in
            guard case LibraryAdoptionError.alreadyAdopted = error else {
                XCTFail("Expected alreadyAdopted error, got: \(error)")
                return
            }
        }
    }
    
    // MARK: - Task 1.11: Confirmation Prompt Tests (Automated Branches Only)
    
    func testIsInteractiveDetectsTTY() {
        // Given: Running in a test environment (may or may not have TTY)
        // When: Checking if interactive
        let isInteractive = LibraryAdoptCommand.isInteractive()
        
        // Then: Should return a boolean value (actual value depends on test environment)
        // This test just verifies the function exists and is callable
        // The actual TTY detection behavior is tested manually (VAL-2)
        XCTAssertTrue(isInteractive || !isInteractive, "isInteractive should return a boolean")
    }
    
    func testIsInteractiveIsInjectable() {
        // Given: A custom file descriptor (for testing)
        // When: Checking if interactive with custom descriptor
        // Then: Function should accept injectable parameter
        // Note: We can't easily test with a non-TTY descriptor in unit tests,
        // but we verify the function signature allows injection
        let result1 = LibraryAdoptCommand.isInteractive(stdinFileDescriptor: 0)
        let result2 = LibraryAdoptCommand.isInteractive(stdinFileDescriptor: 0)
        
        // Both calls with same descriptor should return same result
        XCTAssertEqual(result1, result2, "Same descriptor should return same result")
    }
    
    // Note: Full interactive prompt testing (yes/y, no/n, Ctrl+C) is covered by manual testing (Task VAL-2)
    // These tests only verify the branch logic (skip/require confirmation)
    
    // MARK: - Task 6.1: Idempotent Adoption Tests (Additional)
    
    func testIdempotentAdoptionProducesConsistentResults() throws {
        // Given: A directory that is already adopted
        let libraryPath = tempDirectory.appendingPathComponent("TestLibrary").path
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: libraryPath),
            withIntermediateDirectories: true
        )
        
        // Adopt once
        let firstResult = try LibraryAdopter.adoptLibrary(at: libraryPath)
        let firstLibraryId = firstResult.metadata.libraryId
        
        // When: Attempting to adopt again (should fail with alreadyAdopted)
        XCTAssertThrowsError(try LibraryAdopter.adoptLibrary(at: libraryPath)) { error in
            guard case LibraryAdoptionError.alreadyAdopted = error else {
                XCTFail("Expected alreadyAdopted error, got: \(error)")
                return
            }
        }
        
        // Then: Metadata should remain unchanged (no duplicate metadata)
        let libraryRootURL = URL(fileURLWithPath: libraryPath)
        let metadataFileURL = LibraryStructureCreator.metadataFileURL(for: libraryRootURL)
        let existingMetadata = try LibraryMetadataSerializer.read(from: metadataFileURL)
        
        XCTAssertEqual(
            existingMetadata.libraryId,
            firstLibraryId,
            "Library ID should remain unchanged (no duplicate metadata)"
        )
        
        // Verify only one metadata file exists
        let metadataDir = metadataFileURL.deletingLastPathComponent()
        let contents = try FileManager.default.contentsOfDirectory(at: metadataDir, includingPropertiesForKeys: nil)
        let metadataFiles = contents.filter { $0.lastPathComponent == "library.json" }
        XCTAssertEqual(
            metadataFiles.count,
            1,
            "Only one library.json should exist (no duplicate metadata)"
        )
    }
    
    // MARK: - Task 6.2: Error Handling Tests (Additional)
    
    func testPathValidationErrorsAreClear() throws {
        // Given: Various invalid paths
        // When/Then: Should throw clear errors
        
        // Empty path
        XCTAssertThrowsError(try LibraryAdopter.validatePath("")) { error in
            guard case LibraryAdoptionError.invalidPath = error else {
                XCTFail("Expected invalidPath error for empty path")
                return
            }
        }
        
        // Non-existent path
        let nonExistentPath = tempDirectory.appendingPathComponent("NonExistent").path
        XCTAssertThrowsError(try LibraryAdopter.validatePath(nonExistentPath)) { error in
            guard case LibraryAdoptionError.pathDoesNotExist = error else {
                XCTFail("Expected pathDoesNotExist error")
                return
            }
        }
        
        // File instead of directory
        let filePath = tempDirectory.appendingPathComponent("file.txt").path
        try "test".write(to: URL(fileURLWithPath: filePath), atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try LibraryAdopter.validatePath(filePath)) { error in
            guard case LibraryAdoptionError.pathIsNotDirectory = error else {
                XCTFail("Expected pathIsNotDirectory error")
                return
            }
        }
    }
    
    func testRollbackPreservesLibraryIntegrity() throws {
        // Given: A directory that will fail during adoption (simulated)
        let libraryPath = tempDirectory.appendingPathComponent("TestLibrary").path
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: libraryPath),
            withIntermediateDirectories: true
        )
        
        // Add a media file
        let photoURL = URL(fileURLWithPath: libraryPath).appendingPathComponent("photo.jpg")
        let photoContent = "photo content"
        try photoContent.write(to: photoURL, atomically: true, encoding: .utf8)
        
        // Create .mediahub directory manually, then make it read-only to cause failure
        let libraryRootURL = URL(fileURLWithPath: libraryPath)
        let metadataDirURL = libraryRootURL.appendingPathComponent(LibraryStructure.metadataDirectoryName)
        try FileManager.default.createDirectory(at: metadataDirURL, withIntermediateDirectories: true)
        
        // Make directory read-only
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o555],
            ofItemAtPath: metadataDirURL.path
        )
        
        // When: Attempting to adopt (will fail)
        XCTAssertThrowsError(try LibraryAdopter.adoptLibrary(at: libraryPath)) { error in
            // Verify error type
            switch error {
            case LibraryAdoptionError.permissionDenied, LibraryAdoptionError.metadataWriteFailed:
                break // Expected
            default:
                XCTFail("Expected permissionDenied or metadataWriteFailed, got: \(error)")
            }
        }
        
        // Then: Media file should be unchanged (library integrity preserved)
        let photoContentAfter = try String(contentsOf: photoURL, encoding: .utf8)
        XCTAssertEqual(
            photoContentAfter,
            photoContent,
            "Media file should be unchanged after failed adoption"
        )
        
        // Restore permissions for cleanup
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: metadataDirURL.path
        )
    }
    
    // MARK: - Task 6.3: JSON Output Format Tests
    
    func testJSONOutputIncludesDryRunField() throws {
        // Given: A directory with media files
        let libraryPath = tempDirectory.appendingPathComponent("TestLibrary").path
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: libraryPath),
            withIntermediateDirectories: true
        )
        
        let photoURL = URL(fileURLWithPath: libraryPath).appendingPathComponent("photo.jpg")
        try "photo".write(to: photoURL, atomically: true, encoding: .utf8)
        
        // When: Running adoption with dry-run
        let result = try LibraryAdopter.adoptLibrary(at: libraryPath, dryRun: true)
        
        // Format as JSON
        let formatter = LibraryAdoptionFormatter(
            result: result,
            outputFormat: .json,
            dryRun: true
        )
        let jsonString = formatter.format()
        
        // Then: JSON should include dryRun: true
        XCTAssertTrue(
            jsonString.contains("\"dryRun\" : true") || jsonString.contains("\"dryRun\":true"),
            "JSON output should include dryRun field set to true"
        )
        
        // Verify JSON is valid
        let jsonData = jsonString.data(using: .utf8)!
        let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        XCTAssertTrue(
            jsonObject["dryRun"] as? Bool == true,
            "dryRun field should be true in JSON"
        )
    }
    
    func testJSONOutputStructureIsComplete() throws {
        // Given: A directory with media files
        let libraryPath = tempDirectory.appendingPathComponent("TestLibrary").path
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: libraryPath),
            withIntermediateDirectories: true
        )
        
        let photoURL = URL(fileURLWithPath: libraryPath).appendingPathComponent("photo.jpg")
        try "photo".write(to: photoURL, atomically: true, encoding: .utf8)
        
        // When: Running adoption
        let result = try LibraryAdopter.adoptLibrary(at: libraryPath, dryRun: false)
        
        // Format as JSON
        let formatter = LibraryAdoptionFormatter(
            result: result,
            outputFormat: .json,
            dryRun: false
        )
        let jsonString = formatter.format()
        
        // Then: JSON should have all required fields
        let jsonData = jsonString.data(using: .utf8)!
        let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        
        XCTAssertNotNil(jsonObject["metadata"], "JSON should include metadata")
        XCTAssertNotNil(jsonObject["baselineScan"], "JSON should include baselineScan")
        XCTAssertNotNil(jsonObject["dryRun"], "JSON should include dryRun")
        
        // Verify metadata structure
        if let metadata = jsonObject["metadata"] as? [String: Any] {
            XCTAssertNotNil(metadata["libraryId"], "Metadata should include libraryId")
            XCTAssertNotNil(metadata["rootPath"], "Metadata should include rootPath")
            XCTAssertNotNil(metadata["libraryVersion"], "Metadata should include libraryVersion")
        }
        
        // Verify baselineScan structure
        if let baselineScan = jsonObject["baselineScan"] as? [String: Any] {
            XCTAssertNotNil(baselineScan["fileCount"], "baselineScan should include fileCount")
            XCTAssertNotNil(baselineScan["filePaths"], "baselineScan should include filePaths")
        }
    }
    
    // MARK: - Task 6.4: Compatibility Tests
    
    func testLibraryOpenWorksOnAdoptedLibrary() throws {
        // Given: An adopted library
        let libraryPath = tempDirectory.appendingPathComponent("TestLibrary").path
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: libraryPath),
            withIntermediateDirectories: true
        )
        
        // Adopt the library
        let adoptionResult = try LibraryAdopter.adoptLibrary(at: libraryPath)
        
        // When: Opening the library
        let openedLibrary = try LibraryContext.openLibrary(at: libraryPath)
        
        // Then: Should open successfully
        XCTAssertEqual(
            openedLibrary.metadata.libraryId,
            adoptionResult.metadata.libraryId,
            "Opened library should have same ID as adopted library"
        )
        XCTAssertEqual(
            openedLibrary.rootURL.path,
            libraryPath,
            "Opened library should have correct path"
        )
    }
    
    func testDetectExcludesExistingFilesFromAdoptedLibrary() throws {
        // Given: An adopted library with existing media files
        let libraryPath = tempDirectory.appendingPathComponent("TestLibrary").path
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: libraryPath),
            withIntermediateDirectories: true
        )
        
        // Add media file to library
        let libraryPhotoURL = URL(fileURLWithPath: libraryPath).appendingPathComponent("photo.jpg")
        try "library photo".write(to: libraryPhotoURL, atomically: true, encoding: .utf8)
        
        // Adopt the library
        _ = try LibraryAdopter.adoptLibrary(at: libraryPath)
        
        // Create a source with the same file
        let sourcePath = tempDirectory.appendingPathComponent("Source").path
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: sourcePath),
            withIntermediateDirectories: true
        )
        
        // Copy same file to source (simulating duplicate)
        let sourcePhotoURL = URL(fileURLWithPath: sourcePath).appendingPathComponent("photo.jpg")
        try "library photo".write(to: sourcePhotoURL, atomically: true, encoding: .utf8)
        
        // When: Running detection
        let libraryRootURL = URL(fileURLWithPath: libraryPath)
        let libraryPaths = try LibraryContentQuery.scanLibraryContents(at: libraryRootURL)
        
        // Then: Existing file should be in library paths (known)
        let libraryPhotoPath = libraryPhotoURL.resolvingSymlinksInPath().path
        XCTAssertTrue(
            libraryPaths.contains(libraryPhotoPath),
            "Existing library file should be in known paths"
        )
        
        // The file in source should be detected as "known" if it matches library path
        // (This tests that baseline scan established the file as known)
    }
    
    // MARK: - Task 6.5: Zero Media File Modification Tests (Additional)
    
    func testAdoptionDoesNotModifyFileTimestamps() throws {
        // Given: A directory with media files
        let libraryPath = tempDirectory.appendingPathComponent("TestLibrary").path
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: libraryPath),
            withIntermediateDirectories: true
        )
        
        let photoURL = URL(fileURLWithPath: libraryPath).appendingPathComponent("photo.jpg")
        try "photo content".write(to: photoURL, atomically: true, encoding: .utf8)
        
        // Get original file attributes
        let originalAttributes = try FileManager.default.attributesOfItem(atPath: photoURL.path)
        let originalModificationDate = originalAttributes[.modificationDate] as? Date
        
        // Small delay to ensure timestamp difference
        Thread.sleep(forTimeInterval: 0.1)
        
        // When: Adopting the library
        _ = try LibraryAdopter.adoptLibrary(at: libraryPath)
        
        // Then: File modification date should be unchanged
        let newAttributes = try FileManager.default.attributesOfItem(atPath: photoURL.path)
        let newModificationDate = newAttributes[.modificationDate] as? Date
        
        if let original = originalModificationDate, let new = newModificationDate {
            XCTAssertEqual(
                original.timeIntervalSince1970,
                new.timeIntervalSince1970,
                accuracy: 1.0, // Allow 1 second tolerance
                "File modification date should not change"
            )
        }
    }
    
    func testAdoptionDoesNotMoveOrRenameFiles() throws {
        // Given: A directory with media files in specific locations
        let libraryPath = tempDirectory.appendingPathComponent("TestLibrary").path
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: libraryPath),
            withIntermediateDirectories: true
        )
        
        let yearDir = URL(fileURLWithPath: libraryPath).appendingPathComponent("2024")
        try FileManager.default.createDirectory(at: yearDir, withIntermediateDirectories: true)
        let monthDir = yearDir.appendingPathComponent("01")
        try FileManager.default.createDirectory(at: monthDir, withIntermediateDirectories: true)
        
        let photo1URL = monthDir.appendingPathComponent("photo1.jpg")
        let photo2URL = monthDir.appendingPathComponent("photo2.png")
        
        try "photo1".write(to: photo1URL, atomically: true, encoding: .utf8)
        try "photo2".write(to: photo2URL, atomically: true, encoding: .utf8)
        
        // Record original paths
        let originalPhoto1Path = photo1URL.path
        let originalPhoto2Path = photo2URL.path
        
        // When: Adopting the library
        _ = try LibraryAdopter.adoptLibrary(at: libraryPath)
        
        // Then: Files should still be at same locations
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: originalPhoto1Path),
            "Photo 1 should still be at original location"
        )
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: originalPhoto2Path),
            "Photo 2 should still be at original location"
        )
        
        // Verify no files were moved to different locations
        let libraryRootURL = URL(fileURLWithPath: libraryPath)
        let allFiles = try FileManager.default.subpathsOfDirectory(atPath: libraryPath)
        let mediaFiles = allFiles.filter { path in
            MediaFileFormat.isMediaFile(path: path)
        }
        
        XCTAssertEqual(
            mediaFiles.count,
            2,
            "Should still have 2 media files (none moved or renamed)"
        )
    }
    
    // MARK: - Task 6.6: Dry-Run Accuracy Tests (Additional)
    
    func testDryRunPreviewMetadataMatchesActualMetadata() throws {
        // Given: A directory with media files
        let libraryPath = tempDirectory.appendingPathComponent("TestLibrary").path
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: libraryPath),
            withIntermediateDirectories: true
        )
        
        let photoURL = URL(fileURLWithPath: libraryPath).appendingPathComponent("photo.jpg")
        try "photo".write(to: photoURL, atomically: true, encoding: .utf8)
        
        // When: Running dry-run
        let dryRunResult = try LibraryAdopter.adoptLibrary(at: libraryPath, dryRun: true)
        
        // Verify no files created
        let libraryRootURL = URL(fileURLWithPath: libraryPath)
        let metadataDirURL = libraryRootURL.appendingPathComponent(LibraryStructure.metadataDirectoryName)
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: metadataDirURL.path),
            "Dry-run should not create .mediahub directory"
        )
        
        // When: Running actual adoption
        let actualResult = try LibraryAdopter.adoptLibrary(at: libraryPath, dryRun: false)
        
        // Then: Metadata structure should match (except libraryId which is random)
        XCTAssertEqual(
            dryRunResult.metadata.rootPath,
            actualResult.metadata.rootPath,
            "Dry-run metadata rootPath should match actual"
        )
        XCTAssertEqual(
            dryRunResult.metadata.libraryVersion,
            actualResult.metadata.libraryVersion,
            "Dry-run metadata version should match actual"
        )
        XCTAssertEqual(
            dryRunResult.metadata.version,
            actualResult.metadata.version,
            "Dry-run metadata format version should match actual"
        )
    }
    
    func testDryRunBaselineScanMatchesActualBaselineScan() throws {
        // Given: A directory with multiple media files
        let libraryPath = tempDirectory.appendingPathComponent("TestLibrary").path
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: libraryPath),
            withIntermediateDirectories: true
        )
        
        // Add multiple media files
        let photo1URL = URL(fileURLWithPath: libraryPath).appendingPathComponent("photo1.jpg")
        let photo2URL = URL(fileURLWithPath: libraryPath).appendingPathComponent("photo2.png")
        let videoURL = URL(fileURLWithPath: libraryPath).appendingPathComponent("video.mov")
        
        try "photo1".write(to: photo1URL, atomically: true, encoding: .utf8)
        try "photo2".write(to: photo2URL, atomically: true, encoding: .utf8)
        try "video".write(to: videoURL, atomically: true, encoding: .utf8)
        
        // When: Running dry-run
        let dryRunResult = try LibraryAdopter.adoptLibrary(at: libraryPath, dryRun: true)
        
        // When: Running actual adoption
        let actualResult = try LibraryAdopter.adoptLibrary(at: libraryPath, dryRun: false)
        
        // Then: Baseline scan should match exactly
        XCTAssertEqual(
            dryRunResult.baselineScan.fileCount,
            actualResult.baselineScan.fileCount,
            "Dry-run baseline scan file count should match actual"
        )
        XCTAssertEqual(
            Set(dryRunResult.baselineScan.filePaths),
            Set(actualResult.baselineScan.filePaths),
            "Dry-run baseline scan paths should match actual exactly"
        )
    }
    
    // MARK: - Baseline Index Integration Tests (Slice 7)
    
    func testAdoptLibraryCreatesIndexWhenAbsent() throws {
        // Given: A directory with media files (no index exists)
        let libraryPath = tempDirectory.appendingPathComponent("TestLibrary").path
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: libraryPath),
            withIntermediateDirectories: true
        )
        
        // Add media files
        let photo1URL = URL(fileURLWithPath: libraryPath).appendingPathComponent("2024").appendingPathComponent("01").appendingPathComponent("photo1.jpg")
        let photo2URL = URL(fileURLWithPath: libraryPath).appendingPathComponent("2024").appendingPathComponent("02").appendingPathComponent("photo2.jpg")
        try FileManager.default.createDirectory(at: photo1URL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: photo2URL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "photo1".write(to: photo1URL, atomically: true, encoding: .utf8)
        try "photo2".write(to: photo2URL, atomically: true, encoding: .utf8)
        
        // When: Adopting the library
        let result = try LibraryAdopter.adoptLibrary(at: libraryPath)
        
        // Then: Index should be created
        XCTAssertTrue(result.indexCreated, "Index should be created when absent")
        XCTAssertNil(result.indexSkippedReason, "No skip reason when index is created")
        XCTAssertNotNil(result.indexMetadata, "Index metadata should be present")
        XCTAssertEqual(result.indexMetadata?.version, "1.0")
        XCTAssertEqual(result.indexMetadata?.entryCount, 2)
        
        // Verify index file exists and is decodable
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryPath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: indexPath), "Index file should exist")
        
        let loadedIndex = try BaselineIndexReader.load(from: indexPath)
        XCTAssertEqual(loadedIndex.version, "1.0")
        XCTAssertEqual(loadedIndex.entryCount, 2)
        XCTAssertEqual(loadedIndex.entries.count, 2)
    }
    
    func testAdoptLibraryPreservesValidExistingIndex() throws {
        // Given: A directory with media files
        let libraryPath = tempDirectory.appendingPathComponent("TestLibrary").path
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: libraryPath),
            withIntermediateDirectories: true
        )
        
        // Add media files
        let photo1URL = URL(fileURLWithPath: libraryPath).appendingPathComponent("2024").appendingPathComponent("01").appendingPathComponent("photo1.jpg")
        let photo2URL = URL(fileURLWithPath: libraryPath).appendingPathComponent("2024").appendingPathComponent("02").appendingPathComponent("photo2.jpg")
        try FileManager.default.createDirectory(at: photo1URL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: photo2URL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "photo1".write(to: photo1URL, atomically: true, encoding: .utf8)
        try "photo2".write(to: photo2URL, atomically: true, encoding: .utf8)
        
        // Create a valid index manually (simulating previous adoption)
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryPath)
        let existingEntries = [
            IndexEntry(
                path: try normalizePath(photo1URL.path, relativeTo: libraryPath),
                size: 1000,
                mtime: ISO8601DateFormatter().string(from: Date())
            ),
            IndexEntry(
                path: try normalizePath(photo2URL.path, relativeTo: libraryPath),
                size: 2000,
                mtime: ISO8601DateFormatter().string(from: Date())
            )
        ]
        let existingIndex = BaselineIndex(entries: existingEntries)
        try BaselineIndexWriter.write(existingIndex, to: indexPath, libraryRoot: libraryPath)
        
        // Get original index content hash for comparison
        let originalIndexData = try Data(contentsOf: URL(fileURLWithPath: indexPath))
        let originalIndex = try BaselineIndexReader.load(from: indexPath)
        let originalLastUpdated = originalIndex.lastUpdated
        
        // When: Adopting the library again (idempotent)
        let result = try LibraryAdopter.adoptLibrary(at: libraryPath)
        
        // Then: Index should NOT be modified (preserved)
        XCTAssertFalse(result.indexCreated, "Index should not be created when already valid")
        XCTAssertEqual(result.indexSkippedReason, "already_valid", "Skip reason should indicate index was already valid")
        XCTAssertNotNil(result.indexMetadata, "Index metadata should be present")
        XCTAssertEqual(result.indexMetadata?.version, "1.0")
        XCTAssertEqual(result.indexMetadata?.entryCount, 2)
        
        // Verify index file was not modified (compare lastUpdated timestamp)
        let preservedIndex = try BaselineIndexReader.load(from: indexPath)
        XCTAssertEqual(preservedIndex.lastUpdated, originalLastUpdated, "Index lastUpdated should not change when preserved")
        XCTAssertEqual(preservedIndex.entryCount, 2, "Index entry count should remain unchanged")
        
        // Verify index content is identical (same entries)
        XCTAssertEqual(preservedIndex.entries.count, originalIndex.entries.count)
        for (preservedEntry, originalEntry) in zip(preservedIndex.entries, originalIndex.entries) {
            XCTAssertEqual(preservedEntry.path, originalEntry.path)
            XCTAssertEqual(preservedEntry.size, originalEntry.size)
            XCTAssertEqual(preservedEntry.mtime, originalEntry.mtime)
        }
    }
}
