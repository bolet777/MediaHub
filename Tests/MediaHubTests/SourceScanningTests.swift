//
//  SourceScanningTests.swift
//  MediaHubTests
//
//  Tests for Source scanning and media detection
//

import XCTest
@testable import MediaHub

final class SourceScanningTests: XCTestCase {
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    func testMediaFileFormatIdentification() {
        XCTAssertTrue(MediaFileFormat.isMediaFile(extension: "jpg"))
        XCTAssertTrue(MediaFileFormat.isMediaFile(extension: "JPG"))
        XCTAssertTrue(MediaFileFormat.isMediaFile(extension: ".jpg"))
        XCTAssertTrue(MediaFileFormat.isMediaFile(extension: "png"))
        XCTAssertTrue(MediaFileFormat.isMediaFile(extension: "mov"))
        XCTAssertTrue(MediaFileFormat.isMediaFile(extension: "mp4"))
        XCTAssertFalse(MediaFileFormat.isMediaFile(extension: "txt"))
        XCTAssertFalse(MediaFileFormat.isMediaFile(extension: "pdf"))
    }
    
    func testMediaFileFormatPathIdentification() {
        XCTAssertTrue(MediaFileFormat.isMediaFile(path: "/test/image.jpg"))
        XCTAssertTrue(MediaFileFormat.isMediaFile(path: "/test/video.MOV"))
        XCTAssertFalse(MediaFileFormat.isMediaFile(path: "/test/document.txt"))
    }
    
    func testScanEmptyDirectory() throws {
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: tempDirectory.path
        )
        
        let candidates = try SourceScanner.scan(source: source)
        
        XCTAssertEqual(candidates.count, 0)
    }
    
    func testScanWithMediaFiles() throws {
        // Create test media files
        let imageFile = tempDirectory.appendingPathComponent("test.jpg")
        try "fake image data".write(to: imageFile, atomically: true, encoding: .utf8)
        
        let videoFile = tempDirectory.appendingPathComponent("test.mov")
        try "fake video data".write(to: videoFile, atomically: true, encoding: .utf8)
        
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: tempDirectory.path
        )
        
        let candidates = try SourceScanner.scan(source: source)
        
        XCTAssertEqual(candidates.count, 2)
        XCTAssertTrue(candidates.contains { $0.fileName == "test.jpg" })
        XCTAssertTrue(candidates.contains { $0.fileName == "test.mov" })
    }
    
    func testScanExcludesNonMediaFiles() throws {
        // Create test files
        let imageFile = tempDirectory.appendingPathComponent("test.jpg")
        try "fake image data".write(to: imageFile, atomically: true, encoding: .utf8)
        
        let textFile = tempDirectory.appendingPathComponent("test.txt")
        try "text content".write(to: textFile, atomically: true, encoding: .utf8)
        
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: tempDirectory.path
        )
        
        let candidates = try SourceScanner.scan(source: source)
        
        XCTAssertEqual(candidates.count, 1)
        XCTAssertTrue(candidates.contains { $0.fileName == "test.jpg" })
        XCTAssertFalse(candidates.contains { $0.fileName == "test.txt" })
    }
    
    func testScanRecursive() throws {
        // Create nested directory structure
        let subDir = tempDirectory.appendingPathComponent("subdir")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        
        let rootFile = tempDirectory.appendingPathComponent("root.jpg")
        try "fake image".write(to: rootFile, atomically: true, encoding: .utf8)
        
        let nestedFile = subDir.appendingPathComponent("nested.png")
        try "fake image".write(to: nestedFile, atomically: true, encoding: .utf8)
        
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: tempDirectory.path
        )
        
        let candidates = try SourceScanner.scan(source: source)
        
        XCTAssertEqual(candidates.count, 2)
        XCTAssertTrue(candidates.contains { $0.fileName == "root.jpg" })
        XCTAssertTrue(candidates.contains { $0.fileName == "nested.png" })
    }
    
    func testScanDeterministicOrdering() throws {
        // Create multiple files
        for i in 1...5 {
            let file = tempDirectory.appendingPathComponent("file\(i).jpg")
            try "fake image \(i)".write(to: file, atomically: true, encoding: .utf8)
        }
        
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: tempDirectory.path
        )
        
        let candidates1 = try SourceScanner.scan(source: source)
        let candidates2 = try SourceScanner.scan(source: source)
        
        // Results should be identical and sorted
        XCTAssertEqual(candidates1.count, candidates2.count)
        for (c1, c2) in zip(candidates1, candidates2) {
            XCTAssertEqual(c1.path, c2.path)
        }
        
        // Should be sorted by path
        let paths = candidates1.map { $0.path }
        XCTAssertEqual(paths, paths.sorted())
    }
    
    func testScanInaccessibleSource() {
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: "/nonexistent/path"
        )
        
        XCTAssertThrowsError(try SourceScanner.scan(source: source)) { error in
            XCTAssertTrue(error is SourceScanningError)
        }
    }
}
