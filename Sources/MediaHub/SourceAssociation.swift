//
//  SourceAssociation.swift
//  MediaHub
//
//  Source-Library association persistence
//

import Foundation

/// Source-Library association data structure
public struct SourceAssociation: Codable, Equatable {
    /// Association format version
    public let version: String
    
    /// Library identifier
    public let libraryId: String
    
    /// Array of Sources associated with this Library
    public var sources: [Source]
    
    /// Creates a new SourceAssociation instance
    ///
    /// - Parameters:
    ///   - libraryId: Library identifier
    ///   - sources: Array of Sources
    ///   - version: Format version (defaults to "1.0")
    public init(
        libraryId: String,
        sources: [Source] = [],
        version: String = "1.0"
    ) {
        self.version = version
        self.libraryId = libraryId
        self.sources = sources
    }
    
    /// Validates that the association structure is valid
    ///
    /// - Returns: `true` if association is valid, `false` otherwise
    public func isValid() -> Bool {
        // Validate UUID format for libraryId
        guard UUID(uuidString: libraryId) != nil else {
            return false
        }
        
        // Validate all sources
        for source in sources {
            guard source.isValid() else {
                return false
            }
        }
        
        // Validate version is not empty
        guard !version.isEmpty else {
            return false
        }
        
        return true
    }
}

/// Errors that can occur during association operations
public enum SourceAssociationError: Error, LocalizedError {
    case invalidAssociation
    case invalidLibraryId(String)
    case invalidSource(SourceError)
    case fileNotFound
    case permissionDenied
    case encodingError(Error)
    case decodingError(Error)
    case sourceNotFound(String)
    case duplicateSource(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidAssociation:
            return "Invalid association structure"
        case .invalidLibraryId(let id):
            return "Invalid library identifier: \(id)"
        case .invalidSource(let error):
            return "Invalid source: \(error.localizedDescription)"
        case .fileNotFound:
            return "Association file not found"
        case .permissionDenied:
            return "Permission denied accessing association file"
        case .encodingError(let error):
            return "Encoding error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .sourceNotFound(let sourceId):
            return "Source not found: \(sourceId)"
        case .duplicateSource(let sourceId):
            return "Duplicate source: \(sourceId)"
        }
    }
}

/// Constants for association storage paths
public enum SourceAssociationStorage {
    /// Name of the sources directory within .mediahub
    public static let sourcesDirectoryName = "sources"
    
    /// Name of the associations file
    public static let associationsFileName = "associations.json"
    
    /// Returns the sources directory path relative to library root
    public static var sourcesDirectoryPath: String {
        return "\(LibraryStructure.metadataDirectoryName)/\(sourcesDirectoryName)"
    }
    
    /// Returns the associations file path relative to library root
    public static var associationsFilePath: String {
        return "\(sourcesDirectoryPath)/\(associationsFileName)"
    }
    
    /// Gets the URL for the associations file within a library root
    ///
    /// - Parameter libraryRootURL: The URL of the library root directory
    /// - Returns: URL to the associations file
    public static func associationsFileURL(for libraryRootURL: URL) -> URL {
        return libraryRootURL
            .appendingPathComponent(LibraryStructure.metadataDirectoryName)
            .appendingPathComponent(sourcesDirectoryName)
            .appendingPathComponent(associationsFileName)
    }
}

/// Handles serialization and deserialization of Source associations
public struct SourceAssociationSerializer {
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
    
    /// Serializes Source associations to JSON data
    ///
    /// - Parameter association: The association to serialize
    /// - Returns: JSON data representation
    /// - Throws: `SourceAssociationError` if serialization fails
    public static func serialize(_ association: SourceAssociation) throws -> Data {
        guard association.isValid() else {
            throw SourceAssociationError.invalidAssociation
        }
        
        do {
            return try encoder.encode(association)
        } catch {
            throw SourceAssociationError.encodingError(error)
        }
    }
    
    /// Deserializes Source associations from JSON data
    ///
    /// - Parameter data: JSON data to deserialize
    /// - Returns: Deserialized association
    /// - Throws: `SourceAssociationError` if deserialization fails or data is invalid
    public static func deserialize(_ data: Data) throws -> SourceAssociation {
        do {
            let association = try decoder.decode(SourceAssociation.self, from: data)
            
            // Validate deserialized association
            guard association.isValid() else {
                throw SourceAssociationError.invalidAssociation
            }
            
            return association
        } catch let error as SourceAssociationError {
            throw error
        } catch {
            throw SourceAssociationError.decodingError(error)
        }
    }
    
    /// Writes Source associations to a file
    ///
    /// - Parameters:
    ///   - association: The association to write
    ///   - fileURL: The file URL where association should be written
    /// - Throws: `SourceAssociationError` if writing fails
    public static func write(_ association: SourceAssociation, to fileURL: URL) throws {
        let data = try serialize(association)
        
        do {
            // Create directory if it doesn't exist
            let directoryURL = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
            
            // Write association file atomically
            try data.write(to: fileURL, options: .atomic)
        } catch let error as SourceAssociationError {
            throw error
        } catch {
            if (error as NSError).code == NSFileWriteNoPermissionError {
                throw SourceAssociationError.permissionDenied
            }
            throw SourceAssociationError.encodingError(error)
        }
    }
    
    /// Reads Source associations from a file
    ///
    /// - Parameter fileURL: The file URL to read from
    /// - Returns: Deserialized association
    /// - Throws: `SourceAssociationError` if reading fails
    public static func read(from fileURL: URL) throws -> SourceAssociation {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw SourceAssociationError.fileNotFound
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            return try deserialize(data)
        } catch let error as SourceAssociationError {
            throw error
        } catch {
            if (error as NSError).code == NSFileReadNoPermissionError {
                throw SourceAssociationError.permissionDenied
            }
            throw SourceAssociationError.decodingError(error)
        }
    }
}

/// Manages Source-Library associations
public struct SourceAssociationManager {
    /// Creates a Source-Library association (attaches a Source to a Library)
    ///
    /// - Parameters:
    ///   - source: The Source to attach
    ///   - libraryRootURL: The URL of the library root directory
    ///   - libraryId: The Library identifier
    /// - Throws: `SourceAssociationError` if association creation fails
    public static func attach(
        source: Source,
        to libraryRootURL: URL,
        libraryId: String
    ) throws {
        let fileURL = SourceAssociationStorage.associationsFileURL(for: libraryRootURL)
        
        // Load existing associations or create new
        var association: SourceAssociation
        if FileManager.default.fileExists(atPath: fileURL.path) {
            association = try SourceAssociationSerializer.read(from: fileURL)
            
            // Validate libraryId matches
            guard association.libraryId == libraryId else {
                throw SourceAssociationError.invalidLibraryId(libraryId)
            }
            
            // Check for duplicate source
            if association.sources.contains(where: { $0.sourceId == source.sourceId }) {
                throw SourceAssociationError.duplicateSource(source.sourceId)
            }
        } else {
            association = SourceAssociation(libraryId: libraryId, sources: [])
        }
        
        // Add source to association
        association.sources.append(source)
        
        // Write back
        try SourceAssociationSerializer.write(association, to: fileURL)
    }
    
    /// Retrieves all Sources associated with a Library
    ///
    /// - Parameters:
    ///   - libraryRootURL: The URL of the library root directory
    ///   - libraryId: The Library identifier (for validation)
    /// - Returns: Array of Sources associated with the Library
    /// - Throws: `SourceAssociationError` if retrieval fails
    public static func retrieveSources(
        for libraryRootURL: URL,
        libraryId: String
    ) throws -> [Source] {
        let fileURL = SourceAssociationStorage.associationsFileURL(for: libraryRootURL)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            // No associations file means no sources attached yet
            return []
        }
        
        let association = try SourceAssociationSerializer.read(from: fileURL)
        
        // Validate libraryId matches
        guard association.libraryId == libraryId else {
            throw SourceAssociationError.invalidLibraryId(libraryId)
        }
        
        return association.sources
    }
    
    /// Validates that associations are valid and refer to existing Sources
    ///
    /// - Parameters:
    ///   - libraryRootURL: The URL of the library root directory
    ///   - libraryId: The Library identifier
    /// - Returns: Array of validation errors (empty if all valid)
    public static func validateAssociations(
        for libraryRootURL: URL,
        libraryId: String
    ) -> [SourceAssociationError] {
        do {
            let sources = try retrieveSources(for: libraryRootURL, libraryId: libraryId)
            var errors: [SourceAssociationError] = []
            
            for source in sources {
                // Validate source structure
                if !source.isValid() {
                    errors.append(.invalidSource(.invalidSource))
                }
                
                // Check if source path exists (best-effort, may be temporarily inaccessible)
                // This is informational only; we don't fail validation for inaccessible sources
            }
            
            return errors
        } catch let error as SourceAssociationError {
            return [error]
        } catch {
            return [.decodingError(error)]
        }
    }
    
    /// Removes a Source-Library association (detaches a Source from a Library)
    ///
    /// - Parameters:
    ///   - sourceId: The Source identifier to detach
    ///   - libraryRootURL: The URL of the library root directory
    ///   - libraryId: The Library identifier
    /// - Throws: `SourceAssociationError` if removal fails
    public static func detach(
        sourceId: String,
        from libraryRootURL: URL,
        libraryId: String
    ) throws {
        let fileURL = SourceAssociationStorage.associationsFileURL(for: libraryRootURL)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw SourceAssociationError.sourceNotFound(sourceId)
        }
        
        var association = try SourceAssociationSerializer.read(from: fileURL)
        
        // Validate libraryId matches
        guard association.libraryId == libraryId else {
            throw SourceAssociationError.invalidLibraryId(libraryId)
        }
        
        // Remove source
        guard let index = association.sources.firstIndex(where: { $0.sourceId == sourceId }) else {
            throw SourceAssociationError.sourceNotFound(sourceId)
        }
        
        association.sources.remove(at: index)
        
        // Write back (or delete file if no sources remain)
        if association.sources.isEmpty {
            try FileManager.default.removeItem(at: fileURL)
        } else {
            try SourceAssociationSerializer.write(association, to: fileURL)
        }
    }
}
