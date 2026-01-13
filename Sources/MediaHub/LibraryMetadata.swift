//
//  LibraryMetadata.swift
//  MediaHub
//
//  Library metadata structure and serialization/deserialization
//

import Foundation

/// Library metadata structure representing a MediaHub library's identity and properties.
///
/// This structure stores essential information that makes a directory identifiable
/// as a MediaHub library and maintains library identity across moves and renames.
public struct LibraryMetadata: Codable, Equatable {
    /// Metadata format version (for schema evolution)
    public let version: String
    
    /// Unique identifier (UUID v4) that persists across moves and renames
    public let libraryId: String
    
    /// ISO-8601 timestamp of library creation
    public let createdAt: String
    
    /// MediaHub library version (for compatibility tracking)
    public let libraryVersion: String
    
    /// Absolute path to library root (may become stale after moves)
    public let rootPath: String
    
    /// Creates a new library metadata instance.
    ///
    /// - Parameters:
    ///   - libraryId: Unique identifier (UUID v4)
    ///   - rootPath: Absolute path to library root
    ///   - libraryVersion: MediaHub library version (defaults to "1.0")
    ///   - metadataVersion: Metadata format version (defaults to "1.0")
    public init(
        libraryId: String,
        rootPath: String,
        libraryVersion: String = "1.0",
        metadataVersion: String = "1.0"
    ) {
        self.version = metadataVersion
        self.libraryId = libraryId
        self.createdAt = ISO8601DateFormatter().string(from: Date())
        self.libraryVersion = libraryVersion
        self.rootPath = rootPath
    }
    
    /// Validates that the metadata structure is valid.
    ///
    /// - Returns: `true` if metadata is valid, `false` otherwise
    public func isValid() -> Bool {
        // Validate UUID format
        guard UUID(uuidString: libraryId) != nil else {
            return false
        }
        
        // Validate ISO-8601 timestamp
        let formatter = ISO8601DateFormatter()
        guard formatter.date(from: createdAt) != nil else {
            return false
        }
        
        // Validate paths are absolute
        guard rootPath.hasPrefix("/") else {
            return false
        }
        
        // Validate version strings are not empty
        guard !version.isEmpty && !libraryVersion.isEmpty else {
            return false
        }
        
        return true
    }
}

/// Errors that can occur during metadata serialization/deserialization
public enum LibraryMetadataError: Error, LocalizedError {
    case invalidJSON
    case missingRequiredField(String)
    case invalidUUID(String)
    case invalidTimestamp(String)
    case invalidPath(String)
    case fileNotFound
    case permissionDenied
    case encodingError(Error)
    case decodingError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Invalid JSON format"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .invalidUUID(let uuid):
            return "Invalid UUID format: \(uuid)"
        case .invalidTimestamp(let timestamp):
            return "Invalid timestamp format: \(timestamp)"
        case .invalidPath(let path):
            return "Invalid path: \(path)"
        case .fileNotFound:
            return "Metadata file not found"
        case .permissionDenied:
            return "Permission denied accessing metadata file"
        case .encodingError(let error):
            return "Encoding error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        }
    }
}

/// Handles serialization and deserialization of library metadata.
public struct LibraryMetadataSerializer {
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
    
    /// Serializes library metadata to JSON data.
    ///
    /// - Parameter metadata: The metadata to serialize
    /// - Returns: JSON data representation
    /// - Throws: `LibraryMetadataError` if serialization fails
    public static func serialize(_ metadata: LibraryMetadata) throws -> Data {
        do {
            return try encoder.encode(metadata)
        } catch {
            throw LibraryMetadataError.encodingError(error)
        }
    }
    
    /// Deserializes library metadata from JSON data.
    ///
    /// - Parameter data: JSON data to deserialize
    /// - Returns: Deserialized metadata
    /// - Throws: `LibraryMetadataError` if deserialization fails or data is invalid
    public static func deserialize(_ data: Data) throws -> LibraryMetadata {
        do {
            let metadata = try decoder.decode(LibraryMetadata.self, from: data)
            
            // Validate deserialized metadata
            guard metadata.isValid() else {
                throw LibraryMetadataError.invalidJSON
            }
            
            return metadata
        } catch let error as LibraryMetadataError {
            throw error
        } catch {
            throw LibraryMetadataError.decodingError(error)
        }
    }
    
    /// Writes library metadata to a file.
    ///
    /// - Parameters:
    ///   - metadata: The metadata to write
    ///   - fileURL: The file URL where metadata should be written
    /// - Throws: `LibraryMetadataError` if writing fails
    public static func write(_ metadata: LibraryMetadata, to fileURL: URL) throws {
        let data = try serialize(metadata)
        
        do {
            // Create directory if it doesn't exist
            let directoryURL = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
            
            // Write metadata file
            try data.write(to: fileURL, options: .atomic)
        } catch let error as LibraryMetadataError {
            throw error
        } catch {
            if (error as NSError).code == NSFileWriteNoPermissionError {
                throw LibraryMetadataError.permissionDenied
            }
            throw LibraryMetadataError.encodingError(error)
        }
    }
    
    /// Reads library metadata from a file.
    ///
    /// - Parameter fileURL: The file URL to read from
    /// - Returns: Deserialized metadata
    /// - Throws: `LibraryMetadataError` if reading fails
    public static func read(from fileURL: URL) throws -> LibraryMetadata {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw LibraryMetadataError.fileNotFound
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            return try deserialize(data)
        } catch let error as LibraryMetadataError {
            throw error
        } catch {
            if (error as NSError).code == NSFileReadNoPermissionError {
                throw LibraryMetadataError.permissionDenied
            }
            throw LibraryMetadataError.decodingError(error)
        }
    }
}
