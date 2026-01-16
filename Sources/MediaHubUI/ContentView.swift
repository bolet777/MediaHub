import SwiftUI

struct ContentView: View {
    @ObservedObject var appState: AppState
    
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
                if let errorMessage = appState.errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                } else if let selectedPath = appState.selectedLibraryPath {
                    Text("Selected Library")
                        .font(.headline)
                    Text(selectedPath)
                        .font(.body)
                        .foregroundColor(.secondary)
                } else {
                    Text("Welcome to MediaHub")
                        .font(.largeTitle)
                    Text("Select a folder to discover libraries")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("MediaHub")
    }
}
