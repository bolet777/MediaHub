//
//  ImportExecutionView.swift
//  MediaHubUI
//
//  SwiftUI view for displaying import execution results
//

import SwiftUI
import MediaHub

struct ImportExecutionView: View {
    let importResult: ImportResult?
    @ObservedObject var importState: ImportState
    let onDone: () -> Void
    
    init(importResult: ImportResult? = nil, importState: ImportState, onDone: @escaping () -> Void) {
        self.importResult = importResult
        self.importState = importState
        self.onDone = onDone
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Progress UI (shown when import is in progress)
            if importState.isExecuting {
                VStack(alignment: .leading, spacing: 8) {
                    // Progress bar
                    if let current = importState.progressCurrent,
                       let total = importState.progressTotal {
                        ProgressView(value: Double(current), total: Double(total)) {
                            if let message = importState.progressMessage {
                                Text(message)
                                    .font(.caption)
                            } else if let stage = importState.progressStage {
                                Text(stage.capitalized + "...")
                                    .font(.caption)
                            }
                        }
                    } else {
                        ProgressView()
                    }
                    
                    // Cancel button
                    if let token = importState.cancellationToken {
                        Button(importState.isCanceling ? "Canceling..." : "Cancel") {
                            token.cancel()
                        }
                        .disabled(importState.isCanceling)
                    }
                }
                .padding()
            }
            
            // Error message display
            if let error = importState.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
            }
            
            // Import results (shown when import completes)
            if let result = importResult, !importState.isExecuting {
                Text("Import Complete")
                    .font(.headline)
                
                Text("Import completed successfully")
                    .foregroundColor(.green)
                    .font(.subheadline)
            
                VStack(alignment: .leading, spacing: 8) {
                    Text("Import Statistics")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("Successful imports: \(result.summary.imported)")
                    Text("Failed imports: \(result.summary.failed)")
                    Text("Skipped items: \(result.summary.skipped)")
                    
                    let collisions = result.items.filter { $0.status == .skipped && $0.reason?.contains("collision") == true }
                    if !collisions.isEmpty {
                        Text("Collisions: \(collisions.count)")
                    }
                }
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(result.items.prefix(100)), id: \.sourcePath) { item in
                            HStack {
                                Text(item.sourcePath)
                                    .font(.caption)
                                Spacer()
                                Text(item.status.rawValue)
                                    .font(.caption2)
                                    .foregroundColor(item.status == .imported ? .green : (item.status == .failed ? .red : .orange))
                            }
                        }
                        if result.items.count > 100 {
                            Text("... and \(result.items.count - 100) more")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxHeight: 300)
                
                Spacer()
                
                Button("Done") {
                    onDone()
                }
            }
        }
        .padding()
        .frame(width: 600, height: 500)
    }
}
