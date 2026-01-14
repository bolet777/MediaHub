//
//  LibraryAdoption.swift
//  MediaHub
//
//  Library adoption operations for existing media directories
//

import Foundation

/// Errors that can occur during library adoption
public enum LibraryAdoptionError: Error, LocalizedError {
    case invalidPath
    case pathDoesNotExist
    case pathIsNotDirectory
    case permissionDenied
    case alreadyAdopted
    case metadataCreationFailed(Error)
    case metadataWriteFailed(Error)
    case rollbackFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidPath:
            return "Invalid library path"
        case .pathDoesNotExist:
            return "Path does not exist"
        case .pathIsNotDirectory:
            return "Path is not a directory"
        case .permissionDenied:
            return "Permission denied accessing path"
        case .alreadyAdopted:
            return "Library is already adopted"
        case .metadataCreationFailed(let error):
            return "Failed to create metadata: \(error.localizedDescription)"
        case .metadataWriteFailed(let error):
            return "Failed to write metadata: \(error.localizedDescription)"
        case .rollbackFailed(let error):
            return "Failed to rollback adoption: \(error.localizedDescription)"
        }
    }
}

/// Summary of baseline scan results
public struct BaselineScanSummary: Codable, Equatable {
    /// Number of media files found in the library
    public let fileCount: Int
    
    /// Set of normalized paths of media files (sorted for determinism)
    public let filePaths: [String]
    
    /// Creates a baseline scan summary
    ///
    /// - Parameters:
    ///   - fileCount: Number of media files found
    ///   - filePaths: Set of normalized paths (will be sorted for determinism)
    public init(fileCount: Int, filePaths: Set<String>) {
        self.fileCount = fileCount
        // Sort paths for determinism
        self.filePaths = Array(filePaths).sorted()
    }
}

/// Result of library adoption operation
public struct LibraryAdoptionResult {
    /// Created library metadata
    public let metadata: LibraryMetadata
    
    /// Baseline scan summary
    public let baselineScan: BaselineScanSummary
    
    /// Whether baseline index was created during adoption
    public let indexCreated: Bool
    
    /// Reason why index was skipped (if not created)
    public let indexSkippedReason: String?
    
    /// Index metadata (if index was created or already existed)
    public let indexMetadata: IndexMetadata?
    
    /// Index metadata structure
    public struct IndexMetadata: Codable, Equatable {
        /// Index version
        public let version: String
        
        /// Number of entries in index
        public let entryCount: Int
    }
    
    public init(
        metadata: LibraryMetadata,
        baselineScan: BaselineScanSummary,
        indexCreated: Bool = false,
        indexSkippedReason: String? = nil,
        indexMetadata: IndexMetadata? = nil
    ) {
        self.metadata = metadata
        self.baselineScan = baselineScan
        self.indexCreated = indexCreated
        self.indexSkippedReason = indexSkippedReason
        self.indexMetadata = indexMetadata
    }
}

/// Tracks adoption state for rollback
private struct AdoptionState {
    let libraryRootURL: URL
    var structureCreated: Bool = false
    var metadataWritten: Bool = false
    
    init(libraryRootURL: URL) {
        self.libraryRootURL = libraryRootURL
    }
}

/// Handles library adoption operations for existing media directories
public struct LibraryAdopter {
    /// Checks if a library is already adopted at the specified path.
    ///
    /// - Parameter path: The path to check
    /// - Returns: `true` if library is already adopted, `false` otherwise
    public static func isAlreadyAdopted(at path: String) -> Bool {
        let libraryRootURL = URL(fileURLWithPath: path)
        return LibraryStructureValidator.isLibraryStructure(at: libraryRootURL)
    }
    
    /// Validates that a target path is suitable for adoption.
    ///
    /// Checks:
    /// - Path exists and is a directory
    /// - Path has write permissions
    ///
    /// - Parameter path: The path to validate
    /// - Throws: `LibraryAdoptionError` if validation fails
    public static func validatePath(_ path: String) throws {
        let fileManager = FileManager.default
        
        // Check if path is valid
        guard !path.isEmpty else {
            throw LibraryAdoptionError.invalidPath
        }
        
        // Check if path exists
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            throw LibraryAdoptionError.pathDoesNotExist
        }
        
        // Check if it's a directory
        guard isDirectory.boolValue else {
            throw LibraryAdoptionError.pathIsNotDirectory
        }
        
        // Check if directory is writable
        guard fileManager.isWritableFile(atPath: path) else {
            throw LibraryAdoptionError.permissionDenied
        }
    }
    
    /// Adopts an existing directory as a MediaHub library.
    ///
    /// This operation:
    /// - Creates `.mediahub/` directory (unless dryRun is true)
    /// - Creates `library.json` metadata file (unless dryRun is true)
    /// - Performs baseline scan of existing media files
    /// - Does NOT modify, move, rename, or delete any existing media files
    ///
    /// - Parameters:
    ///   - path: The path to adopt
    ///   - dryRun: If true, performs preview without creating files (read-only operations only)
    /// - Returns: Adoption result with metadata and baseline scan summary
    /// - Throws: `LibraryAdoptionError` if adoption fails
    public static func adoptLibrary(at path: String, dryRun: Bool = false) throws -> LibraryAdoptionResult {
        // Check if already adopted (idempotent check)
        if isAlreadyAdopted(at: path) {
            throw LibraryAdoptionError.alreadyAdopted
        }
        
        // Validate path
        try validatePath(path)
        
        let libraryRootURL = URL(fileURLWithPath: path)
        
        // Step 1: Generate unique identifier (same logic for dry-run and actual)
        let libraryId = LibraryIdentifierGenerator.generate()
        
        // Step 2: Create metadata (same structure for dry-run and actual)
        let metadata = LibraryMetadata(
            libraryId: libraryId,
            rootPath: libraryRootURL.path,
            libraryVersion: "1.0"
        )
        
        // Step 3: Perform baseline scan (read-only, same for dry-run and actual)
        // Note: This establishes minimal "known" state; no hashing, no persistent index (Slice 7)
        let baselinePaths: Set<String>
        do {
            baselinePaths = try LibraryContentQuery.scanLibraryContents(at: libraryRootURL)
        } catch {
            // If baseline scan fails, return empty baseline scan
            let baselineScan = BaselineScanSummary(fileCount: 0, filePaths: [])
            return LibraryAdoptionResult(metadata: metadata, baselineScan: baselineScan)
        }
        
        // Create baseline scan summary (deterministic: sorted paths)
        let baselineScan = BaselineScanSummary(fileCount: baselinePaths.count, filePaths: baselinePaths)
        
        // Step 4: Create baseline index from baseline scan (in memory, for preview or creation)
        let baselineIndex = try createBaselineIndex(
            from: baselinePaths,
            libraryRoot: libraryRootURL.path
        )
        
        // Step 5: Check if index already exists and is valid
        let indexState = BaselineIndexLoader.tryLoadBaselineIndex(libraryRoot: libraryRootURL.path)
        let indexCreated: Bool
        let indexSkippedReason: String?
        let indexMetadata: LibraryAdoptionResult.IndexMetadata?
        
        switch indexState {
        case .valid(let existingIndex):
            // Index already exists and is valid - preserve it (idempotent)
            indexCreated = false
            indexSkippedReason = "already_valid"
            indexMetadata = LibraryAdoptionResult.IndexMetadata(
                version: existingIndex.version,
                entryCount: existingIndex.entryCount
            )
        case .absent, .invalid:
            // Index is absent or invalid - will create it (unless dry-run)
            if dryRun {
                indexCreated = false
                indexSkippedReason = "dry_run"
                indexMetadata = LibraryAdoptionResult.IndexMetadata(
                    version: baselineIndex.version,
                    entryCount: baselineIndex.entryCount
                )
            } else {
                // Will create index after structure is created
                indexCreated = true
                indexSkippedReason = nil
                indexMetadata = LibraryAdoptionResult.IndexMetadata(
                    version: baselineIndex.version,
                    entryCount: baselineIndex.entryCount
                )
            }
        }
        
        // Step 6: In dry-run mode, return preview without creating files
        if dryRun {
            // Dry-run: return preview results without any file system writes
            return LibraryAdoptionResult(
                metadata: metadata,
                baselineScan: baselineScan,
                indexCreated: false,
                indexSkippedReason: "dry_run",
                indexMetadata: indexMetadata
            )
        }
        
        // Step 7: Actual adoption: create structure and write metadata
        var state = AdoptionState(libraryRootURL: libraryRootURL)
        
        do {
            // Create library structure (.mediahub/ directory)
            try LibraryStructureCreator.createStructure(at: libraryRootURL)
            state.structureCreated = true
            
            // Write metadata atomically
            let metadataFileURL = LibraryStructureCreator.metadataFileURL(for: libraryRootURL)
            try writeMetadataAtomically(metadata, to: metadataFileURL)
            state.metadataWritten = true
            
            // Step 8: Create baseline index if needed (idempotent: only if absent/invalid)
            if indexCreated {
                do {
                    let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRootURL.path)
                    try BaselineIndexWriter.write(
                        baselineIndex,
                        to: indexPath,
                        libraryRoot: libraryRootURL.path
                    )
                } catch {
                    // Index creation failure is non-fatal - adoption still succeeds
                    // Error is silently handled (index is optional optimization)
                }
            }
            
            // Success!
            return LibraryAdoptionResult(
                metadata: metadata,
                baselineScan: baselineScan,
                indexCreated: indexCreated,
                indexSkippedReason: indexSkippedReason,
                indexMetadata: indexMetadata
            )
            
        } catch let error as LibraryAdoptionError {
            // Rollback on error
            try? rollback(state)
            throw error
        } catch {
            // Rollback on error
            try? rollback(state)
            throw LibraryAdoptionError.metadataWriteFailed(error)
        }
    }
    
    /// Creates a baseline index from baseline scan paths
    ///
    /// - Parameters:
    ///   - baselinePaths: Set of absolute paths from baseline scan
    ///   - libraryRoot: Absolute path to library root
    /// - Returns: Baseline index with entries for all paths
    /// - Throws: Error if index creation fails
    private static func createBaselineIndex(
        from baselinePaths: Set<String>,
        libraryRoot: String
    ) throws -> BaselineIndex {
        let fileManager = FileManager.default
        var entries: [IndexEntry] = []
        
        // Collect file metadata for each path
        for absolutePath in baselinePaths {
            // Normalize path relative to library root
            let normalizedPath: String
            do {
                normalizedPath = try normalizePath(absolutePath, relativeTo: libraryRoot)
            } catch {
                // Skip paths that can't be normalized (shouldn't happen, but handle gracefully)
                continue
            }
            
            // Get file attributes (size, mtime)
            do {
                let attributes = try fileManager.attributesOfItem(atPath: absolutePath)
                guard let size = attributes[.size] as? Int64,
                      let modificationDate = attributes[.modificationDate] as? Date else {
                    // Skip files without required attributes
                    continue
                }
                
                // Convert modification date to ISO8601 string
                let mtime = ISO8601DateFormatter().string(from: modificationDate)
                
                // Create index entry
                let entry = IndexEntry(path: normalizedPath, size: size, mtime: mtime)
                entries.append(entry)
            } catch {
                // Skip files that can't be read (permissions, etc.)
                continue
            }
        }
        
        // Create baseline index (entries will be sorted by path in BaselineIndex.init)
        return BaselineIndex(entries: entries)
    }
    
    /// Writes metadata to file using atomic write (temp file + atomic move).
    ///
    /// - Parameters:
    ///   - metadata: The metadata to write
    ///   - fileURL: The target file URL
    /// - Throws: `LibraryAdoptionError` if write fails
    private static func writeMetadataAtomically(_ metadata: LibraryMetadata, to fileURL: URL) throws {
        // Serialize metadata
        let data: Data
        do {
            data = try LibraryMetadataSerializer.serialize(metadata)
        } catch {
            throw LibraryAdoptionError.metadataCreationFailed(error)
        }
        
        // Create directory if it doesn't exist
        let directoryURL = fileURL.deletingLastPathComponent()
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            if (error as NSError).code == NSFileWriteNoPermissionError {
                throw LibraryAdoptionError.permissionDenied
            }
            throw LibraryAdoptionError.metadataCreationFailed(error)
        }
        
        // Write to temp file first
        let tempFileURL = fileURL.appendingPathExtension("tmp")
        do {
            try data.write(to: tempFileURL, options: [])
        } catch {
            // Clean up temp file if it exists
            try? fileManager.removeItem(at: tempFileURL)
            if (error as NSError).code == NSFileWriteNoPermissionError {
                throw LibraryAdoptionError.permissionDenied
            }
            throw LibraryAdoptionError.metadataWriteFailed(error)
        }
        
        // Atomically move temp file to final location
        do {
            try fileManager.moveItem(at: tempFileURL, to: fileURL)
        } catch {
            // Clean up temp file if it exists
            try? fileManager.removeItem(at: tempFileURL)
            if (error as NSError).code == NSFileWriteNoPermissionError {
                throw LibraryAdoptionError.permissionDenied
            }
            throw LibraryAdoptionError.metadataWriteFailed(error)
        }
    }
    
    /// Rolls back a failed adoption, removing created files/directories.
    ///
    /// - Parameter state: The adoption state to rollback
    /// - Throws: `LibraryAdoptionError` if rollback fails
    private static func rollback(_ state: AdoptionState) throws {
        let fileManager = FileManager.default
        
        // Only rollback if structure was created
        if state.structureCreated {
            // Remove metadata directory (and its contents)
            let metadataDirURL = state.libraryRootURL
                .appendingPathComponent(LibraryStructure.metadataDirectoryName)
            
            if fileManager.fileExists(atPath: metadataDirURL.path) {
                do {
                    try fileManager.removeItem(at: metadataDirURL)
                } catch {
                    throw LibraryAdoptionError.rollbackFailed(error)
                }
            }
        }
    }
}
