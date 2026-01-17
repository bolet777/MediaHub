//
//  DetachSourceView.swift
//  MediaHubUI
//
//  Confirmation dialog for source detachment
//

import SwiftUI
import MediaHub

struct DetachSourceView: View {
    let source: Source
    @ObservedObject var sourceState: SourceState
    let libraryRootURL: URL
    let libraryId: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Detach Source")
                .font(.headline)
            
            Text("Are you sure you want to detach this source?")
                .font(.body)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Source Path:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(source.path)
                    .font(.body)
                
                Text("Media Types:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(formatMediaTypes(source.mediaTypes))
                    .font(.body)
            }
            
            if sourceState.isDetaching {
                ProgressView()
                    .padding()
            }
            
            if let error = sourceState.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            Spacer()
            
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                
                Spacer()
                
                Button("Detach") {
                    Task {
                        await detachSource()
                    }
                }
                .disabled(sourceState.isDetaching)
            }
        }
        .padding()
        .frame(width: 500, height: 300)
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
    
    private func detachSource() async {
        sourceState.isDetaching = true
        
        do {
            try await SourceOrchestrator.detachSource(
                sourceId: source.sourceId,
                libraryRootURL: libraryRootURL,
                libraryId: libraryId
            )
            
            // Refresh source list
            await sourceState.refreshSources(libraryRootURL: libraryRootURL, libraryId: libraryId)
            
            // Close dialog
            onConfirm()
        } catch {
            sourceState.errorMessage = error.localizedDescription
        }
        
        sourceState.isDetaching = false
    }
}
