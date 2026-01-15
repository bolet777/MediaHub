//
//  LibraryStatisticsTests.swift
//  MediaHubTests
//
//  Tests for library statistics computation
//

import XCTest
@testable import MediaHub

final class LibraryStatisticsTests: XCTestCase {
    
    // MARK: - Basic Statistics Tests
    
    func testComputeStatisticsWithStandardPaths() throws {
        // Create index with standard YYYY/MM paths
        let entries = [
            IndexEntry(path: "2024/01/IMG_001.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z"),
            IndexEntry(path: "2024/01/IMG_002.jpg", size: 2000, mtime: "2024-01-02T00:00:00Z"),
            IndexEntry(path: "2024/02/VID_001.mov", size: 3000, mtime: "2024-02-01T00:00:00Z"),
            IndexEntry(path: "2023/12/IMG_003.png", size: 1500, mtime: "2023-12-31T00:00:00Z"),
            IndexEntry(path: "2023/12/VID_002.mp4", size: 4000, mtime: "2023-12-30T00:00:00Z")
        ]
        
        let index = BaselineIndex(entries: entries)
        let statistics = LibraryStatisticsComputer.compute(from: index)
        
        // Verify total items
        XCTAssertEqual(statistics.totalItems, 5)
        
        // Verify year distribution
        XCTAssertEqual(statistics.byYear["2024"], 3)
        XCTAssertEqual(statistics.byYear["2023"], 2)
        XCTAssertNil(statistics.byYear["unknown"])
        
        // Verify media type distribution
        XCTAssertEqual(statistics.byMediaType["images"], 3) // 2 JPG + 1 PNG
        XCTAssertEqual(statistics.byMediaType["videos"], 2) // 1 MOV + 1 MP4
    }
    
    func testComputeStatisticsWithUnknownYear() throws {
        // Create index with paths that don't follow YYYY/MM pattern
        let entries = [
            IndexEntry(path: "2024/01/IMG_001.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z"),
            IndexEntry(path: "old/photos/IMG_002.jpg", size: 2000, mtime: "2020-01-01T00:00:00Z"),
            IndexEntry(path: "misc/file.jpg", size: 1500, mtime: "2021-01-01T00:00:00Z"),
            IndexEntry(path: "IMG_003.jpg", size: 3000, mtime: "2022-01-01T00:00:00Z") // No year component
        ]
        
        let index = BaselineIndex(entries: entries)
        let statistics = LibraryStatisticsComputer.compute(from: index)
        
        // Verify total items
        XCTAssertEqual(statistics.totalItems, 4)
        
        // Verify year distribution (one valid year, rest in unknown)
        XCTAssertEqual(statistics.byYear["2024"], 1)
        XCTAssertEqual(statistics.byYear["unknown"], 3) // old, misc, and root-level file
        
        // Verify media type distribution (all images)
        XCTAssertEqual(statistics.byMediaType["images"], 4)
        XCTAssertEqual(statistics.byMediaType["videos"], 0)
    }
    
    func testComputeStatisticsWithInvalidYearPattern() throws {
        // Create index with paths that have non-numeric first component
        let entries = [
            IndexEntry(path: "2024/01/IMG_001.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z"),
            IndexEntry(path: "abcd/01/IMG_002.jpg", size: 2000, mtime: "2024-01-01T00:00:00Z"), // Invalid year
            IndexEntry(path: "123/01/IMG_003.jpg", size: 1500, mtime: "2024-01-01T00:00:00Z"), // Too short
            IndexEntry(path: "20245/01/IMG_004.jpg", size: 3000, mtime: "2024-01-01T00:00:00Z") // Too long
        ]
        
        let index = BaselineIndex(entries: entries)
        let statistics = LibraryStatisticsComputer.compute(from: index)
        
        // Verify total items
        XCTAssertEqual(statistics.totalItems, 4)
        
        // Verify year distribution (only valid 4-digit year)
        XCTAssertEqual(statistics.byYear["2024"], 1)
        XCTAssertEqual(statistics.byYear["unknown"], 3) // Invalid patterns go to unknown
        
        // Verify media type distribution
        XCTAssertEqual(statistics.byMediaType["images"], 4)
    }
    
    func testComputeStatisticsWithMixedMediaTypes() throws {
        // Create index with various image and video formats
        let entries = [
            // Images
            IndexEntry(path: "2024/01/IMG_001.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z"),
            IndexEntry(path: "2024/01/IMG_002.jpeg", size: 2000, mtime: "2024-01-01T00:00:00Z"),
            IndexEntry(path: "2024/01/IMG_003.png", size: 1500, mtime: "2024-01-01T00:00:00Z"),
            IndexEntry(path: "2024/01/IMG_004.heic", size: 3000, mtime: "2024-01-01T00:00:00Z"),
            // Videos
            IndexEntry(path: "2024/01/VID_001.mov", size: 5000, mtime: "2024-01-01T00:00:00Z"),
            IndexEntry(path: "2024/01/VID_002.mp4", size: 6000, mtime: "2024-01-01T00:00:00Z"),
            IndexEntry(path: "2024/01/VID_003.m4v", size: 7000, mtime: "2024-01-01T00:00:00Z")
        ]
        
        let index = BaselineIndex(entries: entries)
        let statistics = LibraryStatisticsComputer.compute(from: index)
        
        // Verify total items
        XCTAssertEqual(statistics.totalItems, 7)
        
        // Verify media type distribution
        XCTAssertEqual(statistics.byMediaType["images"], 4) // JPG, JPEG, PNG, HEIC
        XCTAssertEqual(statistics.byMediaType["videos"], 3) // MOV, MP4, M4V
    }
    
    func testComputeStatisticsWithUnknownExtensions() throws {
        // Create index with unknown extensions
        let entries = [
            IndexEntry(path: "2024/01/IMG_001.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z"),
            IndexEntry(path: "2024/01/file.unknown", size: 2000, mtime: "2024-01-01T00:00:00Z"),
            IndexEntry(path: "2024/01/document.pdf", size: 1500, mtime: "2024-01-01T00:00:00Z"),
            IndexEntry(path: "2024/01/file", size: 3000, mtime: "2024-01-01T00:00:00Z") // No extension
        ]
        
        let index = BaselineIndex(entries: entries)
        let statistics = LibraryStatisticsComputer.compute(from: index)
        
        // Verify total items (all counted)
        XCTAssertEqual(statistics.totalItems, 4)
        
        // Verify year distribution (all valid years)
        XCTAssertEqual(statistics.byYear["2024"], 4)
        
        // Verify media type distribution (only known extensions counted)
        XCTAssertEqual(statistics.byMediaType["images"], 1) // Only JPG
        XCTAssertEqual(statistics.byMediaType["videos"], 0)
        // Unknown extensions excluded from byMediaType but counted in totalItems
    }
    
    func testComputeStatisticsWithEmptyIndex() throws {
        // Create empty index
        let index = BaselineIndex(entries: [])
        let statistics = LibraryStatisticsComputer.compute(from: index)
        
        // Verify empty statistics
        XCTAssertEqual(statistics.totalItems, 0)
        XCTAssertEqual(statistics.byYear.count, 0)
        XCTAssertEqual(statistics.byMediaType["images"], 0)
        XCTAssertEqual(statistics.byMediaType["videos"], 0)
    }
    
    func testComputeStatisticsSinglePassPerformance() throws {
        // Create index with many entries to verify single pass
        var entries: [IndexEntry] = []
        for i in 1...1000 {
            let year = 2020 + (i % 5) // Years 2020-2024
            let isImage = i % 2 == 0
            let ext = isImage ? "jpg" : "mov"
            entries.append(IndexEntry(
                path: "\(year)/01/file\(i).\(ext)",
                size: Int64(i * 100),
                mtime: "2024-01-01T00:00:00Z"
            ))
        }
        
        let index = BaselineIndex(entries: entries)
        
        // Measure computation time (should be fast, single pass)
        let startTime = Date()
        let statistics = LibraryStatisticsComputer.compute(from: index)
        let duration = Date().timeIntervalSince(startTime)
        
        // Verify statistics
        XCTAssertEqual(statistics.totalItems, 1000)
        XCTAssertEqual(statistics.byMediaType["images"], 500) // Even numbers
        XCTAssertEqual(statistics.byMediaType["videos"], 500) // Odd numbers
        
        // Verify performance (should complete in < 1 second for 1000 entries)
        XCTAssertLessThan(duration, 1.0, "Statistics computation should be fast (single pass)")
    }
    
    func testComputeStatisticsUsesMediaFileFormatClassification() throws {
        // Verify that statistics uses same classification as scanning
        // Test with various extensions that MediaFileFormat recognizes
        let entries = [
            // Image formats
            IndexEntry(path: "2024/01/file.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z"),
            IndexEntry(path: "2024/01/file.jpeg", size: 1000, mtime: "2024-01-01T00:00:00Z"),
            IndexEntry(path: "2024/01/file.png", size: 1000, mtime: "2024-01-01T00:00:00Z"),
            IndexEntry(path: "2024/01/file.heic", size: 1000, mtime: "2024-01-01T00:00:00Z"),
            IndexEntry(path: "2024/01/file.tiff", size: 1000, mtime: "2024-01-01T00:00:00Z"),
            IndexEntry(path: "2024/01/file.cr2", size: 1000, mtime: "2024-01-01T00:00:00Z"), // RAW
            // Video formats
            IndexEntry(path: "2024/01/file.mov", size: 1000, mtime: "2024-01-01T00:00:00Z"),
            IndexEntry(path: "2024/01/file.mp4", size: 1000, mtime: "2024-01-01T00:00:00Z"),
            IndexEntry(path: "2024/01/file.m4v", size: 1000, mtime: "2024-01-01T00:00:00Z"),
            IndexEntry(path: "2024/01/file.avi", size: 1000, mtime: "2024-01-01T00:00:00Z")
        ]
        
        let index = BaselineIndex(entries: entries)
        let statistics = LibraryStatisticsComputer.compute(from: index)
        
        // Verify classification matches MediaFileFormat
        XCTAssertEqual(statistics.byMediaType["images"], 6) // JPG, JPEG, PNG, HEIC, TIFF, CR2
        XCTAssertEqual(statistics.byMediaType["videos"], 4) // MOV, MP4, M4V, AVI
    }
    
    func testComputeStatisticsYearExtractionEdgeCases() throws {
        // Test edge cases for year extraction
        let entries = [
            IndexEntry(path: "2024/01/file.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z"), // Valid
            IndexEntry(path: "0000/01/file.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z"), // Valid (4 digits)
            IndexEntry(path: "9999/01/file.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z"), // Valid (4 digits)
            IndexEntry(path: "202/01/file.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z"), // Too short -> unknown
            IndexEntry(path: "20245/01/file.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z"), // Too long -> unknown
            IndexEntry(path: "abcd/01/file.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z"), // Non-numeric -> unknown
            IndexEntry(path: "2024a/01/file.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z") // Non-numeric -> unknown
        ]
        
        let index = BaselineIndex(entries: entries)
        let statistics = LibraryStatisticsComputer.compute(from: index)
        
        // Verify year distribution
        XCTAssertEqual(statistics.byYear["2024"], 1)
        XCTAssertEqual(statistics.byYear["0000"], 1)
        XCTAssertEqual(statistics.byYear["9999"], 1)
        XCTAssertEqual(statistics.byYear["unknown"], 4) // Invalid patterns
    }
    
    // MARK: - Task 9: Consistency Checks
    
    func testUnknownExtensionsConsistencyWithScanning() throws {
        // Verify that unknown extensions are handled consistently:
        // - Excluded from byMediaType (not counted as images or videos)
        // - Counted in totalItems
        // This matches the behavior in SourceScanning (unknown extensions excluded from processing)
        let entries = [
            IndexEntry(path: "2024/01/file.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z"),
            IndexEntry(path: "2024/01/file.mov", size: 2000, mtime: "2024-01-01T00:00:00Z"),
            IndexEntry(path: "2024/01/file.unknown", size: 1500, mtime: "2024-01-01T00:00:00Z"),
            IndexEntry(path: "2024/01/document.pdf", size: 3000, mtime: "2024-01-01T00:00:00Z")
        ]
        
        let index = BaselineIndex(entries: entries)
        let statistics = LibraryStatisticsComputer.compute(from: index)
        
        // Verify totalItems includes all files
        XCTAssertEqual(statistics.totalItems, 4)
        
        // Verify byMediaType excludes unknown extensions (only known extensions counted)
        XCTAssertEqual(statistics.byMediaType["images"], 1) // Only JPG
        XCTAssertEqual(statistics.byMediaType["videos"], 1) // Only MOV
        // Unknown extensions (unknown, pdf) excluded from byMediaType but counted in totalItems
    }
    
    func testUnknownYearBucketConsistency() throws {
        // Verify that "unknown" year bucket is used consistently for all unextractable years
        let entries = [
            IndexEntry(path: "2024/01/file.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z"), // Valid year
            IndexEntry(path: "old/photos/file.jpg", size: 2000, mtime: "2024-01-01T00:00:00Z"), // Invalid -> unknown
            IndexEntry(path: "misc/file.jpg", size: 1500, mtime: "2024-01-01T00:00:00Z"), // Invalid -> unknown
            IndexEntry(path: "file.jpg", size: 3000, mtime: "2024-01-01T00:00:00Z") // No year component -> unknown
        ]
        
        let index = BaselineIndex(entries: entries)
        let statistics = LibraryStatisticsComputer.compute(from: index)
        
        // Verify totalItems includes all files
        XCTAssertEqual(statistics.totalItems, 4)
        
        // Verify year distribution: one valid year, rest in unknown bucket
        XCTAssertEqual(statistics.byYear["2024"], 1)
        XCTAssertEqual(statistics.byYear["unknown"], 3) // All invalid patterns grouped under "unknown"
    }
}
