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
    @Published var progressStage: String? = nil
    @Published var progressCurrent: Int? = nil
    @Published var progressTotal: Int? = nil
    @Published var progressMessage: String? = nil
    var cancellationToken: CancellationToken? = nil
    @Published var isCanceling: Bool = false
}
