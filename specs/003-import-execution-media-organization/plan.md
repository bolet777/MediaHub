# Implementation Plan: MediaHub Import Execution & Media Organization (Slice 3)

**Feature**: MediaHub Import Execution & Media Organization  
**Specification**: `specs/003-import-execution-media-organization/spec.md`  
**Slice**: 3 - Import Execution & Media Organization (YYYY/MM)  
**Created**: 2026-01-12

## Plan Scope

This plan implements **Slice 3 only**, which enables MediaHub to execute real import operations: copying selected candidate items from Sources into the MediaHub Library, organizing them in a deterministic Year/Month (YYYY/MM) structure, and updating the Library's known-items tracking so that re-running detection does not re-suggest imported items.

This includes:

- Import execution (copy files from Source to Library)
- Deterministic destination path mapping (Year/Month based on timestamp rule)
- Timestamp extraction (EXIF DateTimeOriginal → filesystem modification date fallback)
- Collision handling policies (rename, skip, error)
- Logically atomic import behavior (safe against interruption)
- Import result reporting and audit trail
- Updating known-items tracking (path-based, source-scoped)
- Integration with detection results from Slice 2

**Explicitly out of scope**:
- Advanced duplicate detection (hashing, fuzzy matching across all media)
- Cross-source or global deduplication strategies
- Media organization beyond Year/Month folders
- Photo editing, tagging, albums, face recognition
- Photos.app integration or device-specific APIs
- Background scheduling, automation, or pipelines
- UI beyond minimal enablement
- Content hash-based known items tracking
- Alternative timestamp strategies beyond EXIF DateTimeOriginal → mtime fallback

## Constitutional Compliance

This plan adheres to the MediaHub Constitution:

- **Transparent Storage**: Imported files stored as normal files in standard Year/Month folder structures; audit trail in human-readable format
- **Safe Operations**: Source files are never modified during import (read-only guarantee); import operations are logically atomic
- **Deterministic Behavior**: Import produces identical results for identical inputs; destination mapping is deterministic
- **Interoperability First**: Imported files remain accessible to external tools; no proprietary containers or locking
- **Scalability by Design**: Import supports multiple Sources independently; known-items tracking scales with Library size

## Work Breakdown

### Component 1: Timestamp Extraction & Resolution

**Purpose**: Extract timestamps from candidate media items according to the P1 timestamp rule (EXIF DateTimeOriginal when available and valid, otherwise filesystem modification date).

**Responsibilities**:
- Extract EXIF DateTimeOriginal from image files when available
- Validate extracted EXIF timestamps (ensure they are reasonable/valid)
- Fallback to filesystem modification date when EXIF is unavailable or invalid
- Handle edge cases (missing metadata, corrupted EXIF, unsupported formats)
- Ensure timestamp extraction is deterministic and consistent
- Support both image and video files (video EXIF extraction may be limited)

**Requirements Addressed**:
- FR-004: Define and document timestamp rule (EXIF DateTimeOriginal → mtime fallback)
- FR-003: Organize files in Year/Month based on timestamp rule
- FR-012: Produce deterministic import results
- User Story 2: Organize imported files by Year/Month (acceptance scenarios 1, 4, 5)
- SC-002: Import results are 100% deterministic
- SC-007: Imported files organized according to timestamp rule 100% of the time

**Key Decisions**:
- Which EXIF library or API to use for timestamp extraction (platform-specific)
- How to validate EXIF timestamps (reasonable date ranges, format validation)
- What constitutes "invalid" EXIF data (corrupted, out-of-range dates, etc.)
- How to handle video files (may not have EXIF; use modification date)
- Whether to cache extracted timestamps during import job
- How to handle files with multiple timestamp fields (prefer DateTimeOriginal over others)

**Validation Points**:
- EXIF DateTimeOriginal is extracted correctly when present
- Fallback to modification date works when EXIF is unavailable
- Timestamp extraction is deterministic (same file produces same timestamp)
- Invalid EXIF data is handled gracefully
- Video files are handled appropriately (may not have EXIF)

**Risks & Open Questions**:
- How reliable is EXIF extraction across different image formats?
- Should EXIF extraction be lazy (on-demand) or eager (during import)?
- How to handle files with corrupted or partially readable EXIF?
- What date range is considered "valid" for EXIF timestamps?
- If EXIF timestamps include timezone/offset information, it is used; otherwise timestamps are treated as local/naive time for P1.

---

### Component 2: Destination Path Mapping

**Purpose**: Map candidate items to their destination paths in the Library using the Year/Month (YYYY/MM) organization rule.

**Responsibilities**:
- Compute destination path for a candidate item based on its timestamp
- Generate Year/Month folder structure (YYYY/MM format)
- Ensure destination mapping is deterministic (same timestamp → same path)
- Handle edge cases (invalid characters in paths, filesystem limitations)
- Preserve original filename in destination path
- Support collision detection (check if destination path already exists)

**Requirements Addressed**:
- FR-003: Organize imported files in Year/Month folders (YYYY/MM)
- FR-012: Produce deterministic import results
- User Story 2: Organize imported files by Year/Month (all acceptance scenarios)
- SC-002: Import results are 100% deterministic
- SC-007: Imported files organized according to timestamp rule 100% of the time

**Key Decisions**:
- Destination path format (e.g., `LibraryRoot/YYYY/MM/filename.ext`)
- How to handle invalid characters in filenames (sanitization strategy)
- Whether to preserve original filename or normalize it
- How to structure Year/Month folders (e.g., `2026/01/` vs `2026/1/`)
- Whether to create folders eagerly or lazily during import
- How to handle filesystem path length limitations

**Validation Points**:
- Destination paths follow YYYY/MM structure correctly
- Mapping is deterministic (same timestamp produces same path)
- Original filenames are preserved (or normalized consistently)
- Invalid characters are handled safely
- Year/Month folder format is consistent and human-readable

**Risks & Open Questions**:
- How to handle very long filenames that exceed filesystem limits?
- Should filenames be normalized (e.g., remove special characters)?
- How to handle files with identical names and timestamps (collision detection)?
- Should Year/Month folders be zero-padded (e.g., `01` vs `1`)?
- How to handle edge cases (year 0000, future dates, etc.)?

---

### Component 3: Collision Detection & Policy Handling

**Purpose**: Detect when an imported file would conflict with an existing file at the destination path and apply the configured collision policy (rename, skip, or error).

**Responsibilities**:
- Detect collisions (destination path already exists)
- Apply collision policy (rename, skip, or error)
- Generate unique filenames when policy is "rename"
- Ensure rename strategy is deterministic and doesn't create infinite loops
- Report collision actions in import results
- Handle edge cases (multiple collisions, rename conflicts, etc.)

**Requirements Addressed**:
- FR-005: Handle name/path collisions according to configurable policy
- FR-007: Report import results showing what was skipped and why
- User Story 3: Handle import collisions safely (all acceptance scenarios)
- SC-008: Collision handling follows configured policy 100% of the time

**Key Decisions**:
- Collision detection strategy (check before copy, check during copy, etc.)
- Rename strategy (suffix pattern, numbering scheme, uniqueness guarantee)
- How to ensure rename doesn't create infinite loops (max attempts, pattern)
- Whether collision policy is per-import-job or global (per-import-job for P1)
- How to handle collisions with directories vs. files
- Whether to compare file content or just path (path-only for P1)

**Validation Points**:
- Collisions are detected correctly
- Rename policy generates unique, non-conflicting filenames
- Skip policy skips files without modifying existing files
- Error policy fails import with clear error messages
- Collision actions are reported in import results

**Risks & Open Questions**:
- How to ensure rename strategy is deterministic?
- What rename pattern to use (e.g., `filename (1).ext`, `filename-1.ext`)?
- How many rename attempts before giving up (prevent infinite loops)?
- Should collision detection compare file content or just paths (path-only for P1)?
- How to handle race conditions (file created between check and copy)?

---

### Component 4: Atomic File Copying & Safety

**Purpose**: Copy files from Source to Library destination with atomic/safe writes that prevent corruption on interruption.

**Responsibilities**:
- Copy files from Source to Library destination
- Ensure atomic writes (no partial files on interruption)
- Validate Source file accessibility before copying
- Preserve original file data (no modification, compression, or conversion)
- Handle copy errors gracefully (permission errors, disk full, etc.)
- Ensure Source files are never modified (read-only guarantee)
- Support interruption handling (cleanup partial files)

**Requirements Addressed**:
- FR-002: Copy files from Source to Library (never move or modify Source files)
- FR-006: Ensure atomic/safe writes (no partial or corrupt files on interruption)
- FR-010: Never modify Source files during import (read-only guarantee)
- FR-013: Handle import interruptions gracefully without corrupting Library state
- FR-014: Validate Source files are still accessible before importing
- FR-015: Preserve original file data during import
- User Story 1: Import selected candidate items (acceptance scenarios 1, 4)
- SC-004: Import operations safe against interruption
- SC-006: Source files remain unmodified after import

**Key Decisions**:
- Atomic write strategy (temporary file + rename, or copy + verify)
- How to handle copy interruptions (cleanup strategy)
- Whether to verify copied files (checksum, size comparison)
- How to handle large files (streaming, chunking, etc.)
- Whether to preserve file metadata (timestamps, permissions, etc.)
- How to handle copy errors (fail-fast vs. continue with other items)

**Validation Points**:
- Files are copied correctly (data integrity preserved)
- Atomic writes prevent partial files on interruption
- Source files remain unmodified after copy
- Copy errors are handled gracefully
- Interrupted imports leave Library in consistent state

**Risks & Open Questions**:
- What atomic write strategy is most reliable (temporary file + rename)?
- Should copied files be verified (checksum, size) after copy?
- How to handle very large files (memory constraints, streaming)?
- Should file metadata (timestamps, permissions) be preserved?
- How to handle network volumes or external drives that disconnect during copy?

---

### Component 5: Import Job Orchestration

**Purpose**: Orchestrate the end-to-end import process, coordinating timestamp extraction, destination mapping, collision handling, and file copying.

**Responsibilities**:
- Coordinate import job execution (timestamp extraction → mapping → collision check → copy)
- Manage import job state and progress
- Handle import interruptions gracefully
- Ensure import is logically atomic (Library remains consistent)
- Support importing selected items from detection results
- Report progress and errors during import
- Ensure deterministic import execution

**Requirements Addressed**:
- FR-001: Support importing selected candidate items from detection results
- FR-012: Produce deterministic import results
- FR-013: Handle import interruptions gracefully
- FR-017: Support re-running import on same detection result safely
- User Story 1: Import selected candidate items (all acceptance scenarios)
- SC-001: Import completes within performance targets
- SC-002: Import results are 100% deterministic
- SC-004: Import operations safe against interruption

**Key Decisions**:
- Import job execution flow (sequential vs. parallel item processing)
- How to handle partial import completion (cleanup vs. resume)
- Whether to support cancellation of in-progress imports
- How to report progress (per-item, batch, etc.)
- Whether import is transactional (all-or-nothing) or item-by-item
- How to ensure determinism (consistent ordering, no side effects)

**Validation Points**:
- Import executes end-to-end successfully
- Import is deterministic (same inputs produce same outputs)
- Interruptions are handled gracefully
- Partial imports are cleaned up or clearly reported
- Import completes within performance targets

**Risks & Open Questions**:
- Should import be transactional (all-or-nothing) or allow partial success?
- How to handle very large import jobs (thousands of items)?
- Should import support parallel processing of items?
- How to ensure determinism when processing items in parallel?
- How to handle Source files that become inaccessible during import?

---

### Component 6: Import Result Model & Storage

**Purpose**: Define and store import results in a transparent, auditable format that shows what was imported, skipped, failed, and why.

**Responsibilities**:
- Define import result data structure (import items, status, reasons, summary)
- Store import results persistently
- Support explainable results (why items were imported, skipped, or failed)
- Support auditable results (import metadata, timestamps, options used)
- Enable retrieval and comparison of import results
- Ensure results are stored in transparent, human-readable format

**Requirements Addressed**:
- FR-007: Report import results showing what was imported, skipped, failed, and why
- FR-009: Maintain audit trail in transparent, human-readable format
- FR-016: Store import results persistently for auditability
- User Story 5: View import results and audit trail (all acceptance scenarios)
- SC-005: Import results are explainable
- SC-009: Import results stored persistently and survive restarts
- SC-010: Import audit trail is transparent and human-readable

**Key Decisions**:
- Import result schema (import items, status, reasons, metadata)
- Storage location for import results (within Library structure)
- Storage format (transparent, human-readable format)
- How to represent import item status (enumeration: imported, skipped, failed)
- How to represent skip/fail reasons (enumeration, codes, or descriptive text)
- Whether to store full import history or only latest results
- How to enable result comparison across import runs

**Validation Points**:
- Import results are stored correctly
- Results include explainable status and reasons
- Results are stored in transparent, human-readable format
- Results can be retrieved and compared across runs
- Results include necessary metadata (timestamp, source, library, options)

**Risks & Open Questions**:
- Should import results be stored per-Source, per-Library, or per-import-run?
- How much metadata should be stored with each import item?
- Should results include file content hashes for future comparison?
- How to handle very large result sets (thousands of items)?
- Should results be versioned or append-only?

---

### Component 7: Known Items Tracking & Persistence

**Purpose**: Track which items have been imported so that future detection runs exclude them. For P1, this is path-based and scoped to the Source from which items were imported.

**Responsibilities**:
- Record imported items in known-items tracking (path-based, source-scoped)
- Persist known-items tracking in transparent, human-readable format
- Support querying known items for a Source
- Update known-items tracking after successful imports
- Ensure tracking is source-scoped (items imported from Source A don't affect Source B)
- Support retrieval of known items for detection comparison

**Requirements Addressed**:
- FR-008: Update "known items" tracking so re-running detection excludes imported items
- FR-009: Maintain audit trail in transparent, human-readable format
- User Story 4: Track imported items for future detection (all acceptance scenarios)
- SC-003: Re-running detection after import excludes imported items with 100% accuracy

**Key Decisions**:
- Known-items tracking schema (what identifiers to store: paths, hashes, etc.)
- Storage location for known-items tracking (within Library structure)
- Storage format (transparent, human-readable format)
- How to scope tracking to Sources (per-Source files, or Library-wide with Source tags)
- How to represent imported items (normalized paths, relative paths, etc.)
- Whether to support removal of known items (e.g., when files are deleted)
- How to integrate with existing detection comparison mechanism from Slice 2

**Validation Points**:
- Imported items are recorded in known-items tracking
- Known-items tracking persists across application restarts
- Tracking is source-scoped correctly
- Future detection runs exclude imported items
- Tracking format is transparent and human-readable

**Risks & Open Questions**:
- Should known-items tracking be per-Source or Library-wide with Source tags?
- How to handle items imported from a Source that is later detached?
- Should tracking support removal of known items (e.g., manual file deletion)?
- How to handle path normalization (absolute vs. relative, symlink resolution)?
- For P1, no automatic reconciliation against actual Library contents is performed; missing or stale known-item entries are logged or reported but not automatically corrected.

---

### Component 8: Import-Detection Integration

**Purpose**: Integrate import functionality with detection results from Slice 2, ensuring imported items are excluded from future detection runs.

**Responsibilities**:
- Integrate known-items tracking with detection comparison mechanism
- Ensure detection excludes items recorded in known-items tracking
- Support querying known items during detection
- Handle edge cases (items deleted from Library, Source detached, etc.)
- Ensure integration maintains determinism and accuracy

**Requirements Addressed**:
- FR-008: Update "known items" tracking so re-running detection excludes imported items
- User Story 1: Import selected candidate items (acceptance scenario 3)
- User Story 4: Track imported items for future detection (acceptance scenarios 1, 4, 5)
- SC-003: Re-running detection after import excludes imported items with 100% accuracy

**Key Decisions**:
- How to integrate known-items tracking with existing Library comparison mechanism
- Whether to extend existing comparison API or create new integration point
- How to handle items that were imported but later deleted from Library
- Whether to validate known items against actual Library contents
- How to handle Sources that are detached after items were imported

**Validation Points**:
- Detection correctly excludes imported items
- Integration maintains detection determinism
- Edge cases are handled gracefully
- Detection accuracy meets success criteria (100%)

**Risks & Open Questions**:
- How to efficiently query known items during detection (performance with large Libraries)?
- Should known-items tracking be validated against actual Library contents?
- How to handle items imported but later manually deleted from Library?
- Should integration support "forgetting" known items (reset tracking)?
- How to handle Sources detached after items were imported?

---

## Implementation Sequence

The components should be implemented in the following order to manage dependencies:

1. **Component 1: Timestamp Extraction & Resolution** (Foundation)
   - Must be defined first as destination mapping depends on it
   - Defines the timestamp rule and extraction logic

2. **Component 2: Destination Path Mapping** (Foundation)
   - Depends on Component 1
   - Enables computing destination paths for candidate items

3. **Component 3: Collision Detection & Policy Handling** (Core Functionality)
   - Depends on Component 2
   - Enables handling destination path conflicts

4. **Component 4: Atomic File Copying & Safety** (Core Functionality)
   - Depends on Components 2 and 3
   - Enables safe file copying with atomic writes

5. **Component 7: Known Items Tracking & Persistence** (Core Functionality)
   - Can be developed in parallel with Components 1-4
   - Enables tracking imported items for future detection

6. **Component 6: Import Result Model & Storage** (Core Functionality)
   - Depends on Components 3 and 4
   - Enables storing and retrieving import results

7. **Component 5: Import Job Orchestration** (Integration)
   - Depends on Components 1, 2, 3, 4, and 6
   - Integrates all components into end-to-end import workflow

8. **Component 8: Import-Detection Integration** (Integration)
   - Depends on Component 7 and detection mechanism from Slice 2
   - Integrates known-items tracking with detection

## Traceability Matrix

| Component | Functional Requirements | User Stories | Success Criteria |
|-----------|------------------------|--------------|------------------|
| Component 1: Timestamp Extraction | FR-004 | Story 2 | SC-002, SC-007 |
| Component 2: Destination Mapping | FR-003, FR-012 | Story 2 | SC-002, SC-007 |
| Component 3: Collision Handling | FR-005, FR-007 | Story 3 | SC-008 |
| Component 4: Atomic File Copying | FR-002, FR-006, FR-010, FR-013, FR-014, FR-015 | Story 1 | SC-004, SC-006 |
| Component 5: Import Orchestration | FR-001, FR-012, FR-013, FR-017 | Story 1 | SC-001, SC-002, SC-004 |
| Component 6: Import Results | FR-007, FR-009, FR-016 | Story 5 | SC-005, SC-009, SC-010 |
| Component 7: Known Items Tracking | FR-008, FR-009 | Story 4 | SC-003 |
| Component 8: Import-Detection Integration | FR-008 | Story 1, Story 4 | SC-003 |

## Risks & Mitigations

### High Risk Items

1. **Atomic File Copying on Interruption**
   - **Risk**: Interrupted imports may leave partial or corrupt files in Library
   - **Mitigation**: Use temporary file + rename strategy; implement cleanup on interruption; verify file integrity after copy
   - **Validation**: Test interrupting import at various stages and verify Library remains consistent

2. **Deterministic Import Results**
   - **Risk**: Import may produce inconsistent results due to non-deterministic ordering or timing
   - **Mitigation**: Ensure consistent item ordering (e.g., from detection result), use deterministic collision handling, avoid time-dependent logic
   - **Validation**: Test import multiple times with same inputs and verify identical results

3. **EXIF Timestamp Extraction Reliability**
   - **Risk**: EXIF extraction may fail or be inconsistent across different image formats
   - **Mitigation**: Implement robust EXIF parsing with fallback to modification date; validate extracted timestamps; handle edge cases gracefully
   - **Validation**: Test EXIF extraction with various image formats and verify fallback works correctly

4. **Known Items Tracking Accuracy**
   - **Risk**: Known-items tracking may incorrectly exclude or include items in future detection
   - **Mitigation**: Use reliable path normalization; ensure source-scoped tracking; for P1, no automatic reconciliation against actual Library contents is performed; missing or stale known-item entries are logged or reported but not automatically corrected.
   - **Validation**: Test detection after import and verify 100% accuracy (SC-003)

### Medium Risk Items

1. **Collision Handling Determinism**
   - **Risk**: Rename strategy may not be deterministic or may create conflicts
   - **Mitigation**: Use deterministic rename pattern (e.g., numbered suffix); implement max attempts to prevent infinite loops; test edge cases
   - **Validation**: Test collision handling with various scenarios and verify deterministic behavior

2. **Performance with Large Imports**
   - **Risk**: Importing thousands of items may be slow
   - **Mitigation**: Optimize file copying; consider parallel processing where safe; batch known-items updates
   - **Validation**: Test import with large item counts and verify performance targets (SC-001: < 60 seconds per 100 items)

3. **Source File Accessibility During Import**
   - **Risk**: Source files may become inaccessible during import (external drive disconnected, network volume unavailable)
   - **Mitigation**: Validate accessibility before copying; handle errors gracefully; report clear error messages
   - **Validation**: Test import with external drives and network volumes

4. **Integration with Detection Mechanism**
   - **Risk**: Known-items tracking may not integrate correctly with existing detection comparison
   - **Mitigation**: Design clear integration API; test end-to-end workflow; ensure determinism is maintained
   - **Validation**: Test detection after import and verify imported items are excluded

## Open Questions Requiring Resolution

1. **EXIF Extraction Library**
   - Which library or API should be used for EXIF extraction on macOS?
   - Should EXIF extraction support video files (may not have EXIF)?
   - How to handle timezone information in EXIF timestamps?

2. **Destination Path Structure**
   - Should Year/Month folders be zero-padded (e.g., `2026/01/` vs `2026/1/`)?
   - How to handle invalid characters in filenames (sanitization strategy)?
   - Should original filenames be preserved exactly or normalized?

3. **Collision Rename Strategy**
   - What rename pattern to use (e.g., `filename (1).ext`, `filename-1.ext`)?
   - How many rename attempts before giving up (prevent infinite loops)?
   - Should rename be deterministic (same collision → same rename)?

4. **Known Items Tracking Storage**
   - Should tracking be per-Source files or Library-wide with Source tags?
   - How to handle path normalization (absolute vs. relative, symlink resolution)?
   - Should tracking include file metadata (size, modification date) for validation?

5. **Import Result Storage**
   - Should results be stored per-Source, per-Library, or per-import-run?
   - How much metadata should be stored with each import item?
   - Should results be versioned or append-only?

6. **Atomic Write Strategy**
   - What atomic write strategy is most reliable (temporary file + rename)?
   - Should copied files be verified (checksum, size) after copy?
   - How to handle very large files (memory constraints, streaming)?

7. **Import Job Transactionality**
   - Should import be transactional (all-or-nothing) or allow partial success?
   - How to handle partial import completion (cleanup vs. resume)?
   - Should import support cancellation of in-progress jobs?

## Validation & Testing Strategy

### Unit Testing Focus Areas

- Timestamp extraction (EXIF DateTimeOriginal, fallback to mtime)
- Destination path mapping (YYYY/MM structure, deterministic)
- Collision detection and policy handling (rename, skip, error)
- Atomic file copying (temporary file + rename, cleanup)
- Known-items tracking (path-based, source-scoped, persistence)
- Import result serialization/deserialization
- Deterministic import execution

### Integration Testing Focus Areas

- End-to-end import workflow (detection result → import → known-items update)
- Import with various collision scenarios
- Import interruption handling (cleanup, consistency)
- Known-items tracking integration with detection
- Import result storage and retrieval
- Import determinism (multiple runs with same inputs)

### Acceptance Testing Scenarios

All acceptance scenarios from the specification should be testable:
- User Story 1: All 5 acceptance scenarios (Import selected items)
- User Story 2: All 5 acceptance scenarios (Organize by Year/Month)
- User Story 3: All 5 acceptance scenarios (Handle collisions)
- User Story 4: All 5 acceptance scenarios (Track imported items)
- User Story 5: All 5 acceptance scenarios (View results and audit trail)

### Edge Case Testing

- Source files deleted or moved after detection but before import
- Disk space insufficient during import
- Source files locked or inaccessible during import
- File timestamp changes between detection and import
- Collision policy creating infinite rename loops
- Library directory becomes read-only during import
- Source files with invalid or corrupted metadata
- Imported files manually deleted from Library after import
- Source detached after items imported from it
- Import interrupted mid-way through copying large file
- Year/Month folder structure creating invalid paths

## Success Criteria Validation

Each success criterion must be validated:

- **SC-001** (Import < 60 seconds per 100 items): Measure import time with various item counts
- **SC-002** (100% deterministic results): Test import multiple times with same inputs
- **SC-003** (100% detection exclusion accuracy): Test detection after import and verify imported items excluded
- **SC-004** (Safe against interruption): Test interrupting import at various stages
- **SC-005** (Explainable results): Verify results include clear status and reasons
- **SC-006** (Source files unmodified): Verify Source files unchanged after import
- **SC-007** (100% Year/Month organization): Verify all imported files in correct folders
- **SC-008** (100% collision policy compliance): Test collision handling with all policies
- **SC-009** (100% result persistence): Test import results survive application restarts
- **SC-010** (Transparent audit trail): Verify audit trail readable without MediaHub

## Dependencies & Prerequisites

### External Dependencies

- File system access APIs (platform-specific)
- File copying APIs (atomic write support)
- EXIF extraction library or API (platform-specific, e.g., ImageIO, Core Image)
- File metadata APIs (modification date, size, permissions)
- Parsing support for transparent, human-readable metadata format

### Internal Dependencies

- **Slice 1 (Library Entity)**: Library structure, identity, and metadata
- **Slice 2 (Sources & Import Detection)**: Detection results, candidate items, Source model, detection comparison mechanism
- Library validation and integrity checking (to ensure Library is valid before import)

### Future Dependencies Created

- Slice 4+ may depend on import results and known-items tracking
- Pipeline system may depend on import execution and organization
- Advanced duplicate detection may depend on known-items tracking structure

## P1 vs P2 Responsibilities

### P1 (Required for Slice 3)

- All Components 1-8 (timestamp extraction through import-detection integration)
- EXIF DateTimeOriginal extraction with mtime fallback
- Year/Month (YYYY/MM) destination mapping
- Collision handling policies (rename, skip, error)
- Atomic file copying with interruption safety
- Import result storage and audit trail
- Path-based, source-scoped known-items tracking
- Integration with detection mechanism

### P2 (Future Enhancements, Out of Scope)

- Content hash-based known-items tracking
- Cross-source or global deduplication
- Alternative timestamp strategies (EXIF DateTime, GPS timestamp, etc.)
- Advanced collision strategies (content comparison, merge, etc.)
- Import resumption after interruption
- Parallel import processing
- Import progress reporting UI
- Import scheduling or automation

## Notes

- This plan intentionally avoids specifying implementation technologies (languages, frameworks, storage formats) except where unavoidable for clarity
- All components should be designed with future extensibility in mind (e.g., alternative timestamp strategies, content hash tracking)
- The plan focuses on correctness, determinism, and safety over performance optimization (performance targets are defined in success criteria)
- Each component should be independently testable where possible
- Import must maintain read-only guarantee for Source files; Source files should never be modified
- Determinism is critical; import results must be reproducible for identical inputs
- Known-items tracking is path-based and source-scoped for P1; content hash and cross-source strategies are explicitly out of scope
- Timestamp rule is fixed for P1 (EXIF DateTimeOriginal → mtime fallback); alternative strategies are out of scope
- Import results and known-items tracking must be stored in transparent, human-readable formats (consistent with detection results from Slice 2)
