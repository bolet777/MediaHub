//
//  LibraryComparison.swift
//  MediaHub
//
//  Library comparison and new item detection
//

import Foundation

/// Comparison result for a candidate item
public enum ItemComparisonResult {
    case new
    case known
}

/// Errors that can occur during comparison
public enum LibraryComparisonError: Error, LocalizedError {
    case libraryInaccessible(String)
    case comparisonFailed(String, Error)
    
    public var errorDescription: String? {
        switch self {
        case .libraryInaccessible(let path):
            return "Library is inaccessible: \(path)"
        case .comparisonFailed(let path, let error):
            return "Comparison failed at \(path): \(error.localizedDescription)"
        }
    }
}

/// Queries Library contents for comparison
public struct LibraryContentQuery {
    /// Scans Library root for media files (excluding .mediahub/)
    ///
    /// - Parameter libraryRootURL: The URL of the library root directory
    /// - Returns: Set of normalized paths of media files in Library
    /// - Throws: `LibraryComparisonError` if scanning fails
    public static func scanLibraryContents(
        at libraryRootURL: URL
    ) throws -> Set<String> {
        let fileManager = FileManager.default
        
        // Validate library root exists
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: libraryRootURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw LibraryComparisonError.libraryInaccessible(libraryRootURL.path)
        }
        
        var libraryPaths: Set<String> = []
        let metadataDirName = LibraryStructure.metadataDirectoryName
        
        // Recursively scan library root (excluding .mediahub/)
        try scanDirectory(
            at: libraryRootURL,
            fileManager: fileManager,
            metadataDirName: metadataDirName,
            libraryPaths: &libraryPaths
        )
        
        return libraryPaths
    }
    
    /// Recursively scans a directory for media files
    ///
    /// - Parameters:
    ///   - directoryURL: The directory URL to scan
    ///   - fileManager: File manager instance
    ///   - metadataDirName: Name of metadata directory to skip
    ///   - libraryPaths: Mutable set to add paths to
    /// - Throws: Errors if scanning fails critically
    private static func scanDirectory(
        at directoryURL: URL,
        fileManager: FileManager,
        metadataDirName: String,
        libraryPaths: inout Set<String>
    ) throws {
        // Skip .mediahub/ directory
        if directoryURL.lastPathComponent == metadataDirName {
            return
        }
        
        let resourceKeys: [URLResourceKey] = [.isRegularFileKey]
        
        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles],
            errorHandler: { url, error in
                // Handle individual file errors gracefully
                return true // Continue enumeration
            }
        ) else {
            return
        }
        
        for case let fileURL as URL in enumerator {
            // Skip .mediahub/ directory and its contents
            if fileURL.pathComponents.contains(metadataDirName) {
                continue
            }
            
            // Check if it's a media file by extension
            guard MediaFileFormat.isMediaFile(path: fileURL.path) else {
                continue
            }
            
            // Try to get file attributes
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                
                // Skip if not a regular file
                guard resourceValues.isRegularFile == true else {
                    continue
                }
                
                // Resolve symlinks to actual paths for comparison
                let resolvedPath = fileURL.resolvingSymlinksInPath().path
                libraryPaths.insert(resolvedPath)
            } catch {
                // Skip files that can't be read
                continue
            }
        }
    }
}

/// Compares candidate items against Library contents
public struct LibraryItemComparator {
    /// Compares a candidate item against Library contents
    ///
    /// - Parameters:
    ///   - candidate: The candidate item to compare
    ///   - libraryPaths: Set of normalized paths in Library
    /// - Returns: Comparison result (new or known)
    public static func compare(
        candidate: CandidateMediaItem,
        against libraryPaths: Set<String>
    ) -> ItemComparisonResult {
        // Resolve symlinks for comparison
        let candidatePath = URL(fileURLWithPath: candidate.path)
        let resolvedPath = candidatePath.resolvingSymlinksInPath().path
        
        // Check if path exists in Library
        if libraryPaths.contains(resolvedPath) {
            return .known
        } else {
            return .new
        }
    }
    
    /// Compares multiple candidate items against Library contents
    ///
    /// - Parameters:
    ///   - candidates: Array of candidate items
    ///   - libraryPaths: Set of normalized paths in Library
    /// - Returns: Dictionary mapping candidate items to comparison results
    public static func compareAll(
        candidates: [CandidateMediaItem],
        against libraryPaths: Set<String>
    ) -> [CandidateMediaItem: ItemComparisonResult] {
        var results: [CandidateMediaItem: ItemComparisonResult] = [:]
        
        for candidate in candidates {
            results[candidate] = compare(candidate: candidate, against: libraryPaths)
        }
        
        return results
    }
}

/// Excludes known items from candidate lists
public struct KnownItemExcluder {
    /// Filters out known items from candidate list
    ///
    /// - Parameters:
    ///   - candidates: Array of candidate items
    ///   - comparisonResults: Dictionary of comparison results
    /// - Returns: Array of only new candidate items
    public static func excludeKnown(
        candidates: [CandidateMediaItem],
        comparisonResults: [CandidateMediaItem: ItemComparisonResult]
    ) -> [CandidateMediaItem] {
        return candidates.filter { candidate in
            guard let result = comparisonResults[candidate] else {
                // If no comparison result, treat as new (shouldn't happen)
                return true
            }
            return result == .new
        }
    }
}
