//
//  SourceTests.swift
//  MediaHubTests
//
//  Tests for Source model and identity
//

import XCTest
@testable import MediaHub

final class SourceTests: XCTestCase {
    
    func testSourceInitialization() {
        let sourceId = SourceIdentifierGenerator.generate()
        let source = Source(
            sourceId: sourceId,
            type: .folder,
            path: "/test/path"
        )
        
        XCTAssertEqual(source.sourceId, sourceId)
        XCTAssertEqual(source.type, .folder)
        XCTAssertEqual(source.path, "/test/path")
        XCTAssertNotNil(source.attachedAt)
        XCTAssertNil(source.lastDetectedAt)
    }
    
    func testSourceValidation() {
        let validSource = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: "/test/path"
        )
        
        XCTAssertTrue(validSource.isValid())
    }
    
    func testSourceValidationInvalidUUID() {
        let invalidSource = Source(
            sourceId: "not-a-uuid",
            type: .folder,
            path: "/test/path"
        )
        
        XCTAssertFalse(invalidSource.isValid())
    }
    
    func testSourceValidationInvalidPath() {
        let invalidSource = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: "relative/path" // Not absolute
        )
        
        XCTAssertFalse(invalidSource.isValid())
    }
    
    func testSourceIdentifierGeneration() {
        let id1 = SourceIdentifierGenerator.generate()
        let id2 = SourceIdentifierGenerator.generate()
        
        XCTAssertNotEqual(id1, id2)
        XCTAssertTrue(SourceIdentifierGenerator.isValid(id1))
        XCTAssertTrue(SourceIdentifierGenerator.isValid(id2))
    }
    
    func testSourceIdentifierValidation() {
        XCTAssertTrue(SourceIdentifierGenerator.isValid(UUID().uuidString))
        XCTAssertFalse(SourceIdentifierGenerator.isValid("not-a-uuid"))
        XCTAssertFalse(SourceIdentifierGenerator.isValid(""))
    }
}
