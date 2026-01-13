//
//  LibraryIdentifier.swift
//  MediaHub
//
//  Unique identifier generation for MediaHub libraries
//

import Foundation

/// Generates unique identifiers for MediaHub libraries.
///
/// Uses UUID v4 to ensure globally unique identifiers that persist
/// across application restarts and library moves.
public struct LibraryIdentifierGenerator {
    /// Generates a new unique identifier for a library.
    ///
    /// - Returns: A UUID v4 string representation
    public static func generate() -> String {
        return UUID().uuidString
    }
    
    /// Validates that a string is a valid UUID format.
    ///
    /// - Parameter identifier: The identifier string to validate
    /// - Returns: `true` if the identifier is a valid UUID, `false` otherwise
    public static func isValid(_ identifier: String) -> Bool {
        return UUID(uuidString: identifier) != nil
    }
}
