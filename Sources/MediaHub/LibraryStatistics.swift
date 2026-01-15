//
//  LibraryStatistics.swift
//  MediaHub
//
//  Library statistics computation from BaselineIndex
//

import Foundation

/// Library statistics data structure
public struct LibraryStatistics: Codable, Equatable {
    /// Total number of items in the library
    public let totalItems: Int
    
    /// Distribution of items by year (year as string key, count as value)
    /// Items with unextractable year are grouped under "unknown" key
    public let byYear: [String: Int]
    
    /// Distribution of items by media type (media type as key: "images", "videos", count as value)
    /// Items with unknown extensions are excluded from this distribution but counted in totalItems
    public let byMediaType: [String: Int]
    
    /// Creates library statistics
    ///
    /// - Parameters:
    ///   - totalItems: Total number of items
    ///   - byYear: Distribution by year
    ///   - byMediaType: Distribution by media type
    public init(totalItems: Int, byYear: [String: Int], byMediaType: [String: Int]) {
        self.totalItems = totalItems
        self.byYear = byYear
        self.byMediaType = byMediaType
    }
}

/// Computes library statistics from BaselineIndex
public struct LibraryStatisticsComputer {
    /// Computes statistics from BaselineIndex entries
    ///
    /// - Parameter index: BaselineIndex to compute statistics from
    /// - Returns: Library statistics
    public static func compute(from index: BaselineIndex) -> LibraryStatistics {
        var totalItems = 0
        var yearCounts: [String: Int] = [:]
        var mediaTypeCounts: [String: Int] = ["images": 0, "videos": 0]
        
        // Single pass over entries (O(n) complexity)
        for entry in index.entries {
            totalItems += 1
            
            // Extract year from normalized path (first path component)
            // Path format: "YYYY/MM/filename.ext" or "unknown/filename.ext" or just "filename.ext"
            let pathComponents = entry.path.split(separator: "/")
            if let firstComponent = pathComponents.first {
                let yearString = String(firstComponent)
                // Validate year pattern: 4 digits (YYYY)
                if yearString.count == 4, yearString.allSatisfy({ $0.isNumber }) {
                    // Valid year pattern
                    yearCounts[yearString, default: 0] += 1
                } else {
                    // Invalid year pattern - use "unknown" bucket
                    yearCounts["unknown", default: 0] += 1
                }
            } else {
                // Empty path or no components - use "unknown" bucket
                yearCounts["unknown", default: 0] += 1
            }
            
            // Classify media type from file extension (reuse MediaFileFormat classification)
            let url = URL(fileURLWithPath: entry.path)
            let fileExtension = url.pathExtension
            
            if !fileExtension.isEmpty {
                if MediaFileFormat.isImageFile(extension: fileExtension) {
                    mediaTypeCounts["images", default: 0] += 1
                } else if MediaFileFormat.isVideoFile(extension: fileExtension) {
                    mediaTypeCounts["videos", default: 0] += 1
                }
                // Unknown extensions are excluded from byMediaType but counted in totalItems
            }
            // Files without extensions are excluded from byMediaType but counted in totalItems
        }
        
        return LibraryStatistics(
            totalItems: totalItems,
            byYear: yearCounts,
            byMediaType: mediaTypeCounts
        )
    }
}
