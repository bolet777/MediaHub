//
//  DetectCommand.swift
//  MediaHubCLI
//
//  Detection command
//

import ArgumentParser
import Foundation
import MediaHub

struct DetectCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "detect",
        abstract: "Run detection on a source to find new media items",
        discussion: """
        Read-only operation: Detection does not modify source files or copy media files.
        Detection may write result files in the library's .mediahub directory, but never
        modifies source files or copies media files.
        """
    )
    
    @Argument(help: "Source identifier")
    var sourceId: String
    
    @Option(name: .long, help: "Library path (or set MEDIAHUB_LIBRARY environment variable)")
    var library: String?
    
    @Flag(name: .shortAndLong, help: "Output results in JSON format")
    var json: Bool = false
    
    func run() throws {
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
        
        guard let source = sources.first(where: { $0.sourceId == sourceId }) else {
            throw CLIError.sourceNotFound(sourceId)
        }
        
        // Show progress
        let progress = ProgressIndicator(isJSONMode: json)
        progress.showDetectionProgress(stage: "Scanning source")
        
        // Run detection
        do {
            let result = try DetectionOrchestrator.executeDetection(
                source: source,
                libraryRootURL: openedLibrary.rootURL,
                libraryId: openedLibrary.metadata.libraryId
            )
            
            progress.showDetectionProgress(stage: "Detection complete", itemCount: result.summary.totalScanned)
            
            // Format and output result
            let formatter = DetectionResultFormatter(
                result: result,
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
