import Foundation
import Combine
import MediaHub

@MainActor
final class AppState: ObservableObject {
    @Published var selectedLibraryPath: String? = nil
    @Published var errorMessage: String? = nil
    @Published var discoveredLibraries: [DiscoveredLibrary] = []
    @Published var discoveryRootPath: String? = nil
    @Published var isDiscovering: Bool = false
    @Published var openedLibraryPath: String? = nil
    @Published var libraryOpenError: String? = nil
    
    var libraryContext: OpenedLibrary? = nil
    
    /// Sets the opened library state consistently.
    func setOpenedLibrary(path: String, context: OpenedLibrary) {
        openedLibraryPath = path
        libraryContext = context
        libraryOpenError = nil
    }
    
    /// Clears the opened library state consistently.
    func clearOpenedLibrary(error: String?) {
        openedLibraryPath = nil
        libraryContext = nil
        libraryOpenError = error
    }
    
    /// Persists current UI state to UserDefaults.
    func persistState() {
        UIPersistenceService.persistLibraryList(discoveredLibraries, discoveryRoot: discoveryRootPath)
        UIPersistenceService.persistLastOpenedLibrary(openedLibraryPath)
    }
    
    /// Restores UI state from UserDefaults.
    func restoreState() {
        let (libraries, discoveryRoot) = UIPersistenceService.restoreLibraryList()
        
        // Re-validate libraries and update isValid status
        discoveredLibraries = libraries.map { library in
            if let validationError = LibraryPathValidator.validateSelectedLibraryPath(library.path) {
                return DiscoveredLibrary(
                    path: library.path,
                    displayName: library.displayName,
                    isValid: false,
                    validationError: validationError
                )
            } else {
                return DiscoveredLibrary(
                    path: library.path,
                    displayName: library.displayName,
                    isValid: true,
                    validationError: nil
                )
            }
        }
        
        discoveryRootPath = discoveryRoot
        
        openedLibraryPath = UIPersistenceService.restoreLastOpenedLibrary()
    }
}
