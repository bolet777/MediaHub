//
//  DetectionOrchestrator.swift
//  MediaHubUI
//
//  Detection orchestration for Core API calls
//

import Foundation
import MediaHub

struct DetectionOrchestrator {
    static func previewDetection(
        source: Source,
        libraryRootURL: URL,
        libraryId: String
    ) async throws -> DetectionResult {
        return try await Task.detached {
            try MediaHub.DetectionOrchestrator.executeDetection(
                source: source,
                libraryRootURL: libraryRootURL,
                libraryId: libraryId
            )
        }.value
    }
    
    static func runDetection(
        source: Source,
        libraryRootURL: URL,
        libraryId: String,
        detectionState: DetectionState
    ) async throws -> DetectionResult {
        // Create cancellation token when operation starts
        let cancellationToken = CancellationToken()
        await MainActor.run {
            detectionState.cancellationToken = cancellationToken
            detectionState.isCanceling = false
            detectionState.progressStage = nil
            detectionState.progressCurrent = nil
            detectionState.progressTotal = nil
            detectionState.progressMessage = nil
        }
        
        // Create progress callback that forwards to MainActor
        let progressCallback: ((ProgressUpdate) -> Void)? = { progressUpdate in
            Task { @MainActor in
                detectionState.progressStage = progressUpdate.stage
                detectionState.progressCurrent = progressUpdate.current
                detectionState.progressTotal = progressUpdate.total
                detectionState.progressMessage = progressUpdate.message
            }
        }
        
        do {
            let result = try await Task.detached {
                try MediaHub.DetectionOrchestrator.executeDetection(
                    source: source,
                    libraryRootURL: libraryRootURL,
                    libraryId: libraryId,
                    progress: progressCallback,
                    cancellationToken: cancellationToken
                )
            }.value
            
            // Clear cancellation token when operation completes
            await MainActor.run {
                detectionState.cancellationToken = nil
            }
            
            return result
        } catch let error as CancellationError {
            // Handle cancellation error
            await MainActor.run {
                detectionState.isCanceling = true
                detectionState.errorMessage = "Operation canceled"
                detectionState.cancellationToken = nil
            }
            throw error
        } catch {
            // Clear cancellation token on other errors
            await MainActor.run {
                detectionState.cancellationToken = nil
            }
            throw error
        }
    }
}
