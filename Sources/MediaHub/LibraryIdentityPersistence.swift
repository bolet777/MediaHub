//
//  LibraryIdentityPersistence.swift
//  MediaHub
//
//  Library identity persistence across moves and renames
//

import Foundation

/// Errors related to library identity persistence
public enum LibraryIdentityError: Error, LocalizedError {
    case identifierNotFound
    case pathNotFound
    case duplicateIdentifier(String)
    case pathUpdateFailed(Error)
    case invalidIdentifier
    
    public var errorDescription: String? {
        switch self {
        case .identifierNotFound:
            return "Library identifier not found"
        case .pathNotFound:
            return "Library path not found"
        case .duplicateIdentifier(let identifier):
            return "Duplicate library identifier found: \(identifier)"
        case .pathUpdateFailed(let error):
            return "Failed to update library path: \(error.localizedDescription)"
        case .invalidIdentifier:
            return "Invalid library identifier"
        }
    }
}

/// Detects when a library has been moved to a new location
public struct LibraryPathChangeDetector {
    /// Detects if a library path has changed by comparing metadata with actual location.
    ///
    /// - Parameter metadata: The library metadata
    /// - Returns: `true` if path has changed, `false` otherwise
    public static func detectPathChange(in metadata: LibraryMetadata) -> Bool {
        let fileManager = FileManager.default
        
        // Check if metadata rootPath still contains a valid library
        let metadataPathURL = URL(fileURLWithPath: metadata.rootPath)
        
        // If path doesn't exist, it may have moved
        guard fileManager.fileExists(atPath: metadata.rootPath) else {
            return true
        }
        
        // Check if it's still a valid library at that path
        guard LibraryStructureValidator.isLibraryStructure(at: metadataPathURL) else {
            return true
        }
        
        // Verify the identifier matches
        do {
            let currentMetadata = try LibraryMetadataReader.readMetadata(from: metadata.rootPath)
            return currentMetadata.libraryId != metadata.libraryId
        } catch {
            // Can't read metadata - assume path changed
            return true
        }
    }
    
    /// Detects if a library at a given path matches a specific identifier.
    ///
    /// - Parameters:
    ///   - path: The path to check
    ///   - identifier: The expected identifier
    /// - Returns: `true` if path contains library with matching identifier, `false` otherwise
    public static func pathMatchesIdentifier(path: String, identifier: String) -> Bool {
        guard LibraryPathDetector.detect(at: path) else {
            return false
        }
        
        do {
            let metadata = try LibraryMetadataReader.readMetadata(from: path)
            return metadata.libraryId == identifier
        } catch {
            return false
        }
    }
}

/// Updates internal references when library paths change
public struct LibraryPathReferenceUpdater {
    /// Updates the library registry when a path change is detected.
    ///
    /// - Parameters:
    ///   - registry: The library registry
    ///   - identifier: The library identifier
    ///   - newPath: The new library path
    public static func updatePath(
        in registry: LibraryRegistry,
        identifier: String,
        newPath: String
    ) {
        registry.register(identifier: identifier, path: newPath)
    }
    
    /// Updates library metadata rootPath (optional - may remain stale).
    ///
    /// Note: This updates the metadata file on disk. For Slice 1, we may choose
    /// to keep metadata.rootPath stale and rely on identifier-based lookup.
    ///
    /// - Parameters:
    ///   - libraryRootPath: The current library root path
    ///   - newPath: The new path (if library was moved)
    /// - Throws: `LibraryIdentityError` if update fails
    public static func updateMetadataPath(
        libraryRootPath: String,
        newPath: String
    ) throws {
        // For Slice 1, we keep metadata.rootPath as-is
        // The identifier is the source of truth, not the path
        // This allows libraries to be moved without requiring metadata updates
        
        // If we wanted to update metadata, we would:
        // 1. Read current metadata
        // 2. Create new metadata with updated rootPath
        // 3. Write updated metadata
        
        // For now, we skip this to keep metadata immutable
    }
}

/// Locates libraries by identifier even when path is unknown
public struct LibraryIdentifierLocator {
    private let registry: LibraryRegistry
    private let knownLocations: [String]
    
    /// Creates a new identifier locator.
    ///
    /// - Parameters:
    ///   - registry: The library registry
    ///   - knownLocations: Known locations to search (previously opened, user-specified)
    public init(registry: LibraryRegistry, knownLocations: [String] = []) {
        self.registry = registry
        self.knownLocations = knownLocations
    }
    
    /// Locates a library by identifier.
    ///
    /// Search order:
    /// 1. Runtime registry
    /// 2. Known locations
    /// 3. Returns nil if not found
    ///
    /// - Parameter identifier: The library identifier
    /// - Returns: The library path if found, `nil` otherwise
    public func locate(identifier: String) -> String? {
        // Step 1: Check runtime registry
        if let path = registry.path(for: identifier) {
            // Verify library still exists at that path
            if LibraryPathChangeDetector.pathMatchesIdentifier(path: path, identifier: identifier) {
                return path
            } else {
                // Path is stale - remove from registry
                registry.unregister(identifier: identifier)
            }
        }
        
        // Step 2: Search known locations
        for location in knownLocations {
            if LibraryPathChangeDetector.pathMatchesIdentifier(path: location, identifier: identifier) {
                // Found it - register in registry
                registry.register(identifier: identifier, path: location)
                return location
            }
        }
        
        // Not found
        return nil
    }
}

/// Detects and handles duplicate library identifiers
public struct DuplicateIdentifierDetector {
    /// Detects if multiple libraries have the same identifier.
    ///
    /// - Parameters:
    ///   - identifier: The identifier to check
    ///   - knownPaths: Known library paths to check
    /// - Returns: Array of paths containing libraries with the identifier
    public static func detectDuplicates(
        identifier: String,
        in knownPaths: [String]
    ) -> [String] {
        var matchingPaths: [String] = []
        
        for path in knownPaths {
            if LibraryPathChangeDetector.pathMatchesIdentifier(path: path, identifier: identifier) {
                matchingPaths.append(path)
            }
        }
        
        return matchingPaths
    }
    
    /// Resolves duplicate identifiers by assigning a new identifier to one library.
    ///
    /// - Parameters:
    ///   - libraryPath: The path to the library that should get a new identifier
    ///   - completion: Called with the new identifier or error
    public static func resolveDuplicate(
        at libraryPath: String,
        completion: @escaping (Result<String, LibraryIdentityError>) -> Void
    ) {
        let libraryRootURL = URL(fileURLWithPath: libraryPath)
        
        // Read current metadata
        guard let currentMetadata = try? LibraryMetadataReader.readMetadata(from: libraryPath) else {
            completion(.failure(.pathNotFound))
            return
        }
        
        // Generate new identifier
        let newIdentifier = LibraryIdentifierGenerator.generate()
        
        // Create new metadata with new identifier
        let newMetadata = LibraryMetadata(
            libraryId: newIdentifier,
            rootPath: libraryRootURL.path,
            libraryVersion: currentMetadata.libraryVersion,
            metadataVersion: currentMetadata.version
        )
        
        // Write updated metadata
        let metadataFileURL = LibraryStructureCreator.metadataFileURL(for: libraryRootURL)
        do {
            try LibraryMetadataSerializer.write(newMetadata, to: metadataFileURL)
            completion(.success(newIdentifier))
        } catch {
            completion(.failure(.pathUpdateFailed(error)))
        }
    }
}

/// Validates that library identity persists across moves
public struct LibraryIdentityPersistenceValidator {
    /// Validates that a library maintains its identity after a move.
    ///
    /// - Parameters:
    ///   - originalPath: The original library path
    ///   - newPath: The new library path after move
    /// - Returns: `true` if identity is preserved, `false` otherwise
    /// - Throws: `LibraryIdentityError` if validation fails
    public static func validatePersistence(
        originalPath: String,
        newPath: String
    ) throws -> Bool {
        // Read metadata from original location (if still accessible)
        let originalMetadata: LibraryMetadata?
        if FileManager.default.fileExists(atPath: originalPath) {
            originalMetadata = try? LibraryMetadataReader.readMetadata(from: originalPath)
        } else {
            originalMetadata = nil
        }
        
        // Read metadata from new location
        guard LibraryPathDetector.detect(at: newPath) else {
            throw LibraryIdentityError.pathNotFound
        }
        
        let newMetadata = try LibraryMetadataReader.readMetadata(from: newPath)
        
        // If we have original metadata, compare identifiers
        if let original = originalMetadata {
            return original.libraryId == newMetadata.libraryId
        }
        
        // If original is not accessible, assume identity is preserved if new location has valid metadata
        return newMetadata.isValid()
    }
}
