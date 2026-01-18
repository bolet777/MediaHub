import Foundation

struct DiscoveredLibrary: Identifiable, Equatable, Codable {
    var id: String { path }  // Full path string as id for determinism
    let path: String
    let displayName: String  // Derived from lastPathComponent, but stored as value
    let isValid: Bool
    let validationError: String?  // nil when valid
}
