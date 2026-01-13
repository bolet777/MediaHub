//
//  LibraryComparisonTests.swift
//  MediaHubTests
//
//  Tests for Library comparison and new item detection
//

import XCTest
@testable import MediaHub

final class LibraryComparisonTests: XCTestCase {
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
    
    func testScanLibraryContentsEmpty() throws {
        let paths = try LibraryContentQuery.scanLibraryContents(at: libraryRootURL)
        
        XCTAssertEqual(paths.count, 0)
    }
    
    func testScanLibraryContentsWithMedia() throws {
        // Add media file to library
        let mediaFile = libraryRootURL.appendingPathComponent("library.jpg")
        try "fake image".write(to: mediaFile, atomically: true, encoding: .utf8)
        
        let paths = try LibraryContentQuery.scanLibraryContents(at: libraryRootURL)
        
        XCTAssertEqual(paths.count, 1)
        XCTAssertTrue(paths.contains(mediaFile.path))
    }
    
    func testScanLibraryContentsExcludesMetadata() throws {
        // Add media file and non-media file
        let mediaFile = libraryRootURL.appendingPathComponent("library.jpg")
        try "fake image".write(to: mediaFile, atomically: true, encoding: .utf8)
        
        // .mediahub should be excluded
        let paths = try LibraryContentQuery.scanLibraryContents(at: libraryRootURL)
        
        XCTAssertEqual(paths.count, 1)
        XCTAssertFalse(paths.contains { $0.contains(".mediahub") })
    }
    
    func testCompareNewItem() {
        let candidate = CandidateMediaItem(
            path: "/test/new.jpg",
            size: 1000,
            modificationDate: ISO8601DateFormatter().string(from: Date()),
            fileName: "new.jpg"
        )
        
        let libraryPaths: Set<String> = []
        let result = LibraryItemComparator.compare(
            candidate: candidate,
            against: libraryPaths
        )
        
        XCTAssertEqual(result, .new)
    }
    
    func testCompareKnownItem() throws {
        let candidate = CandidateMediaItem(
            path: libraryRootURL.appendingPathComponent("known.jpg").path,
            size: 1000,
            modificationDate: ISO8601DateFormatter().string(from: Date()),
            fileName: "known.jpg"
        )
        
        // Add file to library
        let mediaFile = libraryRootURL.appendingPathComponent("known.jpg")
        try "fake image".write(to: mediaFile, atomically: true, encoding: .utf8)
        
        let libraryPaths = try LibraryContentQuery.scanLibraryContents(at: libraryRootURL)
        let result = LibraryItemComparator.compare(
            candidate: candidate,
            against: libraryPaths
        )
        
        XCTAssertEqual(result, .known)
    }
    
    func testExcludeKnownItems() {
        let candidate1 = CandidateMediaItem(
            path: "/test/new.jpg",
            size: 1000,
            modificationDate: ISO8601DateFormatter().string(from: Date()),
            fileName: "new.jpg"
        )
        let candidate2 = CandidateMediaItem(
            path: "/test/known.jpg",
            size: 1000,
            modificationDate: ISO8601DateFormatter().string(from: Date()),
            fileName: "known.jpg"
        )
        
        let candidates = [candidate1, candidate2]
        let libraryPaths: Set<String> = [candidate2.path]
        
        let comparisonResults = LibraryItemComparator.compareAll(
            candidates: candidates,
            against: libraryPaths
        )
        
        let newCandidates = KnownItemExcluder.excludeKnown(
            candidates: candidates,
            comparisonResults: comparisonResults
        )
        
        XCTAssertEqual(newCandidates.count, 1)
        XCTAssertEqual(newCandidates[0].path, candidate1.path)
    }
    
    func testComparisonDeterministic() throws {
        // Add media file to library
        let mediaFile = libraryRootURL.appendingPathComponent("library.jpg")
        try "fake image".write(to: mediaFile, atomically: true, encoding: .utf8)
        
        let candidate = CandidateMediaItem(
            path: mediaFile.path,
            size: 1000,
            modificationDate: ISO8601DateFormatter().string(from: Date()),
            fileName: "library.jpg"
        )
        
        let libraryPaths1 = try LibraryContentQuery.scanLibraryContents(at: libraryRootURL)
        let libraryPaths2 = try LibraryContentQuery.scanLibraryContents(at: libraryRootURL)
        
        let result1 = LibraryItemComparator.compare(
            candidate: candidate,
            against: libraryPaths1
        )
        let result2 = LibraryItemComparator.compare(
            candidate: candidate,
            against: libraryPaths2
        )
        
        XCTAssertEqual(result1, result2)
    }
}
