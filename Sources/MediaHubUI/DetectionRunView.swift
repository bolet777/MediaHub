//
//  DetectionRunView.swift
//  MediaHubUI
//
//  SwiftUI view for displaying detection run results
//

import SwiftUI
import MediaHub

struct DetectionRunView: View {
    let detectionResult: DetectionResult
    @ObservedObject var detectionState: DetectionState
    @StateObject private var importState = ImportState()
    let libraryRootURL: URL
    let libraryId: String
    let onImportComplete: (() -> Void)?
    
    init(detectionResult: DetectionResult, detectionState: DetectionState, importState: ImportState? = nil, libraryRootURL: URL, libraryId: String, onImportComplete: (() -> Void)? = nil) {
        self.detectionResult = detectionResult
        self.detectionState = detectionState
        self.libraryRootURL = libraryRootURL
        self.libraryId = libraryId
        self.onImportComplete = onImportComplete
        // Note: importState parameter is ignored, we create our own instance
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Detection Complete")
                .font(.headline)
            
            Text("Detection completed successfully")
                .foregroundColor(.green)
                .font(.subheadline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Detection Statistics")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("Total scanned items: \(detectionResult.summary.totalScanned)")
                Text("New items: \(detectionResult.summary.newItems)")
                Text("Known items: \(detectionResult.summary.knownItems)")
                
                let duplicates = detectionResult.candidates.filter { $0.duplicateReason == "content_hash" }
                if !duplicates.isEmpty {
                    Text("Duplicates: \(duplicates.count)")
                }
            }
            
            let newItems = detectionResult.candidates.filter { $0.status == "new" }
            if !newItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("New Items")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(newItems.prefix(100)), id: \.item.path) { candidate in
                                Text(candidate.item.path)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if newItems.count > 100 {
                                Text("... and \(newItems.count - 100) more")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
                
                if let error = importState.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding()
                }
                
                Button("Preview Import") {
                    Task {
                        await previewImport()
                    }
                }
                .disabled(importState.isPreviewing)
                
                if importState.isPreviewing {
                    ProgressView()
                        .padding()
                }
            }
        }
        .padding()
        .frame(width: 600, height: 500)
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
    }
    
    @MainActor
    private func previewImport() async {
        importState.isPreviewing = true
        importState.errorMessage = nil
        
        do {
            // Store detectionResult for later use in executeImport
            importState.detectionResult = detectionResult
            
            let result = try await ImportOrchestrator.previewImport(
                detectionResult: detectionResult,
                libraryRootURL: libraryRootURL,
                libraryId: libraryId
            )
            
            // Dismiss DetectionRun sheet FIRST, then present ImportPreview sheet
            // This ensures only ONE sheet trigger is active at a time
            detectionState.runResult = nil
            importState.previewResult = result
            importState.isPreviewing = false
        } catch {
            importState.errorMessage = "Failed to preview import: \(error.localizedDescription)"
            importState.isPreviewing = false
        }
    }
}
