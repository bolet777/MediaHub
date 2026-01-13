//
//  DestinationMapping.swift
//  MediaHub
//
//  Destination path mapping for imported files (Year/Month organization)
//

import Foundation

/// Errors that can occur during destination mapping
public enum DestinationMappingError: Error, LocalizedError {
    case invalidTimestamp
    case invalidPath
    case pathTooLong
    case mappingFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidTimestamp:
            return "Invalid timestamp for destination mapping"
        case .invalidPath:
            return "Invalid destination path"
        case .pathTooLong:
            return "Destination path exceeds filesystem limits"
        case .mappingFailed(let reason):
            return "Destination mapping failed: \(reason)"
        }
    }
}

/// Destination mapping result
public struct DestinationMappingResult {
    /// The destination path (relative to library root)
    public let relativePath: String
    
    /// The full destination URL
    public let destinationURL: URL
    
    /// Year/Month folder path (YYYY/MM)
    public let yearMonthPath: String
    
    /// Creates a new DestinationMappingResult
    ///
    /// - Parameters:
    ///   - relativePath: Path relative to library root
    ///   - destinationURL: Full destination URL
    ///   - yearMonthPath: Year/Month folder path
    public init(relativePath: String, destinationURL: URL, yearMonthPath: String) {
        self.relativePath = relativePath
        self.destinationURL = destinationURL
        self.yearMonthPath = yearMonthPath
    }
}

/// Maps candidate items to destination paths using Year/Month (YYYY/MM) organization
public struct DestinationMapper {
    /// Maps a candidate item to its destination path based on timestamp
    ///
    /// - Parameters:
    ///   - candidate: The candidate item to map
    ///   - timestamp: The timestamp to use for Year/Month organization
    ///   - libraryRootURL: The library root URL
    /// - Returns: DestinationMappingResult with destination path
    /// - Throws: `DestinationMappingError` if mapping fails
    public static func mapDestination(
        for candidate: CandidateMediaItem,
        timestamp: Date,
        libraryRootURL: URL
    ) throws -> DestinationMappingResult {
        // Generate Year/Month folder structure (YYYY/MM)
        let yearMonthPath = generateYearMonthPath(from: timestamp)
        
        // Sanitize filename (preserve original, handle invalid characters)
        let sanitizedFileName = sanitizeFileName(candidate.fileName)
        
        // Build relative path: YYYY/MM/filename.ext
        let relativePath = "\(yearMonthPath)/\(sanitizedFileName)"
        
        // Build full destination URL
        let destinationURL = libraryRootURL.appendingPathComponent(relativePath)
        
        return DestinationMappingResult(
            relativePath: relativePath,
            destinationURL: destinationURL,
            yearMonthPath: yearMonthPath
        )
    }
    
    /// Generates Year/Month folder path (YYYY/MM) from timestamp
    ///
    /// - Parameter timestamp: The timestamp to extract year/month from
    /// - Returns: Year/Month path string (e.g., "2026/01")
    public static func generateYearMonthPath(from timestamp: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: timestamp)
        
        guard let year = components.year,
              let month = components.month else {
            // Fallback to current date if components are invalid
            let now = Date()
            let fallbackComponents = calendar.dateComponents([.year, .month], from: now)
            let fallbackYear = fallbackComponents.year ?? 2026
            let fallbackMonth = fallbackComponents.month ?? 1
            return String(format: "%04d/%02d", fallbackYear, fallbackMonth)
        }
        
        // Format: YYYY/MM (zero-padded month)
        return String(format: "%04d/%02d", year, month)
    }
    
    /// Sanitizes filename to handle invalid filesystem characters
    ///
    /// - Parameter fileName: Original filename
    /// - Returns: Sanitized filename
    public static func sanitizeFileName(_ fileName: String) -> String {
        // Replace invalid characters with underscore
        // Invalid: / (path separator), \0 (null), and any characters that would break paths
        var sanitized = fileName
        
        // Replace path separators and null characters
        sanitized = sanitized.replacingOccurrences(of: "/", with: "_")
        sanitized = sanitized.replacingOccurrences(of: "\0", with: "_")
        
        // Remove any remaining invalid characters (control characters, etc.)
        let invalidCharacters = CharacterSet.controlCharacters
            .union(CharacterSet.illegalCharacters)
        sanitized = sanitized.components(separatedBy: invalidCharacters).joined(separator: "_")
        
        // Ensure filename is not empty
        if sanitized.isEmpty {
            sanitized = "unnamed"
        }
        
        return sanitized
    }
    
    /// Checks if destination path already exists (for collision detection)
    ///
    /// - Parameter destinationURL: The destination URL to check
    /// - Returns: `true` if path exists (file or directory), `false` otherwise
    public static func pathExists(at destinationURL: URL) -> Bool {
        return FileManager.default.fileExists(atPath: destinationURL.path)
    }
    
    /// Checks if destination path is a directory (vs. file)
    ///
    /// - Parameter destinationURL: The destination URL to check
    /// - Returns: `true` if path exists and is a directory, `false` otherwise
    public static func isDirectory(at destinationURL: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: destinationURL.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
}
