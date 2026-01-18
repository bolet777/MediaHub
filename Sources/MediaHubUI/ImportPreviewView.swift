//
//  ImportPreviewView.swift
//  MediaHubUI
//
//  SwiftUI view for displaying import preview results
//

import SwiftUI
import MediaHub

struct ImportPreviewView: View {
    let importResult: ImportResult
    @ObservedObject var importState: ImportState
    let libraryRootURL: URL
    let libraryId: String
    let onImportComplete: (() -> Void)?
    @State private var showConfirmation: Bool = false
    
    init(importResult: ImportResult, importState: ImportState, libraryRootURL: URL, libraryId: String, onImportComplete: (() -> Void)? = nil) {
        self.importResult = importResult
        self.importState = importState
        self.libraryRootURL = libraryRootURL
        self.libraryId = libraryId
        self.onImportComplete = onImportComplete
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Import Preview")
                    .font(.headline)
                Spacer()
                Text("PREVIEW")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .foregroundColor(.orange)
                    .cornerRadius(4)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Import Statistics")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("Items to import: \(importResult.summary.total)")
                Text("Total size: N/A") // Size not available in ImportResult
            }
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(importResult.items.prefix(100)), id: \.sourcePath) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.sourcePath)
                                .font(.caption)
                            if let dest = item.destinationPath {
                                Text("→ \(dest)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    if importResult.items.count > 100 {
                        Text("... and \(importResult.items.count - 100) more")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxHeight: 300)
            
            if let error = importState.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
            }
            
            Spacer()
            
            Button("Confirm Import") {
                showConfirmation = true
            }
            .disabled(importState.isExecuting)
            
            if importState.isExecuting {
                ProgressView()
                    .padding()
            }
        }
        .padding()
        .frame(width: 600, height: 500)
        .sheet(isPresented: $showConfirmation) {
            ImportConfirmationView(
                importResult: importResult,
                importState: importState,
                onConfirm: {
                    Task {
                        await executeImport()
                    }
                },
                onCancel: {
                    showConfirmation = false
                }
            )
        }
        .sheet(isPresented: Binding(
            get: { importState.executionResult != nil },
            set: { 
                if !$0 { 
                    importState.executionResult = nil
                    importState.errorMessage = nil
                }
            }
        )) {
            if let executionResult = importState.executionResult {
                ImportExecutionView(
                    importResult: executionResult,
                    importState: importState,
                    onDone: {
                        // Clean up deterministically: clear execution result first
                        importState.executionResult = nil
                        // Clear preview result so the preview sheet dismisses cleanly
                        importState.previewResult = nil
                        // Clear any errors
                        importState.errorMessage = nil
                        // Call completion handler
                        onImportComplete?()
                    }
                )
            }
        }
    }
    
    private func executeImport() async {
        guard let detectionResult = importState.detectionResult else {
            importState.errorMessage = "Import failed: Detection result not available."
            showConfirmation = false
            return
        }
        
        importState.isExecuting = true
        importState.errorMessage = nil
        
        do {
            let result = try await ImportOrchestrator.executeImport(
                detectionResult: detectionResult,
                libraryRootURL: libraryRootURL,
                libraryId: libraryId,
                importState: importState
            )
            
            // Present execution sheet first by setting executionResult
            importState.executionResult = result
            importState.isExecuting = false
            showConfirmation = false
            
            // Notify completion handler to refresh library status
            onImportComplete?()
        } catch {
            importState.errorMessage = "Import failed. Please try again."
            importState.isExecuting = false
            // Keep confirmation view open so user can retry or cancel
        }
    }
}
