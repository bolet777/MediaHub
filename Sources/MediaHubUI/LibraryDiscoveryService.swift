import Foundation

struct LibraryDiscoveryService {
    static func scanFolder(at rootPath: String) throws -> [DiscoveredLibrary] {
        let fileManager = FileManager.default
        let rootURL = URL(fileURLWithPath: rootPath)
        
        // Verify root path exists and is accessible
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: rootPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw DiscoveryError.rootPathNotAccessible
        }
        
        var discoveredLibraries: [DiscoveredLibrary] = []
        
        // Check if root folder itself is a candidate library
        let rootLibraryJSONPath = rootURL.appendingPathComponent(".mediahub/library.json").path
        if fileManager.fileExists(atPath: rootLibraryJSONPath) {
            let (isValid, validationError) = validateLibraryJSON(at: rootLibraryJSONPath)
            let library = DiscoveredLibrary(
                path: rootPath,
                displayName: rootURL.lastPathComponent,
                isValid: isValid,
                validationError: validationError
            )
            discoveredLibraries.append(library)
        }
        
        // Recursive directory walk
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw DiscoveryError.rootPathNotAccessible
        }
        
        for case let fileURL as URL in enumerator {
            // Only consider directories
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey]),
                  resourceValues.isDirectory == true else {
                continue
            }
            
            // Check if this directory contains .mediahub/library.json
            let libraryJSONPath = fileURL.appendingPathComponent(".mediahub/library.json").path
            
            if fileManager.fileExists(atPath: libraryJSONPath) {
                // Found a candidate library
                let path = fileURL.path
                let displayName = fileURL.lastPathComponent
                
                // Validate library.json
                let (isValid, validationError) = validateLibraryJSON(at: libraryJSONPath)
                
                let library = DiscoveredLibrary(
                    path: path,
                    displayName: displayName,
                    isValid: isValid,
                    validationError: validationError
                )
                
                discoveredLibraries.append(library)
                
                // Skip subdirectories of this library
                enumerator.skipDescendants()
            }
        }
        
        // Sort results lexicographically by path
        discoveredLibraries.sort { $0.path < $1.path }
        
        return discoveredLibraries
    }
    
    private static func validateLibraryJSON(at path: String) -> (isValid: Bool, error: String?) {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return (false, "Cannot read library.json")
        }
        
        guard let _ = try? JSONSerialization.jsonObject(with: data, options: []) else {
            return (false, "Invalid JSON format")
        }
        
        return (true, nil)
    }
}

enum DiscoveryError: Error {
    case rootPathNotAccessible
}
