//
//  SourceCommand.swift
//  MediaHubCLI
//
//  Source management commands
//

import ArgumentParser
import Foundation
import MediaHub

struct SourceCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "source",
        abstract: "Manage sources attached to a library",
        subcommands: [
            SourceAttachCommand.self,
            SourceListCommand.self,
        ]
    )
}

struct SourceAttachCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "attach",
        abstract: "Attach a source folder to a library"
    )
    
    @Argument(help: "Path to the source folder")
    var path: String
    
    @Option(name: .long, help: "Library path (or set MEDIAHUB_LIBRARY environment variable)")
    var library: String?
    
    @Option(name: .long, help: "Media types to process: images, videos, or both (default: both)")
    var mediaTypes: String?
    
    @Flag(name: .shortAndLong, help: "Output results in JSON format")
    var json: Bool = false
    
    func run() throws {
        // Require library context
        let libraryPath = try LibraryContext.requireLibraryPath(from: library)
        let library = try LibraryContext.openLibrary(at: libraryPath)
        
        // Validate source path
        guard FileManager.default.fileExists(atPath: path) else {
            throw CLIError.invalidArgument("Source path does not exist: \(path)")
        }
        
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw CLIError.invalidArgument("Source path is not a directory: \(path)")
        }
        
        // Parse and validate media types
        let parsedMediaTypes: SourceMediaTypes?
        if let mediaTypesString = mediaTypes {
            // Case-insensitive parsing: normalize to lowercase
            let normalized = mediaTypesString.lowercased()
            guard let parsed = SourceMediaTypes(rawValue: normalized) else {
                throw CLIError.invalidArgument(
                    "Invalid media types value: '\(mediaTypesString)'. Valid values: images, videos, both"
                )
            }
            parsedMediaTypes = parsed
        } else {
            // Flag omitted: default to nil, which means .both
            parsedMediaTypes = nil
        }
        
        // Validate source
        let source = Source(
            sourceId: UUID().uuidString,
            type: .folder,
            path: (path as NSString).standardizingPath,
            mediaTypes: parsedMediaTypes
        )
        
        let validationResult = SourceValidator.validateBeforeAttachment(
            source: source,
            type: .folder
        )
        guard validationResult.isValid else {
            let errorMessage = SourceValidator.generateErrorMessage(from: validationResult.errors)
            throw CLIError.invalidArgument("Source validation failed: \(errorMessage)")
        }
        
        // Attach source to library
        do {
            try SourceAssociationManager.attach(
                source: source,
                to: library.rootURL,
                libraryId: library.metadata.libraryId
            )
            
            if json {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(source)
                print(String(data: data, encoding: .utf8) ?? "{}")
            } else {
                print("Source attached successfully")
                print("Source ID: \(source.sourceId)")
                print("Path: \(source.path)")
            }
        } catch {
            let message = ErrorFormatter.format(error)
            FileHandle.standardError.write(("Error: \(message)\n").data(using: .utf8) ?? Data())
            throw ExitCode.failure
        }
    }
}

struct SourceListCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all sources attached to a library"
    )
    
    @Option(name: .long, help: "Library path (or set MEDIAHUB_LIBRARY environment variable)")
    var library: String?
    
    @Flag(name: .shortAndLong, help: "Output results in JSON format")
    var json: Bool = false
    
    func run() throws {
        // Require library context
        let libraryPath = try LibraryContext.requireLibraryPath(from: library)
        let library = try LibraryContext.openLibrary(at: libraryPath)
        
        do {
            let sources = try SourceAssociationManager.retrieveSources(
                for: library.rootURL,
                libraryId: library.metadata.libraryId
            )
            
            let formatter = SourceListFormatter(
                sources: sources,
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
