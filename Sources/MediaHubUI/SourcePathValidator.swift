//
//  SourcePathValidator.swift
//  MediaHubUI
//
//  Path validation logic for source attachment
//

import Foundation
import MediaHub

enum ValidationResult {
    case valid
    case invalid(String)
}

struct SourcePathValidator {
    static func validateSourcePath(
        _ path: String,
        existingSources: [Source]
    ) -> ValidationResult {
        // Check if path exists and is accessible
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: path) else {
            return .invalid("Path does not exist")
        }
        
        // Check if path is a directory
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return .invalid("Path is not a directory")
        }
        
        // Check read permissions
        guard fileManager.isReadableFile(atPath: path) else {
            return .invalid("Path is not readable")
        }
        
        // Check if path is already attached
        let standardizedPath = (path as NSString).standardizingPath
        if existingSources.contains(where: { (existingPath) -> Bool in
            let existingStandardized = (existingPath.path as NSString).standardizingPath
            return existingStandardized == standardizedPath
        }) {
            return .invalid("Source is already attached")
        }
        
        return .valid
    }
}
