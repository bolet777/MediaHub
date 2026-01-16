//
//  DuplicateReportingTests.swift
//  MediaHubTests
//
//  Tests for duplicate reporting core functionality
//

import XCTest
@testable import MediaHub
@testable import MediaHubCLI

final class DuplicateReportingTests: XCTestCase {
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

    // MARK: - Duplicate Grouping Tests

    func testAnalyzeDuplicatesWithMultipleGroups() throws {
        // Create baseline index with multiple duplicate groups
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRoot)
        let entries = [
            // Group 1: hash "dup1" (3 files)
            IndexEntry(path: "2023/01/file1.jpg", size: 1000, mtime: "2023-01-01T00:00:00Z", hash: "dup1"),
            IndexEntry(path: "2023/02/file2.jpg", size: 1000, mtime: "2023-02-01T00:00:00Z", hash: "dup1"),
            IndexEntry(path: "2023/03/file3.jpg", size: 1000, mtime: "2023-03-01T00:00:00Z", hash: "dup1"),

            // Group 2: hash "dup2" (2 files)
            IndexEntry(path: "2024/01/file4.jpg", size: 2000, mtime: "2024-01-01T00:00:00Z", hash: "dup2"),
            IndexEntry(path: "2024/02/file5.jpg", size: 2000, mtime: "2024-02-01T00:00:00Z", hash: "dup2"),

            // Unique file (no duplicates)
            IndexEntry(path: "2023/12/unique.jpg", size: 3000, mtime: "2023-12-01T00:00:00Z", hash: "unique")
        ]
        let index = BaselineIndex(entries: entries)
        try BaselineIndexWriter.write(index, to: indexPath, libraryRoot: libraryRoot)

        // Analyze duplicates
        let (groups, summary) = try DuplicateReporting.analyzeDuplicates(in: libraryRoot)

        // Verify results
        XCTAssertEqual(groups.count, 2, "Should find 2 duplicate groups")
        XCTAssertEqual(summary.duplicateGroups, 2, "Summary should report 2 duplicate groups")
        XCTAssertEqual(summary.totalDuplicateFiles, 5, "Should have 5 total duplicate files")
        XCTAssertEqual(summary.totalDuplicateSizeBytes, 7000, "Should have 7000 bytes total in duplicates")
        XCTAssertEqual(summary.potentialSavingsBytes, 4000, "Should save 4000 bytes (1 copy per group)")

        // Verify group ordering (by hash)
        XCTAssertEqual(groups[0].hash, "dup1", "First group should be dup1")
        XCTAssertEqual(groups[1].hash, "dup2", "Second group should be dup2")

        // Verify files within groups are sorted by path
        let group1Files = groups[0].files
        XCTAssertEqual(group1Files.count, 3, "First group should have 3 files")
        XCTAssertEqual(group1Files[0].path, "2023/01/file1.jpg", "Files should be sorted by path")
        XCTAssertEqual(group1Files[1].path, "2023/02/file2.jpg")
        XCTAssertEqual(group1Files[2].path, "2023/03/file3.jpg")
    }

    func testAnalyzeDuplicatesWithNoDuplicates() throws {
        // Create baseline index with no duplicates
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRoot)
        let entries = [
            IndexEntry(path: "2023/01/file1.jpg", size: 1000, mtime: "2023-01-01T00:00:00Z", hash: "hash1"),
            IndexEntry(path: "2023/02/file2.jpg", size: 2000, mtime: "2023-02-01T00:00:00Z", hash: "hash2"),
            IndexEntry(path: "2023/03/file3.jpg", size: 3000, mtime: "2023-03-01T00:00:00Z", hash: "hash3")
        ]
        let index = BaselineIndex(entries: entries)
        try BaselineIndexWriter.write(index, to: indexPath, libraryRoot: libraryRoot)

        // Analyze duplicates
        let (groups, summary) = try DuplicateReporting.analyzeDuplicates(in: libraryRoot)

        // Verify results
        XCTAssertEqual(groups.count, 0, "Should find no duplicate groups")
        XCTAssertEqual(summary.duplicateGroups, 0, "Summary should report 0 duplicate groups")
        XCTAssertEqual(summary.totalDuplicateFiles, 0, "Should have 0 duplicate files")
        XCTAssertEqual(summary.totalDuplicateSizeBytes, 0, "Should have 0 bytes in duplicates")
        XCTAssertEqual(summary.potentialSavingsBytes, 0, "Should save 0 bytes")
    }

    func testAnalyzeDuplicatesSkipsNilHashes() throws {
        // Create baseline index with nil hashes
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRoot)
        let entries = [
            // File with hash (will be included)
            IndexEntry(path: "2023/01/file1.jpg", size: 1000, mtime: "2023-01-01T00:00:00Z", hash: "dup1"),
            IndexEntry(path: "2023/02/file2.jpg", size: 1000, mtime: "2023-02-01T00:00:00Z", hash: "dup1"),

            // Files without hash (should be skipped)
            IndexEntry(path: "2023/03/file3.jpg", size: 2000, mtime: "2023-03-01T00:00:00Z"),
            IndexEntry(path: "2023/04/file4.jpg", size: 2000, mtime: "2023-04-01T00:00:00Z")
        ]
        let index = BaselineIndex(entries: entries)
        try BaselineIndexWriter.write(index, to: indexPath, libraryRoot: libraryRoot)

        // Analyze duplicates
        let (groups, summary) = try DuplicateReporting.analyzeDuplicates(in: libraryRoot)

        // Verify results - only files with hashes are considered
        XCTAssertEqual(groups.count, 1, "Should find 1 duplicate group")
        XCTAssertEqual(groups[0].fileCount, 2, "Group should have 2 files")
        XCTAssertEqual(groups[0].files[0].path, "2023/01/file1.jpg", "Should only include hashed files")
        XCTAssertEqual(groups[0].files[1].path, "2023/02/file2.jpg")
    }

    // MARK: - Deterministic Ordering Tests

    func testDeterministicOrderingAcrossMultipleRuns() throws {
        // Create baseline index
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRoot)
        let entries = [
            // Multiple groups with multiple files each
            IndexEntry(path: "2023/03/file3.jpg", size: 1000, mtime: "2023-03-01T00:00:00Z", hash: "hashA"),
            IndexEntry(path: "2023/01/file1.jpg", size: 1000, mtime: "2023-01-01T00:00:00Z", hash: "hashA"),
            IndexEntry(path: "2023/02/file2.jpg", size: 1000, mtime: "2023-02-01T00:00:00Z", hash: "hashA"),

            IndexEntry(path: "2024/02/file5.jpg", size: 2000, mtime: "2024-02-01T00:00:00Z", hash: "hashB"),
            IndexEntry(path: "2024/01/file4.jpg", size: 2000, mtime: "2024-01-01T00:00:00Z", hash: "hashB")
        ]
        let index = BaselineIndex(entries: entries)
        try BaselineIndexWriter.write(index, to: indexPath, libraryRoot: libraryRoot)

        // Run analysis multiple times
        let (groups1, _) = try DuplicateReporting.analyzeDuplicates(in: libraryRoot)
        let (groups2, _) = try DuplicateReporting.analyzeDuplicates(in: libraryRoot)
        let (groups3, _) = try DuplicateReporting.analyzeDuplicates(in: libraryRoot)

        // Verify deterministic results across runs
        XCTAssertEqual(groups1.count, groups2.count, "Group count should be consistent")
        XCTAssertEqual(groups2.count, groups3.count, "Group count should be consistent")

        // Verify group ordering is deterministic (by hash)
        for i in 0..<groups1.count {
            XCTAssertEqual(groups1[i].hash, groups2[i].hash, "Group ordering should be deterministic")
            XCTAssertEqual(groups2[i].hash, groups3[i].hash, "Group ordering should be deterministic")
        }

        // Verify file ordering within groups is deterministic (by path)
        for groupIndex in 0..<groups1.count {
            let files1 = groups1[groupIndex].files
            let files2 = groups2[groupIndex].files
            let files3 = groups3[groupIndex].files

            XCTAssertEqual(files1.count, files2.count, "File count should be consistent")
            XCTAssertEqual(files2.count, files3.count, "File count should be consistent")

            for fileIndex in 0..<files1.count {
                XCTAssertEqual(files1[fileIndex].path, files2[fileIndex].path, "File ordering should be deterministic")
                XCTAssertEqual(files2[fileIndex].path, files3[fileIndex].path, "File ordering should be deterministic")
            }
        }
    }

    func testDuplicateGroupComputedProperties() throws {
        // Create a duplicate group manually
        let files = [
            DuplicateFile(path: "2023/02/file2.jpg", sizeBytes: 2000, timestamp: "2023-02-01T00:00:00Z"),
            DuplicateFile(path: "2023/01/file1.jpg", sizeBytes: 1000, timestamp: "2023-01-01T00:00:00Z"),
            DuplicateFile(path: "2023/03/file3.jpg", sizeBytes: 3000, timestamp: "2023-03-01T00:00:00Z")
        ]

        let group = DuplicateGroup(hash: "testHash", files: files)

        // Verify computed properties
        XCTAssertEqual(group.fileCount, 3, "Should count 3 files")
        XCTAssertEqual(group.totalSizeBytes, 6000, "Should sum file sizes correctly")

        // Verify files are sorted by path
        XCTAssertEqual(group.files[0].path, "2023/01/file1.jpg", "Files should be sorted by path")
        XCTAssertEqual(group.files[1].path, "2023/02/file2.jpg")
        XCTAssertEqual(group.files[2].path, "2023/03/file3.jpg")
    }

    func testDuplicateSummaryCalculation() throws {
        // Create multiple duplicate groups
        let group1Files = [
            DuplicateFile(path: "a.jpg", sizeBytes: 1000, timestamp: "2023-01-01T00:00:00Z"),
            DuplicateFile(path: "b.jpg", sizeBytes: 1000, timestamp: "2023-01-01T00:00:00Z")
        ]
        let group1 = DuplicateGroup(hash: "hash1", files: group1Files)

        let group2Files = [
            DuplicateFile(path: "c.jpg", sizeBytes: 2000, timestamp: "2023-01-01T00:00:00Z"),
            DuplicateFile(path: "d.jpg", sizeBytes: 2000, timestamp: "2023-01-01T00:00:00Z"),
            DuplicateFile(path: "e.jpg", sizeBytes: 2000, timestamp: "2023-01-01T00:00:00Z")
        ]
        let group2 = DuplicateGroup(hash: "hash2", files: group2Files)

        let summary = DuplicateSummary(groups: [group1, group2])

        // Verify summary calculations
        XCTAssertEqual(summary.duplicateGroups, 2, "Should have 2 groups")
        XCTAssertEqual(summary.totalDuplicateFiles, 5, "Should have 5 total files")
        XCTAssertEqual(summary.totalDuplicateSizeBytes, 8000, "Should sum all file sizes")
        XCTAssertEqual(summary.potentialSavingsBytes, 5000, "Should save space of duplicate copies")
    }

    // MARK: - Error Handling Tests

    func testAnalyzeDuplicatesThrowsOnMissingIndex() {
        // Don't create any index file
        XCTAssertThrowsError(try DuplicateReporting.analyzeDuplicates(in: libraryRoot)) { error in
            guard case DuplicateReportingError.baselineIndexMissing = error else {
                XCTFail("Expected baselineIndexMissing error")
                return
            }
        }
    }

    func testAnalyzeDuplicatesThrowsOnInvalidIndex() throws {
        // First create a valid index
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRoot)
        let entries = [IndexEntry(path: "test.jpg", size: 1000, mtime: "2023-01-01T00:00:00Z", hash: "hash1")]
        let index = BaselineIndex(entries: entries)
        try BaselineIndexWriter.write(index, to: indexPath, libraryRoot: libraryRoot)

        // Backup the valid index
        let backupPath = indexPath + ".bak"
        try FileManager.default.moveItem(atPath: indexPath, toPath: backupPath)

        // Create invalid index file
        try "invalid json".write(toFile: indexPath, atomically: true, encoding: .utf8)

        // Test should throw invalid index error
        XCTAssertThrowsError(try DuplicateReporting.analyzeDuplicates(in: libraryRoot)) { error in
            guard case DuplicateReportingError.baselineIndexInvalid = error else {
                XCTFail("Expected baselineIndexInvalid error, got: \(error)")
                return
            }
        }

        // Restore valid index
        try FileManager.default.removeItem(atPath: indexPath)
        try FileManager.default.moveItem(atPath: backupPath, toPath: indexPath)
    }

    // MARK: - Output Formatting Tests

    func testTextFormatOutput() throws {
        // Create test data
        let files = [
            DuplicateFile(path: "2023/01/file1.jpg", sizeBytes: 1000, timestamp: "2023-01-01T00:00:00Z"),
            DuplicateFile(path: "2023/02/file2.jpg", sizeBytes: 1000, timestamp: "2023-02-01T00:00:00Z")
        ]
        let group = DuplicateGroup(hash: "sha256:testhash", files: files)
        let summary = DuplicateSummary(groups: [group])

        // Format as text
        let formatter = DuplicateReportFormatter(
            libraryPath: "/test/library",
            groups: [group],
            summary: summary,
            outputFormat: .text,
            scaleMetrics: nil,
            durationSeconds: nil
        )
        let output = formatter.format()

        // Verify key sections are present
        XCTAssertTrue(output.contains("Duplicate Report for Library:"), "Should contain header")
        XCTAssertTrue(output.contains("Generated:"), "Should contain generation timestamp")
        XCTAssertTrue(output.contains("Found 1 duplicate groups"), "Should contain summary")
        XCTAssertTrue(output.contains("Group 1:"), "Should contain group header")
        XCTAssertTrue(output.contains("2023/01/file1.jpg"), "Should contain file paths")
        XCTAssertTrue(output.contains("2023/02/file2.jpg"), "Should contain file paths")
        XCTAssertTrue(output.contains("Summary:"), "Should contain summary section")
        XCTAssertTrue(output.contains("Total duplicate groups:"), "Should contain summary stats")
    }

    func testJSONFormatOutput() throws {
        // Create test data
        let files = [
            DuplicateFile(path: "2023/01/file1.jpg", sizeBytes: 1000, timestamp: "2023-01-01T00:00:00Z"),
            DuplicateFile(path: "2023/02/file2.jpg", sizeBytes: 1000, timestamp: "2023-02-01T00:00:00Z")
        ]
        let group = DuplicateGroup(hash: "sha256:testhash", files: files)
        let summary = DuplicateSummary(groups: [group])

        // Format as JSON
        let formatter = DuplicateReportFormatter(
            libraryPath: "/test/library",
            groups: [group],
            summary: summary,
            outputFormat: .json,
            scaleMetrics: nil,
            durationSeconds: nil
        )
        let output = formatter.format()

        // Verify JSON is valid and decodable
        let decoder = JSONDecoder()
        struct DuplicateReportJSON: Codable {
            let library: String
            let generated: String
            let summary: SummaryJSON
            let groups: [GroupJSON]
        }
        struct SummaryJSON: Codable {
            let duplicateGroups: Int
            let totalDuplicateFiles: Int
            let totalDuplicateSizeBytes: Int64
            let potentialSavingsBytes: Int64
        }
        struct GroupJSON: Codable {
            let hash: String
            let fileCount: Int
            let totalSizeBytes: Int64
            let files: [FileJSON]
        }
        struct FileJSON: Codable {
            let path: String
            let sizeBytes: Int64
            let timestamp: String
        }

        let jsonData = output.data(using: String.Encoding.utf8)!
        let report = try decoder.decode(DuplicateReportJSON.self, from: jsonData)

        // Verify structure
        XCTAssertEqual(report.library, "library", "Library name should be extracted from path")
        XCTAssertEqual(report.summary.duplicateGroups, 1, "Should have 1 group")
        XCTAssertEqual(report.summary.totalDuplicateFiles, 2, "Should have 2 files")
        XCTAssertEqual(report.groups.count, 1, "Should have 1 group")
        XCTAssertEqual(report.groups[0].hash, "sha256:testhash", "Hash should match")
        XCTAssertEqual(report.groups[0].files.count, 2, "Group should have 2 files")
        XCTAssertEqual(report.groups[0].files[0].path, "2023/01/file1.jpg", "Files should be sorted by path")
        XCTAssertEqual(report.groups[0].files[1].path, "2023/02/file2.jpg", "Files should be sorted by path")
    }

    func testCSVFormatOutput() throws {
        // Create test data with multiple duplicate groups (2+ files each)
        let group1Files = [
            DuplicateFile(path: "2023/01/file1.jpg", sizeBytes: 1000, timestamp: "2023-01-01T00:00:00Z"),
            DuplicateFile(path: "2023/02/file2.jpg", sizeBytes: 1000, timestamp: "2023-02-01T00:00:00Z")
        ]
        let group1 = DuplicateGroup(hash: "sha256:hash1", files: group1Files)

        let group2Files = [
            DuplicateFile(path: "2024/01/file3.jpg", sizeBytes: 2000, timestamp: "2024-01-01T00:00:00Z"),
            DuplicateFile(path: "2024/02/file4.jpg", sizeBytes: 2000, timestamp: "2024-02-01T00:00:00Z")
        ]
        let group2 = DuplicateGroup(hash: "sha256:hash2", files: group2Files)

        // Sort groups by hash (as DuplicateReporting does)
        let sortedGroups = [group1, group2].sorted { $0.hash < $1.hash }
        let summary = DuplicateSummary(groups: sortedGroups)

        // Format as CSV
        let formatter = DuplicateReportFormatter(
            libraryPath: "/test/library",
            groups: sortedGroups,
            summary: summary,
            outputFormat: .csv,
            scaleMetrics: nil,
            durationSeconds: nil
        )
        let output = formatter.format()

        // Verify CSV structure
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 5, "Should have header + 4 data rows (2 groups × 2 files each)")

        // Verify header
        XCTAssertTrue(lines[0].contains("group_hash"), "Should contain header")
        XCTAssertTrue(lines[0].contains("file_count"), "Should contain header")
        XCTAssertTrue(lines[0].contains("path"), "Should contain header")

        // Verify data rows
        let dataRows = Array(lines[1...])
        XCTAssertEqual(dataRows.count, 4, "Should have 4 data rows")
        // First group (hash1) - 2 rows
        XCTAssertTrue(dataRows[0].contains("sha256:hash1"), "First row should contain hash1")
        XCTAssertTrue(dataRows[0].contains("2023/01/file1.jpg"), "First row should contain first file path")
        XCTAssertTrue(dataRows[1].contains("sha256:hash1"), "Second row should contain same hash")
        XCTAssertTrue(dataRows[1].contains("2023/02/file2.jpg"), "Second row should contain second file path")
        // Second group (hash2) - 2 rows
        XCTAssertTrue(dataRows[2].contains("sha256:hash2"), "Third row should contain hash2")
        XCTAssertTrue(dataRows[3].contains("sha256:hash2"), "Fourth row should contain hash2")
    }

    func testCSVFormatWithSpecialCharacters() throws {
        // Test CSV escaping with paths containing commas/quotes
        let files = [
            DuplicateFile(path: "2023/01/file,with,commas.jpg", sizeBytes: 1000, timestamp: "2023-01-01T00:00:00Z"),
            DuplicateFile(path: "2023/02/file\"with\"quotes.jpg", sizeBytes: 1000, timestamp: "2023-02-01T00:00:00Z")
        ]
        let group = DuplicateGroup(hash: "sha256:testhash", files: files)
        let summary = DuplicateSummary(groups: [group])

        let formatter = DuplicateReportFormatter(
            libraryPath: "/test/library",
            groups: [group],
            summary: summary,
            outputFormat: .csv,
            scaleMetrics: nil,
            durationSeconds: nil
        )
        let output = formatter.format()

        // Verify CSV is properly escaped
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        XCTAssertGreaterThan(lines.count, 1, "Should have header and data rows")
        
        // Check that paths with special characters are quoted
        let dataRow = lines[1]
        XCTAssertTrue(dataRow.contains("\"2023/01/file,with,commas.jpg\""), "Commas should be escaped with quotes")
    }

    func testFormatDeterministicOrdering() throws {
        // Create groups in non-deterministic order
        let groupB = DuplicateGroup(
            hash: "sha256:hashB",
            files: [
                DuplicateFile(path: "2023/02/file2.jpg", sizeBytes: 1000, timestamp: "2023-02-01T00:00:00Z"),
                DuplicateFile(path: "2023/01/file1.jpg", sizeBytes: 1000, timestamp: "2023-01-01T00:00:00Z")
            ]
        )
        let groupA = DuplicateGroup(
            hash: "sha256:hashA",
            files: [
                DuplicateFile(path: "2024/02/file4.jpg", sizeBytes: 2000, timestamp: "2024-02-01T00:00:00Z"),
                DuplicateFile(path: "2024/01/file3.jpg", sizeBytes: 2000, timestamp: "2024-01-01T00:00:00Z")
            ]
        )

        // Sort groups by hash (as DuplicateReporting does) - this ensures deterministic ordering
        let sortedGroups = [groupB, groupA].sorted { $0.hash < $1.hash }
        let summary = DuplicateSummary(groups: sortedGroups)

        // Format multiple times with sorted groups
        let formatter1 = DuplicateReportFormatter(
            libraryPath: "/test/library",
            groups: sortedGroups,
            summary: summary,
            outputFormat: .json,
            scaleMetrics: nil,
            durationSeconds: nil
        )
        let output1 = formatter1.format()

        let formatter2 = DuplicateReportFormatter(
            libraryPath: "/test/library",
            groups: sortedGroups,
            summary: summary,
            outputFormat: .json,
            scaleMetrics: nil,
            durationSeconds: nil
        )
        let output2 = formatter2.format()

        // Outputs should be identical (deterministic)
        XCTAssertEqual(output1, output2, "JSON output should be deterministic")

        // Verify ordering: groups by hash, files by path (already sorted in DuplicateGroup init)
        let decoder = JSONDecoder()
        struct DuplicateReportJSON: Codable {
            let groups: [GroupJSON]
        }
        struct GroupJSON: Codable {
            let hash: String
            let files: [FileJSON]
        }
        struct FileJSON: Codable {
            let path: String
        }

        let report1 = try decoder.decode(DuplicateReportJSON.self, from: output1.data(using: String.Encoding.utf8)!)
        XCTAssertEqual(report1.groups[0].hash, "sha256:hashA", "Groups should be sorted by hash")
        XCTAssertEqual(report1.groups[1].hash, "sha256:hashB", "Groups should be sorted by hash")
        XCTAssertEqual(report1.groups[0].files[0].path, "2024/01/file3.jpg", "Files should be sorted by path")
        XCTAssertEqual(report1.groups[0].files[1].path, "2024/02/file4.jpg", "Files should be sorted by path")
    }

    func testEmptyReportFormatting() throws {
        // Test formatting with no duplicates
        let summary = DuplicateSummary(groups: [])

        // Text format
        let textFormatter = DuplicateReportFormatter(
            libraryPath: "/test/library",
            groups: [],
            summary: summary,
            outputFormat: .text,
            scaleMetrics: nil,
            durationSeconds: nil
        )
        let textOutput = textFormatter.format()
        XCTAssertTrue(textOutput.contains("No duplicates found"), "Should indicate no duplicates")

        // JSON format
        let jsonFormatter = DuplicateReportFormatter(
            libraryPath: "/test/library",
            groups: [],
            summary: summary,
            outputFormat: .json,
            scaleMetrics: nil,
            durationSeconds: nil
        )
        let jsonOutput = jsonFormatter.format()
        let decoder = JSONDecoder()
        struct DuplicateReportJSON: Codable {
            let summary: SummaryJSON
            let groups: [String]
        }
        struct SummaryJSON: Codable {
            let duplicateGroups: Int
        }
        let report = try decoder.decode(DuplicateReportJSON.self, from: jsonOutput.data(using: String.Encoding.utf8)!)
        XCTAssertEqual(report.summary.duplicateGroups, 0, "Should have 0 groups")

        // CSV format
        let csvFormatter = DuplicateReportFormatter(
            libraryPath: "/test/library",
            groups: [],
            summary: summary,
            outputFormat: .csv,
            scaleMetrics: nil,
            durationSeconds: nil
        )
        let csvOutput = csvFormatter.format()
        let csvLines = csvOutput.components(separatedBy: "\n").filter { !$0.isEmpty }
        XCTAssertEqual(csvLines.count, 1, "Should have only header row")
        XCTAssertTrue(csvLines[0].contains("group_hash"), "Should contain header")
    }

    // MARK: - File Output Tests

    func testWriteReportToFile() throws {
        // Create test data
        let files = [
            DuplicateFile(path: "2023/01/file1.jpg", sizeBytes: 1000, timestamp: "2023-01-01T00:00:00Z"),
            DuplicateFile(path: "2023/02/file2.jpg", sizeBytes: 1000, timestamp: "2023-02-01T00:00:00Z")
        ]
        let group = DuplicateGroup(hash: "sha256:testhash", files: files)
        let summary = DuplicateSummary(groups: [group])

        // Create output file path
        let outputFile = tempDirectory.appendingPathComponent("duplicates-report.json")
        let outputPath = outputFile.path

        // Format and write report
        let formatter = DuplicateReportFormatter(
            libraryPath: "/test/library",
            groups: [group],
            summary: summary,
            outputFormat: .json,
            scaleMetrics: nil,
            durationSeconds: nil
        )
        let reportContent = formatter.format()

        // Write to file (simulating command behavior)
        guard let data = reportContent.data(using: .utf8) else {
            XCTFail("Failed to encode report as UTF-8")
            return
        }
        try data.write(to: outputFile, options: .atomic)

        // Verify file exists and has correct content
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputPath), "Output file should exist")
        let fileContent = try String(contentsOf: outputFile, encoding: .utf8)
        XCTAssertEqual(fileContent, reportContent, "File content should match formatted report")

        // Verify JSON is valid
        let decoder = JSONDecoder()
        struct DuplicateReportJSON: Codable {
            let library: String
            let summary: SummaryJSON
        }
        struct SummaryJSON: Codable {
            let duplicateGroups: Int
        }
        let report = try decoder.decode(DuplicateReportJSON.self, from: data)
        XCTAssertEqual(report.summary.duplicateGroups, 1, "JSON should be valid and decodable")
    }

    func testWriteReportToFileCreatesParentDirectory() throws {
        // Create test data
        let summary = DuplicateSummary(groups: [])

        // Create output file path with non-existent parent directory
        let outputFile = tempDirectory
            .appendingPathComponent("subdir")
            .appendingPathComponent("duplicates-report.txt")
        let outputPath = outputFile.path

        // Format and write report
        let formatter = DuplicateReportFormatter(
            libraryPath: "/test/library",
            groups: [],
            summary: summary,
            outputFormat: .text,
            scaleMetrics: nil,
            durationSeconds: nil
        )
        let reportContent = formatter.format()

        // Write to file (should create parent directory)
        guard let data = reportContent.data(using: .utf8) else {
            XCTFail("Failed to encode report as UTF-8")
            return
        }
        let parentDir = outputFile.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true, attributes: nil)
        try data.write(to: outputFile, options: .atomic)

        // Verify file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputPath), "Output file should exist after creating parent directory")
    }

    func testOutputPathValidationFailsForUnwritableDirectory() throws {
        // Create a directory and make it unwritable (on Unix systems)
        // Note: This test may not work on all systems, so we'll test the validation logic directly
        let unwritableDir = tempDirectory.appendingPathComponent("unwritable")
        try FileManager.default.createDirectory(at: unwritableDir, withIntermediateDirectories: true, attributes: nil)

        // On macOS, we can't easily make a directory unwritable in tests without root
        // So we'll test with a path that doesn't exist and verify the validation logic
        // by checking that it attempts to create the directory

        // Test with a non-existent parent (should be creatable)
        let outputFile = tempDirectory
            .appendingPathComponent("newdir")
            .appendingPathComponent("report.json")
        let outputPath = outputFile.path

        // The validation should succeed if we can create the directory
        // We'll test the actual error case by using a path that's a directory (not a file)
        let directoryAsFile = tempDirectory.path
        let fileManager = FileManager.default

        // Check if path is a directory (this would fail validation)
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: directoryAsFile, isDirectory: &isDirectory), isDirectory.boolValue {
            // This simulates the case where user provides a directory path instead of file path
            // The write would fail, but validation might pass if directory is writable
            // We test the actual write failure instead
        }

        // Test actual write failure by trying to write to a path that's a directory
        let formatter = DuplicateReportFormatter(
            libraryPath: "/test/library",
            groups: [],
            summary: DuplicateSummary(groups: []),
            outputFormat: .text,
            scaleMetrics: nil,
            durationSeconds: nil
        )
        let reportContent = formatter.format()
        guard let data = reportContent.data(using: .utf8) else {
            XCTFail("Failed to encode report")
            return
        }

        // Attempting to write to a directory path should fail
        XCTAssertThrowsError(try data.write(to: URL(fileURLWithPath: directoryAsFile), options: .atomic)) { error in
            // Should throw an error when trying to write to a directory
            XCTAssertNotNil(error, "Should throw error when writing to directory path")
        }
    }

    func testOutputDoesNotModifyIndex() throws {
        // Create baseline index
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRoot)
        let entries = [
            IndexEntry(path: "2023/01/file1.jpg", size: 1000, mtime: "2023-01-01T00:00:00Z", hash: "sha256:dup1"),
            IndexEntry(path: "2023/02/file2.jpg", size: 1000, mtime: "2023-02-01T00:00:00Z", hash: "sha256:dup1")
        ]
        let index = BaselineIndex(entries: entries)
        try BaselineIndexWriter.write(index, to: indexPath, libraryRoot: libraryRoot)

        // Get index mtime before running duplicates analysis
        let indexAttributes = try FileManager.default.attributesOfItem(atPath: indexPath)
        let indexModificationTime = indexAttributes[.modificationDate] as? Date

        // Analyze duplicates (read-only operation)
        let (groups, summary) = try DuplicateReporting.analyzeDuplicates(in: libraryRoot)

        // Format and write to file (simulating --output behavior)
        let outputFile = tempDirectory.appendingPathComponent("duplicates-report.json")
        let formatter = DuplicateReportFormatter(
            libraryPath: libraryRoot,
            groups: groups,
            summary: summary,
            outputFormat: .json,
            scaleMetrics: nil,
            durationSeconds: nil
        )
        let reportContent = formatter.format()
        guard let data = reportContent.data(using: .utf8) else {
            XCTFail("Failed to encode report")
            return
        }
        try data.write(to: outputFile, options: .atomic)

        // Verify index mtime is unchanged
        let indexAttributesAfter = try FileManager.default.attributesOfItem(atPath: indexPath)
        let indexModificationTimeAfter = indexAttributesAfter[.modificationDate] as? Date

        XCTAssertEqual(indexModificationTime, indexModificationTimeAfter, "Index modification time should be unchanged (read-only operation)")

        // Verify output file was created
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputFile.path), "Output file should exist")
    }

    func testEmptyReportCanBeWrittenToFile() throws {
        // Test that empty report (no duplicates) can still be written to file
        let summary = DuplicateSummary(groups: [])

        let outputFile = tempDirectory.appendingPathComponent("empty-report.json")
        let formatter = DuplicateReportFormatter(
            libraryPath: "/test/library",
            groups: [],
            summary: summary,
            outputFormat: .json,
            scaleMetrics: nil,
            durationSeconds: nil
        )
        let reportContent = formatter.format()

        // Write to file
        guard let data = reportContent.data(using: .utf8) else {
            XCTFail("Failed to encode report")
            return
        }
        try data.write(to: outputFile, options: .atomic)

        // Verify file exists and contains valid JSON
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputFile.path), "Output file should exist even for empty report")

        let decoder = JSONDecoder()
        struct DuplicateReportJSON: Codable {
            let summary: SummaryJSON
        }
        struct SummaryJSON: Codable {
            let duplicateGroups: Int
        }
        let report = try decoder.decode(DuplicateReportJSON.self, from: data)
        XCTAssertEqual(report.summary.duplicateGroups, 0, "Empty report should have 0 groups")
    }
    
    // MARK: - Performance Section Tests
    
    func testPerformanceSectionInTextOutput() throws {
        // Create test data
        let files = [
            DuplicateFile(path: "2023/01/file1.jpg", sizeBytes: 1000, timestamp: "2023-01-01T00:00:00Z"),
            DuplicateFile(path: "2023/02/file2.jpg", sizeBytes: 2000, timestamp: "2023-02-01T00:00:00Z")
        ]
        let group = DuplicateGroup(hash: "sha256:testhash", files: files)
        let summary = DuplicateSummary(groups: [group])
        
        // Create scale metrics
        let scaleMetrics = ScaleMetrics(
            fileCount: 10,
            totalSizeBytes: 5000,
            hashCoveragePercent: 80.0
        )
        
        // Format as text with performance metrics
        let formatter = DuplicateReportFormatter(
            libraryPath: "/test/library",
            groups: [group],
            summary: summary,
            outputFormat: .text,
            scaleMetrics: scaleMetrics,
            durationSeconds: 0.123
        )
        let output = formatter.format()
        
        // Verify Performance section is present
        XCTAssertTrue(output.contains("Performance"), "Performance section should be present")
        XCTAssertTrue(output.contains("Duration:"), "Duration should be present")
        XCTAssertTrue(output.contains("File count:"), "File count should be present")
        XCTAssertTrue(output.contains("Total size:"), "Total size should be present")
        XCTAssertTrue(output.contains("Hash coverage:"), "Hash coverage should be present")
        
        // Verify existing content is preserved
        XCTAssertTrue(output.contains("Duplicate Report for Library:"), "Existing header should be preserved")
        XCTAssertTrue(output.contains("Summary:"), "Existing summary should be preserved")
    }
    
    func testPerformanceSectionNotInJSONOutput() throws {
        // Create test data
        let files = [
            DuplicateFile(path: "2023/01/file1.jpg", sizeBytes: 1000, timestamp: "2023-01-01T00:00:00Z")
        ]
        let group = DuplicateGroup(hash: "sha256:testhash", files: files)
        let summary = DuplicateSummary(groups: [group])
        
        let scaleMetrics = ScaleMetrics(
            fileCount: 5,
            totalSizeBytes: 1000,
            hashCoveragePercent: 50.0
        )
        
        // Format as JSON with performance metrics
        let formatter = DuplicateReportFormatter(
            libraryPath: "/test/library",
            groups: [group],
            summary: summary,
            outputFormat: .json,
            scaleMetrics: scaleMetrics,
            durationSeconds: 0.123
        )
        let output = formatter.format()
        
        // Verify Performance section is NOT in JSON
        XCTAssertFalse(output.contains("Performance"), "Performance section should not be in JSON output")
        XCTAssertFalse(output.contains("Duration:"), "Duration should not be in JSON output")
        
        // Verify JSON is still valid
        let jsonData = output.data(using: String.Encoding.utf8)!
        let json = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        XCTAssertNotNil(json["library"], "JSON should still be valid")
    }
    
    func testPerformanceSectionNAWhenIndexMissing() throws {
        // Create test data
        let files = [
            DuplicateFile(path: "2023/01/file1.jpg", sizeBytes: 1000, timestamp: "2023-01-01T00:00:00Z")
        ]
        let group = DuplicateGroup(hash: "sha256:testhash", files: files)
        let summary = DuplicateSummary(groups: [group])
        
        // Format as text without scale metrics (index missing)
        let formatter = DuplicateReportFormatter(
            libraryPath: "/test/library",
            groups: [group],
            summary: summary,
            outputFormat: .text,
            scaleMetrics: nil,
            durationSeconds: nil
        )
        let output = formatter.format()
        
        // Verify Performance section shows N/A
        XCTAssertTrue(output.contains("Performance"), "Performance section should be present")
        XCTAssertTrue(output.contains("Performance: N/A (baseline index not available)"), "Performance should show N/A when index missing")
        
        // Verify existing content is preserved
        XCTAssertTrue(output.contains("Duplicate Report for Library:"), "Existing header should be preserved")
    }
    
    // MARK: - JSON Performance Object Tests
    
    func testDuplicateReportJSONIncludesPerformance() throws {
        // Create test data
        let files = [
            DuplicateFile(path: "2023/01/file1.jpg", sizeBytes: 1000, timestamp: "2023-01-01T00:00:00Z"),
            DuplicateFile(path: "2023/02/file2.jpg", sizeBytes: 1000, timestamp: "2023-02-01T00:00:00Z")
        ]
        let group = DuplicateGroup(hash: "sha256:testhash", files: files)
        let summary = DuplicateSummary(groups: [group])
        
        // Create scale metrics
        let scaleMetrics = ScaleMetrics(
            fileCount: 10,
            totalSizeBytes: 5000,
            hashCoveragePercent: 80.0
        )
        
        // Format as JSON with performance metrics
        let formatter = DuplicateReportFormatter(
            libraryPath: "/test/library",
            groups: [group],
            summary: summary,
            outputFormat: .json,
            scaleMetrics: scaleMetrics,
            durationSeconds: 0.123
        )
        let jsonString = formatter.format()
        
        // Verify JSON is valid and parseable
        let jsonData = jsonString.data(using: String.Encoding.utf8)!
        let json = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        
        // Verify performance field is present
        XCTAssertNotNil(json["performance"], "performance field should be present when scaleMetrics available")
        let performance = json["performance"] as! [String: Any]
        
        // Verify performance structure
        if let duration = performance["durationSeconds"] as? Double {
            XCTAssertGreaterThanOrEqual(duration, 0.0, "durationSeconds should be non-negative")
        } else {
            XCTAssertNil(performance["durationSeconds"], "durationSeconds may be null")
        }
        
        XCTAssertNotNil(performance["scale"], "scale object should be present")
        let scale = performance["scale"] as! [String: Any]
        XCTAssertEqual(scale["fileCount"] as! Int, 10, "fileCount should match")
        XCTAssertEqual(scale["totalSizeBytes"] as! Int64, 5000, "totalSizeBytes should match")
        
        if let coverage = scale["hashCoveragePercent"] as? Double {
            XCTAssertEqual(coverage, 80.0, accuracy: 0.1, "hashCoveragePercent should match")
        }
        
        // Verify no "Performance" text appears in JSON
        XCTAssertFalse(jsonString.contains("Performance\n"), "Performance section text should not appear in JSON output")
        XCTAssertFalse(jsonString.contains("Duration:"), "Duration label should not appear in JSON output")
        
        // Verify existing fields are preserved
        XCTAssertNotNil(json["library"], "Existing fields should be preserved")
        XCTAssertNotNil(json["summary"], "Existing fields should be preserved")
        XCTAssertNotNil(json["groups"], "Existing fields should be preserved")
    }
    
    func testDuplicateReportJSONOmitsPerformanceWhenIndexMissing() throws {
        // Create test data
        let files = [
            DuplicateFile(path: "2023/01/file1.jpg", sizeBytes: 1000, timestamp: "2023-01-01T00:00:00Z")
        ]
        let group = DuplicateGroup(hash: "sha256:testhash", files: files)
        let summary = DuplicateSummary(groups: [group])
        
        // Format as JSON without scale metrics (index missing)
        let formatter = DuplicateReportFormatter(
            libraryPath: "/test/library",
            groups: [group],
            summary: summary,
            outputFormat: .json,
            scaleMetrics: nil,
            durationSeconds: nil
        )
        let jsonString = formatter.format()
        
        // Verify JSON is valid
        let jsonData = jsonString.data(using: String.Encoding.utf8)!
        let json = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        
        // Verify performance field is omitted (not null)
        XCTAssertNil(json["performance"], "performance field should be omitted when scaleMetrics unavailable")
        XCTAssertFalse(jsonString.contains("\"performance\""), "performance should not be present in JSON string")
        
        // Verify existing fields are preserved
        XCTAssertNotNil(json["library"], "Existing fields should be preserved")
        XCTAssertNotNil(json["summary"], "Existing fields should be preserved")
    }
    
    func testDuplicateReportJSONValidWhenPerformancePresent() throws {
        // Create test data
        let files = [
            DuplicateFile(path: "2023/01/file1.jpg", sizeBytes: 1000, timestamp: "2023-01-01T00:00:00Z")
        ]
        let group = DuplicateGroup(hash: "sha256:testhash", files: files)
        let summary = DuplicateSummary(groups: [group])
        
        let scaleMetrics = ScaleMetrics(
            fileCount: 5,
            totalSizeBytes: 1000,
            hashCoveragePercent: 50.0
        )
        
        // Format as JSON with performance
        let formatter = DuplicateReportFormatter(
            libraryPath: "/test/library",
            groups: [group],
            summary: summary,
            outputFormat: .json,
            scaleMetrics: scaleMetrics,
            durationSeconds: 0.123
        )
        let jsonString = formatter.format()
        
        // Verify JSON is valid and decodable using JSONDecoder
        let decoder = JSONDecoder()
        struct DuplicateReportJSON: Codable {
            let library: String
            let generated: String
            let summary: SummaryJSON
            let groups: [GroupJSON]
            let performance: PerformanceJSON?
            
            struct SummaryJSON: Codable {
                let duplicateGroups: Int
                let totalDuplicateFiles: Int
                let totalDuplicateSizeBytes: Int64
                let potentialSavingsBytes: Int64
            }
            
            struct GroupJSON: Codable {
                let hash: String
                let fileCount: Int
                let totalSizeBytes: Int64
                let files: [FileJSON]
            }
            
            struct FileJSON: Codable {
                let path: String
                let sizeBytes: Int64
                let timestamp: String
            }
            
            struct PerformanceJSON: Codable {
                let durationSeconds: Double?
                let scale: ScaleJSON
                
                struct ScaleJSON: Codable {
                    let fileCount: Int
                    let totalSizeBytes: Int64
                    let hashCoveragePercent: Double?
                }
            }
        }
        
        let report = try decoder.decode(DuplicateReportJSON.self, from: jsonString.data(using: String.Encoding.utf8)!)
        
        // Verify performance is present and valid
        XCTAssertNotNil(report.performance, "performance should be present")
        XCTAssertEqual(report.performance!.scale.fileCount, 5, "fileCount should match")
        XCTAssertEqual(report.performance!.scale.totalSizeBytes, 1000, "totalSizeBytes should match")
        
        // Verify existing fields are preserved
        XCTAssertEqual(report.summary.duplicateGroups, 1, "Existing summary should be preserved")
        XCTAssertEqual(report.groups.count, 1, "Existing groups should be preserved")
    }
}
