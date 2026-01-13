//
//  LibraryCreation.swift
//  MediaHub
//
//  Library creation workflow and validation
//

import Foundation

/// Errors that can occur during library creation
public enum LibraryCreationError: Error, LocalizedError {
    case invalidPath
    case pathDoesNotExist
    case pathIsNotDirectory
    case permissionDenied
    case existingLibraryFound
    case nonEmptyDirectory
    case directoryCreationFailed(Error)
    case metadataWriteFailed(Error)
    case rollbackFailed(Error)
    case insufficientDiskSpace
    case userCancelled
    
    public var errorDescription: String? {
        switch self {
        case .invalidPath:
            return "Invalid library path"
        case .pathDoesNotExist:
            return "Path does not exist"
        case .pathIsNotDirectory:
            return "Path is not a directory"
        case .permissionDenied:
            return "Permission denied accessing path"
        case .existingLibraryFound:
            return "A MediaHub library already exists at this location"
        case .nonEmptyDirectory:
            return "Directory is not empty"
        case .directoryCreationFailed(let error):
            return "Failed to create directory: \(error.localizedDescription)"
        case .metadataWriteFailed(let error):
            return "Failed to write metadata: \(error.localizedDescription)"
        case .rollbackFailed(let error):
            return "Failed to rollback creation: \(error.localizedDescription)"
        case .insufficientDiskSpace:
            return "Insufficient disk space"
        case .userCancelled:
            return "Library creation cancelled by user"
        }
    }
}

/// Result of path validation
public enum PathValidationResult {
    case valid
    case invalid(LibraryCreationError)
    case nonEmpty
    case existingLibrary
}

/// Validates target directory path for library creation
public struct LibraryPathValidator {
    /// Validates a target directory path for library creation.
    ///
    /// Checks:
    /// - Path exists and is a directory
    /// - Path has write permissions
    /// - Path is not already a MediaHub library
    /// - Path is empty or user confirmation required
    ///
    /// - Parameter path: The path to validate
    /// - Returns: Validation result
    public static func validatePath(_ path: String) -> PathValidationResult {
        let fileManager = FileManager.default
        
        // Check if path is valid
        guard !path.isEmpty else {
            return .invalid(.invalidPath)
        }
        
        let url = URL(fileURLWithPath: path)
        
        // Check if path exists
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: path, isDirectory: &isDirectory)
        
        if !exists {
            // Path doesn't exist - check if parent directory exists and is writable
            let parentURL = url.deletingLastPathComponent()
            var parentIsDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: parentURL.path, isDirectory: &parentIsDirectory),
                  parentIsDirectory.boolValue else {
                return .invalid(.pathDoesNotExist)
            }
            
            // Check parent directory permissions
            guard fileManager.isWritableFile(atPath: parentURL.path) else {
                return .invalid(.permissionDenied)
            }
            
            return .valid
        }
        
        // Path exists - check if it's a directory
        guard isDirectory.boolValue else {
            return .invalid(.pathIsNotDirectory)
        }
        
        // Check if directory is writable
        guard fileManager.isWritableFile(atPath: path) else {
            return .invalid(.permissionDenied)
        }
        
        // Check if it's already a MediaHub library
        if LibraryStructureValidator.isLibraryStructure(at: url) {
            return .existingLibrary
        }
        
        // Check if directory is empty
        if !isDirectoryEmpty(at: url) {
            return .nonEmpty
        }
        
        return .valid
    }
    
    /// Checks if a directory is empty (ignoring hidden system files).
    ///
    /// - Parameter url: The directory URL to check
    /// - Returns: `true` if directory is empty, `false` otherwise
    private static func isDirectoryEmpty(at url: URL) -> Bool {
        let fileManager = FileManager.default
        
        guard let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return false
        }
        
        // Filter out system files and directories that might be present
        let userVisibleContents = contents.filter { itemURL in
            let fileName = itemURL.lastPathComponent
            // Ignore common system files
            return !fileName.hasPrefix(".") || fileName == ".DS_Store"
        }
        
        return userVisibleContents.isEmpty
    }
}

/// Detects existing MediaHub libraries at a location
public struct ExistingLibraryDetector {
    /// Detects if a location already contains a MediaHub library.
    ///
    /// - Parameter path: The path to check
    /// - Returns: `true` if a library exists, `false` otherwise
    public static func detect(at path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        return LibraryStructureValidator.isLibraryStructure(at: url)
    }
}

/// Checks if a directory is non-empty
public struct NonEmptyDirectoryChecker {
    /// Checks if a directory is non-empty (contains user-visible files).
    ///
    /// - Parameter path: The path to check
    /// - Returns: `true` if directory is non-empty, `false` otherwise
    public static func check(_ path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        let fileManager = FileManager.default
        
        guard let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return false
        }
        
        // Filter out system files
        let userVisibleContents = contents.filter { itemURL in
            let fileName = itemURL.lastPathComponent
            return !fileName.hasPrefix(".") || fileName == ".DS_Store"
        }
        
        return !userVisibleContents.isEmpty
    }
}

/// User confirmation handler for library creation
public protocol LibraryCreationConfirmationHandler {
    /// Requests user confirmation for creating a library in a non-empty directory.
    ///
    /// - Parameters:
    ///   - path: The path where the library will be created
    ///   - completion: Called with `true` if user confirms, `false` if cancelled
    func requestConfirmationForNonEmptyDirectory(
        at path: String,
        completion: @escaping (Bool) -> Void
    )
    
    /// Requests user confirmation when an existing library is found.
    ///
    /// - Parameters:
    ///   - path: The path where an existing library was found
    ///   - completion: Called with `true` if user wants to open existing library, `false` if cancelled
    func requestConfirmationForExistingLibrary(
        at path: String,
        completion: @escaping (Bool) -> Void
    )
}

/// Default confirmation handler that always confirms (for testing/CLI)
public struct DefaultConfirmationHandler: LibraryCreationConfirmationHandler {
    public init() {}
    
    public func requestConfirmationForNonEmptyDirectory(
        at path: String,
        completion: @escaping (Bool) -> Void
    ) {
        // Default: always confirm
        completion(true)
    }
    
    public func requestConfirmationForExistingLibrary(
        at path: String,
        completion: @escaping (Bool) -> Void
    ) {
        // Default: don't open existing library
        completion(false)
    }
}

/// Tracks creation state for rollback
fileprivate struct CreationState {
    let libraryRootURL: URL
    var structureCreated: Bool = false
    var metadataWritten: Bool = false
    
    init(libraryRootURL: URL) {
        self.libraryRootURL = libraryRootURL
    }
}

/// Handles rollback of failed library creation
public struct LibraryCreationRollback {
    /// Rolls back a failed library creation, removing created files/directories.
    ///
    /// - Parameter state: The creation state to rollback
    /// - Throws: `LibraryCreationError` if rollback fails
    fileprivate static func rollback(_ state: CreationState) throws {
        let fileManager = FileManager.default
        
        // Only rollback if structure was created
        if state.structureCreated {
            // Remove metadata directory (and its contents)
            let metadataDirURL = state.libraryRootURL
                .appendingPathComponent(LibraryStructure.metadataDirectoryName)
            
            if fileManager.fileExists(atPath: metadataDirURL.path) {
                do {
                    try fileManager.removeItem(at: metadataDirURL)
                } catch {
                    throw LibraryCreationError.rollbackFailed(error)
                }
            }
            
            // If library root is now empty, remove it
            if let contents = try? fileManager.contentsOfDirectory(
                at: state.libraryRootURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ), contents.isEmpty {
                do {
                    try fileManager.removeItem(at: state.libraryRootURL)
                } catch {
                    // Ignore errors removing empty directory
                }
            }
        }
    }
}

/// Orchestrates library creation workflow
public struct LibraryCreator {
    private let confirmationHandler: LibraryCreationConfirmationHandler
    
    /// Creates a new LibraryCreator with a confirmation handler.
    ///
    /// - Parameter confirmationHandler: Handler for user confirmations (defaults to always-confirm handler)
    public init(confirmationHandler: LibraryCreationConfirmationHandler = DefaultConfirmationHandler()) {
        self.confirmationHandler = confirmationHandler
    }
    
    /// Creates a new MediaHub library at the specified path.
    ///
    /// This function orchestrates the complete library creation workflow:
    /// 1. Validates the target path
    /// 2. Checks for existing libraries
    /// 3. Handles non-empty directories with user confirmation
    /// 4. Creates library structure
    /// 5. Generates and writes metadata
    /// 6. Handles rollback on failure
    ///
    /// - Parameters:
    ///   - path: The path where the library should be created
    ///   - libraryVersion: The MediaHub library version (defaults to "1.0")
    ///   - completion: Called with result (success with metadata or error)
    public func createLibrary(
        at path: String,
        libraryVersion: String = "1.0",
        completion: @escaping (Result<LibraryMetadata, LibraryCreationError>) -> Void
    ) {
        // Step 1: Validate path
        let validationResult = LibraryPathValidator.validatePath(path)
        
        switch validationResult {
        case .invalid(let error):
            completion(.failure(error))
            return
            
        case .existingLibrary:
            // Offer to open existing library instead
            confirmationHandler.requestConfirmationForExistingLibrary(at: path) { shouldOpen in
                if shouldOpen {
                    // This will be handled by library opening logic
                    completion(.failure(.existingLibraryFound))
                } else {
                    completion(.failure(.userCancelled))
                }
            }
            return
            
        case .nonEmpty:
            // Request user confirmation
            confirmationHandler.requestConfirmationForNonEmptyDirectory(at: path) { confirmed in
                if !confirmed {
                    completion(.failure(.userCancelled))
                    return
                }
                // Continue with creation
                self.performCreation(
                    at: path,
                    libraryVersion: libraryVersion,
                    completion: completion
                )
            }
            return
            
        case .valid:
            // Continue with creation
            performCreation(
                at: path,
                libraryVersion: libraryVersion,
                completion: completion
            )
        }
    }
    
    /// Performs the actual library creation after validation and confirmation.
    private func performCreation(
        at path: String,
        libraryVersion: String,
        completion: @escaping (Result<LibraryMetadata, LibraryCreationError>) -> Void
    ) {
        let libraryRootURL = URL(fileURLWithPath: path)
        var state = CreationState(libraryRootURL: libraryRootURL)
        
        do {
            // Step 2: Create library structure
            try LibraryStructureCreator.createStructure(at: libraryRootURL)
            state.structureCreated = true
            
            // Step 3: Generate unique identifier
            let libraryId = LibraryIdentifierGenerator.generate()
            
            // Step 4: Create metadata
            let metadata = LibraryMetadata(
                libraryId: libraryId,
                rootPath: libraryRootURL.path,
                libraryVersion: libraryVersion
            )
            
            // Step 5: Write metadata
            let metadataFileURL = LibraryStructureCreator.metadataFileURL(for: libraryRootURL)
            try LibraryMetadataSerializer.write(metadata, to: metadataFileURL)
            state.metadataWritten = true
            
            // Success!
            completion(.success(metadata))
            
        } catch let error as LibraryCreationError {
            // Rollback on error
            try? LibraryCreationRollback.rollback(state)
            completion(.failure(error))
        } catch {
            // Rollback on error
            try? LibraryCreationRollback.rollback(state)
            completion(.failure(.metadataWriteFailed(error)))
        }
    }
}
