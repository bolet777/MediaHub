//
//  DetectionPreviewView.swift
//  MediaHubUI
//
//  SwiftUI view for displaying detection preview results
//

import SwiftUI
import MediaHub

struct DetectionPreviewView: View {
    let detectionResult: DetectionResult
    @ObservedObject var detectionState: DetectionState
    let source: Source
    let libraryRootURL: URL
    let libraryId: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Detection Preview")
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
            
            Text("Preview updates detection timestamp and stores results.")
                .font(.caption)
                .foregroundColor(.secondary)
            
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
            }
            
            if let error = detectionState.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
            }
            
            Spacer()
            
            Button("Run Detection") {
                Task {
                    await runDetection()
                }
            }
            .disabled(detectionState.isRunning)
            
            if detectionState.isRunning {
                ProgressView()
                    .padding()
            }
        }
        .padding()
        .frame(width: 600, height: 500)
    }
    
    private func runDetection() async {
        detectionState.isRunning = true
        detectionState.errorMessage = nil
        
        do {
            let result = try await DetectionOrchestrator.runDetection(
                source: source,
                libraryRootURL: libraryRootURL,
                libraryId: libraryId
            )
            
            // Clear preview sheet before showing run sheet
            detectionState.previewResult = nil
            detectionState.runResult = result
            detectionState.isRunning = false
        } catch {
            detectionState.errorMessage = "Failed to run detection: \(error.localizedDescription)"
            detectionState.isRunning = false
        }
    }
}
