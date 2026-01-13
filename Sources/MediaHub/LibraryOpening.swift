//
//  LibraryOpening.swift
//  MediaHub
//
//  Library opening, attachment, and active library management
//

import Foundation

/// Errors that can occur during library opening
public enum LibraryOpeningError: Error, LocalizedError {
    case libraryNotFound
    case invalidPath
    case metadataNotFound
    case metadataCorrupted(Error)
    case structureInvalid
    case permissionDenied
    case legacyLibraryNotSupported
    case adoptionFailed(Error)
    case identifierNotFound
    case multipleLibrariesWithSameIdentifier
    
    public var errorDescription: String? {
        switch self {
        case .libraryNotFound:
            return "Library not found at specified path"
        case .invalidPath:
            return "Invalid library path"
        case .metadataNotFound:
            return "Library metadata file not found"
        case .metadataCorrupted(let error):
            return "Library metadata is corrupted: \(error.localizedDescription)"
        case .structureInvalid:
            return "Library structure is invalid"
        case .permissionDenied:
            return "Permission denied accessing library"
        case .legacyLibraryNotSupported:
            return "Legacy library format is not supported"
        case .adoptionFailed(let error):
            return "Failed to adopt legacy library: \(error.localizedDescription)"
        case .identifierNotFound:
            return "Library with specified identifier not found"
        case .multipleLibrariesWithSameIdentifier:
            return "Multiple libraries found with the same identifier"
        }
    }
}

/// Represents an opened MediaHub library
public struct OpenedLibrary {
    /// The library metadata
    public let metadata: LibraryMetadata
    
    /// The library root URL
    public let rootURL: URL
    
    /// Whether this is a legacy library that was adopted
    public let isLegacy: Bool
    
    public init(metadata: LibraryMetadata, rootURL: URL, isLegacy: Bool = false) {
        self.metadata = metadata
        self.rootURL = rootURL
        self.isLegacy = isLegacy
    }
}

/// Detects if a path contains a valid MediaHub library
public struct LibraryPathDetector {
    /// Detects if a path contains a valid MediaHub library.
    ///
    /// - Parameter path: The path to check
    /// - Returns: `true` if a valid library is found, `false` otherwise
    public static func detect(at path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        return LibraryStructureValidator.isLibraryStructure(at: url)
    }
}

/// Reads library metadata from disk
public struct LibraryMetadataReader {
    /// Reads and parses library metadata from a library path.
    ///
    /// - Parameter libraryRootPath: The path to the library root
    /// - Returns: The library metadata
    /// - Throws: `LibraryOpeningError` if reading fails
    public static func readMetadata(from libraryRootPath: String) throws -> LibraryMetadata {
        let libraryRootURL = URL(fileURLWithPath: libraryRootPath)
        let metadataFileURL = LibraryStructureCreator.metadataFileURL(for: libraryRootURL)
        
        do {
            return try LibraryMetadataSerializer.read(from: metadataFileURL)
        } catch let error as LibraryMetadataError {
            switch error {
            case .fileNotFound:
                throw LibraryOpeningError.metadataNotFound
            case .permissionDenied:
                throw LibraryOpeningError.permissionDenied
            case .decodingError(let underlyingError):
                throw LibraryOpeningError.metadataCorrupted(underlyingError)
            default:
                throw LibraryOpeningError.metadataCorrupted(error)
            }
        } catch {
            throw LibraryOpeningError.metadataCorrupted(error)
        }
    }
}

/// Detects libraries created by prior versions (legacy libraries)
public struct LegacyLibraryDetector {
    /// Known patterns for legacy libraries (e.g., MediaVault)
    /// These can be extended as needed for different legacy formats
    
    /// Detects if a directory is a legacy library that can be adopted.
    ///
    /// For Slice 1, we support basic detection. Full legacy support
    /// may require additional patterns in future slices.
    ///
    /// - Parameter path: The path to check
    /// - Returns: `true` if a legacy library is detected, `false` otherwise
    public static func detect(at path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        let fileManager = FileManager.default
        
        // Check for MediaVault-style libraries
        // MediaVault may have used different metadata locations
        // For now, we check for common patterns
        
        // Pattern 1: Check for MediaVault metadata file
        let mediaVaultMetadataURL = url.appendingPathComponent(".mediavault").appendingPathComponent("library.json")
        if fileManager.fileExists(atPath: mediaVaultMetadataURL.path) {
            return true
        }
        
        // Pattern 2: Check for alternative metadata locations
        let altMetadataURL = url.appendingPathComponent("Library").appendingPathComponent("library.json")
        if fileManager.fileExists(atPath: altMetadataURL.path) {
            return true
        }
        
        // Pattern 3: Check for media directory structure that suggests a library
        // This is a heuristic - if there's a Media/ directory with organized structure,
        // it might be a legacy library
        let mediaDirURL = url.appendingPathComponent("Media")
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: mediaDirURL.path, isDirectory: &isDirectory),
           isDirectory.boolValue {
            // Check if it has organized structure (YYYY/MM pattern suggests MediaVault)
            if let contents = try? fileManager.contentsOfDirectory(at: mediaDirURL, includingPropertiesForKeys: nil) {
                // If we find year directories (4 digits), it's likely a legacy library
                let hasYearDirectories = contents.contains { itemURL in
                    let name = itemURL.lastPathComponent
                    return name.count == 4 && name.allSatisfy { $0.isNumber }
                }
                if hasYearDirectories {
                    return true
                }
            }
        }
        
        return false
    }
}

/// Adopts legacy libraries without re-import
public struct LegacyLibraryAdopter {
    /// Adopts a legacy library by creating MediaHub metadata structure.
    ///
    /// This function:
    /// 1. Detects the legacy library format
    /// 2. Generates a new MediaHub identifier
    /// 3. Creates MediaHub metadata structure
    /// 4. Preserves existing media files (no re-import)
    ///
    /// - Parameter legacyLibraryPath: The path to the legacy library
    /// - Returns: The adopted library metadata
    /// - Throws: `LibraryOpeningError` if adoption fails
    public static func adopt(at legacyLibraryPath: String) throws -> LibraryMetadata {
        let libraryRootURL = URL(fileURLWithPath: legacyLibraryPath)
        
        // Verify it's actually a legacy library
        guard LegacyLibraryDetector.detect(at: legacyLibraryPath) else {
            throw LibraryOpeningError.legacyLibraryNotSupported
        }
        
        // Check if it's already been adopted (has MediaHub structure)
        if LibraryStructureValidator.isLibraryStructure(at: libraryRootURL) {
            // Already adopted - just read the metadata
            return try LibraryMetadataReader.readMetadata(from: legacyLibraryPath)
        }
        
        // Create MediaHub structure
        do {
            try LibraryStructureCreator.createStructure(at: libraryRootURL)
        } catch {
            throw LibraryOpeningError.adoptionFailed(error)
        }
        
        // Generate new identifier for the adopted library
        let libraryId = LibraryIdentifierGenerator.generate()
        
        // Create metadata
        let metadata = LibraryMetadata(
            libraryId: libraryId,
            rootPath: libraryRootURL.path,
            libraryVersion: "1.0"
        )
        
        // Write metadata
        let metadataFileURL = LibraryStructureCreator.metadataFileURL(for: libraryRootURL)
        do {
            try LibraryMetadataSerializer.write(metadata, to: metadataFileURL)
        } catch {
            // Rollback structure creation
            try? FileManager.default.removeItem(
                at: libraryRootURL.appendingPathComponent(LibraryStructure.metadataDirectoryName)
            )
            throw LibraryOpeningError.adoptionFailed(error)
        }
        
        return metadata
    }
}

/// Registry for tracking library locations by identifier
public class LibraryRegistry {
    private var identifierToPath: [String: String] = [:]
    private var pathToIdentifier: [String: String] = [:]
    
    public init() {}
    
    /// Registers a library location.
    ///
    /// - Parameters:
    ///   - identifier: The library identifier
    ///   - path: The library root path
    public func register(identifier: String, path: String) {
        // Remove old path if identifier was already registered
        if let oldPath = identifierToPath[identifier], oldPath != path {
            pathToIdentifier.removeValue(forKey: oldPath)
        }
        
        // Remove old identifier if path was already registered
        if let oldIdentifier = pathToIdentifier[path], oldIdentifier != identifier {
            identifierToPath.removeValue(forKey: oldIdentifier)
        }
        
        identifierToPath[identifier] = path
        pathToIdentifier[path] = identifier
    }
    
    /// Gets the path for a library identifier.
    ///
    /// - Parameter identifier: The library identifier
    /// - Returns: The library root path, or `nil` if not found
    public func path(for identifier: String) -> String? {
        return identifierToPath[identifier]
    }
    
    /// Gets the identifier for a library path.
    ///
    /// - Parameter path: The library root path
    /// - Returns: The library identifier, or `nil` if not found
    public func identifier(for path: String) -> String? {
        return pathToIdentifier[path]
    }
    
    /// Removes a library from the registry.
    ///
    /// - Parameter identifier: The library identifier
    public func unregister(identifier: String) {
        if let path = identifierToPath.removeValue(forKey: identifier) {
            pathToIdentifier.removeValue(forKey: path)
        }
    }
    
    /// Clears all registrations.
    public func clear() {
        identifierToPath.removeAll()
        pathToIdentifier.removeAll()
    }
}

/// Manages the currently active library
public class ActiveLibraryManager {
    private var activeLibrary: OpenedLibrary?
    private let registry: LibraryRegistry
    
    public init(registry: LibraryRegistry = LibraryRegistry()) {
        self.registry = registry
    }
    
    /// Sets the active library.
    ///
    /// - Parameter library: The library to make active
    public func setActive(_ library: OpenedLibrary) {
        activeLibrary = library
        registry.register(identifier: library.metadata.libraryId, path: library.rootURL.path)
    }
    
    /// Gets the currently active library.
    ///
    /// - Returns: The active library, or `nil` if none is active
    public func getActive() -> OpenedLibrary? {
        return activeLibrary
    }
    
    /// Clears the active library.
    public func clearActive() {
        if let library = activeLibrary {
            registry.unregister(identifier: library.metadata.libraryId)
        }
        activeLibrary = nil
    }
    
    /// Gets the library registry.
    ///
    /// - Returns: The library registry
    public func getRegistry() -> LibraryRegistry {
        return registry
    }
}

/// Orchestrates library opening workflow
public struct LibraryOpener {
    private let activeLibraryManager: ActiveLibraryManager
    
    /// Creates a new LibraryOpener.
    ///
    /// - Parameter activeLibraryManager: The active library manager (defaults to new instance)
    public init(activeLibraryManager: ActiveLibraryManager = ActiveLibraryManager()) {
        self.activeLibraryManager = activeLibraryManager
    }
    
    /// Opens a library by path.
    ///
    /// - Parameter path: The path to the library root
    /// - Returns: The opened library
    /// - Throws: `LibraryOpeningError` if opening fails
    public func openLibrary(at path: String) throws -> OpenedLibrary {
        let libraryRootURL = URL(fileURLWithPath: path)
        
        // Step 1: Validate structure
        do {
            _ = try LibraryStructureValidator.validateStructure(at: libraryRootURL)
        } catch {
            // Check if it's a legacy library
            if LegacyLibraryDetector.detect(at: path) {
                // Adopt legacy library
                let metadata = try LegacyLibraryAdopter.adopt(at: path)
                let library = OpenedLibrary(metadata: metadata, rootURL: libraryRootURL, isLegacy: true)
                activeLibraryManager.setActive(library)
                return library
            }
            throw LibraryOpeningError.structureInvalid
        }
        
        // Step 2: Full library validation (integrates validation into opening workflow)
        let validationResult = LibraryValidator.validate(at: path)
        switch validationResult {
        case .valid:
            break
        case .invalid(let error):
            // Convert validation error to opening error
            throw convertValidationError(error)
        case .warning(let message):
            // Log warning but continue
            print("Warning: \(message)")
        }
        
        // Step 3: Read metadata
        let metadata = try LibraryMetadataReader.readMetadata(from: path)
        
        // Step 4: Validate metadata structure
        guard metadata.isValid() else {
            throw LibraryOpeningError.metadataCorrupted(
                LibraryMetadataError.invalidJSON
            )
        }
        
        // Step 5: Create opened library
        let library = OpenedLibrary(metadata: metadata, rootURL: libraryRootURL)
        
        // Step 6: Set as active
        activeLibraryManager.setActive(library)
        
        return library
    }
    
    /// Converts a validation error to an opening error.
    private func convertValidationError(_ error: LibraryValidationError) -> LibraryOpeningError {
        switch error {
        case .structureInvalid:
            return .structureInvalid
        case .metadataMissing:
            return .metadataNotFound
        case .metadataCorrupted(let details):
            return .metadataCorrupted(NSError(domain: "MediaHub", code: 1, userInfo: [NSLocalizedDescriptionKey: details]))
        case .invalidUUID, .invalidTimestamp, .missingRequiredField:
            return .metadataCorrupted(NSError(domain: "MediaHub", code: 1, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription]))
        case .permissionDenied:
            return .permissionDenied
        case .pathMismatch:
            // Path mismatch is a warning, not an error
            return .structureInvalid
        }
    }
    
    /// Opens a library by identifier.
    ///
    /// - Parameter identifier: The library identifier
    /// - Returns: The opened library
    /// - Throws: `LibraryOpeningError` if opening fails
    public func openLibrary(identifier: String) throws -> OpenedLibrary {
        let registry = activeLibraryManager.getRegistry()
        
        // Try to find path from registry
        if let path = registry.path(for: identifier) {
            // Verify library still exists at that path
            if LibraryPathDetector.detect(at: path) {
                return try openLibrary(at: path)
            } else {
                // Path is stale - remove from registry
                registry.unregister(identifier: identifier)
            }
        }
        
        // Identifier not found in registry
        throw LibraryOpeningError.identifierNotFound
    }
    
    /// Handles corrupted metadata by providing clear error information.
    ///
    /// - Parameter path: The path to the library
    /// - Returns: Detailed error information
    public func handleCorruptedMetadata(at path: String) -> LibraryOpeningError {
        let libraryRootURL = URL(fileURLWithPath: path)
        let metadataFileURL = LibraryStructureCreator.metadataFileURL(for: libraryRootURL)
        
        // Check if metadata file exists
        if !FileManager.default.fileExists(atPath: metadataFileURL.path) {
            return .metadataNotFound
        }
        
        // Try to read and see what error we get
        do {
            _ = try LibraryMetadataReader.readMetadata(from: path)
            // If we get here, metadata is actually valid
            return .structureInvalid
        } catch let error as LibraryOpeningError {
            return error
        } catch {
            return .metadataCorrupted(error)
        }
    }
    
    /// Gets the active library manager.
    ///
    /// - Returns: The active library manager
    public func getActiveLibraryManager() -> ActiveLibraryManager {
        return activeLibraryManager
    }
}
