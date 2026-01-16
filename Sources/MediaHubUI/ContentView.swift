import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var statusViewModel = StatusViewModel()
    
    var body: some View {
        NavigationSplitView {
            // Left sidebar: Libraries
            VStack(alignment: .leading, spacing: 8) {
                Text("Libraries")
                    .font(.headline)
                    .padding()
                
                Button("Choose Folder…") {
                    chooseFolder()
                }
                .padding(.horizontal)
                
                if appState.isDiscovering {
                    Text("Discovering…")
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                } else if appState.discoveredLibraries.isEmpty && appState.discoveryRootPath != nil && appState.errorMessage == nil {
                    Text("(No libraries found)")
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                } else {
                    List(selection: Binding(
                        get: { appState.selectedLibraryPath },
                        set: { newPath in
                            handleLibrarySelection(newPath)
                        }
                    )) {
                        ForEach(appState.discoveredLibraries) { library in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(library.displayName)
                                if !library.isValid {
                                    Text("Invalid")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                            .tag(library.path)
                        }
                    }
                }
                
                Spacer()
            }
            .frame(minWidth: 200)
        } detail: {
            // Right detail: empty state or selected library
            VStack(spacing: 16) {
                // Show only one error at a time (prefer libraryOpenError)
                if let libraryOpenError = appState.libraryOpenError {
                    Text(libraryOpenError)
                        .foregroundStyle(.red)
                } else if let errorMessage = appState.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
                
                if appState.openedLibraryPath != nil && appState.libraryContext != nil {
                    StatusView(viewModel: statusViewModel)
                } else {
                    EmptyStateView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task(id: appState.openedLibraryPath) {
            guard let opened = appState.libraryContext,
                  let path = appState.openedLibraryPath else {
                // Library was closed, reset status view model
                statusViewModel.status = nil
                statusViewModel.errorMessage = nil
                statusViewModel.isLoading = false
                return
            }
            // Library was opened, load status
            statusViewModel.load(from: opened, libraryPath: path)
        }
        .navigationTitle("MediaHub")
        .task {
            // Periodic validation of opened library path
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                
                guard let openedPath = appState.openedLibraryPath else {
                    continue
                }
                
                // Validate that the library is still accessible
                if LibraryPathValidator.validateSelectedLibraryPath(openedPath) != nil {
                    // Library is no longer accessible
                    appState.clearOpenedLibrary(error: "Opened library is no longer accessible (moved or deleted).")
                    appState.selectedLibraryPath = nil
                }
            }
        }
    }
    
    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Choose Folder to Discover Libraries"
        panel.message = "Select a folder to scan for MediaHub libraries"
        
        if panel.runModal() == .OK, let url = panel.url {
            let path = url.path
            // Clear selection and previous results when starting new discovery
            appState.selectedLibraryPath = nil
            appState.discoveredLibraries = []
            appState.errorMessage = nil
            appState.clearOpenedLibrary(error: nil)
            appState.discoveryRootPath = path
            appState.isDiscovering = true
            
            Task {
                do {
                    // Run discovery off the main actor to avoid blocking the UI.
                    let libraries = try await Task.detached {
                        try LibraryDiscoveryService.scanFolder(at: path)
                    }.value

                    await MainActor.run {
                        appState.discoveredLibraries = libraries
                        appState.isDiscovering = false
                    }
                } catch {
                    await MainActor.run {
                        if let discoveryError = error as? DiscoveryError,
                           case .rootPathNotAccessible = discoveryError {
                            appState.errorMessage = "Cannot access this folder. Please choose a readable folder."
                        } else {
                            appState.errorMessage = "Failed to discover libraries: \(error.localizedDescription)"
                        }
                        appState.discoveredLibraries = []
                        appState.isDiscovering = false
                    }
                }
            }
        }
    }
    
    private func handleLibrarySelection(_ path: String?) {
        guard let path = path else {
            appState.selectedLibraryPath = nil
            return
        }
        
        // Find the library by path
        if let library = appState.discoveredLibraries.first(where: { $0.path == path }) {
            if library.isValid {
                // Validate the selected library path
                if let validationError = LibraryPathValidator.validateSelectedLibraryPath(path) {
                    appState.selectedLibraryPath = nil
                    appState.errorMessage = validationError
                    appState.clearOpenedLibrary(error: nil)
                } else {
                    appState.selectedLibraryPath = path
                    appState.errorMessage = nil
                    
                    // Attempt to open the library
                    do {
                        let openedLibrary = try LibraryStatusService.openLibrary(at: path)
                        appState.setOpenedLibrary(path: path, context: openedLibrary)
                    } catch {
                        appState.clearOpenedLibrary(error: "Failed to open library: \(error.localizedDescription)")
                        // Reset status view model to avoid showing stale status
                        statusViewModel.status = nil
                        statusViewModel.errorMessage = nil
                        statusViewModel.isLoading = false
                    }
                }
            } else {
                appState.selectedLibraryPath = nil
                appState.errorMessage = library.validationError ?? "This library is invalid (unreadable or malformed .mediahub/library.json)."
                appState.clearOpenedLibrary(error: nil)
            }
        }
    }
}
