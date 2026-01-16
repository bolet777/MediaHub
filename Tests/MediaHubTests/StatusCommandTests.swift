//
//  StatusCommandTests.swift
//  MediaHubTests
//
//  Tests for status command
//

import XCTest
@testable import MediaHub
@testable import MediaHubCLI

final class StatusCommandTests: XCTestCase {
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
    
    // MARK: - Statistics Tests
    
    func testStatusWithStatisticsWhenIndexAvailable() throws {
        // Create baseline index with entries
        let entries = [
            IndexEntry(path: "2024/01/IMG_001.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z"),
            IndexEntry(path: "2024/01/IMG_002.jpg", size: 2000, mtime: "2024-01-02T00:00:00Z"),
            IndexEntry(path: "2024/02/VID_001.mov", size: 3000, mtime: "2024-02-01T00:00:00Z"),
            IndexEntry(path: "2023/12/IMG_003.png", size: 1500, mtime: "2023-12-31T00:00:00Z")
        ]
        let index = BaselineIndex(entries: entries)
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRootURL.path)
        try BaselineIndexWriter.write(index, to: indexPath, libraryRoot: libraryRootURL.path)
        
        // Create source
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: "/tmp/test",
            mediaTypes: .images
        )
        try SourceAssociationManager.attach(source: source, to: libraryRootURL, libraryId: libraryId)
        
        // Open library and format status
        let openedLibrary = try LibraryContext.openLibrary(at: libraryRootURL.path)
        let sources = try SourceAssociationManager.retrieveSources(for: libraryRootURL, libraryId: libraryId)
        let statistics = LibraryStatisticsComputer.compute(from: index)
        
        let formatter = StatusFormatter(
            library: openedLibrary,
            sources: sources,
            baselineIndex: index,
            statistics: statistics,
            scaleMetrics: ScaleMetricsComputer.compute(from: index),
            durationSeconds: nil,
            outputFormat: .humanReadable
        )
        let output = formatter.format()
        
        // Verify statistics are displayed
        XCTAssertTrue(output.contains("Statistics:"))
        XCTAssertTrue(output.contains("Total items: 4"))
        XCTAssertTrue(output.contains("By year:"))
        XCTAssertTrue(output.contains("2024:"))
        XCTAssertTrue(output.contains("2023:"))
        XCTAssertTrue(output.contains("By media type:"))
        XCTAssertTrue(output.contains("Images:"))
        XCTAssertTrue(output.contains("Videos:"))
    }
    
    func testStatusWithoutStatisticsWhenIndexMissing() throws {
        // Create source (no index)
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: "/tmp/test",
            mediaTypes: .images
        )
        try SourceAssociationManager.attach(source: source, to: libraryRootURL, libraryId: libraryId)
        
        // Open library and format status
        let openedLibrary = try LibraryContext.openLibrary(at: libraryRootURL.path)
        let sources = try SourceAssociationManager.retrieveSources(for: libraryRootURL, libraryId: libraryId)
        
        let formatter = StatusFormatter(
            library: openedLibrary,
            sources: sources,
            baselineIndex: nil,
            statistics: nil,
            scaleMetrics: nil,
            durationSeconds: nil,
            outputFormat: .humanReadable
        )
        let output = formatter.format()
        
        // Verify statistics show N/A
        XCTAssertTrue(output.contains("Statistics: N/A (baseline index not available)"))
    }
    
    func testStatusJSONWithStatisticsWhenIndexAvailable() throws {
        // Create baseline index with entries
        let entries = [
            IndexEntry(path: "2024/01/IMG_001.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z"),
            IndexEntry(path: "2024/02/VID_001.mov", size: 3000, mtime: "2024-02-01T00:00:00Z"),
            IndexEntry(path: "2023/12/IMG_003.png", size: 1500, mtime: "2023-12-31T00:00:00Z")
        ]
        let index = BaselineIndex(entries: entries)
        
        // Create source
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: "/tmp/test",
            mediaTypes: .images
        )
        try SourceAssociationManager.attach(source: source, to: libraryRootURL, libraryId: libraryId)
        
        // Open library and format status JSON
        let openedLibrary = try LibraryContext.openLibrary(at: libraryRootURL.path)
        let sources = try SourceAssociationManager.retrieveSources(for: libraryRootURL, libraryId: libraryId)
        let statistics = LibraryStatisticsComputer.compute(from: index)
        
        let formatter = StatusFormatter(
            library: openedLibrary,
            sources: sources,
            baselineIndex: index,
            statistics: statistics,
            scaleMetrics: ScaleMetricsComputer.compute(from: index),
            durationSeconds: nil,
            outputFormat: .json
        )
        let jsonString = formatter.format()
        
        // Parse JSON and verify statistics field is present
        let jsonData = jsonString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        
        XCTAssertNotNil(json["statistics"])
        let stats = json["statistics"] as! [String: Any]
        XCTAssertEqual(stats["totalItems"] as! Int, 3)
        
        let byYear = stats["byYear"] as! [String: Int]
        XCTAssertEqual(byYear["2024"], 2)
        XCTAssertEqual(byYear["2023"], 1)
        
        let byMediaType = stats["byMediaType"] as! [String: Int]
        XCTAssertEqual(byMediaType["images"], 2)
        XCTAssertEqual(byMediaType["videos"], 1)
    }
    
    func testStatusJSONWithoutStatisticsWhenIndexMissing() throws {
        // Create source (no index)
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: "/tmp/test",
            mediaTypes: .images
        )
        try SourceAssociationManager.attach(source: source, to: libraryRootURL, libraryId: libraryId)
        
        // Open library and format status JSON
        let openedLibrary = try LibraryContext.openLibrary(at: libraryRootURL.path)
        let sources = try SourceAssociationManager.retrieveSources(for: libraryRootURL, libraryId: libraryId)
        
        let formatter = StatusFormatter(
            library: openedLibrary,
            sources: sources,
            baselineIndex: nil,
            statistics: nil,
            scaleMetrics: nil,
            durationSeconds: nil,
            outputFormat: .json
        )
        let jsonString = formatter.format()
        
        // Parse JSON and verify statistics field is omitted (not null)
        let jsonData = jsonString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        
        XCTAssertNil(json["statistics"], "statistics field should be omitted when index unavailable, not set to null")
        // Verify other fields are present
        XCTAssertNotNil(json["path"])
        XCTAssertNotNil(json["sources"])
    }
    
    func testStatusJSONStatisticsOmittedNotNull() throws {
        // Test that statistics field follows same pattern as hashCoverage (omit when unavailable, not null)
        let openedLibrary = try LibraryContext.openLibrary(at: libraryRootURL.path)
        let sources = try SourceAssociationManager.retrieveSources(for: libraryRootURL, libraryId: libraryId)
        
        let formatter = StatusFormatter(
            library: openedLibrary,
            sources: sources,
            baselineIndex: nil,
            statistics: nil,
            scaleMetrics: nil,
            durationSeconds: nil,
            outputFormat: .json
        )
        let jsonString = formatter.format()
        
        // Verify statistics is omitted (not present in JSON string, not "null")
        XCTAssertFalse(jsonString.contains("\"statistics\""), "statistics should be omitted, not present as null")
        XCTAssertFalse(jsonString.contains("\"statistics\": null"), "statistics should not be set to null")
        
        // Verify hashCoverage is also omitted (same pattern)
        XCTAssertFalse(jsonString.contains("\"hashCoverage\""), "hashCoverage should also be omitted when unavailable")
    }
    
    // MARK: - JSON Performance Object Tests
    
    func testStatusJSONIncludesPerformanceWhenIndexAvailable() throws {
        // Create baseline index with entries
        let entries = [
            IndexEntry(path: "2024/01/IMG_001.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z", hash: "sha256:abc123"),
            IndexEntry(path: "2024/01/IMG_002.jpg", size: 2000, mtime: "2024-01-02T00:00:00Z", hash: nil)
        ]
        let index = BaselineIndex(entries: entries)
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRootURL.path)
        try BaselineIndexWriter.write(index, to: indexPath, libraryRoot: libraryRootURL.path)
        
        // Create source
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: "/tmp/test",
            mediaTypes: .images
        )
        try SourceAssociationManager.attach(source: source, to: libraryRootURL, libraryId: libraryId)
        
        // Open library and format status JSON
        let openedLibrary = try LibraryContext.openLibrary(at: libraryRootURL.path)
        let sources = try SourceAssociationManager.retrieveSources(for: libraryRootURL, libraryId: libraryId)
        let statistics = LibraryStatisticsComputer.compute(from: index)
        let scaleMetrics = ScaleMetricsComputer.compute(from: index)
        
        let formatter = StatusFormatter(
            library: openedLibrary,
            sources: sources,
            baselineIndex: index,
            statistics: statistics,
            scaleMetrics: scaleMetrics,
            durationSeconds: 0.123,
            outputFormat: .json
        )
        let jsonString = formatter.format()
        
        // Parse JSON and verify performance field is present
        let jsonData = jsonString.data(using: String.Encoding.utf8)!
        let json = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        
        XCTAssertNotNil(json["performance"], "performance field should be present when scaleMetrics available")
        let performance = json["performance"] as! [String: Any]
        
        // Verify durationSeconds
        if let duration = performance["durationSeconds"] as? Double {
            XCTAssertGreaterThanOrEqual(duration, 0.0, "durationSeconds should be non-negative")
        } else {
            XCTAssertNil(performance["durationSeconds"], "durationSeconds may be null")
        }
        
        // Verify scale object
        XCTAssertNotNil(performance["scale"], "scale object should be present")
        let scale = performance["scale"] as! [String: Any]
        XCTAssertEqual(scale["fileCount"] as! Int, 2, "fileCount should match")
        XCTAssertEqual(scale["totalSizeBytes"] as! Int64, 3000, "totalSizeBytes should match")
        
        // hashCoveragePercent may be null or a number
        if let coverage = scale["hashCoveragePercent"] as? Double {
            XCTAssertGreaterThanOrEqual(coverage, 0.0, "hashCoveragePercent should be non-negative")
            XCTAssertLessThanOrEqual(coverage, 100.0, "hashCoveragePercent should be <= 100")
        } else {
            XCTAssertNil(scale["hashCoveragePercent"], "hashCoveragePercent may be null")
        }
        
        // Verify existing fields are still present
        XCTAssertNotNil(json["path"], "Existing fields should be preserved")
        XCTAssertNotNil(json["sources"], "Existing fields should be preserved")
    }
    
    func testStatusJSONOmitsPerformanceWhenIndexMissing() throws {
        // Create source (no index)
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: "/tmp/test",
            mediaTypes: .images
        )
        try SourceAssociationManager.attach(source: source, to: libraryRootURL, libraryId: libraryId)
        
        // Open library and format status JSON
        let openedLibrary = try LibraryContext.openLibrary(at: libraryRootURL.path)
        let sources = try SourceAssociationManager.retrieveSources(for: libraryRootURL, libraryId: libraryId)
        
        let formatter = StatusFormatter(
            library: openedLibrary,
            sources: sources,
            baselineIndex: nil,
            statistics: nil,
            scaleMetrics: nil,
            durationSeconds: nil,
            outputFormat: .json
        )
        let jsonString = formatter.format()
        
        // Parse JSON and verify performance field is omitted (not null)
        let jsonData = jsonString.data(using: String.Encoding.utf8)!
        let json = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        
        XCTAssertNil(json["performance"], "performance field should be omitted when scaleMetrics unavailable, not set to null")
        
        // Verify JSON is still valid and existing fields are present
        XCTAssertNotNil(json["path"], "Existing fields should be preserved")
        XCTAssertNotNil(json["sources"], "Existing fields should be preserved")
        
        // Verify performance is not present as null in JSON string
        XCTAssertFalse(jsonString.contains("\"performance\": null"), "performance should not be set to null")
    }
    
    func testStatusJSONHumanReadableUnchanged() throws {
        // Create baseline index with entries
        let entries = [
            IndexEntry(path: "2024/01/IMG_001.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z", hash: "sha256:abc123")
        ]
        let index = BaselineIndex(entries: entries)
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRootURL.path)
        try BaselineIndexWriter.write(index, to: indexPath, libraryRoot: libraryRootURL.path)
        
        // Create source
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: "/tmp/test",
            mediaTypes: .images
        )
        try SourceAssociationManager.attach(source: source, to: libraryRootURL, libraryId: libraryId)
        
        // Open library and format status human-readable
        let openedLibrary = try LibraryContext.openLibrary(at: libraryRootURL.path)
        let sources = try SourceAssociationManager.retrieveSources(for: libraryRootURL, libraryId: libraryId)
        let statistics = LibraryStatisticsComputer.compute(from: index)
        let scaleMetrics = ScaleMetricsComputer.compute(from: index)
        
        let formatter = StatusFormatter(
            library: openedLibrary,
            sources: sources,
            baselineIndex: index,
            statistics: statistics,
            scaleMetrics: scaleMetrics,
            durationSeconds: 0.123,
            outputFormat: .humanReadable
        )
        let output = formatter.format()
        
        // Verify Performance section is still present in human-readable output
        XCTAssertTrue(output.contains("Performance"), "Performance section should be present in human-readable output")
        XCTAssertTrue(output.contains("Duration:"), "Duration should be present")
        XCTAssertTrue(output.contains("File count:"), "File count should be present")
        
        // Verify no JSON-like text appears in human-readable output
        XCTAssertFalse(output.contains("\"performance\""), "JSON performance field should not appear in human-readable output")
    }
    
    func testStatusJSONSourcesIncludeMediaTypes() throws {
        // Create sources with different mediaTypes
        let source1 = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: "/tmp/test1",
            mediaTypes: .images
        )
        let source2 = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: "/tmp/test2",
            mediaTypes: .videos
        )
        let source3 = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: "/tmp/test3"
            // mediaTypes is nil (defaults to .both)
        )
        
        try SourceAssociationManager.attach(source: source1, to: libraryRootURL, libraryId: libraryId)
        try SourceAssociationManager.attach(source: source2, to: libraryRootURL, libraryId: libraryId)
        try SourceAssociationManager.attach(source: source3, to: libraryRootURL, libraryId: libraryId)
        
        // Open library and format status JSON
        let openedLibrary = try LibraryContext.openLibrary(at: libraryRootURL.path)
        let sources = try SourceAssociationManager.retrieveSources(for: libraryRootURL, libraryId: libraryId)
        
        let formatter = StatusFormatter(
            library: openedLibrary,
            sources: sources,
            baselineIndex: nil,
            statistics: nil,
            scaleMetrics: nil,
            durationSeconds: nil,
            outputFormat: .json
        )
        let jsonString = formatter.format()
        
        // Parse JSON and verify sources include mediaTypes
        let jsonData = jsonString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        let sourcesArray = json["sources"] as! [[String: Any]]
        
        XCTAssertEqual(sourcesArray.count, 3)
        
        let source1Json = sourcesArray.first { ($0["sourceId"] as! String) == source1.sourceId }!
        XCTAssertEqual(source1Json["mediaTypes"] as! String, "images")
        
        let source2Json = sourcesArray.first { ($0["sourceId"] as! String) == source2.sourceId }!
        XCTAssertEqual(source2Json["mediaTypes"] as! String, "videos")
        
        let source3Json = sourcesArray.first { ($0["sourceId"] as! String) == source3.sourceId }!
        XCTAssertEqual(source3Json["mediaTypes"] as! String, "both") // Default when nil
    }
    
    func testStatusHumanReadableSourcesIncludeMediaTypes() throws {
        // Create source with mediaTypes
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: "/tmp/test",
            mediaTypes: .images
        )
        try SourceAssociationManager.attach(source: source, to: libraryRootURL, libraryId: libraryId)
        
        // Open library and format status
        let openedLibrary = try LibraryContext.openLibrary(at: libraryRootURL.path)
        let sources = try SourceAssociationManager.retrieveSources(for: libraryRootURL, libraryId: libraryId)
        
        let formatter = StatusFormatter(
            library: openedLibrary,
            sources: sources,
            baselineIndex: nil,
            statistics: nil,
            scaleMetrics: nil,
            durationSeconds: nil,
            outputFormat: .humanReadable
        )
        let output = formatter.format()
        
        // Verify mediaTypes are displayed
        XCTAssertTrue(output.contains("Media types: images"))
    }
    
    // MARK: - Performance Section Tests
    
    func testStatusPerformanceSectionWhenIndexAvailable() throws {
        // Create baseline index with entries
        let entries = [
            IndexEntry(path: "2024/01/IMG_001.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z", hash: "sha256:abc123"),
            IndexEntry(path: "2024/01/IMG_002.jpg", size: 2000, mtime: "2024-01-02T00:00:00Z", hash: nil),
            IndexEntry(path: "2024/02/VID_001.mov", size: 3000, mtime: "2024-02-01T00:00:00Z", hash: "sha256:def456")
        ]
        let index = BaselineIndex(entries: entries)
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRootURL.path)
        try BaselineIndexWriter.write(index, to: indexPath, libraryRoot: libraryRootURL.path)
        
        // Create source
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: "/tmp/test",
            mediaTypes: .images
        )
        try SourceAssociationManager.attach(source: source, to: libraryRootURL, libraryId: libraryId)
        
        // Open library and format status
        let openedLibrary = try LibraryContext.openLibrary(at: libraryRootURL.path)
        let sources = try SourceAssociationManager.retrieveSources(for: libraryRootURL, libraryId: libraryId)
        let statistics = LibraryStatisticsComputer.compute(from: index)
        let scaleMetrics = ScaleMetricsComputer.compute(from: index)
        
        let formatter = StatusFormatter(
            library: openedLibrary,
            sources: sources,
            baselineIndex: index,
            statistics: statistics,
            scaleMetrics: scaleMetrics,
            durationSeconds: 0.123,
            outputFormat: .humanReadable
        )
        let output = formatter.format()
        
        // Verify Performance section is present
        XCTAssertTrue(output.contains("Performance"), "Performance section should be present")
        XCTAssertTrue(output.contains("Duration:"), "Duration should be present")
        XCTAssertTrue(output.contains("File count:"), "File count should be present")
        XCTAssertTrue(output.contains("Total size:"), "Total size should be present")
        XCTAssertTrue(output.contains("Hash coverage:"), "Hash coverage should be present")
        
        // Verify existing content is preserved
        XCTAssertTrue(output.contains("Library Status"), "Existing header should be preserved")
        XCTAssertTrue(output.contains("Statistics:"), "Existing statistics section should be preserved")
        
        // Verify duration format (informational, may vary - only check label presence)
        XCTAssertTrue(output.contains("Duration:") || output.contains("Duration: N/A"), "Duration label should be present")
        
        // Verify scale metrics values
        XCTAssertTrue(output.contains("File count: 3"), "File count should be 3")
        XCTAssertTrue(output.contains("Hash coverage:"), "Hash coverage should be present")
    }
    
    func testStatusPerformanceSectionWhenIndexMissing() throws {
        // Create source (no index)
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: "/tmp/test",
            mediaTypes: .images
        )
        try SourceAssociationManager.attach(source: source, to: libraryRootURL, libraryId: libraryId)
        
        // Open library and format status
        let openedLibrary = try LibraryContext.openLibrary(at: libraryRootURL.path)
        let sources = try SourceAssociationManager.retrieveSources(for: libraryRootURL, libraryId: libraryId)
        
        let formatter = StatusFormatter(
            library: openedLibrary,
            sources: sources,
            baselineIndex: nil,
            statistics: nil,
            scaleMetrics: nil,
            durationSeconds: nil,
            outputFormat: .humanReadable
        )
        let output = formatter.format()
        
        // Verify Performance section shows N/A
        XCTAssertTrue(output.contains("Performance"), "Performance section should be present")
        XCTAssertTrue(output.contains("Performance: N/A (baseline index not available)"), "Performance should show N/A when index missing")
        
        // Verify existing content is preserved
        XCTAssertTrue(output.contains("Library Status"), "Existing header should be preserved")
        XCTAssertTrue(output.contains("Statistics: N/A"), "Existing statistics section should be preserved")
    }
    
    func testStatusPerformanceSectionDurationNATWhenNil() throws {
        // Create baseline index with entries
        let entries = [
            IndexEntry(path: "2024/01/IMG_001.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z")
        ]
        let index = BaselineIndex(entries: entries)
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRootURL.path)
        try BaselineIndexWriter.write(index, to: indexPath, libraryRoot: libraryRootURL.path)
        
        // Create source
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: "/tmp/test",
            mediaTypes: .images
        )
        try SourceAssociationManager.attach(source: source, to: libraryRootURL, libraryId: libraryId)
        
        // Open library and format status
        let openedLibrary = try LibraryContext.openLibrary(at: libraryRootURL.path)
        let sources = try SourceAssociationManager.retrieveSources(for: libraryRootURL, libraryId: libraryId)
        let statistics = LibraryStatisticsComputer.compute(from: index)
        let scaleMetrics = ScaleMetricsComputer.compute(from: index)
        
        let formatter = StatusFormatter(
            library: openedLibrary,
            sources: sources,
            baselineIndex: index,
            statistics: statistics,
            scaleMetrics: scaleMetrics,
            durationSeconds: nil, // Duration is nil
            outputFormat: .humanReadable
        )
        let output = formatter.format()
        
        // Verify Performance section shows Duration: N/A
        XCTAssertTrue(output.contains("Duration: N/A"), "Duration should show N/A when nil")
        
        // Verify other metrics are still present
        XCTAssertTrue(output.contains("File count:"), "File count should be present")
        XCTAssertTrue(output.contains("Total size:"), "Total size should be present")
    }
    
    func testStatusPerformanceSectionNotInJSON() throws {
        // Create baseline index with entries
        let entries = [
            IndexEntry(path: "2024/01/IMG_001.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z")
        ]
        let index = BaselineIndex(entries: entries)
        
        // Create source
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: "/tmp/test",
            mediaTypes: .images
        )
        try SourceAssociationManager.attach(source: source, to: libraryRootURL, libraryId: libraryId)
        
        // Open library and format status JSON
        let openedLibrary = try LibraryContext.openLibrary(at: libraryRootURL.path)
        let sources = try SourceAssociationManager.retrieveSources(for: libraryRootURL, libraryId: libraryId)
        let statistics = LibraryStatisticsComputer.compute(from: index)
        let scaleMetrics = ScaleMetricsComputer.compute(from: index)
        
        let formatter = StatusFormatter(
            library: openedLibrary,
            sources: sources,
            baselineIndex: index,
            statistics: statistics,
            scaleMetrics: scaleMetrics,
            durationSeconds: 0.123,
            outputFormat: .json
        )
        let jsonString = formatter.format()
        
        // Verify Performance section is NOT in JSON (human-readable only)
        XCTAssertFalse(jsonString.contains("Performance"), "Performance section should not be in JSON output")
        XCTAssertFalse(jsonString.contains("Duration:"), "Duration should not be in JSON output")
        
        // Verify JSON is still valid
        let jsonData = jsonString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        XCTAssertNotNil(json["path"], "JSON should still be valid")
    }
}
