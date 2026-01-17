//
//  ImportConfirmationView.swift
//  MediaHubUI
//
//  Confirmation dialog for import execution
//

import SwiftUI
import MediaHub

struct ImportConfirmationView: View {
    let importResult: ImportResult
    @ObservedObject var importState: ImportState
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Confirm Import")
                .font(.headline)
            
            Text("Are you sure you want to import these items?")
                .font(.body)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Summary:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("Item count: \(importResult.summary.total)")
                Text("Total size: N/A") // Size not available
            }
            
            Spacer()
            
            if let error = importState.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
            }
            
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .disabled(importState.isExecuting)
                
                Spacer()
                
                Button("Import") {
                    onConfirm()
                }
                .disabled(importState.isExecuting)
                
                if importState.isExecuting {
                    ProgressView()
                        .padding(.leading)
                }
            }
        }
        .padding()
        .frame(width: 500, height: 300)
    }
}
