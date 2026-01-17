import SwiftUI

struct WizardPreviewView: View {
    let createPreviewResult: CreatePreviewResult?
    let adoptPreviewResult: AdoptPreviewResult?
    let isForAdopt: Bool
    let isLoading: Bool
    let errorMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Preview indicator
            HStack {
                Label("Preview", systemImage: "eye")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            if isLoading {
                ProgressView("Generating preview...")
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            } else if isForAdopt, let result = adoptPreviewResult {
                AdoptPreviewContent(result: result)
            } else if !isForAdopt, let result = createPreviewResult {
                CreatePreviewContent(result: result)
            } else {
                Text("No preview available")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

private struct CreatePreviewContent: View {
    let result: CreatePreviewResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Create Library")
                .font(.headline)
            
            LabeledContent("Metadata Location:") {
                Text(result.metadataLocation)
                    .font(.system(.body, design: .monospaced))
            }
            
            LabeledContent("Library ID:") {
                Text(result.libraryId)
                    .font(.system(.body, design: .monospaced))
            }
            
            LabeledContent("Library Version:") {
                Text(result.libraryVersion)
            }
        }
    }
}

private struct AdoptPreviewContent: View {
    let result: AdoptPreviewResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Adopt Library")
                .font(.headline)
            
            LabeledContent("Metadata Location:") {
                Text(result.metadataLocation)
                    .font(.system(.body, design: .monospaced))
            }
            
            LabeledContent("Library ID:") {
                Text(result.libraryId)
                    .font(.system(.body, design: .monospaced))
            }
            
            LabeledContent("Library Version:") {
                Text(result.libraryVersion)
            }
            
            LabeledContent("Baseline Scan:") {
                Text("\(result.baselineScanSummary.fileCount) files")
            }
        }
    }
}
