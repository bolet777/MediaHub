//
//  DetectionResult.swift
//  MediaHub
//
//  Detection result model and storage
//

import Foundation

/// Exclusion reason for candidate items
public enum ExclusionReason: String, Codable {
    case alreadyKnown = "already_known"
    case unsupportedFormat = "unsupported_format"
    case unreadable = "unreadable"
}

/// Candidate item with status and exclusion reason
public struct CandidateItemResult: Codable, Equatable {
    /// The candidate item
    public let item: CandidateMediaItem
    
    /// Status: "new" or "known"
    public let status: String
    
    /// Exclusion reason if item was excluded (null if included)
    public let exclusionReason: ExclusionReason?
    
    /// Creates a new CandidateItemResult
    ///
    /// - Parameters:
    ///   - item: The candidate item
    ///   - status: Status string ("new" or "known")
    ///   - exclusionReason: Optional exclusion reason
    public init(
        item: CandidateMediaItem,
        status: String,
        exclusionReason: ExclusionReason? = nil
    ) {
        self.item = item
        self.status = status
        self.exclusionReason = exclusionReason
    }
}

/// Detection result summary statistics
public struct DetectionSummary: Codable, Equatable {
    /// Total number of items scanned
    public let totalScanned: Int
    
    /// Number of new items
    public let newItems: Int
    
    /// Number of known items
    public let knownItems: Int
    
    /// Creates a new DetectionSummary
    ///
    /// - Parameters:
    ///   - totalScanned: Total items scanned
    ///   - newItems: Number of new items
    ///   - knownItems: Number of known items
    public init(
        totalScanned: Int,
        newItems: Int,
        knownItems: Int
    ) {
        self.totalScanned = totalScanned
        self.newItems = newItems
        self.knownItems = knownItems
    }
}

/// Detection result data structure
public struct DetectionResult: Codable, Equatable {
    /// Result format version
    public let version: String
    
    /// Source identifier
    public let sourceId: String
    
    /// Library identifier
    public let libraryId: String
    
    /// ISO-8601 timestamp of detection run
    public let detectedAt: String
    
    /// Array of candidate items with status
    public let candidates: [CandidateItemResult]
    
    /// Summary statistics
    public let summary: DetectionSummary
    
    /// Creates a new DetectionResult
    ///
    /// - Parameters:
    ///   - sourceId: Source identifier
    ///   - libraryId: Library identifier
    ///   - detectedAt: ISO-8601 timestamp (defaults to now)
    ///   - candidates: Array of candidate results
    ///   - summary: Summary statistics
    ///   - version: Format version (defaults to "1.0")
    public init(
        sourceId: String,
        libraryId: String,
        detectedAt: String? = nil,
        candidates: [CandidateItemResult],
        summary: DetectionSummary,
        version: String = "1.0"
    ) {
        self.version = version
        self.sourceId = sourceId
        self.libraryId = libraryId
        self.detectedAt = detectedAt ?? ISO8601DateFormatter().string(from: Date())
        self.candidates = candidates
        self.summary = summary
    }
    
    /// Validates that the result structure is valid
    ///
    /// - Returns: `true` if result is valid, `false` otherwise
    public func isValid() -> Bool {
        // Validate UUID formats
        guard UUID(uuidString: sourceId) != nil,
              UUID(uuidString: libraryId) != nil else {
            return false
        }
        
        // Validate ISO-8601 timestamp
        let formatter = ISO8601DateFormatter()
        guard formatter.date(from: detectedAt) != nil else {
            return false
        }
        
        // Validate summary matches candidates
        let newCount = candidates.filter { $0.status == "new" }.count
        let knownCount = candidates.filter { $0.status == "known" }.count
        
        guard summary.newItems == newCount,
              summary.knownItems == knownCount,
              summary.totalScanned == candidates.count else {
            return false
        }
        
        return true
    }
}

/// Errors that can occur during result operations
public enum DetectionResultError: Error, LocalizedError {
    case invalidResult
    case fileNotFound
    case permissionDenied
    case encodingError(Error)
    case decodingError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidResult:
            return "Invalid detection result structure"
        case .fileNotFound:
            return "Detection result file not found"
        case .permissionDenied:
            return "Permission denied accessing detection result file"
        case .encodingError(let error):
            return "Encoding error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        }
    }
}

/// Constants for detection result storage paths
public enum DetectionResultStorage {
    /// Name of the detections directory
    public static let detectionsDirectoryName = "detections"
    
    /// Returns the detections directory path for a Source
    ///
    /// - Parameter sourceId: Source identifier
    /// - Returns: Path relative to library root
    public static func detectionsDirectoryPath(for sourceId: String) -> String {
        return "\(SourceAssociationStorage.sourcesDirectoryPath)/\(sourceId)/\(detectionsDirectoryName)"
    }
    
    /// Gets the URL for a detection result file
    ///
    /// - Parameters:
    ///   - libraryRootURL: Library root URL
    ///   - sourceId: Source identifier
    ///   - timestamp: Detection timestamp (ISO-8601, used as filename)
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
            .appendingPathComponent(detectionsDirectoryName)
            .appendingPathComponent(filename)
    }
}

/// Handles serialization and deserialization of detection results
public struct DetectionResultSerializer {
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
    
    /// Serializes detection result to JSON data
    ///
    /// - Parameter result: The result to serialize
    /// - Returns: JSON data representation
    /// - Throws: `DetectionResultError` if serialization fails
    public static func serialize(_ result: DetectionResult) throws -> Data {
        guard result.isValid() else {
            throw DetectionResultError.invalidResult
        }
        
        do {
            return try encoder.encode(result)
        } catch {
            throw DetectionResultError.encodingError(error)
        }
    }
    
    /// Deserializes detection result from JSON data
    ///
    /// - Parameter data: JSON data to deserialize
    /// - Returns: Deserialized result
    /// - Throws: `DetectionResultError` if deserialization fails
    public static func deserialize(_ data: Data) throws -> DetectionResult {
        do {
            let result = try decoder.decode(DetectionResult.self, from: data)
            
            // Validate deserialized result
            guard result.isValid() else {
                throw DetectionResultError.invalidResult
            }
            
            return result
        } catch let error as DetectionResultError {
            throw error
        } catch {
            throw DetectionResultError.decodingError(error)
        }
    }
    
    /// Writes detection result to a file
    ///
    /// - Parameters:
    ///   - result: The result to write
    ///   - fileURL: The file URL where result should be written
    /// - Throws: `DetectionResultError` if writing fails
    public static func write(_ result: DetectionResult, to fileURL: URL) throws {
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
        } catch let error as DetectionResultError {
            throw error
        } catch {
            if (error as NSError).code == NSFileWriteNoPermissionError {
                throw DetectionResultError.permissionDenied
            }
            throw DetectionResultError.encodingError(error)
        }
    }
    
    /// Reads detection result from a file
    ///
    /// - Parameter fileURL: The file URL to read from
    /// - Returns: Deserialized result
    /// - Throws: `DetectionResultError` if reading fails
    public static func read(from fileURL: URL) throws -> DetectionResult {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw DetectionResultError.fileNotFound
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            return try deserialize(data)
        } catch let error as DetectionResultError {
            throw error
        } catch {
            if (error as NSError).code == NSFileReadNoPermissionError {
                throw DetectionResultError.permissionDenied
            }
            throw DetectionResultError.decodingError(error)
        }
    }
}

/// Retrieves stored detection results
public struct DetectionResultRetriever {
    /// Retrieves all detection results for a Source
    ///
    /// - Parameters:
    ///   - libraryRootURL: Library root URL
    ///   - sourceId: Source identifier
    /// - Returns: Array of detection results (sorted by timestamp, newest first)
    /// - Throws: `DetectionResultError` if retrieval fails
    public static func retrieveAll(
        for libraryRootURL: URL,
        sourceId: String
    ) throws -> [DetectionResult] {
        let detectionsDir = libraryRootURL
            .appendingPathComponent(LibraryStructure.metadataDirectoryName)
            .appendingPathComponent(SourceAssociationStorage.sourcesDirectoryName)
            .appendingPathComponent(sourceId)
            .appendingPathComponent(DetectionResultStorage.detectionsDirectoryName)
        
        guard FileManager.default.fileExists(atPath: detectionsDir.path) else {
            return []
        }
        
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(atPath: detectionsDir.path) else {
            return []
        }
        
        var results: [DetectionResult] = []
        
        for file in files where file.hasSuffix(".json") {
            let fileURL = detectionsDir.appendingPathComponent(file)
            if let result = try? DetectionResultSerializer.read(from: fileURL) {
                results.append(result)
            }
        }
        
        // Sort by timestamp (newest first)
        results.sort { result1, result2 in
            let formatter = ISO8601DateFormatter()
            guard let date1 = formatter.date(from: result1.detectedAt),
                  let date2 = formatter.date(from: result2.detectedAt) else {
                return false
            }
            return date1 > date2
        }
        
        return results
    }
    
    /// Retrieves the latest detection result for a Source
    ///
    /// - Parameters:
    ///   - libraryRootURL: Library root URL
    ///   - sourceId: Source identifier
    /// - Returns: Latest detection result, or nil if none exist
    /// - Throws: `DetectionResultError` if retrieval fails
    public static func retrieveLatest(
        for libraryRootURL: URL,
        sourceId: String
    ) throws -> DetectionResult? {
        let allResults = try retrieveAll(for: libraryRootURL, sourceId: sourceId)
        return allResults.first
    }
}

/// Supports comparison of results from different detection runs
public struct DetectionResultComparator {
    /// Compares two detection results and identifies differences
    ///
    /// - Parameters:
    ///   - result1: First detection result
    ///   - result2: Second detection result
    /// - Returns: Dictionary describing differences
    public static func compare(
        _ result1: DetectionResult,
        _ result2: DetectionResult
    ) -> [String: Any] {
        var differences: [String: Any] = [:]
        
        // Compare summary statistics
        if result1.summary.totalScanned != result2.summary.totalScanned {
            differences["totalScanned"] = [
                "before": result1.summary.totalScanned,
                "after": result2.summary.totalScanned
            ]
        }
        
        if result1.summary.newItems != result2.summary.newItems {
            differences["newItems"] = [
                "before": result1.summary.newItems,
                "after": result2.summary.newItems
            ]
        }
        
        if result1.summary.knownItems != result2.summary.knownItems {
            differences["knownItems"] = [
                "before": result1.summary.knownItems,
                "after": result2.summary.knownItems
            ]
        }
        
        // Compare candidate items
        let paths1 = Set(result1.candidates.map { $0.item.path })
        let paths2 = Set(result2.candidates.map { $0.item.path })
        
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
