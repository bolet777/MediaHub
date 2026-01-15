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
    
    // MARK: - Media Type Filtering Tests
    
    func testScanWithMediaTypesImages() throws {
        // Create test files: images and videos
        let imageFile1 = tempDirectory.appendingPathComponent("test1.jpg")
        try "fake image data".write(to: imageFile1, atomically: true, encoding: .utf8)
        
        let imageFile2 = tempDirectory.appendingPathComponent("test2.png")
        try "fake image data".write(to: imageFile2, atomically: true, encoding: .utf8)
        
        let videoFile = tempDirectory.appendingPathComponent("test.mov")
        try "fake video data".write(to: videoFile, atomically: true, encoding: .utf8)
        
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: tempDirectory.path,
            mediaTypes: .images
        )
        
        let candidates = try SourceScanner.scan(source: source)
        
        // Should only return image files
        XCTAssertEqual(candidates.count, 2)
        XCTAssertTrue(candidates.contains { $0.fileName == "test1.jpg" })
        XCTAssertTrue(candidates.contains { $0.fileName == "test2.png" })
        XCTAssertFalse(candidates.contains { $0.fileName == "test.mov" })
    }
    
    func testScanWithMediaTypesVideos() throws {
        // Create test files: images and videos
        let imageFile = tempDirectory.appendingPathComponent("test.jpg")
        try "fake image data".write(to: imageFile, atomically: true, encoding: .utf8)
        
        let videoFile1 = tempDirectory.appendingPathComponent("test1.mov")
        try "fake video data".write(to: videoFile1, atomically: true, encoding: .utf8)
        
        let videoFile2 = tempDirectory.appendingPathComponent("test2.mp4")
        try "fake video data".write(to: videoFile2, atomically: true, encoding: .utf8)
        
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: tempDirectory.path,
            mediaTypes: .videos
        )
        
        let candidates = try SourceScanner.scan(source: source)
        
        // Should only return video files
        XCTAssertEqual(candidates.count, 2)
        XCTAssertTrue(candidates.contains { $0.fileName == "test1.mov" })
        XCTAssertTrue(candidates.contains { $0.fileName == "test2.mp4" })
        XCTAssertFalse(candidates.contains { $0.fileName == "test.jpg" })
    }
    
    func testScanWithMediaTypesBoth() throws {
        // Create test files: images and videos
        let imageFile = tempDirectory.appendingPathComponent("test.jpg")
        try "fake image data".write(to: imageFile, atomically: true, encoding: .utf8)
        
        let videoFile = tempDirectory.appendingPathComponent("test.mov")
        try "fake video data".write(to: videoFile, atomically: true, encoding: .utf8)
        
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: tempDirectory.path,
            mediaTypes: .both
        )
        
        let candidates = try SourceScanner.scan(source: source)
        
        // Should return both images and videos
        XCTAssertEqual(candidates.count, 2)
        XCTAssertTrue(candidates.contains { $0.fileName == "test.jpg" })
        XCTAssertTrue(candidates.contains { $0.fileName == "test.mov" })
    }
    
    func testScanWithMediaTypesNilDefaultsToBoth() throws {
        // Create test files: images and videos
        let imageFile = tempDirectory.appendingPathComponent("test.jpg")
        try "fake image data".write(to: imageFile, atomically: true, encoding: .utf8)
        
        let videoFile = tempDirectory.appendingPathComponent("test.mov")
        try "fake video data".write(to: videoFile, atomically: true, encoding: .utf8)
        
        // Source without mediaTypes (nil) should default to .both
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: tempDirectory.path
            // mediaTypes is nil
        )
        
        let candidates = try SourceScanner.scan(source: source)
        
        // Should return both images and videos (default behavior)
        XCTAssertEqual(candidates.count, 2)
        XCTAssertTrue(candidates.contains { $0.fileName == "test.jpg" })
        XCTAssertTrue(candidates.contains { $0.fileName == "test.mov" })
    }
    
    func testScanWithMediaTypesImagesExcludesUnknownExtensions() throws {
        // Create test files: image, video, and unknown extension
        let imageFile = tempDirectory.appendingPathComponent("test.jpg")
        try "fake image data".write(to: imageFile, atomically: true, encoding: .utf8)
        
        let videoFile = tempDirectory.appendingPathComponent("test.mov")
        try "fake video data".write(to: videoFile, atomically: true, encoding: .utf8)
        
        let unknownFile = tempDirectory.appendingPathComponent("test.unknown")
        try "fake data".write(to: unknownFile, atomically: true, encoding: .utf8)
        
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: tempDirectory.path,
            mediaTypes: .images
        )
        
        let candidates = try SourceScanner.scan(source: source)
        
        // Should only return image file (video and unknown excluded)
        XCTAssertEqual(candidates.count, 1)
        XCTAssertTrue(candidates.contains { $0.fileName == "test.jpg" })
        XCTAssertFalse(candidates.contains { $0.fileName == "test.mov" })
        XCTAssertFalse(candidates.contains { $0.fileName == "test.unknown" })
    }
    
    func testScanWithMediaTypesRecursiveFiltering() throws {
        // Create nested directory structure with mixed media types
        let subDir = tempDirectory.appendingPathComponent("subdir")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        
        let rootImage = tempDirectory.appendingPathComponent("root.jpg")
        try "fake image".write(to: rootImage, atomically: true, encoding: .utf8)
        
        let rootVideo = tempDirectory.appendingPathComponent("root.mov")
        try "fake video".write(to: rootVideo, atomically: true, encoding: .utf8)
        
        let nestedImage = subDir.appendingPathComponent("nested.png")
        try "fake image".write(to: nestedImage, atomically: true, encoding: .utf8)
        
        let nestedVideo = subDir.appendingPathComponent("nested.mp4")
        try "fake video".write(to: nestedVideo, atomically: true, encoding: .utf8)
        
        let source = Source(
            sourceId: SourceIdentifierGenerator.generate(),
            type: .folder,
            path: tempDirectory.path,
            mediaTypes: .images
        )
        
        let candidates = try SourceScanner.scan(source: source)
        
        // Should only return image files from both root and nested directories
        XCTAssertEqual(candidates.count, 2)
        XCTAssertTrue(candidates.contains { $0.fileName == "root.jpg" })
        XCTAssertTrue(candidates.contains { $0.fileName == "nested.png" })
        XCTAssertFalse(candidates.contains { $0.fileName == "root.mov" })
        XCTAssertFalse(candidates.contains { $0.fileName == "nested.mp4" })
    }
}
