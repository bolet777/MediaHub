import Foundation
import MediaHub

struct WizardConfirmationHandler: LibraryCreationConfirmationHandler {
    func requestConfirmationForNonEmptyDirectory(
        at path: String,
        completion: @escaping (Bool) -> Void
    ) {
        // Auto-confirm: wizard handles confirmation in UI
        completion(true)
    }
    
    func requestConfirmationForExistingLibrary(
        at path: String,
        completion: @escaping (Bool) -> Void
    ) {
        // Don't open existing library: wizard shows error
        completion(false)
    }
}
