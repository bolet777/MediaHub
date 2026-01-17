import SwiftUI
import AppKit

struct WizardPathSelectionView: View {
    @Binding var selectedPath: String?
    @Binding var errorMessage: String?
    let isForAdopt: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isForAdopt ? "Select directory to adopt" : "Select directory for new library")
                .font(.headline)
            
            HStack {
                TextField("No folder selected", text: Binding(
                    get: { selectedPath ?? "" },
                    set: { _ in }
                ))
                .disabled(true)
                
                Button("Choose Folder…") {
                    chooseFolder()
                }
            }
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding()
    }
    
    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.title = isForAdopt ? "Choose Directory to Adopt" : "Choose Directory for New Library"
        panel.message = isForAdopt ? "Select a directory to adopt as a MediaHub library" : "Select a directory where the new library will be created"
        
        if panel.runModal() == .OK, let url = panel.url {
            selectedPath = url.path
        }
    }
}
