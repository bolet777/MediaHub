//
//  LibraryContext.swift
//  MediaHubCLI
//
//  Library context management for CLI commands
//

import Foundation
import MediaHub

/// Manages library context resolution from command-line arguments or environment variables
struct LibraryContext {
    /// Resolves library path from command-line argument or environment variable
    ///
    /// Precedence: command-line argument > environment variable
    ///
    /// - Parameter libraryPath: Optional library path from command-line argument
    /// - Returns: Resolved library path, or nil if not provided
    static func resolveLibraryPath(from libraryPath: String?) -> String? {
        // Command-line argument takes precedence
        if let path = libraryPath, !path.isEmpty {
            return path
        }
        
        // Fall back to environment variable
        if let envPath = ProcessInfo.processInfo.environment["MEDIAHUB_LIBRARY"], !envPath.isEmpty {
            return envPath
        }
        
        return nil
    }
    
    /// Validates and opens a library from a path
    ///
    /// - Parameter path: Library path
    /// - Returns: Opened library
    /// - Throws: LibraryOpeningError if opening fails
    static func openLibrary(at path: String) throws -> OpenedLibrary {
        let opener = LibraryOpener()
        return try opener.openLibrary(at: path)
    }
    
    /// Validates that a library path is provided and accessible
    ///
    /// - Parameter libraryPath: Optional library path from command-line argument
    /// - Returns: Resolved library path
    /// - Throws: CLIError if library path is missing or invalid
    static func requireLibraryPath(from libraryPath: String?) throws -> String {
        guard let path = resolveLibraryPath(from: libraryPath) else {
            throw CLIError.missingLibraryContext
        }
        
        // Validate path exists and is accessible
        guard FileManager.default.fileExists(atPath: path) else {
            throw CLIError.libraryNotFound(path)
        }
        
        return path
    }
}
