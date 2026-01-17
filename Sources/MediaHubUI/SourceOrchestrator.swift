//
//  SourceOrchestrator.swift
//  MediaHubUI
//
//  Source orchestration for Core API calls
//

import Foundation
import MediaHub

struct SourceOrchestrator {
    static func loadSources(
        libraryRootURL: URL,
        libraryId: String
    ) async throws -> [Source] {
        return try await Task.detached {
            try SourceAssociationManager.retrieveSources(
                for: libraryRootURL,
                libraryId: libraryId
            )
        }.value
    }
    
    static func attachSource(
        path: String,
        mediaTypes: SourceMediaTypes,
        libraryRootURL: URL,
        libraryId: String
    ) async throws -> Source {
        do {
            return try await Task.detached {
                let standardizedPath = (path as NSString).standardizingPath
                let source = Source(
                    sourceId: UUID().uuidString,
                    type: .folder,
                    path: standardizedPath,
                    attachedAt: nil,
                    lastDetectedAt: nil,
                    mediaTypes: mediaTypes
                )
                
                try SourceAssociationManager.attach(
                    source: source,
                    to: libraryRootURL,
                    libraryId: libraryId
                )
                
                return source
            }.value
        } catch let error as SourceAssociationError {
            throw mapSourceAssociationError(error)
        } catch {
            throw error
        }
    }
    
    static func detachSource(
        sourceId: String,
        libraryRootURL: URL,
        libraryId: String
    ) async throws {
        do {
            try await Task.detached {
                try SourceAssociationManager.detach(
                    sourceId: sourceId,
                    from: libraryRootURL,
                    libraryId: libraryId
                )
            }.value
        } catch let error as SourceAssociationError {
            throw mapSourceAssociationError(error)
        } catch {
            throw error
        }
    }
    
    private static func mapSourceAssociationError(_ error: SourceAssociationError) -> Error {
        switch error {
        case .duplicateSource(_):
            return NSError(domain: "SourceOrchestrator", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "This source is already attached to the library."
            ])
        case .invalidLibraryId(let id):
            return NSError(domain: "SourceOrchestrator", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Invalid library identifier: \(id)"
            ])
        case .permissionDenied:
            return NSError(domain: "SourceOrchestrator", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Permission denied. Please check folder permissions."
            ])
        case .fileNotFound:
            return NSError(domain: "SourceOrchestrator", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "Library metadata file not found."
            ])
        default:
            return NSError(domain: "SourceOrchestrator", code: 5, userInfo: [
                NSLocalizedDescriptionKey: error.localizedDescription
            ])
        }
    }
}
