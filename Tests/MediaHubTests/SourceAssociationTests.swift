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
}
