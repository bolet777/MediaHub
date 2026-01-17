//
//  Progress.swift
//  MediaHub
//
//  Progress reporting and cancellation support
//

import Foundation

/// Progress update information for long-running operations
public struct ProgressUpdate {
    /// Operation stage name (e.g., "scanning", "comparing", "importing", "computing")
    public let stage: String
    
    /// Current item count (optional, nil if not applicable)
    public let current: Int?
    
    /// Total item count (optional, nil if not applicable)
    public let total: Int?
    
    /// Optional human-readable message (optional, nil if not provided)
    public let message: String?
    
    /// Creates a progress update
    ///
    /// - Parameters:
    ///   - stage: Operation stage name
    ///   - current: Current item count (optional)
    ///   - total: Total item count (optional)
    ///   - message: Optional human-readable message (optional)
    public init(stage: String, current: Int? = nil, total: Int? = nil, message: String? = nil) {
        self.stage = stage
        self.current = current
        self.total = total
        self.message = message
    }
}

/// Thread-safe cancellation token for canceling long-running operations
public final class CancellationToken {
    private let lock = NSLock()
    private var _isCanceled: Bool = false
    
    /// Creates a new cancellation token
    public init() {
    }
    
    /// Marks the token as canceled (thread-safe)
    public func cancel() {
        lock.lock()
        defer { lock.unlock() }
        _isCanceled = true
    }
    
    /// Returns whether cancellation has been requested (thread-safe, read-only)
    public var isCanceled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isCanceled
    }
}

/// Error thrown when an operation is canceled
public enum CancellationError: Error, LocalizedError {
    case cancelled
    
    public var errorDescription: String? {
        return "Operation was cancelled"
    }
}
