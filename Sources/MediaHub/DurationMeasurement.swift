//
//  DurationMeasurement.swift
//  MediaHub
//
//  Duration measurement helper (best-effort, informational only)
//

import Foundation

/// Result of measuring operation duration
///
/// Contains the operation result and optional duration in seconds.
/// Duration is informational and may be nil if measurement fails.
public struct MeasurementResult<T> {
    /// The result of the measured operation
    public let result: T
    
    /// Duration in seconds (informational, may vary across runs)
    /// nil if measurement failed or was unavailable
    public let durationSeconds: Double?
    
    /// Creates a measurement result
    ///
    /// - Parameters:
    ///   - result: Operation result
    ///   - durationSeconds: Optional duration in seconds
    public init(result: T, durationSeconds: Double?) {
        self.result = result
        self.durationSeconds = durationSeconds
    }
}

/// Measures execution time of a closure (best-effort, informational only)
///
/// This is a lightweight utility for measuring wall-clock time.
/// Duration is informational and may vary across runs.
/// Measurement failures do not affect operation results or error behavior.
public struct DurationMeasurement {
    /// Measures execution time of a throwing closure
    ///
    /// Returns the result and optional duration. If the closure throws,
    /// the original error is rethrown unchanged. If timing fails,
    /// duration will be nil but the operation result is unaffected.
    ///
    /// - Parameter operation: Closure to measure
    /// - Returns: Measurement result with operation result and optional duration
    /// - Throws: Original error from the operation (unchanged)
    public static func measure<T>(_ operation: () throws -> T) rethrows -> MeasurementResult<T> {
        let startTime = Date()
        
        // Execute operation and capture result
        let result = try operation()
        
        // Calculate duration (best-effort)
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Duration should be >= 0, but return nil if somehow invalid
        // (defensive programming, though this should never happen)
        let durationSeconds: Double? = duration >= 0 ? duration : nil
        
        return MeasurementResult(result: result, durationSeconds: durationSeconds)
    }
    
    /// Measures execution time of a non-throwing closure
    ///
    /// Returns the result and optional duration. If timing fails,
    /// duration will be nil but the operation result is unaffected.
    ///
    /// - Parameter operation: Closure to measure
    /// - Returns: Measurement result with operation result and optional duration
    public static func measure<T>(_ operation: () -> T) -> MeasurementResult<T> {
        let startTime = Date()
        
        // Execute operation and capture result
        let result = operation()
        
        // Calculate duration (best-effort)
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Duration should be >= 0, but return nil if somehow invalid
        let durationSeconds: Double? = duration >= 0 ? duration : nil
        
        return MeasurementResult(result: result, durationSeconds: durationSeconds)
    }
}
