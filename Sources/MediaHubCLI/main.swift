import ArgumentParser
import Foundation
import MediaHub

struct MediaHubCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "mediahub",
        abstract: "MediaHub - Media library management CLI",
        subcommands: [
            LibraryCommand.self,
            SourceCommand.self,
            DetectCommand.self,
            ImportCommand.self,
            IndexCommand.self,
            StatusCommand.self,
        ],
        defaultSubcommand: nil
    )
}

MediaHubCommand.main()
