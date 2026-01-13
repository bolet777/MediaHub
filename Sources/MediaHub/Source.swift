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
    
    /// Creates a new Source instance
    ///
    /// - Parameters:
    ///   - sourceId: Unique identifier (UUID v4)
    ///   - type: Source type
    ///   - path: Absolute path to source location
    ///   - attachedAt: ISO-8601 timestamp of attachment (defaults to now)
    ///   - lastDetectedAt: Optional timestamp of last detection
    public init(
        sourceId: String,
        type: SourceType,
        path: String,
        attachedAt: String? = nil,
        lastDetectedAt: String? = nil
    ) {
        self.sourceId = sourceId
        self.type = type
        self.path = path
        self.attachedAt = attachedAt ?? ISO8601DateFormatter().string(from: Date())
        self.lastDetectedAt = lastDetectedAt
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
