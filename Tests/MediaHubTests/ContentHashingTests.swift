//
//  ContentHashingTests.swift
//  MediaHubTests
//
//  Tests for SHA-256 content hashing
//

import XCTest
@testable import MediaHub

final class ContentHashingTests: XCTestCase {
    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ContentHashingTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    // MARK: - Known Test Vector Tests

    func testHashEmptyFile() throws {
        // Known SHA-256 hash of empty file
        let expectedHash = "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

        let fileURL = tempDirectory.appendingPathComponent("empty.txt")
        try Data().write(to: fileURL)

        let hash = try ContentHasher.computeHash(for: fileURL, allowedRoot: tempDirectory)

        XCTAssertEqual(hash, expectedHash, "Empty file hash should match known test vector")
    }

    func testHashHelloWorld() throws {
        // Known SHA-256 hash of "hello world\n" (literal backslash-n, not newline)
        // Verified with: echo -n "hello world\n" | shasum -a 256
        let expectedHash = "sha256:a948904f2f0f479b8f8197694b30184b0d2ed1c1cd2a1ec0fb85d299a192a447"

        let fileURL = tempDirectory.appendingPathComponent("hello.txt")
        try "hello world\n".write(to: fileURL, atomically: true, encoding: .utf8)

        let hash = try ContentHasher.computeHash(for: fileURL, allowedRoot: tempDirectory)

        XCTAssertEqual(hash, expectedHash, "hello world hash should match known test vector")
    }

    func testHashBinaryNullByte() throws {
        // Known SHA-256 hash of single null byte (0x00)
        let expectedHash = "sha256:6e340b9cffb37a989ca544e6bb780a2c78901d3fb33738768511a30617afa01d"

        let fileURL = tempDirectory.appendingPathComponent("null.bin")
        try Data([0x00]).write(to: fileURL)

        let hash = try ContentHasher.computeHash(for: fileURL, allowedRoot: tempDirectory)

        XCTAssertEqual(hash, expectedHash, "Single null byte hash should match known test vector")
    }

    // MARK: - Hash Format Tests

    func testHashFormatHasPrefix() throws {
        let fileURL = tempDirectory.appendingPathComponent("test.txt")
        try "test content".write(to: fileURL, atomically: true, encoding: .utf8)

        let hash = try ContentHasher.computeHash(for: fileURL, allowedRoot: tempDirectory)

        XCTAssertTrue(hash.hasPrefix("sha256:"), "Hash should start with sha256: prefix")
    }

    func testHashFormatHas64HexChars() throws {
        let fileURL = tempDirectory.appendingPathComponent("test.txt")
        try "test content".write(to: fileURL, atomically: true, encoding: .utf8)

        let hash = try ContentHasher.computeHash(for: fileURL, allowedRoot: tempDirectory)

        // Remove prefix, check hex length
        let hexPart = String(hash.dropFirst("sha256:".count))
        XCTAssertEqual(hexPart.count, 64, "Hash should have 64 hex characters after prefix")

        // Verify all characters are valid hex
        let hexCharacters = CharacterSet(charactersIn: "0123456789abcdef")
        XCTAssertTrue(hexPart.unicodeScalars.allSatisfy { hexCharacters.contains($0) },
                      "Hash should only contain lowercase hex characters")
    }

    // MARK: - Determinism Tests

    func testHashIsDeterministic() throws {
        let fileURL = tempDirectory.appendingPathComponent("deterministic.txt")
        try "same content every time".write(to: fileURL, atomically: true, encoding: .utf8)

        let hash1 = try ContentHasher.computeHash(for: fileURL, allowedRoot: tempDirectory)
        let hash2 = try ContentHasher.computeHash(for: fileURL, allowedRoot: tempDirectory)
        let hash3 = try ContentHasher.computeHash(for: fileURL, allowedRoot: tempDirectory)

        XCTAssertEqual(hash1, hash2, "Hash should be deterministic (run 1 vs 2)")
        XCTAssertEqual(hash2, hash3, "Hash should be deterministic (run 2 vs 3)")
    }

    func testDifferentContentProducesDifferentHash() throws {
        let file1URL = tempDirectory.appendingPathComponent("file1.txt")
        let file2URL = tempDirectory.appendingPathComponent("file2.txt")

        try "content A".write(to: file1URL, atomically: true, encoding: .utf8)
        try "content B".write(to: file2URL, atomically: true, encoding: .utf8)

        let hash1 = try ContentHasher.computeHash(for: file1URL, allowedRoot: tempDirectory)
        let hash2 = try ContentHasher.computeHash(for: file2URL, allowedRoot: tempDirectory)

        XCTAssertNotEqual(hash1, hash2, "Different content should produce different hashes")
    }

    func testSameContentProducesSameHash() throws {
        let file1URL = tempDirectory.appendingPathComponent("copy1.txt")
        let file2URL = tempDirectory.appendingPathComponent("copy2.txt")

        let content = "identical content in both files"
        try content.write(to: file1URL, atomically: true, encoding: .utf8)
        try content.write(to: file2URL, atomically: true, encoding: .utf8)

        let hash1 = try ContentHasher.computeHash(for: file1URL, allowedRoot: tempDirectory)
        let hash2 = try ContentHasher.computeHash(for: file2URL, allowedRoot: tempDirectory)

        XCTAssertEqual(hash1, hash2, "Same content should produce same hash regardless of filename")
    }

    // MARK: - Error Handling Tests

    func testHashMissingFileThrowsFileNotFound() {
        let missingURL = tempDirectory.appendingPathComponent("does-not-exist.txt")

        XCTAssertThrowsError(try ContentHasher.computeHash(for: missingURL, allowedRoot: tempDirectory)) { error in
            guard case ContentHashError.fileNotFound(let path) = error else {
                XCTFail("Expected fileNotFound error, got: \(error)")
                return
            }
            XCTAssertEqual(path, missingURL.path)
        }
    }

    // MARK: - Symlink Safety Tests

    func testSymlinkWithinRootSucceeds() throws {
        // Create target file within root
        let targetURL = tempDirectory.appendingPathComponent("target.txt")
        try "symlink target content".write(to: targetURL, atomically: true, encoding: .utf8)

        // Create symlink to target
        let symlinkURL = tempDirectory.appendingPathComponent("link.txt")
        try FileManager.default.createSymbolicLink(at: symlinkURL, withDestinationURL: targetURL)

        // Hash should succeed and match target content
        let symlinkHash = try ContentHasher.computeHash(for: symlinkURL, allowedRoot: tempDirectory)
        let targetHash = try ContentHasher.computeHash(for: targetURL, allowedRoot: tempDirectory)

        XCTAssertEqual(symlinkHash, targetHash, "Symlink hash should match target file hash")
    }

    func testSymlinkOutsideRootThrows() throws {
        // Create file outside temp directory (in system temp root)
        let outsideRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("outside-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: outsideRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outsideRoot) }

        let outsideFile = outsideRoot.appendingPathComponent("outside.txt")
        try "outside content".write(to: outsideFile, atomically: true, encoding: .utf8)

        // Create symlink inside temp directory pointing outside
        let symlinkURL = tempDirectory.appendingPathComponent("escape-link.txt")
        try FileManager.default.createSymbolicLink(at: symlinkURL, withDestinationURL: outsideFile)

        // Hash should throw symlinkOutsideRoot
        XCTAssertThrowsError(try ContentHasher.computeHash(for: symlinkURL, allowedRoot: tempDirectory)) { error in
            guard case ContentHashError.symlinkOutsideRoot(let path, let root) = error else {
                XCTFail("Expected symlinkOutsideRoot error, got: \(error)")
                return
            }
            XCTAssertEqual(path, symlinkURL.path)
            XCTAssertEqual(root, tempDirectory.path)
        }
    }

    func testNestedSymlinkWithinRootSucceeds() throws {
        // Create subdirectory structure
        let subdir = tempDirectory.appendingPathComponent("subdir")
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)

        // Create target in subdirectory
        let targetURL = subdir.appendingPathComponent("nested-target.txt")
        try "nested content".write(to: targetURL, atomically: true, encoding: .utf8)

        // Create symlink at root pointing to nested file
        let symlinkURL = tempDirectory.appendingPathComponent("nested-link.txt")
        try FileManager.default.createSymbolicLink(at: symlinkURL, withDestinationURL: targetURL)

        // Should succeed
        let hash = try ContentHasher.computeHash(for: symlinkURL, allowedRoot: tempDirectory)
        XCTAssertTrue(hash.hasPrefix("sha256:"), "Should successfully hash symlink to nested file")
    }

    // MARK: - Large File Tests (Streaming Verification)

    func testHashLargeFile() throws {
        // Create a 1MB file to verify streaming works
        let fileURL = tempDirectory.appendingPathComponent("large.bin")

        // Create deterministic 1MB of data
        let oneMB = 1024 * 1024
        var data = Data(count: oneMB)
        for i in 0..<oneMB {
            data[i] = UInt8(i % 256)
        }
        try data.write(to: fileURL)

        // Hash should complete without memory issues
        let hash = try ContentHasher.computeHash(for: fileURL, allowedRoot: tempDirectory)

        XCTAssertTrue(hash.hasPrefix("sha256:"), "Should successfully hash large file")
        XCTAssertEqual(hash.count, "sha256:".count + 64, "Hash format should be correct")

        // Verify determinism on large file
        let hash2 = try ContentHasher.computeHash(for: fileURL, allowedRoot: tempDirectory)
        XCTAssertEqual(hash, hash2, "Large file hash should be deterministic")
    }

    // MARK: - Binary Content Tests

    func testHashBinaryContent() throws {
        let fileURL = tempDirectory.appendingPathComponent("binary.bin")

        // Create file with all byte values 0-255
        var data = Data(count: 256)
        for i in 0..<256 {
            data[i] = UInt8(i)
        }
        try data.write(to: fileURL)

        let hash = try ContentHasher.computeHash(for: fileURL, allowedRoot: tempDirectory)

        XCTAssertTrue(hash.hasPrefix("sha256:"), "Should successfully hash binary content")

        // Verify determinism
        let hash2 = try ContentHasher.computeHash(for: fileURL, allowedRoot: tempDirectory)
        XCTAssertEqual(hash, hash2, "Binary file hash should be deterministic")
    }
}
