//
//  DuplicatesCommand.swift
//  MediaHubCLI
//
//  Duplicates command - reports duplicate files by content hash
//

import ArgumentParser
import Foundation
import MediaHub

struct DuplicatesCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "duplicates",
        abstract: "Report duplicate files by content hash"
    )

    @Option(name: .long, help: "Output format: text, json, csv")
    var format: String = "text"

    @Option(name: .long, help: "Output file path (default: stdout)")
    var output: String?

    func run() throws {
        // Require library context
        let libraryPath = try LibraryContext.requireLibraryPath(from: nil)

        // Parse and validate format
        let reportFormat: DuplicateReportFormat
        switch format.lowercased() {
        case "text":
            reportFormat = .text
        case "json":
            reportFormat = .json
        case "csv":
            reportFormat = .csv
        default:
            throw ValidationError("Invalid format '\(format)'. Must be one of: text, json, csv")
        }

        // Validate output path early (fail fast)
        if let outputPath = output {
            try validateOutputPath(outputPath)
        }

        // Analyze duplicates using core component
        let (groups, summary) = try DuplicateReporting.analyzeDuplicates(in: libraryPath)

        // Format report
        let formatter = DuplicateReportFormatter(
            libraryPath: libraryPath,
            groups: groups,
            summary: summary,
            outputFormat: reportFormat
        )
        let reportContent = formatter.format()

        // Write to file or stdout
        if let outputPath = output {
            try writeReportToFile(reportContent, to: outputPath)
            // Minimal stdout feedback when writing to file
            print("Report written to \(outputPath)")
        } else {
            print(reportContent)
        }
    }

    /// Validates that the output path is writable (fail fast before processing)
    private func validateOutputPath(_ path: String) throws {
        let fileURL = URL(fileURLWithPath: path)
        let fileManager = FileManager.default

        // Check if parent directory exists and is writable
        let parentDir = fileURL.deletingLastPathComponent()
        let parentPath = parentDir.path

        // Check if parent directory exists
        var isDirectory: ObjCBool = false
        if !fileManager.fileExists(atPath: parentPath, isDirectory: &isDirectory) || !isDirectory.boolValue {
            // Try to create parent directory to check if we can
            do {
                try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                throw ValidationError("Cannot create output directory at \(parentPath): \(error.localizedDescription)")
            }
        }

        // Check if parent directory is writable
        if !fileManager.isWritableFile(atPath: parentPath) {
            throw ValidationError("Output directory is not writable: \(parentPath)")
        }

        // If file exists, check if it's writable
        if fileManager.fileExists(atPath: path) {
            if !fileManager.isWritableFile(atPath: path) {
                throw ValidationError("Output file exists and is not writable: \(path)")
            }
        }
    }

    /// Writes report content to file atomically
    private func writeReportToFile(_ content: String, to path: String) throws {
        let fileURL = URL(fileURLWithPath: path)
        let fileManager = FileManager.default

        // Ensure parent directory exists
        let parentDir = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true, attributes: nil)

        // Write content atomically
        guard let data = content.data(using: .utf8) else {
            throw ValidationError("Failed to encode report content as UTF-8")
        }

        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw ValidationError("Failed to write report to \(path): \(error.localizedDescription)")
        }
    }
}
