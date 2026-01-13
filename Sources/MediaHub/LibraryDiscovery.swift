//
//  LibraryDiscovery.swift
//  MediaHub
//
//  Library discovery at known and specified locations
//

import Foundation

/// Errors that can occur during library discovery
public enum LibraryDiscoveryError: Error, LocalizedError {
    case pathNotFound
    case permissionDenied(String)
    case invalidPath
    case discoveryFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .pathNotFound:
            return "Discovery path not found"
        case .permissionDenied(let path):
            return "Permission denied accessing path: \(path)"
        case .invalidPath:
            return "Invalid discovery path"
        case .discoveryFailed(let error):
            return "Discovery failed: \(error.localizedDescription)"
        }
    }
}

/// Represents a discovered library
public struct DiscoveredLibrary {
    /// The library metadata
    public let metadata: LibraryMetadata
    
    /// The library root path
    public let path: String
    
    /// Whether this library was found at a known location
    public let isKnown: Bool
    
    public init(metadata: LibraryMetadata, path: String, isKnown: Bool = false) {
        self.metadata = metadata
        self.path = path
        self.isKnown = isKnown
    }
}

/// Note: LibraryPathDetector is defined in LibraryOpening.swift
/// This file uses that implementation for library detection

/// Tracks previously known library locations
public class KnownLocationTracker {
    private var knownLocations: Set<String> = []
    
    public init() {}
    
    /// Adds a location to the known locations set.
    ///
    /// - Parameter path: The library path to track
    public func addLocation(_ path: String) {
        knownLocations.insert(path)
    }
    
    /// Removes a location from the known locations set.
    ///
    /// - Parameter path: The library path to remove
    public func removeLocation(_ path: String) {
        knownLocations.remove(path)
    }
    
    /// Gets all known locations.
    ///
    /// - Returns: Array of known library paths
    public func getKnownLocations() -> [String] {
        return Array(knownLocations)
    }
    
    /// Clears all known locations.
    public func clear() {
        knownLocations.removeAll()
    }
}

/// Handles permission errors during discovery
public struct PermissionErrorHandler {
    /// Handles permission errors gracefully during discovery.
    ///
    /// - Parameters:
    ///   - path: The path where permission error occurred
    ///   - error: The underlying error
    /// - Returns: A discovery error or `nil` if error was handled
    public static func handle(path: String, error: Error) -> LibraryDiscoveryError? {
        let nsError = error as NSError
        
        // Check for permission errors
        if nsError.domain == NSCocoaErrorDomain {
            switch nsError.code {
            case NSFileReadNoPermissionError, NSFileWriteNoPermissionError:
                return .permissionDenied(path)
            default:
                break
            }
        }
        
        // Check for POSIX permission errors
        if nsError.domain == NSPOSIXErrorDomain {
            let code = Int32(nsError.code)
            switch code {
            case EACCES, EPERM:
                return .permissionDenied(path)
            default:
                break
            }
        }
        
        // Not a permission error
        return nil
    }
    
    /// Checks if an error is a permission error.
    ///
    /// - Parameter error: The error to check
    /// - Returns: `true` if error is permission-related, `false` otherwise
    public static func isPermissionError(_ error: Error) -> Bool {
        return handle(path: "", error: error) != nil
    }
}

/// Discovers libraries at known locations
public struct KnownLocationDiscoverer {
    private let tracker: KnownLocationTracker
    private let registry: LibraryRegistry
    
    /// Creates a new known location discoverer.
    ///
    /// - Parameters:
    ///   - tracker: The known location tracker
    ///   - registry: The library registry
    public init(tracker: KnownLocationTracker, registry: LibraryRegistry) {
        self.tracker = tracker
        self.registry = registry
    }
    
    /// Discovers libraries at previously known locations.
    ///
    /// - Returns: Array of discovered libraries
    public func discover() -> [DiscoveredLibrary] {
        var discovered: [DiscoveredLibrary] = []
        let knownLocations = tracker.getKnownLocations()
        
        for location in knownLocations {
            // Check if location still exists
            guard FileManager.default.fileExists(atPath: location) else {
                // Location no longer exists - remove from tracker
                tracker.removeLocation(location)
                continue
            }
            
            // Check if location contains a valid library
            guard LibraryPathDetector.detect(at: location) else {
                // Not a valid library - remove from tracker
                tracker.removeLocation(location)
                continue
            }
            
            // Read metadata
            guard let metadata = try? LibraryMetadataReader.readMetadata(from: location) else {
                // Can't read metadata - skip
                continue
            }
            
            // Register in registry
            registry.register(identifier: metadata.libraryId, path: location)
            
            // Add to discovered list
            discovered.append(DiscoveredLibrary(metadata: metadata, path: location, isKnown: true))
        }
        
        return discovered
    }
}

/// Discovers libraries at specified locations
public struct SpecifiedLocationDiscoverer {
    private let registry: LibraryRegistry
    private let tracker: KnownLocationTracker
    
    /// Creates a new specified location discoverer.
    ///
    /// - Parameters:
    ///   - registry: The library registry
    ///   - tracker: The known location tracker
    public init(registry: LibraryRegistry, tracker: KnownLocationTracker) {
        self.registry = registry
        self.tracker = tracker
    }
    
    /// Discovers libraries at specified locations.
    ///
    /// - Parameter paths: Array of paths to search
    /// - Returns: Array of discovered libraries
    /// - Throws: `LibraryDiscoveryError` if discovery fails
    public func discover(at paths: [String]) throws -> [DiscoveredLibrary] {
        var discovered: [DiscoveredLibrary] = []
        
        for path in paths {
            do {
                // Check if path exists
                guard FileManager.default.fileExists(atPath: path) else {
                    throw LibraryDiscoveryError.pathNotFound
                }
                
                // Check if path is accessible
                guard FileManager.default.isReadableFile(atPath: path) else {
                    throw LibraryDiscoveryError.permissionDenied(path)
                }
                
                // Check if path contains a valid library
                guard LibraryPathDetector.detect(at: path) else {
                    // Not a library - skip
                    continue
                }
                
                // Read metadata
                let metadata = try LibraryMetadataReader.readMetadata(from: path)
                
                // Register in registry and tracker
                registry.register(identifier: metadata.libraryId, path: path)
                tracker.addLocation(path)
                
                // Add to discovered list
                discovered.append(DiscoveredLibrary(metadata: metadata, path: path, isKnown: false))
                
            } catch let error as LibraryDiscoveryError {
                // Re-throw discovery errors
                throw error
            } catch {
                // Handle permission errors
                if let permissionError = PermissionErrorHandler.handle(path: path, error: error) {
                    throw permissionError
                }
                // Other errors - skip this path
                continue
            }
        }
        
        return discovered
    }
}

/// Orchestrates library discovery workflow
public struct LibraryDiscoverer {
    private let knownLocationDiscoverer: KnownLocationDiscoverer
    private let specifiedLocationDiscoverer: SpecifiedLocationDiscoverer
    private let tracker: KnownLocationTracker
    private let registry: LibraryRegistry
    
    /// Creates a new library discoverer.
    ///
    /// - Parameters:
    ///   - tracker: The known location tracker
    ///   - registry: The library registry
    public init(tracker: KnownLocationTracker = KnownLocationTracker(), registry: LibraryRegistry = LibraryRegistry()) {
        self.tracker = tracker
        self.registry = registry
        self.knownLocationDiscoverer = KnownLocationDiscoverer(tracker: tracker, registry: registry)
        self.specifiedLocationDiscoverer = SpecifiedLocationDiscoverer(registry: registry, tracker: tracker)
    }
    
    /// Discovers all available libraries.
    ///
    /// Discovers libraries at:
    /// 1. Previously known locations
    /// 2. User-specified locations (if provided)
    ///
    /// - Parameter specifiedPaths: Optional array of user-specified paths to search
    /// - Returns: Array of all discovered libraries
    /// - Throws: `LibraryDiscoveryError` if discovery fails
    public func discoverAll(specifiedPaths: [String] = []) throws -> [DiscoveredLibrary] {
        var allDiscovered: [DiscoveredLibrary] = []
        
        // Step 1: Discover at known locations
        let knownDiscovered = knownLocationDiscoverer.discover()
        allDiscovered.append(contentsOf: knownDiscovered)
        
        // Step 2: Discover at specified locations (if any)
        if !specifiedPaths.isEmpty {
            do {
                let specifiedDiscovered = try specifiedLocationDiscoverer.discover(at: specifiedPaths)
                allDiscovered.append(contentsOf: specifiedDiscovered)
            } catch {
                // Log error but continue with known locations
                throw error
            }
        }
        
        // Remove duplicates (same identifier)
        var seenIdentifiers: Set<String> = []
        return allDiscovered.filter { library in
            if seenIdentifiers.contains(library.metadata.libraryId) {
                return false
            }
            seenIdentifiers.insert(library.metadata.libraryId)
            return true
        }
    }
    
    /// Gets the known location tracker.
    ///
    /// - Returns: The known location tracker
    public func getTracker() -> KnownLocationTracker {
        return tracker
    }
    
    /// Gets the library registry.
    ///
    /// - Returns: The library registry
    public func getRegistry() -> LibraryRegistry {
        return registry
    }
}
