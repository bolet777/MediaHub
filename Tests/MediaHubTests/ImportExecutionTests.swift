//
//  ImportExecutionTests.swift
//  MediaHubTests
//
//  Integration tests for import execution
//

import XCTest
@testable import MediaHub

final class ImportExecutionTests: XCTestCase {
    var libraryRootURL: URL!
    var sourceRootURL: URL!
    var libraryId: String!
    var source: Source!
    
    override func setUp() {
        super.setUp()
        
        // Create library
        libraryRootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Library-\(UUID().uuidString)")
        libraryId = UUID().uuidString
        
        // Create source
        sourceRootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Source-\(UUID().uuidString)")
        source = Source(
            sourceId: UUID().uuidString,
            type: .folder,
            path: sourceRootURL.path
        )
        
        // Create directories
        try? FileManager.default.createDirectory(at: libraryRootURL, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: sourceRootURL, withIntermediateDirectories: true)
        
        // Create library structure
        try? FileManager.default.createDirectory(
            at: libraryRootURL.appendingPathComponent(".mediahub"),
            withIntermediateDirectories: true
        )
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: libraryRootURL)
        try? FileManager.default.removeItem(at: sourceRootURL)
        super.tearDown()
    }
    
    func testExecuteImport() throws {
        // Create source file
        let sourceFile = sourceRootURL.appendingPathComponent("test.jpg")
        try "test content".write(to: sourceFile, atomically: true, encoding: .utf8)
        
        // Create detection result
        let candidate = CandidateMediaItem(
            path: sourceFile.path,
            size: 1024,
            modificationDate: ISO8601DateFormatter().string(from: Date()),
            fileName: "test.jpg"
        )
        
        let detectionResult = DetectionResult(
            sourceId: source.sourceId,
            libraryId: libraryId,
            candidates: [
                CandidateItemResult(item: candidate, status: "new")
            ],
            summary: DetectionSummary(totalScanned: 1, newItems: 1, knownItems: 0)
        )
        
        // Execute import
        let options = ImportOptions(collisionPolicy: .rename)
        let importResult = try ImportExecutor.executeImport(
            detectionResult: detectionResult,
            selectedItems: [candidate],
            libraryRootURL: libraryRootURL,
            libraryId: libraryId,
            options: options
        )
        
        // Verify import result
        XCTAssertEqual(importResult.summary.total, 1)
        XCTAssertEqual(importResult.summary.imported, 1)
        XCTAssertEqual(importResult.summary.skipped, 0)
        XCTAssertEqual(importResult.summary.failed, 0)
        
        // Verify file was copied
        let importedItems = importResult.items.filter { $0.status == .imported }
        XCTAssertEqual(importedItems.count, 1)
        
        if let importedItem = importedItems.first,
           let destinationPath = importedItem.destinationPath {
            let destinationURL = libraryRootURL.appendingPathComponent(destinationPath)
            XCTAssertTrue(FileManager.default.fileExists(atPath: destinationURL.path))
        }
        
        // Verify source file is unchanged
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceFile.path))
        let sourceContent = try String(contentsOf: sourceFile, encoding: .utf8)
        XCTAssertEqual(sourceContent, "test content")
    }
    
    func testExecuteImportWithCollisionSkip() throws {
        // Create source file
        let sourceFile = sourceRootURL.appendingPathComponent("test.jpg")
        try "test content".write(to: sourceFile, atomically: true, encoding: .utf8)
        
        // Create existing file in library (collision)
        let yearMonthDir = libraryRootURL.appendingPathComponent("2026").appendingPathComponent("01")
        try? FileManager.default.createDirectory(at: yearMonthDir, withIntermediateDirectories: true)
        let existingFile = yearMonthDir.appendingPathComponent("test.jpg")
        try "existing".write(to: existingFile, atomically: true, encoding: .utf8)
        
        // Create detection result
        let candidate = CandidateMediaItem(
            path: sourceFile.path,
            size: 1024,
            modificationDate: ISO8601DateFormatter().string(from: Date()),
            fileName: "test.jpg"
        )
        
        let detectionResult = DetectionResult(
            sourceId: source.sourceId,
            libraryId: libraryId,
            candidates: [
                CandidateItemResult(item: candidate, status: "new")
            ],
            summary: DetectionSummary(totalScanned: 1, newItems: 1, knownItems: 0)
        )
        
        // Execute import with skip policy
        let options = ImportOptions(collisionPolicy: .skip)
        let importResult = try ImportExecutor.executeImport(
            detectionResult: detectionResult,
            selectedItems: [candidate],
            libraryRootURL: libraryRootURL,
            libraryId: libraryId,
            options: options
        )
        
        // Verify import result
        XCTAssertEqual(importResult.summary.skipped, 1)
        XCTAssertEqual(importResult.summary.imported, 0)
        
        // Verify existing file is unchanged
        let existingContent = try String(contentsOf: existingFile, encoding: .utf8)
        XCTAssertEqual(existingContent, "existing")
    }
    
    func testExecuteImportUpdatesKnownItems() throws {
        // Create source file
        let sourceFile = sourceRootURL.appendingPathComponent("test.jpg")
        try "test content".write(to: sourceFile, atomically: true, encoding: .utf8)
        
        // Create detection result
        let candidate = CandidateMediaItem(
            path: sourceFile.path,
            size: 1024,
            modificationDate: ISO8601DateFormatter().string(from: Date()),
            fileName: "test.jpg"
        )
        
        let detectionResult = DetectionResult(
            sourceId: source.sourceId,
            libraryId: libraryId,
            candidates: [
                CandidateItemResult(item: candidate, status: "new")
            ],
            summary: DetectionSummary(totalScanned: 1, newItems: 1, knownItems: 0)
        )
        
        // Execute import
        let options = ImportOptions(collisionPolicy: .rename)
        _ = try ImportExecutor.executeImport(
            detectionResult: detectionResult,
            selectedItems: [candidate],
            libraryRootURL: libraryRootURL,
            libraryId: libraryId,
            options: options
        )
        
        // Query known items
        let knownItems = try KnownItemsTracker.queryKnownItems(
            sourceId: source.sourceId,
            libraryRootURL: libraryRootURL
        )
        
        // Verify item is in known items
        XCTAssertTrue(knownItems.contains(sourceFile.path))
    }
}
