//
//  ImportResultTests.swift
//  MediaHubTests
//
//  Tests for import result model and storage
//

import XCTest
@testable import MediaHub

final class ImportResultTests: XCTestCase {
    var libraryRootURL: URL!
    let sourceId = UUID().uuidString
    let libraryId = UUID().uuidString
    
    override func setUp() {
        super.setUp()
        libraryRootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        
        // Create library structure
        try? FileManager.default.createDirectory(
            at: libraryRootURL.appendingPathComponent(".mediahub"),
            withIntermediateDirectories: true
        )
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: libraryRootURL)
        super.tearDown()
    }
    
    func testImportResultValidation() {
        // Create valid import result
        let items = [
            ImportItemResult(
                sourcePath: "/source/path1.jpg",
                destinationPath: "2026/01/path1.jpg",
                status: .imported
            ),
            ImportItemResult(
                sourcePath: "/source/path2.jpg",
                status: .skipped,
                reason: "File already exists"
            )
        ]
        
        let summary = ImportSummary(total: 2, imported: 1, skipped: 1, failed: 0)
        let options = ImportOptions(collisionPolicy: .rename)
        
        let result = ImportResult(
            sourceId: sourceId,
            libraryId: libraryId,
            options: options,
            items: items,
            summary: summary
        )
        
        // Verify result is valid
        XCTAssertTrue(result.isValid())
    }
    
    func testImportResultSerialization() throws {
        // Create import result
        let items = [
            ImportItemResult(
                sourcePath: "/source/path1.jpg",
                destinationPath: "2026/01/path1.jpg",
                status: .imported
            )
        ]
        
        let summary = ImportSummary(total: 1, imported: 1, skipped: 0, failed: 0)
        let options = ImportOptions(collisionPolicy: .rename)
        
        let result = ImportResult(
            sourceId: sourceId,
            libraryId: libraryId,
            options: options,
            items: items,
            summary: summary
        )
        
        // Serialize
        let data = try ImportResultSerializer.serialize(result)
        
        // Deserialize
        let deserialized = try ImportResultSerializer.deserialize(data)
        
        // Verify deserialized result matches
        XCTAssertEqual(deserialized.sourceId, result.sourceId)
        XCTAssertEqual(deserialized.libraryId, result.libraryId)
        XCTAssertEqual(deserialized.items.count, result.items.count)
    }
    
    func testImportResultStorage() throws {
        // Create import result
        let items = [
            ImportItemResult(
                sourcePath: "/source/path1.jpg",
                destinationPath: "2026/01/path1.jpg",
                status: .imported
            )
        ]
        
        let summary = ImportSummary(total: 1, imported: 1, skipped: 0, failed: 0)
        let options = ImportOptions(collisionPolicy: .rename)
        
        let result = ImportResult(
            sourceId: sourceId,
            libraryId: libraryId,
            options: options,
            items: items,
            summary: summary
        )
        
        // Write to file
        let fileURL = ImportResultStorage.resultFileURL(
            for: libraryRootURL,
            sourceId: sourceId,
            timestamp: result.importedAt
        )
        
        try ImportResultSerializer.write(result, to: fileURL)
        
        // Read from file
        let readResult = try ImportResultSerializer.read(from: fileURL)
        
        // Verify read result matches
        XCTAssertEqual(readResult.sourceId, result.sourceId)
        XCTAssertEqual(readResult.items.count, result.items.count)
    }
}
