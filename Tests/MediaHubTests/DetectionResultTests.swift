//
//  DetectionResultTests.swift
//  MediaHubTests
//
//  Tests for Detection result model and storage
//

import XCTest
@testable import MediaHub

final class DetectionResultTests: XCTestCase {
    var tempDirectory: URL!
    var libraryRootURL: URL!
    let libraryId = LibraryIdentifierGenerator.generate()
    let sourceId = SourceIdentifierGenerator.generate()
    
    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        libraryRootURL = tempDirectory.appendingPathComponent("TestLibrary")
        
        // Create library structure
        try! FileManager.default.createDirectory(at: libraryRootURL, withIntermediateDirectories: true)
        try! LibraryStructureCreator.createStructure(at: libraryRootURL)
        
        // Create library metadata
        let metadata = LibraryMetadata(libraryId: libraryId, rootPath: libraryRootURL.path)
        let metadataURL = LibraryStructureCreator.metadataFileURL(for: libraryRootURL)
        try! LibraryMetadataSerializer.write(metadata, to: metadataURL)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    func testDetectionResultCreation() {
        let candidate = CandidateItemResult(
            item: CandidateMediaItem(
                path: "/test/item.jpg",
                size: 1000,
                modificationDate: ISO8601DateFormatter().string(from: Date()),
                fileName: "item.jpg"
            ),
            status: "new",
            exclusionReason: nil
        )
        
        let summary = DetectionSummary(
            totalScanned: 1,
            newItems: 1,
            knownItems: 0
        )
        
        let result = DetectionResult(
            sourceId: sourceId,
            libraryId: libraryId,
            candidates: [candidate],
            summary: summary
        )
        
        XCTAssertEqual(result.sourceId, sourceId)
        XCTAssertEqual(result.libraryId, libraryId)
        XCTAssertEqual(result.candidates.count, 1)
        XCTAssertEqual(result.summary.totalScanned, 1)
    }
    
    func testDetectionResultValidation() {
        let candidate = CandidateItemResult(
            item: CandidateMediaItem(
                path: "/test/item.jpg",
                size: 1000,
                modificationDate: ISO8601DateFormatter().string(from: Date()),
                fileName: "item.jpg"
            ),
            status: "new"
        )
        
        let summary = DetectionSummary(
            totalScanned: 1,
            newItems: 1,
            knownItems: 0
        )
        
        let result = DetectionResult(
            sourceId: sourceId,
            libraryId: libraryId,
            candidates: [candidate],
            summary: summary
        )
        
        XCTAssertTrue(result.isValid())
    }
    
    func testDetectionResultSerialization() throws {
        let candidate = CandidateItemResult(
            item: CandidateMediaItem(
                path: "/test/item.jpg",
                size: 1000,
                modificationDate: ISO8601DateFormatter().string(from: Date()),
                fileName: "item.jpg"
            ),
            status: "new"
        )
        
        let summary = DetectionSummary(
            totalScanned: 1,
            newItems: 1,
            knownItems: 0
        )
        
        let result = DetectionResult(
            sourceId: sourceId,
            libraryId: libraryId,
            candidates: [candidate],
            summary: summary
        )
        
        let data = try DetectionResultSerializer.serialize(result)
        let deserialized = try DetectionResultSerializer.deserialize(data)
        
        XCTAssertEqual(deserialized.sourceId, result.sourceId)
        XCTAssertEqual(deserialized.libraryId, result.libraryId)
        XCTAssertEqual(deserialized.candidates.count, result.candidates.count)
    }
    
    func testDetectionResultStorage() throws {
        let candidate = CandidateItemResult(
            item: CandidateMediaItem(
                path: "/test/item.jpg",
                size: 1000,
                modificationDate: ISO8601DateFormatter().string(from: Date()),
                fileName: "item.jpg"
            ),
            status: "new"
        )
        
        let summary = DetectionSummary(
            totalScanned: 1,
            newItems: 1,
            knownItems: 0
        )
        
        let result = DetectionResult(
            sourceId: sourceId,
            libraryId: libraryId,
            candidates: [candidate],
            summary: summary
        )
        
        let fileURL = DetectionResultStorage.resultFileURL(
            for: libraryRootURL,
            sourceId: sourceId,
            timestamp: result.detectedAt
        )
        
        try DetectionResultSerializer.write(result, to: fileURL)
        
        let retrieved = try DetectionResultSerializer.read(from: fileURL)
        
        XCTAssertEqual(retrieved.sourceId, result.sourceId)
        XCTAssertEqual(retrieved.libraryId, result.libraryId)
    }
    
    func testDetectionResultRetrieval() throws {
        let candidate = CandidateItemResult(
            item: CandidateMediaItem(
                path: "/test/item.jpg",
                size: 1000,
                modificationDate: ISO8601DateFormatter().string(from: Date()),
                fileName: "item.jpg"
            ),
            status: "new"
        )
        
        let summary = DetectionSummary(
            totalScanned: 1,
            newItems: 1,
            knownItems: 0
        )
        
        let result = DetectionResult(
            sourceId: sourceId,
            libraryId: libraryId,
            candidates: [candidate],
            summary: summary
        )
        
        let fileURL = DetectionResultStorage.resultFileURL(
            for: libraryRootURL,
            sourceId: sourceId,
            timestamp: result.detectedAt
        )
        
        try DetectionResultSerializer.write(result, to: fileURL)
        
        let allResults = try DetectionResultRetriever.retrieveAll(
            for: libraryRootURL,
            sourceId: sourceId
        )
        
        XCTAssertEqual(allResults.count, 1)
        
        let latest = try DetectionResultRetriever.retrieveLatest(
            for: libraryRootURL,
            sourceId: sourceId
        )
        
        XCTAssertNotNil(latest)
        XCTAssertEqual(latest?.sourceId, sourceId)
    }
    
    func testDetectionResultComparison() {
        let candidate1 = CandidateItemResult(
            item: CandidateMediaItem(
                path: "/test/item1.jpg",
                size: 1000,
                modificationDate: ISO8601DateFormatter().string(from: Date()),
                fileName: "item1.jpg"
            ),
            status: "new"
        )
        
        let candidate2 = CandidateItemResult(
            item: CandidateMediaItem(
                path: "/test/item2.jpg",
                size: 1000,
                modificationDate: ISO8601DateFormatter().string(from: Date()),
                fileName: "item2.jpg"
            ),
            status: "new"
        )
        
        let result1 = DetectionResult(
            sourceId: sourceId,
            libraryId: libraryId,
            candidates: [candidate1],
            summary: DetectionSummary(totalScanned: 1, newItems: 1, knownItems: 0)
        )
        
        let result2 = DetectionResult(
            sourceId: sourceId,
            libraryId: libraryId,
            candidates: [candidate1, candidate2],
            summary: DetectionSummary(totalScanned: 2, newItems: 2, knownItems: 0)
        )
        
        let differences = DetectionResultComparator.compare(result1, result2)
        
        XCTAssertNotNil(differences["totalScanned"])
        XCTAssertNotNil(differences["newItems"])
        XCTAssertNotNil(differences["addedItems"])
    }
}
