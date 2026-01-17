import Foundation
import MediaHub

struct AdoptExecutionOrchestrator {
    static func executeAdopt(at path: String) async throws -> LibraryAdoptionResult {
        do {
            return try await Task.detached {
                try LibraryAdopter.adoptLibrary(at: path, dryRun: false)
            }.value
        } catch LibraryAdoptionError.alreadyAdopted {
            // Defensive catch: if validation missed it, open existing library and return its metadata
            let openedLibrary = try await Task.detached {
                try LibraryOpener().openLibrary(at: path)
            }.value
            
            // Construct LibraryAdoptionResult from opened library metadata
            // Use empty baseline scan (library already exists, no new scan needed)
            let baselineScan = BaselineScanSummary(fileCount: 0, filePaths: [])
            return LibraryAdoptionResult(
                metadata: openedLibrary.metadata,
                baselineScan: baselineScan,
                indexCreated: false,
                indexSkippedReason: "already_adopted",
                indexMetadata: nil
            )
        } catch let error as LibraryAdoptionError {
            // Map error to user-facing message
            throw mapError(error)
        }
        // Other errors are propagated as-is
    }
    
    private static func mapError(_ error: LibraryAdoptionError) -> Error {
        let message: String
        switch error {
        case .invalidPath:
            message = "Invalid path specified"
        case .pathDoesNotExist:
            message = "Path does not exist"
        case .pathIsNotDirectory:
            message = "Path is not a directory"
        case .permissionDenied:
            message = "Permission denied accessing path"
        case .alreadyAdopted:
            // This should be handled above, but include for completeness
            message = "Library is already adopted"
        case .metadataCreationFailed(let underlyingError):
            message = "Failed to create library metadata: \(underlyingError.localizedDescription)"
        case .metadataWriteFailed(let underlyingError):
            message = "Failed to write library metadata: \(underlyingError.localizedDescription)"
        case .rollbackFailed(let underlyingError):
            message = "Failed to rollback library adoption: \(underlyingError.localizedDescription)"
        }
        
        return NSError(
            domain: "MediaHub",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
