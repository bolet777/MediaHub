//
//  ImportExecution.swift
//  MediaHub
//
//  Import job orchestration and execution
//

import Foundation

/// Errors that can occur during import execution
public enum ImportExecutionError: Error, LocalizedError {
    case invalidDetectionResult
    case invalidLibrary
    case invalidSource
    case noItemsSelected
    case importFailed(String, Error)
    case knownItemsUpdateFailed(Error)
    case resultStorageFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidDetectionResult:
            return "Invalid detection result"
        case .invalidLibrary:
            return "Invalid library"
        case .invalidSource:
            return "Invalid source"
        case .noItemsSelected:
            return "No items selected for import"
        case .importFailed(let path, let error):
            return "Import failed at \(path): \(error.localizedDescription)"
        case .knownItemsUpdateFailed(let error):
            return "Failed to update known items: \(error.localizedDescription)"
        case .resultStorageFailed(let error):
            return "Failed to store import result: \(error.localizedDescription)"
        }
    }
}

/// Executes import jobs for selected candidate items
public struct ImportExecutor {
    /// Executes an import job for selected candidate items from a detection result
    ///
    /// - Parameters:
    ///   - detectionResult: The detection result containing candidate items
    ///   - selectedItems: Array of candidate items to import (must be from detection result)
    ///   - libraryRootURL: Library root URL
    ///   - libraryId: Library identifier
    ///   - options: Import options (collision policy, etc.)
    ///   - dryRun: If true, preview import operations without copying files (default: false)
    ///   - fileOperations: File operations implementation (default: FileManager)
    /// - Returns: ImportResult with results for all items
    /// - Throws: `ImportExecutionError` if import fails
    public static func executeImport(
        detectionResult: DetectionResult,
        selectedItems: [CandidateMediaItem],
        libraryRootURL: URL,
        libraryId: String,
        options: ImportOptions,
        dryRun: Bool = false,
        fileOperations: FileOperationsProtocol = DefaultFileOperations()
    ) throws -> ImportResult {
        // Validate inputs
        guard detectionResult.isValid() else {
            throw ImportExecutionError.invalidDetectionResult
        }
        
        guard UUID(uuidString: libraryId) != nil else {
            throw ImportExecutionError.invalidLibrary
        }
        
        guard UUID(uuidString: detectionResult.sourceId) != nil else {
            throw ImportExecutionError.invalidSource
        }
        
        guard !selectedItems.isEmpty else {
            throw ImportExecutionError.noItemsSelected
        }
        
        // Validate selected items are from detection result
        let detectionItemPaths = Set(detectionResult.candidates.map { $0.item.path })
        let selectedPaths = Set(selectedItems.map { $0.path })
        guard selectedPaths.isSubset(of: detectionItemPaths) else {
            throw ImportExecutionError.invalidDetectionResult
        }
        
        // Step 1: Check baseline index state at start (for incremental updates)
        let indexStateAtStart = BaselineIndexLoader.tryLoadBaselineIndex(libraryRoot: libraryRootURL.path)
        let shouldUpdateIndex = indexStateAtStart.isValid // Only update if index was valid at start
        
        // Load existing index if we'll need to update it
        var existingIndex: BaselineIndex?
        if shouldUpdateIndex {
            do {
                let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRootURL.path)
                existingIndex = try BaselineIndexReader.load(from: indexPath)
            } catch {
                // If loading fails, treat as if index is invalid (won't update)
                // Import will still succeed
            }
        }
        
        // Process items sequentially (deterministic order)
        let sortedItems = selectedItems.sorted { $0.path < $1.path }
        var importItemResults: [ImportItemResult] = []
        var successfullyImported: [(path: String, destinationPath: String)] = []
        var newIndexEntries: [IndexEntry] = [] // Collect entries for successfully imported files
        
        let importTimestamp = ISO8601DateFormatter().string(from: Date())
        
        for item in sortedItems {
            let itemResult = processImportItem(
                item: item,
                libraryRootURL: libraryRootURL,
                options: options,
                dryRun: dryRun,
                fileOperations: fileOperations
            )
            
            importItemResults.append(itemResult)
            
            // Track successfully imported items for known-items update (skip in dry-run)
            if !dryRun,
               itemResult.status == .imported,
               let destinationPath = itemResult.destinationPath {
                successfullyImported.append(
                    (path: item.path, destinationPath: destinationPath)
                )
                
                // Collect index entry for successfully imported file (if we'll update index)
                if shouldUpdateIndex {
                    do {
                        // Build absolute destination path
                        let absoluteDestinationPath = libraryRootURL.appendingPathComponent(destinationPath).path
                        let destinationURL = URL(fileURLWithPath: absoluteDestinationPath)
                        
                        // Get file attributes (size, mtime)
                        let attributes = try fileOperations.attributesOfItem(atPath: absoluteDestinationPath)
                        guard let size = attributes[.size] as? Int64,
                              let modificationDate = attributes[.modificationDate] as? Date else {
                            // Skip if attributes can't be read
                            continue
                        }
                        
                        // Normalize path relative to library root
                        let normalizedPath = try normalizePath(absoluteDestinationPath, relativeTo: libraryRootURL.path)
                        
                        // Convert modification date to ISO8601 string
                        let mtime = ISO8601DateFormatter().string(from: modificationDate)
                        
                        // Compute content hash for imported destination file
                        // Hash computation is non-fatal: if it fails, continue without hash
                        var contentHash: String? = nil
                        do {
                            contentHash = try ContentHasher.computeHash(for: destinationURL, allowedRoot: libraryRootURL)
                        } catch {
                            // Hash computation failed - continue without hash (non-fatal)
                            // Warning will be included in import result if needed
                            // For now, we silently continue (hash is optional)
                        }
                        
                        // Create index entry with hash (if computed successfully)
                        let entry = IndexEntry(path: normalizedPath, size: size, mtime: mtime, hash: contentHash)
                        newIndexEntries.append(entry)
                    } catch {
                        // Skip if we can't create entry (non-fatal)
                        continue
                    }
                }
            }
        }
        
        // Generate summary
        let importedCount = importItemResults.filter { $0.status == .imported }.count
        let skippedCount = importItemResults.filter { $0.status == .skipped }.count
        let failedCount = importItemResults.filter { $0.status == .failed }.count
        
        let summary = ImportSummary(
            total: importItemResults.count,
            imported: importedCount,
            skipped: skippedCount,
            failed: failedCount
        )
        
        // Step 2: Update baseline index incrementally (batched, only if index was valid at start)
        let indexUpdateAttempted = shouldUpdateIndex
        var indexUpdated = false
        var indexUpdateSkippedReason: String?
        var indexMetadata: ImportResult.IndexMetadata?
        
        if shouldUpdateIndex && !dryRun && !newIndexEntries.isEmpty {
            // Update index with new entries
            if let currentIndex = existingIndex {
                // Merge new entries with existing index (idempotent: same path = update entry)
                do {
                    let updatedIndex = currentIndex.updating(with: newIndexEntries)
                    
                    // Write updated index atomically
                    let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRootURL.path)
                    try BaselineIndexWriter.write(
                        updatedIndex,
                        to: indexPath,
                        libraryRoot: libraryRootURL.path
                    )
                    
                    indexUpdated = true
                    indexMetadata = ImportResult.IndexMetadata(
                        version: updatedIndex.version,
                        entryCount: updatedIndex.entryCount,
                        lastUpdated: updatedIndex.lastUpdated
                    )
                } catch {
                    // Index update failure is non-fatal - import still succeeds
                    indexUpdateSkippedReason = "update_failed"
                    if case .valid(let index) = indexStateAtStart {
                        indexMetadata = ImportResult.IndexMetadata(
                            version: index.version,
                            entryCount: index.entryCount,
                            lastUpdated: index.lastUpdated
                        )
                    }
                }
            } else {
                // Index was valid but couldn't be loaded - skip update
                indexUpdateSkippedReason = "index_load_failed"
                if case .valid(let index) = indexStateAtStart {
                    indexMetadata = ImportResult.IndexMetadata(
                        version: index.version,
                        entryCount: index.entryCount,
                        lastUpdated: index.lastUpdated
                    )
                }
            }
        } else {
            // Determine skip reason
            if dryRun {
                indexUpdateSkippedReason = "dry_run"
                if case .valid(let index) = indexStateAtStart {
                    indexMetadata = ImportResult.IndexMetadata(
                        version: index.version,
                        entryCount: index.entryCount,
                        lastUpdated: index.lastUpdated
                    )
                }
            } else if !shouldUpdateIndex {
                // Index was absent or invalid at start
                if case .absent = indexStateAtStart {
                    indexUpdateSkippedReason = "index_missing"
                } else if case .invalid = indexStateAtStart {
                    indexUpdateSkippedReason = "index_invalid"
                }
            } else if newIndexEntries.isEmpty {
                indexUpdateSkippedReason = "no_new_entries"
                if case .valid(let index) = indexStateAtStart {
                    indexMetadata = ImportResult.IndexMetadata(
                        version: index.version,
                        entryCount: index.entryCount,
                        lastUpdated: index.lastUpdated
                    )
                }
            }
        }
        
        // Create import result with index update information
        let importResult = ImportResult(
            sourceId: detectionResult.sourceId,
            libraryId: libraryId,
            importedAt: importTimestamp,
            options: options,
            items: importItemResults,
            summary: summary,
            indexUpdateAttempted: indexUpdateAttempted,
            indexUpdated: indexUpdated,
            indexUpdateSkippedReason: indexUpdateSkippedReason,
            indexMetadata: indexMetadata
        )
        
        // Update known-items tracking (only for successfully imported items, skip in dry-run)
        if !dryRun && !successfullyImported.isEmpty {
            do {
                try KnownItemsTracker.recordImportedItems(
                    successfullyImported,
                    sourceId: detectionResult.sourceId,
                    libraryRootURL: libraryRootURL,
                    importedAt: importTimestamp
                )
            } catch {
                throw ImportExecutionError.knownItemsUpdateFailed(error)
            }
        }
        
        // Store import result (skip in dry-run to avoid file I/O)
        if !dryRun {
            let resultFileURL = ImportResultStorage.resultFileURL(
                for: libraryRootURL,
                sourceId: detectionResult.sourceId,
                timestamp: importResult.importedAt
            )
            
            do {
                try ImportResultSerializer.write(importResult, to: resultFileURL)
            } catch {
                throw ImportExecutionError.resultStorageFailed(error)
            }
        }
        
        return importResult
    }
    
    /// Processes a single import item
    ///
    /// - Parameters:
    ///   - item: The candidate item to import
    ///   - libraryRootURL: Library root URL
    ///   - options: Import options
    ///   - dryRun: If true, skip file operations but perform all other logic
    ///   - fileOperations: File operations implementation
    /// - Returns: ImportItemResult with status and details
    private static func processImportItem(
        item: CandidateMediaItem,
        libraryRootURL: URL,
        options: ImportOptions,
        dryRun: Bool,
        fileOperations: FileOperationsProtocol
    ) -> ImportItemResult {
        // Step 1: Extract timestamp
        let timestampResult: TimestampResult
        do {
            timestampResult = try TimestampExtractor.extractTimestamp(from: item.path)
        } catch {
            return ImportItemResult(
                sourcePath: item.path,
                status: .failed,
                reason: "Timestamp extraction failed: \(error.localizedDescription)"
            )
        }
        
        // Step 2: Map destination path
        let destinationMapping: DestinationMappingResult
        do {
            destinationMapping = try DestinationMapper.mapDestination(
                for: item,
                timestamp: timestampResult.date,
                libraryRootURL: libraryRootURL
            )
        } catch {
            return ImportItemResult(
                sourcePath: item.path,
                status: .failed,
                reason: "Destination mapping failed: \(error.localizedDescription)",
                timestampUsed: ISO8601DateFormatter().string(from: timestampResult.date),
                timestampSource: timestampResult.source == .exifDateTimeOriginal ? "exif" : "filesystem"
            )
        }
        
        // Step 3: Detect collision
        let collision = CollisionHandler.detectCollision(at: destinationMapping.destinationURL)
        
        // Step 4: Handle collision
        let collisionHandling = CollisionHandler.handleCollision(
            collision,
            policy: options.collisionPolicy,
            originalDestinationURL: destinationMapping.destinationURL,
            originalFileName: item.fileName
        )
        
        // Step 5: Process based on collision handling result
        switch collisionHandling {
        case .proceed(let finalDestinationURL):
            // In dry-run mode, skip file copy but return success result
            if dryRun {
                return ImportItemResult(
                    sourcePath: item.path,
                    destinationPath: destinationMapping.relativePath,
                    status: .imported,
                    timestampUsed: ISO8601DateFormatter().string(from: timestampResult.date),
                    timestampSource: timestampResult.source == .exifDateTimeOriginal ? "exif" : "filesystem"
                )
            }
            
            // Copy file atomically (only in non-dry-run mode)
            do {
                let sourceURL = URL(fileURLWithPath: item.path)
                _ = try AtomicFileCopier.copyAtomically(
                    from: sourceURL,
                    to: finalDestinationURL,
                    fileOperations: fileOperations
                )
                
                return ImportItemResult(
                    sourcePath: item.path,
                    destinationPath: destinationMapping.relativePath,
                    status: .imported,
                    timestampUsed: ISO8601DateFormatter().string(from: timestampResult.date),
                    timestampSource: timestampResult.source == .exifDateTimeOriginal ? "exif" : "filesystem"
                )
            } catch {
                return ImportItemResult(
                    sourcePath: item.path,
                    destinationPath: destinationMapping.relativePath,
                    status: .failed,
                    reason: "File copy failed: \(error.localizedDescription)",
                    timestampUsed: ISO8601DateFormatter().string(from: timestampResult.date),
                    timestampSource: timestampResult.source == .exifDateTimeOriginal ? "exif" : "filesystem"
                )
            }
            
        case .skip(let reason):
            return ImportItemResult(
                sourcePath: item.path,
                destinationPath: destinationMapping.relativePath,
                status: .skipped,
                reason: reason,
                timestampUsed: ISO8601DateFormatter().string(from: timestampResult.date),
                timestampSource: timestampResult.source == .exifDateTimeOriginal ? "exif" : "filesystem"
            )
            
        case .error(let error):
            return ImportItemResult(
                sourcePath: item.path,
                destinationPath: destinationMapping.relativePath,
                status: .failed,
                reason: "Collision error: \(error.localizedDescription)",
                timestampUsed: ISO8601DateFormatter().string(from: timestampResult.date),
                timestampSource: timestampResult.source == .exifDateTimeOriginal ? "exif" : "filesystem"
            )
        }
    }
}
