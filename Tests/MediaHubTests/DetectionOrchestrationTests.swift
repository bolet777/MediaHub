//
//  DetectionOrchestrationTests.swift
//  MediaHubTests
//
//  Tests for Detection execution and orchestration
//

import XCTest
@testable import MediaHub

final class DetectionOrchestrationTests: XCTestCase {
    var tempDirectory: URL!
    var libraryRootURL: URL!
    var sourceDirectory: URL!
    let libraryId = LibraryIdentifierGenerator.generate()
    
    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        libraryRootURL = tempDirectory.appendingPathComponent("TestLibrary")
        sourceDirectory = tempDirectory.appendingPathComponent("Source")
        
        // Create library structure
        try! FileManager.default.createDirectory(at: libraryRootURL, withIntermediateDirectories: true)
        try! LibraryStructureCreator.createStructure(at: libraryRootURL)
        
        // Create library metadata
        let metadata = LibraryMetadata(libraryId: libraryId, rootPath: libraryRootURL.path)
        let metadataURL = LibraryStructureCreator.metadataFileURL(for: libraryRootURL)
        try! LibraryMetadataSerializer.write(metadata, to: metadataURL)
        
        // Create source directory
        try! FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    func testExecuteDetectionWithNewItems() throws {
        // Add media file to source
        let sourceFile = sourceDirectory.appendingPathComponent("new.jpg")
        try "fake image".write(to: sourceFile, atomically: true, encoding: .utf8)
        
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: sourceDirectory.path
        )
        
        // Attach source to library
        try SourceAssociationManager.attach(
            source: source,
            to: libraryRootURL,
            libraryId: libraryId
        )
        
        // Execute detection
        let result = try DetectionOrchestrator.executeDetection(
            source: source,
            libraryRootURL: libraryRootURL,
            libraryId: libraryId
        )
        
        XCTAssertEqual(result.summary.totalScanned, 1)
        XCTAssertEqual(result.summary.newItems, 1)
        XCTAssertEqual(result.summary.knownItems, 0)
        XCTAssertEqual(result.candidates.count, 1)
        XCTAssertEqual(result.candidates[0].status, "new")
        
        // Verify read-only behavior: source file is unchanged
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceFile.path))
        let sourceContent = try String(contentsOf: sourceFile, encoding: .utf8)
        XCTAssertEqual(sourceContent, "fake image", "Detection should not modify source files")
    }
    
    func testExecuteDetectionWithKnownItems() throws {
        // For path-based comparison (P1), files are considered "known" if they have the same absolute path.
        // Create a subdirectory in the library and use it as both library content and source.
        let mediaSubdir = libraryRootURL.appendingPathComponent("Media")
        try FileManager.default.createDirectory(at: mediaSubdir, withIntermediateDirectories: true)
        
        // Add media file to the subdirectory (this will be both in library and source)
        let mediaFile = mediaSubdir.appendingPathComponent("image.jpg")
        try "fake image".write(to: mediaFile, atomically: true, encoding: .utf8)
        
        // Create source pointing to the subdirectory
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: mediaSubdir.path
        )
        
        // Attach source to library
        try SourceAssociationManager.attach(
            source: source,
            to: libraryRootURL,
            libraryId: libraryId
        )
        
        // Execute detection - the file should be detected as "known" since it's already in the library
        let result = try DetectionOrchestrator.executeDetection(
            source: source,
            libraryRootURL: libraryRootURL,
            libraryId: libraryId
        )
        
        XCTAssertEqual(result.summary.totalScanned, 1)
        XCTAssertEqual(result.summary.newItems, 0)
        XCTAssertEqual(result.summary.knownItems, 1)
        XCTAssertEqual(result.candidates[0].status, "known")
        XCTAssertEqual(result.candidates[0].exclusionReason, .alreadyKnown)
    }
    
    func testExecuteDetectionDeterministic() throws {
        // Add media files to source
        for i in 1...3 {
            let file = sourceDirectory.appendingPathComponent("file\(i).jpg")
            try "fake image \(i)".write(to: file, atomically: true, encoding: .utf8)
        }
        
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: sourceDirectory.path
        )
        
        // Attach source to library
        try SourceAssociationManager.attach(
            source: source,
            to: libraryRootURL,
            libraryId: libraryId
        )
        
        // Execute detection twice
        let result1 = try DetectionOrchestrator.executeDetection(
            source: source,
            libraryRootURL: libraryRootURL,
            libraryId: libraryId
        )
        
        let result2 = try DetectionOrchestrator.executeDetection(
            source: source,
            libraryRootURL: libraryRootURL,
            libraryId: libraryId
        )
        
        // Results should be identical (except timestamps)
        XCTAssertEqual(result1.summary.totalScanned, result2.summary.totalScanned)
        XCTAssertEqual(result1.summary.newItems, result2.summary.newItems)
        XCTAssertEqual(result1.summary.knownItems, result2.summary.knownItems)
        XCTAssertEqual(result1.candidates.count, result2.candidates.count)
        
        // Candidate paths should match
        let paths1 = result1.candidates.map { $0.item.path }.sorted()
        let paths2 = result2.candidates.map { $0.item.path }.sorted()
        XCTAssertEqual(paths1, paths2)
    }
    
    func testExecuteDetectionInaccessibleSource() {
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: "/nonexistent/path"
        )
        
        XCTAssertThrowsError(
            try DetectionOrchestrator.executeDetection(
                source: source,
                libraryRootURL: libraryRootURL,
                libraryId: libraryId
            )
        ) { error in
            XCTAssertTrue(error is DetectionOrchestrationError)
        }
    }
    
    func testExecuteDetectionStoresResult() throws {
        // Add media file to source
        let sourceFile = sourceDirectory.appendingPathComponent("new.jpg")
        try "fake image".write(to: sourceFile, atomically: true, encoding: .utf8)
        
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: sourceDirectory.path
        )
        
        // Attach source to library
        try SourceAssociationManager.attach(
            source: source,
            to: libraryRootURL,
            libraryId: libraryId
        )
        
        // Execute detection
        let result = try DetectionOrchestrator.executeDetection(
            source: source,
            libraryRootURL: libraryRootURL,
            libraryId: libraryId
        )
        
        // Verify result was stored
        let retrieved = try DetectionResultRetriever.retrieveLatest(
            for: libraryRootURL,
            sourceId: source.sourceId
        )
        
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.sourceId, source.sourceId)
        XCTAssertEqual(retrieved?.summary.totalScanned, result.summary.totalScanned)
    }
    
    func testExecuteDetectionUpdatesSourceMetadata() throws {
        // Add media file to source
        let sourceFile = sourceDirectory.appendingPathComponent("new.jpg")
        try "fake image".write(to: sourceFile, atomically: true, encoding: .utf8)
        
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: sourceDirectory.path
        )
        
        // Attach source to library
        try SourceAssociationManager.attach(
            source: source,
            to: libraryRootURL,
            libraryId: libraryId
        )
        
        // Execute detection
        let result = try DetectionOrchestrator.executeDetection(
            source: source,
            libraryRootURL: libraryRootURL,
            libraryId: libraryId
        )
        
        // Verify source metadata was updated
        let sources = try SourceAssociationManager.retrieveSources(
            for: libraryRootURL,
            libraryId: libraryId
        )
        
        let updatedSource = sources.first { $0.sourceId == source.sourceId }
        XCTAssertNotNil(updatedSource)
        XCTAssertNotNil(updatedSource?.lastDetectedAt)
        XCTAssertEqual(updatedSource?.lastDetectedAt, result.detectedAt)
    }
    
    // MARK: - Baseline Index Integration Tests
    
    func testExecuteDetectionUsesValidIndex() throws {
        // Create library files
        let mediaSubdir = libraryRootURL.appendingPathComponent("2024").appendingPathComponent("01")
        try FileManager.default.createDirectory(at: mediaSubdir, withIntermediateDirectories: true)
        
        let libraryFile1 = mediaSubdir.appendingPathComponent("file1.jpg")
        let libraryFile2 = mediaSubdir.appendingPathComponent("file2.jpg")
        try "fake image 1".write(to: libraryFile1, atomically: true, encoding: .utf8)
        try "fake image 2".write(to: libraryFile2, atomically: true, encoding: .utf8)
        
        // Create baseline index with library files
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRootURL.path)
        let entries = [
            IndexEntry(
                path: try normalizePath(libraryFile1.path, relativeTo: libraryRootURL.path),
                size: 1000,
                mtime: ISO8601DateFormatter().string(from: Date())
            ),
            IndexEntry(
                path: try normalizePath(libraryFile2.path, relativeTo: libraryRootURL.path),
                size: 2000,
                mtime: ISO8601DateFormatter().string(from: Date())
            )
        ]
        let index = BaselineIndex(entries: entries)
        try BaselineIndexWriter.write(index, to: indexPath, libraryRoot: libraryRootURL.path)
        
        // Create source with new file
        let sourceFile = sourceDirectory.appendingPathComponent("new.jpg")
        try "new image".write(to: sourceFile, atomically: true, encoding: .utf8)
        
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: sourceDirectory.path
        )
        
        // Attach source to library
        try SourceAssociationManager.attach(
            source: source,
            to: libraryRootURL,
            libraryId: libraryId
        )
        
        // Execute detection
        let result = try DetectionOrchestrator.executeDetection(
            source: source,
            libraryRootURL: libraryRootURL,
            libraryId: libraryId
        )
        
        // Verify index was used
        XCTAssertTrue(result.indexUsed, "Index should be used when valid")
        XCTAssertNil(result.indexFallbackReason, "No fallback reason when index is used")
        XCTAssertNotNil(result.indexMetadata, "Index metadata should be present")
        XCTAssertEqual(result.indexMetadata?.version, "1.0")
        XCTAssertEqual(result.indexMetadata?.entryCount, 2)
        
        // Verify detection results (new file should be detected as new)
        XCTAssertEqual(result.summary.totalScanned, 1)
        XCTAssertEqual(result.summary.newItems, 1)
        XCTAssertEqual(result.summary.knownItems, 0)
        
        // Verify index file was not modified (read-only guarantee)
        let indexAfter = try BaselineIndexReader.load(from: indexPath)
        XCTAssertEqual(indexAfter.entryCount, 2, "Index should not be modified by detection")
    }
    
    func testExecuteDetectionFallsBackWhenIndexAbsent() throws {
        // Create library files (no index created)
        let mediaSubdir = libraryRootURL.appendingPathComponent("2024").appendingPathComponent("01")
        try FileManager.default.createDirectory(at: mediaSubdir, withIntermediateDirectories: true)
        
        let libraryFile = mediaSubdir.appendingPathComponent("file1.jpg")
        try "fake image".write(to: libraryFile, atomically: true, encoding: .utf8)
        
        // Create source with new file
        let sourceFile = sourceDirectory.appendingPathComponent("new.jpg")
        try "new image".write(to: sourceFile, atomically: true, encoding: .utf8)
        
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: sourceDirectory.path
        )
        
        // Attach source to library
        try SourceAssociationManager.attach(
            source: source,
            to: libraryRootURL,
            libraryId: libraryId
        )
        
        // Execute detection
        let result = try DetectionOrchestrator.executeDetection(
            source: source,
            libraryRootURL: libraryRootURL,
            libraryId: libraryId
        )
        
        // Verify fallback occurred
        XCTAssertFalse(result.indexUsed, "Index should not be used when absent")
        XCTAssertEqual(result.indexFallbackReason, "missing", "Fallback reason should be 'missing'")
        XCTAssertNil(result.indexMetadata, "No index metadata when index is absent")
        
        // Verify detection still works (fallback to full scan)
        XCTAssertEqual(result.summary.totalScanned, 1)
        XCTAssertEqual(result.summary.newItems, 1)
        XCTAssertEqual(result.summary.knownItems, 0)
    }
    
    func testExecuteDetectionFallsBackWhenIndexInvalid() throws {
        // Create invalid index file (wrong version)
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRootURL.path)
        let invalidIndex = """
        {
            "version": "2.0",
            "created": "2024-01-01T00:00:00Z",
            "lastUpdated": "2024-01-01T00:00:00Z",
            "entryCount": 0,
            "entries": []
        }
        """
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: indexPath).deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try invalidIndex.write(toFile: indexPath, atomically: true, encoding: .utf8)
        
        // Create library files
        let mediaSubdir = libraryRootURL.appendingPathComponent("2024").appendingPathComponent("01")
        try FileManager.default.createDirectory(at: mediaSubdir, withIntermediateDirectories: true)
        
        let libraryFile = mediaSubdir.appendingPathComponent("file1.jpg")
        try "fake image".write(to: libraryFile, atomically: true, encoding: .utf8)
        
        // Create source with new file
        let sourceFile = sourceDirectory.appendingPathComponent("new.jpg")
        try "new image".write(to: sourceFile, atomically: true, encoding: .utf8)
        
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: sourceDirectory.path
        )
        
        // Attach source to library
        try SourceAssociationManager.attach(
            source: source,
            to: libraryRootURL,
            libraryId: libraryId
        )
        
        // Execute detection
        let result = try DetectionOrchestrator.executeDetection(
            source: source,
            libraryRootURL: libraryRootURL,
            libraryId: libraryId
        )
        
        // Verify fallback occurred
        XCTAssertFalse(result.indexUsed, "Index should not be used when invalid")
        XCTAssertNotNil(result.indexFallbackReason, "Fallback reason should be present")
        XCTAssertTrue(result.indexFallbackReason?.contains("unsupported_version") == true, "Fallback reason should indicate unsupported version")
        XCTAssertNil(result.indexMetadata, "No index metadata when index is invalid")
        
        // Verify detection still works (fallback to full scan)
        XCTAssertEqual(result.summary.totalScanned, 1)
        XCTAssertEqual(result.summary.newItems, 1)
        XCTAssertEqual(result.summary.knownItems, 0)
        
        // Verify index file was not modified (read-only guarantee)
        let indexContent = try String(contentsOfFile: indexPath, encoding: .utf8)
        XCTAssertTrue(indexContent.contains("2.0"), "Index should not be modified by detection")
    }
}
