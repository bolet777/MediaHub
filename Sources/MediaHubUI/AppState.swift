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
}
