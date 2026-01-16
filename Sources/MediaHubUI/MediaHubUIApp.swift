import SwiftUI

@main
struct MediaHubUIApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState)
        }
        .defaultSize(width: 800, height: 600)
    }
}
