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
    
    /// Loads library status from an opened library using Core APIs.
    /// - Parameters:
    ///   - opened: The opened library context
    ///   - libraryPath: The library root path
    /// - Returns: LibraryStatus with available information
    /// - Throws: Never (all errors are handled by returning nil values)
    static func loadStatus(from opened: OpenedLibrary, libraryPath: String) throws -> LibraryStatus {
        // Try to load baseline index
        let indexState = BaselineIndexLoader.tryLoadBaselineIndex(libraryRoot: libraryPath)
        
        switch indexState {
        case .valid(let index):
            // Baseline index is present and valid
            let isBaselineIndexPresent = true
            
            // Check if hash index is present (version 1.1 or has entries with hashes)
            let isHashIndexPresent = index.version == "1.1" || index.hashEntryCount > 0
            
            // Items count from index entry count
            let itemsCount = index.entryCount
            
            // Try to parse lastUpdated as Date (optional, can be nil)
            let lastScanDate: Date?
            let formatter = ISO8601DateFormatter()
            lastScanDate = formatter.date(from: index.lastUpdated)
            
            return LibraryStatus(
                libraryPath: libraryPath,
                isBaselineIndexPresent: isBaselineIndexPresent,
                isHashIndexPresent: isHashIndexPresent,
                itemsCount: itemsCount,
                lastScanDate: lastScanDate
            )
            
        case .absent, .invalid:
            // Baseline index is not present or invalid
            return LibraryStatus(
                libraryPath: libraryPath,
                isBaselineIndexPresent: false,
                isHashIndexPresent: nil, // N/A when baseline index not available
                itemsCount: nil, // Cannot know without scanning
                lastScanDate: nil
            )
        }
    }
}
