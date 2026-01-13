//
//  SourceValidation.swift
//  MediaHub
//
//  Source validation and accessibility checks
//

import Foundation

/// Validation result for Source validation
public struct SourceValidationResult {
    /// Whether the Source is valid
    public let isValid: Bool
    
    /// Array of validation errors (empty if valid)
    public let errors: [SourceValidationError]
    
    /// Creates a validation result
    ///
    /// - Parameters:
    ///   - isValid: Whether validation passed
    ///   - errors: Array of validation errors
    public init(isValid: Bool, errors: [SourceValidationError] = []) {
        self.isValid = isValid
        self.errors = errors
    }
}

/// Errors that can occur during Source validation
public enum SourceValidationError: Error, LocalizedError {
    case pathNotFound(String)
    case permissionDenied(String)
    case invalidType(SourceType)
    case notADirectory(String)
    case inaccessible(String)
    
    public var errorDescription: String? {
        switch self {
        case .pathNotFound(let path):
            return "Source path does not exist: \(path)"
        case .permissionDenied(let path):
            return "Permission denied accessing source: \(path). Please check read permissions."
        case .invalidType(let type):
            return "Source type not supported: \(type.rawValue). Supported types: folder"
        case .notADirectory(let path):
            return "Source path is not a directory: \(path)"
        case .inaccessible(let path):
            return "Source is inaccessible: \(path)"
        }
    }
}

/// Validates Source accessibility and permissions
public struct SourceValidator {
    /// Validates that a Source path exists and is accessible
    ///
    /// - Parameter path: The Source path to validate
    /// - Returns: Validation result
    public static func validatePathExists(_ path: String) -> SourceValidationResult {
        let fileManager = FileManager.default
        
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return SourceValidationResult(
                isValid: false,
                errors: [.pathNotFound(path)]
            )
        }
        
        return SourceValidationResult(isValid: true)
    }
    
    /// Validates that a Source has read permissions
    ///
    /// - Parameter path: The Source path to validate
    /// - Returns: Validation result
    public static func validateReadPermissions(_ path: String) -> SourceValidationResult {
        let fileManager = FileManager.default
        
        guard fileManager.isReadableFile(atPath: path) else {
            return SourceValidationResult(
                isValid: false,
                errors: [.permissionDenied(path)]
            )
        }
        
        return SourceValidationResult(isValid: true)
    }
    
    /// Validates that a Source type is supported
    ///
    /// - Parameter type: The Source type to validate
    /// - Returns: Validation result
    public static func validateSourceType(_ type: SourceType) -> SourceValidationResult {
        // For P1, only folder type is supported
        guard type == .folder else {
            return SourceValidationResult(
                isValid: false,
                errors: [.invalidType(type)]
            )
        }
        
        return SourceValidationResult(isValid: true)
    }
    
    /// Validates that a folder Source path is actually a directory
    ///
    /// - Parameter path: The Source path to validate
    /// - Returns: Validation result
    public static func validateIsDirectory(_ path: String) -> SourceValidationResult {
        let fileManager = FileManager.default
        
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return SourceValidationResult(
                isValid: false,
                errors: [.pathNotFound(path)]
            )
        }
        
        guard isDirectory.boolValue else {
            return SourceValidationResult(
                isValid: false,
                errors: [.notADirectory(path)]
            )
        }
        
        return SourceValidationResult(isValid: true)
    }
    
    /// Performs all validation checks before Source attachment
    ///
    /// - Parameters:
    ///   - source: The Source to validate
    ///   - type: The Source type
    /// - Returns: Validation result with all errors
    public static func validateBeforeAttachment(
        source: Source,
        type: SourceType
    ) -> SourceValidationResult {
        var allErrors: [SourceValidationError] = []
        
        // Validate source type
        let typeResult = validateSourceType(type)
        if !typeResult.isValid {
            allErrors.append(contentsOf: typeResult.errors)
        }
        
        // Validate path exists
        let pathResult = validatePathExists(source.path)
        if !pathResult.isValid {
            allErrors.append(contentsOf: pathResult.errors)
            // If path doesn't exist, skip further checks
            return SourceValidationResult(isValid: false, errors: allErrors)
        }
        
        // Validate read permissions
        let permissionResult = validateReadPermissions(source.path)
        if !permissionResult.isValid {
            allErrors.append(contentsOf: permissionResult.errors)
        }
        
        // Validate is directory (for folder sources)
        if type == .folder {
            let directoryResult = validateIsDirectory(source.path)
            if !directoryResult.isValid {
                allErrors.append(contentsOf: directoryResult.errors)
            }
        }
        
        return SourceValidationResult(
            isValid: allErrors.isEmpty,
            errors: allErrors
        )
    }
    
    /// Checks Source accessibility during detection runs
    ///
    /// - Parameter source: The Source to check
    /// - Returns: Validation result
    public static func validateDuringDetection(_ source: Source) -> SourceValidationResult {
        let fileManager = FileManager.default
        
        // Quick accessibility check
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: source.path, isDirectory: &isDirectory) else {
            return SourceValidationResult(
                isValid: false,
                errors: [.inaccessible(source.path)]
            )
        }
        
        guard fileManager.isReadableFile(atPath: source.path) else {
            return SourceValidationResult(
                isValid: false,
                errors: [.inaccessible(source.path)]
            )
        }
        
        return SourceValidationResult(isValid: true)
    }
    
    /// Generates a clear, actionable error message from validation errors
    ///
    /// - Parameter errors: Array of validation errors
    /// - Returns: Combined error message
    public static func generateErrorMessage(from errors: [SourceValidationError]) -> String {
        if errors.isEmpty {
            return "Source validation passed"
        }
        
        let errorMessages = errors.map { $0.localizedDescription }
        return errorMessages.joined(separator: "\n")
    }
}
