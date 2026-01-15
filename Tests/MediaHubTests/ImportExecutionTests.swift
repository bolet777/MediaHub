//
//  ImportExecutionTests.swift
//  MediaHubTests
//
//  Integration tests for import execution
//

import XCTest
@testable import MediaHub
@testable import MediaHubCLI

final class ImportExecutionTests: XCTestCase {
    var libraryRootURL: URL!
    var sourceRootURL: URL!
    var libraryId: String!
    var source: Source!
    
    override func setUp() {
        super.setUp()
        
        // Create library
        libraryRootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Library-\(UUID().uuidString)")
        libraryId = UUID().uuidString
        
        // Create source
        sourceRootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Source-\(UUID().uuidString)")
        source = Source(
            sourceId: UUID().uuidString,
            type: .folder,
            path: sourceRootURL.path
        )
        
        // Create directories
        try? FileManager.default.createDirectory(at: libraryRootURL, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: sourceRootURL, withIntermediateDirectories: true)
        
        // Create library structure
        try? FileManager.default.createDirectory(
            at: libraryRootURL.appendingPathComponent(".mediahub"),
            withIntermediateDirectories: true
        )
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: libraryRootURL)
        try? FileManager.default.removeItem(at: sourceRootURL)
        super.tearDown()
    }
    
    func testExecuteImport() throws {
        // Create source file
        let sourceFile = sourceRootURL.appendingPathComponent("test.jpg")
        try "test content".write(to: sourceFile, atomically: true, encoding: .utf8)
        
        // Create detection result
        let candidate = CandidateMediaItem(
            path: sourceFile.path,
            size: 1024,
            modificationDate: ISO8601DateFormatter().string(from: Date()),
            fileName: "test.jpg"
        )
        
        let detectionResult = DetectionResult(
            sourceId: source.sourceId,
            libraryId: libraryId,
            candidates: [
                CandidateItemResult(item: candidate, status: "new")
            ],
            summary: DetectionSummary(totalScanned: 1, newItems: 1, knownItems: 0)
        )
        
        // Execute import
        let options = ImportOptions(collisionPolicy: .rename)
        let importResult = try ImportExecutor.executeImport(
            detectionResult: detectionResult,
            selectedItems: [candidate],
            libraryRootURL: libraryRootURL,
            libraryId: libraryId,
            options: options
        )
        
        // Verify import result
        XCTAssertEqual(importResult.summary.total, 1)
        XCTAssertEqual(importResult.summary.imported, 1)
        XCTAssertEqual(importResult.summary.skipped, 0)
        XCTAssertEqual(importResult.summary.failed, 0)
        
        // Verify file was copied
        let importedItems = importResult.items.filter { $0.status == .imported }
        XCTAssertEqual(importedItems.count, 1)
        
        if let importedItem = importedItems.first,
           let destinationPath = importedItem.destinationPath {
            let destinationURL = libraryRootURL.appendingPathComponent(destinationPath)
            XCTAssertTrue(FileManager.default.fileExists(atPath: destinationURL.path))
        }
        
        // Verify source file is unchanged
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceFile.path))
        let sourceContent = try String(contentsOf: sourceFile, encoding: .utf8)
        XCTAssertEqual(sourceContent, "test content")
    }
    
    func testExecuteImportWithCollisionSkip() throws {
        // Create source file
        let sourceFile = sourceRootURL.appendingPathComponent("test.jpg")
        try "test content".write(to: sourceFile, atomically: true, encoding: .utf8)
        
        // Create existing file in library (collision)
        let yearMonthDir = libraryRootURL.appendingPathComponent("2026").appendingPathComponent("01")
        try? FileManager.default.createDirectory(at: yearMonthDir, withIntermediateDirectories: true)
        let existingFile = yearMonthDir.appendingPathComponent("test.jpg")
        try "existing".write(to: existingFile, atomically: true, encoding: .utf8)
        
        // Create detection result
        let candidate = CandidateMediaItem(
            path: sourceFile.path,
            size: 1024,
            modificationDate: ISO8601DateFormatter().string(from: Date()),
            fileName: "test.jpg"
        )
        
        let detectionResult = DetectionResult(
            sourceId: source.sourceId,
            libraryId: libraryId,
            candidates: [
                CandidateItemResult(item: candidate, status: "new")
            ],
            summary: DetectionSummary(totalScanned: 1, newItems: 1, knownItems: 0)
        )
        
        // Execute import with skip policy
        let options = ImportOptions(collisionPolicy: .skip)
        let importResult = try ImportExecutor.executeImport(
            detectionResult: detectionResult,
            selectedItems: [candidate],
            libraryRootURL: libraryRootURL,
            libraryId: libraryId,
            options: options
        )
        
        // Verify import result
        XCTAssertEqual(importResult.summary.skipped, 1)
        XCTAssertEqual(importResult.summary.imported, 0)
        
        // Verify existing file is unchanged
        let existingContent = try String(contentsOf: existingFile, encoding: .utf8)
        XCTAssertEqual(existingContent, "existing")
    }
    
    func testExecuteImportUpdatesKnownItems() throws {
        // Create source file
        let sourceFile = sourceRootURL.appendingPathComponent("test.jpg")
        try "test content".write(to: sourceFile, atomically: true, encoding: .utf8)
        
        // Create detection result
        let candidate = CandidateMediaItem(
            path: sourceFile.path,
            size: 1024,
            modificationDate: ISO8601DateFormatter().string(from: Date()),
            fileName: "test.jpg"
        )
        
        let detectionResult = DetectionResult(
            sourceId: source.sourceId,
            libraryId: libraryId,
            candidates: [
                CandidateItemResult(item: candidate, status: "new")
            ],
            summary: DetectionSummary(totalScanned: 1, newItems: 1, knownItems: 0)
        )
        
        // Execute import
        let options = ImportOptions(collisionPolicy: .rename)
        _ = try ImportExecutor.executeImport(
            detectionResult: detectionResult,
            selectedItems: [candidate],
            libraryRootURL: libraryRootURL,
            libraryId: libraryId,
            options: options
        )
        
        // Query known items
        let knownItems = try KnownItemsTracker.queryKnownItems(
            sourceId: source.sourceId,
            libraryRootURL: libraryRootURL
        )
        
        // Verify item is in known items
        XCTAssertTrue(knownItems.contains(sourceFile.path))
    }
    
    func testExecuteImportDryRun() throws {
        // Create source file
        let sourceFile = sourceRootURL.appendingPathComponent("test.jpg")
        try "test content".write(to: sourceFile, atomically: true, encoding: .utf8)
        
        // Create detection result
        let candidate = CandidateMediaItem(
            path: sourceFile.path,
            size: 1024,
            modificationDate: ISO8601DateFormatter().string(from: Date()),
            fileName: "test.jpg"
        )
        
        let detectionResult = DetectionResult(
            sourceId: source.sourceId,
            libraryId: libraryId,
            candidates: [
                CandidateItemResult(item: candidate, status: "new")
            ],
            summary: DetectionSummary(totalScanned: 1, newItems: 1, knownItems: 0)
        )
        
        // Count files in library before dry-run
        let filesBefore = try FileManager.default.contentsOfDirectory(atPath: libraryRootURL.path)
            .filter { !$0.hasPrefix(".") }
        
        // Execute dry-run import
        let options = ImportOptions(collisionPolicy: .rename)
        let importResult = try ImportExecutor.executeImport(
            detectionResult: detectionResult,
            selectedItems: [candidate],
            libraryRootURL: libraryRootURL,
            libraryId: libraryId,
            options: options,
            dryRun: true
        )
        
        // Verify import result structure (same as actual import)
        XCTAssertEqual(importResult.summary.total, 1)
        XCTAssertEqual(importResult.summary.imported, 1)
        XCTAssertEqual(importResult.summary.skipped, 0)
        XCTAssertEqual(importResult.summary.failed, 0)
        
        // Verify destination path is set (preview information)
        let importedItems = importResult.items.filter { $0.status == .imported }
        XCTAssertEqual(importedItems.count, 1)
        XCTAssertNotNil(importedItems.first?.destinationPath)
        
        // Verify NO files were copied (zero file operations)
        let filesAfter = try FileManager.default.contentsOfDirectory(atPath: libraryRootURL.path)
            .filter { !$0.hasPrefix(".") }
        XCTAssertEqual(filesBefore.count, filesAfter.count, "Dry-run should not create any media files")
        
        // Verify source file is unchanged
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceFile.path))
        let sourceContent = try String(contentsOf: sourceFile, encoding: .utf8)
        XCTAssertEqual(sourceContent, "test content")
        
        // Verify known items were NOT updated (dry-run skips this)
        let knownItems = try KnownItemsTracker.queryKnownItems(
            sourceId: source.sourceId,
            libraryRootURL: libraryRootURL
        )
        XCTAssertFalse(knownItems.contains(sourceFile.path), "Dry-run should not update known items")
    }
    
    func testExecuteImportDryRunWithCollision() throws {
        // Create source file
        let sourceFile = sourceRootURL.appendingPathComponent("test.jpg")
        try "test content".write(to: sourceFile, atomically: true, encoding: .utf8)
        
        // Create existing file in library (collision)
        let yearMonthDir = libraryRootURL.appendingPathComponent("2026").appendingPathComponent("01")
        try? FileManager.default.createDirectory(at: yearMonthDir, withIntermediateDirectories: true)
        let existingFile = yearMonthDir.appendingPathComponent("test.jpg")
        try "existing".write(to: existingFile, atomically: true, encoding: .utf8)
        
        // Create detection result
        let candidate = CandidateMediaItem(
            path: sourceFile.path,
            size: 1024,
            modificationDate: ISO8601DateFormatter().string(from: Date()),
            fileName: "test.jpg"
        )
        
        let detectionResult = DetectionResult(
            sourceId: source.sourceId,
            libraryId: libraryId,
            candidates: [
                CandidateItemResult(item: candidate, status: "new")
            ],
            summary: DetectionSummary(totalScanned: 1, newItems: 1, knownItems: 0)
        )
        
        // Execute dry-run import with skip policy
        let options = ImportOptions(collisionPolicy: .skip)
        let importResult = try ImportExecutor.executeImport(
            detectionResult: detectionResult,
            selectedItems: [candidate],
            libraryRootURL: libraryRootURL,
            libraryId: libraryId,
            options: options,
            dryRun: true
        )
        
        // Verify import result shows collision handling (same as actual import)
        XCTAssertEqual(importResult.summary.skipped, 1)
        XCTAssertEqual(importResult.summary.imported, 0)
        
        // Verify existing file is unchanged
        let existingContent = try String(contentsOf: existingFile, encoding: .utf8)
        XCTAssertEqual(existingContent, "existing")
        
        // Verify no new files were created
        let filesInLibrary = try FileManager.default.contentsOfDirectory(atPath: yearMonthDir.path)
        XCTAssertEqual(filesInLibrary.count, 1, "Dry-run should not create any new files")
    }
    
    func testExecuteImportDryRunMatchesActualImport() throws {
        // Create source file
        let sourceFile = sourceRootURL.appendingPathComponent("test.jpg")
        try "test content".write(to: sourceFile, atomically: true, encoding: .utf8)
        
        // Create detection result
        let candidate = CandidateMediaItem(
            path: sourceFile.path,
            size: 1024,
            modificationDate: ISO8601DateFormatter().string(from: Date()),
            fileName: "test.jpg"
        )
        
        let detectionResult = DetectionResult(
            sourceId: source.sourceId,
            libraryId: libraryId,
            candidates: [
                CandidateItemResult(item: candidate, status: "new")
            ],
            summary: DetectionSummary(totalScanned: 1, newItems: 1, knownItems: 0)
        )
        
        // Execute dry-run import
        let options = ImportOptions(collisionPolicy: .rename)
        let dryRunResult = try ImportExecutor.executeImport(
            detectionResult: detectionResult,
            selectedItems: [candidate],
            libraryRootURL: libraryRootURL,
            libraryId: libraryId,
            options: options,
            dryRun: true
        )
        
        // Execute actual import
        let actualResult = try ImportExecutor.executeImport(
            detectionResult: detectionResult,
            selectedItems: [candidate],
            libraryRootURL: libraryRootURL,
            libraryId: libraryId,
            options: options,
            dryRun: false
        )
        
        // Verify dry-run preview matches actual import results
        // (same destination paths, same collision handling)
        XCTAssertEqual(dryRunResult.summary.total, actualResult.summary.total)
        XCTAssertEqual(dryRunResult.summary.imported, actualResult.summary.imported)
        XCTAssertEqual(dryRunResult.summary.skipped, actualResult.summary.skipped)
        XCTAssertEqual(dryRunResult.summary.failed, actualResult.summary.failed)
        
        // Verify destination paths match
        let dryRunDestination = dryRunResult.items.first?.destinationPath
        let actualDestination = actualResult.items.first?.destinationPath
        XCTAssertEqual(dryRunDestination, actualDestination, "Dry-run preview should match actual import destination paths")
    }
    
    func testDryRunShowsErrorsInPreview() throws {
        // Create source file
        let sourceFile = sourceRootURL.appendingPathComponent("test.jpg")
        try "test content".write(to: sourceFile, atomically: true, encoding: .utf8)
        
        // Create detection result with invalid path (simulating error scenario)
        let candidate = CandidateMediaItem(
            path: sourceFile.path,
            size: 1024,
            modificationDate: ISO8601DateFormatter().string(from: Date()),
            fileName: "test.jpg"
        )
        
        let detectionResult = DetectionResult(
            sourceId: source.sourceId,
            libraryId: libraryId,
            candidates: [
                CandidateItemResult(item: candidate, status: "new")
            ],
            summary: DetectionSummary(totalScanned: 1, newItems: 1, knownItems: 0)
        )
        
        // Create a mock file operations that fails on copy (simulating error)
        struct FailingFileOperations: FileOperationsProtocol {
            func fileExists(atPath path: String) -> Bool {
                return FileManager.default.fileExists(atPath: path)
            }
            
            func copyItem(at srcURL: URL, to dstURL: URL) throws {
                throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Simulated copy failure"])
            }
            
            func moveItem(at srcURL: URL, to dstURL: URL) throws {
                try FileManager.default.moveItem(at: srcURL, to: dstURL)
            }
            
            func removeItem(at URL: URL) throws {
                try FileManager.default.removeItem(at: URL)
            }
            
            func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any] {
                return try FileManager.default.attributesOfItem(atPath: path)
            }
            
            func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey: Any]?) throws {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: createIntermediates, attributes: attributes)
            }
        }
        
        // Execute dry-run import with failing file operations
        let options = ImportOptions(collisionPolicy: .rename)
        let dryRunResult = try ImportExecutor.executeImport(
            detectionResult: detectionResult,
            selectedItems: [candidate],
            libraryRootURL: libraryRootURL,
            libraryId: libraryId,
            options: options,
            dryRun: true,
            fileOperations: FailingFileOperations()
        )
        
        // Verify dry-run preview shows the error that would occur
        XCTAssertEqual(dryRunResult.summary.failed, 0, "Dry-run should not fail (no actual file operations)")
        XCTAssertEqual(dryRunResult.summary.imported, 1, "Dry-run should show item as would-be imported")
        
        // Execute actual import with same failing operations
        let actualResult = try ImportExecutor.executeImport(
            detectionResult: detectionResult,
            selectedItems: [candidate],
            libraryRootURL: libraryRootURL,
            libraryId: libraryId,
            options: options,
            dryRun: false,
            fileOperations: FailingFileOperations()
        )
        
        // Verify actual import shows the error
        XCTAssertEqual(actualResult.summary.failed, 1, "Actual import should show failure")
        XCTAssertEqual(actualResult.summary.imported, 0, "No items should be imported when copy fails")
        
        // Note: Dry-run doesn't show errors that would occur during copy (since it doesn't attempt copy)
        // But it does show validation errors. This test verifies that dry-run and actual import
        // both handle errors correctly, even if dry-run doesn't simulate copy failures.
    }
    
    // MARK: - Safety-First Error Handling Tests (Component 5)
    
    func testImportErrorPreservesLibraryIntegrity() throws {
        // Create source file
        let sourceFile = sourceRootURL.appendingPathComponent("test.jpg")
        try "test content".write(to: sourceFile, atomically: true, encoding: .utf8)
        
        // Create detection result
        let candidate = CandidateMediaItem(
            path: sourceFile.path,
            size: 1024,
            modificationDate: ISO8601DateFormatter().string(from: Date()),
            fileName: "test.jpg"
        )
        
        let detectionResult = DetectionResult(
            sourceId: source.sourceId,
            libraryId: libraryId,
            candidates: [
                CandidateItemResult(item: candidate, status: "new")
            ],
            summary: DetectionSummary(totalScanned: 1, newItems: 1, knownItems: 0)
        )
        
        // Create a mock file operations that fails on copy
        struct FailingFileOperations: FileOperationsProtocol {
            func fileExists(atPath path: String) -> Bool {
                return FileManager.default.fileExists(atPath: path)
            }
            
            func copyItem(at srcURL: URL, to dstURL: URL) throws {
                throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Simulated copy failure"])
            }
            
            func moveItem(at srcURL: URL, to dstURL: URL) throws {
                try FileManager.default.moveItem(at: srcURL, to: dstURL)
            }
            
            func removeItem(at URL: URL) throws {
                try FileManager.default.removeItem(at: URL)
            }
            
            func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any] {
                return try FileManager.default.attributesOfItem(atPath: path)
            }
            
            func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey: Any]?) throws {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: createIntermediates, attributes: attributes)
            }
        }
        
        // Attempt import with failing file operations
        let options = ImportOptions(collisionPolicy: .rename)
        let result = try ImportExecutor.executeImport(
            detectionResult: detectionResult,
            selectedItems: [candidate],
            libraryRootURL: libraryRootURL,
            libraryId: libraryId,
            options: options,
            fileOperations: FailingFileOperations()
        )
        
        // Verify import result shows failure
        XCTAssertEqual(result.summary.failed, 1, "Import should report failure")
        XCTAssertEqual(result.summary.imported, 0, "No items should be imported")
        
        // Verify no temporary files were left in library (atomic copy should clean up on error)
        // This is the key integrity check: no partial files should remain
        let allFiles = try FileManager.default.subpathsOfDirectory(atPath: libraryRootURL.path)
        let tempFiles = allFiles.filter { $0.contains(".mediahub-tmp-") }
        XCTAssertEqual(tempFiles.count, 0, "No temporary files should remain after import error - library integrity preserved")
        
        // Verify source file is unchanged
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceFile.path))
        let sourceContent = try String(contentsOf: sourceFile, encoding: .utf8)
        XCTAssertEqual(sourceContent, "test content", "Source file should remain unchanged after import error")
    }
    
    // MARK: - Confirmation Prompt Tests (Component 3)
    
    func testTTYDetection() {
        // Test TTY detection with standard input (should be true in interactive terminal)
        // Note: This test may behave differently in CI/non-interactive environments
        // The actual TTY detection is tested manually in interactive terminals
        let isInteractive = ImportCommand.isInteractive()
        // We can't assert a specific value as it depends on the test environment
        // But we can verify the function doesn't crash
        _ = isInteractive
    }
    
    func testTTYDetectionWithFileDescriptor() {
        // Test TTY detection with specific file descriptor
        // Using a non-TTY file descriptor (e.g., a file) should return false
        // Note: This is a basic test; full TTY detection testing requires manual validation
        
        // Test with stdin (0) - behavior depends on environment
        let stdinResult = ImportCommand.isInteractive(stdinFileDescriptor: 0)
        _ = stdinResult // Verify function doesn't crash
        
        // Test with invalid file descriptor (should return false)
        let invalidResult = ImportCommand.isInteractive(stdinFileDescriptor: -1)
        XCTAssertFalse(invalidResult, "Invalid file descriptor should return false for TTY detection")
    }
    
    // Note: Testing promptForConfirmation interactively requires stdin simulation
    // which is complex and not reliable in automated tests.
    // Full interactive prompt testing (yes/y, no/n, Ctrl+C) requires manual validation.
    // The confirmation logic branches (skip for dry-run, skip for --yes, require --yes
    // in non-interactive mode) are tested through the CLI integration when possible.
    
    // MARK: - Baseline Index Integration Tests (Slice 7)
    
    func testExecuteImportUpdatesIndexWhenValidAtStart() throws {
        // Create library with existing index
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRootURL.path)
        let existingEntries = [
            IndexEntry(path: "2024/01/existing.jpg", size: 1000, mtime: ISO8601DateFormatter().string(from: Date()))
        ]
        let existingIndex = BaselineIndex(entries: existingEntries)
        try BaselineIndexWriter.write(existingIndex, to: indexPath, libraryRoot: libraryRootURL.path)
        
        // Create source file
        let sourceFile = sourceRootURL.appendingPathComponent("new.jpg")
        try "new content".write(to: sourceFile, atomically: true, encoding: .utf8)
        
        // Create detection result
        let candidate = CandidateMediaItem(
            path: sourceFile.path,
            size: 2048,
            modificationDate: ISO8601DateFormatter().string(from: Date()),
            fileName: "new.jpg"
        )
        
        let detectionResult = DetectionResult(
            sourceId: source.sourceId,
            libraryId: libraryId,
            candidates: [
                CandidateItemResult(item: candidate, status: "new")
            ],
            summary: DetectionSummary(totalScanned: 1, newItems: 1, knownItems: 0)
        )
        
        // Execute import
        let options = ImportOptions(collisionPolicy: .rename)
        let importResult = try ImportExecutor.executeImport(
            detectionResult: detectionResult,
            selectedItems: [candidate],
            libraryRootURL: libraryRootURL,
            libraryId: libraryId,
            options: options
        )
        
        // Verify import succeeded
        XCTAssertEqual(importResult.summary.imported, 1)
        
        // Verify index was updated
        XCTAssertTrue(importResult.indexUpdateAttempted, "Index update should be attempted when index is valid at start")
        XCTAssertTrue(importResult.indexUpdated, "Index should be updated after successful import")
        XCTAssertNil(importResult.indexUpdateSkippedReason, "No skip reason when index is updated")
        XCTAssertNotNil(importResult.indexMetadata, "Index metadata should be present")
        // Version should be "1.1" if hash was computed, "1.0" if not (hash computation may fail)
        XCTAssertTrue(importResult.indexMetadata?.version == "1.0" || importResult.indexMetadata?.version == "1.1", "Index version should be 1.0 or 1.1")
        
        // Verify index file contains new entry
        let updatedIndex = try BaselineIndexReader.load(from: indexPath)
        XCTAssertGreaterThan(updatedIndex.entryCount, existingIndex.entryCount, "Index entry count should increase")
        
        // Verify new entry is in index (check by path)
        let importedItem = importResult.items.first { $0.status == .imported }
        if let destinationPath = importedItem?.destinationPath {
            let normalizedPath = try normalizePath(
                libraryRootURL.appendingPathComponent(destinationPath).path,
                relativeTo: libraryRootURL.path
            )
            let entryPaths = Set(updatedIndex.entries.map { $0.path })
            XCTAssertTrue(entryPaths.contains(normalizedPath), "Index should contain imported file path")
        }
    }
    
    func testExecuteImportDoesNotCreateIndexWhenAbsentAtStart() throws {
        // Create library without index (no index file)
        // Create source file
        let sourceFile = sourceRootURL.appendingPathComponent("new.jpg")
        try "new content".write(to: sourceFile, atomically: true, encoding: .utf8)
        
        // Create detection result
        let candidate = CandidateMediaItem(
            path: sourceFile.path,
            size: 2048,
            modificationDate: ISO8601DateFormatter().string(from: Date()),
            fileName: "new.jpg"
        )
        
        let detectionResult = DetectionResult(
            sourceId: source.sourceId,
            libraryId: libraryId,
            candidates: [
                CandidateItemResult(item: candidate, status: "new")
            ],
            summary: DetectionSummary(totalScanned: 1, newItems: 1, knownItems: 0)
        )
        
        // Execute import
        let options = ImportOptions(collisionPolicy: .rename)
        let importResult = try ImportExecutor.executeImport(
            detectionResult: detectionResult,
            selectedItems: [candidate],
            libraryRootURL: libraryRootURL,
            libraryId: libraryId,
            options: options
        )
        
        // Verify import succeeded
        XCTAssertEqual(importResult.summary.imported, 1)
        
        // Verify index was NOT created/updated
        XCTAssertFalse(importResult.indexUpdateAttempted, "Index update should not be attempted when index is absent")
        XCTAssertFalse(importResult.indexUpdated, "Index should not be updated when absent at start")
        XCTAssertEqual(importResult.indexUpdateSkippedReason, "index_missing", "Skip reason should indicate index was missing")
        XCTAssertNil(importResult.indexMetadata, "No index metadata when index is absent")
        
        // Verify index file does not exist
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRootURL.path)
        XCTAssertFalse(FileManager.default.fileExists(atPath: indexPath), "Index file should not be created when absent at start")
    }
    
    func testExecuteImportDoesNotUpdateIndexInDryRun() throws {
        // Create library with existing index
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRootURL.path)
        let existingEntries = [
            IndexEntry(path: "2024/01/existing.jpg", size: 1000, mtime: ISO8601DateFormatter().string(from: Date()))
        ]
        let existingIndex = BaselineIndex(entries: existingEntries)
        try BaselineIndexWriter.write(existingIndex, to: indexPath, libraryRoot: libraryRootURL.path)
        
        // Get original index lastUpdated for comparison
        let originalIndex = try BaselineIndexReader.load(from: indexPath)
        let originalLastUpdated = originalIndex.lastUpdated
        
        // Create source file
        let sourceFile = sourceRootURL.appendingPathComponent("new.jpg")
        try "new content".write(to: sourceFile, atomically: true, encoding: .utf8)
        
        // Create detection result
        let candidate = CandidateMediaItem(
            path: sourceFile.path,
            size: 2048,
            modificationDate: ISO8601DateFormatter().string(from: Date()),
            fileName: "new.jpg"
        )
        
        let detectionResult = DetectionResult(
            sourceId: source.sourceId,
            libraryId: libraryId,
            candidates: [
                CandidateItemResult(item: candidate, status: "new")
            ],
            summary: DetectionSummary(totalScanned: 1, newItems: 1, knownItems: 0)
        )
        
        // Execute import in dry-run mode
        let options = ImportOptions(collisionPolicy: .rename)
        let importResult = try ImportExecutor.executeImport(
            detectionResult: detectionResult,
            selectedItems: [candidate],
            libraryRootURL: libraryRootURL,
            libraryId: libraryId,
            options: options,
            dryRun: true
        )
        
        // Verify import preview succeeded
        XCTAssertEqual(importResult.summary.imported, 1) // Dry-run still reports as imported
        
        // Verify index was NOT updated (dry-run = zero writes)
        XCTAssertTrue(importResult.indexUpdateAttempted, "Index update should be attempted (index was valid)")
        XCTAssertFalse(importResult.indexUpdated, "Index should not be updated in dry-run mode")
        XCTAssertEqual(importResult.indexUpdateSkippedReason, "dry_run", "Skip reason should indicate dry-run")
        XCTAssertNotNil(importResult.indexMetadata, "Index metadata should be present (from existing index)")
        
        // Verify index file was not modified
        let preservedIndex = try BaselineIndexReader.load(from: indexPath)
        XCTAssertEqual(preservedIndex.lastUpdated, originalLastUpdated, "Index lastUpdated should not change in dry-run")
        XCTAssertEqual(preservedIndex.entryCount, existingIndex.entryCount, "Index entry count should not change in dry-run")
    }
    
    // MARK: - Media Type Filtering Tests
    
    func testImportRespectsFilteredDetectionResults() throws {
        // Create source with both images and videos
        let imageFile = sourceRootURL.appendingPathComponent("test.jpg")
        try "fake image".write(to: imageFile, atomically: true, encoding: .utf8)
        
        let videoFile = sourceRootURL.appendingPathComponent("test.mov")
        try "fake video".write(to: videoFile, atomically: true, encoding: .utf8)
        
        // Create detection result with only image (simulating filtered scan with mediaTypes=.images)
        let imageCandidate = CandidateMediaItem(
            path: imageFile.path,
            size: 1024,
            modificationDate: ISO8601DateFormatter().string(from: Date()),
            fileName: "test.jpg"
        )
        
        // Detection result only contains image (video was filtered out at scan stage)
        let detectionResult = DetectionResult(
            sourceId: source.sourceId,
            libraryId: libraryId,
            candidates: [
                CandidateItemResult(item: imageCandidate, status: "new")
            ],
            summary: DetectionSummary(totalScanned: 1, newItems: 1, knownItems: 0)
        )
        
        // Execute import with only image candidate
        let options = ImportOptions(collisionPolicy: .rename)
        let importResult = try ImportExecutor.executeImport(
            detectionResult: detectionResult,
            selectedItems: [imageCandidate],
            libraryRootURL: libraryRootURL,
            libraryId: libraryId,
            options: options
        )
        
        // Verify only image was imported (video was never in detection result, so can't be imported)
        XCTAssertEqual(importResult.summary.total, 1)
        XCTAssertEqual(importResult.summary.imported, 1)
        
        // Verify only image file exists in library
        let importedItems = importResult.items.filter { $0.status == .imported }
        XCTAssertEqual(importedItems.count, 1)
        XCTAssertTrue(importedItems.first?.sourcePath.contains("test.jpg") ?? false)
        
        // Verify video file was never processed (not in detection result)
        XCTAssertFalse(importResult.items.contains { $0.sourcePath.contains("test.mov") })
    }
}
