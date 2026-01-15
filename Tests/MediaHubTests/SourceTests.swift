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
    
    // MARK: - Media Types Tests
    
    func testSourceWithMediaTypesImages() {
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: "/test/path",
            mediaTypes: .images
        )
        
        XCTAssertEqual(source.mediaTypes, .images)
        XCTAssertEqual(source.effectiveMediaTypes, .images)
    }
    
    func testSourceWithMediaTypesVideos() {
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: "/test/path",
            mediaTypes: .videos
        )
        
        XCTAssertEqual(source.mediaTypes, .videos)
        XCTAssertEqual(source.effectiveMediaTypes, .videos)
    }
    
    func testSourceWithMediaTypesBoth() {
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: "/test/path",
            mediaTypes: .both
        )
        
        XCTAssertEqual(source.mediaTypes, .both)
        XCTAssertEqual(source.effectiveMediaTypes, .both)
    }
    
    func testSourceWithoutMediaTypesDefaultsToBoth() {
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: "/test/path"
        )
        
        XCTAssertNil(source.mediaTypes)
        XCTAssertEqual(source.effectiveMediaTypes, .both)
    }
    
    func testSourceMediaTypesCodableEncoding() throws {
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: "/test/path",
            mediaTypes: .images
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(source)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        XCTAssertNotNil(json)
        XCTAssertEqual(json?["mediaTypes"] as? String, "images")
    }
    
    func testSourceMediaTypesCodableDecoding() throws {
        let json = """
        {
            "sourceId": "\(UUID().uuidString)",
            "type": "folder",
            "path": "/test/path",
            "attachedAt": "2026-01-27T00:00:00Z",
            "mediaTypes": "videos"
        }
        """
        
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let source = try decoder.decode(Source.self, from: data)
        
        XCTAssertEqual(source.mediaTypes, .videos)
        XCTAssertEqual(source.effectiveMediaTypes, .videos)
    }
    
    func testSourceMediaTypesCodableDecodingWithoutField() throws {
        // Test backward compatibility: Source without mediaTypes field defaults to .both
        let json = """
        {
            "sourceId": "\(UUID().uuidString)",
            "type": "folder",
            "path": "/test/path",
            "attachedAt": "2026-01-27T00:00:00Z"
        }
        """
        
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let source = try decoder.decode(Source.self, from: data)
        
        XCTAssertNil(source.mediaTypes)
        XCTAssertEqual(source.effectiveMediaTypes, .both)
    }
    
    func testSourceMediaTypesCodableRoundTrip() throws {
        let originalSource = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: "/test/path",
            mediaTypes: .both
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalSource)
        
        let decoder = JSONDecoder()
        let decodedSource = try decoder.decode(Source.self, from: data)
        
        XCTAssertEqual(decodedSource.mediaTypes, originalSource.mediaTypes)
        XCTAssertEqual(decodedSource.effectiveMediaTypes, originalSource.effectiveMediaTypes)
    }
    
    func testSourceMediaTypesInvalidEnumValueRejected() {
        let json = """
        {
            "sourceId": "\(UUID().uuidString)",
            "type": "folder",
            "path": "/test/path",
            "attachedAt": "2026-01-27T00:00:00Z",
            "mediaTypes": "invalid_value"
        }
        """
        
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        XCTAssertThrowsError(try decoder.decode(Source.self, from: data)) { error in
            // Enum decoding should reject invalid raw string values
            XCTAssertTrue(error is DecodingError)
        }
    }
}
