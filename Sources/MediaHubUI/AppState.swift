import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var selectedLibraryPath: String? = nil
    @Published var errorMessage: String? = nil
}
