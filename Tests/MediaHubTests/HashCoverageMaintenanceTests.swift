//
//  HashCoverageMaintenanceTests.swift
//  MediaHubTests
//
//  Tests for hash coverage maintenance operations
//

import XCTest
@testable import MediaHub
@testable import MediaHubCLI

final class HashCoverageMaintenanceTests: XCTestCase {
    var tempDirectory: URL!
    var libraryRoot: String!
    
    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        libraryRoot = tempDirectory.path
        
        // Create .mediahub/registry directory structure
        let metadataDir = tempDirectory.appendingPathComponent(".mediahub")
        let registryDir = metadataDir.appendingPathComponent("registry")
        try? FileManager.default.createDirectory(at: registryDir, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    // MARK: - Candidate Selection Tests
    
    func testSelectCandidatesWithMixedHashCoverage() throws {
        // Create test files
        let file1 = tempDirectory.appendingPathComponent("2024/01/file1.jpg")
        let file2 = tempDirectory.appendingPathComponent("2024/01/file2.jpg")
        let file3 = tempDirectory.appendingPathComponent("2024/02/file3.jpg")
        
        try FileManager.default.createDirectory(at: file1.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: file3.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        try "content1".write(to: file1, atomically: true, encoding: .utf8)
        try "content2".write(to: file2, atomically: true, encoding: .utf8)
        try "content3".write(to: file3, atomically: true, encoding: .utf8)
        
        // Create index with mixed hash coverage
        let entries = [
            IndexEntry(path: "2024/01/file1.jpg", size: 8, mtime: "2024-01-01T00:00:00Z", hash: "sha256:abc123"), // Has hash
            IndexEntry(path: "2024/01/file2.jpg", size: 8, mtime: "2024-01-02T00:00:00Z", hash: nil), // Missing hash
            IndexEntry(path: "2024/02/file3.jpg", size: 8, mtime: "2024-01-03T00:00:00Z", hash: nil), // Missing hash
        ]
        
        let index = BaselineIndex(entries: entries)
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRoot)
        try BaselineIndexWriter.write(index, to: indexPath, libraryRoot: libraryRoot)
        
        // Select candidates
        let result = try HashCoverageMaintenance.selectCandidates(libraryRoot: libraryRoot)
        
        // Verify statistics
        XCTAssertEqual(result.statistics.totalEntries, 3)
        XCTAssertEqual(result.statistics.entriesWithHash, 1)
        XCTAssertEqual(result.statistics.entriesMissingHash, 2)
        XCTAssertEqual(result.statistics.candidateCount, 2)
        XCTAssertEqual(result.statistics.missingFilesCount, 0)
        XCTAssertEqual(result.statistics.hashCoverage, 1.0 / 3.0, accuracy: 0.001)
        
        // Verify candidates (should be sorted by normalized path)
        XCTAssertEqual(result.candidates.count, 2)
        XCTAssertEqual(result.candidates[0].path, "2024/01/file2.jpg")
        XCTAssertEqual(result.candidates[1].path, "2024/02/file3.jpg")
    }
    
    func testSelectCandidatesDeterministicOrder() throws {
        // Create test files in non-alphabetical order
        let file1 = tempDirectory.appendingPathComponent("2024/03/file3.jpg")
        let file2 = tempDirectory.appendingPathComponent("2024/01/file1.jpg")
        let file3 = tempDirectory.appendingPathComponent("2024/02/file2.jpg")
        
        try FileManager.default.createDirectory(at: file1.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: file2.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: file3.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        try "content1".write(to: file1, atomically: true, encoding: .utf8)
        try "content2".write(to: file2, atomically: true, encoding: .utf8)
        try "content3".write(to: file3, atomically: true, encoding: .utf8)
        
        // Create index with entries in non-alphabetical order
        let entries = [
            IndexEntry(path: "2024/03/file3.jpg", size: 8, mtime: "2024-01-03T00:00:00Z", hash: nil),
            IndexEntry(path: "2024/01/file1.jpg", size: 8, mtime: "2024-01-01T00:00:00Z", hash: nil),
            IndexEntry(path: "2024/02/file2.jpg", size: 8, mtime: "2024-01-02T00:00:00Z", hash: nil),
        ]
        
        let index = BaselineIndex(entries: entries)
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRoot)
        try BaselineIndexWriter.write(index, to: indexPath, libraryRoot: libraryRoot)
        
        // Select candidates
        let result = try HashCoverageMaintenance.selectCandidates(libraryRoot: libraryRoot)
        
        // Verify candidates are sorted by normalized path (deterministic order)
        XCTAssertEqual(result.candidates.count, 3)
        XCTAssertEqual(result.candidates[0].path, "2024/01/file1.jpg")
        XCTAssertEqual(result.candidates[1].path, "2024/02/file2.jpg")
        XCTAssertEqual(result.candidates[2].path, "2024/03/file3.jpg")
    }
    
    func testSelectCandidatesWithLimit() throws {
        // Create test files in non-alphabetical order to test deterministic sorting before limit
        let file1 = tempDirectory.appendingPathComponent("2024/03/file3.jpg")
        let file2 = tempDirectory.appendingPathComponent("2024/01/file1.jpg")
        let file3 = tempDirectory.appendingPathComponent("2024/02/file2.jpg")
        
        try FileManager.default.createDirectory(at: file1.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: file2.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: file3.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        try "content1".write(to: file1, atomically: true, encoding: .utf8)
        try "content2".write(to: file2, atomically: true, encoding: .utf8)
        try "content3".write(to: file3, atomically: true, encoding: .utf8)
        
        // Create index with entries in non-alphabetical order
        // BaselineIndex will sort them, but we want to test that limit is applied after sorting
        let entries = [
            IndexEntry(path: "2024/03/file3.jpg", size: 8, mtime: "2024-01-03T00:00:00Z", hash: nil),
            IndexEntry(path: "2024/01/file1.jpg", size: 8, mtime: "2024-01-01T00:00:00Z", hash: nil),
            IndexEntry(path: "2024/02/file2.jpg", size: 8, mtime: "2024-01-02T00:00:00Z", hash: nil),
        ]
        
        let index = BaselineIndex(entries: entries)
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRoot)
        try BaselineIndexWriter.write(index, to: indexPath, libraryRoot: libraryRoot)
        
        // Select candidates with limit
        let result = try HashCoverageMaintenance.selectCandidates(libraryRoot: libraryRoot, limit: 2)
        
        // Verify limit is applied
        XCTAssertEqual(result.statistics.totalEntries, 3)
        XCTAssertEqual(result.statistics.entriesMissingHash, 3)
        XCTAssertEqual(result.statistics.candidateCount, 2) // Limited to 2
        XCTAssertEqual(result.candidates.count, 2)
        
        // Verify limit takes the FIRST 2 entries in sorted (deterministic) order
        // After sorting by path: 2024/01/file1.jpg, 2024/02/file2.jpg, 2024/03/file3.jpg
        // Limit 2 should give: 2024/01/file1.jpg, 2024/02/file2.jpg
        XCTAssertEqual(result.candidates[0].path, "2024/01/file1.jpg", "Limit should take first entry in sorted order")
        XCTAssertEqual(result.candidates[1].path, "2024/02/file2.jpg", "Limit should take second entry in sorted order")
    }
    
    func testSelectCandidatesExcludesMissingFiles() throws {
        // Create only one test file
        let file1 = tempDirectory.appendingPathComponent("2024/01/file1.jpg")
        try FileManager.default.createDirectory(at: file1.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "content1".write(to: file1, atomically: true, encoding: .utf8)
        
        // Create index with one existing file and one missing file
        let entries = [
            IndexEntry(path: "2024/01/file1.jpg", size: 8, mtime: "2024-01-01T00:00:00Z", hash: nil), // Exists
            IndexEntry(path: "2024/02/missing.jpg", size: 8, mtime: "2024-01-02T00:00:00Z", hash: nil), // Missing
        ]
        
        let index = BaselineIndex(entries: entries)
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRoot)
        try BaselineIndexWriter.write(index, to: indexPath, libraryRoot: libraryRoot)
        
        // Select candidates
        let result = try HashCoverageMaintenance.selectCandidates(libraryRoot: libraryRoot)
        
        // Verify statistics
        XCTAssertEqual(result.statistics.totalEntries, 2)
        XCTAssertEqual(result.statistics.entriesMissingHash, 2)
        XCTAssertEqual(result.statistics.candidateCount, 1) // Only existing file
        XCTAssertEqual(result.statistics.missingFilesCount, 1) // One missing file
        
        // Verify only existing file is in candidates
        XCTAssertEqual(result.candidates.count, 1)
        XCTAssertEqual(result.candidates[0].path, "2024/01/file1.jpg")
    }
    
    func testSelectCandidatesThrowsOnMissingLibrary() {
        let nonExistentPath = "/nonexistent/library/path"
        
        XCTAssertThrowsError(try HashCoverageMaintenance.selectCandidates(libraryRoot: nonExistentPath)) { error in
            guard case HashCoverageMaintenanceError.libraryNotFound(let path) = error else {
                XCTFail("Expected libraryNotFound error")
                return
            }
            XCTAssertEqual(path, nonExistentPath)
        }
    }
    
    func testSelectCandidatesThrowsOnMissingIndex() throws {
        // Create library structure but no index
        let metadataDir = tempDirectory.appendingPathComponent(".mediahub")
        try FileManager.default.createDirectory(at: metadataDir, withIntermediateDirectories: true)
        
        XCTAssertThrowsError(try HashCoverageMaintenance.selectCandidates(libraryRoot: libraryRoot)) { error in
            guard case HashCoverageMaintenanceError.indexNotFound = error else {
                XCTFail("Expected indexNotFound error")
                return
            }
        }
    }
    
    func testSelectCandidatesNoWrites() throws {
        // Create test file
        let file1 = tempDirectory.appendingPathComponent("2024/01/file1.jpg")
        try FileManager.default.createDirectory(at: file1.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "content1".write(to: file1, atomically: true, encoding: .utf8)
        
        // Create index
        let entries = [
            IndexEntry(path: "2024/01/file1.jpg", size: 8, mtime: "2024-01-01T00:00:00Z", hash: nil),
        ]
        
        let index = BaselineIndex(entries: entries)
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRoot)
        try BaselineIndexWriter.write(index, to: indexPath, libraryRoot: libraryRoot)
        
        // Get original index modification time
        let originalAttributes = try FileManager.default.attributesOfItem(atPath: indexPath)
        let originalModificationDate = originalAttributes[.modificationDate] as? Date
        
        // Select candidates (should not modify index)
        _ = try HashCoverageMaintenance.selectCandidates(libraryRoot: libraryRoot)
        
        // Verify index was not modified
        let newAttributes = try FileManager.default.attributesOfItem(atPath: indexPath)
        let newModificationDate = newAttributes[.modificationDate] as? Date
        
        XCTAssertEqual(originalModificationDate, newModificationDate, "Index should not be modified by selectCandidates")
        
        // Verify index content is unchanged
        let loadedIndex = try BaselineIndexReader.load(from: indexPath)
        XCTAssertEqual(loadedIndex.entryCount, 1)
        XCTAssertEqual(loadedIndex.entries[0].path, "2024/01/file1.jpg")
        XCTAssertNil(loadedIndex.entries[0].hash)
    }
    
    // MARK: - Hash Computation Tests
    
    func testComputeMissingHashesCalculatesHashes() throws {
        // Create test files
        let file1 = tempDirectory.appendingPathComponent("2024/01/file1.jpg")
        let file2 = tempDirectory.appendingPathComponent("2024/01/file2.jpg")
        
        try FileManager.default.createDirectory(at: file1.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        try "content1".write(to: file1, atomically: true, encoding: .utf8)
        try "content2".write(to: file2, atomically: true, encoding: .utf8)
        
        // Create index without hashes
        let entries = [
            IndexEntry(path: "2024/01/file1.jpg", size: 8, mtime: "2024-01-01T00:00:00Z", hash: nil),
            IndexEntry(path: "2024/01/file2.jpg", size: 8, mtime: "2024-01-02T00:00:00Z", hash: nil),
        ]
        
        let index = BaselineIndex(entries: entries)
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRoot)
        try BaselineIndexWriter.write(index, to: indexPath, libraryRoot: libraryRoot)
        
        // Get original index modification time
        let originalAttributes = try FileManager.default.attributesOfItem(atPath: indexPath)
        let originalModificationDate = originalAttributes[.modificationDate] as? Date
        
        // Compute hashes
        let result = try HashCoverageMaintenance.computeMissingHashes(libraryRoot: libraryRoot)
        
        // Verify hashes were computed
        XCTAssertEqual(result.hashesComputed, 2)
        XCTAssertEqual(result.hashFailures, 0)
        XCTAssertEqual(result.computedHashes.count, 2)
        
        // Verify hashes are in correct format (sha256:...)
        for (_, hash) in result.computedHashes {
            XCTAssertTrue(hash.hasPrefix("sha256:"), "Hash should have sha256: prefix")
            XCTAssertEqual(hash.count, 71, "Hash should be sha256: + 64 hex chars = 71 chars")
        }
        
        // Verify hashes are different for different content
        let hash1 = result.computedHashes["2024/01/file1.jpg"]
        let hash2 = result.computedHashes["2024/01/file2.jpg"]
        XCTAssertNotNil(hash1)
        XCTAssertNotNil(hash2)
        XCTAssertNotEqual(hash1, hash2, "Different content should produce different hashes")
        
        // Verify index was NOT modified (no write)
        let newAttributes = try FileManager.default.attributesOfItem(atPath: indexPath)
        let newModificationDate = newAttributes[.modificationDate] as? Date
        
        XCTAssertEqual(originalModificationDate, newModificationDate, "Index should not be modified by computeMissingHashes")
        
        // Verify index content is unchanged (still no hashes)
        let loadedIndex = try BaselineIndexReader.load(from: indexPath)
        XCTAssertEqual(loadedIndex.entryCount, 2)
        XCTAssertNil(loadedIndex.entries[0].hash)
        XCTAssertNil(loadedIndex.entries[1].hash)
    }
    
    func testComputeMissingHashesRespectsLimit() throws {
        // Create test files
        let file1 = tempDirectory.appendingPathComponent("2024/01/file1.jpg")
        let file2 = tempDirectory.appendingPathComponent("2024/01/file2.jpg")
        let file3 = tempDirectory.appendingPathComponent("2024/02/file3.jpg")
        
        try FileManager.default.createDirectory(at: file1.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: file3.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        try "content1".write(to: file1, atomically: true, encoding: .utf8)
        try "content2".write(to: file2, atomically: true, encoding: .utf8)
        try "content3".write(to: file3, atomically: true, encoding: .utf8)
        
        // Create index without hashes
        let entries = [
            IndexEntry(path: "2024/01/file1.jpg", size: 8, mtime: "2024-01-01T00:00:00Z", hash: nil),
            IndexEntry(path: "2024/01/file2.jpg", size: 8, mtime: "2024-01-02T00:00:00Z", hash: nil),
            IndexEntry(path: "2024/02/file3.jpg", size: 8, mtime: "2024-01-03T00:00:00Z", hash: nil),
        ]
        
        let index = BaselineIndex(entries: entries)
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRoot)
        try BaselineIndexWriter.write(index, to: indexPath, libraryRoot: libraryRoot)
        
        // Compute hashes with limit
        let result = try HashCoverageMaintenance.computeMissingHashes(libraryRoot: libraryRoot, limit: 2)
        
        // Verify limit is respected
        XCTAssertEqual(result.hashesComputed, 2, "Should compute hashes for only 2 files (limit)")
        XCTAssertEqual(result.computedHashes.count, 2)
        
        // Verify first 2 files in sorted order have hashes
        XCTAssertNotNil(result.computedHashes["2024/01/file1.jpg"])
        XCTAssertNotNil(result.computedHashes["2024/01/file2.jpg"])
        XCTAssertNil(result.computedHashes["2024/02/file3.jpg"], "Third file should not have hash (limit)")
    }
    
    func testComputeMissingHashesNeverReplacesExistingHashes() throws {
        // Create test file
        let file1 = tempDirectory.appendingPathComponent("2024/01/file1.jpg")
        try FileManager.default.createDirectory(at: file1.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "content1".write(to: file1, atomically: true, encoding: .utf8)
        
        // Create index WITH existing hash
        let existingHash = "sha256:existinghash123456789012345678901234567890123456789012345678901234567890"
        let entries = [
            IndexEntry(path: "2024/01/file1.jpg", size: 8, mtime: "2024-01-01T00:00:00Z", hash: existingHash),
        ]
        
        let index = BaselineIndex(entries: entries)
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRoot)
        try BaselineIndexWriter.write(index, to: indexPath, libraryRoot: libraryRoot)
        
        // Compute hashes (should skip entries with existing hashes)
        let result = try HashCoverageMaintenance.computeMissingHashes(libraryRoot: libraryRoot)
        
        // Verify no hashes were computed (entry already has hash)
        XCTAssertEqual(result.hashesComputed, 0)
        XCTAssertEqual(result.computedHashes.count, 0)
        
        // Verify existing hash was not replaced
        let loadedIndex = try BaselineIndexReader.load(from: indexPath)
        XCTAssertEqual(loadedIndex.entries[0].hash, existingHash, "Existing hash should not be replaced")
    }
    
    func testComputeMissingHashesHandlesHashFailures() throws {
        // Note: Missing files are excluded by selectCandidates, so they never reach hash computation.
        // Hash failures can only occur for files that exist but fail during hash computation
        // (e.g., permission errors, I/O errors). This test verifies that computeMissingHashes
        // correctly handles the case where selectCandidates excludes missing files.
        
        // Create one valid file
        let file1 = tempDirectory.appendingPathComponent("2024/01/file1.jpg")
        try FileManager.default.createDirectory(at: file1.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "content1".write(to: file1, atomically: true, encoding: .utf8)
        
        // Create index with one existing file and one missing file
        // Missing file will be excluded by selectCandidates (not a candidate)
        let entries = [
            IndexEntry(path: "2024/01/file1.jpg", size: 8, mtime: "2024-01-01T00:00:00Z", hash: nil),
            IndexEntry(path: "2024/02/missing.jpg", size: 8, mtime: "2024-01-02T00:00:00Z", hash: nil), // File doesn't exist
        ]
        
        let index = BaselineIndex(entries: entries)
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRoot)
        try BaselineIndexWriter.write(index, to: indexPath, libraryRoot: libraryRoot)
        
        // Compute hashes
        let result = try HashCoverageMaintenance.computeMissingHashes(libraryRoot: libraryRoot)
        
        // Verify one hash computed, no failures (missing file excluded by selectCandidates)
        XCTAssertEqual(result.hashesComputed, 1, "Should compute hash for existing file")
        XCTAssertEqual(result.hashFailures, 0, "Missing files are excluded by selectCandidates, not hash failures")
        XCTAssertEqual(result.computedHashes.count, 1)
        XCTAssertNotNil(result.computedHashes["2024/01/file1.jpg"])
        
        // Verify statistics reflect missing file exclusion
        XCTAssertEqual(result.statistics.missingFilesCount, 1, "Statistics should report missing file")
    }
    
    // MARK: - Index Update Tests
    
    func testApplyComputedHashesAndWriteIndexUpdatesIndex() throws {
        // Create test files
        let file1 = tempDirectory.appendingPathComponent("2024/01/file1.jpg")
        let file2 = tempDirectory.appendingPathComponent("2024/01/file2.jpg")
        
        try FileManager.default.createDirectory(at: file1.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        try "content1".write(to: file1, atomically: true, encoding: .utf8)
        try "content2".write(to: file2, atomically: true, encoding: .utf8)
        
        // Create index without hashes
        let entries = [
            IndexEntry(path: "2024/01/file1.jpg", size: 8, mtime: "2024-01-01T00:00:00Z", hash: nil),
            IndexEntry(path: "2024/01/file2.jpg", size: 8, mtime: "2024-01-02T00:00:00Z", hash: nil),
        ]
        
        let index = BaselineIndex(entries: entries)
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRoot)
        try BaselineIndexWriter.write(index, to: indexPath, libraryRoot: libraryRoot)
        
        // Get original index modification time
        let originalAttributes = try FileManager.default.attributesOfItem(atPath: indexPath)
        let originalModificationDate = originalAttributes[.modificationDate] as? Date
        
        // Compute hashes
        let computationResult = try HashCoverageMaintenance.computeMissingHashes(libraryRoot: libraryRoot)
        XCTAssertEqual(computationResult.hashesComputed, 2)
        
        // Apply hashes and write index
        let updateResult = try HashCoverageMaintenance.applyComputedHashesAndWriteIndex(
            libraryRoot: libraryRoot,
            computedHashes: computationResult.computedHashes
        )
        
        // Verify update result
        XCTAssertEqual(updateResult.entriesUpdated, 2)
        XCTAssertTrue(updateResult.indexUpdated, "Index should be updated")
        XCTAssertEqual(updateResult.statisticsBefore.entriesWithHash, 0)
        XCTAssertEqual(updateResult.statisticsAfter.entriesWithHash, 2)
        
        // Verify index was modified
        let newAttributes = try FileManager.default.attributesOfItem(atPath: indexPath)
        let newModificationDate = newAttributes[.modificationDate] as? Date
        
        XCTAssertNotEqual(originalModificationDate, newModificationDate, "Index should be modified")
        
        // Verify index content has hashes
        let loadedIndex = try BaselineIndexReader.load(from: indexPath)
        XCTAssertEqual(loadedIndex.entryCount, 2)
        XCTAssertNotNil(loadedIndex.entries[0].hash)
        XCTAssertNotNil(loadedIndex.entries[1].hash)
        XCTAssertEqual(loadedIndex.version, "1.1", "Index should be upgraded to v1.1")
        
        // Verify hashes match computed hashes
        for entry in loadedIndex.entries {
            let computedHash = computationResult.computedHashes[entry.path]
            XCTAssertEqual(entry.hash, computedHash, "Hash should match computed hash")
        }
    }
    
    func testApplyComputedHashesIdempotentWhenCoverageComplete() throws {
        // Create test file
        let file1 = tempDirectory.appendingPathComponent("2024/01/file1.jpg")
        try FileManager.default.createDirectory(at: file1.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "content1".write(to: file1, atomically: true, encoding: .utf8)
        
        // Create index WITH existing hash (coverage complete)
        let existingHash = "sha256:existinghash123456789012345678901234567890123456789012345678901234567890"
        let entries = [
            IndexEntry(path: "2024/01/file1.jpg", size: 8, mtime: "2024-01-01T00:00:00Z", hash: existingHash),
        ]
        
        let index = BaselineIndex(entries: entries)
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRoot)
        try BaselineIndexWriter.write(index, to: indexPath, libraryRoot: libraryRoot)
        
        // Get original index modification time
        let originalAttributes = try FileManager.default.attributesOfItem(atPath: indexPath)
        let originalModificationDate = originalAttributes[.modificationDate] as? Date
        
        // Try to apply empty computed hashes (no candidates, coverage already complete)
        let updateResult = try HashCoverageMaintenance.applyComputedHashesAndWriteIndex(
            libraryRoot: libraryRoot,
            computedHashes: [:] // Empty: no new hashes to apply
        )
        
        // Verify no update occurred (idempotence)
        XCTAssertEqual(updateResult.entriesUpdated, 0)
        XCTAssertFalse(updateResult.indexUpdated, "Index should not be updated when coverage complete")
        XCTAssertEqual(updateResult.statisticsBefore.entriesWithHash, 1)
        XCTAssertEqual(updateResult.statisticsAfter.entriesWithHash, 1)
        
        // Verify index was NOT modified
        let newAttributes = try FileManager.default.attributesOfItem(atPath: indexPath)
        let newModificationDate = newAttributes[.modificationDate] as? Date
        
        XCTAssertEqual(originalModificationDate, newModificationDate, "Index should not be modified (idempotence)")
        
        // Verify index content unchanged
        let loadedIndex = try BaselineIndexReader.load(from: indexPath)
        XCTAssertEqual(loadedIndex.entries[0].hash, existingHash, "Existing hash should be preserved")
    }
    
    func testApplyComputedHashesNeverOverwritesExistingHash() throws {
        // Create test file
        let file1 = tempDirectory.appendingPathComponent("2024/01/file1.jpg")
        try FileManager.default.createDirectory(at: file1.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "content1".write(to: file1, atomically: true, encoding: .utf8)
        
        // Create index WITH existing hash
        let existingHash = "sha256:existinghash123456789012345678901234567890123456789012345678901234567890"
        let entries = [
            IndexEntry(path: "2024/01/file1.jpg", size: 8, mtime: "2024-01-01T00:00:00Z", hash: existingHash),
        ]
        
        let index = BaselineIndex(entries: entries)
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRoot)
        try BaselineIndexWriter.write(index, to: indexPath, libraryRoot: libraryRoot)
        
        // Try to apply a different computed hash for the same path
        let differentHash = "sha256:differenthash123456789012345678901234567890123456789012345678901234567890"
        let computedHashes = ["2024/01/file1.jpg": differentHash]
        
        let updateResult = try HashCoverageMaintenance.applyComputedHashesAndWriteIndex(
            libraryRoot: libraryRoot,
            computedHashes: computedHashes
        )
        
        // Verify no update occurred (existing hash preserved)
        XCTAssertEqual(updateResult.entriesUpdated, 0, "Should not update entry with existing hash")
        XCTAssertFalse(updateResult.indexUpdated, "Index should not be updated")
        
        // Verify existing hash was preserved (not overwritten)
        let loadedIndex = try BaselineIndexReader.load(from: indexPath)
        XCTAssertEqual(loadedIndex.entries[0].hash, existingHash, "Existing hash should be preserved, not overwritten")
        XCTAssertNotEqual(loadedIndex.entries[0].hash, differentHash, "Computed hash should not overwrite existing hash")
    }
    
    // MARK: - Performance Section Tests
    
    func testHashCoverageFormatterPerformanceSectionInHumanReadable() throws {
        // Create index with entries
        let entries = [
            IndexEntry(path: "2024/01/file1.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z", hash: "sha256:abc123"),
            IndexEntry(path: "2024/01/file2.jpg", size: 2000, mtime: "2024-01-02T00:00:00Z", hash: nil)
        ]
        let index = BaselineIndex(entries: entries)
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRoot)
        try BaselineIndexWriter.write(index, to: indexPath, libraryRoot: libraryRoot)
        
        // Create statistics
        let statistics = HashCoverageStatistics(
            totalEntries: 2,
            entriesWithHash: 1,
            entriesMissingHash: 1,
            candidateCount: 1,
            missingFilesCount: 0,
            hashCoverage: 0.5
        )
        
        // Create scale metrics
        let scaleMetrics = ScaleMetricsComputer.compute(from: index)
        
        // Format dry-run output with performance metrics
        let formatter = HashCoverageFormatter(
            libraryPath: libraryRoot,
            statistics: statistics,
            dryRun: true,
            hashesComputed: nil,
            hashFailures: nil,
            entriesUpdated: nil,
            indexUpdated: nil,
            limit: nil,
            outputFormat: .humanReadable,
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
        XCTAssertTrue(output.contains("Hash Coverage Preview"), "Existing header should be preserved")
        XCTAssertTrue(output.contains("Total entries:"), "Existing statistics should be preserved")
    }
    
    func testHashCoverageFormatterPerformanceSectionNotInJSON() throws {
        // Create statistics
        let statistics = HashCoverageStatistics(
            totalEntries: 2,
            entriesWithHash: 1,
            entriesMissingHash: 1,
            candidateCount: 1,
            missingFilesCount: 0,
            hashCoverage: 0.5
        )
        
        let scaleMetrics = ScaleMetrics(
            fileCount: 2,
            totalSizeBytes: 3000,
            hashCoveragePercent: 50.0
        )
        
        // Format JSON output with performance metrics
        let formatter = HashCoverageFormatter(
            libraryPath: libraryRoot,
            statistics: statistics,
            dryRun: true,
            hashesComputed: nil,
            hashFailures: nil,
            entriesUpdated: nil,
            indexUpdated: nil,
            limit: nil,
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
    
    func testHashCoverageFormatterPerformanceSectionNAWhenIndexMissing() throws {
        // Create statistics
        let statistics = HashCoverageStatistics(
            totalEntries: 0,
            entriesWithHash: 0,
            entriesMissingHash: 0,
            candidateCount: 0,
            missingFilesCount: 0,
            hashCoverage: 0.0
        )
        
        // Format without scale metrics (index missing)
        let formatter = HashCoverageFormatter(
            libraryPath: libraryRoot,
            statistics: statistics,
            dryRun: true,
            hashesComputed: nil,
            hashFailures: nil,
            entriesUpdated: nil,
            indexUpdated: nil,
            limit: nil,
            outputFormat: .humanReadable,
            scaleMetrics: nil,
            durationSeconds: nil
        )
        let output = formatter.format()
        
        // Verify Performance section shows N/A
        XCTAssertTrue(output.contains("Performance"), "Performance section should be present")
        XCTAssertTrue(output.contains("Performance: N/A (baseline index not available)"), "Performance should show N/A when index missing")
        
        // Verify existing content is preserved
        XCTAssertTrue(output.contains("Hash Coverage Preview"), "Existing header should be preserved")
    }
    
    // MARK: - JSON Performance Object Tests
    
    func testHashCoverageFormatterJSONIncludesPerformance() throws {
        // Create index with entries
        let entries = [
            IndexEntry(path: "2024/01/file1.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z", hash: "sha256:abc123"),
            IndexEntry(path: "2024/01/file2.jpg", size: 2000, mtime: "2024-01-02T00:00:00Z", hash: nil)
        ]
        let index = BaselineIndex(entries: entries)
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRoot)
        try BaselineIndexWriter.write(index, to: indexPath, libraryRoot: libraryRoot)
        
        // Create statistics
        let statistics = HashCoverageStatistics(
            totalEntries: 2,
            entriesWithHash: 1,
            entriesMissingHash: 1,
            candidateCount: 1,
            missingFilesCount: 0,
            hashCoverage: 0.5
        )
        
        // Create scale metrics
        let scaleMetrics = ScaleMetricsComputer.compute(from: index)
        
        // Format JSON output with performance metrics
        let formatter = HashCoverageFormatter(
            libraryPath: libraryRoot,
            statistics: statistics,
            dryRun: true,
            hashesComputed: nil,
            hashFailures: nil,
            entriesUpdated: nil,
            indexUpdated: nil,
            limit: nil,
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
        XCTAssertEqual(scale["fileCount"] as! Int, 2, "fileCount should match")
        XCTAssertEqual(scale["totalSizeBytes"] as! Int64, 3000, "totalSizeBytes should match")
        
        // Verify no "Performance" text appears in JSON
        XCTAssertFalse(jsonString.contains("Performance\n"), "Performance section text should not appear in JSON output")
        XCTAssertFalse(jsonString.contains("Duration:"), "Duration label should not appear in JSON output")
        
        // Verify existing fields are preserved
        XCTAssertNotNil(json["dryRun"], "Existing fields should be preserved")
        XCTAssertNotNil(json["library"], "Existing fields should be preserved")
    }
    
    func testHashCoverageFormatterJSONOmitsPerformanceWhenIndexMissing() throws {
        // Create statistics
        let statistics = HashCoverageStatistics(
            totalEntries: 0,
            entriesWithHash: 0,
            entriesMissingHash: 0,
            candidateCount: 0,
            missingFilesCount: 0,
            hashCoverage: 0.0
        )
        
        // Format JSON without scale metrics (index missing)
        let formatter = HashCoverageFormatter(
            libraryPath: libraryRoot,
            statistics: statistics,
            dryRun: true,
            hashesComputed: nil,
            hashFailures: nil,
            entriesUpdated: nil,
            indexUpdated: nil,
            limit: nil,
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
        XCTAssertNotNil(json["dryRun"], "Existing fields should be preserved")
        XCTAssertNotNil(json["library"], "Existing fields should be preserved")
    }
}
