# Feature Specification: Baseline Index

**Feature Branch**: `007-baseline-index`  
**Created**: 2026-01-27  
**Status**: Ready for Plan  
**Input**: User description: "Accélérer `detect` et `import` sur très grosses librairies (10k+ fichiers) en évitant un full re-scan systématique des contenus de la Library. Introduire un index persistant 'baseline' des fichiers présents dans la Library (déjà adoptés/importés)."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Fast Detection with Baseline Index (Priority: P1)

A user has a very large library (10,000+ media files) that was adopted or has been importing files over time. When running `mediahub detect <source-id> --library <path>`, the user wants the detection to complete quickly by using a persistent baseline index instead of performing a full recursive scan of all library contents. The index should be automatically created during `library adopt` and updated incrementally during `import` operations.

**Why this priority**: Performance optimization is critical for large libraries. Without a baseline index, every `detect` operation must scan all library files, which becomes prohibitively slow for libraries with 10,000+ files. The baseline index enables fast detection by providing a pre-computed list of library contents.

**Independent Test**: Can be fully tested by:
1. Adopting a library with 10,000+ files and verifying that `index.json` is created
2. Running `detect` and verifying it uses the index (no full scan)
3. Measuring detection time with and without index (should show significant improvement)

**Acceptance Scenarios**:

1. **Given** a user has adopted a library with existing media files, **When** adoption completes, **Then** MediaHub creates `.mediahub/registry/index.json` containing a baseline index of all existing media files (normalized paths, file sizes, modification times)
2. **Given** a user runs `mediahub detect <source-id> --library <path>` on a library with a baseline index, **When** detection executes, **Then** MediaHub uses the index to query library contents instead of performing a full recursive scan (fallback to full scan if index is missing or invalid)
3. **Given** a user runs detection with a baseline index, **When** detection completes, **Then** detection results are identical to results obtained with a full scan (deterministic behavior preserved)
4. **Given** a user runs detection on a library without a baseline index, **When** detection executes, **Then** MediaHub falls back to `LibraryContentQuery.scanLibraryContents()` (existing behavior) and detection completes successfully
5. **Given** a user runs detection with a corrupted or invalid baseline index, **When** detection executes, **Then** MediaHub detects the corruption, falls back to full scan, and reports the fallback reason in output (detection is read-only, does not modify `index.json`)

---

### User Story 2 - Incremental Index Updates During Import (Priority: P1)

A user wants the baseline index to be updated incrementally during `import` operations so that newly imported files are immediately reflected in the index without requiring a full re-scan. Each successful import should add the new file's metadata to the index atomically.

**Why this priority**: Incremental updates ensure the index stays current without expensive full rescans. Without incremental updates, the index would become stale after imports, requiring recovery via `library adopt` or falling back to full scans.

**Independent Test**: Can be fully tested by:
1. Importing files into a library with a baseline index
2. Verifying that `index.json` is updated with new entries after import
3. Running detection immediately after import and verifying new files are recognized as known

**Acceptance Scenarios**:

1. **Given** a user runs `mediahub import <source-id> --all --library <path>` on a library with a baseline index, **When** import completes successfully, **Then** MediaHub updates `.mediahub/registry/index.json` with metadata for all newly imported files (incremental update, no full re-scan)
2. **Given** a user runs import with incremental index updates, **When** import completes, **Then** the index update is atomic (write-then-rename pattern) and the library state remains consistent even if interrupted
3. **Given** a user runs import with `--dry-run` flag, **When** import preview completes, **Then** MediaHub shows what index updates would be performed but does not modify `index.json` (zero writes in dry-run mode)
4. **Given** a user runs import and some items fail to import, **When** import completes, **Then** only successfully imported items are added to the index (failed items are not indexed)
5. **Given** a user runs import multiple times, **When** imports complete, **Then** the index contains no duplicate entries (idempotent index updates)

---

### User Story 3 - Index Initialization During Library Adoption (Priority: P1)

A user wants the baseline index to be created automatically during `library adopt` operations, using the baseline scan already performed during adoption to avoid a double scan. The index should be created from the adoption baseline scan results without requiring an additional full library scan.

**Why this priority**: Adoption already performs a baseline scan to establish known items. Creating the index during adoption reuses this scan, avoiding duplicate work and ensuring the index is available immediately after adoption.

**Independent Test**: Can be fully tested by:
1. Running `library adopt <path>` on a library with existing files
2. Verifying that `index.json` is created with entries matching the baseline scan
3. Verifying that adoption does not perform a second full scan (index creation uses existing baseline scan results)

**Acceptance Scenarios**:

1. **Given** a user runs `mediahub library adopt <path>`, **When** adoption completes, **Then** MediaHub creates `.mediahub/registry/index.json` using the baseline scan results from adoption (no double scan, reuse existing scan)
2. **Given** a user runs adoption with `--dry-run` flag, **When** adoption preview completes, **Then** MediaHub shows what index would be created (entry count, structure preview) but does not create `index.json` (zero writes in dry-run mode)
3. **Given** a user runs adoption on an already adopted library (idempotent), **When** adoption completes, **Then** MediaHub does not modify the existing index if it is valid (idempotent behavior: valid index preserved); if index is absent or invalid, MediaHub (re)creates it from baseline scan
4. **Given** a user runs adoption and the baseline scan completes but index creation fails, **When** adoption completes, **Then** MediaHub reports the index creation failure but adoption still succeeds (index is optional, adoption metadata is primary)
5. **Given** a user runs adoption on a library with 10,000+ files, **When** adoption completes, **Then** the index is created efficiently (O(n) where n is number of files, no quadratic operations)

---

### User Story 4 - Index Recovery and Fallback (Priority: P1)

A user wants operations to gracefully handle missing or corrupted baseline index by falling back to full scan and reporting the fallback reason. The index should be recoverable through `library adopt` operations if needed.

**Why this priority**: Index corruption or staleness can occur due to external file system modifications, interruptions, or bugs. Operations must degrade gracefully without failing, and users need visibility into fallback behavior.

**Independent Test**: Can be fully tested by:
1. Manually corrupting or deleting `index.json`
2. Running detection and verifying fallback to full scan works
3. Verifying that detection reports fallback reason in output
4. Running `library adopt` on library with missing/corrupted index and verifying index is (re)created

**Acceptance Scenarios**:

1. **Given** a user has a library with a missing or corrupted baseline index, **When** they run `mediahub detect <source-id> --library <path>`, **Then** MediaHub detects the missing/corrupted index, falls back to full scan, and reports the fallback reason in output (detection is read-only, does not modify `index.json`)
2. **Given** a user runs `mediahub library adopt <path>` on a library with a missing or corrupted index, **When** adoption completes, **Then** MediaHub (re)creates the index from baseline scan results (idempotent: if index is valid, it is not overwritten; if absent/invalid, it is created)
3. **Given** a user runs detection with a corrupted index, **When** detection completes, **Then** MediaHub reports index status and fallback reason in JSON output (e.g., `indexUsed: false`, `indexFallbackReason: "corrupted"`)
4. **Given** a user runs operations with missing/corrupted index, **When** operations complete, **Then** MediaHub provides clear information about index state without requiring manual intervention (fallback is automatic, recovery via `library adopt` if needed)
5. **Given** a user runs `library adopt` with `--dry-run` flag on a library with missing index, **When** adoption preview completes, **Then** MediaHub shows what index would be created but does not modify `index.json` (zero writes in dry-run mode)

---

### User Story 5 - Index Information in Status and JSON Output (Priority: P1)

A user wants to see information about the baseline index in `status` command output and JSON output formats. This includes whether an index exists, its version, statistics (entry count, last update time), and whether it's being used for operations.

**Why this priority**: Visibility into index state helps users understand performance characteristics and diagnose issues. JSON output enables automation and monitoring tools to track index health.

**Independent Test**: Can be fully tested by:
1. Running `mediahub status --library <path> --json` on libraries with and without indexes
2. Verifying JSON output includes index metadata
3. Verifying human-readable status output includes index information

**Acceptance Scenarios**:

1. **Given** a user runs `mediahub status --library <path>`, **When** status completes, **Then** MediaHub displays index information (presence, version, entry count, last update time) in human-readable format
2. **Given** a user runs `mediahub status --library <path> --json`, **When** status completes, **Then** MediaHub outputs JSON with index metadata including `index.present`, `index.version`, `index.entryCount`, `index.lastUpdated` fields
3. **Given** a user runs `mediahub detect <source-id> --library <path> --json`, **When** detection completes, **Then** MediaHub JSON output includes index usage information (e.g., `indexUsed: true/false`, `indexFallbackReason` if fallback occurred)
4. **Given** a user runs detection or import operations, **When** operations complete with JSON output, **Then** MediaHub includes index statistics in JSON results without breaking existing JSON schema (backward compatible)
5. **Given** a user runs status on a library without an index, **When** status completes, **Then** MediaHub clearly indicates that no index is present (no misleading "index missing" errors)

---

### Edge Cases

- What happens when a user manually modifies files in the library outside of MediaHub (index becomes stale)?
- What happens when a user runs adoption/import and the file system becomes read-only during index write?
- What happens when a user runs detection/import and the index file is locked by another process?
- What happens when a user runs operations on a library with an index from a different MediaHub version (version compatibility)?
- What happens when a user runs import and disk space runs out during index update?
- What happens when a user runs detection/import and the index contains entries for files that no longer exist (orphaned entries)?
- What happens when a user runs adoption on a library that already has an index from a previous adoption attempt?
- What happens when a user runs operations with `--dry-run` and the index would be updated (should show preview but not write)?
- What happens when a user runs detection/import and the index file is corrupted mid-read?
- What happens when a user runs import and the index update fails but import succeeds (partial failure scenario)?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: MediaHub MUST create a persistent baseline index at `.mediahub/registry/index.json` containing metadata for all media files in the library (normalized paths, file sizes, modification times)
- **FR-002**: MediaHub MUST initialize the baseline index during `library adopt` operations using the baseline scan results from adoption (no double scan, reuse existing scan)
- **FR-003**: MediaHub MUST update the baseline index incrementally during `import` operations, adding entries for each successfully imported file (atomic updates, no full re-scan)
- **FR-004**: MediaHub MUST use the baseline index in `detect` and `import` operations to query library contents when the index is present and valid (fallback to `LibraryContentQuery.scanLibraryContents()` if index is missing or invalid)
- **FR-005**: MediaHub MUST ensure that index-based detection produces identical results to full-scan detection (deterministic behavior preserved)
- **FR-006**: MediaHub MUST support graceful degradation: if the index is missing, corrupted, or invalid, operations MUST fall back to full scan without failing and MUST report the fallback reason in output
- **FR-007**: MediaHub MUST ensure that index updates are atomic (write-then-rename pattern, similar to `AtomicFileCopy`) and tolerate interruptions
- **FR-008**: MediaHub MUST ensure that index creation and updates are idempotent (re-running operations produces consistent results, no duplicate entries)
- **FR-009**: MediaHub MUST ensure that `--dry-run` operations perform zero writes to `index.json` (dry-run shows what would be updated but does not modify the index)
- **FR-010**: MediaHub MUST include index metadata in `status` command output (presence, version, entry count, last update time)
- **FR-011**: MediaHub MUST include index information in JSON output formats (`status --json`, `detect --json`, `import --json`) without breaking existing JSON schema (backward compatible)
- **FR-012**: MediaHub MUST validate that index file paths are strictly within the library root (never write outside library boundaries)
- **FR-013**: MediaHub MUST ensure that index format is stable and deterministic (entries sorted by normalized path, JSON encoding with stable options such as sorted keys, normalized paths)
- **FR-014**: MediaHub MUST support index versioning to enable future format migrations (simple version field, no complex migration logic for P1)
- **FR-015**: MediaHub MUST ensure that index operations do not block or slow down adoption/import operations (index updates should be fast, O(n) for new items)

### Non-Functional Requirements

- **NFR-001**: Index-based detection MUST complete significantly faster than full-scan detection for libraries with 10,000+ files (target: >=5x speedup compared to full-scan on the same machine and library)
- **NFR-002**: Index creation during adoption MUST complete in reasonable time (O(n) where n is number of files, no quadratic operations)
- **NFR-003**: Index incremental updates during import MUST be fast (O(n) where n is number of new items, not O(N) where N is total library size)
- **NFR-004**: Index file size MUST be reasonable (target: < 1MB per 10,000 entries, JSON format with efficient encoding)
- **NFR-005**: Index read operations MUST be fast (target: load and parse index quickly relative to full-scan time, measured on reference dataset with 10,000+ entries)
- **NFR-006**: Index write operations MUST be atomic and interruption-safe (write-then-rename pattern, no partial writes)
- **NFR-007**: Index format MUST be human-readable and debuggable (JSON format, clear structure, version field)
- **NFR-008**: Index operations MUST not impact existing functionality (backward compatible, no breaking changes to existing commands)

### Key Entities *(include if feature involves data)*

- **Baseline Index**: A persistent JSON file (`.mediahub/registry/index.json`) containing metadata for all media files currently present in the library. The index enables fast library content queries without full recursive scans. Index entries contain normalized paths, file sizes, and modification times (no content hashing for P1).

- **Index Entry**: A single entry in the baseline index representing one media file in the library. Each entry contains: normalized path (relative to library root), file size (bytes), modification time (ISO8601 timestamp), and optional metadata fields for future extensibility.

- **Index Version**: A version field in the index JSON structure that enables future format migrations. Version 1.0 is the initial format. Future versions may add fields (e.g., content hashes in Slice 8) while maintaining backward compatibility.

- **Index Recovery**: The process of recreating the baseline index from scratch by performing a full library scan. Recovery occurs during `library adopt` operations when the index is missing or invalid. Recovery is idempotent and safe to re-run.

- **Incremental Index Update**: The process of adding new entries to the baseline index during import operations without performing a full library re-scan. Each successfully imported file adds one entry to the index atomically.

## Index Structure

### Proposed `index.json` Format

```json
{
  "version": "1.0",
  "created": "2026-01-27T10:00:00Z",
  "lastUpdated": "2026-01-27T15:30:00Z",
  "entryCount": 12543,
  "entries": [
    {
      "path": "2024/01/IMG_1234.jpg",
      "size": 2456789,
      "mtime": "2024-01-15T14:30:00Z"
    },
    {
      "path": "2024/01/VID_5678.mov",
      "size": 15678901,
      "mtime": "2024-01-15T14:35:00Z"
    }
  ]
}
```

**Field Descriptions**:
- `version`: Index format version (string, "1.0" for P1)
- `created`: ISO8601 timestamp when index was first created
- `lastUpdated`: ISO8601 timestamp when index was last updated
- `entryCount`: Number of entries in the index (for quick statistics)
- `entries`: Array of index entries, sorted by normalized path for determinism

**Entry Field Descriptions**:
- `path`: Normalized relative path from library root (string, e.g., "2024/01/IMG_1234.jpg")
- `size`: File size in bytes (integer)
- `mtime`: File modification time as ISO8601 timestamp (string)

**Design Decisions**:
- Paths are relative to library root for portability (library can be moved/renamed)
- Paths are normalized (resolved symlinks, consistent separators)
- Entries are sorted by path for deterministic JSON output
- No content hashing in P1 (reserved for Slice 8)
- Simple version field enables future format extensions

## Index Update Rules

### Initialization (Library Adoption)

1. **Trigger**: During `library adopt` operation, after baseline scan completes
2. **Input**: Baseline scan results from adoption (Set<String> of normalized paths)
3. **Process**:
   - For each path in baseline scan results, collect file metadata (size, mtime)
   - Create index entries sorted by normalized path
   - Write index to `.mediahub/registry/index.json` atomically (write-then-rename)
4. **Dry-Run**: In dry-run mode, show what index would be created (entry count, structure preview) but do not write `index.json`
5. **Idempotence**: If index already exists and is valid, do not overwrite (adoption is idempotent). If index is absent or invalid, (re)create it from baseline scan results.

### Incremental Update (Import)

1. **Trigger**: During `import` operation, after each file is successfully copied
2. **Input**: Successfully imported file metadata (destination path, size, mtime)
3. **Process**:
   - Load existing index (or create new if missing)
   - Add new entry for imported file (normalized relative path, size, mtime)
   - Remove duplicate entries if any (idempotent: same path = update entry)
   - Sort entries by path for determinism
   - Write updated index atomically (write-then-rename)
4. **Dry-Run**: In dry-run mode, show what index updates would be performed but do not modify `index.json`
5. **Batch Updates**: For multiple imports, batch index updates (update once per import operation, not per file) for performance
6. **Failure Handling**: If index update fails, import still succeeds (index is performance optimization, not critical path)

### Recovery via Library Adoption

1. **Trigger**: During `library adopt` operation, if index is absent or invalid
2. **Input**: Baseline scan results from adoption (Set<String> of normalized paths)
3. **Process**:
   - If index is valid, skip index creation (idempotent: preserve existing index)
   - If index is absent or invalid, create index from baseline scan results
   - For each path in baseline scan results, collect file metadata (size, mtime)
   - Create index entries sorted by normalized path
   - Write index atomically (write-then-rename)
4. **Idempotence**: Index creation is idempotent (same library state produces same index)

## Index Read Rules

### Detection Operations

1. **Check Index**: Attempt to load index from `.mediahub/registry/index.json`
2. **Validate Index**: 
   - Check file exists and is readable
   - Check JSON is valid and parseable
   - Check version is supported (1.0 for P1)
   - Check entries array is present and non-empty
3. **Use Index**: If valid, extract normalized paths from index entries and use for library comparison
4. **Fallback**: If index is missing or invalid, fall back to `LibraryContentQuery.scanLibraryContents()` (existing behavior) and report fallback reason in output
5. **Read-Only**: Detection operations never create or modify `index.json` (detection is read-only)

### Import Operations

1. **Check Index**: Same as detection (load and validate index)
2. **Use Index**: If valid, use index for library comparison during import planning
3. **Update Index**: After successful imports, update index incrementally (only if index was valid at start of import)
4. **Fallback**: If index is missing or invalid, fall back to full scan for comparison and report fallback reason in output (import does not regenerate index, only updates if index was valid)

### Status Operations

1. **Check Index**: Attempt to load index from `.mediahub/registry/index.json`
2. **Report Status**: Include index metadata in status output:
   - `index.present`: Boolean (index exists and is readable)
   - `index.version`: String (index format version)
   - `index.entryCount`: Integer (number of entries)
   - `index.lastUpdated`: ISO8601 timestamp (last update time)
   - `index.valid`: Boolean (index is valid and usable)
3. **Error Handling**: If index is missing or invalid, report status clearly (not an error, just informational)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Baseline index is created during `library adopt` operations using baseline scan results (no double scan, index created from existing scan)
- **SC-002**: Baseline index is updated incrementally during `import` operations (each successful import adds entry, no full re-scan)
- **SC-003**: Detection operations use baseline index when present and valid (fallback to full scan if missing/invalid)
- **SC-004**: Detection results are identical with and without baseline index (100% accuracy: index-based detection matches full-scan detection)
- **SC-005**: Detection performance improves significantly for large libraries (measured: index-based detection is >=5x faster than full-scan on a 10,000+ file library on the same machine)
- **SC-006**: Index updates are atomic and interruption-safe (write-then-rename pattern, no partial writes, verified by tests)
- **SC-007**: Index operations are idempotent (re-running adopt/import produces consistent index state, no duplicate entries)
- **SC-008**: Dry-run operations perform zero writes to `index.json` (verified by tests: no file modifications in dry-run mode)
- **SC-009**: Index information is included in `status` command output (presence, version, entry count, last update time)
- **SC-010**: Index information is included in JSON output formats without breaking existing schema (backward compatible, verified by tests)
- **SC-011**: Index format is stable and deterministic (same library state produces identical index JSON, verified by tests)
- **SC-012**: Index operations handle errors gracefully (missing/corrupted index triggers fallback, not failure)
- **SC-013**: Index file paths are validated strictly (never write outside library root, verified by tests)
- **SC-014**: All existing core tests still pass after index implementation (no regression in core functionality)
- **SC-015**: Index operations do not block or slow down adoption/import operations (index updates are fast relative to import operation time, measured on reference dataset)

## Assumptions

- Users will primarily benefit from baseline index for libraries with 10,000+ files (smaller libraries may not show significant performance improvement)
- Index will be created automatically during adoption and updated automatically during imports (no manual index management required for P1)
- Index corruption or staleness will be rare (external file system modifications are uncommon)
- Index format version 1.0 will be sufficient for P1 (future versions may add fields but maintain backward compatibility)
- JSON format is acceptable for index storage (human-readable, debuggable, sufficient performance for 10k+ entries)
- Index file size will remain reasonable (< 1MB per 10k entries) with efficient JSON encoding
- Index read/write operations will be fast enough for real-time use (load and update times are reasonable relative to operation time, measured on reference dataset)
- Users will not manually modify `index.json` (index is managed automatically by MediaHub)
- Library structure remains stable (files are not moved/renamed outside of MediaHub operations)
- Index recovery occurs during `library adopt` operations when index is missing or invalid (no separate regeneration command required)

## Safety Constraints

### Explicit Target Directories

- **Core Code**: Index implementation MUST be in `Sources/MediaHub/` (new `BaselineIndex.swift` or similar)
- **CLI Code**: Index information display MAY require changes in `Sources/MediaHubCLI/` (status command, JSON output)
- **Tests**: Index tests MUST be in `Tests/MediaHubTests/` (new `BaselineIndexTests.swift`)
- **Documentation**: Index documentation updates MAY be in `docs/` but MUST NOT modify existing ADRs without explicit justification

### Explicit "No Touch" Rules

- **DO NOT** modify existing `LibraryContentQuery.scanLibraryContents()` behavior (it remains the fallback mechanism)
- **DO NOT** add content hashing to index entries (hashing is reserved for Slice 8)
- **DO NOT** create new global registry format beyond baseline index (index is performance optimization, not new data model)
- **DO NOT** modify existing detection/import logic beyond adding index read/write calls (index is transparent optimization)
- **DO NOT** change existing JSON output schema (add index fields without breaking existing fields)
- **DO NOT** modify Package.swift beyond adding dependencies if absolutely necessary
- **DO NOT** modify existing specs/ or docs/ except for this Slice 7 spec
- **DO NOT** change existing CLI command structure beyond adding index information to output
- **DO NOT** modify existing error types beyond adding index-specific error messages

### Explicit Validation Commands

- **Validation**: Run `swift test` to ensure all existing tests pass
- **Validation**: Run `scripts/smoke_cli.sh` to ensure CLI smoke tests pass with index feature
- **Validation**: Performance testing: measure detection time with and without index on 10,000+ file library (target: >=5x speedup compared to full-scan on same machine)
- **Validation**: Manual testing of index creation during adoption (verify no double scan)
- **Validation**: Manual testing of incremental index updates during import (verify atomic updates)
- **Validation**: Manual testing of dry-run operations (verify zero writes to `index.json`)
- **Validation**: Manual testing of index fallback (corrupt/delete index, verify fallback works)
- **Validation**: Verify that index format is deterministic (same library state produces identical JSON)

## Non-Goals

- **P2 Features**: Content hashing in index entries (Slice 8)
- **P2 Features**: Cross-source deduplication using index (Slice 8)
- **P2 Features**: Index version migration logic beyond simple version field (P1 supports version 1.0 only)
- **P2 Features**: Manual index management commands (index is managed automatically)
- **P2 Features**: Index compression or optimization beyond efficient JSON encoding
- **P2 Features**: Index sharding or partitioning for very large libraries (P1 assumes single index file)
- **P2 Features**: Index query optimization beyond simple path lookup (P1 uses linear search, sufficient for 10k entries)
- **P2 Features**: Index backup or recovery beyond recovery via `library adopt`
- **P2 Features**: Index statistics or analytics beyond basic entry count and timestamps

## Risks & Mitigations

### Risk 1: Stale Index

**Description**: Index becomes out of sync with actual library contents if files are modified/deleted outside of MediaHub operations.

**Impact**: Detection/import may incorrectly identify files as known or new, leading to missed imports or false positives.

**Mitigation**:
- Index is performance optimization, not source of truth: fallback to full scan if index validation fails
- Index entries include mtime: can detect file modifications (future enhancement)
- Recovery via `library adopt` when index is missing or invalid
- Clear documentation that index is managed automatically and should not be manually modified

**Acceptance**: Index staleness does not cause data loss or incorrect imports (fallback ensures correctness).

### Risk 2: Index Corruption

**Description**: Index file becomes corrupted due to interruption, disk errors, or bugs.

**Impact**: Operations may fail or produce incorrect results if index is corrupted.

**Mitigation**:
- Atomic writes (write-then-rename pattern) prevent partial writes
- JSON validation on read: detect corruption and fall back to full scan
- Recovery via `library adopt` when index is corrupted
- Graceful degradation: operations succeed even if index is corrupted (fallback to full scan)

**Acceptance**: Index corruption does not cause operations to fail (fallback ensures functionality).

### Risk 3: Performance Regression

**Description**: Index operations (read/write) may slow down operations if not implemented efficiently.

**Impact**: Adoption/import operations may become slower despite index optimization.

**Mitigation**:
- Efficient JSON parsing (use native Foundation JSONDecoder)
- Batch index updates (update once per import operation, not per file)
- Lazy index loading (load only when needed)
- Performance testing: measure index operations and optimize if needed
- Index is optional: if index operations are too slow, fall back to full scan

**Acceptance**: Index operations complete quickly relative to operation time, measured on reference dataset (10k+ entries).

### Risk 4: Index File Size

**Description**: Index file may become very large for libraries with 100,000+ files.

**Impact**: Index read/write operations may become slow, JSON parsing may be expensive.

**Mitigation**:
- Efficient JSON encoding (compact format, no unnecessary whitespace)
- Performance testing: measure index size and operations for large libraries
- Future enhancement: index compression or sharding (out of scope for P1)
- P1 target: < 1MB per 10k entries (sufficient for typical libraries)

**Acceptance**: Index file size remains reasonable for libraries up to 50,000 files (P1 target).

### Risk 5: Migration to Slice 8 Hash Format

**Description**: Future Slice 8 (hashing) may require index format changes to include content hashes.

**Impact**: Index format migration may be complex if not designed for extensibility.

**Mitigation**:
- Version field in index format enables future migrations
- Index entries use flexible structure (can add fields without breaking existing code)
- Backward compatibility: version 1.0 index remains readable even after format updates
- Simple migration: Slice 8 can add hash fields to existing entries (additive change)

**Acceptance**: Index format is extensible and supports future hash fields (version field enables migration).

### Risk 6: Index Write Failures

**Description**: Index updates may fail due to disk space, permissions, or file system errors.

**Impact**: Index may become stale if updates fail silently.

**Mitigation**:
- Index updates are non-critical: import succeeds even if index update fails
- Error logging: report index update failures but do not fail operations
- Recovery via `library adopt`: if index is missing after import, can be recreated during next adoption
- Clear error messages: inform users if index updates fail (non-fatal)

**Acceptance**: Index update failures do not cause import/detection to fail (index is optimization, not critical path).

## Constitutional Compliance

This specification adheres to the MediaHub Constitution:

- **3.3 Safe Operations**: Index operations are atomic and interruption-safe, dry-run performs zero writes, graceful degradation on errors
- **4.1 Data Safety**: Index updates do not modify media files, index corruption does not cause data loss, fallback ensures correctness
- **3.4 Deterministic Behavior**: Index format is stable and deterministic, index-based detection produces identical results to full-scan detection
- **3.2 Transparent Storage**: Index is human-readable JSON, stored in `.mediahub/` directory, can be inspected without MediaHub
- **3.1 Simplicity of User Experience**: Index is managed automatically, no manual intervention required, transparent performance optimization
