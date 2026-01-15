//
//  SourceAssociationTests.swift
//  MediaHubTests
//
//  Tests for Source-Library association persistence
//

import XCTest
@testable import MediaHub

final class SourceAssociationTests: XCTestCase {
    var tempDirectory: URL!
    var libraryRootURL: URL!
    let libraryId = LibraryIdentifierGenerator.generate()
    
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
    
    func testAttachSource() throws {
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: "/test/source"
        )
        
        try SourceAssociationManager.attach(
            source: source,
            to: libraryRootURL,
            libraryId: libraryId
        )
        
        let sources = try SourceAssociationManager.retrieveSources(
            for: libraryRootURL,
            libraryId: libraryId
        )
        
        XCTAssertEqual(sources.count, 1)
        XCTAssertEqual(sources[0].sourceId, source.sourceId)
    }
    
    func testAttachMultipleSources() throws {
        let source1 = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: "/test/source1"
        )
        let source2 = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: "/test/source2"
        )
        
        try SourceAssociationManager.attach(
            source: source1,
            to: libraryRootURL,
            libraryId: libraryId
        )
        try SourceAssociationManager.attach(
            source: source2,
            to: libraryRootURL,
            libraryId: libraryId
        )
        
        let sources = try SourceAssociationManager.retrieveSources(
            for: libraryRootURL,
            libraryId: libraryId
        )
        
        XCTAssertEqual(sources.count, 2)
    }
    
    func testDetachSource() throws {
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: "/test/source"
        )
        
        try SourceAssociationManager.attach(
            source: source,
            to: libraryRootURL,
            libraryId: libraryId
        )
        
        try SourceAssociationManager.detach(
            sourceId: source.sourceId,
            from: libraryRootURL,
            libraryId: libraryId
        )
        
        let sources = try SourceAssociationManager.retrieveSources(
            for: libraryRootURL,
            libraryId: libraryId
        )
        
        XCTAssertEqual(sources.count, 0)
    }
    
    func testAssociationPersistence() throws {
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: "/test/source"
        )
        
        try SourceAssociationManager.attach(
            source: source,
            to: libraryRootURL,
            libraryId: libraryId
        )
        
        // Retrieve again (simulating app restart)
        let sources = try SourceAssociationManager.retrieveSources(
            for: libraryRootURL,
            libraryId: libraryId
        )
        
        XCTAssertEqual(sources.count, 1)
        XCTAssertEqual(sources[0].sourceId, source.sourceId)
    }
    
    func testRetrieveSourcesWhenNoneExist() throws {
        let sources = try SourceAssociationManager.retrieveSources(
            for: libraryRootURL,
            libraryId: libraryId
        )
        
        XCTAssertEqual(sources.count, 0)
    }
    
    func testDuplicateSourceAttachment() throws {
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: "/test/source"
        )
        
        try SourceAssociationManager.attach(
            source: source,
            to: libraryRootURL,
            libraryId: libraryId
        )
        
        // Try to attach same source again
        XCTAssertThrowsError(
            try SourceAssociationManager.attach(
                source: source,
                to: libraryRootURL,
                libraryId: libraryId
            )
        ) { error in
            XCTAssertTrue(error is SourceAssociationError)
            if case .duplicateSource(let sourceId) = error as? SourceAssociationError {
                XCTAssertEqual(sourceId, source.sourceId)
            } else {
                XCTFail("Expected duplicateSource error")
            }
        }
    }
    
    // MARK: - Media Types Persistence Tests
    
    func testAssociationPersistenceWithMediaTypes() throws {
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: "/test/source",
            mediaTypes: .images
        )
        
        try SourceAssociationManager.attach(
            source: source,
            to: libraryRootURL,
            libraryId: libraryId
        )
        
        // Retrieve again (simulating app restart)
        let sources = try SourceAssociationManager.retrieveSources(
            for: libraryRootURL,
            libraryId: libraryId
        )
        
        XCTAssertEqual(sources.count, 1)
        XCTAssertEqual(sources[0].sourceId, source.sourceId)
        XCTAssertEqual(sources[0].mediaTypes, .images)
        XCTAssertEqual(sources[0].effectiveMediaTypes, .images)
    }
    
    func testAssociationPersistenceWithoutMediaTypes() throws {
        // Test backward compatibility: Source without mediaTypes field persists and loads correctly
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: "/test/source"
            // mediaTypes is nil (default)
        )
        
        try SourceAssociationManager.attach(
            source: source,
            to: libraryRootURL,
            libraryId: libraryId
        )
        
        // Retrieve again (simulating app restart)
        let sources = try SourceAssociationManager.retrieveSources(
            for: libraryRootURL,
            libraryId: libraryId
        )
        
        XCTAssertEqual(sources.count, 1)
        XCTAssertEqual(sources[0].sourceId, source.sourceId)
        XCTAssertNil(sources[0].mediaTypes)
        XCTAssertEqual(sources[0].effectiveMediaTypes, .both) // Default behavior
    }
    
    func testAssociationRoundTripWithMediaTypes() throws {
        let source1 = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: "/test/source1",
            mediaTypes: .videos
        )
        let source2 = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: "/test/source2",
            mediaTypes: .both
        )
        let source3 = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: "/test/source3"
            // mediaTypes is nil
        )
        
        try SourceAssociationManager.attach(
            source: source1,
            to: libraryRootURL,
            libraryId: libraryId
        )
        try SourceAssociationManager.attach(
            source: source2,
            to: libraryRootURL,
            libraryId: libraryId
        )
        try SourceAssociationManager.attach(
            source: source3,
            to: libraryRootURL,
            libraryId: libraryId
        )
        
        // Retrieve and verify all mediaTypes are preserved
        let sources = try SourceAssociationManager.retrieveSources(
            for: libraryRootURL,
            libraryId: libraryId
        )
        
        XCTAssertEqual(sources.count, 3)
        
        let retrievedSource1 = sources.first(where: { $0.sourceId == source1.sourceId })!
        XCTAssertEqual(retrievedSource1.mediaTypes, .videos)
        XCTAssertEqual(retrievedSource1.effectiveMediaTypes, .videos)
        
        let retrievedSource2 = sources.first(where: { $0.sourceId == source2.sourceId })!
        XCTAssertEqual(retrievedSource2.mediaTypes, .both)
        XCTAssertEqual(retrievedSource2.effectiveMediaTypes, .both)
        
        let retrievedSource3 = sources.first(where: { $0.sourceId == source3.sourceId })!
        XCTAssertNil(retrievedSource3.mediaTypes)
        XCTAssertEqual(retrievedSource3.effectiveMediaTypes, .both)
    }
    
    func testAssociationDeserializationWithoutMediaTypesField() throws {
        // Test backward compatibility: Association file without mediaTypes field loads successfully
        // This simulates an association file created before Slice 10
        
        let sourceId = SourceIdentifierGenerator.generate()
        let json = """
        {
            "version": "1.0",
            "libraryId": "\(libraryId)",
            "sources": [
                {
                    "sourceId": "\(sourceId)",
                    "type": "folder",
                    "path": "/test/source",
                    "attachedAt": "2026-01-27T00:00:00Z"
                }
            ]
        }
        """
        
        let fileURL = SourceAssociationStorage.associationsFileURL(for: libraryRootURL)
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try json.data(using: .utf8)!.write(to: fileURL)
        
        // Load the association
        let sources = try SourceAssociationManager.retrieveSources(
            for: libraryRootURL,
            libraryId: libraryId
        )
        
        XCTAssertEqual(sources.count, 1)
        XCTAssertEqual(sources[0].sourceId, sourceId)
        XCTAssertNil(sources[0].mediaTypes) // Field absent, should be nil
        XCTAssertEqual(sources[0].effectiveMediaTypes, .both) // Defaults to .both
    }
    
    // MARK: - Task 9: Edge Cases and Error Handling
    
    func testInvalidMediaTypesValueRejectedDuringDecoding() throws {
        // Test that invalid mediaTypes values are rejected during decoding (Option 2: error, not fallback)
        // This simulates a corrupted association file with invalid mediaTypes value
        let sourceId = SourceIdentifierGenerator.generate()
        let json = """
        {
            "version": "1.0",
            "libraryId": "\(libraryId)",
            "sources": [
                {
                    "sourceId": "\(sourceId)",
                    "type": "folder",
                    "path": "/test/source",
                    "attachedAt": "2026-01-27T00:00:00Z",
                    "mediaTypes": "invalid_value"
                }
            ]
        }
        """
        
        let fileURL = SourceAssociationStorage.associationsFileURL(for: libraryRootURL)
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try json.data(using: .utf8)!.write(to: fileURL)
        
        // Attempt to load association - should fail with decoding error (Option 2: error, not silent fallback)
        XCTAssertThrowsError(try SourceAssociationManager.retrieveSources(
            for: libraryRootURL,
            libraryId: libraryId
        )) { error in
            // Enum decoding rejects invalid raw string values (Option 2 behavior)
            XCTAssertTrue(error is SourceAssociationError)
            if case .decodingError(let underlyingError) = error as? SourceAssociationError {
                // Underlying error should be a DecodingError
                XCTAssertTrue(underlyingError is DecodingError)
            } else {
                XCTFail("Expected decodingError with DecodingError")
            }
        }
    }
    
    func testUpdateSourceLastDetectedPreservesMediaTypes() throws {
        // Test that updateSourceLastDetected preserves mediaTypes field
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: "/test/source",
            mediaTypes: .videos
        )
        
        try SourceAssociationManager.attach(
            source: source,
            to: libraryRootURL,
            libraryId: libraryId
        )
        
        // Simulate detection update (this would normally be called by DetectionOrchestrator)
        // We'll manually update lastDetectedAt to test mediaTypes preservation
        let fileURL = SourceAssociationStorage.associationsFileURL(for: libraryRootURL)
        var association = try SourceAssociationSerializer.read(from: fileURL)
        
        guard let index = association.sources.firstIndex(where: { $0.sourceId == source.sourceId }) else {
            XCTFail("Source not found")
            return
        }
        
        // Update source with new lastDetectedAt (preserve mediaTypes)
        let updatedSource = Source(
            sourceId: association.sources[index].sourceId,
            type: association.sources[index].type,
            path: association.sources[index].path,
            attachedAt: association.sources[index].attachedAt,
            lastDetectedAt: "2026-01-27T12:00:00Z",
            mediaTypes: association.sources[index].mediaTypes
        )
        
        association.sources[index] = updatedSource
        try SourceAssociationSerializer.write(association, to: fileURL)
        
        // Verify mediaTypes is preserved
        let sources = try SourceAssociationManager.retrieveSources(
            for: libraryRootURL,
            libraryId: libraryId
        )
        
        let retrievedSource = sources.first { $0.sourceId == source.sourceId }
        XCTAssertNotNil(retrievedSource)
        XCTAssertEqual(retrievedSource?.mediaTypes, .videos, "mediaTypes should be preserved after update")
        XCTAssertEqual(retrievedSource?.lastDetectedAt, "2026-01-27T12:00:00Z")
    }
}
