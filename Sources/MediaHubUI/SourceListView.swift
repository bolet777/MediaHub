//
//  SourceListView.swift
//  MediaHubUI
//
//  SwiftUI view for displaying source list
//

import SwiftUI
import MediaHub

struct SourceListView: View {
    @ObservedObject var sourceState: SourceState
    @StateObject private var detectionState = DetectionState()
    @StateObject private var importState = ImportState()
    let libraryRootURL: URL
    let libraryId: String
    @State private var showAttachSource = false
    @State private var selectedSourceForDetach: Source? = nil
    @State private var showDetachSource = false
    @State private var selectedSourceForDetection: Source? = nil
    @State private var previewedSource: Source? = nil
    
    let onImportComplete: (() -> Void)?
    
    init(sourceState: SourceState, libraryRootURL: URL, libraryId: String, onImportComplete: (() -> Void)? = nil) {
        self.sourceState = sourceState
        self.libraryRootURL = libraryRootURL
        self.libraryId = libraryId
        self.onImportComplete = onImportComplete
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Sources")
                    .font(.headline)
                Spacer()
                Button("Attach Source") {
                    showAttachSource = true
                }
            }
            .padding()
            
            if let error = detectionState.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
            }
            
            if sourceState.sources.isEmpty {
                VStack(spacing: 8) {
                    Text("No sources attached")
                        .foregroundColor(.secondary)
                    Text("Click 'Attach Source' to add a source folder")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(sourceState.sources, id: \.sourceId) { source in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(source.path)
                                .font(.body)
                            
                            HStack {
                                Text("Media types: \(formatMediaTypes(source.mediaTypes))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                if let lastDetected = source.lastDetectedAt {
                                    Text("Last detected: \(formatDate(lastDetected))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Never detected")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .contextMenu {
                            Button("Preview Detection") {
                                selectedSourceForDetection = source
                                previewedSource = source
                                Task {
                                    await previewDetection(for: source)
                                }
                            }
                            Button("Run Detection") {
                                selectedSourceForDetection = source
                                Task {
                                    await runDetection(for: source)
                                }
                            }
                            Button("Detach Source") {
                                selectedSourceForDetach = source
                                showDetachSource = true
                            }
                        }
                    }
                }
            }
        }
        .task {
            await sourceState.refreshSources(libraryRootURL: libraryRootURL, libraryId: libraryId)
        }
        .sheet(isPresented: $showAttachSource) {
            AttachSourceView(
                libraryRootURL: libraryRootURL,
                libraryId: libraryId,
                sourceState: sourceState,
                onComplete: {
                    showAttachSource = false
                }
            )
        }
        .sheet(isPresented: $showDetachSource) {
            if let source = selectedSourceForDetach {
                DetachSourceView(
                    source: source,
                    sourceState: sourceState,
                    libraryRootURL: libraryRootURL,
                    libraryId: libraryId,
                    onConfirm: {
                        showDetachSource = false
                        selectedSourceForDetach = nil
                    },
                    onCancel: {
                        showDetachSource = false
                        selectedSourceForDetach = nil
                    }
                )
            }
        }
        .sheet(isPresented: Binding(
            get: { detectionState.previewResult != nil },
            set: { 
                if !$0 { 
                    detectionState.previewResult = nil
                    detectionState.errorMessage = nil
                    previewedSource = nil
                }
            }
        )) {
            if let previewResult = detectionState.previewResult,
               let source = previewedSource {
                DetectionPreviewView(
                    detectionResult: previewResult,
                    detectionState: detectionState,
                    source: source,
                    libraryRootURL: libraryRootURL,
                    libraryId: libraryId
                )
            }
        }
        .sheet(isPresented: Binding(
            get: { detectionState.runResult != nil },
            set: { 
                if !$0 { 
                    detectionState.runResult = nil
                    detectionState.errorMessage = nil
                }
            }
        )) {
            if let runResult = detectionState.runResult {
                DetectionRunView(
                    detectionResult: runResult,
                    detectionState: detectionState,
                    importState: importState,
                    libraryRootURL: libraryRootURL,
                    libraryId: libraryId,
                    onImportComplete: onImportComplete
                )
            }
        }
        .sheet(isPresented: Binding(
            get: { importState.previewResult != nil },
            set: { 
                if !$0 { 
                    importState.previewResult = nil
                    importState.errorMessage = nil
                }
            }
        )) {
            if let previewResult = importState.previewResult {
                ImportPreviewView(
                    importResult: previewResult,
                    importState: importState,
                    libraryRootURL: libraryRootURL,
                    libraryId: libraryId,
                    onImportComplete: onImportComplete
                )
            }
        }
        .overlay {
            if detectionState.isPreviewing || detectionState.isRunning || importState.isPreviewing || importState.isExecuting {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.2))
            }
        }
    }
    
    private func previewDetection(for source: Source) async {
        detectionState.isPreviewing = true
        detectionState.errorMessage = nil
        
        do {
            let result = try await DetectionOrchestrator.previewDetection(
                source: source,
                libraryRootURL: libraryRootURL,
                libraryId: libraryId
            )
            
            detectionState.previewResult = result
            detectionState.isPreviewing = false
            // Refresh source list to show updated lastDetectedAt
            await sourceState.refreshSources(libraryRootURL: libraryRootURL, libraryId: libraryId)
        } catch {
            detectionState.errorMessage = error.localizedDescription
            detectionState.isPreviewing = false
        }
    }
    
    private func runDetection(for source: Source) async {
        detectionState.isRunning = true
        detectionState.errorMessage = nil
        
        do {
            let result = try await DetectionOrchestrator.runDetection(
                source: source,
                libraryRootURL: libraryRootURL,
                libraryId: libraryId,
                detectionState: detectionState
            )
            
            detectionState.runResult = result
            detectionState.isRunning = false
            // Refresh source list to show updated lastDetectedAt
            await sourceState.refreshSources(libraryRootURL: libraryRootURL, libraryId: libraryId)
        } catch {
            detectionState.errorMessage = error.localizedDescription
            detectionState.isRunning = false
        }
    }
    
    private func formatMediaTypes(_ mediaTypes: SourceMediaTypes?) -> String {
        guard let mediaTypes = mediaTypes else {
            return "both"
        }
        switch mediaTypes {
        case .images:
            return "images"
        case .videos:
            return "videos"
        case .both:
            return "both"
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}
