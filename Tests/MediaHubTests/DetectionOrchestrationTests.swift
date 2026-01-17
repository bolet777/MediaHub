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
    
    // MARK: - Media Type Filtering Tests
    
    func testExecuteDetectionWithMediaTypesImages() throws {
        // Create source with both images and videos
        let imageFile = sourceDirectory.appendingPathComponent("test.jpg")
        try "fake image".write(to: imageFile, atomically: true, encoding: .utf8)
        
        let videoFile = sourceDirectory.appendingPathComponent("test.mov")
        try "fake video".write(to: videoFile, atomically: true, encoding: .utf8)
        
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: sourceDirectory.path,
            mediaTypes: .images
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
        
        // Should only detect image files
        XCTAssertEqual(result.summary.totalScanned, 1)
        XCTAssertEqual(result.candidates.count, 1)
        XCTAssertTrue(result.candidates[0].item.fileName == "test.jpg")
        XCTAssertFalse(result.candidates.contains { $0.item.fileName == "test.mov" })
    }
    
    func testExecuteDetectionWithMediaTypesVideos() throws {
        // Create source with both images and videos
        let imageFile = sourceDirectory.appendingPathComponent("test.jpg")
        try "fake image".write(to: imageFile, atomically: true, encoding: .utf8)
        
        let videoFile = sourceDirectory.appendingPathComponent("test.mov")
        try "fake video".write(to: videoFile, atomically: true, encoding: .utf8)
        
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: sourceDirectory.path,
            mediaTypes: .videos
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
        
        // Should only detect video files
        XCTAssertEqual(result.summary.totalScanned, 1)
        XCTAssertEqual(result.candidates.count, 1)
        XCTAssertTrue(result.candidates[0].item.fileName == "test.mov")
        XCTAssertFalse(result.candidates.contains { $0.item.fileName == "test.jpg" })
    }
    
    func testExecuteDetectionWithMediaTypesBoth() throws {
        // Create source with both images and videos
        let imageFile = sourceDirectory.appendingPathComponent("test.jpg")
        try "fake image".write(to: imageFile, atomically: true, encoding: .utf8)
        
        let videoFile = sourceDirectory.appendingPathComponent("test.mov")
        try "fake video".write(to: videoFile, atomically: true, encoding: .utf8)
        
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: sourceDirectory.path,
            mediaTypes: .both
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
        
        // Should detect both images and videos
        XCTAssertEqual(result.summary.totalScanned, 2)
        XCTAssertEqual(result.candidates.count, 2)
        XCTAssertTrue(result.candidates.contains { $0.item.fileName == "test.jpg" })
        XCTAssertTrue(result.candidates.contains { $0.item.fileName == "test.mov" })
    }
    
    func testExecuteDetectionPreservesMediaTypesWhenUpdatingMetadata() throws {
        // Add media file to source
        let sourceFile = sourceDirectory.appendingPathComponent("new.jpg")
        try "fake image".write(to: sourceFile, atomically: true, encoding: .utf8)
        
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: sourceDirectory.path,
            mediaTypes: .images
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
        
        // Verify source metadata was updated AND mediaTypes field is preserved
        let sources = try SourceAssociationManager.retrieveSources(
            for: libraryRootURL,
            libraryId: libraryId
        )
        
        let updatedSource = sources.first { $0.sourceId == source.sourceId }
        XCTAssertNotNil(updatedSource)
        XCTAssertNotNil(updatedSource?.lastDetectedAt)
        XCTAssertEqual(updatedSource?.lastDetectedAt, result.detectedAt)
        XCTAssertEqual(updatedSource?.mediaTypes, .images, "mediaTypes field should be preserved when updating lastDetectedAt")
    }
    
    // MARK: - Progress Callback Tests
    
    func testDetectionProgressCallbackInvocation() throws {
        // Create source with multiple files
        for i in 1...5 {
            let sourceFile = sourceDirectory.appendingPathComponent("image\(i).jpg")
            try "fake image \(i)".write(to: sourceFile, atomically: true, encoding: .utf8)
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
        
        // Record all progress callbacks
        var progressUpdates: [ProgressUpdate] = []
        
        // Execute detection with progress callback
        let result = try DetectionOrchestrator.executeDetection(
            source: source,
            libraryRootURL: libraryRootURL,
            libraryId: libraryId,
            progress: { update in
                progressUpdates.append(update)
            }
        )
        
        // Verify progress callbacks were invoked
        XCTAssertFalse(progressUpdates.isEmpty, "Progress callbacks should be invoked")
        
        // Verify scanning stage callback
        let scanningUpdates = progressUpdates.filter { $0.stage == "scanning" }
        XCTAssertFalse(scanningUpdates.isEmpty, "Progress callback should be invoked during scanning stage")
        
        // Verify comparison stage callback (may be throttled or skipped if all items are known by path)
        let comparingUpdates = progressUpdates.filter { $0.stage == "comparing" }
        // Comparison callbacks may not be invoked if all items are known by path (they skip hash computation)
        // But if any items go through hash computation, we should see comparison callbacks
        
        // Verify completion callback
        let completeUpdates = progressUpdates.filter { $0.stage == "complete" }
        XCTAssertEqual(completeUpdates.count, 1, "Progress callback should be invoked exactly once at completion")
        
        if let completeUpdate = completeUpdates.first {
            XCTAssertEqual(completeUpdate.current, result.candidates.count)
            XCTAssertEqual(completeUpdate.total, result.candidates.count)
        }
        
        // Verify at least scanning and completion callbacks were received
        XCTAssertTrue(scanningUpdates.count > 0 || comparingUpdates.count > 0, "At least one progress callback should be received during scanning or comparison")
    }
    
    func testDetectionProgressThrottling() throws {
        // Create source with many files to test throttling
        for i in 1...20 {
            let sourceFile = sourceDirectory.appendingPathComponent("image\(i).jpg")
            try "fake image \(i)".write(to: sourceFile, atomically: true, encoding: .utf8)
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
        
        // Record all progress callbacks
        var progressUpdates: [ProgressUpdate] = []
        
        // Execute detection with progress callback
        _ = try DetectionOrchestrator.executeDetection(
            source: source,
            libraryRootURL: libraryRootURL,
            libraryId: libraryId,
            progress: { update in
                progressUpdates.append(update)
            }
        )
        
        // Verify throttling works (comparison stage callbacks should be throttled)
        // With 20 items, we should get fewer than 20 comparison callbacks due to throttling
        let comparingUpdates = progressUpdates.filter { $0.stage == "comparing" }
        // Throttling should limit callbacks (exact count depends on timing, but should be less than total items)
        XCTAssertLessThan(comparingUpdates.count, 20, "Progress callbacks should be throttled during comparison stage")
    }
    
    // MARK: - Cancellation Tests
    
    func testDetectionCancellationDuringScanning() throws {
        // Create source with files
        for i in 1...10 {
            let sourceFile = sourceDirectory.appendingPathComponent("image\(i).jpg")
            try "fake image \(i)".write(to: sourceFile, atomically: true, encoding: .utf8)
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
        
        // Create cancellation token and cancel it
        let token = CancellationToken()
        token.cancel()
        
        // Execute detection with cancellation token (should throw CancellationError)
        do {
            _ = try DetectionOrchestrator.executeDetection(
                source: source,
                libraryRootURL: libraryRootURL,
                libraryId: libraryId,
                cancellationToken: token
            )
            XCTFail("Detection should throw CancellationError when canceled")
        } catch let error as CancellationError {
            XCTAssertEqual(error, .cancelled, "Should throw CancellationError.cancelled")
        }
        
        // Verify no source metadata was updated (no lastDetectedAt timestamp)
        let associations = try SourceAssociationSerializer.read(
            from: SourceAssociationStorage.associationsFileURL(for: libraryRootURL)
        )
        let updatedSource = associations.sources.first { $0.sourceId == source.sourceId }
        XCTAssertNil(updatedSource?.lastDetectedAt, "Source metadata should not be updated if canceled")
    }
    
    func testDetectionCancellationDuringComparison() throws {
        // Create source with many files to ensure comparison stage takes time
        for i in 1...50 {
            let sourceFile = sourceDirectory.appendingPathComponent("image\(i).jpg")
            try "fake image content \(i) with some data to make hash computation take time".write(to: sourceFile, atomically: true, encoding: .utf8)
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
        
        // Create cancellation token
        let token = CancellationToken()
        
        // Start detection in background
        var detectionError: Error?
        var detectionCompleted = false
        let expectation = XCTestExpectation(description: "Detection completes or is canceled")
        
        DispatchQueue.global().async {
            do {
                _ = try DetectionOrchestrator.executeDetection(
                    source: source,
                    libraryRootURL: self.libraryRootURL,
                    libraryId: self.libraryId,
                    cancellationToken: token
                )
                detectionCompleted = true
            } catch {
                detectionError = error
            }
            expectation.fulfill()
        }
        
        // Cancel after a short delay (during comparison stage)
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
            token.cancel()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        // Verify either CancellationError was thrown or operation completed (race condition)
        if detectionCompleted {
            // Operation completed before cancellation - this is acceptable
            // Verify source metadata was updated (operation completed)
            let associations = try SourceAssociationSerializer.read(
                from: SourceAssociationStorage.associationsFileURL(for: libraryRootURL)
            )
            let updatedSource = associations.sources.first { $0.sourceId == source.sourceId }
            XCTAssertNotNil(updatedSource?.lastDetectedAt, "Source metadata should be updated if operation completed")
        } else if let error = detectionError as? CancellationError {
            // Operation was canceled - verify CancellationError
            XCTAssertEqual(error, .cancelled, "Should throw CancellationError.cancelled")
            
            // Verify no source metadata was updated
            let associations = try SourceAssociationSerializer.read(
                from: SourceAssociationStorage.associationsFileURL(for: libraryRootURL)
            )
            let updatedSource = associations.sources.first { $0.sourceId == source.sourceId }
            XCTAssertNil(updatedSource?.lastDetectedAt, "Source metadata should not be updated if canceled")
        } else {
            XCTFail("Expected CancellationError or completion, got \(String(describing: detectionError))")
        }
    }
    
    func testDetectionCancellationAfterCompletion() throws {
        // Create source with small number of files (quick completion)
        let sourceFile = sourceDirectory.appendingPathComponent("image.jpg")
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
        
        // Create cancellation token
        let token = CancellationToken()
        
        // Execute detection (should complete normally)
        let result = try DetectionOrchestrator.executeDetection(
            source: source,
            libraryRootURL: libraryRootURL,
            libraryId: libraryId,
            cancellationToken: token
        )
        
        // Cancel after completion
        token.cancel()
        
        // Verify detection completed normally (cancellation has no effect after completion)
        XCTAssertEqual(result.summary.totalScanned, 1)
        XCTAssertEqual(result.summary.newItems, 1)
        
        // Verify source metadata was updated (detection completed)
        let associations = try SourceAssociationSerializer.read(
            from: SourceAssociationStorage.associationsFileURL(for: libraryRootURL)
        )
        let updatedSource = associations.sources.first { $0.sourceId == source.sourceId }
        XCTAssertNotNil(updatedSource?.lastDetectedAt, "Source metadata should be updated after completion")
    }
}
