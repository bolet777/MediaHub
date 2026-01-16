import SwiftUI

@main
struct MediaHubUIApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 800, height: 600)
    }
}

struct ContentView: View {
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
            // Right detail: empty state
            VStack(spacing: 16) {
                Text("Welcome to MediaHub")
                    .font(.largeTitle)
                Text("Select a folder to discover libraries")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("MediaHub")
    }
}
