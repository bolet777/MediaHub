//
//  CLIError.swift
//  MediaHubCLI
//
//  CLI-specific error types and formatting
//

import Foundation
import MediaHub

/// CLI-specific errors
enum CLIError: Error, CustomStringConvertible {
    case missingLibraryContext
    case libraryNotFound(String)
    case sourceNotFound(String)
    case invalidSourceId(String)
    case detectionResultNotFound
    case invalidArgument(String)
    case operationFailed(String)
    case nonInteractiveModeRequiresYes
    
    var description: String {
        switch self {
        case .missingLibraryContext:
            return "Library context is required. Provide --library <path> or set MEDIAHUB_LIBRARY environment variable."
        case .libraryNotFound(let path):
            return "Library not found at path: \(path)"
        case .sourceNotFound(let sourceId):
            return "Source not found: \(sourceId)"
        case .invalidSourceId(let sourceId):
            return "Invalid source identifier: \(sourceId)"
        case .detectionResultNotFound:
            return "No detection result found. Run detection first."
        case .invalidArgument(let message):
            return "Invalid argument: \(message)"
        case .operationFailed(let message):
            return "Operation failed: \(message)"
        case .nonInteractiveModeRequiresYes:
            return "Non-interactive mode requires --yes flag. Use --yes to skip confirmation in scripts."
        }
    }
}

/// Maps MediaHub core errors to user-friendly CLI error messages
struct ErrorFormatter {
    /// Formats an error for CLI output
    ///
    /// - Parameter error: The error to format
    /// - Returns: User-friendly error message
    static func format(_ error: Error) -> String {
        // Handle CLI-specific errors
        if let cliError = error as? CLIError {
            return cliError.description
        }
        
        // Handle MediaHub core errors
        if let creationError = error as? LibraryCreationError {
            return formatCreationError(creationError)
        }
        
        if let openingError = error as? LibraryOpeningError {
            return formatOpeningError(openingError)
        }
        
        if let discoveryError = error as? LibraryDiscoveryError {
            return formatDiscoveryError(discoveryError)
        }
        
        if let sourceError = error as? SourceError {
            return formatSourceError(sourceError)
        }
        
        if let validationError = error as? SourceValidationError {
            return formatValidationError(validationError)
        }
        
        if let associationError = error as? SourceAssociationError {
            return formatAssociationError(associationError)
        }
        
        if let detectionError = error as? DetectionOrchestrationError {
            return formatDetectionError(detectionError)
        }
        
        if let importError = error as? ImportExecutionError {
            return formatImportError(importError)
        }
        
        if let adoptionError = error as? LibraryAdoptionError {
            return formatAdoptionError(adoptionError)
        }
        
        // Fall back to localized description
        if let localizedError = error as? LocalizedError {
            return localizedError.errorDescription ?? error.localizedDescription
        }
        
        return error.localizedDescription
    }
    
    private static func formatCreationError(_ error: LibraryCreationError) -> String {
        switch error {
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
            return "Library creation cancelled"
        }
    }
    
    private static func formatOpeningError(_ error: LibraryOpeningError) -> String {
        switch error {
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
    
    private static func formatDiscoveryError(_ error: LibraryDiscoveryError) -> String {
        switch error {
        case .pathNotFound:
            return "Discovery path not found"
        case .permissionDenied(let path):
            return "Permission denied accessing path: \(path)"
        case .invalidPath:
            return "Invalid discovery path"
        case .discoveryFailed(let error):
            return "Discovery failed: \(error.localizedDescription)"
        }
    }
    
    private static func formatSourceError(_ error: SourceError) -> String {
        switch error {
        case .invalidSourceId(let id):
            return "Invalid source identifier: \(id)"
        case .invalidPath(let path):
            return "Invalid source path: \(path)"
        case .invalidTimestamp(let timestamp):
            return "Invalid timestamp: \(timestamp)"
        case .invalidSource:
            return "Invalid source"
        }
    }
    
    private static func formatValidationError(_ error: SourceValidationError) -> String {
        return error.localizedDescription
    }
    
    private static func formatAssociationError(_ error: SourceAssociationError) -> String {
        switch error {
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
            return "Source already attached: \(sourceId)"
        }
    }
    
    private static func formatDetectionError(_ error: DetectionOrchestrationError) -> String {
        switch error {
        case .sourceInaccessible(let path):
            return "Source is inaccessible: \(path)"
        case .scanningFailed(let error):
            return "Scanning failed: \(error.localizedDescription)"
        case .comparisonFailed(let error):
            return "Comparison failed: \(error.localizedDescription)"
        case .resultGenerationFailed(let error):
            return "Result generation failed: \(error.localizedDescription)"
        case .sourceUpdateFailed(let error):
            return "Source update failed: \(error.localizedDescription)"
        }
    }
    
    private static func formatImportError(_ error: ImportExecutionError) -> String {
        switch error {
        case .invalidDetectionResult:
            return "Invalid detection result. Run detection again to generate a new result."
        case .invalidLibrary:
            return "Invalid library. Verify the library path and ensure it's a valid MediaHub library."
        case .invalidSource:
            return "Invalid source. Verify the source is properly attached to the library."
        case .noItemsSelected:
            return "No items selected for import. Use --all to import all detected items."
        case .importFailed(let path, let error):
            return "Import failed for \(path). Library integrity preserved. Error: \(error.localizedDescription). Check file permissions and disk space."
        case .knownItemsUpdateFailed(let error):
            return "Import completed but failed to update tracking. Library integrity preserved. Error: \(error.localizedDescription). You may need to run detection again."
        case .resultStorageFailed(let error):
            return "Import completed but failed to store result. Library integrity preserved. Error: \(error.localizedDescription). Imported files are safe."
        }
    }
    
    private static func formatAdoptionError(_ error: LibraryAdoptionError) -> String {
        switch error {
        case .invalidPath:
            return "Invalid library path"
        case .pathDoesNotExist:
            return "Path does not exist"
        case .pathIsNotDirectory:
            return "Path is not a directory"
        case .permissionDenied:
            return "Permission denied accessing path"
        case .alreadyAdopted:
            return "Library is already adopted"
        case .metadataCreationFailed(let error):
            return "Failed to create metadata: \(error.localizedDescription)"
        case .metadataWriteFailed(let error):
            return "Failed to write metadata: \(error.localizedDescription)"
        case .rollbackFailed(let error):
            return "Failed to rollback adoption: \(error.localizedDescription)"
        }
    }
}
