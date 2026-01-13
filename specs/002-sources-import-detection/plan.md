# Implementation Plan: MediaHub Sources & Import Detection (Slice 2)

**Feature**: MediaHub Sources & Import Detection  
**Specification**: `specs/002-sources-import-detection/spec.md`  
**Slice**: 2 - Attaching Sources and detecting new media items for import  
**Created**: 2026-01-12

## Plan Scope

This plan implements **Slice 2 only**, which enables a MediaHub Library to attach one or more Sources and safely detect new media items available for import, without modifying the source or importing files. This includes:

- Attaching a folder-based Source to an existing Library
- Persisting Source-Library associations
- Validating Source accessibility and permissions
- Scanning a Source to detect candidate media files
- Determining which items are new relative to the Library
- Producing deterministic, explainable detection results
- Supporting safe re-runs of detection with no side effects

**Explicitly out of scope**:
- Copying or importing files into the Library
- Media organization (YYYY/MM or otherwise)
- Pipelines, automation, or scheduling
- Metadata editing or enrichment
- Advanced duplicate detection strategies
- UI beyond minimal enablement
- Photos.app or device-specific integrations
- Moving/renaming Source detection (P2, best-effort only)

## Constitutional Compliance

This plan adheres to the MediaHub Constitution:

- **Transparent Storage**: Source associations stored as normal files in standard folder structures
- **Safe Operations**: Source files are never modified during detection; all operations are read-only
- **Deterministic Behavior**: Detection produces identical results for identical source states; re-runs are safe and idempotent
- **Interoperability First**: Source files remain accessible to external tools; detection does not lock or modify files
- **Scalability by Design**: Multiple Sources per Library supported as first-class concern

## Work Breakdown

### Component 1: Source Model & Identity

**Purpose**: Define the Source entity and its persistent identity that survives across application restarts; handling path changes is best-effort (P2).

**Responsibilities**:
- Define the Source data structure (type, path, identity, metadata)
- Define Source identity mechanism (how Sources are uniquely identified)
- Define Source types (folder-based for P1; extensible for future types)
- Ensure Source identity persists across application restarts; path changes are handled best-effort (P2)
- Support Source metadata storage (attachment date, last scan time, etc.)

**Requirements Addressed**:
- FR-001: Support attaching at least one Source to a Library
- FR-002: Support multiple Sources attached to a single Library
- FR-004: Maintain Source identity that persists across application restarts
- FR-005: Support at least folder-based Sources
- FR-015 (P2): Detect when Source has been moved/renamed (best-effort)
- FR-017: Store Source associations in transparent, human-readable format

**Key Decisions**:
- Source identity mechanism (path-based, volume-based, or hybrid approach)
- Source metadata schema (identifier, type, path, attachment timestamp, etc.)
- Storage location for Source associations (within Library structure)
- How to attempt best-effort detection when a Source path changes (P2)
- Whether to support Source metadata versioning

**Validation Points**:
- Source identity persists across application restarts
- Multiple Sources can be attached to a single Library
- Source associations are stored in transparent, human-readable format
- Source identity mechanism works for folder-based Sources

**Risks & Open Questions**:
- How to reliably identify a Source when its path changes? (P2: best-effort only)
- Should Source identity be based on path, volume identifier, or a combination?
- How to handle Sources on external drives that are disconnected?
- Should Source metadata include integrity checksums?

---

### Component 2: Source-Library Association Persistence

**Purpose**: Persistently store and manage associations between Sources and Libraries.

**Responsibilities**:
- Define storage format for Source-Library associations
- Implement association creation (attaching a Source to a Library)
- Implement association retrieval (listing Sources for a Library)
- Implement association validation (ensuring associations are valid)
- Support association removal (detaching a Source from a Library)
- Ensure associations survive application restarts

**Requirements Addressed**:
- FR-001: Support attaching Sources to Libraries
- FR-002: Support multiple Sources per Library
- FR-004: Maintain Source identity across restarts
- FR-017: Store associations in transparent, human-readable format
- User Story 1: Attach a Source to a Library (persistence aspect)
- SC-008: Source associations persist across application restarts 100% of the time

**Key Decisions**:
- Where to store associations (within Library structure, e.g., `.mediahub/sources/`)
- Association storage format (JSON, plist, or similar transparent format)
- Association schema (Library ID, Source ID, attachment metadata, etc.)
- How to handle orphaned associations (Sources that no longer exist)
- Whether to support association metadata (attachment date, last scan, etc.)

**Validation Points**:
- Associations are created and stored correctly
- Associations persist across application restarts
- Multiple Sources can be associated with a single Library
- Associations are stored in transparent, human-readable format
- Associations can be retrieved and validated

**Risks & Open Questions**:
- Should associations be stored per-Library or in a central registry?
- How to handle corrupted association files?
- Should associations include Source status (accessible/inaccessible)?
- How to handle duplicate associations (same Source attached twice)?

---

### Component 3: Source Validation & Accessibility

**Purpose**: Validate that a Source is accessible and has appropriate permissions before attachment and during use.

**Responsibilities**:
- Validate Source path exists and is accessible
- Validate Source has read permissions
- Validate Source type (folder-based for P1)
- Check Source accessibility before attachment
- Check Source accessibility during detection
- Report clear, actionable error messages for validation failures

**Requirements Addressed**:
- FR-003: Validate Source accessibility and permissions before allowing attachment
- FR-012: Report clear errors when Sources are inaccessible or have permission issues
- User Story 1: Validate Source before attachment (acceptance scenarios 2, 3)
- User Story 2: Handle inaccessible Sources during detection (acceptance scenario 5)
- SC-002: Validate Source accessibility within 2 seconds
- SC-009: Report clear, actionable error messages within 5 seconds

**Key Decisions**:
- What validation checks are required vs. optional
- How to validate folder-based Sources (directory existence, read permissions)
- How to handle validation failures (reject, warn, or allow with limitations)
- What constitutes "accessible" (exists, readable, not locked, etc.)
- How to validate Sources on external drives or network volumes

**Validation Points**:
- Valid Sources pass all accessibility checks
- Invalid Sources are detected and reported clearly
- Permission errors are identified and reported
- Validation completes within performance targets
- Error messages are clear and actionable

**Risks & Open Questions**:
- How to handle Sources that are temporarily inaccessible (network volumes, external drives)?
- Should validation check for write permissions (not needed for read-only detection)?
- How to validate Sources on network volumes that may be slow to respond?
- Should validation include checks for sufficient disk space (not needed for read-only detection)?

---

### Component 4: Source Scanning & Media Detection

**Purpose**: Scan a Source to detect candidate media files without modifying the Source.

**Responsibilities**:
- Recursively scan folder-based Sources for media files
- Identify media files by extension and/or content type
- Extract basic file metadata (path, size, modification date, etc.)
- Handle nested folder structures at various depths
- Support common image and video file formats
- Handle edge cases (symbolic links, locked files, corrupted files, etc.)
- Ensure scanning is read-only (never modifies Source files)

**Requirements Addressed**:
- FR-006: Scan a Source to detect candidate media files
- FR-011: Never modify Source files during detection
- FR-016: Support detection of common image and video file formats
- User Story 2: Detect new media items from a Source (acceptance scenarios 1, 5)
- SC-003: Detect candidate items from Source with 1000 files within 30 seconds

**Key Decisions**:
- Which categories of common image and video formats to include in P1 (specific enumerations belong in implementation or tests, not in the plan)
- How to identify media files (extension-based, content-based, or both)
- How to handle nested folder structures (recursive scanning depth limits)
- How to handle edge cases (symbolic links, aliases, locked files, corrupted files)
- Whether to extract file metadata during scanning or defer to comparison phase
- How to handle large Sources (performance optimization strategies)

**Validation Points**:
- All media files in a Source are detected
- Non-media files are excluded from detection
- Scanning completes within performance targets
- Source files are never modified during scanning
- Edge cases are handled gracefully

**Risks & Open Questions**:
- How to handle very large Sources (thousands of files) efficiently?
- Should scanning be incremental or full scan each time?
- How to handle files that appear to be media but are not (text files with image extensions)?
- Should scanning extract metadata (EXIF, etc.) or just basic file properties?
- How to handle symbolic links and aliases (follow or ignore)?

---

### Component 5: Library Comparison & New Item Detection

**Purpose**: Compare detected candidate items against the Library to determine which items are new.

**Responsibilities**:
- Compare candidate items against Library contents
- Identify items already known to the Library
- Exclude known items from candidate lists
- Determine comparison mechanism (path-based, content-based, or identifier-based)
- Ensure comparison is deterministic and repeatable
- Support efficient comparison for large Libraries
> For P1, comparison must remain simple, deterministic, and non-fuzzy; advanced duplicate detection or content-hash-based strategies may be deferred to later slices.

**Requirements Addressed**:
- FR-007: Identify which candidate items are new relative to the Library
- FR-008: Exclude items already known to the Library from candidate lists
- FR-009: Produce deterministic detection results
- User Story 2: Detect new media items (acceptance scenarios 2, 3, 4)
- SC-004: Detection results are 100% deterministic
- SC-005: Re-running detection on unchanged Source produces identical results
- SC-006: Correctly identify items already known to Library with 100% accuracy

**Key Decisions**:
- Comparison mechanism (how to determine if an item is "known" to the Library)
- Which simple, deterministic comparison mechanism to use in P1 (e.g., path- or identifier-based), deferring advanced strategies to later slices
- How to handle items with same content but different paths
- How to handle items that were previously imported but deleted from Library
- Whether comparison should be exact match or fuzzy matching
- How to efficiently compare large numbers of items

**Validation Points**:
- Known items are correctly identified and excluded
- New items are correctly identified and included
- Comparison is deterministic (same inputs produce same results)
- Comparison completes within performance targets
- Comparison accuracy meets success criteria (100%)

**Risks & Open Questions**:
- How to efficiently compare thousands of items against a large Library?
- Should comparison be based on file path, content hash, or both?
- How to handle items that exist in Library but at different paths?
- Should comparison support fuzzy matching or only exact matches?
- How to handle items that were imported but later deleted from Library?

---

### Component 6: Detection Result Model & Storage

**Purpose**: Define and store detection results in an explainable, auditable format.

**Responsibilities**:
- Define detection result data structure (candidate items, status, explanations)
- Store detection results persistently
- Support explainable results (why items were included/excluded)
- Support auditable results (detection run metadata, timestamps, etc.)
- Enable comparison of results from different detection runs
- Ensure results are stored in transparent, human-readable format

**Requirements Addressed**:
- FR-010: Support re-running detection safely without side effects
- FR-013: Maintain detection results in explainable and auditable format
- User Story 3: View detection results (all acceptance scenarios)
- User Story 4: Re-run detection safely (acceptance scenarios 1, 4)
- SC-007: Detection results are explainable

**Key Decisions**:
- Detection result schema (candidate items, status, exclusion reasons, metadata)
- Storage location for detection results (within Library structure)
- Storage format (JSON, plist, or similar transparent format)
- How to represent exclusion reasons (enumeration, codes, or descriptive text)
- Whether to store full detection history or only latest results
- How to enable result comparison across detection runs

**Validation Points**:
- Detection results are stored correctly
- Results include explainable inclusion/exclusion reasons
- Results are stored in transparent, human-readable format
- Results can be retrieved and compared across runs
- Results include necessary metadata (timestamp, Source, etc.)

**Risks & Open Questions**:
- Should detection results be stored per-Source or per-Library?
- How much metadata should be stored with each candidate item?
- Should results include file content hashes for future comparison?
- How to handle very large result sets (thousands of candidates)?
- Should results be versioned or append-only?

---

### Component 7: Detection Execution & Orchestration

**Purpose**: Orchestrate the detection process, coordinating scanning, comparison, and result generation.

**Responsibilities**:
- Coordinate Source scanning and Library comparison
- Execute detection runs end-to-end
- Handle detection interruptions gracefully
- Ensure detection is deterministic and repeatable
- Support safe re-runs of detection
- Report progress and errors during detection
- Ensure no side effects (read-only operations)

**Requirements Addressed**:
- FR-009: Produce deterministic detection results
- FR-010: Support re-running detection safely without side effects
- FR-011: Never modify Source files during detection
- FR-014: Handle detection interruptions gracefully
- User Story 2: Detect new media items (all acceptance scenarios)
- User Story 4: Re-run detection safely (all acceptance scenarios)
- SC-003: Detect candidate items within performance targets
- SC-004: Detection results are 100% deterministic
- SC-005: Re-running detection produces identical results
- SC-010: Detection can be safely interrupted and resumed

**Key Decisions**:
- Detection execution flow (scan → compare → generate results)
- How to handle interruptions (save state, resume, or restart)
- Whether to support incremental detection or only full scans
- How to report progress during long-running detections
- How to ensure determinism (consistent ordering, no side effects)
- Whether to support parallel scanning of multiple Sources

**Validation Points**:
- Detection executes end-to-end successfully
- Detection is deterministic (same Source state produces same results)
- Re-running detection produces identical results when Source unchanged
- Detection handles interruptions gracefully
- Detection completes within performance targets
- No Source files are modified during detection

**Risks & Open Questions**:
- How to ensure determinism when scanning large Sources?
- Should detection support resumption after interruption?
- How to handle Sources that change during detection?
- Should detection be cancellable by user?
- How to report progress for long-running detections?

---

### Component 8: Source Status & Health Monitoring (P2)

**Purpose**: Monitor Source accessibility and detect when Sources have been moved or renamed.

**Responsibilities**:
- Check Source accessibility status
- Detect when Source paths have changed (moved/renamed)
- Attempt to locate moved Sources (best-effort)
- Report Source status (accessible, inaccessible, moved, etc.)
- Update Source associations when moves are detected

**Requirements Addressed**:
- FR-015 (P2): Detect when Source has been moved/renamed (best-effort)
- User Story 1: Display Source status (acceptance scenario 5)
- User Story 4: Handle temporarily inaccessible Sources (acceptance scenario 3)

**Key Decisions**:
- How to detect Source moves (path comparison, volume identifier, etc.)
- How to locate moved Sources (search strategies, user prompts)
- What constitutes "best-effort" detection (limitations and fallbacks)
- How to report Source status to users
- Whether to automatically update associations or require user confirmation

**Validation Points**:
- Source status is accurately reported
- Moved Sources are detected (when possible)
- Inaccessible Sources are identified and reported
- Status checks complete within reasonable time

**Risks & Open Questions**:
- How reliable can move detection be without user input?
- Should move detection search entire filesystem or limited locations?
- How to handle Sources moved to external drives that are disconnected?
- Should status monitoring be continuous or on-demand?

---

## Implementation Sequence

The components should be implemented in the following order to manage dependencies:

1. **Component 1: Source Model & Identity** (Foundation)
   - Must be defined first as all other components depend on it
   - Defines the core Source data structures and identity mechanism

2. **Component 2: Source-Library Association Persistence** (Foundation)
   - Depends on Component 1
   - Enables storing and retrieving Source-Library associations

3. **Component 3: Source Validation & Accessibility** (Core Functionality)
   - Depends on Components 1 and 2
   - Enables Source attachment validation

4. **Component 4: Source Scanning & Media Detection** (Core Functionality)
   - Depends on Component 1
   - Enables detecting candidate media files in Sources

5. **Component 5: Library Comparison & New Item Detection** (Core Functionality)
   - Depends on Component 4 and Library structure from Slice 1
   - Enables determining which items are new

6. **Component 6: Detection Result Model & Storage** (Core Functionality)
   - Depends on Components 4 and 5
   - Enables storing and retrieving detection results

7. **Component 7: Detection Execution & Orchestration** (Integration)
   - Depends on Components 3, 4, 5, and 6
   - Integrates all components into end-to-end detection workflow

8. **Component 8: Source Status & Health Monitoring** (P2 Enhancement)
   - Depends on Components 1, 2, and 3
   - Enhances Source management with status monitoring

## Traceability Matrix

| Component | Functional Requirements | User Stories | Success Criteria |
|-----------|------------------------|--------------|------------------|
| Component 1: Source Model & Identity | FR-001, FR-002, FR-004, FR-005, FR-015 (P2), FR-017 | Story 1 | SC-008 |
| Component 2: Association Persistence | FR-001, FR-002, FR-004, FR-017 | Story 1 | SC-008 |
| Component 3: Source Validation | FR-003, FR-012 | Story 1, Story 2 | SC-002, SC-009 |
| Component 4: Source Scanning | FR-006, FR-011, FR-016 | Story 2 | SC-003 |
| Component 5: Library Comparison | FR-007, FR-008, FR-009 | Story 2 | SC-004, SC-005, SC-006 |
| Component 6: Detection Results | FR-010, FR-013 | Story 3, Story 4 | SC-007 |
| Component 7: Detection Execution | FR-009, FR-010, FR-011, FR-014 | Story 2, Story 4 | SC-003, SC-004, SC-005, SC-010 |
| Component 8: Source Status (P2) | FR-015 (P2) | Story 1, Story 4 | - |

## Risks & Mitigations

### High Risk Items

1. **Deterministic Detection Results**
   - **Risk**: Detection may produce inconsistent results due to non-deterministic file system ordering or timing
   - **Mitigation**: Ensure consistent file ordering (e.g., alphabetical), avoid time-dependent logic, use deterministic comparison algorithms
   - **Validation**: Test detection multiple times on unchanged Sources and verify identical results

2. **Performance with Large Sources**
   - **Risk**: Scanning and comparison may be slow with Sources containing thousands of files
   - **Mitigation**: Implement efficient scanning algorithms, optimize comparison logic, consider incremental scanning strategies
   - **Validation**: Test with Sources containing 1000+ files and verify performance targets (SC-003: within 30 seconds)

3. **Source Identity Across Moves**
   - **Risk**: Sources moved or renamed may not be reliably identified (P2: best-effort only)
   - **Mitigation**: Use volume identifiers and path patterns where possible; accept limitations of best-effort approach
   - **Validation**: Test moving Sources to various locations and verify detection works when possible

### Medium Risk Items

1. **Comparison Accuracy**
   - **Risk**: Comparison mechanism may incorrectly identify items as new or known
   - **Mitigation**: Use reliable comparison mechanism (content hash or robust identifier); test extensively with various scenarios
   - **Validation**: Test comparison accuracy with known items, new items, and edge cases (SC-006: 100% accuracy)

2. **Source Accessibility on External Drives**
   - **Risk**: Sources on external drives or network volumes may be temporarily inaccessible
   - **Mitigation**: Handle accessibility errors gracefully; report clear error messages; support re-validation
   - **Validation**: Test with external drives (connected/disconnected) and network volumes

3. **Detection Interruption Handling**
   - **Risk**: Interrupted detection may leave inconsistent state or require full restart
   - **Mitigation**: Design detection to be resumable or restartable; ensure no partial state corruption
   - **Validation**: Test interrupting detection at various stages and verify safe recovery

## Open Questions Requiring Resolution

1. **Source Identity Mechanism**
   - Should Source identity be based on absolute path, volume identifier, or a combination?
   - How to handle Sources on network volumes where volume identifiers may not be reliable?
   - Should Source identity include a generated UUID stored within the Source?

2. **Comparison Mechanism**
   - Should comparison be path-based, content-based (hash), or identifier-based?
   - How to handle items that exist in Library but at different paths (moved after import)?
   - Should comparison support fuzzy matching or only exact matches?

3. **Detection Result Storage**
   - Should results be stored per-Source, per-Library, or per-detection-run?
   - How much metadata should be stored with each candidate item?
   - Should results include file content hashes for future comparison?

4. **File Format Support**
   - Which specific image and video formats should be supported in P1?
   - Should format detection be extension-based, content-based (MIME type), or both?
   - How to handle files with incorrect extensions (e.g., JPEG with .txt extension)?

5. **Source Scanning Strategy**
   - Should scanning be recursive with depth limits or unlimited depth?
   - How to handle symbolic links and aliases (follow, ignore, or report)?
   - Should scanning extract file metadata (EXIF, etc.) or defer to later phases?

6. **Move Detection Strategy (P2)**
   - What strategies can reliably detect moved Sources without user input?
   - Should move detection search entire filesystem or limited locations (same volume, recent paths)?
   - How to handle Sources moved to external drives that are later disconnected?

## Validation & Testing Strategy

### Unit Testing Focus Areas

- Source identity generation and persistence
- Source-Library association creation and retrieval
- Source validation logic (accessibility, permissions)
- Media file detection (format identification, filtering)
- Library comparison logic (new vs. known items)
- Detection result serialization/deserialization
- Deterministic detection execution

### Integration Testing Focus Areas

- End-to-end Source attachment workflow
- End-to-end detection workflow (scan → compare → results)
- Source association persistence across application restarts
- Detection determinism (multiple runs on unchanged Source)
- Detection with changed Source (new files added)
- Source validation with various error conditions

### Acceptance Testing Scenarios

All acceptance scenarios from the specification should be testable:
- User Story 1: All 5 acceptance scenarios (Source attachment)
- User Story 2: All 5 acceptance scenarios (Detection)
- User Story 3: All 5 acceptance scenarios (View results)
- User Story 4: All 4 acceptance scenarios (Re-run detection)

### Edge Case Testing

- Sources on external drives (connected/disconnected)
- Sources on network volumes (available/unavailable)
- Sources with permission errors
- Sources containing symbolic links or aliases
- Sources with nested folders at various depths
- Sources with corrupted or invalid files
- Sources with files that appear to be media but are not
- Detection interruptions (application quit, system shutdown)
- Sources moved or renamed after attachment (P2)
- Multiple Sources containing same media files
- Sources containing files previously imported but deleted from Library

## Success Criteria Validation

Each success criterion must be validated:

- **SC-001** (Attachment < 10 seconds): Measure Source attachment time
- **SC-002** (Validation < 2 seconds): Measure Source validation time
- **SC-003** (Detection < 30 seconds for 1000 files): Measure detection time with large Sources
- **SC-004** (100% deterministic results): Test detection multiple times on unchanged Source
- **SC-005** (100% identical re-runs): Test re-running detection on unchanged Source
- **SC-006** (100% comparison accuracy): Test comparison with known and new items
- **SC-007** (Explainable results): Verify results include clear inclusion/exclusion reasons
- **SC-008** (100% association persistence): Test associations across application restarts
- **SC-009** (Error reporting < 5 seconds): Measure error reporting time
- **SC-010** (Safe interruption): Test interrupting detection at various stages

## Dependencies & Prerequisites

### External Dependencies

- File system access APIs (platform-specific)
- File metadata APIs (size, modification date, permissions)
- Media file format detection (extension-based or content-based)
- Parsing support for a transparent, human-readable metadata format
- UUID generation utilities (if using UUIDs for Source identity)

### Internal Dependencies

- **Slice 1 (Library Entity)**: Library structure, identity, and metadata
- Slice 1 library identity, metadata, and a minimal representation of known items sufficient for comparison
- Library validation and integrity checking (to ensure Library is valid before detection)

### Future Dependencies Created

- Slice 3+ will depend on Source detection and candidate item identification
- Import functionality will depend on detection results and candidate items
- Pipeline system will depend on Source associations and detection results

## P1 vs P2 Responsibilities

### P1 (Required for Slice 2)

- All Components 1-7 (Source model through detection execution)
- Basic Source attachment and validation
- Source scanning and media detection
- Library comparison and new item detection
- Detection result storage and retrieval
- Deterministic detection execution
- Safe re-runs of detection

### P2 (Best-Effort, Optional for Slice 2)

- Component 8: Source Status & Health Monitoring
- Move/rename detection for Sources (FR-015)
- Advanced Source health monitoring
- Automatic Source relocation
- Enhanced status reporting

## Notes

- This plan intentionally avoids specifying implementation technologies (languages, frameworks, storage formats) except where unavoidable for clarity
- All components should be designed with future extensibility in mind (e.g., additional Source types beyond folder-based)
- The plan focuses on correctness, determinism, and safety over performance optimization (performance targets are defined in success criteria)
- Each component should be independently testable where possible
- Detection must be completely read-only; no Source files should ever be modified
- Determinism is critical; detection results must be reproducible for identical Source states
- The plan assumes folder-based Sources are sufficient for P1; other Source types are future enhancements
