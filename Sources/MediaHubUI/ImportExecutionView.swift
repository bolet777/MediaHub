//
//  ImportExecutionView.swift
//  MediaHubUI
//
//  SwiftUI view for displaying import execution results
//

import SwiftUI
import MediaHub

struct ImportExecutionView: View {
    let importResult: ImportResult
    let onDone: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Import Complete")
                .font(.headline)
            
            Text("Import completed successfully")
                .foregroundColor(.green)
                .font(.subheadline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Import Statistics")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("Successful imports: \(importResult.summary.imported)")
                Text("Failed imports: \(importResult.summary.failed)")
                Text("Skipped items: \(importResult.summary.skipped)")
                
                let collisions = importResult.items.filter { $0.status == .skipped && $0.reason?.contains("collision") == true }
                if !collisions.isEmpty {
                    Text("Collisions: \(collisions.count)")
                }
            }
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(importResult.items.prefix(100)), id: \.sourcePath) { item in
                        HStack {
                            Text(item.sourcePath)
                                .font(.caption)
                            Spacer()
                            Text(item.status.rawValue)
                                .font(.caption2)
                                .foregroundColor(item.status == .imported ? .green : (item.status == .failed ? .red : .orange))
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
            
            Spacer()
            
            Button("Done") {
                onDone()
            }
        }
        .padding()
        .frame(width: 600, height: 500)
    }
}
