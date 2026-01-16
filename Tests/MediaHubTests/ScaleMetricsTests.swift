//
//  ScaleMetricsTests.swift
//  MediaHubTests
//
//  Tests for scale metrics computation
//

import XCTest
@testable import MediaHub

final class ScaleMetricsTests: XCTestCase {
    var tempDirectory: URL!
    var libraryRoot: String!
    
    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        libraryRoot = tempDirectory.path
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    // MARK: - Basic Computation Tests
    
    func testComputeMetricsFromEmptyIndex() {
        let entries: [IndexEntry] = []
        let index = BaselineIndex(entries: entries)
        
        let metrics = ScaleMetricsComputer.compute(from: index)
        
        XCTAssertEqual(metrics.fileCount, 0)
        XCTAssertEqual(metrics.totalSizeBytes, 0)
        XCTAssertNil(metrics.hashCoveragePercent, "Hash coverage should be nil for empty index")
    }
    
    func testComputeMetricsFromIndexWithoutHashes() {
        let entries = [
            IndexEntry(path: "2024/01/IMG_001.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z", hash: nil),
            IndexEntry(path: "2024/01/IMG_002.jpg", size: 2000, mtime: "2024-01-02T00:00:00Z", hash: nil),
            IndexEntry(path: "2024/02/VID_001.mov", size: 3000, mtime: "2024-02-01T00:00:00Z", hash: nil)
        ]
        let index = BaselineIndex(entries: entries)
        
        let metrics = ScaleMetricsComputer.compute(from: index)
        
        XCTAssertEqual(metrics.fileCount, 3)
        XCTAssertEqual(metrics.totalSizeBytes, 6000)
        XCTAssertNotNil(metrics.hashCoveragePercent, "Hash coverage should be present when index has entries")
        XCTAssertEqual(metrics.hashCoveragePercent!, 0.0, accuracy: 0.001, "Hash coverage should be 0% when no hashes present")
    }
    
    func testComputeMetricsFromIndexWithPartialHashes() {
        let entries = [
            IndexEntry(path: "2024/01/IMG_001.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z", hash: "sha256:abc123"),
            IndexEntry(path: "2024/01/IMG_002.jpg", size: 2000, mtime: "2024-01-02T00:00:00Z", hash: nil),
            IndexEntry(path: "2024/02/VID_001.mov", size: 3000, mtime: "2024-02-01T00:00:00Z", hash: "sha256:def456")
        ]
        let index = BaselineIndex(entries: entries)
        
        let metrics = ScaleMetricsComputer.compute(from: index)
        
        XCTAssertEqual(metrics.fileCount, 3)
        XCTAssertEqual(metrics.totalSizeBytes, 6000)
        // 2 out of 3 files have hashes = 66.666...%
        XCTAssertNotNil(metrics.hashCoveragePercent)
        XCTAssertEqual(metrics.hashCoveragePercent!, 200.0 / 3.0, accuracy: 0.001)
    }
    
    func testComputeMetricsFromIndexWithAllHashes() {
        let entries = [
            IndexEntry(path: "2024/01/IMG_001.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z", hash: "sha256:abc123"),
            IndexEntry(path: "2024/01/IMG_002.jpg", size: 2000, mtime: "2024-01-02T00:00:00Z", hash: "sha256:def456"),
            IndexEntry(path: "2024/02/VID_001.mov", size: 3000, mtime: "2024-02-01T00:00:00Z", hash: "sha256:ghi789")
        ]
        let index = BaselineIndex(entries: entries)
        
        let metrics = ScaleMetricsComputer.compute(from: index)
        
        XCTAssertEqual(metrics.fileCount, 3)
        XCTAssertEqual(metrics.totalSizeBytes, 6000)
        XCTAssertNotNil(metrics.hashCoveragePercent, "Hash coverage should be present when index has entries")
        XCTAssertEqual(metrics.hashCoveragePercent!, 100.0, accuracy: 0.001, "Hash coverage should be 100% when all files have hashes")
    }
    
    func testComputeMetricsWithLargeSizes() {
        let entries = [
            IndexEntry(path: "2024/01/IMG_001.jpg", size: 1_000_000_000, mtime: "2024-01-01T00:00:00Z", hash: nil),
            IndexEntry(path: "2024/01/IMG_002.jpg", size: 2_000_000_000, mtime: "2024-01-02T00:00:00Z", hash: nil),
            IndexEntry(path: "2024/02/VID_001.mov", size: 3_000_000_000, mtime: "2024-02-01T00:00:00Z", hash: nil)
        ]
        let index = BaselineIndex(entries: entries)
        
        let metrics = ScaleMetricsComputer.compute(from: index)
        
        XCTAssertEqual(metrics.fileCount, 3)
        XCTAssertEqual(metrics.totalSizeBytes, 6_000_000_000)
        XCTAssertNotNil(metrics.hashCoveragePercent)
        XCTAssertEqual(metrics.hashCoveragePercent!, 0.0, accuracy: 0.001)
    }
    
    // MARK: - Determinism Tests
    
    func testDeterminismSameIndexMultipleRuns() {
        let entries = [
            IndexEntry(path: "2024/01/IMG_001.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z", hash: "sha256:abc123"),
            IndexEntry(path: "2024/01/IMG_002.jpg", size: 2000, mtime: "2024-01-02T00:00:00Z", hash: nil),
            IndexEntry(path: "2024/02/VID_001.mov", size: 3000, mtime: "2024-02-01T00:00:00Z", hash: "sha256:def456")
        ]
        let index = BaselineIndex(entries: entries)
        
        // Compute metrics multiple times
        let metrics1 = ScaleMetricsComputer.compute(from: index)
        let metrics2 = ScaleMetricsComputer.compute(from: index)
        let metrics3 = ScaleMetricsComputer.compute(from: index)
        
        // All results should be identical
        XCTAssertEqual(metrics1, metrics2)
        XCTAssertEqual(metrics2, metrics3)
        XCTAssertEqual(metrics1.fileCount, metrics2.fileCount)
        XCTAssertEqual(metrics1.totalSizeBytes, metrics2.totalSizeBytes)
        if let coverage1 = metrics1.hashCoveragePercent, let coverage2 = metrics2.hashCoveragePercent {
            XCTAssertEqual(coverage1, coverage2, accuracy: 0.001)
        } else {
            XCTAssertNil(metrics1.hashCoveragePercent)
            XCTAssertNil(metrics2.hashCoveragePercent)
        }
    }
    
    func testDeterminismWithReorderedEntries() {
        // Create same entries in different order
        let entries1 = [
            IndexEntry(path: "2024/01/IMG_001.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z", hash: "sha256:abc123"),
            IndexEntry(path: "2024/01/IMG_002.jpg", size: 2000, mtime: "2024-01-02T00:00:00Z", hash: nil),
            IndexEntry(path: "2024/02/VID_001.mov", size: 3000, mtime: "2024-02-01T00:00:00Z", hash: "sha256:def456")
        ]
        let entries2 = [
            IndexEntry(path: "2024/02/VID_001.mov", size: 3000, mtime: "2024-02-01T00:00:00Z", hash: "sha256:def456"),
            IndexEntry(path: "2024/01/IMG_001.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z", hash: "sha256:abc123"),
            IndexEntry(path: "2024/01/IMG_002.jpg", size: 2000, mtime: "2024-01-02T00:00:00Z", hash: nil)
        ]
        
        let index1 = BaselineIndex(entries: entries1)
        let index2 = BaselineIndex(entries: entries2)
        
        let metrics1 = ScaleMetricsComputer.compute(from: index1)
        let metrics2 = ScaleMetricsComputer.compute(from: index2)
        
        // Results should be identical (BaselineIndex sorts entries internally)
        XCTAssertEqual(metrics1, metrics2)
    }
    
    // MARK: - Library Root Loading Tests
    
    func testComputeMetricsForLibraryRootWithValidIndex() throws {
        // Create a valid index file
        let entries = [
            IndexEntry(path: "2024/01/IMG_001.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z", hash: "sha256:abc123"),
            IndexEntry(path: "2024/01/IMG_002.jpg", size: 2000, mtime: "2024-01-02T00:00:00Z", hash: nil)
        ]
        let index = BaselineIndex(entries: entries)
        
        // Write index to expected location
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRoot)
        try BaselineIndexWriter.write(index, to: indexPath, libraryRoot: libraryRoot)
        
        // Compute metrics from library root
        let metrics = ScaleMetricsComputer.compute(for: libraryRoot)
        
        XCTAssertNotNil(metrics)
        XCTAssertEqual(metrics?.fileCount, 2)
        XCTAssertEqual(metrics?.totalSizeBytes, 3000)
        let hashCoverage = metrics?.hashCoveragePercent
        XCTAssertNotNil(hashCoverage)
        XCTAssertEqual(hashCoverage!, 50.0, accuracy: 0.001)
    }
    
    func testComputeMetricsForLibraryRootWithMissingIndex() {
        // No index file exists
        
        let metrics = ScaleMetricsComputer.compute(for: libraryRoot)
        
        XCTAssertNil(metrics, "Should return nil when index is missing")
    }
    
    func testComputeMetricsForLibraryRootWithInvalidIndex() throws {
        // Create an invalid index file (corrupted JSON)
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRoot)
        let indexPathURL = URL(fileURLWithPath: indexPath)
        try FileManager.default.createDirectory(at: indexPathURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "{ invalid json }".write(toFile: indexPath, atomically: true, encoding: .utf8)
        
        let metrics = ScaleMetricsComputer.compute(for: libraryRoot)
        
        XCTAssertNil(metrics, "Should return nil when index is invalid")
    }
    
    // MARK: - Read-Only Safety Tests
    
    func testReadOnlySafetyIndexFileMtimeUnchanged() throws {
        // Create a valid index file
        let entries = [
            IndexEntry(path: "2024/01/IMG_001.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z", hash: "sha256:abc123")
        ]
        let index = BaselineIndex(entries: entries)
        
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRoot)
        try BaselineIndexWriter.write(index, to: indexPath, libraryRoot: libraryRoot)
        
        // Get initial mtime
        let initialAttributes = try FileManager.default.attributesOfItem(atPath: indexPath)
        let initialMtime = initialAttributes[.modificationDate] as? Date
        
        // Wait a small amount to ensure time difference would be detectable
        Thread.sleep(forTimeInterval: 0.1)
        
        // Compute metrics (should be read-only)
        _ = ScaleMetricsComputer.compute(for: libraryRoot)
        
        // Get mtime after computation
        let finalAttributes = try FileManager.default.attributesOfItem(atPath: indexPath)
        let finalMtime = finalAttributes[.modificationDate] as? Date
        
        // Mtime should be unchanged (read-only operation)
        XCTAssertEqual(initialMtime, finalMtime, "Index file mtime should not change after read-only metrics computation")
    }
    
    func testReadOnlySafetyMultipleComputations() throws {
        // Create a valid index file
        let entries = [
            IndexEntry(path: "2024/01/IMG_001.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z", hash: "sha256:abc123")
        ]
        let index = BaselineIndex(entries: entries)
        
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRoot)
        try BaselineIndexWriter.write(index, to: indexPath, libraryRoot: libraryRoot)
        
        // Get initial mtime
        let initialAttributes = try FileManager.default.attributesOfItem(atPath: indexPath)
        let initialMtime = initialAttributes[.modificationDate] as? Date
        
        // Wait a small amount
        Thread.sleep(forTimeInterval: 0.1)
        
        // Compute metrics multiple times (should all be read-only)
        _ = ScaleMetricsComputer.compute(for: libraryRoot)
        _ = ScaleMetricsComputer.compute(for: libraryRoot)
        _ = ScaleMetricsComputer.compute(for: libraryRoot)
        
        // Get mtime after multiple computations
        let finalAttributes = try FileManager.default.attributesOfItem(atPath: indexPath)
        let finalMtime = finalAttributes[.modificationDate] as? Date
        
        // Mtime should be unchanged
        XCTAssertEqual(initialMtime, finalMtime, "Index file mtime should not change after multiple read-only metrics computations")
    }
}
