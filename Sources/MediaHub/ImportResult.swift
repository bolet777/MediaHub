//
//  ImportResult.swift
//  MediaHub
//
//  Import result model and storage
//

import Foundation

/// Import item status
public enum ImportItemStatus: String, Codable {
    case imported = "imported"
    case skipped = "skipped"
    case failed = "failed"
}

/// Import item result
public struct ImportItemResult: Codable, Equatable {
    /// Absolute source path
    public let sourcePath: String
    
    /// Relative destination path in Library
    public let destinationPath: String?
    
    /// Import status
    public let status: ImportItemStatus
    
    /// Reason for status (optional, for skipped/failed items)
    public let reason: String?
    
    /// Timestamp used for organization (ISO-8601)
    public let timestampUsed: String?
    
    /// Source of timestamp (EXIF or filesystem)
    public let timestampSource: String?
    
    /// Creates a new ImportItemResult
    ///
    /// - Parameters:
    ///   - sourcePath: Absolute source path
    ///   - destinationPath: Relative destination path (if imported)
    ///   - status: Import status
    ///   - reason: Optional reason for status
    ///   - timestampUsed: Optional timestamp used (ISO-8601)
    ///   - timestampSource: Optional timestamp source
    public init(
        sourcePath: String,
        destinationPath: String? = nil,
        status: ImportItemStatus,
        reason: String? = nil,
        timestampUsed: String? = nil,
        timestampSource: String? = nil
    ) {
        self.sourcePath = sourcePath
        self.destinationPath = destinationPath
        self.status = status
        self.reason = reason
        self.timestampUsed = timestampUsed
        self.timestampSource = timestampSource
    }
}

/// Import options used during import
public struct ImportOptions: Codable, Equatable {
    /// Collision policy
    public let collisionPolicy: CollisionPolicy
    
    /// Creates new ImportOptions
    ///
    /// - Parameter collisionPolicy: Collision policy
    public init(collisionPolicy: CollisionPolicy) {
        self.collisionPolicy = collisionPolicy
    }
}

/// Import result summary statistics
public struct ImportSummary: Codable, Equatable {
    /// Total number of items processed
    public let total: Int
    
    /// Number of imported items
    public let imported: Int
    
    /// Number of skipped items
    public let skipped: Int
    
    /// Number of failed items
    public let failed: Int
    
    /// Creates a new ImportSummary
    ///
    /// - Parameters:
    ///   - total: Total items processed
    ///   - imported: Number imported
    ///   - skipped: Number skipped
    ///   - failed: Number failed
    public init(
        total: Int,
        imported: Int,
        skipped: Int,
        failed: Int
    ) {
        self.total = total
        self.imported = imported
        self.skipped = skipped
        self.failed = failed
    }
}

/// Import result data structure
public struct ImportResult: Codable, Equatable {
    /// Format version
    public let version: String
    
    /// Source identifier
    public let sourceId: String
    
    /// Library identifier
    public let libraryId: String
    
    /// ISO-8601 timestamp of import run
    public let importedAt: String
    
    /// Import options used
    public let options: ImportOptions
    
    /// Array of import item results
    public let items: [ImportItemResult]
    
    /// Summary statistics
    public let summary: ImportSummary
    
    /// Creates a new ImportResult
    ///
    /// - Parameters:
    ///   - sourceId: Source identifier
    ///   - libraryId: Library identifier
    ///   - importedAt: ISO-8601 timestamp (defaults to now)
    ///   - options: Import options
    ///   - items: Array of import item results
    ///   - summary: Summary statistics
    ///   - version: Format version (defaults to "1.0")
    public init(
        sourceId: String,
        libraryId: String,
        importedAt: String? = nil,
        options: ImportOptions,
        items: [ImportItemResult],
        summary: ImportSummary,
        version: String = "1.0"
    ) {
        self.version = version
        self.sourceId = sourceId
        self.libraryId = libraryId
        self.importedAt = importedAt ?? ISO8601DateFormatter().string(from: Date())
        self.options = options
        self.items = items
        self.summary = summary
    }
    
    /// Validates that the result structure is valid
    ///
    /// - Returns: `true` if valid, `false` otherwise
    public func isValid() -> Bool {
        // Validate UUID formats
        guard UUID(uuidString: sourceId) != nil,
              UUID(uuidString: libraryId) != nil else {
            return false
        }
        
        // Validate ISO-8601 timestamp
        let formatter = ISO8601DateFormatter()
        guard formatter.date(from: importedAt) != nil else {
            return false
        }
        
        // Validate summary matches items
        let importedCount = items.filter { $0.status == .imported }.count
        let skippedCount = items.filter { $0.status == .skipped }.count
        let failedCount = items.filter { $0.status == .failed }.count
        
        guard summary.total == items.count,
              summary.imported == importedCount,
              summary.skipped == skippedCount,
              summary.failed == failedCount else {
            return false
        }
        
        return true
    }
}

/// Errors that can occur during import result operations
public enum ImportResultError: Error, LocalizedError {
    case invalidResult
    case fileNotFound
    case permissionDenied
    case encodingError(Error)
    case decodingError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidResult:
            return "Invalid import result structure"
        case .fileNotFound:
            return "Import result file not found"
        case .permissionDenied:
            return "Permission denied accessing import result file"
        case .encodingError(let error):
            return "Encoding error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        }
    }
}

/// Constants for import result storage paths
public enum ImportResultStorage {
    /// Name of the imports directory
    public static let importsDirectoryName = "imports"
    
    /// Returns the imports directory path for a Source
    ///
    /// - Parameter sourceId: Source identifier
    /// - Returns: Path relative to library root
    public static func importsDirectoryPath(for sourceId: String) -> String {
        return "\(SourceAssociationStorage.sourcesDirectoryPath)/\(sourceId)/\(importsDirectoryName)"
    }
    
    /// Gets the URL for an import result file
    ///
    /// - Parameters:
    ///   - libraryRootURL: Library root URL
    ///   - sourceId: Source identifier
    ///   - timestamp: Import timestamp (ISO-8601, used as filename)
    /// - Returns: URL to the result file
    public static func resultFileURL(
        for libraryRootURL: URL,
        sourceId: String,
        timestamp: String
    ) -> URL {
        // Sanitize timestamp for filename (replace colons with dashes)
        let sanitizedTimestamp = timestamp.replacingOccurrences(of: ":", with: "-")
        let filename = "\(sanitizedTimestamp).json"
        
        return libraryRootURL
            .appendingPathComponent(LibraryStructure.metadataDirectoryName)
            .appendingPathComponent(SourceAssociationStorage.sourcesDirectoryName)
            .appendingPathComponent(sourceId)
            .appendingPathComponent(importsDirectoryName)
            .appendingPathComponent(filename)
    }
}

/// Handles serialization and deserialization of import results
public struct ImportResultSerializer {
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    /// Serializes import result to JSON data
    ///
    /// - Parameter result: The result to serialize
    /// - Returns: JSON data representation
    /// - Throws: `ImportResultError` if serialization fails
    public static func serialize(_ result: ImportResult) throws -> Data {
        guard result.isValid() else {
            throw ImportResultError.invalidResult
        }
        
        do {
            return try encoder.encode(result)
        } catch {
            throw ImportResultError.encodingError(error)
        }
    }
    
    /// Deserializes import result from JSON data
    ///
    /// - Parameter data: JSON data to deserialize
    /// - Returns: Deserialized result
    /// - Throws: `ImportResultError` if deserialization fails
    public static func deserialize(_ data: Data) throws -> ImportResult {
        do {
            let result = try decoder.decode(ImportResult.self, from: data)
            
            // Validate deserialized result
            guard result.isValid() else {
                throw ImportResultError.invalidResult
            }
            
            return result
        } catch let error as ImportResultError {
            throw error
        } catch {
            throw ImportResultError.decodingError(error)
        }
    }
    
    /// Writes import result to a file
    ///
    /// - Parameters:
    ///   - result: The result to write
    ///   - fileURL: The file URL where result should be written
    /// - Throws: `ImportResultError` if writing fails
    public static func write(_ result: ImportResult, to fileURL: URL) throws {
        let data = try serialize(result)
        
        do {
            // Create directory if it doesn't exist
            let directoryURL = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
            
            // Write result file atomically
            try data.write(to: fileURL, options: .atomic)
        } catch let error as ImportResultError {
            throw error
        } catch {
            if (error as NSError).code == NSFileWriteNoPermissionError {
                throw ImportResultError.permissionDenied
            }
            throw ImportResultError.encodingError(error)
        }
    }
    
    /// Reads import result from a file
    ///
    /// - Parameter fileURL: The file URL to read from
    /// - Returns: Deserialized result
    /// - Throws: `ImportResultError` if reading fails
    public static func read(from fileURL: URL) throws -> ImportResult {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ImportResultError.fileNotFound
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            return try deserialize(data)
        } catch let error as ImportResultError {
            throw error
        } catch {
            if (error as NSError).code == NSFileReadNoPermissionError {
                throw ImportResultError.permissionDenied
            }
            throw ImportResultError.decodingError(error)
        }
    }
}

/// Retrieves stored import results
public struct ImportResultRetriever {
    /// Retrieves all import results for a Source
    ///
    /// - Parameters:
    ///   - libraryRootURL: Library root URL
    ///   - sourceId: Source identifier
    /// - Returns: Array of import results (sorted by timestamp, newest first)
    /// - Throws: `ImportResultError` if retrieval fails
    public static func retrieveAll(
        for libraryRootURL: URL,
        sourceId: String
    ) throws -> [ImportResult] {
        let importsDir = libraryRootURL
            .appendingPathComponent(LibraryStructure.metadataDirectoryName)
            .appendingPathComponent(SourceAssociationStorage.sourcesDirectoryName)
            .appendingPathComponent(sourceId)
            .appendingPathComponent(ImportResultStorage.importsDirectoryName)
        
        guard FileManager.default.fileExists(atPath: importsDir.path) else {
            return []
        }
        
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(atPath: importsDir.path) else {
            return []
        }
        
        var results: [ImportResult] = []
        
        for file in files where file.hasSuffix(".json") {
            let fileURL = importsDir.appendingPathComponent(file)
            if let result = try? ImportResultSerializer.read(from: fileURL) {
                results.append(result)
            }
        }
        
        // Sort by timestamp (newest first)
        results.sort { result1, result2 in
            let formatter = ISO8601DateFormatter()
            guard let date1 = formatter.date(from: result1.importedAt),
                  let date2 = formatter.date(from: result2.importedAt) else {
                return false
            }
            return date1 > date2
        }
        
        return results
    }
    
    /// Retrieves the latest import result for a Source
    ///
    /// - Parameters:
    ///   - libraryRootURL: Library root URL
    ///   - sourceId: Source identifier
    /// - Returns: Latest import result, or nil if none exist
    /// - Throws: `ImportResultError` if retrieval fails
    public static func retrieveLatest(
        for libraryRootURL: URL,
        sourceId: String
    ) throws -> ImportResult? {
        let allResults = try retrieveAll(for: libraryRootURL, sourceId: sourceId)
        return allResults.first
    }
}

/// Supports comparison of results from different import runs
public struct ImportResultComparator {
    /// Compares two import results and identifies differences
    ///
    /// - Parameters:
    ///   - result1: First import result
    ///   - result2: Second import result
    /// - Returns: Dictionary describing differences
    public static func compare(
        _ result1: ImportResult,
        _ result2: ImportResult
    ) -> [String: Any] {
        var differences: [String: Any] = [:]
        
        // Compare summary statistics
        if result1.summary.total != result2.summary.total {
            differences["total"] = [
                "before": result1.summary.total,
                "after": result2.summary.total
            ]
        }
        
        if result1.summary.imported != result2.summary.imported {
            differences["imported"] = [
                "before": result1.summary.imported,
                "after": result2.summary.imported
            ]
        }
        
        if result1.summary.skipped != result2.summary.skipped {
            differences["skipped"] = [
                "before": result1.summary.skipped,
                "after": result2.summary.skipped
            ]
        }
        
        if result1.summary.failed != result2.summary.failed {
            differences["failed"] = [
                "before": result1.summary.failed,
                "after": result2.summary.failed
            ]
        }
        
        // Compare item paths
        let paths1 = Set(result1.items.map { $0.sourcePath })
        let paths2 = Set(result2.items.map { $0.sourcePath })
        
        let added = paths2.subtracting(paths1)
        let removed = paths1.subtracting(paths2)
        
        if !added.isEmpty {
            differences["addedItems"] = Array(added)
        }
        
        if !removed.isEmpty {
            differences["removedItems"] = Array(removed)
        }
        
        return differences
    }
}
