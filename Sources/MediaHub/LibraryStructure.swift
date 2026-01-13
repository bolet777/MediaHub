//
//  LibraryStructure.swift
//  MediaHub
//
//  Library root structure validation and creation
//

import Foundation

/// Constants for library structure paths and names
public enum LibraryStructure {
    /// Name of the hidden metadata directory
    public static let metadataDirectoryName = ".mediahub"
    
    /// Name of the library metadata file
    public static let metadataFileName = "library.json"
    
    /// Returns the metadata directory path relative to library root
    public static var metadataDirectoryPath: String {
        return metadataDirectoryName
    }
    
    /// Returns the metadata file path relative to library root
    public static var metadataFilePath: String {
        return "\(metadataDirectoryName)/\(metadataFileName)"
    }
}

/// Errors that can occur during structure operations
public enum LibraryStructureError: Error, LocalizedError {
    case invalidPath
    case directoryNotFound
    case metadataDirectoryMissing
    case metadataFileMissing
    case structureCreationFailed(Error)
    case permissionDenied
    
    public var errorDescription: String? {
        switch self {
        case .invalidPath:
            return "Invalid library path"
        case .directoryNotFound:
            return "Library directory not found"
        case .metadataDirectoryMissing:
            return "Library metadata directory (.mediahub) is missing"
        case .metadataFileMissing:
            return "Library metadata file (library.json) is missing"
        case .structureCreationFailed(let error):
            return "Failed to create library structure: \(error.localizedDescription)"
        case .permissionDenied:
            return "Permission denied accessing library structure"
        }
    }
}

/// Validates and manages library root structure
public struct LibraryStructureValidator {
    /// Validates that a directory matches MediaHub library structure.
    ///
    /// A directory is considered a valid MediaHub library if:
    /// - The `.mediahub/` directory exists
    /// - The `.mediahub/library.json` file exists
    ///
    /// - Parameter libraryRootURL: The URL of the library root directory
    /// - Returns: `true` if the structure is valid, `false` otherwise
    /// - Throws: `LibraryStructureError` if validation fails due to file system errors
    public static func validateStructure(at libraryRootURL: URL) throws -> Bool {
        let fileManager = FileManager.default
        
        // Check if library root exists and is a directory
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: libraryRootURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw LibraryStructureError.directoryNotFound
        }
        
        // Check for metadata directory
        let metadataDirURL = libraryRootURL.appendingPathComponent(LibraryStructure.metadataDirectoryName)
        var metadataDirIsDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: metadataDirURL.path, isDirectory: &metadataDirIsDirectory),
              metadataDirIsDirectory.boolValue else {
            throw LibraryStructureError.metadataDirectoryMissing
        }
        
        // Check for metadata file
        let metadataFileURL = metadataDirURL.appendingPathComponent(LibraryStructure.metadataFileName)
        guard fileManager.fileExists(atPath: metadataFileURL.path) else {
            throw LibraryStructureError.metadataFileMissing
        }
        
        return true
    }
    
    /// Checks if a directory appears to be a MediaHub library.
    ///
    /// This is a lightweight check that doesn't validate metadata content,
    /// only the presence of required structure elements.
    ///
    /// - Parameter libraryRootURL: The URL of the library root directory
    /// - Returns: `true` if the directory appears to be a library, `false` otherwise
    public static func isLibraryStructure(at libraryRootURL: URL) -> Bool {
        do {
            return try validateStructure(at: libraryRootURL)
        } catch {
            return false
        }
    }
}

/// Creates library root structure on disk
public struct LibraryStructureCreator {
    /// Creates the standard library root structure at the specified location.
    ///
    /// Creates:
    /// - Library root directory (if it doesn't exist)
    /// - `.mediahub/` directory
    /// - Does NOT create `library.json` (that's handled by library creation)
    ///
    /// - Parameter libraryRootURL: The URL where the library structure should be created
    /// - Throws: `LibraryStructureError` if structure creation fails
    public static func createStructure(at libraryRootURL: URL) throws {
        let fileManager = FileManager.default
        
        // Create library root directory if it doesn't exist
        if !fileManager.fileExists(atPath: libraryRootURL.path) {
            do {
                try fileManager.createDirectory(
                    at: libraryRootURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                if (error as NSError).code == NSFileWriteNoPermissionError {
                    throw LibraryStructureError.permissionDenied
                }
                throw LibraryStructureError.structureCreationFailed(error)
            }
        }
        
        // Create metadata directory
        let metadataDirURL = libraryRootURL.appendingPathComponent(LibraryStructure.metadataDirectoryName)
        if !fileManager.fileExists(atPath: metadataDirURL.path) {
            do {
                try fileManager.createDirectory(
                    at: metadataDirURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                if (error as NSError).code == NSFileWriteNoPermissionError {
                    throw LibraryStructureError.permissionDenied
                }
                throw LibraryStructureError.structureCreationFailed(error)
            }
        }
    }
    
    /// Gets the URL for the metadata file within a library root.
    ///
    /// - Parameter libraryRootURL: The URL of the library root directory
    /// - Returns: URL to the metadata file
    public static func metadataFileURL(for libraryRootURL: URL) -> URL {
        return libraryRootURL
            .appendingPathComponent(LibraryStructure.metadataDirectoryName)
            .appendingPathComponent(LibraryStructure.metadataFileName)
    }
}
