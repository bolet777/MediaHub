//
//  BaselineIndex.swift
//  MediaHub
//
//  Baseline index for fast library content queries
//

import Foundation

// MARK: - Data Structures

/// Baseline index structure containing metadata for all media files in the library
public struct BaselineIndex: Codable, Equatable {
    /// Index format version (string, "1.0" or "1.1")
    /// - "1.0": Entries without hash field
    /// - "1.1": Entries may have optional hash field
    public let version: String

    /// ISO8601 timestamp when index was first created
    public let created: String

    /// ISO8601 timestamp when index was last updated
    public let lastUpdated: String

    /// Number of entries in the index (for quick statistics)
    public let entryCount: Int

    /// Array of index entries, sorted by normalized path for determinism
    public let entries: [IndexEntry]

    /// Supported index versions
    public static let supportedVersions: Set<String> = ["1.0", "1.1"]

    /// Creates a new baseline index
    ///
    /// Version is automatically determined:
    /// - "1.1" if any entry has a non-nil hash
    /// - "1.0" if no entries have hashes
    ///
    /// - Parameter entries: Array of index entries (will be sorted by normalized path)
    public init(entries: [IndexEntry]) {
        // Determine version based on hash presence
        let hasAnyHash = entries.contains { $0.hash != nil }
        self.version = hasAnyHash ? "1.1" : "1.0"
        let now = ISO8601DateFormatter().string(from: Date())
        self.created = now
        self.lastUpdated = now
        self.entryCount = entries.count
        // Sort entries by normalized path for determinism
        self.entries = entries.sorted { $0.path < $1.path }
    }

    /// Creates a baseline index with explicit timestamps (for loading from file)
    ///
    /// - Parameters:
    ///   - version: Index format version
    ///   - created: ISO8601 timestamp when index was first created
    ///   - lastUpdated: ISO8601 timestamp when index was last updated
    ///   - entries: Array of index entries (will be sorted by normalized path)
    internal init(version: String, created: String, lastUpdated: String, entries: [IndexEntry]) {
        self.version = version
        self.created = created
        self.lastUpdated = lastUpdated
        self.entryCount = entries.count
        // Sort entries by normalized path for determinism
        self.entries = entries.sorted { $0.path < $1.path }
    }

    /// Updates the index with new entries, updating lastUpdated timestamp
    ///
    /// Version is automatically determined based on merged entries:
    /// - "1.1" if any entry has a non-nil hash
    /// - "1.0" if no entries have hashes
    ///
    /// - Parameter newEntries: New entries to add (will be merged with existing entries, removing duplicates)
    /// - Returns: Updated baseline index
    public func updating(with newEntries: [IndexEntry]) -> BaselineIndex {
        // Merge entries: use dictionary to remove duplicates by path (same path = update entry)
        var entryMap: [String: IndexEntry] = [:]

        // Add existing entries
        for entry in entries {
            entryMap[entry.path] = entry
        }

        // Add/update with new entries
        for entry in newEntries {
            entryMap[entry.path] = entry
        }

        let mergedEntries = Array(entryMap.values)

        // Determine version based on hash presence
        let hasAnyHash = mergedEntries.contains { $0.hash != nil }
        let newVersion = hasAnyHash ? "1.1" : "1.0"

        // Create updated index with new timestamp
        return BaselineIndex(
            version: newVersion,
            created: created,
            lastUpdated: ISO8601DateFormatter().string(from: Date()),
            entries: mergedEntries
        )
    }

    // MARK: - Hash Lookup Properties (v1.1)

    /// Maps content hash to a representative library path
    ///
    /// For hashes that appear multiple times (same content, different paths),
    /// the first path encountered in sorted order is kept (deterministic).
    /// Entries without hashes are skipped.
    ///
    /// - Complexity: O(n) where n is the number of entries
    public var hashToAnyPath: [String: String] {
        var result: [String: String] = [:]
        // Entries are already sorted by path, so first encountered is deterministic
        for entry in entries {
            if let hash = entry.hash, result[hash] == nil {
                result[hash] = entry.path
            }
        }
        return result
    }

    /// Set of all content hashes in the index for O(1) duplicate detection
    ///
    /// Entries without hashes are skipped.
    ///
    /// - Complexity: O(n) where n is the number of entries
    public var hashSet: Set<String> {
        var result = Set<String>()
        for entry in entries {
            if let hash = entry.hash {
                result.insert(hash)
            }
        }
        return result
    }

    /// Number of entries that have hash values
    public var hashEntryCount: Int {
        entries.filter { $0.hash != nil }.count
    }

    /// Hash coverage as a percentage (0.0 to 1.0)
    ///
    /// Returns 0.0 if index is empty.
    public var hashCoverage: Double {
        guard entryCount > 0 else { return 0.0 }
        return Double(hashEntryCount) / Double(entryCount)
    }
}

/// Single entry in the baseline index representing one media file
public struct IndexEntry: Equatable {
    /// Normalized relative path from library root (e.g., "2024/01/IMG_1234.jpg")
    public let path: String

    /// File size in bytes
    public let size: Int64

    /// File modification time as ISO8601 timestamp
    public let mtime: String

    /// Content hash (SHA-256) in format "sha256:<hexdigest>"
    /// Optional for backward compatibility with v1.0 indexes
    public let hash: String?

    /// Creates a new index entry
    ///
    /// - Parameters:
    ///   - path: Normalized relative path from library root
    ///   - size: File size in bytes
    ///   - mtime: File modification time as ISO8601 timestamp
    ///   - hash: Optional content hash (SHA-256)
    public init(path: String, size: Int64, mtime: String, hash: String? = nil) {
        self.path = path
        self.size = size
        self.mtime = mtime
        self.hash = hash
    }
}

// MARK: - IndexEntry Codable

extension IndexEntry: Codable {
    enum CodingKeys: String, CodingKey {
        case path, size, mtime, hash
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        path = try container.decode(String.self, forKey: .path)
        size = try container.decode(Int64.self, forKey: .size)
        mtime = try container.decode(String.self, forKey: .mtime)
        // Hash is optional - decodeIfPresent returns nil if key is missing
        hash = try container.decodeIfPresent(String.self, forKey: .hash)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(path, forKey: .path)
        try container.encode(size, forKey: .size)
        try container.encode(mtime, forKey: .mtime)
        // Only encode hash if present (omit nil values from JSON)
        try container.encodeIfPresent(hash, forKey: .hash)
    }
}

// MARK: - Errors

/// Errors that can occur during baseline index operations
public enum BaselineIndexError: Error, LocalizedError {
    case fileNotFound(String)
    case invalidJSON(String)
    case unsupportedVersion(String)
    case missingEntriesArray
    case pathOutsideLibraryRoot(String)
    case directoryCreationFailed(String, Error)
    case writeFailed(String, Error)
    case readFailed(String, Error)
    case encodingFailed(Error)
    case decodingFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Index file not found: \(path)"
        case .invalidJSON(let reason):
            return "Invalid JSON format: \(reason)"
        case .unsupportedVersion(let version):
            return "Unsupported index version: \(version) (supported: 1.0, 1.1)"
        case .missingEntriesArray:
            return "Index is missing required 'entries' array"
        case .pathOutsideLibraryRoot(let path):
            return "Index path is outside library root: \(path)"
        case .directoryCreationFailed(let path, let error):
            return "Failed to create registry directory at \(path): \(error.localizedDescription)"
        case .writeFailed(let path, let error):
            return "Failed to write index to \(path): \(error.localizedDescription)"
        case .readFailed(let path, let error):
            return "Failed to read index from \(path): \(error.localizedDescription)"
        case .encodingFailed(let error):
            return "Failed to encode index: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to decode index: \(error.localizedDescription)"
        }
    }
}

// MARK: - Path Normalization

/// Helper function to check if a resolved path is within a resolved root
///
/// - Parameters:
///   - resolvedPath: Resolved absolute path to check
///   - resolvedRoot: Resolved absolute path to root
/// - Returns: `true` if path is within root (equal to root or starts with root + "/"), `false` otherwise
private func isPathWithinRoot(_ resolvedPath: String, _ resolvedRoot: String) -> Bool {
    // Path must be exactly the root, or start with root + "/"
    return resolvedPath == resolvedRoot || resolvedPath.hasPrefix(resolvedRoot + "/")
}

/// Helper function to check if a resolved path is strictly within a resolved root (not equal to root)
///
/// - Parameters:
///   - resolvedPath: Resolved absolute path to check
///   - resolvedRoot: Resolved absolute path to root
/// - Returns: `true` if path is strictly within root (must start with root + "/"), `false` otherwise
private func isPathStrictlyWithinRoot(_ resolvedPath: String, _ resolvedRoot: String) -> Bool {
    // Path must start with root + "/" (strictly within, not equal to root)
    return resolvedPath.hasPrefix(resolvedRoot + "/")
}

/// Normalizes a file path relative to library root
///
/// - Parameters:
///   - absolutePath: Absolute path to normalize
///   - libraryRoot: Absolute path to library root
/// - Returns: Normalized relative path (using `/` separators, resolved symlinks)
/// - Throws: `BaselineIndexError` if path cannot be normalized
public func normalizePath(_ absolutePath: String, relativeTo libraryRoot: String) throws -> String {
    let absoluteURL = URL(fileURLWithPath: absolutePath)
    let libraryRootURL = URL(fileURLWithPath: libraryRoot)
    
    // Resolve symlinks
    let resolvedPathURL = absoluteURL.resolvingSymlinksInPath()
    let resolvedLibraryRootURL = libraryRootURL.resolvingSymlinksInPath()
    
    let resolvedPath = resolvedPathURL.path
    let resolvedLibraryRoot = resolvedLibraryRootURL.path
    
    // Verify that resolved path is actually within resolved library root
    guard isPathWithinRoot(resolvedPath, resolvedLibraryRoot) else {
        throw BaselineIndexError.pathOutsideLibraryRoot(absolutePath)
    }
    
    // Calculate relative path by removing the root prefix
    let relativePath: String
    if resolvedPath == resolvedLibraryRoot {
        // Path is exactly the root, relative path is empty
        relativePath = ""
    } else {
        // Remove root + "/" prefix
        relativePath = String(resolvedPath.dropFirst(resolvedLibraryRoot.count + 1))
    }
    
    // Normalize separators to `/`
    let normalized = relativePath.replacingOccurrences(of: "\\", with: "/")
    
    return normalized
}

// MARK: - Index Validator

/// Validation result for index validation
public enum IndexValidationResult {
    case valid
    case invalid(BaselineIndexError)
}

/// Validates baseline index files
public struct IndexValidator {
    /// Validates an index file
    ///
    /// - Parameters:
    ///   - indexPath: Path to the index file
    ///   - fileManager: File manager to use (default: FileManager.default)
    /// - Returns: Validation result
    public static func validate(_ indexPath: String, fileManager: FileManager = .default) -> IndexValidationResult {
        // Check if file exists
        guard fileManager.fileExists(atPath: indexPath) else {
            return .invalid(.fileNotFound(indexPath))
        }
        
        // Check if file is readable
        guard fileManager.isReadableFile(atPath: indexPath) else {
            return .invalid(.readFailed(indexPath, NSError(domain: "BaselineIndex", code: 1, userInfo: [NSLocalizedDescriptionKey: "File is not readable"])))
        }
        
        // Try to read and parse JSON
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: indexPath))
            let decoder = JSONDecoder()
            let index = try decoder.decode(BaselineIndex.self, from: data)

            // Validate version (support version 1.0 and 1.1)
            guard BaselineIndex.supportedVersions.contains(index.version) else {
                return .invalid(.unsupportedVersion(index.version))
            }

            // Validate entries array is present (can be empty)
            // Note: entries array is always present in BaselineIndex struct, so this check is implicit
            // But we verify the structure is valid

            return .valid
        } catch let error as DecodingError {
            return .invalid(.invalidJSON("Decoding error: \(error.localizedDescription)"))
        } catch {
            return .invalid(.decodingFailed(error))
        }
    }
}

// MARK: - Index State

/// Index usage state for detection operations
public enum IndexUsageState {
    case valid(BaselineIndex)
    case absent
    case invalid(String) // Fallback reason
    
    /// Returns true if index is valid and can be used
    public var isValid: Bool {
        switch self {
        case .valid:
            return true
        case .absent, .invalid:
            return false
        }
    }
    
    /// Returns fallback reason if index is not valid
    public var fallbackReason: String? {
        switch self {
        case .valid:
            return nil
        case .absent:
            return "missing"
        case .invalid(let reason):
            return reason
        }
    }
}

// MARK: - Index Reader

/// Reads baseline index from JSON file
public struct BaselineIndexReader {
    /// Loads index from JSON file
    ///
    /// - Parameter indexPath: Path to the index file
    /// - Returns: Loaded baseline index
    /// - Throws: `BaselineIndexError` if loading fails
    public static func load(from indexPath: String) throws -> BaselineIndex {
        let fileManager = FileManager.default
        
        // Check if file exists
        guard fileManager.fileExists(atPath: indexPath) else {
            throw BaselineIndexError.fileNotFound(indexPath)
        }
        
        // Validate index before loading
        switch IndexValidator.validate(indexPath, fileManager: fileManager) {
        case .valid:
            break
        case .invalid(let error):
            throw error
        }
        
        // Read and parse JSON
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: indexPath))
            let decoder = JSONDecoder()
            let index = try decoder.decode(BaselineIndex.self, from: data)
            return index
        } catch let error as DecodingError {
            throw BaselineIndexError.decodingFailed(error)
        } catch {
            throw BaselineIndexError.readFailed(indexPath, error)
        }
    }
}

// MARK: - Index Writer

/// Writes baseline index to JSON file atomically
public struct BaselineIndexWriter {
    /// Temporary file prefix for MediaHub temp files (reused from AtomicFileCopy pattern)
    private static let tempFilePrefix = ".mediahub-tmp-"
    
    /// Registry directory name within .mediahub
    private static let registryDirectoryName = "registry"
    
    /// Index file name
    private static let indexFileName = "index.json"
    
    /// Ensures registry directory exists
    ///
    /// - Parameters:
    ///   - libraryRoot: Absolute path to library root
    ///   - fileManager: File manager to use
    /// - Throws: `BaselineIndexError` if directory creation fails
    private static func ensureRegistryDirectoryExists(
        libraryRoot: String,
        fileManager: FileManager = .default
    ) throws {
        let libraryRootURL = URL(fileURLWithPath: libraryRoot)
        let registryDirURL = libraryRootURL
            .appendingPathComponent(LibraryStructure.metadataDirectoryName)
            .appendingPathComponent(registryDirectoryName)
        
        // Check if directory exists
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: registryDirURL.path, isDirectory: &isDirectory),
           isDirectory.boolValue {
            return // Directory already exists
        }
        
        // Create directory with intermediate directories
        do {
            try fileManager.createDirectory(
                at: registryDirURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            throw BaselineIndexError.directoryCreationFailed(registryDirURL.path, error)
        }
    }
    
    /// Validates that index file path is strictly within library root
    ///
    /// - Parameters:
    ///   - indexPath: Path to the index file
    ///   - libraryRoot: Absolute path to library root
    /// - Throws: `BaselineIndexError` if path is outside library root
    public static func validateIndexPath(_ indexPath: String, libraryRoot: String) throws {
        let indexPathURL = URL(fileURLWithPath: indexPath)
        let libraryRootURL = URL(fileURLWithPath: libraryRoot)
        
        // Resolve symlinks
        let resolvedIndexPath = indexPathURL.resolvingSymlinksInPath().path
        let resolvedLibraryRoot = libraryRootURL.resolvingSymlinksInPath().path
        
        // Check that index path is strictly within library root
        // Path must start with root + "/" (strictly within, not equal to root)
        guard isPathStrictlyWithinRoot(resolvedIndexPath, resolvedLibraryRoot) else {
            throw BaselineIndexError.pathOutsideLibraryRoot(indexPath)
        }
    }
    
    /// Writes index to JSON file atomically (write-then-rename pattern, reusing AtomicFileCopy pattern)
    ///
    /// - Parameters:
    ///   - index: Baseline index to write
    ///   - indexPath: Path where index should be written
    ///   - libraryRoot: Absolute path to library root (for validation and directory creation)
    /// - Throws: `BaselineIndexError` if writing fails
    public static func write(
        _ index: BaselineIndex,
        to indexPath: String,
        libraryRoot: String
    ) throws {
        let fileManager = FileManager.default
        
        // Validate index path is within library root
        try validateIndexPath(indexPath, libraryRoot: libraryRoot)
        
        // Ensure registry directory exists
        try ensureRegistryDirectoryExists(libraryRoot: libraryRoot, fileManager: fileManager)
        
        // Create JSON encoder with stable options for determinism
        // Note: Entries are already sorted in BaselineIndex.init, so we just need stable encoder options
        let encoder = JSONEncoder()
        // Use sortedKeys for deterministic key order (documented in code)
        encoder.outputFormatting = [.sortedKeys]
        // Note: Timestamps are stored as String (ISO8601), not Date, so dateEncodingStrategy is not needed
        
        // Encode index to JSON
        let jsonData: Data
        do {
            jsonData = try encoder.encode(index)
        } catch {
            throw BaselineIndexError.encodingFailed(error)
        }
        
        // Generate temporary file URL (same directory as destination)
        let indexPathURL = URL(fileURLWithPath: indexPath)
        let directory = indexPathURL.deletingLastPathComponent()
        let tempFileName = ".\(indexFileName).\(tempFilePrefix)\(UUID().uuidString)"
        let tempURL = directory.appendingPathComponent(tempFileName)
        
        // Write JSON to temporary file
        do {
            try jsonData.write(to: tempURL, options: .atomic)
        } catch {
            throw BaselineIndexError.writeFailed(tempURL.path, error)
        }
        
        // Verify write integrity (file exists, size matches)
        do {
            let tempAttributes = try fileManager.attributesOfItem(atPath: tempURL.path)
            guard let tempSize = tempAttributes[.size] as? Int64,
                  tempSize == Int64(jsonData.count) else {
                // Cleanup temp file
                _ = try? fileManager.removeItem(at: tempURL)
                throw BaselineIndexError.writeFailed(tempURL.path, NSError(domain: "BaselineIndex", code: 1, userInfo: [NSLocalizedDescriptionKey: "File size mismatch after write"]))
            }
        } catch let error as BaselineIndexError {
            throw error
        } catch {
            // Cleanup temp file
            _ = try? fileManager.removeItem(at: tempURL)
            throw BaselineIndexError.writeFailed(tempURL.path, error)
        }
        
        // Atomically replace/rename temporary file to final destination
        // Use replaceItemAt if destination exists (atomic replacement), otherwise use moveItem
        do {
            if fileManager.fileExists(atPath: indexPathURL.path) {
                // Destination exists: use replaceItemAt for atomic replacement
                // replaceItemAt returns backup URL (if backup was created), we don't need it
                _ = try fileManager.replaceItemAt(
                    indexPathURL,
                    withItemAt: tempURL,
                    backupItemName: nil,
                    options: []
                )
            } else {
                // Destination doesn't exist: use moveItem
                try fileManager.moveItem(at: tempURL, to: indexPathURL)
            }
        } catch {
            // Cleanup temp file on rename/replace failure
            _ = try? fileManager.removeItem(at: tempURL)
            throw BaselineIndexError.writeFailed(indexPath, error)
        }
    }
    
    /// Gets the index file path for a library root
    ///
    /// - Parameter libraryRoot: Absolute path to library root
    /// - Returns: Path to the index file
    public static func indexFilePath(for libraryRoot: String) -> String {
        let libraryRootURL = URL(fileURLWithPath: libraryRoot)
        return libraryRootURL
            .appendingPathComponent(LibraryStructure.metadataDirectoryName)
            .appendingPathComponent(registryDirectoryName)
            .appendingPathComponent(indexFileName)
            .path
    }
}

// MARK: - Index Loading Utility

/// Utility for loading baseline index with state tracking (for detection operations)
public struct BaselineIndexLoader {
    /// Attempts to load baseline index for a library root
    ///
    /// Returns the index state: valid (with index), absent, or invalid (with reason)
    /// This function is READ-ONLY and never creates or modifies the index.
    ///
    /// - Parameter libraryRoot: Absolute path to library root
    /// - Returns: Index usage state
    public static func tryLoadBaselineIndex(libraryRoot: String) -> IndexUsageState {
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRoot)
        
        // Check if index file exists
        guard FileManager.default.fileExists(atPath: indexPath) else {
            return .absent
        }
        
        // Validate index
        switch IndexValidator.validate(indexPath) {
        case .valid:
            // Try to load index
            do {
                let index = try BaselineIndexReader.load(from: indexPath)
                return .valid(index)
            } catch {
                // If loading fails, determine reason
                if case BaselineIndexError.unsupportedVersion(let version) = error {
                    return .invalid("unsupported_version: \(version)")
                } else if case BaselineIndexError.invalidJSON = error {
                    return .invalid("corrupted")
                } else if case BaselineIndexError.decodingFailed = error {
                    return .invalid("corrupted")
                } else {
                    return .invalid("load_failed")
                }
            }
        case .invalid(let error):
            // Determine fallback reason from validation error
            switch error {
            case .fileNotFound:
                return .absent
            case .unsupportedVersion(let version):
                return .invalid("unsupported_version: \(version)")
            case .invalidJSON, .decodingFailed:
                return .invalid("corrupted")
            default:
                return .invalid("validation_failed")
            }
        }
    }
}
