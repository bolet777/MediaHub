//
//  ImportCommand.swift
//  MediaHubCLI
//
//  Import command
//

import ArgumentParser
import Foundation
import MediaHub

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

struct ImportCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "import",
        abstract: "Import detected items into the library"
    )
    
    @Argument(help: "Source identifier")
    var sourceId: String
    
    @Flag(name: .long, help: "Import all detected items")
    var all: Bool = false
    
    @Option(name: .long, help: "Library path (or set MEDIAHUB_LIBRARY environment variable)")
    var library: String?
    
    @Flag(name: .shortAndLong, help: "Output results in JSON format")
    var json: Bool = false
    
    @Flag(name: .long, help: "Preview import operations without copying files")
    var dryRun: Bool = false
    
    @Flag(name: .long, help: "Skip confirmation prompt (non-interactive mode)")
    var yes: Bool = false
    
    /// Detects if the CLI is running in interactive mode (TTY available)
    /// - Parameter stdinFileDescriptor: File descriptor for stdin (injectable for testing, defaults to 0)
    /// - Returns: true if running in interactive mode (TTY available), false otherwise
    static func isInteractive(stdinFileDescriptor: Int32 = 0) -> Bool {
        return isatty(stdinFileDescriptor) != 0
    }
    
    /// Prompts user for confirmation before import
    /// - Parameters:
    ///   - itemCount: Number of items to import
    ///   - sourcePath: Path of the source
    ///   - libraryPath: Path of the library
    ///   - stdinFileDescriptor: File descriptor for stdin (injectable for testing)
    /// - Returns: true if user confirmed, false if user cancelled
    /// - Throws: CLIError if confirmation fails or is required but not provided
    static func promptForConfirmation(
        itemCount: Int,
        sourcePath: String,
        libraryPath: String,
        stdinFileDescriptor: Int32 = 0
    ) throws -> Bool {
        // Display confirmation prompt
        let prompt = "Import \(itemCount) item(s) from \(sourcePath) to \(libraryPath)? [yes/no]: "
        print(prompt, terminator: "")
        fflush(stdout)
        
        // Read user input
        // Note: Ctrl+C during readLine() will be handled by the system and may cause
        // readLine() to return nil or throw. We handle this gracefully below.
        guard let input = readLine() else {
            // EOF or error reading input (including Ctrl+C interruption)
            // This is treated as cancellation
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
    
    func run() throws {
        // Require --all flag for P1
        guard all else {
            throw CLIError.invalidArgument("Item selection is required. Use --all to import all detected items.")
        }
        
        // Require library context
        let libraryPath = try LibraryContext.requireLibraryPath(from: library)
        let openedLibrary = try LibraryContext.openLibrary(at: libraryPath)
        
        // Validate source ID
        guard UUID(uuidString: sourceId) != nil else {
            throw CLIError.invalidSourceId(sourceId)
        }
        
        // Retrieve source
        let sources = try SourceAssociationManager.retrieveSources(
            for: openedLibrary.rootURL,
            libraryId: openedLibrary.metadata.libraryId
        )
        
        guard sources.contains(where: { $0.sourceId == sourceId }) else {
            throw CLIError.sourceNotFound(sourceId)
        }
        
        // Find latest detection result
        guard let detectionResult = try DetectionResultRetriever.retrieveLatest(
            for: openedLibrary.rootURL,
            sourceId: sourceId
        ) else {
            throw CLIError.detectionResultNotFound
        }
        
        // Get all new candidate items
        let newItems = detectionResult.candidates
            .filter { $0.status == "new" }
            .map { $0.item }
        
        guard !newItems.isEmpty else {
            if json {
                print("{\"message\": \"No new items to import\"}")
            } else {
                print("No new items to import.")
            }
            return
        }
        
        // Handle confirmation (skip for dry-run, skip for --yes, require --yes in non-interactive)
        if !dryRun && !yes {
            // Check if we're in interactive mode
            let interactive = Self.isInteractive()
            
            if !interactive {
                // Non-interactive mode: require --yes flag
                throw CLIError.nonInteractiveModeRequiresYes
            }
            
            // Interactive mode: prompt for confirmation
            let sourcePath = sources.first(where: { $0.sourceId == sourceId })?.path ?? sourceId
            do {
                let confirmed = try Self.promptForConfirmation(
                    itemCount: newItems.count,
                    sourcePath: sourcePath,
                    libraryPath: libraryPath
                )
                
                if !confirmed {
                    // User cancelled
                    print("Import cancelled.")
                    return
                }
            } catch {
                // Handle cancellation or error
                if error is CLIError {
                    throw error
                }
                print("Import cancelled.")
                return
            }
        }
        
        // Set up SIGINT handler for graceful interruption
        let previousHandler = signal(SIGINT) { _ in
            print("\nInterrupted: import cancelled. Library integrity preserved.")
            Foundation.exit(0)
        }
        
        defer {
            // Restore previous signal handler
            signal(SIGINT, previousHandler)
        }
        
        // Show progress
        let progress = ProgressIndicator(isJSONMode: json)
        progress.showImportProgress(stage: "Starting import", current: 0, total: newItems.count)
        
        // Execute import
        do {
            let options = ImportOptions(collisionPolicy: .skip)
            let result = try ImportExecutor.executeImport(
                detectionResult: detectionResult,
                selectedItems: newItems,
                libraryRootURL: openedLibrary.rootURL,
                libraryId: openedLibrary.metadata.libraryId,
                options: options,
                dryRun: dryRun
            )
            
            let progressStage = dryRun ? "Preview complete" : "Import complete"
            progress.showImportProgress(stage: progressStage, current: result.summary.imported, total: result.summary.total)
            
            // Format and output result
            let formatter = ImportResultFormatter(
                result: result,
                outputFormat: json ? .json : .humanReadable,
                dryRun: dryRun
            )
            print(formatter.format())
        } catch {
            let message = ErrorFormatter.format(error)
            FileHandle.standardError.write(("Error: \(message)\n").data(using: .utf8) ?? Data())
            throw ExitCode.failure
        }
    }
}
