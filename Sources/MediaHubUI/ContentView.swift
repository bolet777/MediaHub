import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationSplitView {
            // Left sidebar: placeholder "Libraries"
            VStack {
                Text("Libraries")
                    .font(.headline)
                    .padding()
                Spacer()
            }
            .frame(minWidth: 200)
        } detail: {
            // Right detail: empty state or selected library
            VStack(spacing: 16) {
                if let selectedPath = appState.selectedLibraryPath {
                    Text("Selected: \(selectedPath)")
                } else {
                    Text("Welcome to MediaHub")
                        .font(.largeTitle)
                    Text("Select a folder to discover libraries")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                if let errorMessage = appState.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("MediaHub")
    }
}
