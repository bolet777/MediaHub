//
//  DetectionState.swift
//  MediaHubUI
//
//  Detection state management
//

import SwiftUI
import MediaHub

@MainActor
class DetectionState: ObservableObject {
    @Published var previewResult: DetectionResult? = nil
    @Published var runResult: DetectionResult? = nil
    @Published var isPreviewing: Bool = false
    @Published var isRunning: Bool = false
    @Published var errorMessage: String? = nil
}
