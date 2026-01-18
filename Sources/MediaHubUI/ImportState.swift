//
//  ImportState.swift
//  MediaHubUI
//
//  Import state management
//

import SwiftUI
import MediaHub

@MainActor
class ImportState: ObservableObject {
    @Published var previewResult: ImportResult? = nil
    @Published var executionResult: ImportResult? = nil
    @Published var isPreviewing: Bool = false
    @Published var isExecuting: Bool = false
    @Published var errorMessage: String? = nil
    var detectionResult: DetectionResult? = nil
    @Published var progressStage: String? = nil
    @Published var progressCurrent: Int? = nil
    @Published var progressTotal: Int? = nil
    @Published var progressMessage: String? = nil
    var cancellationToken: CancellationToken? = nil
    @Published var isCanceling: Bool = false
}
