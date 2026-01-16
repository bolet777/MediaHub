import Foundation
import MediaHub

@MainActor
final class StatusViewModel: ObservableObject {
    @Published var status: LibraryStatus? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    func load(from opened: OpenedLibrary, libraryPath: String) {
        isLoading = true
        errorMessage = nil
        
        Task.detached {
            do {
                let status = try LibraryStatusService.loadStatus(from: opened, libraryPath: libraryPath)
                await MainActor.run {
                    self.status = status
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load status. Please try reopening the library."
                    self.status = nil
                    self.isLoading = false
                }
            }
        }
    }
}
