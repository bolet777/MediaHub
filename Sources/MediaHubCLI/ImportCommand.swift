//
//  ImportCommand.swift
//  MediaHubCLI
//
//  Import command
//

import ArgumentParser
import Foundation
import MediaHub

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
                options: options
            )
            
            progress.showImportProgress(stage: "Import complete", current: result.summary.imported, total: result.summary.total)
            
            // Format and output result
            let formatter = ImportResultFormatter(
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
