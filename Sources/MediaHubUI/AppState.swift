import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var selectedLibraryPath: String? = nil
    @Published var errorMessage: String? = nil
    @Published var discoveredLibraries: [DiscoveredLibrary] = []
    @Published var discoveryRootPath: String? = nil
    @Published var isDiscovering: Bool = false
}
