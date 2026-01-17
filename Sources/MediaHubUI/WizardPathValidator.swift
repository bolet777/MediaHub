import Foundation
import MediaHub

enum PathValidationResult: Equatable {
    case valid
    case invalid(String)
    case alreadyAdopted
}

struct WizardPathValidator {
    static func validatePath(_ path: String, isForAdopt: Bool) -> PathValidationResult {
        let fileManager = FileManager.default
        let url = URL(fileURLWithPath: path)
        
        // Check if path exists
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return .invalid("Path does not exist")
        }
        
        // Check if path is a directory
        guard isDirectory.boolValue else {
            return .invalid("Path is not a directory")
        }
        
        // Check write permissions
        guard fileManager.isWritableFile(atPath: path) else {
            return .invalid("Write permission denied for this directory")
        }
        
        // Check if path already contains MediaHub library
        if LibraryStructureValidator.isLibraryStructure(at: url) {
            if isForAdopt {
                // For adopt: already-adopted is idempotent, not an error
                return .alreadyAdopted
            } else {
                // For create: already-adopted is an error
                return .invalid("This location already contains a MediaHub library")
            }
        }
        
        // For create: check if path contains files but is not a library
        if !isForAdopt {
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: path)
                // Filter out hidden files and directories (like .DS_Store)
                let visibleContents = contents.filter { !$0.hasPrefix(".") }
                if !visibleContents.isEmpty {
                    // Path contains files but is not a library - this is OK for create
                    // (user might want to create library in non-empty directory)
                }
            } catch {
                return .invalid("Cannot read directory contents: \(error.localizedDescription)")
            }
        }
        
        return .valid
    }
}
