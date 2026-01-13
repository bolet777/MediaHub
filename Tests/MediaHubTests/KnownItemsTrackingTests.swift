//
//  KnownItemsTrackingTests.swift
//  MediaHubTests
//
//  Tests for known items tracking
//

import XCTest
@testable import MediaHub

final class KnownItemsTrackingTests: XCTestCase {
    var libraryRootURL: URL!
    let sourceId = UUID().uuidString
    
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
    
    func testRecordImportedItems() throws {
        // Record imported items
        let items: [(path: String, destinationPath: String)] = [
            ("/source/path1.jpg", "2026/01/path1.jpg"),
            ("/source/path2.jpg", "2026/01/path2.jpg")
        ]
        
        try KnownItemsTracker.recordImportedItems(
            items,
            sourceId: sourceId,
            libraryRootURL: libraryRootURL
        )
        
        // Query known items
        let knownItems = try KnownItemsTracker.queryKnownItems(
            sourceId: sourceId,
            libraryRootURL: libraryRootURL
        )
        
        // Verify items are recorded
        XCTAssertEqual(knownItems.count, 2)
        XCTAssertTrue(knownItems.contains("/source/path1.jpg"))
        XCTAssertTrue(knownItems.contains("/source/path2.jpg"))
    }
    
    func testQueryKnownItemsEmpty() throws {
        // Query known items when none exist
        let knownItems = try KnownItemsTracker.queryKnownItems(
            sourceId: sourceId,
            libraryRootURL: libraryRootURL
        )
        
        // Verify empty set
        XCTAssertEqual(knownItems.count, 0)
    }
    
    func testRecordImportedItemsAppends() throws {
        // Record first batch
        let items1: [(path: String, destinationPath: String)] = [
            ("/source/path1.jpg", "2026/01/path1.jpg")
        ]
        
        try KnownItemsTracker.recordImportedItems(
            items1,
            sourceId: sourceId,
            libraryRootURL: libraryRootURL
        )
        
        // Record second batch
        let items2: [(path: String, destinationPath: String)] = [
            ("/source/path2.jpg", "2026/01/path2.jpg")
        ]
        
        try KnownItemsTracker.recordImportedItems(
            items2,
            sourceId: sourceId,
            libraryRootURL: libraryRootURL
        )
        
        // Query known items
        let knownItems = try KnownItemsTracker.queryKnownItems(
            sourceId: sourceId,
            libraryRootURL: libraryRootURL
        )
        
        // Verify both items are recorded
        XCTAssertEqual(knownItems.count, 2)
    }
    
    func testRecordImportedItemsAvoidsDuplicates() throws {
        // Record same item twice
        let items: [(path: String, destinationPath: String)] = [
            ("/source/path1.jpg", "2026/01/path1.jpg")
        ]
        
        try KnownItemsTracker.recordImportedItems(
            items,
            sourceId: sourceId,
            libraryRootURL: libraryRootURL
        )
        
        try KnownItemsTracker.recordImportedItems(
            items,
            sourceId: sourceId,
            libraryRootURL: libraryRootURL
        )
        
        // Query known items
        let knownItems = try KnownItemsTracker.queryKnownItems(
            sourceId: sourceId,
            libraryRootURL: libraryRootURL
        )
        
        // Verify item is only recorded once
        XCTAssertEqual(knownItems.count, 1)
    }
}
