import Foundation
import MediaHub

struct AdoptPreviewOrchestrator {
    static func generatePreview(at path: String) async throws -> AdoptPreviewResult {
        do {
            let result = try await Task.detached {
                try LibraryAdopter.adoptLibrary(at: path, dryRun: true)
            }.value
            
            // Convert LibraryAdoptionResult to AdoptPreviewResult
            let metadataLocation = (path as NSString).appendingPathComponent(".mediahub/library.json")
            return AdoptPreviewResult(
                metadataLocation: metadataLocation,
                libraryId: result.metadata.libraryId,
                libraryVersion: result.metadata.libraryVersion,
                baselineScanSummary: result.baselineScan
            )
        } catch LibraryAdoptionError.alreadyAdopted {
            // Defensive catch: if validation (T-005) missed it, open existing library for preview
            let openedLibrary = try await Task.detached {
                try LibraryOpener().openLibrary(at: path)
            }.value
            
            // Construct preview result from opened library (idempotent case)
            // Use empty baseline scan for preview (library already exists)
            let baselineScan = BaselineScanSummary(fileCount: 0, filePaths: [])
            let metadataLocation = (path as NSString).appendingPathComponent(".mediahub/library.json")
            return AdoptPreviewResult(
                metadataLocation: metadataLocation,
                libraryId: openedLibrary.metadata.libraryId,
                libraryVersion: openedLibrary.metadata.libraryVersion,
                baselineScanSummary: baselineScan
            )
        }
        // Other errors are propagated
    }
}
