//
//  ScaleMetrics.swift
//  MediaHub
//
//  Scale metrics computation from BaselineIndex (read-only, deterministic)
//

import Foundation

/// Scale metrics for a library (file count, total size, hash coverage)
///
/// All metrics are computed deterministically from BaselineIndex.
/// Same library state produces identical scale metrics.
public struct ScaleMetrics: Equatable {
    /// Total number of files in the library
    public let fileCount: Int
    
    /// Total size of all files in bytes
    public let totalSizeBytes: Int64
    
    /// Hash coverage as a percentage (0.0 to 100.0)
    /// nil if hash coverage cannot be computed (e.g., empty index)
    public let hashCoveragePercent: Double?
    
    /// Creates scale metrics
    ///
    /// - Parameters:
    ///   - fileCount: Total number of files
    ///   - totalSizeBytes: Total size in bytes
    ///   - hashCoveragePercent: Hash coverage percentage (nil if not applicable)
    public init(fileCount: Int, totalSizeBytes: Int64, hashCoveragePercent: Double?) {
        self.fileCount = fileCount
        self.totalSizeBytes = totalSizeBytes
        self.hashCoveragePercent = hashCoveragePercent
    }
}

/// Computes scale metrics from BaselineIndex
///
/// This is a read-only, deterministic operation.
/// Same BaselineIndex produces identical ScaleMetrics.
public struct ScaleMetricsComputer {
    /// Computes scale metrics from BaselineIndex
    ///
    /// - Parameter index: BaselineIndex to compute metrics from
    /// - Returns: Scale metrics computed from the index
    public static func compute(from index: BaselineIndex) -> ScaleMetrics {
        let fileCount = index.entryCount
        let totalSizeBytes = index.entries.reduce(Int64(0)) { $0 + $1.size }
        
        // Compute hash coverage percentage
        // Use the existing hashCoverage property (0.0 to 1.0) and convert to percentage
        let hashCoveragePercent: Double?
        if fileCount > 0 {
            // Convert from 0.0-1.0 to 0.0-100.0
            hashCoveragePercent = index.hashCoverage * 100.0
        } else {
            // Empty index: hash coverage is not applicable
            hashCoveragePercent = nil
        }
        
        return ScaleMetrics(
            fileCount: fileCount,
            totalSizeBytes: totalSizeBytes,
            hashCoveragePercent: hashCoveragePercent
        )
    }
    
    /// Attempts to compute scale metrics for a library root
    ///
    /// Loads BaselineIndex via existing loaders and computes metrics.
    /// Returns nil if BaselineIndex is missing or invalid.
    ///
    /// This is a read-only operation that does not modify the index or filesystem.
    ///
    /// - Parameter libraryRoot: Absolute path to library root
    /// - Returns: Scale metrics if index is valid, nil otherwise
    public static func compute(for libraryRoot: String) -> ScaleMetrics? {
        let indexState = BaselineIndexLoader.tryLoadBaselineIndex(libraryRoot: libraryRoot)
        
        guard case .valid(let index) = indexState else {
            // Index is missing or invalid - return nil (caller decides how to handle)
            return nil
        }
        
        return compute(from: index)
    }
}
