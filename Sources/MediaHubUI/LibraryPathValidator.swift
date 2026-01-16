import Foundation

struct LibraryPathValidator {
    /// Validates that a library path is accessible and contains a valid library structure.
    /// - Parameter path: The path to validate
    /// - Returns: `nil` if the path is valid, or a short user-facing error string if invalid
    static func validateSelectedLibraryPath(_ path: String) -> String? {
        let fileManager = FileManager.default
        
        // Check if folder exists
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return "Library folder does not exist"
        }
        
        // Check if folder is readable
        guard fileManager.isReadableFile(atPath: path) else {
            return "Library folder is not readable"
        }
        
        // Check if .mediahub/library.json exists
        let libraryJSONPath = URL(fileURLWithPath: path).appendingPathComponent(".mediahub/library.json").path
        guard fileManager.fileExists(atPath: libraryJSONPath) else {
            return "Library metadata (.mediahub/library.json) is missing"
        }
        
        return nil
    }
}
