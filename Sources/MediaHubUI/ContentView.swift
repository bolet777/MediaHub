import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var statusViewModel = StatusViewModel()
    @StateObject private var sourceState = SourceState()
    @State private var showCreateWizard = false
    @State private var showAdoptWizard = false
    
    var body: some View {
        NavigationSplitView {
            // Left sidebar: Libraries
            VStack(alignment: .leading, spacing: 8) {
                Text("Libraries")
                    .font(.headline)
                    .padding()
                
                HStack {
                    Button("Choose Folder…") {
                        chooseFolder()
                    }
                    
                    Button("Create Library…") {
                        showCreateWizard = true
                    }
                    
                    Button("Adopt Library…") {
                        showAdoptWizard = true
                    }
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
                    VStack(alignment: .leading, spacing: 16) {
                        StatusView(viewModel: statusViewModel)
                        
                        Divider()
                        
                        // Source List Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Attached Sources")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            if let opened = appState.libraryContext {
                                SourceListView(
                                    sourceState: sourceState,
                                    libraryRootURL: opened.rootURL,
                                    libraryId: opened.metadata.libraryId,
                                    onImportComplete: {
                                        // Refresh library status after import
                                        statusViewModel.load(from: opened, libraryPath: appState.openedLibraryPath ?? "")
                                    }
                                )
                            }
                        }
                    }
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
                // Reset source state
                sourceState.sources = []
                sourceState.errorMessage = nil
                return
            }
            // Library was opened, load status
            statusViewModel.load(from: opened, libraryPath: path)
            // Load sources
            await sourceState.refreshSources(
                libraryRootURL: opened.rootURL,
                libraryId: opened.metadata.libraryId
            )
        }
        .navigationTitle("MediaHub")
        .onAppear {
            appState.restoreState()
        }
        .task {
            // Auto-open last opened library on launch (if restored but not yet opened)
            guard let restoredPath = appState.openedLibraryPath,
                  appState.libraryContext == nil else {
                // Library already opened or no restored path
                return
            }
            
            // Validate library path
            if let validationError = LibraryPathValidator.validateSelectedLibraryPath(restoredPath) {
                // Library is invalid or missing
                appState.clearOpenedLibrary(error: "Library no longer accessible: \(validationError)")
                UIPersistenceService.persistLastOpenedLibrary(nil)
                return
            }
            
            // Attempt to open library
            do {
                let openedLibrary = try LibraryStatusService.openLibrary(at: restoredPath)
                appState.setOpenedLibrary(path: restoredPath, context: openedLibrary)
                appState.selectedLibraryPath = restoredPath
            } catch {
                // Library open failed
                appState.clearOpenedLibrary(error: "Library no longer accessible: \(error.localizedDescription)")
                UIPersistenceService.persistLastOpenedLibrary(nil)
            }
        }
        .sheet(isPresented: $showCreateWizard) {
            CreateLibraryWizard(onCompletion: handleWizardCompletion)
        }
        .sheet(isPresented: $showAdoptWizard) {
            AdoptLibraryWizard(onCompletion: handleWizardCompletion)
        }
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
                        appState.persistState()
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
                        appState.persistState()
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
    
    private func handleWizardCompletion(libraryPath: String) {
        // Close wizard sheets
        showCreateWizard = false
        showAdoptWizard = false
        
        // Open library using LibraryStatusService
        do {
            let openedLibrary = try LibraryStatusService.openLibrary(at: libraryPath)
            appState.setOpenedLibrary(path: libraryPath, context: openedLibrary)
            appState.selectedLibraryPath = libraryPath
            appState.errorMessage = nil
            appState.persistState()
        } catch {
            appState.clearOpenedLibrary(error: "Failed to open library: \(error.localizedDescription)")
            appState.errorMessage = "Failed to open library: \(error.localizedDescription)"
        }
    }
}
