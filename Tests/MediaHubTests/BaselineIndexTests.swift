//
//  BaselineIndexTests.swift
//  MediaHubTests
//
//  Tests for baseline index core functionality
//

import XCTest
@testable import MediaHub

final class BaselineIndexTests: XCTestCase {
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
    
    // MARK: - Path Normalization Tests
    
    func testNormalizePathUnderRoot() throws {
        // Create a file under library root
        let filePath = tempDirectory.appendingPathComponent("2024").appendingPathComponent("01").appendingPathComponent("IMG_1234.jpg")
        try FileManager.default.createDirectory(at: filePath.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "test".write(to: filePath, atomically: true, encoding: .utf8)
        
        // Normalize path
        let normalized = try normalizePath(filePath.path, relativeTo: libraryRoot)
        
        // Should return relative path with / separators
        XCTAssertEqual(normalized, "2024/01/IMG_1234.jpg")
    }
    
    func testNormalizePathWithNestedStructure() throws {
        // Create nested structure
        let filePath = tempDirectory.appendingPathComponent("photos").appendingPathComponent("2024").appendingPathComponent("january").appendingPathComponent("photo.jpg")
        try FileManager.default.createDirectory(at: filePath.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "test".write(to: filePath, atomically: true, encoding: .utf8)
        
        let normalized = try normalizePath(filePath.path, relativeTo: libraryRoot)
        
        XCTAssertEqual(normalized, "photos/2024/january/photo.jpg")
    }
    
    func testNormalizePathOutsideRootThrows() {
        // Try to normalize a path outside library root
        let outsidePath = "/tmp/outside/file.jpg"
        
        XCTAssertThrowsError(try normalizePath(outsidePath, relativeTo: libraryRoot)) { error in
            guard case BaselineIndexError.pathOutsideLibraryRoot(let path) = error else {
                XCTFail("Expected pathOutsideLibraryRoot error")
                return
            }
            XCTAssertEqual(path, outsidePath)
        }
    }
    
    func testNormalizePathAtRoot() throws {
        // Normalize root itself
        let normalized = try normalizePath(libraryRoot, relativeTo: libraryRoot)
        
        // Should return empty string (root is relative to itself)
        XCTAssertEqual(normalized, "")
    }
    
    // MARK: - Index Validator Tests
    
    func testValidatorWithMissingFile() {
        let indexPath = tempDirectory.appendingPathComponent("nonexistent.json").path
        
        let result = IndexValidator.validate(indexPath)
        
        guard case .invalid(let error) = result else {
            XCTFail("Expected invalid result")
            return
        }
        guard case BaselineIndexError.fileNotFound(let path) = error else {
            XCTFail("Expected fileNotFound error")
            return
        }
        XCTAssertEqual(path, indexPath)
    }
    
    func testValidatorWithInvalidJSON() throws {
        // Create a file with invalid JSON
        let indexPath = tempDirectory.appendingPathComponent("invalid.json").path
        try "{ invalid json }".write(toFile: indexPath, atomically: true, encoding: .utf8)
        
        let result = IndexValidator.validate(indexPath)
        
        guard case .invalid(let error) = result else {
            XCTFail("Expected invalid result")
            return
        }
        // Should be either invalidJSON or decodingFailed
        switch error {
        case .invalidJSON, .decodingFailed:
            break
        default:
            XCTFail("Expected invalidJSON or decodingFailed, got \(error)")
        }
    }
    
    func testValidatorWithUnsupportedVersion() throws {
        // Create index with unsupported version
        let indexPath = tempDirectory.appendingPathComponent("wrong_version.json").path
        let invalidIndex = """
        {
            "version": "2.0",
            "created": "2024-01-01T00:00:00Z",
            "lastUpdated": "2024-01-01T00:00:00Z",
            "entryCount": 0,
            "entries": []
        }
        """
        try invalidIndex.write(toFile: indexPath, atomically: true, encoding: .utf8)
        
        let result = IndexValidator.validate(indexPath)
        
        guard case .invalid(let error) = result else {
            XCTFail("Expected invalid result")
            return
        }
        guard case BaselineIndexError.unsupportedVersion(let version) = error else {
            XCTFail("Expected unsupportedVersion error")
            return
        }
        XCTAssertEqual(version, "2.0")
    }
    
    func testValidatorWithEmptyEntriesArray() throws {
        // Create valid index with empty entries
        let indexPath = tempDirectory.appendingPathComponent("empty.json").path
        let emptyIndex = BaselineIndex(entries: [])
        let indexData = try JSONEncoder().encode(emptyIndex)
        try indexData.write(to: URL(fileURLWithPath: indexPath))
        
        let result = IndexValidator.validate(indexPath)
        
        guard case .valid = result else {
            XCTFail("Expected valid result for empty entries array")
            return
        }
    }
    
    func testValidatorWithValidIndex() throws {
        // Create valid index with entries
        let indexPath = tempDirectory.appendingPathComponent("valid.json").path
        let entries = [
            IndexEntry(path: "2024/01/file1.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z"),
            IndexEntry(path: "2024/01/file2.jpg", size: 2000, mtime: "2024-01-02T00:00:00Z")
        ]
        let index = BaselineIndex(entries: entries)
        let indexData = try JSONEncoder().encode(index)
        try indexData.write(to: URL(fileURLWithPath: indexPath))
        
        let result = IndexValidator.validate(indexPath)
        
        guard case .valid = result else {
            XCTFail("Expected valid result")
            return
        }
    }
    
    // MARK: - Index Reader Tests
    
    func testReaderLoadsValidIndex() throws {
        // Create valid index
        let indexPath = tempDirectory.appendingPathComponent("index.json").path
        let entries = [
            IndexEntry(path: "2024/01/file1.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z"),
            IndexEntry(path: "2024/02/file2.jpg", size: 2000, mtime: "2024-01-02T00:00:00Z"),
            IndexEntry(path: "2024/01/file3.jpg", size: 3000, mtime: "2024-01-03T00:00:00Z")
        ]
        let originalIndex = BaselineIndex(entries: entries)
        let indexData = try JSONEncoder().encode(originalIndex)
        try indexData.write(to: URL(fileURLWithPath: indexPath))
        
        // Load index
        let loadedIndex = try BaselineIndexReader.load(from: indexPath)
        
        // Verify version
        XCTAssertEqual(loadedIndex.version, "1.0")
        XCTAssertEqual(loadedIndex.entryCount, 3)
        
        // Verify entries are sorted by path (determinism)
        XCTAssertEqual(loadedIndex.entries.count, 3)
        XCTAssertEqual(loadedIndex.entries[0].path, "2024/01/file1.jpg")
        XCTAssertEqual(loadedIndex.entries[1].path, "2024/01/file3.jpg")
        XCTAssertEqual(loadedIndex.entries[2].path, "2024/02/file2.jpg")
    }
    
    func testReaderThrowsOnMissingFile() {
        let indexPath = tempDirectory.appendingPathComponent("nonexistent.json").path
        
        XCTAssertThrowsError(try BaselineIndexReader.load(from: indexPath)) { error in
            guard case BaselineIndexError.fileNotFound(let path) = error else {
                XCTFail("Expected fileNotFound error")
                return
            }
            XCTAssertEqual(path, indexPath)
        }
    }
    
    func testReaderThrowsOnInvalidJSON() throws {
        // Create invalid JSON file
        let indexPath = tempDirectory.appendingPathComponent("invalid.json").path
        try "{ invalid }".write(toFile: indexPath, atomically: true, encoding: .utf8)
        
        XCTAssertThrowsError(try BaselineIndexReader.load(from: indexPath)) { error in
            switch error {
            case BaselineIndexError.invalidJSON, BaselineIndexError.decodingFailed:
                break
            default:
                XCTFail("Expected invalidJSON or decodingFailed error")
            }
        }
    }
    
    func testReaderThrowsOnUnsupportedVersion() throws {
        // Create index with wrong version
        let indexPath = tempDirectory.appendingPathComponent("wrong_version.json").path
        let invalidIndex = """
        {
            "version": "2.0",
            "created": "2024-01-01T00:00:00Z",
            "lastUpdated": "2024-01-01T00:00:00Z",
            "entryCount": 0,
            "entries": []
        }
        """
        try invalidIndex.write(toFile: indexPath, atomically: true, encoding: .utf8)
        
        XCTAssertThrowsError(try BaselineIndexReader.load(from: indexPath)) { error in
            guard case BaselineIndexError.unsupportedVersion(let version) = error else {
                XCTFail("Expected unsupportedVersion error")
                return
            }
            XCTAssertEqual(version, "2.0")
        }
    }
    
    // MARK: - Index Writer Tests
    
    func testWriterCreatesValidJSON() throws {
        // Create index
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRoot)
        let entries = [
            IndexEntry(path: "2024/01/file1.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z"),
            IndexEntry(path: "2024/02/file2.jpg", size: 2000, mtime: "2024-01-02T00:00:00Z")
        ]
        let index = BaselineIndex(entries: entries)
        
        // Write index
        try BaselineIndexWriter.write(index, to: indexPath, libraryRoot: libraryRoot)
        
        // Verify file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: indexPath))
        
        // Verify file is decodable
        let loadedIndex = try BaselineIndexReader.load(from: indexPath)
        XCTAssertEqual(loadedIndex.version, "1.0")
        XCTAssertEqual(loadedIndex.entryCount, 2)
        XCTAssertEqual(loadedIndex.entries.count, 2)
    }
    
    func testWriterCreatesRegistryDirectory() throws {
        // Ensure .mediahub doesn't exist
        let mediahubDir = tempDirectory.appendingPathComponent(".mediahub")
        try? FileManager.default.removeItem(at: mediahubDir)
        
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRoot)
        let index = BaselineIndex(entries: [])
        
        // Write index (should create .mediahub/registry/)
        try BaselineIndexWriter.write(index, to: indexPath, libraryRoot: libraryRoot)
        
        // Verify registry directory exists
        let registryDir = mediahubDir.appendingPathComponent("registry")
        XCTAssertTrue(FileManager.default.fileExists(atPath: registryDir.path))
        
        // Verify index file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: indexPath))
    }
    
    func testWriterRepeatWriteKeepsValidFile() throws {
        // Write index first time
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRoot)
        let entries1 = [
            IndexEntry(path: "2024/01/file1.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z")
        ]
        let index1 = BaselineIndex(entries: entries1)
        try BaselineIndexWriter.write(index1, to: indexPath, libraryRoot: libraryRoot)
        
        // Verify first write
        let loaded1 = try BaselineIndexReader.load(from: indexPath)
        XCTAssertEqual(loaded1.entryCount, 1)
        
        // Write index second time
        let entries2 = [
            IndexEntry(path: "2024/01/file1.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z"),
            IndexEntry(path: "2024/02/file2.jpg", size: 2000, mtime: "2024-01-02T00:00:00Z")
        ]
        let index2 = BaselineIndex(entries: entries2)
        try BaselineIndexWriter.write(index2, to: indexPath, libraryRoot: libraryRoot)
        
        // Verify second write (file should still be valid)
        let loaded2 = try BaselineIndexReader.load(from: indexPath)
        XCTAssertEqual(loaded2.entryCount, 2)
        
        // Verify no temp files left behind
        let registryDir = tempDirectory.appendingPathComponent(".mediahub").appendingPathComponent("registry")
        let contents = try FileManager.default.contentsOfDirectory(atPath: registryDir.path)
        let tempFiles = contents.filter { $0.contains(".mediahub-tmp-") }
        XCTAssertEqual(tempFiles.count, 0, "No temporary files should remain")
    }
    
    func testWriterRejectsPathOutsideLibraryRoot() {
        // Try to write to a path outside library root
        let indexPath = "/tmp/outside/index.json"
        let index = BaselineIndex(entries: [])
        
        XCTAssertThrowsError(try BaselineIndexWriter.write(index, to: indexPath, libraryRoot: libraryRoot)) { error in
            guard case BaselineIndexError.pathOutsideLibraryRoot(let path) = error else {
                XCTFail("Expected pathOutsideLibraryRoot error")
                return
            }
            XCTAssertEqual(path, indexPath)
        }
    }
    
    func testWriterDeterministicEncoding() throws {
        // Create index with unsorted entries
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRoot)
        let entries = [
            IndexEntry(path: "2024/02/file2.jpg", size: 2000, mtime: "2024-01-02T00:00:00Z"),
            IndexEntry(path: "2024/01/file1.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z"),
            IndexEntry(path: "2024/03/file3.jpg", size: 3000, mtime: "2024-01-03T00:00:00Z")
        ]
        let index = BaselineIndex(entries: entries)
        
        // Write index
        try BaselineIndexWriter.write(index, to: indexPath, libraryRoot: libraryRoot)
        
        // Load and verify entries are sorted
        let loadedIndex = try BaselineIndexReader.load(from: indexPath)
        XCTAssertEqual(loadedIndex.entries[0].path, "2024/01/file1.jpg")
        XCTAssertEqual(loadedIndex.entries[1].path, "2024/02/file2.jpg")
        XCTAssertEqual(loadedIndex.entries[2].path, "2024/03/file3.jpg")
        
        // Write again and verify identical JSON
        try BaselineIndexWriter.write(index, to: indexPath, libraryRoot: libraryRoot)
        let loadedIndex2 = try BaselineIndexReader.load(from: indexPath)
        
        // Both should have same sorted order
        XCTAssertEqual(loadedIndex.entries.map { $0.path }, loadedIndex2.entries.map { $0.path })
    }
    
    func testWriterAtomicWriteNoPartialFile() throws {
        // This test verifies that atomic write doesn't leave partial files
        // We can't easily simulate a write failure, but we can verify the pattern
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRoot)
        let index = BaselineIndex(entries: [
            IndexEntry(path: "test.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z")
        ])
        
        // Write index
        try BaselineIndexWriter.write(index, to: indexPath, libraryRoot: libraryRoot)
        
        // Verify final file exists and is valid
        XCTAssertTrue(FileManager.default.fileExists(atPath: indexPath))
        let loadedIndex = try BaselineIndexReader.load(from: indexPath)
        XCTAssertEqual(loadedIndex.entryCount, 1)
        
        // Verify no temp files
        let registryDir = tempDirectory.appendingPathComponent(".mediahub").appendingPathComponent("registry")
        let contents = try FileManager.default.contentsOfDirectory(atPath: registryDir.path)
        let tempFiles = contents.filter { $0.contains(".mediahub-tmp-") }
        XCTAssertEqual(tempFiles.count, 0, "No temporary files should remain after write")
    }
    
    // MARK: - v1.1 Hash Support Tests
    
    func testIndexVersion1_0WhenNoHashes() throws {
        // Create index without hashes
        let entries = [
            IndexEntry(path: "2024/01/file1.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z"),
            IndexEntry(path: "2024/02/file2.jpg", size: 2000, mtime: "2024-01-02T00:00:00Z")
        ]
        let index = BaselineIndex(entries: entries)
        
        // Should be version 1.0
        XCTAssertEqual(index.version, "1.0")
    }
    
    func testIndexVersion1_1WhenAnyHashPresent() throws {
        // Create index with at least one hash
        let entries = [
            IndexEntry(path: "2024/01/file1.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z", hash: "sha256:abc123"),
            IndexEntry(path: "2024/02/file2.jpg", size: 2000, mtime: "2024-01-02T00:00:00Z")
        ]
        let index = BaselineIndex(entries: entries)
        
        // Should be version 1.1
        XCTAssertEqual(index.version, "1.1")
    }
    
    func testIndexVersion1_1WhenAllHashesPresent() throws {
        // Create index with all hashes
        let entries = [
            IndexEntry(path: "2024/01/file1.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z", hash: "sha256:abc123"),
            IndexEntry(path: "2024/02/file2.jpg", size: 2000, mtime: "2024-01-02T00:00:00Z", hash: "sha256:def456")
        ]
        let index = BaselineIndex(entries: entries)
        
        // Should be version 1.1
        XCTAssertEqual(index.version, "1.1")
    }
    
    func testReaderLoadsV1_0IndexWithoutHash() throws {
        // Create v1.0 index JSON (without hash field)
        let indexPath = tempDirectory.appendingPathComponent("v1_0_index.json").path
        let v1_0JSON = """
        {
            "version": "1.0",
            "created": "2024-01-01T00:00:00Z",
            "lastUpdated": "2024-01-01T00:00:00Z",
            "entryCount": 2,
            "entries": [
                {
                    "path": "2024/01/file1.jpg",
                    "size": 1000,
                    "mtime": "2024-01-01T00:00:00Z"
                },
                {
                    "path": "2024/02/file2.jpg",
                    "size": 2000,
                    "mtime": "2024-01-02T00:00:00Z"
                }
            ]
        }
        """
        try v1_0JSON.write(toFile: indexPath, atomically: true, encoding: .utf8)
        
        // Load index
        let loadedIndex = try BaselineIndexReader.load(from: indexPath)
        
        // Verify version and entries
        XCTAssertEqual(loadedIndex.version, "1.0")
        XCTAssertEqual(loadedIndex.entryCount, 2)
        XCTAssertNil(loadedIndex.entries[0].hash)
        XCTAssertNil(loadedIndex.entries[1].hash)
    }
    
    func testReaderLoadsV1_1IndexWithHash() throws {
        // Create v1.1 index JSON (with hash field)
        let indexPath = tempDirectory.appendingPathComponent("v1_1_index.json").path
        let v1_1JSON = """
        {
            "version": "1.1",
            "created": "2024-01-01T00:00:00Z",
            "lastUpdated": "2024-01-01T00:00:00Z",
            "entryCount": 2,
            "entries": [
                {
                    "path": "2024/01/file1.jpg",
                    "size": 1000,
                    "mtime": "2024-01-01T00:00:00Z",
                    "hash": "sha256:abc123"
                },
                {
                    "path": "2024/02/file2.jpg",
                    "size": 2000,
                    "mtime": "2024-01-02T00:00:00Z"
                }
            ]
        }
        """
        try v1_1JSON.write(toFile: indexPath, atomically: true, encoding: .utf8)
        
        // Load index
        let loadedIndex = try BaselineIndexReader.load(from: indexPath)
        
        // Verify version and entries
        XCTAssertEqual(loadedIndex.version, "1.1")
        XCTAssertEqual(loadedIndex.entryCount, 2)
        XCTAssertEqual(loadedIndex.entries[0].hash, "sha256:abc123")
        XCTAssertNil(loadedIndex.entries[1].hash)
    }
    
    func testWriterEncodesV1_0WhenNoHashes() throws {
        // Create index without hashes
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRoot)
        let entries = [
            IndexEntry(path: "2024/01/file1.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z"),
            IndexEntry(path: "2024/02/file2.jpg", size: 2000, mtime: "2024-01-02T00:00:00Z")
        ]
        let index = BaselineIndex(entries: entries)
        
        // Write index
        try BaselineIndexWriter.write(index, to: indexPath, libraryRoot: libraryRoot)
        
        // Load and verify
        let loadedIndex = try BaselineIndexReader.load(from: indexPath)
        XCTAssertEqual(loadedIndex.version, "1.0")
        
        // Verify JSON doesn't contain hash field
        let jsonData = try Data(contentsOf: URL(fileURLWithPath: indexPath))
        let jsonString = String(data: jsonData, encoding: .utf8)!
        XCTAssertFalse(jsonString.contains("\"hash\""), "JSON should not contain hash field for v1.0")
    }
    
    func testWriterEncodesV1_1WhenHashesPresent() throws {
        // Create index with hashes
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRoot)
        let entries = [
            IndexEntry(path: "2024/01/file1.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z", hash: "sha256:abc123"),
            IndexEntry(path: "2024/02/file2.jpg", size: 2000, mtime: "2024-01-02T00:00:00Z", hash: "sha256:def456")
        ]
        let index = BaselineIndex(entries: entries)
        
        // Write index
        try BaselineIndexWriter.write(index, to: indexPath, libraryRoot: libraryRoot)
        
        // Load and verify
        let loadedIndex = try BaselineIndexReader.load(from: indexPath)
        XCTAssertEqual(loadedIndex.version, "1.1")
        XCTAssertEqual(loadedIndex.entries[0].hash, "sha256:abc123")
        XCTAssertEqual(loadedIndex.entries[1].hash, "sha256:def456")
    }
    
    func testWriterOmitNilHashFromJSON() throws {
        // Create index with mixed hashes (some nil)
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRoot)
        let entries = [
            IndexEntry(path: "2024/01/file1.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z", hash: "sha256:abc123"),
            IndexEntry(path: "2024/02/file2.jpg", size: 2000, mtime: "2024-01-02T00:00:00Z")
        ]
        let index = BaselineIndex(entries: entries)
        
        // Write index
        try BaselineIndexWriter.write(index, to: indexPath, libraryRoot: libraryRoot)
        
        // Load and verify entries directly
        let loadedIndex = try BaselineIndexReader.load(from: indexPath)
        XCTAssertEqual(loadedIndex.entryCount, 2)
        
        // Find entries by path
        let entry1 = loadedIndex.entries.first { $0.path == "2024/01/file1.jpg" }
        let entry2 = loadedIndex.entries.first { $0.path == "2024/02/file2.jpg" }
        
        XCTAssertNotNil(entry1, "First entry should exist")
        XCTAssertNotNil(entry2, "Second entry should exist")
        
        // First entry should have hash
        XCTAssertEqual(entry1?.hash, "sha256:abc123", "First entry should have hash")
        
        // Second entry should not have hash
        XCTAssertNil(entry2?.hash, "Second entry should not have hash")
        
        // Verify JSON doesn't contain hash field for second entry
        let jsonData = try Data(contentsOf: URL(fileURLWithPath: indexPath))
        let jsonString = String(data: jsonData, encoding: .utf8)!
        
        // JSON should contain hash for first entry
        XCTAssertTrue(jsonString.contains("\"hash\":\"sha256:abc123\""), "JSON should contain hash for first entry")
        
        // JSON should not contain hash field for second entry (only path, size, mtime)
        // Count occurrences of "hash" - should be exactly 1 (for first entry only)
        let hashCount = jsonString.components(separatedBy: "\"hash\"").count - 1
        XCTAssertEqual(hashCount, 1, "JSON should contain exactly one hash field")
    }
    
    func testHashToAnyPath() throws {
        // Create index with hashes (some duplicates)
        let entries = [
            IndexEntry(path: "2024/01/file1.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z", hash: "sha256:abc123"),
            IndexEntry(path: "2024/02/file2.jpg", size: 2000, mtime: "2024-01-02T00:00:00Z", hash: "sha256:def456"),
            IndexEntry(path: "2024/03/file3.jpg", size: 3000, mtime: "2024-01-03T00:00:00Z", hash: "sha256:abc123"), // Duplicate hash
            IndexEntry(path: "2024/04/file4.jpg", size: 4000, mtime: "2024-01-04T00:00:00Z") // No hash
        ]
        let index = BaselineIndex(entries: entries)
        
        // Test hashToAnyPath
        let hashToPath = index.hashToAnyPath
        
        // Should have 2 unique hashes
        XCTAssertEqual(hashToPath.count, 2)
        
        // First hash should map to first path (deterministic: sorted order)
        XCTAssertEqual(hashToPath["sha256:abc123"], "2024/01/file1.jpg")
        XCTAssertEqual(hashToPath["sha256:def456"], "2024/02/file2.jpg")
        
        // Entry without hash should not appear
        XCTAssertFalse(hashToPath.values.contains("2024/04/file4.jpg"))
    }
    
    func testHashSet() throws {
        // Create index with hashes
        let entries = [
            IndexEntry(path: "2024/01/file1.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z", hash: "sha256:abc123"),
            IndexEntry(path: "2024/02/file2.jpg", size: 2000, mtime: "2024-01-02T00:00:00Z", hash: "sha256:def456"),
            IndexEntry(path: "2024/03/file3.jpg", size: 3000, mtime: "2024-01-03T00:00:00Z", hash: "sha256:abc123"), // Duplicate hash
            IndexEntry(path: "2024/04/file4.jpg", size: 4000, mtime: "2024-01-04T00:00:00Z") // No hash
        ]
        let index = BaselineIndex(entries: entries)
        
        // Test hashSet
        let hashSet = index.hashSet
        
        // Should have 2 unique hashes (duplicate is deduplicated)
        XCTAssertEqual(hashSet.count, 2)
        XCTAssertTrue(hashSet.contains("sha256:abc123"))
        XCTAssertTrue(hashSet.contains("sha256:def456"))
    }
    
    func testHashEntryCount() throws {
        // Create index with mixed hashes
        let entries = [
            IndexEntry(path: "2024/01/file1.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z", hash: "sha256:abc123"),
            IndexEntry(path: "2024/02/file2.jpg", size: 2000, mtime: "2024-01-02T00:00:00Z"),
            IndexEntry(path: "2024/03/file3.jpg", size: 3000, mtime: "2024-01-03T00:00:00Z", hash: "sha256:def456")
        ]
        let index = BaselineIndex(entries: entries)
        
        // Should have 2 entries with hash
        XCTAssertEqual(index.hashEntryCount, 2)
    }
    
    func testHashCoverage() throws {
        // Create index with mixed hashes
        let entries = [
            IndexEntry(path: "2024/01/file1.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z", hash: "sha256:abc123"),
            IndexEntry(path: "2024/02/file2.jpg", size: 2000, mtime: "2024-01-02T00:00:00Z"),
            IndexEntry(path: "2024/03/file3.jpg", size: 3000, mtime: "2024-01-03T00:00:00Z", hash: "sha256:def456")
        ]
        let index = BaselineIndex(entries: entries)
        
        // Should have 2/3 = 0.666... coverage
        XCTAssertEqual(index.hashCoverage, 2.0 / 3.0, accuracy: 0.001)
    }
    
    func testHashCoverageEmptyIndex() throws {
        // Create empty index
        let index = BaselineIndex(entries: [])
        
        // Should have 0.0 coverage
        XCTAssertEqual(index.hashCoverage, 0.0)
    }
    
    func testUpdatingIndexVersionChangesWhenHashAdded() throws {
        // Start with v1.0 index (no hashes)
        let entries1 = [
            IndexEntry(path: "2024/01/file1.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z"),
            IndexEntry(path: "2024/02/file2.jpg", size: 2000, mtime: "2024-01-02T00:00:00Z")
        ]
        let index1 = BaselineIndex(entries: entries1)
        XCTAssertEqual(index1.version, "1.0")
        
        // Update with entry that has hash
        let newEntries = [
            IndexEntry(path: "2024/03/file3.jpg", size: 3000, mtime: "2024-01-03T00:00:00Z", hash: "sha256:abc123")
        ]
        let index2 = index1.updating(with: newEntries)
        
        // Should now be v1.1
        XCTAssertEqual(index2.version, "1.1")
    }
    
    func testUpdatingIndexVersionStays1_0WhenNoHashAdded() throws {
        // Start with v1.0 index (no hashes)
        let entries1 = [
            IndexEntry(path: "2024/01/file1.jpg", size: 1000, mtime: "2024-01-01T00:00:00Z"),
            IndexEntry(path: "2024/02/file2.jpg", size: 2000, mtime: "2024-01-02T00:00:00Z")
        ]
        let index1 = BaselineIndex(entries: entries1)
        XCTAssertEqual(index1.version, "1.0")
        
        // Update with entry without hash
        let newEntries = [
            IndexEntry(path: "2024/03/file3.jpg", size: 3000, mtime: "2024-01-03T00:00:00Z")
        ]
        let index2 = index1.updating(with: newEntries)
        
        // Should still be v1.0
        XCTAssertEqual(index2.version, "1.0")
    }
}
