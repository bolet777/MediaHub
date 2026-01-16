//
//  DuplicateReporting.swift
//  MediaHub
//
//  Core duplicate detection and reporting logic
//

import Foundation

/// Represents a duplicate file within a duplicate group
public struct DuplicateFile: Equatable {
    /// Relative path from library root
    public let path: String
    /// File size in bytes
    public let sizeBytes: Int64
    /// File creation timestamp (ISO8601)
    public let timestamp: String

    public init(path: String, sizeBytes: Int64, timestamp: String) {
        self.path = path
        self.sizeBytes = sizeBytes
        self.timestamp = timestamp
    }
}

/// Represents a group of duplicate files (same content hash)
public struct DuplicateGroup: Equatable {
    /// Content hash (SHA-256)
    public let hash: String
    /// Files in this duplicate group (sorted deterministically)
    public let files: [DuplicateFile]

    /// Number of files in this group
    public var fileCount: Int { files.count }

    /// Total size of all files in this group
    public var totalSizeBytes: Int64 {
        files.reduce(0) { $0 + $1.sizeBytes }
    }

    public init(hash: String, files: [DuplicateFile]) {
        self.hash = hash
        self.files = files.sorted { $0.path < $1.path }
    }
}

/// Summary statistics for duplicate analysis
public struct DuplicateSummary: Equatable {
    /// Total number of duplicate groups
    public let duplicateGroups: Int
    /// Total number of duplicate files across all groups
    public let totalDuplicateFiles: Int
    /// Total size of all duplicate files in bytes
    public let totalDuplicateSizeBytes: Int64
    /// Potential space savings (total size - size of one copy per group)
    public let potentialSavingsBytes: Int64

    public init(groups: [DuplicateGroup]) {
        self.duplicateGroups = groups.count
        self.totalDuplicateFiles = groups.reduce(0) { $0 + $1.fileCount }
        self.totalDuplicateSizeBytes = groups.reduce(0) { $0 + $1.totalSizeBytes }
        // Potential savings: total size minus one copy per group
        self.potentialSavingsBytes = groups.reduce(0) { $0 + ($1.totalSizeBytes - ($1.files.first?.sizeBytes ?? 0)) }
    }
}

/// Core duplicate reporting component
public struct DuplicateReporting {
    /// Analyzes a library for duplicate files by content hash
    ///
    /// - Parameter libraryPath: Absolute path to library root
    /// - Returns: Tuple of (duplicate groups, summary statistics)
    /// - Throws: DuplicateReportingError if analysis fails
    public static func analyzeDuplicates(in libraryPath: String) throws -> ([DuplicateGroup], DuplicateSummary) {
        // Load baseline index (read-only)
        let indexState = BaselineIndexLoader.tryLoadBaselineIndex(libraryRoot: libraryPath)

        let index: BaselineIndex
        switch indexState {
        case .valid(let loadedIndex):
            index = loadedIndex
        case .absent:
            throw DuplicateReportingError.baselineIndexMissing
        case .invalid(let reason):
            throw DuplicateReportingError.baselineIndexInvalid(reason)
        }

        // Build hash → [entries] mapping for entries with non-nil hashes
        var hashToEntries: [String: [IndexEntry]] = [:]

        for entry in index.entries {
            if let hash = entry.hash {
                hashToEntries[hash, default: []].append(entry)
            }
        }

        // Filter for groups with multiple files (true duplicates)
        let duplicateGroups = hashToEntries
            .filter { $0.value.count >= 2 }
            .map { (hash, entries) -> DuplicateGroup in
                let files = entries.map { entry in
                    DuplicateFile(
                        path: entry.path,
                        sizeBytes: entry.size,
                        timestamp: entry.mtime
                    )
                }
                return DuplicateGroup(hash: hash, files: files)
            }
            .sorted { $0.hash < $1.hash } // Deterministic group ordering

        let summary = DuplicateSummary(groups: duplicateGroups)

        return (duplicateGroups, summary)
    }
}

/// Errors that can occur during duplicate reporting
public enum DuplicateReportingError: Error, LocalizedError {
    case baselineIndexMissing
    case baselineIndexInvalid(String)

    public var errorDescription: String? {
        switch self {
        case .baselineIndexMissing:
            return "Baseline index not found. Run 'mediahub index hash' to create the index first."
        case .baselineIndexInvalid(let reason):
            return "Baseline index is invalid (\(reason)). Run 'mediahub index hash' to recreate the index."
        }
    }
}
