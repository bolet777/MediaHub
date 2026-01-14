//
//  StatusCommand.swift
//  MediaHubCLI
//
//  Status command
//

import ArgumentParser
import Foundation
import MediaHub

struct StatusCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Display library status and information"
    )
    
    @Option(name: .long, help: "Library path (or set MEDIAHUB_LIBRARY environment variable)")
    var library: String?
    
    @Flag(name: .shortAndLong, help: "Output results in JSON format")
    var json: Bool = false
    
    func run() throws {
        // Require library context
        let libraryPath = try LibraryContext.requireLibraryPath(from: library)
        let openedLibrary = try LibraryContext.openLibrary(at: libraryPath)
        
        // Retrieve sources
        let sources = try SourceAssociationManager.retrieveSources(
            for: openedLibrary.rootURL,
            libraryId: openedLibrary.metadata.libraryId
        )
        
        // Try to load baseline index for hash coverage stats (optional, backward compatible)
        let indexState = BaselineIndexLoader.tryLoadBaselineIndex(libraryRoot: libraryPath)
        let baselineIndex: BaselineIndex?
        if case .valid(let index) = indexState {
            baselineIndex = index
        } else {
            baselineIndex = nil
        }
        
        // Format and output status
        let formatter = StatusFormatter(
            library: openedLibrary,
            sources: sources,
            baselineIndex: baselineIndex,
            outputFormat: json ? .json : .humanReadable
        )
        print(formatter.format())
    }
}
