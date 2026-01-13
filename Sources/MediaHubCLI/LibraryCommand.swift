//
//  LibraryCommand.swift
//  MediaHubCLI
//
//  Library management commands
//

import ArgumentParser
import Foundation
import MediaHub

struct LibraryCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "library",
        abstract: "Manage MediaHub libraries",
        subcommands: [
            LibraryCreateCommand.self,
            LibraryOpenCommand.self,
            LibraryListCommand.self,
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
