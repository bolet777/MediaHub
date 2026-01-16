import Foundation
import MediaHub

struct LibraryStatusService {
    /// Opens and validates a library at the given path.
    /// - Parameter path: The library path to open
    /// - Returns: The opened library context
    /// - Throws: LibraryOpeningError if opening fails
    static func openLibrary(at path: String) throws -> OpenedLibrary {
        let opener = LibraryOpener()
        return try opener.openLibrary(at: path)
    }
}
