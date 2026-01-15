//
//  SourceCommandTests.swift
//  MediaHubTests
//
//  Tests for Source CLI commands
//

import XCTest
@testable import MediaHub
@testable import MediaHubCLI
import ArgumentParser

final class SourceCommandTests: XCTestCase {
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
    
    // MARK: - Media Types Flag Tests
    
    func testAttachSourceWithMediaTypesImages() throws {
        // Test attaching source with --media-types images
        var command = SourceAttachCommand()
        command.path = sourceDirectory.path
        command.library = libraryRootURL.path
        command.mediaTypes = "images"
        command.json = false
        
        try command.run()
        
        // Verify source was attached with correct mediaTypes
        let sources = try SourceAssociationManager.retrieveSources(
            for: libraryRootURL,
            libraryId: libraryId
        )
        
        XCTAssertEqual(sources.count, 1)
        XCTAssertEqual(sources[0].mediaTypes, .images)
        XCTAssertEqual(sources[0].effectiveMediaTypes, .images)
    }
    
    func testAttachSourceWithMediaTypesVideos() throws {
        // Test attaching source with --media-types videos
        var command = SourceAttachCommand()
        command.path = sourceDirectory.path
        command.library = libraryRootURL.path
        command.mediaTypes = "videos"
        command.json = false
        
        try command.run()
        
        // Verify source was attached with correct mediaTypes
        let sources = try SourceAssociationManager.retrieveSources(
            for: libraryRootURL,
            libraryId: libraryId
        )
        
        XCTAssertEqual(sources.count, 1)
        XCTAssertEqual(sources[0].mediaTypes, .videos)
        XCTAssertEqual(sources[0].effectiveMediaTypes, .videos)
    }
    
    func testAttachSourceWithMediaTypesBoth() throws {
        // Test attaching source with --media-types both
        var command = SourceAttachCommand()
        command.path = sourceDirectory.path
        command.library = libraryRootURL.path
        command.mediaTypes = "both"
        command.json = false
        
        try command.run()
        
        // Verify source was attached with correct mediaTypes
        let sources = try SourceAssociationManager.retrieveSources(
            for: libraryRootURL,
            libraryId: libraryId
        )
        
        XCTAssertEqual(sources.count, 1)
        XCTAssertEqual(sources[0].mediaTypes, .both)
        XCTAssertEqual(sources[0].effectiveMediaTypes, .both)
    }
    
    func testAttachSourceWithoutMediaTypesFlag() throws {
        // Test attaching source without --media-types flag (defaults to .both)
        var command = SourceAttachCommand()
        command.path = sourceDirectory.path
        command.library = libraryRootURL.path
        command.mediaTypes = nil // Flag omitted
        command.json = false
        
        try command.run()
        
        // Verify source was attached with nil mediaTypes (defaults to .both)
        let sources = try SourceAssociationManager.retrieveSources(
            for: libraryRootURL,
            libraryId: libraryId
        )
        
        XCTAssertEqual(sources.count, 1)
        XCTAssertNil(sources[0].mediaTypes)
        XCTAssertEqual(sources[0].effectiveMediaTypes, .both)
    }
    
    func testAttachSourceWithCaseInsensitiveMediaTypes() throws {
        // Test case-insensitive parsing: "IMAGES", "Videos", "BOTH"
        var command1 = SourceAttachCommand()
        command1.path = sourceDirectory.path
        command1.library = libraryRootURL.path
        command1.mediaTypes = "IMAGES"
        command1.json = false
        
        try command1.run()
        
        // Verify first source
        var sources = try SourceAssociationManager.retrieveSources(
            for: libraryRootURL,
            libraryId: libraryId
        )
        XCTAssertEqual(sources.count, 1)
        XCTAssertEqual(sources[0].mediaTypes, .images)
        
        // Clean up and test second case
        try SourceAssociationManager.detach(
            sourceId: sources[0].sourceId,
            from: libraryRootURL,
            libraryId: libraryId
        )
        
        var command2 = SourceAttachCommand()
        command2.path = sourceDirectory.path
        command2.library = libraryRootURL.path
        command2.mediaTypes = "Videos"
        command2.json = false
        
        try command2.run()
        
        sources = try SourceAssociationManager.retrieveSources(
            for: libraryRootURL,
            libraryId: libraryId
        )
        XCTAssertEqual(sources.count, 1)
        XCTAssertEqual(sources[0].mediaTypes, .videos)
    }
    
    func testAttachSourceWithInvalidMediaTypes() throws {
        // Test invalid media types value
        var command = SourceAttachCommand()
        command.path = sourceDirectory.path
        command.library = libraryRootURL.path
        command.mediaTypes = "invalid"
        command.json = false
        
        // Should throw error
        XCTAssertThrowsError(try command.run()) { error in
            if let cliError = error as? CLIError {
                switch cliError {
                case .invalidArgument(let message):
                    XCTAssertTrue(message.contains("Invalid media types value"))
                    XCTAssertTrue(message.contains("images, videos, both"))
                default:
                    XCTFail("Expected invalidArgument error")
                }
            } else {
                XCTFail("Expected CLIError")
            }
        }
        
        // Verify source was NOT attached
        let sources = try SourceAssociationManager.retrieveSources(
            for: libraryRootURL,
            libraryId: libraryId
        )
        XCTAssertEqual(sources.count, 0)
    }
    
    func testAttachSourceWithInvalidMediaTypesImage() throws {
        // Test invalid value "image" (should be "images")
        var command = SourceAttachCommand()
        command.path = sourceDirectory.path
        command.library = libraryRootURL.path
        command.mediaTypes = "image"
        command.json = false
        
        XCTAssertThrowsError(try command.run())
    }
    
    func testAttachSourceWithInvalidMediaTypesVideo() throws {
        // Test invalid value "video" (should be "videos")
        var command = SourceAttachCommand()
        command.path = sourceDirectory.path
        command.library = libraryRootURL.path
        command.mediaTypes = "video"
        command.json = false
        
        XCTAssertThrowsError(try command.run())
    }
    
    func testAttachSourceMediaTypesPersistence() throws {
        // Test that mediaTypes is persisted correctly
        var command = SourceAttachCommand()
        command.path = sourceDirectory.path
        command.library = libraryRootURL.path
        command.mediaTypes = "images"
        command.json = false
        
        try command.run()
        
        // Retrieve sources (simulating app restart)
        let sources = try SourceAssociationManager.retrieveSources(
            for: libraryRootURL,
            libraryId: libraryId
        )
        
        XCTAssertEqual(sources.count, 1)
        XCTAssertEqual(sources[0].mediaTypes, .images)
        
        // Verify persistence by reading association file directly
        let fileURL = SourceAssociationStorage.associationsFileURL(for: libraryRootURL)
        let data = try Data(contentsOf: fileURL)
        let association = try SourceAssociationSerializer.deserialize(data)
        
        XCTAssertEqual(association.sources.count, 1)
        XCTAssertEqual(association.sources[0].mediaTypes, .images)
    }
    
    // MARK: - Source List Output Tests
    
    func testSourceListHumanReadableIncludesMediaTypes() throws {
        // Attach sources with different mediaTypes
        let source1 = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: sourceDirectory.path,
            mediaTypes: .images
        )
        let source2 = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: sourceDirectory.path,
            mediaTypes: .videos
        )
        let source3 = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: sourceDirectory.path
            // mediaTypes is nil (defaults to .both)
        )
        
        try SourceAssociationManager.attach(source: source1, to: libraryRootURL, libraryId: libraryId)
        try SourceAssociationManager.attach(source: source2, to: libraryRootURL, libraryId: libraryId)
        try SourceAssociationManager.attach(source: source3, to: libraryRootURL, libraryId: libraryId)
        
        // Format output
        let sources = try SourceAssociationManager.retrieveSources(for: libraryRootURL, libraryId: libraryId)
        let formatter = SourceListFormatter(sources: sources, outputFormat: .humanReadable)
        let output = formatter.format()
        
        // Verify mediaTypes are displayed
        XCTAssertTrue(output.contains("Media types: images"))
        XCTAssertTrue(output.contains("Media types: videos"))
        XCTAssertTrue(output.contains("Media types: both"))
    }
    
    func testSourceListJSONIncludesMediaTypes() throws {
        // Attach sources with different mediaTypes
        let source1 = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: sourceDirectory.path,
            mediaTypes: .images
        )
        let source2 = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: sourceDirectory.path,
            mediaTypes: .videos
        )
        let source3 = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: sourceDirectory.path
            // mediaTypes is nil (defaults to .both)
        )
        
        try SourceAssociationManager.attach(source: source1, to: libraryRootURL, libraryId: libraryId)
        try SourceAssociationManager.attach(source: source2, to: libraryRootURL, libraryId: libraryId)
        try SourceAssociationManager.attach(source: source3, to: libraryRootURL, libraryId: libraryId)
        
        // Format JSON output
        let sources = try SourceAssociationManager.retrieveSources(for: libraryRootURL, libraryId: libraryId)
        let formatter = SourceListFormatter(sources: sources, outputFormat: .json)
        let jsonString = formatter.format()
        
        // Parse JSON and verify mediaTypes field is present
        let jsonData = jsonString.data(using: .utf8)!
        let jsonArray = try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]
        
        XCTAssertEqual(jsonArray.count, 3)
        
        // Verify each source has mediaTypes field
        let source1Json = jsonArray.first { ($0["sourceId"] as! String) == source1.sourceId }!
        XCTAssertEqual(source1Json["mediaTypes"] as! String, "images")
        
        let source2Json = jsonArray.first { ($0["sourceId"] as! String) == source2.sourceId }!
        XCTAssertEqual(source2Json["mediaTypes"] as! String, "videos")
        
        let source3Json = jsonArray.first { ($0["sourceId"] as! String) == source3.sourceId }!
        XCTAssertEqual(source3Json["mediaTypes"] as! String, "both") // Default when nil
    }
    
    func testSourceListJSONDefaultMediaTypes() throws {
        // Attach source without mediaTypes (nil)
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: sourceDirectory.path
            // mediaTypes is nil
        )
        
        try SourceAssociationManager.attach(source: source, to: libraryRootURL, libraryId: libraryId)
        
        // Format JSON output
        let sources = try SourceAssociationManager.retrieveSources(for: libraryRootURL, libraryId: libraryId)
        let formatter = SourceListFormatter(sources: sources, outputFormat: .json)
        let jsonString = formatter.format()
        
        // Parse JSON and verify mediaTypes defaults to "both"
        let jsonData = jsonString.data(using: .utf8)!
        let jsonArray = try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]
        
        XCTAssertEqual(jsonArray.count, 1)
        XCTAssertEqual(jsonArray[0]["mediaTypes"] as! String, "both")
    }
    
    // MARK: - Task 9: Edge Cases and Error Handling
    
    func testInvalidMediaTypesErrorMessageConsistency() throws {
        // Test that invalid mediaTypes flag produces consistent error message
        var command = SourceAttachCommand()
        command.path = sourceDirectory.path
        command.library = libraryRootURL.path
        command.mediaTypes = "invalid"
        command.json = false
        
        // Should throw error with clear message
        XCTAssertThrowsError(try command.run()) { error in
            if let cliError = error as? CLIError {
                switch cliError {
                case .invalidArgument(let message):
                    XCTAssertTrue(message.contains("Invalid media types value"))
                    XCTAssertTrue(message.contains("images, videos, both"))
                default:
                    XCTFail("Expected invalidArgument error")
                }
            } else {
                XCTFail("Expected CLIError")
            }
        }
    }
    
    func testInvalidMediaTypesErrorExitCode() throws {
        // Verify invalid mediaTypes results in exit code 1 (tested via error throwing)
        var command = SourceAttachCommand()
        command.path = sourceDirectory.path
        command.library = libraryRootURL.path
        command.mediaTypes = "invalid"
        command.json = false
        
        // Command should throw error (which translates to exit code 1 in CLI)
        XCTAssertThrowsError(try command.run())
        
        // Verify source was NOT attached
        let sources = try SourceAssociationManager.retrieveSources(
            for: libraryRootURL,
            libraryId: libraryId
        )
        XCTAssertEqual(sources.count, 0)
    }
}
