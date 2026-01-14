//
//  IndexCommand.swift
//  MediaHubCLI
//
//  Index management commands
//

import ArgumentParser
import Foundation
import MediaHub

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

struct IndexCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "index",
        abstract: "Manage library index operations",
        subcommands: [
            IndexHashCommand.self,
        ]
    )
}

struct IndexHashCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "hash",
        abstract: "Hash media files and update the library index"
    )
    
    @Flag(name: .long, help: "Preview operations without modifying the index")
    var dryRun: Bool = false
    
    @Option(name: .long, help: "Limit the number of files to process")
    var limit: Int?
    
    @Flag(name: .long, help: "Skip confirmation prompt")
    var yes: Bool = false
    
    @Flag(name: .shortAndLong, help: "Output results in JSON format")
    var json: Bool = false
    
    func run() throws {
        if dryRun {
            // SAFE PASS 2: Dry-run mode - enumerate candidates and statistics only
            // Require library context (from environment variable, no local --library flag)
            let libraryPath = try LibraryContext.requireLibraryPath(from: nil)
            
            do {
                // Select candidates (read-only, no hash computation, no writes)
                let result = try HashCoverageMaintenance.selectCandidates(
                    libraryRoot: libraryPath,
                    limit: limit
                )
                
                // Display dry-run summary
                let formatter = HashCoverageFormatter(
                    libraryPath: libraryPath,
                    statistics: result.statistics,
                    dryRun: true,
                    hashesComputed: nil,
                    hashFailures: nil,
                    entriesUpdated: nil,
                    indexUpdated: nil,
                    limit: limit,
                    outputFormat: json ? .json : .humanReadable
                )
                print(formatter.format())
            } catch let error as HashCoverageMaintenanceError {
                let message = error.localizedDescription
                FileHandle.standardError.write(("Error: \(message)\n").data(using: .utf8) ?? Data())
                throw ExitCode.failure
            } catch {
                let message = ErrorFormatter.format(error)
                FileHandle.standardError.write(("Error: \(message)\n").data(using: .utf8) ?? Data())
                throw ExitCode.failure
            }
        } else {
            // SAFE PASS 4: Non-dry-run mode - compute hashes and write index atomically
            // Require library context (from environment variable, no local --library flag)
            let libraryPath = try LibraryContext.requireLibraryPath(from: nil)
            
            // Check if interactive mode
            let interactive = IndexHashCommand.isInteractive()
            
            // Require --yes flag in non-interactive mode
            if !interactive && !yes {
                let message = ErrorFormatter.format(CLIError.nonInteractiveModeRequiresYes)
                FileHandle.standardError.write(("Error: \(message)\n").data(using: .utf8) ?? Data())
                throw ExitCode.failure
            }
            
            // Prompt for confirmation in interactive mode (unless --yes)
            if interactive && !yes {
                // First, get preview to show what will be done
                let previewResult = try HashCoverageMaintenance.selectCandidates(
                    libraryRoot: libraryPath,
                    limit: limit
                )
                
                let confirmed = IndexHashCommand.promptForConfirmation(
                    libraryPath: libraryPath,
                    candidateCount: previewResult.statistics.candidateCount,
                    limit: limit
                )
                
                if !confirmed {
                    print("Operation cancelled.")
                    return // Exit code 0 (not an error)
                }
            }
            
            do {
                // Compute missing hashes
                let computationResult = try HashCoverageMaintenance.computeMissingHashes(
                    libraryRoot: libraryPath,
                    limit: limit
                )
                
                // Apply computed hashes and write index atomically
                let updateResult = try HashCoverageMaintenance.applyComputedHashesAndWriteIndex(
                    libraryRoot: libraryPath,
                    computedHashes: computationResult.computedHashes
                )
                
                // Display summary
                let formatter = HashCoverageFormatter(
                    libraryPath: libraryPath,
                    statistics: updateResult.statisticsBefore,
                    dryRun: false,
                    hashesComputed: computationResult.hashesComputed,
                    hashFailures: computationResult.hashFailures > 0 ? computationResult.hashFailures : nil,
                    entriesUpdated: updateResult.entriesUpdated,
                    indexUpdated: updateResult.indexUpdated,
                    limit: limit,
                    outputFormat: json ? .json : .humanReadable
                )
                print(formatter.format())
            } catch let error as HashCoverageMaintenanceError {
                let message = error.localizedDescription
                FileHandle.standardError.write(("Error: \(message)\n").data(using: .utf8) ?? Data())
                throw ExitCode.failure
            } catch {
                let message = ErrorFormatter.format(error)
                FileHandle.standardError.write(("Error: \(message)\n").data(using: .utf8) ?? Data())
                throw ExitCode.failure
            }
        }
    }
    
    /// Detects if the CLI is running in interactive mode (TTY available)
    /// - Parameter stdinFileDescriptor: File descriptor for stdin (injectable for testing, defaults to 0)
    /// - Returns: true if running in interactive mode (TTY available), false otherwise
    static func isInteractive(stdinFileDescriptor: Int32 = 0) -> Bool {
        return isatty(stdinFileDescriptor) != 0
    }
    
    /// Prompts user for confirmation before hash computation and index update
    /// - Parameters:
    ///   - libraryPath: Path to the library
    ///   - candidateCount: Number of files that will be processed
    ///   - limit: Optional limit on number of files
    ///   - stdinFileDescriptor: File descriptor for stdin (injectable for testing)
    /// - Returns: true if user confirmed, false if user cancelled
    static func promptForConfirmation(
        libraryPath: String,
        candidateCount: Int,
        limit: Int?,
        stdinFileDescriptor: Int32 = 0
    ) -> Bool {
        print("Library: \(libraryPath)")
        print("Files to process: \(candidateCount)", terminator: "")
        if let limit = limit {
            print(" (limited to \(limit))", terminator: "")
        }
        print("")
        print("This will compute SHA-256 hashes and update the baseline index.")
        print("Proceed? [yes/no]: ", terminator: "")
        fflush(stdout)
        
        // Read user input
        guard let input = readLine() else {
            // EOF or error reading input (including Ctrl+C interruption)
            return false
        }
        
        // Parse user input (case-insensitive, trim whitespace)
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Handle confirmation responses
        switch trimmedInput {
        case "yes", "y":
            return true
        case "no", "n":
            return false
        default:
            // Invalid input, treat as cancellation
            return false
        }
    }
}
