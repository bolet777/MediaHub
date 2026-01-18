//
//  ImportOrchestrator.swift
//  MediaHubUI
//
//  Import orchestration for Core API calls
//

import Foundation
import MediaHub

struct ImportOrchestrator {
    static func previewImport(
        detectionResult: DetectionResult,
        libraryRootURL: URL,
        libraryId: String
    ) async throws -> ImportResult {
        // Get all candidate items (matching CLI `import --all` behavior)
        let selectedItems = detectionResult.candidates
            .filter { $0.status == "new" }
            .map { $0.item }
        
        let options = ImportOptions(collisionPolicy: .rename)
        
        return try await Task.detached {
            try ImportExecutor.executeImport(
                detectionResult: detectionResult,
                selectedItems: selectedItems,
                libraryRootURL: libraryRootURL,
                libraryId: libraryId,
                options: options,
                dryRun: true
            )
        }.value
    }
    
    static func executeImport(
        detectionResult: DetectionResult,
        libraryRootURL: URL,
        libraryId: String,
        importState: ImportState
    ) async throws -> ImportResult {
        // Create cancellation token when operation starts
        let cancellationToken = CancellationToken()
        await MainActor.run {
            importState.cancellationToken = cancellationToken
            importState.isCanceling = false
            importState.progressStage = nil
            importState.progressCurrent = nil
            importState.progressTotal = nil
            importState.progressMessage = nil
        }
        
        // Create progress callback that forwards to MainActor
        let progressCallback: ((ProgressUpdate) -> Void)? = { progressUpdate in
            Task { @MainActor in
                importState.progressStage = progressUpdate.stage
                importState.progressCurrent = progressUpdate.current
                importState.progressTotal = progressUpdate.total
                importState.progressMessage = progressUpdate.message
            }
        }
        
        // Get all candidate items (matching CLI `import --all` behavior)
        let selectedItems = detectionResult.candidates
            .filter { $0.status == "new" }
            .map { $0.item }
        
        let options = ImportOptions(collisionPolicy: .rename)
        
        do {
            let result = try await Task.detached {
                try ImportExecutor.executeImport(
                    detectionResult: detectionResult,
                    selectedItems: selectedItems,
                    libraryRootURL: libraryRootURL,
                    libraryId: libraryId,
                    options: options,
                    dryRun: false,
                    progress: progressCallback,
                    cancellationToken: cancellationToken
                )
            }.value
            
            // Clear cancellation token when operation completes
            await MainActor.run {
                importState.cancellationToken = nil
            }
            
            return result
        } catch let error as CancellationError {
            // Handle cancellation error
            await MainActor.run {
                importState.isCanceling = true
                importState.errorMessage = "Operation canceled"
                importState.cancellationToken = nil
            }
            throw error
        } catch {
            // Clear cancellation token on other errors
            await MainActor.run {
                importState.cancellationToken = nil
            }
            throw error
        }
    }
}
