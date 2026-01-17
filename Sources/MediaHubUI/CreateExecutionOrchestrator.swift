import Foundation
import MediaHub

struct CreateExecutionOrchestrator {
    static func executeCreate(
        at path: String,
        completion: @escaping (Result<LibraryMetadata, Error>) -> Void
    ) {
        // Create custom confirmation handler
        let confirmationHandler = WizardConfirmationHandler()
        
        // Create LibraryCreator with custom handler
        let creator = LibraryCreator(confirmationHandler: confirmationHandler)
        
        // Invoke Core API off MainActor
        Task.detached {
            creator.createLibrary(at: path, libraryVersion: "1.0") { result in
                switch result {
                case .success(let metadata):
                    completion(.success(metadata))
                case .failure(let error):
                    // Map error to user-facing message
                    let mappedError = mapError(error)
                    completion(.failure(mappedError))
                }
            }
        }
    }
    
    private static func mapError(_ error: LibraryCreationError) -> Error {
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
        case .existingLibraryFound:
            message = "This location already contains a MediaHub library"
        case .nonEmptyDirectory:
            message = "Directory is not empty"
        case .directoryCreationFailed(let underlyingError):
            message = "Failed to create directory: \(underlyingError.localizedDescription)"
        case .metadataWriteFailed(let underlyingError):
            message = "Failed to write library metadata: \(underlyingError.localizedDescription)"
        case .rollbackFailed(let underlyingError):
            message = "Failed to rollback library creation: \(underlyingError.localizedDescription)"
        case .insufficientDiskSpace:
            message = "Insufficient disk space"
        case .userCancelled:
            message = "Library creation cancelled by user"
        }
        
        return NSError(
            domain: "MediaHub",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
