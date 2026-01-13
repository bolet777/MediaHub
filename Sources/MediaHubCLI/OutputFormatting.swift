//
//  OutputFormatting.swift
//  MediaHubCLI
//
//  Output formatting for human-readable and JSON modes
//

import Foundation
import MediaHub

/// Output format options
enum OutputFormat {
    case humanReadable
    case json
}

/// Base protocol for output formatting
protocol OutputFormatter {
    func format() -> String
}

/// Formats library list output
struct LibraryListFormatter: OutputFormatter {
    let libraries: [DiscoveredLibrary]
    let outputFormat: OutputFormat
    
    func format() -> String {
        switch outputFormat {
        case .humanReadable:
            return formatHumanReadable()
        case .json:
            return formatJSON()
        }
    }
    
    private func formatHumanReadable() -> String {
        if libraries.isEmpty {
            return "No libraries found."
        }
        
        var output = "Found \(libraries.count) library(ies):\n\n"
        for (index, library) in libraries.enumerated() {
            output += "\(index + 1). \(library.path)\n"
            output += "   ID: \(library.metadata.libraryId)\n"
            output += "   Version: \(library.metadata.libraryVersion)\n"
            if index < libraries.count - 1 {
                output += "\n"
            }
        }
        return output
    }
    
    private func formatJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        struct LibraryInfo: Codable {
            let path: String
            let identifier: String
            let version: String
        }
        
        let libraryInfos = libraries.map { library in
            LibraryInfo(
                path: library.path,
                identifier: library.metadata.libraryId,
                version: library.metadata.libraryVersion
            )
        }
        
        guard let data = try? encoder.encode(libraryInfos),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        
        return jsonString
    }
}

/// Formats source list output
struct SourceListFormatter: OutputFormatter {
    let sources: [Source]
    let outputFormat: OutputFormat
    
    func format() -> String {
        switch outputFormat {
        case .humanReadable:
            return formatHumanReadable()
        case .json:
            return formatJSON()
        }
    }
    
    private func formatHumanReadable() -> String {
        if sources.isEmpty {
            return "No sources attached."
        }
        
        var output = "Attached sources (\(sources.count)):\n\n"
        for (index, source) in sources.enumerated() {
            output += "\(index + 1). \(source.path)\n"
            output += "   ID: \(source.sourceId)\n"
            output += "   Type: \(source.type.rawValue)\n"
            output += "   Attached: \(source.attachedAt)\n"
            if let lastDetected = source.lastDetectedAt {
                output += "   Last detected: \(lastDetected)\n"
            }
            if index < sources.count - 1 {
                output += "\n"
            }
        }
        return output
    }
    
    private func formatJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        guard let data = try? encoder.encode(sources),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        
        return jsonString
    }
}

/// Formats detection result output
struct DetectionResultFormatter: OutputFormatter {
    let result: DetectionResult
    let outputFormat: OutputFormat
    
    func format() -> String {
        switch outputFormat {
        case .humanReadable:
            return formatHumanReadable()
        case .json:
            return formatJSON()
        }
    }
    
    private func formatHumanReadable() -> String {
        var output = "Detection Results\n"
        output += "=================\n\n"
        output += "Read-only: No source files or media files modified\n\n"
        output += "Source ID: \(result.sourceId)\n"
        output += "Detected at: \(result.detectedAt)\n\n"
        output += "Summary:\n"
        output += "  Total scanned: \(result.summary.totalScanned)\n"
        output += "  New items: \(result.summary.newItems)\n"
        output += "  Known items: \(result.summary.knownItems)\n\n"
        
        if result.summary.newItems > 0 {
            output += "New items:\n"
            let newItems = result.candidates.filter { $0.status == "new" }
            for (index, candidate) in newItems.prefix(20).enumerated() {
                output += "  \(index + 1). \(candidate.item.path)\n"
            }
            if newItems.count > 20 {
                output += "  ... and \(newItems.count - 20) more\n"
            }
        }
        
        return output
    }
    
    private func formatJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        guard let data = try? encoder.encode(result),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        
        return jsonString
    }
}

/// Formats import result output
struct ImportResultFormatter: OutputFormatter {
    let result: ImportResult
    let outputFormat: OutputFormat
    let dryRun: Bool
    
    init(result: ImportResult, outputFormat: OutputFormat, dryRun: Bool = false) {
        self.result = result
        self.outputFormat = outputFormat
        self.dryRun = dryRun
    }
    
    func format() -> String {
        switch outputFormat {
        case .humanReadable:
            return formatHumanReadable()
        case .json:
            return formatJSON()
        }
    }
    
    private func formatHumanReadable() -> String {
        var output = dryRun ? "DRY-RUN: Import Preview\n" : "Import Results\n"
        output += dryRun ? "=======================\n\n" : "==============\n\n"
        output += "Source ID: \(result.sourceId)\n"
        output += dryRun ? "Preview at: \(result.importedAt)\n\n" : "Imported at: \(result.importedAt)\n\n"
        output += "Summary:\n"
        output += "  Total: \(result.summary.total)\n"
        if dryRun {
            output += "  Would import: \(result.summary.imported)\n"
        } else {
            output += "  Imported: \(result.summary.imported)\n"
        }
        output += "  Skipped: \(result.summary.skipped)\n"
        output += "  Failed: \(result.summary.failed)\n\n"
        
        // Show preview details for dry-run (source paths, destination paths, collisions)
        if dryRun {
            let importedItems = result.items.filter { $0.status == .imported }
            let skippedItems = result.items.filter { $0.status == .skipped }
            
            if !importedItems.isEmpty {
                output += "Would import:\n"
                for (index, item) in importedItems.prefix(20).enumerated() {
                    output += "  \(index + 1). \(item.sourcePath)\n"
                    if let destinationPath = item.destinationPath {
                        output += "     → \(destinationPath)\n"
                    }
                }
                if importedItems.count > 20 {
                    output += "  ... and \(importedItems.count - 20) more\n"
                }
                output += "\n"
            }
            
            if !skippedItems.isEmpty {
                output += "Would skip (collisions):\n"
                for (index, item) in skippedItems.prefix(10).enumerated() {
                    output += "  \(index + 1). \(item.sourcePath)\n"
                    if let destinationPath = item.destinationPath {
                        output += "     → \(destinationPath)\n"
                    }
                    if let reason = item.reason {
                        output += "     Reason: \(reason)\n"
                    }
                }
                if skippedItems.count > 10 {
                    output += "  ... and \(skippedItems.count - 10) more\n"
                }
                output += "\n"
            }
        }
        
        if result.summary.failed > 0 {
            output += "Failed items:\n"
            let failedItems = result.items.filter { $0.status == .failed }
            for (index, item) in failedItems.prefix(10).enumerated() {
                output += "  \(index + 1). \(item.sourcePath)\n"
                if let reason = item.reason {
                    output += "     Reason: \(reason)\n"
                }
            }
            if failedItems.count > 10 {
                output += "  ... and \(failedItems.count - 10) more\n"
            }
        }
        
        return output
    }
    
    private func formatJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        // In dry-run mode, wrap result in envelope with dryRun field
        if dryRun {
            struct DryRunEnvelope: Codable {
                let dryRun: Bool
                let result: ImportResult
            }
            
            let envelope = DryRunEnvelope(dryRun: true, result: result)
            guard let data = try? encoder.encode(envelope),
                  let jsonString = String(data: data, encoding: .utf8) else {
                return "{}"
            }
            return jsonString
        }
        
        // Normal mode: encode result directly
        guard let data = try? encoder.encode(result),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        
        return jsonString
    }
}

/// Formats status output
struct StatusFormatter: OutputFormatter {
    let library: OpenedLibrary
    let sources: [Source]
    let outputFormat: OutputFormat
    
    func format() -> String {
        switch outputFormat {
        case .humanReadable:
            return formatHumanReadable()
        case .json:
            return formatJSON()
        }
    }
    
    private func formatHumanReadable() -> String {
        var output = "Library Status\n"
        output += "==============\n\n"
        output += "Path: \(library.rootURL.path)\n"
        output += "ID: \(library.metadata.libraryId)\n"
        output += "Version: \(library.metadata.libraryVersion)\n"
        output += "Sources: \(sources.count)\n"
        
        if !sources.isEmpty {
            output += "\nAttached sources:\n"
            for (index, source) in sources.enumerated() {
                output += "  \(index + 1). \(source.path) (\(source.sourceId))\n"
                if let lastDetected = source.lastDetectedAt {
                    output += "     Last detected: \(lastDetected)\n"
                }
            }
        }
        
        return output
    }
    
    private func formatJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        struct StatusInfo: Codable {
            let path: String
            let identifier: String
            let version: String
            let sourceCount: Int
            let sources: [Source]
        }
        
        let statusInfo = StatusInfo(
            path: library.rootURL.path,
            identifier: library.metadata.libraryId,
            version: library.metadata.libraryVersion,
            sourceCount: sources.count,
            sources: sources
        )
        
        guard let data = try? encoder.encode(statusInfo),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        
        return jsonString
    }
}
