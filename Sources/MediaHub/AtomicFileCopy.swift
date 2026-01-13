//
//  AtomicFileCopy.swift
//  MediaHub
//
//  Atomic file copying with interruption safety
//

import Foundation

/// Protocol for file operations (enables testing via injection)
public protocol FileOperationsProtocol {
    func fileExists(atPath path: String) -> Bool
    func copyItem(at srcURL: URL, to dstURL: URL) throws
    func moveItem(at srcURL: URL, to dstURL: URL) throws
    func removeItem(at URL: URL) throws
    func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any]
    func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey: Any]?) throws
}

/// Default file operations implementation using FileManager
public struct DefaultFileOperations: FileOperationsProtocol {
    private let fileManager: FileManager
    
    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }
    
    public func fileExists(atPath path: String) -> Bool {
        return fileManager.fileExists(atPath: path)
    }
    
    public func copyItem(at srcURL: URL, to dstURL: URL) throws {
        try fileManager.copyItem(at: srcURL, to: dstURL)
    }
    
    public func moveItem(at srcURL: URL, to dstURL: URL) throws {
        try fileManager.moveItem(at: srcURL, to: dstURL)
    }
    
    public func removeItem(at URL: URL) throws {
        try fileManager.removeItem(at: URL)
    }
    
    public func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any] {
        return try fileManager.attributesOfItem(atPath: path)
    }
    
    public func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey: Any]?) throws {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: createIntermediates, attributes: attributes)
    }
}

/// Errors that can occur during atomic file copying
public enum AtomicFileCopyError: Error, LocalizedError {
    case sourceFileInaccessible(String)
    case sourceFileNotFound(String)
    case sourceNotRegularFile(String)
    case destinationDirectoryCreationFailed(String, Error)
    case copyFailed(String, Error)
    case verificationFailed(String)
    case atomicRenameFailed(String, Error)
    case cleanupFailed(String, Error)
    
    public var errorDescription: String? {
        switch self {
        case .sourceFileInaccessible(let path):
            return "Source file is inaccessible: \(path)"
        case .sourceFileNotFound(let path):
            return "Source file not found: \(path)"
        case .sourceNotRegularFile(let path):
            return "Source is not a regular file: \(path)"
        case .destinationDirectoryCreationFailed(let path, let error):
            return "Failed to create destination directory at \(path): \(error.localizedDescription)"
        case .copyFailed(let path, let error):
            return "Copy failed at \(path): \(error.localizedDescription)"
        case .verificationFailed(let reason):
            return "Verification failed: \(reason)"
        case .atomicRenameFailed(let path, let error):
            return "Atomic rename failed at \(path): \(error.localizedDescription)"
        case .cleanupFailed(let path, let error):
            return "Cleanup failed at \(path): \(error.localizedDescription)"
        }
    }
}

/// Result of atomic file copy operation
public struct AtomicCopyResult {
    /// The final destination URL
    public let destinationURL: URL
    
    /// The temporary file URL (if cleanup needed)
    public let temporaryURL: URL?
    
    /// Creates a new AtomicCopyResult
    ///
    /// - Parameters:
    ///   - destinationURL: Final destination URL
    ///   - temporaryURL: Temporary file URL (if cleanup needed)
    public init(destinationURL: URL, temporaryURL: URL?) {
        self.destinationURL = destinationURL
        self.temporaryURL = temporaryURL
    }
}

/// Performs atomic file copying with interruption safety
public struct AtomicFileCopier {
    /// Temporary file prefix for MediaHub temp files
    private static let tempFilePrefix = ".mediahub-tmp-"
    
    /// Copies a file atomically from source to destination
    ///
    /// - Parameters:
    ///   - sourceURL: Source file URL
    ///   - destinationURL: Destination file URL
    ///   - fileOperations: File operations implementation (default: FileManager)
    /// - Returns: AtomicCopyResult with destination and temp file info
    /// - Throws: `AtomicFileCopyError` if copy fails
    public static func copyAtomically(
        from sourceURL: URL,
        to destinationURL: URL,
        fileOperations: FileOperationsProtocol = DefaultFileOperations()
    ) throws -> AtomicCopyResult {
        // Step 1: Validate source file
        try validateSourceFile(at: sourceURL, fileOperations: fileOperations)
        
        // Step 2: Create destination directory if needed
        let destinationDir = destinationURL.deletingLastPathComponent()
        try createDestinationDirectory(at: destinationDir, fileOperations: fileOperations)
        
        // Step 3: Generate temporary file URL
        let tempURL = generateTemporaryFileURL(for: destinationURL)
        
        // Step 4: Copy to temporary file
        try performCopy(from: sourceURL, to: tempURL, fileOperations: fileOperations)
        
        // Step 5: Verify copy integrity (size comparison)
        try verifyCopy(sourceURL: sourceURL, tempURL: tempURL, fileOperations: fileOperations)
        
        // Step 6: Atomically rename temporary file to final destination
        do {
            try fileOperations.moveItem(at: tempURL, to: destinationURL)
            return AtomicCopyResult(destinationURL: destinationURL, temporaryURL: nil)
        } catch {
            // Cleanup temp file on rename failure
            _ = try? fileOperations.removeItem(at: tempURL)
            throw AtomicFileCopyError.atomicRenameFailed(destinationURL.path, error)
        }
    }
    
    /// Validates that source file is accessible and readable
    ///
    /// - Parameters:
    ///   - sourceURL: Source file URL
    ///   - fileOperations: File operations implementation
    /// - Throws: `AtomicFileCopyError` if validation fails
    private static func validateSourceFile(
        at sourceURL: URL,
        fileOperations: FileOperationsProtocol
    ) throws {
        // Check if file exists
        guard fileOperations.fileExists(atPath: sourceURL.path) else {
            throw AtomicFileCopyError.sourceFileNotFound(sourceURL.path)
        }
        
        // Check if file is readable (try to get attributes)
        do {
            let attributes = try fileOperations.attributesOfItem(atPath: sourceURL.path)
            // Check if it's a regular file (not directory)
            guard let fileType = attributes[.type] as? FileAttributeType,
                  fileType == .typeRegular else {
                throw AtomicFileCopyError.sourceNotRegularFile(sourceURL.path)
            }
        } catch let error as AtomicFileCopyError {
            throw error
        } catch {
            throw AtomicFileCopyError.sourceFileInaccessible(sourceURL.path)
        }
    }
    
    /// Creates destination directory if it doesn't exist
    ///
    /// - Parameters:
    ///   - directoryURL: Directory URL to create
    ///   - fileOperations: File operations implementation
    /// - Throws: `AtomicFileCopyError` if creation fails
    private static func createDestinationDirectory(
        at directoryURL: URL,
        fileOperations: FileOperationsProtocol
    ) throws {
        guard !fileOperations.fileExists(atPath: directoryURL.path) else {
            return // Directory already exists
        }
        
        do {
            try fileOperations.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            throw AtomicFileCopyError.destinationDirectoryCreationFailed(directoryURL.path, error)
        }
    }
    
    /// Generates temporary file URL for atomic copy
    ///
    /// - Parameter destinationURL: Final destination URL
    /// - Returns: Temporary file URL
    private static func generateTemporaryFileURL(for destinationURL: URL) -> URL {
        let directory = destinationURL.deletingLastPathComponent()
        let fileName = destinationURL.lastPathComponent
        let tempFileName = ".\(fileName).\(tempFilePrefix)\(UUID().uuidString)"
        return directory.appendingPathComponent(tempFileName)
    }
    
    /// Performs the actual file copy operation
    ///
    /// - Parameters:
    ///   - sourceURL: Source file URL
    ///   - tempURL: Temporary file URL
    ///   - fileOperations: File operations implementation
    /// - Throws: `AtomicFileCopyError` if copy fails
    private static func performCopy(
        from sourceURL: URL,
        to tempURL: URL,
        fileOperations: FileOperationsProtocol
    ) throws {
        do {
            try fileOperations.copyItem(at: sourceURL, to: tempURL)
        } catch {
            throw AtomicFileCopyError.copyFailed(tempURL.path, error)
        }
    }
    
    /// Verifies copy integrity by comparing file sizes
    ///
    /// - Parameters:
    ///   - sourceURL: Source file URL
    ///   - tempURL: Temporary file URL
    ///   - fileOperations: File operations implementation
    /// - Throws: `AtomicFileCopyError` if verification fails
    private static func verifyCopy(
        sourceURL: URL,
        tempURL: URL,
        fileOperations: FileOperationsProtocol
    ) throws {
        do {
            let sourceAttributes = try fileOperations.attributesOfItem(atPath: sourceURL.path)
            let tempAttributes = try fileOperations.attributesOfItem(atPath: tempURL.path)
            
            guard let sourceSize = sourceAttributes[.size] as? Int64,
                  let tempSize = tempAttributes[.size] as? Int64 else {
                throw AtomicFileCopyError.verificationFailed("Could not read file sizes")
            }
            
            guard sourceSize == tempSize else {
                throw AtomicFileCopyError.verificationFailed("File size mismatch: source=\(sourceSize), temp=\(tempSize)")
            }
        } catch let error as AtomicFileCopyError {
            throw error
        } catch {
            throw AtomicFileCopyError.verificationFailed("Verification error: \(error.localizedDescription)")
        }
    }
    
    /// Cleans up temporary file
    ///
    /// - Parameters:
    ///   - tempURL: Temporary file URL to clean up
    ///   - fileOperations: File operations implementation
    /// - Throws: `AtomicFileCopyError` if cleanup fails
    public static func cleanupTemporaryFile(
        at tempURL: URL,
        fileOperations: FileOperationsProtocol = DefaultFileOperations()
    ) throws {
        guard fileOperations.fileExists(atPath: tempURL.path) else {
            return // Already cleaned up
        }
        
        do {
            try fileOperations.removeItem(at: tempURL)
        } catch {
            throw AtomicFileCopyError.cleanupFailed(tempURL.path, error)
        }
    }
}
