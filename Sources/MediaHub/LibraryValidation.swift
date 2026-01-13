//
//  LibraryValidation.swift
//  MediaHub
//
//  Library validation and integrity checking
//

import Foundation

/// Validation result for library integrity checks
public enum ValidationResult {
    case valid
    case invalid(LibraryValidationError)
    case warning(String)
}

/// Errors that can occur during library validation
public enum LibraryValidationError: Error, LocalizedError {
    case structureInvalid(String)
    case metadataMissing
    case metadataCorrupted(String)
    case invalidUUID(String)
    case invalidTimestamp(String)
    case missingRequiredField(String)
    case permissionDenied(String)
    case pathMismatch
    
    public var errorDescription: String? {
        switch self {
        case .structureInvalid(let details):
            return "Library structure is invalid: \(details)"
        case .metadataMissing:
            return "Library metadata file is missing"
        case .metadataCorrupted(let details):
            return "Library metadata is corrupted: \(details)"
        case .invalidUUID(let uuid):
            return "Invalid library identifier (UUID): \(uuid)"
        case .invalidTimestamp(let timestamp):
            return "Invalid creation timestamp: \(timestamp)"
        case .missingRequiredField(let field):
            return "Missing required metadata field: \(field)"
        case .permissionDenied(let path):
            return "Permission denied accessing library at: \(path)"
        case .pathMismatch:
            return "Library path mismatch detected"
        }
    }
}

/// Validates library integrity
public struct LibraryValidator {
    /// Validates a library at the specified path.
    ///
    /// Performs all required validation checks:
    /// 1. Structure validation
    /// 2. Metadata file validation
    /// 3. Metadata content validation
    /// 4. Permission validation
    ///
    /// - Parameter libraryPath: The path to the library root
    /// - Returns: Validation result
    public static func validate(at libraryPath: String) -> ValidationResult {
        let libraryRootURL = URL(fileURLWithPath: libraryPath)
        
        // Step 1: Structure validation
        switch validateStructure(at: libraryRootURL) {
        case .invalid(let error):
            return .invalid(error)
        case .valid:
            break
        case .warning:
            break
        }
        
        // Step 2: Metadata file validation
        switch validateMetadataFile(at: libraryRootURL) {
        case .invalid(let error):
            return .invalid(error)
        case .valid:
            break
        case .warning:
            break
        }
        
        // Step 3: Metadata content validation
        switch validateMetadataContent(at: libraryPath) {
        case .invalid(let error):
            return .invalid(error)
        case .valid:
            break
        case .warning(let message):
            return .warning(message)
        }
        
        // Step 4: Permission validation
        switch validatePermissions(at: libraryPath) {
        case .invalid(let error):
            return .invalid(error)
        case .valid:
            break
        case .warning:
            break
        }
        
        return .valid
    }
    
    /// Validates library structure.
    private static func validateStructure(at libraryRootURL: URL) -> ValidationResult {
        do {
            _ = try LibraryStructureValidator.validateStructure(at: libraryRootURL)
            return .valid
        } catch let error as LibraryStructureError {
            return .invalid(.structureInvalid(error.localizedDescription))
        } catch {
            return .invalid(.structureInvalid("Unexpected error: \(error.localizedDescription)"))
        }
    }
    
    /// Validates metadata file presence and accessibility.
    private static func validateMetadataFile(at libraryRootURL: URL) -> ValidationResult {
        let metadataFileURL = LibraryStructureCreator.metadataFileURL(for: libraryRootURL)
        let fileManager = FileManager.default
        
        // Check if file exists
        guard fileManager.fileExists(atPath: metadataFileURL.path) else {
            return .invalid(.metadataMissing)
        }
        
        // Check if file is readable
        guard fileManager.isReadableFile(atPath: metadataFileURL.path) else {
            return .invalid(.permissionDenied(metadataFileURL.path))
        }
        
        // Check if file is not empty
        guard let attributes = try? fileManager.attributesOfItem(atPath: metadataFileURL.path),
              let size = attributes[.size] as? Int64,
              size > 0 else {
            return .invalid(.metadataCorrupted("Metadata file is empty"))
        }
        
        return .valid
    }
    
    /// Validates metadata content.
    private static func validateMetadataContent(at libraryPath: String) -> ValidationResult {
        do {
            let metadata = try LibraryMetadataReader.readMetadata(from: libraryPath)
            
            // Validate metadata structure
            guard metadata.isValid() else {
                return .invalid(.metadataCorrupted("Metadata validation failed"))
            }
            
            // Validate UUID format
            guard LibraryIdentifierGenerator.isValid(metadata.libraryId) else {
                return .invalid(.invalidUUID(metadata.libraryId))
            }
            
            // Validate timestamp format
            let formatter = ISO8601DateFormatter()
            guard formatter.date(from: metadata.createdAt) != nil else {
                return .invalid(.invalidTimestamp(metadata.createdAt))
            }
            
            // Check for missing required fields
            if metadata.version.isEmpty {
                return .invalid(.missingRequiredField("version"))
            }
            if metadata.libraryVersion.isEmpty {
                return .invalid(.missingRequiredField("libraryVersion"))
            }
            if metadata.rootPath.isEmpty {
                return .invalid(.missingRequiredField("rootPath"))
            }
            
            // Check path consistency (warning only)
            if metadata.rootPath != libraryPath {
                return .warning("Library path mismatch: metadata indicates '\(metadata.rootPath)' but library is at '\(libraryPath)'. Library may have been moved.")
            }
            
            return .valid
        } catch let error as LibraryOpeningError {
            switch error {
            case .metadataNotFound:
                return .invalid(.metadataMissing)
            case .metadataCorrupted(let underlyingError):
                return .invalid(.metadataCorrupted(underlyingError.localizedDescription))
            case .permissionDenied:
                return .invalid(.permissionDenied(libraryPath))
            default:
                return .invalid(.metadataCorrupted(error.localizedDescription))
            }
        } catch {
            return .invalid(.metadataCorrupted("Unexpected error: \(error.localizedDescription)"))
        }
    }
    
    /// Validates library permissions.
    private static func validatePermissions(at libraryPath: String) -> ValidationResult {
        let fileManager = FileManager.default
        let libraryRootURL = URL(fileURLWithPath: libraryPath)
        
        // Check root directory is readable
        guard fileManager.isReadableFile(atPath: libraryPath) else {
            return .invalid(.permissionDenied(libraryPath))
        }
        
        // Check metadata directory is readable
        let metadataDirURL = libraryRootURL.appendingPathComponent(LibraryStructure.metadataDirectoryName)
        guard fileManager.isReadableFile(atPath: metadataDirURL.path) else {
            return .invalid(.permissionDenied(metadataDirURL.path))
        }
        
        return .valid
    }
}

/// Detects corruption in library files
public struct LibraryCorruptionDetector {
    /// Detects common corruption scenarios.
    ///
    /// - Parameter libraryPath: The path to the library
    /// - Returns: Array of detected corruption issues
    public static func detectCorruption(at libraryPath: String) -> [LibraryValidationError] {
        var issues: [LibraryValidationError] = []
        
        let libraryRootURL = URL(fileURLWithPath: libraryPath)
        let fileManager = FileManager.default
        
        // Check for missing metadata directory
        let metadataDirURL = libraryRootURL.appendingPathComponent(LibraryStructure.metadataDirectoryName)
        if !fileManager.fileExists(atPath: metadataDirURL.path) {
            issues.append(.structureInvalid("Metadata directory (.mediahub) is missing"))
        }
        
        // Check for missing metadata file
        let metadataFileURL = metadataDirURL.appendingPathComponent(LibraryStructure.metadataFileName)
        if !fileManager.fileExists(atPath: metadataFileURL.path) {
            issues.append(.metadataMissing)
        } else {
            // Check if metadata file is readable
            if !fileManager.isReadableFile(atPath: metadataFileURL.path) {
                issues.append(.permissionDenied(metadataFileURL.path))
            } else {
                // Try to read and parse metadata
                do {
                    let metadata = try LibraryMetadataReader.readMetadata(from: libraryPath)
                    if !metadata.isValid() {
                        issues.append(.metadataCorrupted("Metadata validation failed"))
                    }
                } catch {
                    issues.append(.metadataCorrupted("Failed to read metadata: \(error.localizedDescription)"))
                }
            }
        }
        
        return issues
    }
}

/// Generates clear error messages for validation failures
public struct LibraryValidationErrorMessageGenerator {
    /// Generates a user-friendly error message for a validation error.
    ///
    /// - Parameter error: The validation error
    /// - Returns: User-friendly error message
    public static func generateMessage(for error: LibraryValidationError) -> String {
        switch error {
        case .structureInvalid(let details):
            return """
            Library structure is invalid
            
            \(details)
            
            This library may be corrupted or incomplete. You may need to recreate the library or restore from backup.
            """
            
        case .metadataMissing:
            return """
            Library metadata not found
            
            The library is missing its metadata file (.mediahub/library.json).
            
            This library may be corrupted or incomplete. You may need to recreate the library or restore from backup.
            """
            
        case .metadataCorrupted(let details):
            return """
            Library metadata is corrupted
            
            \(details)
            
            The metadata file may be damaged. You may need to restore from backup or recreate the library.
            """
            
        case .invalidUUID(let uuid):
            return """
            Invalid library identifier
            
            The library identifier "\(uuid)" is not a valid UUID.
            
            This library may be corrupted. You may need to restore from backup or recreate the library.
            """
            
        case .invalidTimestamp(let timestamp):
            return """
            Invalid creation timestamp
            
            The library creation timestamp "\(timestamp)" is not valid.
            
            This library may be corrupted. You may need to restore from backup or recreate the library.
            """
            
        case .missingRequiredField(let field):
            return """
            Missing required metadata field
            
            The library metadata is missing the required field: \(field)
            
            This library may be corrupted. You may need to restore from backup or recreate the library.
            """
            
        case .permissionDenied(let path):
            return """
            Permission denied
            
            MediaHub does not have permission to access the library at: \(path)
            
            Please check file permissions and ensure MediaHub has access to this location.
            """
            
        case .pathMismatch:
            return """
            Library path mismatch
            
            The library metadata indicates a different location than where the library is currently located.
            
            This is usually harmless if the library was moved. MediaHub will update its records.
            """
        }
    }
}
