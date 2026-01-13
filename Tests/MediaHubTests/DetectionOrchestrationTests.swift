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
}
