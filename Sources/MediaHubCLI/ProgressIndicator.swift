//
//  ProgressIndicator.swift
//  MediaHubCLI
//
//  Progress indicators for long-running operations
//

import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Progress indicator for CLI operations
struct ProgressIndicator {
    private let isJSONMode: Bool
    private let isRedirected: Bool
    
    init(isJSONMode: Bool = false) {
        self.isJSONMode = isJSONMode
        // Check if output is redirected (simple heuristic: check if stdout is a TTY)
        self.isRedirected = isatty(STDOUT_FILENO) == 0
    }
    
    /// Prints a progress message if appropriate
    ///
    /// - Parameter message: Progress message
    func show(_ message: String) {
        // Suppress progress in JSON mode or when redirected
        if isJSONMode || isRedirected {
            return
        }
        
        // Print to stderr so it doesn't interfere with JSON output
        FileHandle.standardError.write((message + "\n").data(using: .utf8) ?? Data())
    }
    
    /// Shows detection progress
    func showDetectionProgress(stage: String, itemCount: Int? = nil) {
        var message = "Detection: \(stage)"
        if let count = itemCount {
            message += " (\(count) items)"
        }
        show(message)
    }
    
    /// Shows import progress
    func showImportProgress(stage: String, current: Int? = nil, total: Int? = nil) {
        var message = "Import: \(stage)"
        if let current = current, let total = total {
            message += " (\(current) of \(total))"
        } else if let current = current {
            message += " (\(current))"
        }
        show(message)
    }
}
