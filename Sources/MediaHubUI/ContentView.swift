import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationSplitView {
            // Left sidebar: placeholder "Libraries"
            VStack(alignment: .leading, spacing: 8) {
                Text("Libraries")
                    .font(.headline)
                    .padding()
                
                Text("(No libraries yet)")
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                Spacer()
            }
            .frame(minWidth: 200)
        } detail: {
            // Right detail: empty state or selected library
            VStack(spacing: 16) {
                if let errorMessage = appState.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
                
                if let selectedPath = appState.selectedLibraryPath {
                    Text("Selected: \(selectedPath)")
                } else {
                    EmptyStateView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("MediaHub")
    }
}
