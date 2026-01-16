import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
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
                if let errorMessage = appState.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
                
                if let libraryOpenError = appState.libraryOpenError {
                    Text(libraryOpenError)
                        .foregroundStyle(.red)
                }
                
                if let openedPath = appState.openedLibraryPath {
                    Text("Opened: \(openedPath)")
                } else {
                    EmptyStateView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("MediaHub")
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
                    appState.openedLibraryPath = nil
                    appState.libraryContext = nil
                    appState.libraryOpenError = nil
                } else {
                    appState.selectedLibraryPath = path
                    appState.errorMessage = nil
                    
                    // Attempt to open the library
                    do {
                        let openedLibrary = try LibraryStatusService.openLibrary(at: path)
                        appState.openedLibraryPath = path
                        appState.libraryContext = openedLibrary
                        appState.libraryOpenError = nil
                    } catch {
                        appState.openedLibraryPath = nil
                        appState.libraryContext = nil
                        appState.libraryOpenError = "Failed to open library: \(error.localizedDescription)"
                    }
                }
            } else {
                appState.selectedLibraryPath = nil
                appState.errorMessage = library.validationError ?? "This library is invalid (unreadable or malformed .mediahub/library.json)."
                appState.openedLibraryPath = nil
                appState.libraryContext = nil
                appState.libraryOpenError = nil
            }
        }
    }
}
