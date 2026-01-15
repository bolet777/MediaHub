//
//  SourceScanning.swift
//  MediaHub
//
//  Source scanning and media file detection
//

import Foundation

/// Candidate media item found during scanning
public struct CandidateMediaItem: Codable, Equatable, Hashable {
    /// Absolute path to the media file
    public let path: String
    
    /// File size in bytes
    public let size: Int64
    
    /// File modification date (ISO-8601)
    public let modificationDate: String
    
    /// File name
    public let fileName: String
    
    /// Creates a new CandidateMediaItem
    ///
    /// - Parameters:
    ///   - path: Absolute path to the file
    ///   - size: File size in bytes
    ///   - modificationDate: ISO-8601 modification date
    ///   - fileName: File name
    public init(
        path: String,
        size: Int64,
        modificationDate: String,
        fileName: String
    ) {
        self.path = path
        self.size = size
        self.modificationDate = modificationDate
        self.fileName = fileName
    }
}

/// Errors that can occur during scanning
public enum SourceScanningError: Error, LocalizedError {
    case sourceInaccessible(String)
    case scanningFailed(String, Error)
    
    public var errorDescription: String? {
        switch self {
        case .sourceInaccessible(let path):
            return "Source is inaccessible: \(path)"
        case .scanningFailed(let path, let error):
            return "Scanning failed at \(path): \(error.localizedDescription)"
        }
    }
}

/// Media file format identifiers
/// 
/// **Single Source of Truth**: This struct contains the authoritative extension sets
/// for image and video file classification. Both scan filtering (Task 4) and statistics
/// computation (Task 7) MUST reference these extension sets to ensure consistency.
/// No duplicate classification logic should exist elsewhere in the codebase.
public struct MediaFileFormat {
    /// Supported image file extensions (lowercase, case-insensitive matching)
    public static let imageExtensions: Set<String> = [
        "jpg", "jpeg",
        "png",
        "heic", "heif",
        "tiff", "tif",
        "gif",
        "webp",
        "cr2", "nef", "arw", "dng", "raf", "orf", "rw2" // RAW formats
    ]
    
    /// Supported video file extensions (lowercase, case-insensitive matching)
    public static let videoExtensions: Set<String> = [
        "mov",
        "mp4", "m4v",
        "avi",
        "mkv",
        "mpg", "mpeg"
    ]
    
    /// All supported media extensions
    public static var allExtensions: Set<String> {
        return imageExtensions.union(videoExtensions)
    }
    
    /// Checks if a file extension indicates a media file
    ///
    /// - Parameter fileExtension: File extension (with or without leading dot)
    /// - Returns: `true` if extension indicates a media file
    public static func isMediaFile(extension fileExtension: String) -> Bool {
        let ext = fileExtension.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return allExtensions.contains(ext)
    }
    
    /// Checks if a file path indicates a media file
    ///
    /// - Parameter path: File path
    /// - Returns: `true` if path indicates a media file
    public static func isMediaFile(path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        guard let ext = url.pathExtension.isEmpty ? nil : url.pathExtension else {
            return false
        }
        return isMediaFile(extension: ext)
    }
    
    /// Checks if a file extension indicates an image file
    ///
    /// - Parameter fileExtension: File extension (with or without leading dot)
    /// - Returns: `true` if extension indicates an image file
    public static func isImageFile(extension fileExtension: String) -> Bool {
        let ext = fileExtension.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return imageExtensions.contains(ext)
    }
    
    /// Checks if a file extension indicates a video file
    ///
    /// - Parameter fileExtension: File extension (with or without leading dot)
    /// - Returns: `true` if extension indicates a video file
    public static func isVideoFile(extension fileExtension: String) -> Bool {
        let ext = fileExtension.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return videoExtensions.contains(ext)
    }
    
    /// Checks if a file path indicates an image file
    ///
    /// - Parameter path: File path
    /// - Returns: `true` if path indicates an image file
    public static func isImageFile(path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        guard let ext = url.pathExtension.isEmpty ? nil : url.pathExtension else {
            return false
        }
        return isImageFile(extension: ext)
    }
    
    /// Checks if a file path indicates a video file
    ///
    /// - Parameter path: File path
    /// - Returns: `true` if path indicates a video file
    public static func isVideoFile(path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        guard let ext = url.pathExtension.isEmpty ? nil : url.pathExtension else {
            return false
        }
        return isVideoFile(extension: ext)
    }
}

/// Scans Sources for media files
public struct SourceScanner {
    /// Scans a folder-based Source for media files
    ///
    /// - Parameter source: The Source to scan
    /// - Returns: Array of candidate media items found
    /// - Throws: `SourceScanningError` if scanning fails
    public static func scan(source: Source) throws -> [CandidateMediaItem] {
        guard source.type == .folder else {
            throw SourceScanningError.sourceInaccessible("Source type not supported: \(source.type.rawValue)")
        }
        
        // Validate source is accessible
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: source.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw SourceScanningError.sourceInaccessible(source.path)
        }
        
        var candidates: [CandidateMediaItem] = []
        let sourceURL = URL(fileURLWithPath: source.path)
        let mediaTypes = source.effectiveMediaTypes
        
        // Recursively scan directory
        try scanDirectory(
            at: sourceURL,
            fileManager: fileManager,
            mediaTypes: mediaTypes,
            candidates: &candidates
        )
        
        // Sort by path for deterministic results
        candidates.sort { $0.path < $1.path }
        
        return candidates
    }
    
    /// Recursively scans a directory for media files
    ///
    /// - Parameters:
    ///   - directoryURL: The directory URL to scan
    ///   - fileManager: File manager instance
    ///   - mediaTypes: Media types filter (images, videos, or both)
    ///   - candidates: Mutable array to append candidates to
    /// - Throws: Errors if scanning fails critically
    private static func scanDirectory(
        at directoryURL: URL,
        fileManager: FileManager,
        mediaTypes: SourceMediaTypes,
        candidates: inout [CandidateMediaItem]
    ) throws {
        let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        
        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles], // Skip hidden files for performance
            errorHandler: { url, error in
                // Handle individual file errors gracefully
                // Log but continue scanning
                return true // Continue enumeration
            }
        ) else {
            return
        }
        
        for case let fileURL as URL in enumerator {
            // Check if it's a media file by extension
            guard MediaFileFormat.isMediaFile(path: fileURL.path) else {
                continue
            }
            
            // Apply media type filtering based on Source configuration
            // Filter BEFORE adding to candidates (at scan stage, not post-filter)
            let fileExtension = fileURL.pathExtension
            let isImage = MediaFileFormat.isImageFile(extension: fileExtension)
            let isVideo = MediaFileFormat.isVideoFile(extension: fileExtension)
            
            switch mediaTypes {
            case .images:
                // Only include image files
                guard isImage else {
                    continue
                }
            case .videos:
                // Only include video files
                guard isVideo else {
                    continue
                }
            case .both:
                // Include both images and videos (no additional filtering)
                break
            }
            
            // Try to get file attributes
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                
                // Skip if not a regular file (e.g., directory, symlink to directory)
                guard resourceValues.isRegularFile == true else {
                    continue
                }
                
                // Extract metadata
                let size = resourceValues.fileSize ?? 0
                let modificationDate = resourceValues.contentModificationDate ?? Date()
                
                // Create candidate item
                let candidate = CandidateMediaItem(
                    path: fileURL.path,
                    size: Int64(size),
                    modificationDate: ISO8601DateFormatter().string(from: modificationDate),
                    fileName: fileURL.lastPathComponent
                )
                
                candidates.append(candidate)
            } catch {
                // Skip files that can't be read (locked, corrupted, etc.)
                // Continue scanning
                continue
            }
        }
    }
}
