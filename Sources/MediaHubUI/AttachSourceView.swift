//
//  AttachSourceView.swift
//  MediaHubUI
//
//  Attach source view with folder picker and media type selection
//

import SwiftUI
import AppKit
import MediaHub

struct AttachSourceView: View {
    let libraryRootURL: URL
    let libraryId: String
    @Binding var sourceState: SourceState
    let onComplete: () -> Void
    
    @State private var selectedPath: String? = nil
    @State private var selectedMediaTypes: SourceMediaTypes = .both
    @State private var errorMessage: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Attach Source")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Select a folder to attach as a source")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    if let path = selectedPath {
                        Text(path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else {
                        Text("No folder selected")
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Choose Folder…") {
                        chooseFolder()
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Media Types")
                        .font(.subheadline)
                    
                    Picker("Media Types", selection: $selectedMediaTypes) {
                        Text("Images").tag(SourceMediaTypes.images)
                        Text("Videos").tag(SourceMediaTypes.videos)
                        Text("Both").tag(SourceMediaTypes.both)
                    }
                    .pickerStyle(.segmented)
                }
            }
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            if sourceState.isAttaching {
                ProgressView()
                    .padding()
            }
            
            Spacer()
            
            HStack {
                Button("Cancel") {
                    onComplete()
                }
                
                Spacer()
                
                Button("Attach") {
                    Task {
                        await attachSource()
                    }
                }
                .disabled(selectedPath == nil || sourceState.isAttaching)
            }
        }
        .padding()
        .frame(width: 500, height: 300)
    }
    
    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Choose Source Folder"
        panel.message = "Select a folder to attach as a source"
        
        if panel.runModal() == .OK, let url = panel.url {
            selectedPath = url.path
            errorMessage = nil
        }
    }
    
    private func attachSource() async {
        guard let path = selectedPath else {
            return
        }
        
        // Validate path
        let validationResult = SourcePathValidator.validateSourcePath(path, existingSources: sourceState.sources)
        switch validationResult {
        case .invalid(let message):
            errorMessage = message
            return
        case .valid:
            break
        }
        
        sourceState.isAttaching = true
        errorMessage = nil
        
        do {
            _ = try await SourceOrchestrator.attachSource(
                path: path,
                mediaTypes: selectedMediaTypes,
                libraryRootURL: libraryRootURL,
                libraryId: libraryId
            )
            
            // Refresh source list
            await sourceState.refreshSources(libraryRootURL: libraryRootURL, libraryId: libraryId)
            
            // Close view
            onComplete()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        sourceState.isAttaching = false
    }
}
