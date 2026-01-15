//
//  Source.swift
//  MediaHub
//
//  Source model and identity for MediaHub libraries
//

import Foundation

/// Source type enumeration
public enum SourceType: String, Codable {
    case folder
    // Future types: device, photosApp, etc.
}

/// Source media types enumeration
///
/// **Invalid Value Handling (Option 2)**: Invalid raw string values are automatically rejected
/// during Codable decoding (enum safety). This means corrupted association files with invalid
/// `mediaTypes` values will cause a decoding error rather than silently falling back to "both".
/// This is the chosen approach for Slice 10 (Option 2: error, not Option 1: fallback with warning).
/// Invalid values MUST NOT cause silent failures or undefined behavior.
public enum SourceMediaTypes: String, Codable {
    case images
    case videos
    case both
}

/// Source data structure representing an external location containing media files
public struct Source: Codable, Equatable {
    /// Unique identifier that persists across application restarts
    public let sourceId: String
    
    /// Source type (folder-based for P1)
    public let type: SourceType
    
    /// Absolute path to the source location
    public let path: String
    
    /// ISO-8601 timestamp when source was attached to library
    public let attachedAt: String
    
    /// Optional: ISO-8601 timestamp of last successful detection run
    public let lastDetectedAt: String?
    
    /// Optional: Media types filter (images, videos, or both)
    /// When nil/absent, defaults to `.both` for backward compatibility
    public let mediaTypes: SourceMediaTypes?
    
    /// Computed property that returns the effective media types (defaults to `.both` when nil)
    public var effectiveMediaTypes: SourceMediaTypes {
        return mediaTypes ?? .both
    }
    
    /// Creates a new Source instance
    ///
    /// - Parameters:
    ///   - sourceId: Unique identifier (UUID v4)
    ///   - type: Source type
    ///   - path: Absolute path to source location
    ///   - attachedAt: ISO-8601 timestamp of attachment (defaults to now)
    ///   - lastDetectedAt: Optional timestamp of last detection
    ///   - mediaTypes: Optional media types filter (defaults to nil, which means `.both`)
    public init(
        sourceId: String,
        type: SourceType,
        path: String,
        attachedAt: String? = nil,
        lastDetectedAt: String? = nil,
        mediaTypes: SourceMediaTypes? = nil
    ) {
        self.sourceId = sourceId
        self.type = type
        self.path = path
        self.attachedAt = attachedAt ?? ISO8601DateFormatter().string(from: Date())
        self.lastDetectedAt = lastDetectedAt
        self.mediaTypes = mediaTypes
    }
    
    /// Validates that the Source structure is valid
    ///
    /// - Returns: `true` if source is valid, `false` otherwise
    public func isValid() -> Bool {
        // Validate UUID format
        guard UUID(uuidString: sourceId) != nil else {
            return false
        }
        
        // Validate ISO-8601 timestamp
        let formatter = ISO8601DateFormatter()
        guard formatter.date(from: attachedAt) != nil else {
            return false
        }
        
        // Validate lastDetectedAt if present
        if let lastDetected = lastDetectedAt {
            guard formatter.date(from: lastDetected) != nil else {
                return false
            }
        }
        
        // Validate path is absolute
        guard path.hasPrefix("/") else {
            return false
        }
        
        return true
    }
}

/// Errors that can occur during source operations
public enum SourceError: Error, LocalizedError {
    case invalidSourceId(String)
    case invalidPath(String)
    case invalidTimestamp(String)
    case invalidSource
    
    public var errorDescription: String? {
        switch self {
        case .invalidSourceId(let id):
            return "Invalid source identifier: \(id)"
        case .invalidPath(let path):
            return "Invalid source path: \(path)"
        case .invalidTimestamp(let timestamp):
            return "Invalid timestamp: \(timestamp)"
        case .invalidSource:
            return "Source structure is invalid"
        }
    }
}
