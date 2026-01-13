//
//  LibraryMetadataTests.swift
//  MediaHubTests
//
//  Basic tests for library metadata functionality
//

import XCTest
@testable import MediaHub

final class LibraryMetadataTests: XCTestCase {
    func testMetadataCreation() {
        let libraryId = LibraryIdentifierGenerator.generate()
        let metadata = LibraryMetadata(
            libraryId: libraryId,
            rootPath: "/test/library"
        )
        
        XCTAssertEqual(metadata.libraryId, libraryId)
        XCTAssertEqual(metadata.rootPath, "/test/library")
        XCTAssertFalse(metadata.createdAt.isEmpty)
    }
    
    func testMetadataValidation() {
        let validMetadata = LibraryMetadata(
            libraryId: LibraryIdentifierGenerator.generate(),
            rootPath: "/test/library"
        )
        
        XCTAssertTrue(validMetadata.isValid())
    }
    
    func testIdentifierGeneration() {
        let id1 = LibraryIdentifierGenerator.generate()
        let id2 = LibraryIdentifierGenerator.generate()
        
        XCTAssertNotEqual(id1, id2)
        XCTAssertTrue(LibraryIdentifierGenerator.isValid(id1))
        XCTAssertTrue(LibraryIdentifierGenerator.isValid(id2))
    }
}
