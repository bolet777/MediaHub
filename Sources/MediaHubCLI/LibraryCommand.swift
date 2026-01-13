//
//  LibraryCommand.swift
//  MediaHubCLI
//
//  Library management commands
//

import ArgumentParser
import Foundation
import MediaHub

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

struct LibraryCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "library",
        abstract: "Manage MediaHub libraries",
        subcommands: [
            LibraryCreateCommand.self,
            LibraryOpenCommand.self,
            LibraryListCommand.self,
            LibraryAdoptCommand.self,
        ]
    )
}

struct LibraryCreateCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "create",
        abstract: "Create a new MediaHub library"
    )
    
    @Argument(help: "Path where the library should be created")
    var path: String
    
    @Flag(name: .shortAndLong, help: "Output results in JSON format")
    var json: Bool = false
    
    func run() throws {
        let creator = LibraryCreator(confirmationHandler: DefaultConfirmationHandler())
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<LibraryMetadata, LibraryCreationError>?
        
        creator.createLibrary(at: path) { creationResult in
            result = creationResult
            semaphore.signal()
        }
        
        semaphore.wait()
        
        switch result! {
        case .success(let metadata):
            if json {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(metadata)
                print(String(data: data, encoding: .utf8) ?? "{}")
            } else {
                print("Library created successfully at: \(path)")
                print("Library ID: \(metadata.libraryId)")
                print("Version: \(metadata.libraryVersion)")
            }
        case .failure(let error):
            let message = ErrorFormatter.format(error)
            FileHandle.standardError.write(("Error: \(message)\n").data(using: .utf8) ?? Data())
            throw ExitCode.failure
        }
    }
}

struct LibraryOpenCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "open",
        abstract: "Open and display information about a MediaHub library"
    )
    
    @Argument(help: "Path to the library")
    var path: String
    
    @Flag(name: .shortAndLong, help: "Output results in JSON format")
    var json: Bool = false
    
    func run() throws {
        do {
            let library = try LibraryContext.openLibrary(at: path)
            
            if json {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                struct LibraryInfo: Codable {
                    let path: String
                    let identifier: String
                    let version: String
                }
                let info = LibraryInfo(
                    path: library.rootURL.path,
                    identifier: library.metadata.libraryId,
                    version: library.metadata.libraryVersion
                )
                let data = try encoder.encode(info)
                print(String(data: data, encoding: .utf8) ?? "{}")
            } else {
                print("Library opened successfully")
                print("Path: \(library.rootURL.path)")
                print("ID: \(library.metadata.libraryId)")
                print("Version: \(library.metadata.libraryVersion)")
                if library.isLegacy {
                    print("Note: This is a legacy library that was adopted")
                }
            }
        } catch {
            let message = ErrorFormatter.format(error)
            FileHandle.standardError.write(("Error: \(message)\n").data(using: .utf8) ?? Data())
            throw ExitCode.failure
        }
    }
}

struct LibraryListCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all discoverable MediaHub libraries"
    )
    
    @Flag(name: .shortAndLong, help: "Output results in JSON format")
    var json: Bool = false
    
    func run() throws {
        do {
            let discoverer = LibraryDiscoverer()
            let libraries = try discoverer.discoverAll()
            
            let formatter = LibraryListFormatter(
                libraries: libraries,
                outputFormat: json ? .json : .humanReadable
            )
            print(formatter.format())
        } catch {
            let message = ErrorFormatter.format(error)
            FileHandle.standardError.write(("Error: \(message)\n").data(using: .utf8) ?? Data())
            throw ExitCode.failure
        }
    }
}

struct LibraryAdoptCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "adopt",
        abstract: "Adopt an existing directory as a MediaHub library",
        discussion: """
        Adopts an existing media library directory that already contains organized media files.
        This operation creates only .mediahub/ metadata and does not modify, move, rename, or
        delete any existing media files.
        """
    )
    
    @Argument(help: "Path to the directory to adopt")
    var path: String
    
    @Flag(name: .long, help: "Preview adoption operations without creating metadata")
    var dryRun: Bool = false
    
    @Flag(name: .long, help: "Skip confirmation prompt")
    var yes: Bool = false
    
    @Flag(name: .shortAndLong, help: "Output results in JSON format")
    var json: Bool = false
    
    /// Detects if the CLI is running in interactive mode (TTY available)
    /// - Parameter stdinFileDescriptor: File descriptor for stdin (injectable for testing, defaults to 0)
    /// - Returns: true if running in interactive mode (TTY available), false otherwise
    static func isInteractive(stdinFileDescriptor: Int32 = 0) -> Bool {
        return isatty(stdinFileDescriptor) != 0
    }
    
    /// Prompts user for confirmation before adoption
    /// - Parameters:
    ///   - path: Path to the directory to adopt
    ///   - baselineScanSummary: Summary of baseline scan (file count)
    ///   - stdinFileDescriptor: File descriptor for stdin (injectable for testing)
    /// - Returns: true if user confirmed, false if user cancelled
    static func promptForConfirmation(
        path: String,
        baselineScanSummary: BaselineScanSummary,
        stdinFileDescriptor: Int32 = 0
    ) -> Bool {
        // Task 5.5: Format confirmation prompt
        print("Adopt library at: \(path)")
        print("Metadata location: \(path)/.mediahub/library.json")
        print("Baseline scan: \(baselineScanSummary.fileCount) file(s) found")
        print("Note: No media files will be modified; only .mediahub metadata will be created.")
        print("Proceed with adoption? [yes/no]: ", terminator: "")
        fflush(stdout)
        
        // Read user input
        // Note: Ctrl+C during readLine() will be handled by the system and may cause
        // readLine() to return nil. We handle this gracefully below.
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
        // Task 1.5: Quick user-facing path validation
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            let message = ErrorFormatter.format(LibraryAdoptionError.pathDoesNotExist)
            FileHandle.standardError.write(("Error: \(message)\n").data(using: .utf8) ?? Data())
            throw ExitCode.failure
        }
        
        guard isDirectory.boolValue else {
            let message = ErrorFormatter.format(LibraryAdoptionError.pathIsNotDirectory)
            FileHandle.standardError.write(("Error: \(message)\n").data(using: .utf8) ?? Data())
            throw ExitCode.failure
        }
        
        // Task 1.10: Ensure dry-run skips confirmation
        // Task 1.8, 1.9: Handle confirmation prompts
        if !dryRun && !yes {
            // Check if we're in interactive mode
            let interactive = Self.isInteractive()
            
            if !interactive {
                // Task 1.6: Non-interactive mode requires --yes flag
                let message = ErrorFormatter.format(CLIError.nonInteractiveModeRequiresYes)
                FileHandle.standardError.write(("Error: \(message)\n").data(using: .utf8) ?? Data())
                throw ExitCode.failure
            }
            
            // Interactive mode: perform dry-run preview to get baseline scan info
            let previewResult = try LibraryAdopter.adoptLibrary(at: path, dryRun: true)
            
            // Task 1.8: Prompt for confirmation
            let confirmed = Self.promptForConfirmation(
                path: path,
                baselineScanSummary: previewResult.baselineScan
            )
            
            // Task 1.9: Handle user cancellation (exit code 0, not an error)
            if !confirmed {
                print("Adoption cancelled.")
                return // Exit code 0 (not an error)
            }
        }
        
        // Set up SIGINT handler for graceful interruption during adoption
        let previousHandler = signal(SIGINT) { _ in
            print("\nInterrupted: adoption cancelled. No files were modified.")
            Foundation.exit(0)
        }
        
        defer {
            // Restore previous signal handler
            signal(SIGINT, previousHandler)
        }
        
        // Task 1.7: Route to adoption execution
        do {
            let result = try LibraryAdopter.adoptLibrary(at: path, dryRun: dryRun)
            
            // Task 5.1-5.4: Format output
            let formatter = LibraryAdoptionFormatter(
                result: result,
                outputFormat: json ? .json : .humanReadable,
                dryRun: dryRun
            )
            print(formatter.format())
            
        } catch let error as LibraryAdoptionError {
            // Handle idempotent adoption (already adopted)
            if case .alreadyAdopted = error {
                let formatter = LibraryAdoptionIdempotentFormatter(
                    path: path,
                    outputFormat: json ? .json : .humanReadable
                )
                print(formatter.format())
                // Exit code 0 (not an error)
                return
            }
            
            // Other errors
            let message = ErrorFormatter.format(error)
            FileHandle.standardError.write(("Error: \(message)\n").data(using: .utf8) ?? Data())
            throw ExitCode.failure
        } catch {
            let message = ErrorFormatter.format(error)
            FileHandle.standardError.write(("Error: \(message)\n").data(using: .utf8) ?? Data())
            throw ExitCode.failure
        }
    }
}
