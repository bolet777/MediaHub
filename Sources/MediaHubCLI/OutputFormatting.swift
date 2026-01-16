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
            output += "   Media types: \(source.effectiveMediaTypes.rawValue)\n"
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
        
        // Create wrapper struct to ensure mediaTypes is always included (defaults to "both" when nil)
        struct SourceInfo: Codable {
            let sourceId: String
            let type: String
            let path: String
            let attachedAt: String
            let lastDetectedAt: String?
            let mediaTypes: String // Always present, defaults to "both" when nil
            
            init(from source: Source) {
                self.sourceId = source.sourceId
                self.type = source.type.rawValue
                self.path = source.path
                self.attachedAt = source.attachedAt
                self.lastDetectedAt = source.lastDetectedAt
                self.mediaTypes = source.effectiveMediaTypes.rawValue
            }
        }
        
        let sourceInfos = sources.map { SourceInfo(from: $0) }
        
        guard let data = try? encoder.encode(sourceInfos),
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
        output += "  Known items: \(result.summary.knownItems)\n"
        
        // Display hash coverage if available
        if let hashCoverage = result.hashCoverage {
            let percentage = Int(hashCoverage * 100)
            output += "  Hash coverage: \(percentage)%\n"
        }
        output += "\n"
        
        if result.summary.newItems > 0 {
            output += "New items:\n"
            let newItems = result.candidates.filter { $0.status == "new" }
            for (index, candidate) in newItems.prefix(20).enumerated() {
                output += "  \(index + 1). \(candidate.item.path)\n"
            }
            if newItems.count > 20 {
                output += "  ... and \(newItems.count - 20) more\n"
            }
            output += "\n"
        }
        
        // Display known items with duplicate information
        if result.summary.knownItems > 0 {
            output += "Known items:\n"
            let knownItems = result.candidates.filter { $0.status == "known" }
            for (index, candidate) in knownItems.prefix(20).enumerated() {
                output += "  \(index + 1). \(candidate.item.path)\n"
                
                // Display duplicate information
                if let duplicateReason = candidate.duplicateReason {
                    // Hash-based duplicate
                    output += "     Duplicate reason: \(duplicateReason)\n"
                    if let hash = candidate.duplicateOfHash {
                        // Shorten hash for display: show first 12 chars + "..."
                        let shortHash = String(hash.prefix(12)) + "..."
                        output += "     Hash: \(shortHash)\n"
                    }
                    if let libraryPath = candidate.duplicateOfLibraryPath {
                        output += "     Duplicate of: \(libraryPath)\n"
                    }
                } else if candidate.exclusionReason != nil {
                    // Path-based duplicate
                    output += "     Duplicate reason: path_match\n"
                }
            }
            if knownItems.count > 20 {
                output += "  ... and \(knownItems.count - 20) more\n"
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
    let baselineIndex: BaselineIndex?
    let statistics: LibraryStatistics?
    let outputFormat: OutputFormat
    
    func format() -> String {
        switch outputFormat {
        case .humanReadable:
            return formatHumanReadable()
        case .json:
            return formatJSON()
        }
    }
    
    /// Formats a number with comma separators for readability
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
    
    private func formatHumanReadable() -> String {
        var output = "Library Status\n"
        output += "==============\n\n"
        output += "Path: \(library.rootURL.path)\n"
        output += "ID: \(library.metadata.libraryId)\n"
        output += "Version: \(library.metadata.libraryVersion)\n"
        output += "Sources: \(sources.count)\n"
        
        // Statistics (if baseline index is available)
        if let stats = statistics {
            output += "\nStatistics:\n"
            output += "  Total items: \(formatNumber(stats.totalItems))\n"
            
            if !stats.byYear.isEmpty {
                output += "  By year:\n"
                // Sort years descending for display
                let sortedYears = stats.byYear.keys.sorted(by: >)
                for year in sortedYears {
                    if let count = stats.byYear[year] {
                        output += "    \(year): \(formatNumber(count))\n"
                    }
                }
            }
            
            if !stats.byMediaType.isEmpty {
                output += "  By media type:\n"
                if let imagesCount = stats.byMediaType["images"], imagesCount > 0 {
                    output += "    Images: \(formatNumber(imagesCount))\n"
                }
                if let videosCount = stats.byMediaType["videos"], videosCount > 0 {
                    output += "    Videos: \(formatNumber(videosCount))\n"
                }
            }
        } else {
            output += "\nStatistics: N/A (baseline index not available)\n"
        }
        
        // Hash coverage stats (if baseline index is available)
        if let index = baselineIndex {
            output += "\nHash Coverage:\n"
            output += "  Total entries: \(index.entryCount)\n"
            output += "  Entries with hash: \(index.hashEntryCount)\n"
            output += "  Coverage: \(Int(index.hashCoverage * 100))%\n"
        } else {
            output += "\nHash Coverage: N/A (baseline index not available)\n"
        }
        
        if !sources.isEmpty {
            output += "\nAttached sources:\n"
            for (index, source) in sources.enumerated() {
                output += "  \(index + 1). \(source.path) (\(source.sourceId))\n"
                output += "     Media types: \(source.effectiveMediaTypes.rawValue)\n"
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
        
        struct HashCoverageInfo: Codable {
            let totalEntries: Int
            let entriesWithHash: Int
            let hashCoverage: Double
        }
        
        struct StatisticsInfo: Codable {
            let totalItems: Int
            let byYear: [String: Int]
            let byMediaType: [String: Int]
        }
        
        // SourceInfo wrapper to ensure mediaTypes is always included (defaults to "both" when nil)
        struct SourceInfo: Codable {
            let sourceId: String
            let type: String
            let path: String
            let attachedAt: String
            let lastDetectedAt: String?
            let mediaTypes: String // Always present, defaults to "both" when nil
            
            init(from source: Source) {
                self.sourceId = source.sourceId
                self.type = source.type.rawValue
                self.path = source.path
                self.attachedAt = source.attachedAt
                self.lastDetectedAt = source.lastDetectedAt
                self.mediaTypes = source.effectiveMediaTypes.rawValue
            }
        }
        
        struct StatusInfo: Codable {
            let path: String
            let identifier: String
            let version: String
            let sourceCount: Int
            let sources: [SourceInfo]
            let statistics: StatisticsInfo?
            let hashCoverage: HashCoverageInfo?
        }
        
        let statisticsInfo: StatisticsInfo?
        if let stats = statistics {
            statisticsInfo = StatisticsInfo(
                totalItems: stats.totalItems,
                byYear: stats.byYear,
                byMediaType: stats.byMediaType
            )
        } else {
            statisticsInfo = nil
        }
        
        let hashCoverageInfo: HashCoverageInfo?
        if let index = baselineIndex {
            hashCoverageInfo = HashCoverageInfo(
                totalEntries: index.entryCount,
                entriesWithHash: index.hashEntryCount,
                hashCoverage: index.hashCoverage
            )
        } else {
            hashCoverageInfo = nil
        }
        
        let sourceInfos = sources.map { SourceInfo(from: $0) }
        
        let statusInfo = StatusInfo(
            path: library.rootURL.path,
            identifier: library.metadata.libraryId,
            version: library.metadata.libraryVersion,
            sourceCount: sources.count,
            sources: sourceInfos,
            statistics: statisticsInfo,
            hashCoverage: hashCoverageInfo
        )
        
        guard let data = try? encoder.encode(statusInfo),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        
        return jsonString
    }
}

/// Formats library adoption success output
struct LibraryAdoptionFormatter: OutputFormatter {
    let result: LibraryAdoptionResult
    let outputFormat: OutputFormat
    let dryRun: Bool
    
    func format() -> String {
        switch outputFormat {
        case .humanReadable:
            return formatHumanReadable()
        case .json:
            return formatJSON()
        }
    }
    
    private func formatHumanReadable() -> String {
        var output = ""
        if dryRun {
            output += "DRY-RUN: Library adoption preview\n"
            output += "==================================\n\n"
            output += "Would create:\n"
            output += "  Library ID: \(result.metadata.libraryId)\n"
            output += "  Metadata location: \(result.metadata.rootPath)/.mediahub/library.json\n"
            output += "\nBaseline scan summary:\n"
            output += "  Files found: \(result.baselineScan.fileCount)\n"
            output += "\n"
            output += "Note: No files will be created; this is a preview only.\n"
        } else {
            output += "Library adopted successfully\n"
            output += "===========================\n\n"
            output += "Library ID: \(result.metadata.libraryId)\n"
            output += "Metadata location: \(result.metadata.rootPath)/.mediahub/library.json\n"
            output += "\nBaseline scan summary:\n"
            output += "  Files found: \(result.baselineScan.fileCount)\n"
            output += "\n"
            output += "Note: No media files were modified; only .mediahub metadata was created.\n"
        }
        return output
    }
    
    private func formatJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        struct AdoptionOutput: Codable {
            let dryRun: Bool
            let metadata: LibraryMetadata
            let baselineScan: BaselineScanSummary
        }
        
        let output = AdoptionOutput(
            dryRun: dryRun,
            metadata: result.metadata,
            baselineScan: result.baselineScan
        )
        
        guard let data = try? encoder.encode(output),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        
        return jsonString
    }
}

/// Formats idempotent adoption output (library already adopted)
struct LibraryAdoptionIdempotentFormatter: OutputFormatter {
    let path: String
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
        return "Library is already adopted at: \(path)\n"
    }
    
    private func formatJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        struct IdempotentOutput: Codable {
            let alreadyAdopted: Bool
            let path: String
        }
        
        let output = IdempotentOutput(
            alreadyAdopted: true,
            path: path
        )
        
        guard let data = try? encoder.encode(output),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        
        return jsonString
    }
}

/// Formats hash coverage maintenance output
struct HashCoverageFormatter: OutputFormatter {
    let libraryPath: String
    let statistics: HashCoverageStatistics
    let dryRun: Bool
    let hashesComputed: Int?
    let hashFailures: Int?
    let entriesUpdated: Int?
    let indexUpdated: Bool?
    let limit: Int?
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
        if dryRun {
            var output = "Hash Coverage Preview\n"
            output += "====================\n\n"
            output += "Library: \(libraryPath)\n"
            output += "Total entries: \(statistics.totalEntries)\n"
            output += "Entries with hash: \(statistics.entriesWithHash)\n"
            output += "Entries missing hash: \(statistics.entriesMissingHash)\n"
            output += "Current coverage: \(Int(statistics.hashCoverage * 100))%\n\n"
            output += "DRY-RUN: Would compute hashes for \(statistics.candidateCount) file(s)\n"
            if let limit = limit {
                output += "  (Limited to \(limit) files)\n"
            }
            if statistics.missingFilesCount > 0 {
                output += "  Note: \(statistics.missingFilesCount) entry/entries reference missing files\n"
            }
            output += "\nNo hashes will be computed. No changes will be made to the index."
            return output
        } else {
            var output = "Hash Coverage Update Summary\n"
            output += "===========================\n\n"
            output += "Library: \(libraryPath)\n\n"
            output += "Before:\n"
            output += "  Total entries: \(statistics.totalEntries)\n"
            output += "  Entries with hash: \(statistics.entriesWithHash)\n"
            output += "  Coverage: \(Int(statistics.hashCoverage * 100))%\n\n"
            if let entriesUpdated = entriesUpdated, let indexUpdated = indexUpdated {
                // After stats (for update result)
                let afterEntriesWithHash = statistics.entriesWithHash + entriesUpdated
                let afterCoverage = statistics.totalEntries > 0 ? Double(afterEntriesWithHash) / Double(statistics.totalEntries) : 0.0
                output += "After:\n"
                output += "  Total entries: \(statistics.totalEntries)\n"
                output += "  Entries with hash: \(afterEntriesWithHash)\n"
                output += "  Coverage: \(Int(afterCoverage * 100))%\n\n"
                if let hashesComputed = hashesComputed {
                    output += "Hashes computed: \(hashesComputed)\n"
                }
                if let hashFailures = hashFailures, hashFailures > 0 {
                    output += "Hash computation failures: \(hashFailures)\n"
                }
                if let limit = limit {
                    output += "  (Limited to \(limit) files)\n"
                }
                output += "Entries updated: \(entriesUpdated)\n"
                output += "Index updated: \(indexUpdated ? "yes" : "no")\n"
                if !indexUpdated {
                    output += "  (No changes needed - coverage already complete)\n"
                }
            } else {
                // Before stats only (for computation result)
                if let hashesComputed = hashesComputed {
                    output += "Hashes computed: \(hashesComputed)\n"
                }
                if let hashFailures = hashFailures, hashFailures > 0 {
                    output += "Hash computation failures: \(hashFailures)\n"
                }
                if let limit = limit {
                    output += "  (Limited to \(limit) files)\n"
                }
            }
            return output
        }
    }
    
    private func formatJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        if dryRun {
            struct DryRunOutput: Codable {
                let dryRun: Bool
                let library: String
                let statistics: HashCoverageStatisticsJSON
                let limit: Int?
            }
            
            struct HashCoverageStatisticsJSON: Codable {
                let totalEntries: Int
                let entriesWithHash: Int
                let entriesMissingHash: Int
                let candidateCount: Int
                let missingFilesCount: Int
                let hashCoverage: Double
            }
            
            let statsJSON = HashCoverageStatisticsJSON(
                totalEntries: statistics.totalEntries,
                entriesWithHash: statistics.entriesWithHash,
                entriesMissingHash: statistics.entriesMissingHash,
                candidateCount: statistics.candidateCount,
                missingFilesCount: statistics.missingFilesCount,
                hashCoverage: statistics.hashCoverage
            )
            
            let output = DryRunOutput(
                dryRun: true,
                library: libraryPath,
                statistics: statsJSON,
                limit: limit
            )
            
            guard let data = try? encoder.encode(output),
                  let jsonString = String(data: data, encoding: .utf8) else {
                return "{}"
            }
            return jsonString
        } else {
            struct UpdateOutput: Codable {
                let library: String
                let before: HashCoverageStatisticsJSON
                let after: HashCoverageStatisticsJSON?
                let hashesComputed: Int?
                let hashFailures: Int?
                let entriesUpdated: Int?
                let indexUpdated: Bool?
                let limit: Int?
            }
            
            struct HashCoverageStatisticsJSON: Codable {
                let totalEntries: Int
                let entriesWithHash: Int
                let entriesMissingHash: Int
                let hashCoverage: Double
            }
            
            let beforeJSON = HashCoverageStatisticsJSON(
                totalEntries: statistics.totalEntries,
                entriesWithHash: statistics.entriesWithHash,
                entriesMissingHash: statistics.entriesMissingHash,
                hashCoverage: statistics.hashCoverage
            )
            
            let afterJSON: HashCoverageStatisticsJSON?
            if let entriesUpdated = entriesUpdated {
                let afterEntriesWithHash = statistics.entriesWithHash + entriesUpdated
                let afterCoverage = statistics.totalEntries > 0 ? Double(afterEntriesWithHash) / Double(statistics.totalEntries) : 0.0
                afterJSON = HashCoverageStatisticsJSON(
                    totalEntries: statistics.totalEntries,
                    entriesWithHash: afterEntriesWithHash,
                    entriesMissingHash: statistics.totalEntries - afterEntriesWithHash,
                    hashCoverage: afterCoverage
                )
            } else {
                afterJSON = nil
            }
            
            let output = UpdateOutput(
                library: libraryPath,
                before: beforeJSON,
                after: afterJSON,
                hashesComputed: hashesComputed,
                hashFailures: hashFailures,
                entriesUpdated: entriesUpdated,
                indexUpdated: indexUpdated,
                limit: limit
            )
            
            guard let data = try? encoder.encode(output),
                  let jsonString = String(data: data, encoding: .utf8) else {
                return "{}"
            }
            return jsonString
        }
    }
}

/// Output format for duplicate reports
enum DuplicateReportFormat {
    case text
    case json
    case csv
}

/// Formats duplicate report output
struct DuplicateReportFormatter: OutputFormatter {
    let libraryPath: String
    let groups: [DuplicateGroup]
    let summary: DuplicateSummary
    let outputFormat: DuplicateReportFormat
    
    func format() -> String {
        switch outputFormat {
        case .text:
            return formatText()
        case .json:
            return formatJSON()
        case .csv:
            return formatCSV()
        }
    }
    
    private func formatText() -> String {
        // Get library name from path (last component)
        let libraryName = (libraryPath as NSString).lastPathComponent
        
        // Generate timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let generated = dateFormatter.string(from: Date())
        
        var output = "Duplicate Report for Library: \(libraryName)\n"
        output += "Generated: \(generated)\n\n"
        
        if groups.isEmpty {
            output += "No duplicates found.\n"
            return output
        }
        
        output += "Found \(summary.duplicateGroups) duplicate groups containing \(summary.totalDuplicateFiles) total files\n\n"
        
        // Format each group
        for (index, group) in groups.enumerated() {
            let totalSizeMB = formatSizeBytes(group.totalSizeBytes)
            output += "Group \(index + 1): Hash \(group.hash) (\(group.fileCount) files, \(totalSizeMB) total)\n"
            
            // Format each file in the group
            for file in group.files {
                let fileSizeMB = formatSizeBytes(file.sizeBytes)
                // Format timestamp for display (simplify ISO8601 to readable format)
                let displayTimestamp = formatTimestamp(file.timestamp)
                output += "  - \(file.path) (\(fileSizeMB)) [\(displayTimestamp)]\n"
            }
            
            if index < groups.count - 1 {
                output += "\n"
            }
        }
        
        output += "\nSummary:\n"
        output += "- Total duplicate groups: \(summary.duplicateGroups)\n"
        output += "- Total duplicate files: \(summary.totalDuplicateFiles)\n"
        let totalSizeMB = formatSizeBytes(summary.totalDuplicateSizeBytes)
        output += "- Total space used by duplicates: \(totalSizeMB)\n"
        let savingsMB = formatSizeBytes(summary.potentialSavingsBytes)
        output += "- Potential space savings: ~\(savingsMB) (keep 1 copy per group)\n"
        
        return output
    }
    
    private func formatJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        // Get library name from path
        let libraryName = (libraryPath as NSString).lastPathComponent
        
        // Generate ISO8601 timestamp
        let generated = ISO8601DateFormatter().string(from: Date())
        
        struct DuplicateReportJSON: Codable {
            let library: String
            let generated: String
            let summary: SummaryJSON
            let groups: [GroupJSON]
        }
        
        struct SummaryJSON: Codable {
            let duplicateGroups: Int
            let totalDuplicateFiles: Int
            let totalDuplicateSizeBytes: Int64
            let potentialSavingsBytes: Int64
        }
        
        struct GroupJSON: Codable {
            let hash: String
            let fileCount: Int
            let totalSizeBytes: Int64
            let files: [FileJSON]
        }
        
        struct FileJSON: Codable {
            let path: String
            let sizeBytes: Int64
            let timestamp: String
        }
        
        let report = DuplicateReportJSON(
            library: libraryName,
            generated: generated,
            summary: SummaryJSON(
                duplicateGroups: summary.duplicateGroups,
                totalDuplicateFiles: summary.totalDuplicateFiles,
                totalDuplicateSizeBytes: summary.totalDuplicateSizeBytes,
                potentialSavingsBytes: summary.potentialSavingsBytes
            ),
            groups: groups.map { group in
                GroupJSON(
                    hash: group.hash,
                    fileCount: group.fileCount,
                    totalSizeBytes: group.totalSizeBytes,
                    files: group.files.map { file in
                        FileJSON(
                            path: file.path,
                            sizeBytes: file.sizeBytes,
                            timestamp: file.timestamp
                        )
                    }
                )
            }
        )
        
        guard let data = try? encoder.encode(report),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        
        return jsonString
    }
    
    private func formatCSV() -> String {
        // CSV header
        var output = "group_hash,file_count,total_size_bytes,path,size_bytes,timestamp\n"
        
        // One row per file, with group metadata repeated
        for group in groups {
            for file in group.files {
                // Escape CSV values (handle commas, quotes, newlines in paths)
                let escapedHash = escapeCSV(group.hash)
                let escapedPath = escapeCSV(file.path)
                let escapedTimestamp = escapeCSV(file.timestamp)
                
                output += "\(escapedHash),\(group.fileCount),\(group.totalSizeBytes),\(escapedPath),\(file.sizeBytes),\(escapedTimestamp)\n"
            }
        }
        
        return output
    }
    
    /// Formats bytes to human-readable size (MB)
    private func formatSizeBytes(_ bytes: Int64) -> String {
        let mb = Double(bytes) / (1024.0 * 1024.0)
        if mb < 0.1 {
            return String(format: "%.0f bytes", Double(bytes))
        } else {
            return String(format: "%.1f MB", mb)
        }
    }
    
    /// Formats ISO8601 timestamp to readable format
    private func formatTimestamp(_ iso8601: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: iso8601) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return displayFormatter.string(from: date)
        }
        return iso8601
    }
    
    /// Escapes CSV values (wraps in quotes if needed, doubles internal quotes)
    private func escapeCSV(_ value: String) -> String {
        // If value contains comma, quote, or newline, wrap in quotes and double internal quotes
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }
}
