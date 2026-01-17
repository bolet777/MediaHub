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
                dryRun: false
            )
        }.value
    }
}
