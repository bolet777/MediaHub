//
//  DetectionOrchestration.swift
//  MediaHub
//
//  Detection execution and orchestration
//

import Foundation

/// Errors that can occur during detection orchestration
public enum DetectionOrchestrationError: Error, LocalizedError {
    case sourceInaccessible(String)
    case scanningFailed(SourceScanningError)
    case comparisonFailed(LibraryComparisonError)
    case resultGenerationFailed(DetectionResultError)
    case sourceUpdateFailed(SourceAssociationError)
    
    public var errorDescription: String? {
        switch self {
        case .sourceInaccessible(let path):
            return "Source is inaccessible: \(path)"
        case .scanningFailed(let error):
            return "Scanning failed: \(error.localizedDescription)"
        case .comparisonFailed(let error):
            return "Comparison failed: \(error.localizedDescription)"
        case .resultGenerationFailed(let error):
            return "Result generation failed: \(error.localizedDescription)"
        case .sourceUpdateFailed(let error):
            return "Source update failed: \(error.localizedDescription)"
        }
    }
}

/// Orchestrates the complete detection workflow
public struct DetectionOrchestrator {
    /// Executes a complete detection run on a Source
    ///
    /// - Parameters:
    ///   - source: The Source to detect
    ///   - libraryRootURL: The URL of the library root directory
    ///   - libraryId: The Library identifier
    /// - Returns: Detection result
    /// - Throws: `DetectionOrchestrationError` if detection fails
    public static func executeDetection(
        source: Source,
        libraryRootURL: URL,
        libraryId: String
    ) throws -> DetectionResult {
        // Step 1: Validate Source accessibility
        let validationResult = SourceValidator.validateDuringDetection(source)
        guard validationResult.isValid else {
            let errorMessage = SourceValidator.generateErrorMessage(from: validationResult.errors)
            throw DetectionOrchestrationError.sourceInaccessible(errorMessage)
        }
        
        // Step 2: Scan Source for candidate media files
        let candidates: [CandidateMediaItem]
        do {
            candidates = try SourceScanner.scan(source: source)
        } catch let error as SourceScanningError {
            throw DetectionOrchestrationError.scanningFailed(error)
        }
        
        // Sort candidates by path for determinism
        let sortedCandidates = candidates.sorted { $0.path < $1.path }
        
        // Step 3: Query Library contents (try index first, fallback to full scan)
        let libraryPaths: Set<String>
        let indexState: IndexUsageState
        let indexMetadata: DetectionResult.IndexMetadata?
        let libraryHashSet: Set<String>
        let libraryHashToPath: [String: String]
        let hashCoverage: Double?
        
        // Try to load baseline index (READ-ONLY: never creates or modifies index)
        indexState = BaselineIndexLoader.tryLoadBaselineIndex(libraryRoot: libraryRootURL.path)
        
        switch indexState {
        case .valid(let index):
            // Extract normalized paths from index entries
            libraryPaths = Set(index.entries.map { $0.path })
            indexMetadata = DetectionResult.IndexMetadata(
                version: index.version,
                entryCount: index.entryCount,
                lastUpdated: index.lastUpdated
            )
            // Extract hash set and hash-to-path mapping for duplicate detection
            libraryHashSet = index.hashSet
            libraryHashToPath = index.hashToAnyPath
            hashCoverage = index.hashCoverage
        case .absent, .invalid:
            // Fallback to full scan
            do {
                libraryPaths = try LibraryContentQuery.scanLibraryContents(at: libraryRootURL)
            } catch let error as LibraryComparisonError {
                throw DetectionOrchestrationError.comparisonFailed(error)
            }
            indexMetadata = nil
            libraryHashSet = Set()
            libraryHashToPath = [:]
            hashCoverage = nil
        }
        
        // Step 3.5: Query known items for this Source (import-detection integration)
        let knownItemsPaths: Set<String>
        do {
            knownItemsPaths = try KnownItemsTracker.queryKnownItems(
                sourceId: source.sourceId,
                libraryRootURL: libraryRootURL
            )
        } catch {
            // If known-items tracking fails, treat as empty set (graceful degradation)
            knownItemsPaths = Set()
        }
        
        // Combine Library paths and known items paths for comparison
        let allKnownPaths = libraryPaths.union(knownItemsPaths)
        
        // Step 4: Compare candidates against Library contents and known items (path-based)
        let comparisonResults = LibraryItemComparator.compareAll(
            candidates: sortedCandidates,
            against: allKnownPaths
        )
        
        // Step 4.5: Compute content hashes for source candidates and detect duplicates by hash
        let sourceRootURL = URL(fileURLWithPath: source.path)
        var hashBasedDuplicates: [CandidateMediaItem: (hash: String, libraryPath: String)] = [:]
        
        for candidate in sortedCandidates {
            // Only compute hash for candidates that are "new" by path (skip known-by-path)
            let comparisonResult = comparisonResults[candidate] ?? .new
            guard comparisonResult == .new else {
                // Skip hash computation for path-based known items
                continue
            }
            
            // Compute content hash for source file
            let candidateURL = URL(fileURLWithPath: candidate.path)
            var contentHash: String? = nil
            
            do {
                contentHash = try ContentHasher.computeHash(for: candidateURL, allowedRoot: sourceRootURL)
            } catch {
                // Hash computation failed - continue without hash (non-fatal)
                // Candidate will be marked as "new" without hash-based duplicate detection
                continue
            }
            
            // Check if hash exists in library hash set
            if let hash = contentHash, libraryHashSet.contains(hash) {
                // Hash match found - duplicate detected
                if let libraryPath = libraryHashToPath[hash] {
                    hashBasedDuplicates[candidate] = (hash: hash, libraryPath: libraryPath)
                }
            }
        }
        
        // Step 5: Generate detection results with status and explanations
        // Combine path-based and hash-based exclusions (union)
        var candidateResults: [CandidateItemResult] = []
        for candidate in sortedCandidates {
            let comparisonResult = comparisonResults[candidate] ?? .new
            let isHashDuplicate = hashBasedDuplicates[candidate] != nil
            
            let status: String
            let exclusionReason: ExclusionReason?
            let duplicateOfHash: String?
            let duplicateOfLibraryPath: String?
            let duplicateReason: String?
            
            // Determine status: if path-based known OR hash-based duplicate, mark as "known"
            // Note: "known" can mean two things:
            // 1. Known by path (exclusionReason = .alreadyKnown, duplicateReason = nil)
            // 2. Known by hash (exclusionReason = nil, duplicateReason = "content_hash")
            // If both are true, prefer path-based (more specific)
            if comparisonResult == .known || isHashDuplicate {
                status = "known"
                
                // Prefer path-based exclusion reason if both exist (path-based is more specific)
                if comparisonResult == .known {
                    // Known by path: use exclusionReason, clear hash-based metadata
                    exclusionReason = .alreadyKnown
                    duplicateOfHash = nil
                    duplicateOfLibraryPath = nil
                    duplicateReason = nil
                } else {
                    // Known by hash only: use duplicateReason and hash metadata
                    let hashInfo = hashBasedDuplicates[candidate]!
                    exclusionReason = nil
                    duplicateOfHash = hashInfo.hash
                    duplicateOfLibraryPath = hashInfo.libraryPath
                    duplicateReason = "content_hash"
                }
            } else {
                // New item (neither path-based nor hash-based duplicate)
                status = "new"
                exclusionReason = nil
                duplicateOfHash = nil
                duplicateOfLibraryPath = nil
                duplicateReason = nil
            }
            
            candidateResults.append(CandidateItemResult(
                item: candidate,
                status: status,
                exclusionReason: exclusionReason,
                duplicateOfHash: duplicateOfHash,
                duplicateOfLibraryPath: duplicateOfLibraryPath,
                duplicateReason: duplicateReason
            ))
        }
        
        // Generate summary
        let newCount = candidateResults.filter { $0.status == "new" }.count
        let knownCount = candidateResults.filter { $0.status == "known" }.count
        
        let summary = DetectionSummary(
            totalScanned: candidateResults.count,
            newItems: newCount,
            knownItems: knownCount
        )
        
        // Create detection result with index usage information
        let result = DetectionResult(
            sourceId: source.sourceId,
            libraryId: libraryId,
            candidates: candidateResults,
            summary: summary,
            indexUsed: indexState.isValid,
            indexFallbackReason: indexState.fallbackReason,
            indexMetadata: indexMetadata,
            hashCoverage: hashCoverage
        )
        
        // Step 6: Store detection result
        let resultFileURL = DetectionResultStorage.resultFileURL(
            for: libraryRootURL,
            sourceId: source.sourceId,
            timestamp: result.detectedAt
        )
        
        do {
            try DetectionResultSerializer.write(result, to: resultFileURL)
        } catch let error as DetectionResultError {
            throw DetectionOrchestrationError.resultGenerationFailed(error)
        }
        
        // Step 7: Update Source metadata (lastDetectedAt)
        do {
            try updateSourceLastDetected(
                sourceId: source.sourceId,
                libraryRootURL: libraryRootURL,
                libraryId: libraryId,
                timestamp: result.detectedAt
            )
        } catch let error as SourceAssociationError {
            throw DetectionOrchestrationError.sourceUpdateFailed(error)
        }
        
        return result
    }
    
    /// Updates Source lastDetectedAt timestamp
    ///
    /// - Parameters:
    ///   - sourceId: Source identifier
    ///   - libraryRootURL: Library root URL
    ///   - libraryId: Library identifier
    ///   - timestamp: Detection timestamp
    /// - Throws: `SourceAssociationError` if update fails
    private static func updateSourceLastDetected(
        sourceId: String,
        libraryRootURL: URL,
        libraryId: String,
        timestamp: String
    ) throws {
        let fileURL = SourceAssociationStorage.associationsFileURL(for: libraryRootURL)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            // No associations file - nothing to update
            return
        }
        
        var association = try SourceAssociationSerializer.read(from: fileURL)
        
        // Validate libraryId matches
        guard association.libraryId == libraryId else {
            throw SourceAssociationError.invalidLibraryId(libraryId)
        }
        
        // Find and update source
        guard let index = association.sources.firstIndex(where: { $0.sourceId == sourceId }) else {
            throw SourceAssociationError.sourceNotFound(sourceId)
        }
        
        // Update source with new lastDetectedAt (preserve mediaTypes field)
        let updatedSource = Source(
            sourceId: association.sources[index].sourceId,
            type: association.sources[index].type,
            path: association.sources[index].path,
            attachedAt: association.sources[index].attachedAt,
            lastDetectedAt: timestamp,
            mediaTypes: association.sources[index].mediaTypes
        )
        
        association.sources[index] = updatedSource
        
        // Write back
        try SourceAssociationSerializer.write(association, to: fileURL)
    }
}
