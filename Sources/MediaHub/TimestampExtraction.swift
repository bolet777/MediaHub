//
//  TimestampExtraction.swift
//  MediaHub
//
//  Timestamp extraction from media files (EXIF DateTimeOriginal → mtime fallback)
//

import Foundation
import ImageIO

/// Errors that can occur during timestamp extraction
public enum TimestampExtractionError: Error, LocalizedError {
    case fileInaccessible(String)
    case extractionFailed(String, Error)
    case invalidTimestamp(String)
    
    public var errorDescription: String? {
        switch self {
        case .fileInaccessible(let path):
            return "File is inaccessible: \(path)"
        case .extractionFailed(let path, let error):
            return "Timestamp extraction failed at \(path): \(error.localizedDescription)"
        case .invalidTimestamp(let reason):
            return "Invalid timestamp: \(reason)"
        }
    }
}

/// Timestamp extraction result
public struct TimestampResult {
    /// The extracted timestamp
    public let date: Date
    
    /// Source of the timestamp (EXIF or filesystem)
    public let source: TimestampSource
    
    /// Creates a new TimestampResult
    ///
    /// - Parameters:
    ///   - date: The extracted timestamp
    ///   - source: Source of the timestamp
    public init(date: Date, source: TimestampSource) {
        self.date = date
        self.source = source
    }
}

/// Source of timestamp
public enum TimestampSource {
    case exifDateTimeOriginal
    case filesystemModificationDate
}

/// Extracts timestamps from media files according to P1 rule:
/// EXIF DateTimeOriginal when present and valid, otherwise filesystem modification date
public struct TimestampExtractor {
    /// Minimum valid date (1900-01-01)
    private static let minValidDate = Date(timeIntervalSince1970: -2208988800) // 1900-01-01 00:00:00 UTC
    
    /// Maximum valid date (2100-12-31)
    private static let maxValidDate = Date(timeIntervalSince1970: 4133980800) // 2100-12-31 23:59:59 UTC
    
    /// Extracts timestamp from a media file
    ///
    /// - Parameter filePath: Absolute path to the media file
    /// - Returns: TimestampResult with extracted date and source
    /// - Throws: `TimestampExtractionError` if extraction fails
    public static func extractTimestamp(from filePath: String) throws -> TimestampResult {
        let fileURL = URL(fileURLWithPath: filePath)
        
        // Try EXIF DateTimeOriginal first
        if let exifDate = try? extractEXIFDateTimeOriginal(from: fileURL) {
            if let validatedDate = validateTimestamp(exifDate) {
                return TimestampResult(date: validatedDate, source: .exifDateTimeOriginal)
            }
        }
        
        // Fallback to filesystem modification date
        let fileManager = FileManager.default
        guard let attributes = try? fileManager.attributesOfItem(atPath: filePath),
              let modificationDate = attributes[.modificationDate] as? Date else {
            throw TimestampExtractionError.fileInaccessible(filePath)
        }
        
        return TimestampResult(date: modificationDate, source: .filesystemModificationDate)
    }
    
    /// Extracts EXIF DateTimeOriginal from an image file
    ///
    /// - Parameter fileURL: URL to the image file
    /// - Returns: Date from EXIF DateTimeOriginal, or nil if not available
    /// - Throws: Errors if file cannot be read
    private static func extractEXIFDateTimeOriginal(from fileURL: URL) throws -> Date? {
        guard let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else {
            return nil
        }
        
        guard let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            return nil
        }
        
        // Check EXIF dictionary
        guard let exifDict = imageProperties[kCGImagePropertyExifDictionary as String] as? [String: Any] else {
            return nil
        }
        
        // Get DateTimeOriginal
        guard let dateTimeOriginal = exifDict[kCGImagePropertyExifDateTimeOriginal as String] as? String else {
            return nil
        }
        
        // Parse EXIF date string (format: "YYYY:MM:DD HH:MM:SS")
        return parseEXIFDateString(dateTimeOriginal)
    }
    
    /// Parses EXIF date string to Date
    ///
    /// EXIF date format: "YYYY:MM:DD HH:MM:SS" (e.g., "2026:01:12 10:30:45")
    ///
    /// - Parameter dateString: EXIF date string
    /// - Returns: Parsed Date, or nil if parsing fails
    private static func parseEXIFDateString(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current // Treat as local time for P1
        
        return formatter.date(from: dateString)
    }
    
    /// Validates that a timestamp is within reasonable range
    ///
    /// - Parameter date: Date to validate
    /// - Returns: Validated date, or nil if invalid
    private static func validateTimestamp(_ date: Date) -> Date? {
        // Check if date is within reasonable range (1900-01-01 to 2100-12-31)
        guard date >= minValidDate && date <= maxValidDate else {
            return nil
        }
        
        return date
    }
    
    /// Extracts filesystem modification date from a file
    ///
    /// - Parameter filePath: Absolute path to the file
    /// - Returns: Modification date
    /// - Throws: `TimestampExtractionError` if extraction fails
    public static func extractModificationDate(from filePath: String) throws -> Date {
        let fileManager = FileManager.default
        guard let attributes = try? fileManager.attributesOfItem(atPath: filePath),
              let modificationDate = attributes[.modificationDate] as? Date else {
            throw TimestampExtractionError.fileInaccessible(filePath)
        }
        
        return modificationDate
    }
}
