//
//  ContentHashing.swift
//  MediaHub
//
//  SHA-256 content hashing for duplicate detection
//

import Foundation
import CryptoKit

/// Errors that can occur during content hash computation
public enum ContentHashError: Error, LocalizedError, Equatable {
    case fileNotFound(String)
    case permissionDenied(String)
    case ioError(String, String)
    case computationFailed(String, String)
    case symlinkOutsideRoot(String, String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .ioError(let path, let reason):
            return "I/O error reading \(path): \(reason)"
        case .computationFailed(let path, let reason):
            return "Hash computation failed for \(path): \(reason)"
        case .symlinkOutsideRoot(let path, let root):
            return "Symlink target is outside allowed root: \(path) (root: \(root))"
        }
    }

    public static func == (lhs: ContentHashError, rhs: ContentHashError) -> Bool {
        switch (lhs, rhs) {
        case (.fileNotFound(let a), .fileNotFound(let b)):
            return a == b
        case (.permissionDenied(let a), .permissionDenied(let b)):
            return a == b
        case (.ioError(let a1, let a2), .ioError(let b1, let b2)):
            return a1 == b1 && a2 == b2
        case (.computationFailed(let a1, let a2), .computationFailed(let b1, let b2)):
            return a1 == b1 && a2 == b2
        case (.symlinkOutsideRoot(let a1, let a2), .symlinkOutsideRoot(let b1, let b2)):
            return a1 == b1 && a2 == b2
        default:
            return false
        }
    }
}

/// Computes SHA-256 content hashes for files using streaming reads
///
/// Hash computation is:
/// - Streaming: Reads file in 64KB chunks for constant memory usage
/// - Deterministic: Same file content always produces same hash
/// - Read-only: Never modifies source files
/// - Safe: Validates symlinks stay within allowed root directory
public struct ContentHasher {

    /// Chunk size for streaming file reads (64KB)
    private static let chunkSize = 64 * 1024

    /// Hash algorithm prefix for future extensibility
    private static let hashPrefix = "sha256:"

    /// Computes SHA-256 hash for file at URL
    ///
    /// - Parameters:
    ///   - url: File URL to hash
    ///   - allowedRoot: Root directory for symlink validation. Symlinks must resolve
    ///                  to targets within this directory, otherwise an error is thrown.
    /// - Returns: Hash string in format "sha256:<64-char-hexdigest>"
    /// - Throws: `ContentHashError` on failure
    ///
    /// ## Symlink Safety
    /// Before hashing, symlinks are resolved using `resolvingSymlinksInPath()`.
    /// If the resolved path is outside the `allowedRoot` directory, a
    /// `symlinkOutsideRoot` error is thrown to prevent path traversal attacks.
    ///
    /// ## Streaming Computation
    /// The file is read in 64KB chunks to maintain constant memory usage
    /// regardless of file size. This allows hashing files of any size
    /// (tested with 10GB+) without memory issues.
    ///
    /// ## Example
    /// ```swift
    /// let hash = try ContentHasher.computeHash(
    ///     for: fileURL,
    ///     allowedRoot: libraryRoot
    /// )
    /// // Returns: "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    /// ```
    public static func computeHash(for url: URL, allowedRoot: URL) throws -> String {
        // Step 1: Resolve symlinks and validate target is within allowed root
        let resolvedURL = try resolveAndValidateSymlink(url: url, allowedRoot: allowedRoot)

        // Step 2: Open file for reading
        let fileHandle: FileHandle
        do {
            fileHandle = try FileHandle(forReadingFrom: resolvedURL)
        } catch let error as NSError {
            throw mapFileHandleError(error, path: url.path)
        }

        defer {
            try? fileHandle.close()
        }

        // Step 3: Compute hash using streaming reads
        return try computeHashStreaming(fileHandle: fileHandle, originalPath: url.path)
    }

    /// Resolves symlinks and validates target is within allowed root
    ///
    /// - Parameters:
    ///   - url: File URL (may be symlink)
    ///   - allowedRoot: Root directory for validation
    /// - Returns: Resolved URL (symlinks followed)
    /// - Throws: `ContentHashError.symlinkOutsideRoot` if target is outside root
    private static func resolveAndValidateSymlink(url: URL, allowedRoot: URL) throws -> URL {
        let resolvedURL = url.resolvingSymlinksInPath()
        let resolvedRoot = allowedRoot.resolvingSymlinksInPath()

        // Normalize paths for comparison (ensure trailing slash consistency)
        let resolvedPath = resolvedURL.path
        let rootPath = resolvedRoot.path

        // Check if resolved path is within allowed root
        // Use standardized path comparison to handle edge cases
        guard resolvedPath.hasPrefix(rootPath + "/") || resolvedPath == rootPath else {
            throw ContentHashError.symlinkOutsideRoot(url.path, allowedRoot.path)
        }

        return resolvedURL
    }

    /// Maps FileHandle errors to ContentHashError
    ///
    /// - Parameters:
    ///   - error: NSError from FileHandle
    ///   - path: Original file path for error messages
    /// - Returns: Appropriate ContentHashError
    private static func mapFileHandleError(_ error: NSError, path: String) -> ContentHashError {
        switch error.code {
        case NSFileReadNoSuchFileError, NSFileNoSuchFileError:
            return .fileNotFound(path)
        case NSFileReadNoPermissionError:
            return .permissionDenied(path)
        default:
            return .ioError(path, error.localizedDescription)
        }
    }

    /// Computes hash using streaming file reads
    ///
    /// - Parameters:
    ///   - fileHandle: Open file handle for reading
    ///   - originalPath: Original file path for error messages
    /// - Returns: Hash string in format "sha256:<hexdigest>"
    /// - Throws: `ContentHashError` on read failure
    private static func computeHashStreaming(
        fileHandle: FileHandle,
        originalPath: String
    ) throws -> String {
        var hasher = SHA256()

        do {
            while true {
                guard let chunk = try fileHandle.read(upToCount: chunkSize) else {
                    break
                }
                if chunk.isEmpty {
                    break
                }
                hasher.update(data: chunk)
            }
        } catch {
            throw ContentHashError.ioError(originalPath, error.localizedDescription)
        }

        let digest = hasher.finalize()
        let hexString = digest.map { String(format: "%02x", $0) }.joined()

        return hashPrefix + hexString
    }
}
