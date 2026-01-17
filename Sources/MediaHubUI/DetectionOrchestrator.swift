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
}
