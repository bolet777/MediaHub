import Foundation

@MainActor
final class UIPersistenceService {
    private init() {}
    
    private static let libraryListKey = "mediahub.ui.libraryList"
    private static let discoveryRootKey = "mediahub.ui.discoveryRoot"
    private static let lastOpenedLibraryKey = "mediahub.ui.lastOpenedLibrary"
    
    static func persistLibraryList(_ libraries: [DiscoveredLibrary], discoveryRoot: String?) {
        do {
            let encoder = JSONEncoder()
            let encodedData = try encoder.encode(libraries)
            UserDefaults.standard.set(encodedData, forKey: libraryListKey)
            
            if let discoveryRoot = discoveryRoot {
                UserDefaults.standard.set(discoveryRoot, forKey: discoveryRootKey)
            } else {
                UserDefaults.standard.removeObject(forKey: discoveryRootKey)
            }
        } catch {
            // Log error gracefully, don't crash
            print("Failed to persist library list: \(error.localizedDescription)")
        }
    }
    
    static func restoreLibraryList() -> ([DiscoveredLibrary], String?) {
        var libraries: [DiscoveredLibrary] = []
        var discoveryRoot: String? = nil
        
        // Restore library list
        if let encodedData = UserDefaults.standard.data(forKey: libraryListKey) {
            do {
                let decoder = JSONDecoder()
                libraries = try decoder.decode([DiscoveredLibrary].self, from: encodedData)
            } catch {
                // Decoding failed, return empty array
                print("Failed to restore library list: \(error.localizedDescription)")
            }
        }
        
        // Restore discovery root
        discoveryRoot = UserDefaults.standard.string(forKey: discoveryRootKey)
        
        return (libraries, discoveryRoot)
    }
    
    static func persistLastOpenedLibrary(_ path: String?) {
        if let path = path {
            UserDefaults.standard.set(path, forKey: lastOpenedLibraryKey)
        } else {
            UserDefaults.standard.removeObject(forKey: lastOpenedLibraryKey)
        }
    }
    
    static func restoreLastOpenedLibrary() -> String? {
        return UserDefaults.standard.string(forKey: lastOpenedLibraryKey)
    }
    
    static func clearPersistence() {
        UserDefaults.standard.removeObject(forKey: libraryListKey)
        UserDefaults.standard.removeObject(forKey: discoveryRootKey)
        UserDefaults.standard.removeObject(forKey: lastOpenedLibraryKey)
    }
}
