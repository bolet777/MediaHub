//
//  HashCoverageMaintenance.swift
//  MediaHub
//
//  Hash coverage maintenance operations for existing libraries
//

import Foundation

// MARK: - Errors

/// Errors that can occur during hash coverage maintenance operations
public enum HashCoverageMaintenanceError: Error, LocalizedError {
    case libraryNotFound(String)
    case indexNotFound(String)
    case indexInvalid(String)
    case indexLoadFailed(String)
    case permissionDenied(String)
    
    public var errorDescription: String? {
        switch self {
        case .libraryNotFound(let path):
            return "Library not found at path: \(path)"
        case .indexNotFound(let path):
            return "Baseline index not found at path: \(path)"
        case .indexInvalid(let reason):
            return "Baseline index is invalid: \(reason)"
        case .indexLoadFailed(let reason):
            return "Failed to load baseline index: \(reason)"
        case .permissionDenied(let path):
            return "Permission denied accessing path: \(path)"
        }
    }
}

// MARK: - Statistics

/// Statistics about hash coverage in the library
public struct HashCoverageStatistics {
    /// Total number of entries in the baseline index
    public let totalEntries: Int
    
    /// Number of entries that have hash values
    public let entriesWithHash: Int
    
    /// Number of entries missing hash values
    public let entriesMissingHash: Int
    
    /// Number of candidate entries (missing hash and file exists)
    public let candidateCount: Int
    
    /// Number of entries where file is missing (missing hash but file doesn't exist)
    public let missingFilesCount: Int
    
    /// Hash coverage as a percentage (0.0 to 1.0)
    public let hashCoverage: Double
    
    /// Creates hash coverage statistics
    public init(
        totalEntries: Int,
        entriesWithHash: Int,
        entriesMissingHash: Int,
        candidateCount: Int,
        missingFilesCount: Int,
        hashCoverage: Double
    ) {
        self.totalEntries = totalEntries
        self.entriesWithHash = entriesWithHash
        self.entriesMissingHash = entriesMissingHash
        self.candidateCount = candidateCount
        self.missingFilesCount = missingFilesCount
        self.hashCoverage = hashCoverage
    }
}

// MARK: - Candidate Selection Result

/// Result of candidate selection for hash computation
public struct HashCoverageCandidates {
    /// Statistics about hash coverage
    public let statistics: HashCoverageStatistics
    
    /// Candidate entries (missing hash, file exists), sorted by normalized path for determinism
    public let candidates: [IndexEntry]
    
    /// Creates candidate selection result
    ///
    /// - Parameters:
    ///   - statistics: Hash coverage statistics
    ///   - candidates: Candidate entries (should already be sorted by normalized path)
    public init(statistics: HashCoverageStatistics, candidates: [IndexEntry]) {
        self.statistics = statistics
        // Candidates should already be sorted before being passed here
        // We still sort here as a safety measure to ensure determinism
        self.candidates = candidates.sorted { $0.path < $1.path }
    }
}

// MARK: - Hash Computation Result

/// Result of hash computation operation
public struct HashComputationResult {
    /// Statistics about hash coverage (before computation)
    public let statistics: HashCoverageStatistics
    
    /// Map of computed hashes: path -> hash (only for successfully computed hashes)
    public let computedHashes: [String: String]
    
    /// Number of hashes successfully computed
    public let hashesComputed: Int
    
    /// Number of files that failed hash computation
    public let hashFailures: Int
    
    /// Creates hash computation result
    public init(
        statistics: HashCoverageStatistics,
        computedHashes: [String: String],
        hashesComputed: Int,
        hashFailures: Int
    ) {
        self.statistics = statistics
        self.computedHashes = computedHashes
        self.hashesComputed = hashesComputed
        self.hashFailures = hashFailures
    }
}

// MARK: - Index Update Result

/// Result of index update operation
public struct IndexUpdateResult {
    /// Statistics before update
    public let statisticsBefore: HashCoverageStatistics
    
    /// Statistics after update
    public let statisticsAfter: HashCoverageStatistics
    
    /// Number of entries updated with new hashes
    public let entriesUpdated: Int
    
    /// Whether the index file was actually written (false if no changes)
    public let indexUpdated: Bool
    
    /// Creates index update result
    public init(
        statisticsBefore: HashCoverageStatistics,
        statisticsAfter: HashCoverageStatistics,
        entriesUpdated: Int,
        indexUpdated: Bool
    ) {
        self.statisticsBefore = statisticsBefore
        self.statisticsAfter = statisticsAfter
        self.entriesUpdated = entriesUpdated
        self.indexUpdated = indexUpdated
    }
}

// MARK: - Hash Coverage Maintenance

/// Operations for maintaining hash coverage in existing libraries
public struct HashCoverageMaintenance {
    /// Progress throttling helper to limit callbacks to 1 update per second
    private struct ProgressThrottle {
        var lastInvocationTime: Date? = nil
        
        func shouldInvoke() -> Bool {
            guard let lastTime = lastInvocationTime else {
                return true
            }
            return Date().timeIntervalSince(lastTime) >= 1.0
        }
        
        mutating func recordInvocation() {
            lastInvocationTime = Date()
        }
    }
    
    /// Invokes progress callback if needed (with throttling)
    private static func invokeProgressIfNeeded(
        progress: ProgressUpdate,
        throttle: inout ProgressThrottle,
        callback: ((ProgressUpdate) -> Void)?
    ) {
        guard let callback = callback else {
            return
        }
        
        if throttle.shouldInvoke() {
            callback(progress)
            throttle.recordInvocation()
        }
    }
    /// Selects candidates for hash computation from the baseline index
    ///
    /// This is a READ-ONLY operation that:
    /// - Loads the baseline index
    /// - Selects entries missing hash values
    /// - Validates file existence (metadata-only check)
    /// - Returns candidates sorted by normalized path (deterministic order)
    /// - Computes statistics
    ///
    /// This function does NOT:
    /// - Compute any hashes
    /// - Write to the index
    /// - Modify any files
    ///
    /// - Parameters:
    ///   - libraryRoot: Absolute path to library root
    ///   - limit: Optional limit on number of candidates to return (for incremental operation)
    ///   - fileManager: File manager to use (default: FileManager.default)
    /// - Returns: Candidate selection result with statistics and sorted candidates
    /// - Throws: `HashCoverageMaintenanceError` if library or index is invalid
    public static func selectCandidates(
        libraryRoot: String,
        limit: Int? = nil,
        fileManager: FileManager = .default
    ) throws -> HashCoverageCandidates {
        // Validate library root exists
        guard fileManager.fileExists(atPath: libraryRoot) else {
            throw HashCoverageMaintenanceError.libraryNotFound(libraryRoot)
        }
        
        // Get index file path
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRoot)
        
        // Check if index exists
        guard fileManager.fileExists(atPath: indexPath) else {
            throw HashCoverageMaintenanceError.indexNotFound(indexPath)
        }
        
        // Load baseline index
        let index: BaselineIndex
        do {
            index = try BaselineIndexReader.load(from: indexPath)
        } catch let error as BaselineIndexError {
            switch error {
            case .fileNotFound:
                throw HashCoverageMaintenanceError.indexNotFound(indexPath)
            case .unsupportedVersion(let version):
                throw HashCoverageMaintenanceError.indexInvalid("unsupported version: \(version)")
            case .invalidJSON, .decodingFailed:
                throw HashCoverageMaintenanceError.indexInvalid("corrupted or invalid JSON")
            default:
                throw HashCoverageMaintenanceError.indexLoadFailed(error.localizedDescription)
            }
        } catch {
            throw HashCoverageMaintenanceError.indexLoadFailed(error.localizedDescription)
        }
        
        // Calculate statistics
        let totalEntries = index.entryCount
        let entriesWithHash = index.hashEntryCount
        let entriesMissingHash = totalEntries - entriesWithHash
        
        // Select candidates: entries without hash
        var candidates: [IndexEntry] = []
        var missingFilesCount = 0
        
        for entry in index.entries {
            // Skip entries that already have hashes
            guard entry.hash == nil else {
                continue
            }
            
            // Validate file existence (metadata-only check)
            let absolutePath = (libraryRoot as NSString).appendingPathComponent(entry.path)
            
            // Check if file exists (metadata-only, no content reading)
            if fileManager.fileExists(atPath: absolutePath) {
                candidates.append(entry)
            } else {
                missingFilesCount += 1
            }
        }
        
        // Sort candidates by normalized path for deterministic order (before applying limit)
        // This ensures --limit N always takes the first N entries in sorted order
        let sortedCandidates = candidates.sorted { $0.path < $1.path }
        
        // Apply limit if specified (after sorting to ensure deterministic selection)
        let limitedCandidates: [IndexEntry]
        if let limit = limit, limit > 0 {
            limitedCandidates = Array(sortedCandidates.prefix(limit))
        } else {
            limitedCandidates = sortedCandidates
        }
        
        // Calculate hash coverage
        let hashCoverage = totalEntries > 0 ? Double(entriesWithHash) / Double(totalEntries) : 0.0
        
        // Create statistics
        let statistics = HashCoverageStatistics(
            totalEntries: totalEntries,
            entriesWithHash: entriesWithHash,
            entriesMissingHash: entriesMissingHash,
            candidateCount: limitedCandidates.count,
            missingFilesCount: missingFilesCount,
            hashCoverage: hashCoverage
        )
        
        // Return result with candidates (already sorted and limited above)
        return HashCoverageCandidates(
            statistics: statistics,
            candidates: limitedCandidates
        )
    }
    
    /// Computes missing hashes for candidates in the baseline index
    ///
    /// This function:
    /// - Selects candidates (entries missing hash values)
    /// - Computes SHA-256 hashes for each candidate file
    /// - Returns computed hashes in memory (map path -> hash)
    /// - Respects `--limit` if specified
    /// - Never replaces existing hashes (only computes for entries without hash)
    ///
    /// This function does NOT:
    /// - Write to the baseline index
    /// - Modify any files
    ///
    /// - Parameters:
    ///   - libraryRoot: Absolute path to library root
    ///   - limit: Optional limit on number of files to process (for incremental operation)
    ///   - fileManager: File manager to use (default: FileManager.default)
    ///   - progress: Optional progress callback for reporting progress updates
    ///   - cancellationToken: Optional cancellation token for canceling the operation
    /// - Returns: Hash computation result with statistics and computed hashes
    /// - Throws: `HashCoverageMaintenanceError` if library or index is invalid, `CancellationError` if canceled
    ///           Note: Individual hash computation failures are collected and reported in result, not thrown
    public static func computeMissingHashes(
        libraryRoot: String,
        limit: Int? = nil,
        fileManager: FileManager = .default,
        progress: ((ProgressUpdate) -> Void)? = nil,
        cancellationToken: CancellationToken? = nil
    ) throws -> HashComputationResult {
        // Select candidates first
        let candidatesResult = try selectCandidates(
            libraryRoot: libraryRoot,
            limit: limit,
            fileManager: fileManager
        )
        
        let libraryRootURL = URL(fileURLWithPath: libraryRoot)
        var computedHashes: [String: String] = [:]
        var hashFailures = 0
        
        // Initialize progress throttle if progress callback provided
        var progressThrottle = ProgressThrottle()
        
        // Compute hashes for each candidate
        for (fileIndex, candidate) in candidatesResult.candidates.enumerated() {
            let absolutePath = (libraryRoot as NSString).appendingPathComponent(candidate.path)
            let candidateURL = URL(fileURLWithPath: absolutePath)
            
            do {
                // Compute SHA-256 hash using ContentHasher
                let hash = try ContentHasher.computeHash(
                    for: candidateURL,
                    allowedRoot: libraryRootURL
                )
                
                // Store computed hash (path -> hash)
                computedHashes[candidate.path] = hash
            } catch {
                // Hash computation failed for this file
                // Collect error but continue processing other files
                hashFailures += 1
            }
            
            // Invoke progress callback during hash computation loop (throttled)
            if let progressCallback = progress {
                invokeProgressIfNeeded(
                    progress: ProgressUpdate(
                        stage: "computing",
                        current: fileIndex + 1,
                        total: candidatesResult.candidates.count,
                        message: nil
                    ),
                    throttle: &progressThrottle,
                    callback: progressCallback
                )
            }
            
            // Check cancellation between files (after current file hash completes)
            if let token = cancellationToken, token.isCanceled {
                throw CancellationError.cancelled
            }
        }
        
        // Invoke progress callback at completion (not throttled, final update)
        if let progressCallback = progress {
            progressCallback(ProgressUpdate(
                stage: "complete",
                current: computedHashes.count,
                total: candidatesResult.candidates.count,
                message: nil
            ))
        }
        
        // Create result
        return HashComputationResult(
            statistics: candidatesResult.statistics,
            computedHashes: computedHashes,
            hashesComputed: computedHashes.count,
            hashFailures: hashFailures
        )
    }
    
    /// Applies computed hashes to the baseline index and writes it atomically
    ///
    /// This function:
    /// - Reloads the baseline index
    /// - Applies computed hashes only to entries with `hash == nil` (never overwrites existing hashes)
    /// - If no entries were modified → returns `indexUpdated=false` and does NOT write
    /// - Writes the index atomically using BaselineIndexWriter (write-then-rename pattern)
    /// - On write failure: guarantees no partial state (atomic write ensures all-or-nothing)
    ///
    /// - Parameters:
    ///   - libraryRoot: Absolute path to library root
    ///   - computedHashes: Map of path -> hash for hashes to apply
    ///   - fileManager: File manager to use (default: FileManager.default)
    /// - Returns: Index update result with before/after statistics
    /// - Throws: `HashCoverageMaintenanceError` if library or index is invalid, or `BaselineIndexError` on write failure
    public static func applyComputedHashesAndWriteIndex(
        libraryRoot: String,
        computedHashes: [String: String],
        fileManager: FileManager = .default
    ) throws -> IndexUpdateResult {
        // Validate library root exists
        guard fileManager.fileExists(atPath: libraryRoot) else {
            throw HashCoverageMaintenanceError.libraryNotFound(libraryRoot)
        }
        
        // Get index file path
        let indexPath = BaselineIndexWriter.indexFilePath(for: libraryRoot)
        
        // Reload baseline index
        let index: BaselineIndex
        do {
            index = try BaselineIndexReader.load(from: indexPath)
        } catch let error as BaselineIndexError {
            switch error {
            case .fileNotFound:
                throw HashCoverageMaintenanceError.indexNotFound(indexPath)
            case .unsupportedVersion(let version):
                throw HashCoverageMaintenanceError.indexInvalid("unsupported version: \(version)")
            case .invalidJSON, .decodingFailed:
                throw HashCoverageMaintenanceError.indexInvalid("corrupted or invalid JSON")
            default:
                throw HashCoverageMaintenanceError.indexLoadFailed(error.localizedDescription)
            }
        } catch {
            throw HashCoverageMaintenanceError.indexLoadFailed(error.localizedDescription)
        }
        
        // Calculate statistics before update
        let statsBefore = HashCoverageStatistics(
            totalEntries: index.entryCount,
            entriesWithHash: index.hashEntryCount,
            entriesMissingHash: index.entryCount - index.hashEntryCount,
            candidateCount: 0, // Not relevant for update result
            missingFilesCount: 0, // Not relevant for update result
            hashCoverage: index.hashCoverage
        )
        
        // Create updated entries: apply computed hashes only to entries with hash == nil
        var updatedEntries: [IndexEntry] = []
        var entriesUpdated = 0
        
        for entry in index.entries {
            if let computedHash = computedHashes[entry.path] {
                // We have a computed hash for this entry
                if entry.hash == nil {
                    // Entry has no hash: apply computed hash
                    let updatedEntry = IndexEntry(
                        path: entry.path,
                        size: entry.size,
                        mtime: entry.mtime,
                        hash: computedHash
                    )
                    updatedEntries.append(updatedEntry)
                    entriesUpdated += 1
                } else {
                    // Entry already has hash: preserve existing hash (never overwrite)
                    updatedEntries.append(entry)
                }
            } else {
                // No computed hash for this entry: preserve as-is
                updatedEntries.append(entry)
            }
        }
        
        // If no entries were updated, return early without writing
        guard entriesUpdated > 0 else {
            // Idempotence: no changes needed, return without write
            return IndexUpdateResult(
                statisticsBefore: statsBefore,
                statisticsAfter: statsBefore,
                entriesUpdated: 0,
                indexUpdated: false
            )
        }
        
        // Create updated index using BaselineIndex.updating method
        let updatedIndex = index.updating(with: updatedEntries)
        
        // Write index atomically
        do {
            try BaselineIndexWriter.write(
                updatedIndex,
                to: indexPath,
                libraryRoot: libraryRoot
            )
        } catch {
            // Write failure: rethrow as HashCoverageMaintenanceError
            throw HashCoverageMaintenanceError.indexLoadFailed("Failed to write index: \(error.localizedDescription)")
        }
        
        // Calculate statistics after update
        let statsAfter = HashCoverageStatistics(
            totalEntries: updatedIndex.entryCount,
            entriesWithHash: updatedIndex.hashEntryCount,
            entriesMissingHash: updatedIndex.entryCount - updatedIndex.hashEntryCount,
            candidateCount: 0, // Not relevant for update result
            missingFilesCount: 0, // Not relevant for update result
            hashCoverage: updatedIndex.hashCoverage
        )
        
        return IndexUpdateResult(
            statisticsBefore: statsBefore,
            statisticsAfter: statsAfter,
            entriesUpdated: entriesUpdated,
            indexUpdated: true
        )
    }
}
