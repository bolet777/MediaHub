//
//  CollisionHandling.swift
//  MediaHub
//
//  Collision detection and policy handling for import operations
//

import Foundation

/// Collision policy for handling destination path conflicts
public enum CollisionPolicy: String, Codable {
    case rename = "rename"
    case skip = "skip"
    case error = "error"
}

/// Collision detection result
public enum CollisionResult {
    case noCollision
    case collision(existingPath: URL, isDirectory: Bool)
}

/// Collision handling result
public enum CollisionHandlingResult {
    case proceed(destinationURL: URL)
    case skip(reason: String)
    case error(Error)
}

/// Errors that can occur during collision handling
public enum CollisionHandlingError: Error, LocalizedError {
    case collisionDetected(URL)
    case directoryCollision(URL)
    case renameFailed(String)
    case maxRenameAttemptsReached
    
    public var errorDescription: String? {
        switch self {
        case .collisionDetected(let url):
            return "Collision detected at destination: \(url.path)"
        case .directoryCollision(let url):
            return "Directory exists at destination: \(url.path)"
        case .renameFailed(let reason):
            return "Rename failed: \(reason)"
        case .maxRenameAttemptsReached:
            return "Maximum rename attempts reached (1000)"
        }
    }
}

/// Handles collision detection and policy application
public struct CollisionHandler {
    /// Maximum number of rename attempts before giving up
    private static let maxRenameAttempts = 1000
    
    /// Detects if a collision exists at the destination path
    ///
    /// - Parameter destinationURL: The destination URL to check
    /// - Returns: CollisionResult indicating if collision exists
    public static func detectCollision(at destinationURL: URL) -> CollisionResult {
        guard DestinationMapper.pathExists(at: destinationURL) else {
            return .noCollision
        }
        
        let isDirectory = DestinationMapper.isDirectory(at: destinationURL)
        return .collision(existingPath: destinationURL, isDirectory: isDirectory)
    }
    
    /// Handles a collision according to the configured policy
    ///
    /// - Parameters:
    ///   - collision: The collision result
    ///   - policy: The collision policy to apply
    ///   - originalDestinationURL: The original destination URL
    ///   - originalFileName: The original filename (for rename)
    /// - Returns: CollisionHandlingResult indicating how to proceed
    public static func handleCollision(
        _ collision: CollisionResult,
        policy: CollisionPolicy,
        originalDestinationURL: URL,
        originalFileName: String
    ) -> CollisionHandlingResult {
        switch collision {
        case .noCollision:
            return .proceed(destinationURL: originalDestinationURL)
            
        case .collision(let existingPath, let isDirectory):
            // Directory collisions always error (cannot rename/skip directories)
            if isDirectory {
                return .error(CollisionHandlingError.directoryCollision(existingPath))
            }
            
            // Apply policy
            switch policy {
            case .rename:
                return handleRenamePolicy(
                    originalDestinationURL: originalDestinationURL,
                    originalFileName: originalFileName
                )
                
            case .skip:
                return .skip(reason: "File already exists at destination")
                
            case .error:
                return .error(CollisionHandlingError.collisionDetected(existingPath))
            }
        }
    }
    
    /// Handles rename policy by generating unique filename
    ///
    /// - Parameters:
    ///   - originalDestinationURL: The original destination URL
    ///   - originalFileName: The original filename
    /// - Returns: CollisionHandlingResult with renamed destination URL
    private static func handleRenamePolicy(
        originalDestinationURL: URL,
        originalFileName: String
    ) -> CollisionHandlingResult {
        // Extract filename components
        let fileExtension = originalDestinationURL.pathExtension
        let fileNameWithoutExtension = originalDestinationURL.deletingPathExtension().lastPathComponent
        let directoryURL = originalDestinationURL.deletingLastPathComponent()
        
        // Try numbered suffixes: (1), (2), (3), ...
        for attempt in 1...maxRenameAttempts {
            let numberedFileName: String
            if fileExtension.isEmpty {
                numberedFileName = "\(fileNameWithoutExtension) (\(attempt))"
            } else {
                numberedFileName = "\(fileNameWithoutExtension) (\(attempt)).\(fileExtension)"
            }
            
            let renamedURL = directoryURL.appendingPathComponent(numberedFileName)
            
            // Check if this name is available
            if !DestinationMapper.pathExists(at: renamedURL) {
                return .proceed(destinationURL: renamedURL)
            }
        }
        
        // Max attempts reached
        return .error(CollisionHandlingError.maxRenameAttemptsReached)
    }
    
    /// Generates a unique filename for rename policy (deterministic)
    ///
    /// This is a helper that can be used to pre-compute renamed paths
    /// for deterministic import results.
    ///
    /// - Parameters:
    ///   - originalDestinationURL: The original destination URL
    ///   - existingPaths: Set of existing paths to avoid
    /// - Returns: Unique destination URL, or nil if max attempts reached
    public static func generateUniqueFilename(
        for originalDestinationURL: URL,
        avoiding existingPaths: Set<URL>
    ) -> URL? {
        let fileExtension = originalDestinationURL.pathExtension
        let fileNameWithoutExtension = originalDestinationURL.deletingPathExtension().lastPathComponent
        let directoryURL = originalDestinationURL.deletingLastPathComponent()
        
        // Try numbered suffixes: (1), (2), (3), ...
        for attempt in 1...maxRenameAttempts {
            let numberedFileName: String
            if fileExtension.isEmpty {
                numberedFileName = "\(fileNameWithoutExtension) (\(attempt))"
            } else {
                numberedFileName = "\(fileNameWithoutExtension) (\(attempt)).\(fileExtension)"
            }
            
            let renamedURL = directoryURL.appendingPathComponent(numberedFileName)
            
            // Check if this name conflicts with existing paths
            if !existingPaths.contains(renamedURL) && !DestinationMapper.pathExists(at: renamedURL) {
                return renamedURL
            }
        }
        
        // Max attempts reached
        return nil
    }
}
