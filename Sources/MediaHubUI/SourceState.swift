//
//  SourceState.swift
//  MediaHubUI
//
//  Source state management for source list and operations
//

import SwiftUI
import MediaHub

@MainActor
class SourceState: ObservableObject {
    @Published var sources: [Source] = []
    @Published var isAttaching: Bool = false
    @Published var isDetaching: Bool = false
    @Published var errorMessage: String? = nil
    
    func refreshSources(libraryRootURL: URL, libraryId: String) async {
        do {
            let loadedSources = try await SourceOrchestrator.loadSources(
                libraryRootURL: libraryRootURL,
                libraryId: libraryId
            )
            self.sources = loadedSources
            self.errorMessage = nil
        } catch {
            self.errorMessage = "Failed to load sources: \(error.localizedDescription)"
        }
    }
}
