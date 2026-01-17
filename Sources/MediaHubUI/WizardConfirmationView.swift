import SwiftUI

struct WizardConfirmationView: View {
    let createPreviewResult: CreatePreviewResult?
    let adoptPreviewResult: AdoptPreviewResult?
    let isForAdopt: Bool
    let isExecuting: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(isForAdopt ? "Adopt Library" : "Create Library")
                .font(.title2)
                .fontWeight(.bold)
            
            if isForAdopt {
                if let result = adoptPreviewResult {
                    VStack(alignment: .leading, spacing: 12) {
                        LabeledContent("Metadata Location:") {
                            Text(result.metadataLocation)
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        LabeledContent("Library ID:") {
                            Text(result.libraryId)
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        LabeledContent("Baseline Scan:") {
                            Text("\(result.baselineScanSummary.fileCount) files")
                        }
                    }
                }
                
                Text("No media files will be modified; only .mediahub metadata will be created")
                    .foregroundColor(.secondary)
                    .padding(.top)
            } else {
                if let result = createPreviewResult {
                    VStack(alignment: .leading, spacing: 12) {
                        LabeledContent("Metadata Location:") {
                            Text(result.metadataLocation)
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        LabeledContent("Library ID:") {
                            Text(result.libraryId)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                }
            }
            
            Spacer()
            
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                
                Spacer()
                
                Button(isForAdopt ? "Adopt" : "Create") {
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isExecuting)
            }
        }
        .padding()
    }
}
