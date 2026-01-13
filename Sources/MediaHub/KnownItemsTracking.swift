//
//  KnownItemsTracking.swift
//  MediaHub
//
//  Known items tracking for imported items (path-based, source-scoped)
//

import Foundation

/// Known item entry
public struct KnownItem: Codable, Equatable, Hashable {
    /// Absolute source path (normalized)
    public let path: String
    
    /// ISO-8601 timestamp when item was imported
    public let importedAt: String
    
    /// Relative destination path in Library
    public let destinationPath: String
    
    /// Creates a new KnownItem
    ///
    /// - Parameters:
    ///   - path: Absolute source path
    ///   - importedAt: ISO-8601 import timestamp
    ///   - destinationPath: Relative destination path
    public init(
        path: String,
        importedAt: String,
        destinationPath: String
    ) {
        self.path = path
        self.importedAt = importedAt
        self.destinationPath = destinationPath
    }
}

/// Known items tracking data structure
public struct KnownItemsTracking: Codable, Equatable {
    /// Format version
    public let version: String
    
    /// Source identifier
    public let sourceId: String
    
    /// Array of known items
    public let items: [KnownItem]
    
    /// ISO-8601 timestamp of last update
    public let lastUpdated: String
    
    /// Creates a new KnownItemsTracking
    ///
    /// - Parameters:
    ///   - sourceId: Source identifier
    ///   - items: Array of known items
    ///   - lastUpdated: ISO-8601 timestamp (defaults to now)
    ///   - version: Format version (defaults to "1.0")
    public init(
        sourceId: String,
        items: [KnownItem],
        lastUpdated: String? = nil,
        version: String = "1.0"
    ) {
        self.version = version
        self.sourceId = sourceId
        self.items = items
        self.lastUpdated = lastUpdated ?? ISO8601DateFormatter().string(from: Date())
    }
    
    /// Validates that the tracking structure is valid
    ///
    /// - Returns: `true` if valid, `false` otherwise
    public func isValid() -> Bool {
        // Validate UUID format
        guard UUID(uuidString: sourceId) != nil else {
            return false
        }
        
        // Validate ISO-8601 timestamp
        let formatter = ISO8601DateFormatter()
        guard formatter.date(from: lastUpdated) != nil else {
            return false
        }
        
        // Validate all items have valid timestamps
        for item in items {
            guard formatter.date(from: item.importedAt) != nil else {
                return false
            }
        }
        
        return true
    }
}

/// Errors that can occur during known items tracking operations
public enum KnownItemsTrackingError: Error, LocalizedError {
    case invalidTracking
    case fileNotFound
    case permissionDenied
    case encodingError(Error)
    case decodingError(Error)
    case sourceMismatch(String, String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidTracking:
            return "Invalid known items tracking structure"
        case .fileNotFound:
            return "Known items tracking file not found"
        case .permissionDenied:
            return "Permission denied accessing known items tracking file"
        case .encodingError(let error):
            return "Encoding error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .sourceMismatch(let expected, let actual):
            return "Source ID mismatch: expected \(expected), got \(actual)"
        }
    }
}

/// Constants for known items tracking storage paths
public enum KnownItemsTrackingStorage {
    /// Name of the known items tracking file
    public static let knownItemsFileName = "known-items.json"
    
    /// Returns the known items tracking file path for a Source
    ///
    /// - Parameter sourceId: Source identifier
    /// - Returns: Path relative to library root
    public static func knownItemsFilePath(for sourceId: String) -> String {
        return "\(SourceAssociationStorage.sourcesDirectoryPath)/\(sourceId)/\(knownItemsFileName)"
    }
    
    /// Gets the URL for a known items tracking file
    ///
    /// - Parameters:
    ///   - libraryRootURL: Library root URL
    ///   - sourceId: Source identifier
    /// - Returns: URL to the tracking file
    public static func knownItemsFileURL(
        for libraryRootURL: URL,
        sourceId: String
    ) -> URL {
        return libraryRootURL
            .appendingPathComponent(LibraryStructure.metadataDirectoryName)
            .appendingPathComponent(SourceAssociationStorage.sourcesDirectoryName)
            .appendingPathComponent(sourceId)
            .appendingPathComponent(knownItemsFileName)
    }
}

/// Handles serialization and deserialization of known items tracking
public struct KnownItemsTrackingSerializer {
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    /// Serializes known items tracking to JSON data
    ///
    /// - Parameter tracking: The tracking to serialize
    /// - Returns: JSON data representation
    /// - Throws: `KnownItemsTrackingError` if serialization fails
    public static func serialize(_ tracking: KnownItemsTracking) throws -> Data {
        guard tracking.isValid() else {
            throw KnownItemsTrackingError.invalidTracking
        }
        
        do {
            return try encoder.encode(tracking)
        } catch {
            throw KnownItemsTrackingError.encodingError(error)
        }
    }
    
    /// Deserializes known items tracking from JSON data
    ///
    /// - Parameter data: JSON data to deserialize
    /// - Returns: Deserialized tracking
    /// - Throws: `KnownItemsTrackingError` if deserialization fails
    public static func deserialize(_ data: Data) throws -> KnownItemsTracking {
        do {
            let tracking = try decoder.decode(KnownItemsTracking.self, from: data)
            
            // Validate deserialized tracking
            guard tracking.isValid() else {
                throw KnownItemsTrackingError.invalidTracking
            }
            
            return tracking
        } catch let error as KnownItemsTrackingError {
            throw error
        } catch {
            throw KnownItemsTrackingError.decodingError(error)
        }
    }
    
    /// Writes known items tracking to a file
    ///
    /// - Parameters:
    ///   - tracking: The tracking to write
    ///   - fileURL: The file URL where tracking should be written
    /// - Throws: `KnownItemsTrackingError` if writing fails
    public static func write(_ tracking: KnownItemsTracking, to fileURL: URL) throws {
        let data = try serialize(tracking)
        
        do {
            // Create directory if it doesn't exist
            let directoryURL = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
            
            // Write tracking file atomically
            try data.write(to: fileURL, options: .atomic)
        } catch let error as KnownItemsTrackingError {
            throw error
        } catch {
            if (error as NSError).code == NSFileWriteNoPermissionError {
                throw KnownItemsTrackingError.permissionDenied
            }
            throw KnownItemsTrackingError.encodingError(error)
        }
    }
    
    /// Reads known items tracking from a file
    ///
    /// - Parameter fileURL: The file URL to read from
    /// - Returns: Deserialized tracking, or nil if file doesn't exist
    /// - Throws: `KnownItemsTrackingError` if reading fails
    public static func read(from fileURL: URL) throws -> KnownItemsTracking? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            return try deserialize(data)
        } catch let error as KnownItemsTrackingError {
            throw error
        } catch {
            if (error as NSError).code == NSFileReadNoPermissionError {
                throw KnownItemsTrackingError.permissionDenied
            }
            throw KnownItemsTrackingError.decodingError(error)
        }
    }
}

/// Manages known items tracking for Sources
public struct KnownItemsTracker {
    /// Records imported items in known-items tracking
    ///
    /// - Parameters:
    ///   - items: Array of imported items to record
    ///   - sourceId: Source identifier
    ///   - libraryRootURL: Library root URL
    ///   - importedAt: ISO-8601 timestamp of import (defaults to now)
    /// - Throws: `KnownItemsTrackingError` if recording fails
    public static func recordImportedItems(
        _ items: [(path: String, destinationPath: String)],
        sourceId: String,
        libraryRootURL: URL,
        importedAt: String? = nil
    ) throws {
        let importTimestamp = importedAt ?? ISO8601DateFormatter().string(from: Date())
        
        // Load existing tracking or create new
        let trackingFileURL = KnownItemsTrackingStorage.knownItemsFileURL(
            for: libraryRootURL,
            sourceId: sourceId
        )
        
        let existingTracking = try KnownItemsTrackingSerializer.read(from: trackingFileURL)
        
        // Validate source ID matches
        if let existing = existingTracking, existing.sourceId != sourceId {
            throw KnownItemsTrackingError.sourceMismatch(sourceId, existing.sourceId)
        }
        
        // Create new known items
        let newKnownItems = items.map { item in
            KnownItem(
                path: normalizePath(item.path),
                importedAt: importTimestamp,
                destinationPath: item.destinationPath
            )
        }
        
        // Merge with existing items (append-only, avoid duplicates)
        let existingPaths = Set(existingTracking?.items.map { $0.path } ?? [])
        let itemsToAdd = newKnownItems.filter { !existingPaths.contains($0.path) }
        
        let allItems = (existingTracking?.items ?? []) + itemsToAdd
        
        // Create updated tracking
        let updatedTracking = KnownItemsTracking(
            sourceId: sourceId,
            items: allItems,
            lastUpdated: importTimestamp
        )
        
        // Write updated tracking
        try KnownItemsTrackingSerializer.write(updatedTracking, to: trackingFileURL)
    }
    
    /// Queries known items for a Source
    ///
    /// - Parameters:
    ///   - sourceId: Source identifier
    ///   - libraryRootURL: Library root URL
    /// - Returns: Set of normalized paths of known items
    /// - Throws: `KnownItemsTrackingError` if query fails
    public static func queryKnownItems(
        sourceId: String,
        libraryRootURL: URL
    ) throws -> Set<String> {
        let trackingFileURL = KnownItemsTrackingStorage.knownItemsFileURL(
            for: libraryRootURL,
            sourceId: sourceId
        )
        
        guard let tracking = try KnownItemsTrackingSerializer.read(from: trackingFileURL) else {
            return Set() // No tracking file means no known items
        }
        
        // Validate source ID matches
        guard tracking.sourceId == sourceId else {
            throw KnownItemsTrackingError.sourceMismatch(sourceId, tracking.sourceId)
        }
        
        // Return set of normalized paths
        return Set(tracking.items.map { $0.path })
    }
    
    /// Normalizes a path for consistent comparison
    ///
    /// - Parameter path: Path to normalize
    /// - Returns: Normalized path (absolute, symlinks resolved)
    private static func normalizePath(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        return url.resolvingSymlinksInPath().path
    }
}
