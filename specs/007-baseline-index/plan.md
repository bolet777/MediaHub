# Implementation Plan: Baseline Index (Slice 7)

**Feature**: Baseline Index  
**Specification**: `specs/007-baseline-index/spec.md`  
**Slice**: 7 - Baseline Index  
**Created**: 2026-01-27

## Plan Scope

This plan implements **Slice 7 only**, which adds a persistent baseline index to accelerate `detect` and `import` operations on very large libraries (10,000+ files) by avoiding full re-scans of library contents. The index is created during `library adopt` and updated incrementally during `import` operations.

**Key Features**:
- Persistent baseline index at `.mediahub/registry/index.json` (normalized paths, file sizes, modification times)
- Index creation during `library adopt` (reuses baseline scan, no double scan, idempotent)
- Incremental index updates during `import` (atomic write-then-rename, batched updates)
- Index usage in `detect` and `import` (read-only for detect, fallback to full scan if missing/invalid)
- Index information in `status` command (presence, version, entry count, last update time)
- Fallback reporting (human-readable and JSON output with fallback reason)

**Explicitly out of scope**:
- Content hashing in index entries (Slice 8)
- Manual index management commands (index is managed automatically)
- Index version migration logic beyond simple version field (P1 supports version 1.0 only)
- Index compression, sharding, or advanced optimization (P1 assumes single JSON file)
- New CLI commands for index management

## Constitutional Compliance

This plan adheres to the MediaHub Constitution:

- **Safe Operations (3.3)**: Index operations are atomic and interruption-safe, dry-run performs zero writes, graceful degradation on errors
- **Data Safety (4.1)**: Index updates do not modify media files, index corruption does not cause data loss, fallback ensures correctness
- **Deterministic Behavior (3.4)**: Index format is stable and deterministic, index-based detection produces identical results to full-scan detection
- **Transparent Storage (3.2)**: Index is human-readable JSON, stored in `.mediahub/` directory, can be inspected without MediaHub
- **Simplicity of User Experience (3.1)**: Index is managed automatically, no manual intervention required, transparent performance optimization

## Work Breakdown

### Component 1: Baseline Index Core (Reader/Writer/Validator)

**Purpose**: Implement core baseline index data structures, file I/O operations (read/write), validation logic, and atomic write-then-rename pattern.

**Responsibilities**:
- Define index data structures (`BaselineIndex`, `IndexEntry`) matching spec format
- Implement index reader (load from JSON, parse, validate)
- Implement index writer (serialize to JSON, atomic write-then-rename)
- Implement index validator (check file exists, JSON valid, version supported, entries present)
- Ensure deterministic JSON encoding (entries sorted by normalized path, JSONEncoder with stable options documented — key order is not a contract)
- Ensure path normalization (relative to library root, resolved symlinks, consistent separators)
- Handle index errors gracefully (missing, corrupted, invalid version)
- Validate index file paths (never write outside library root)

**Requirements Addressed**:
- FR-001: Create persistent baseline index at `.mediahub/registry/index.json`
- FR-007: Ensure index updates are atomic (write-then-rename pattern)
- FR-012: Validate index file paths are strictly within library root
- FR-013: Ensure index format is stable and deterministic
- FR-014: Support index versioning (simple version field, no complex migration)

**Key Decisions**:
- How to structure index data types (`BaselineIndex` struct with Codable conformance)
- How to implement atomic write (reuse pattern from `AtomicFileCopy`: temp file + rename)
- How to ensure deterministic JSON (sorted entries by path, sorted keys in JSON encoder)
- How to normalize paths (relative to library root, use `URL.resolvingSymlinksInPath()`)
- How to validate index version (check version field, support 1.0 only for P1)
- Where to store index file (`.mediahub/registry/index.json`, ensure registry directory exists)

**File Touch List**:
- `Sources/MediaHub/BaselineIndex.swift` - New file with:
  - `BaselineIndex` struct (Codable, matches spec format)
  - `IndexEntry` struct (path, size, mtime)
  - `BaselineIndexReader` struct (load, parse, validate)
  - `BaselineIndexWriter` struct (serialize, atomic write)
  - `IndexValidator` struct (validate file, JSON, version, entries)
  - `BaselineIndexError` enum (missing, corrupted, invalid version, validation failed)

**Validation Points**:
- Index can be loaded from JSON file (valid format)
- Index can be written atomically (temp file + rename, no partial writes)
- Index validation detects missing, corrupted, or invalid index
- Index format is deterministic (same library state produces identical JSON)
- Path normalization works correctly (relative paths, symlink resolution)
- Index file paths are validated (never write outside library root)

**Risks & Open Questions**:
- How to ensure deterministic JSON encoding? (Use `JSONEncoder` with sorted keys option, sort entries array by path)
- How to handle index file locking? (Read-only operations for detect, write operations for adopt/import)
- How to ensure atomic write on all platforms? (Use `FileManager.moveItem()` which is atomic on macOS/Linux)
- Should index writer create registry directory if missing? (Yes, ensure `.mediahub/registry/` exists)

**NON-NEGOTIABLE CONSTRAINTS**:
- Index file MUST be written atomically (write-then-rename pattern, similar to `AtomicFileCopy`)
- Index format MUST be deterministic (entries sorted by path, stable JSON encoding)
- Index paths MUST be normalized (relative to library root, resolved symlinks)
- Index file paths MUST be validated (never write outside library root)
- Index version MUST be checked (support version 1.0 only for P1)

---

### Component 2: Index Integration in Library Adoption

**Purpose**: Integrate baseline index creation into `library adopt` workflow, reusing baseline scan results to avoid double scan, with idempotent behavior (preserve valid index, recreate if absent/invalid).

**Responsibilities**:
- Create index during adoption using baseline scan results (no double scan)
- Check if index exists and is valid before creating (idempotent: preserve valid index)
- Recreate index if absent or invalid (recovery via adoption)
- Collect file metadata (size, mtime) for each baseline scan path
- Create index entries sorted by normalized path
- Write index atomically (write-then-rename)
- Handle index creation failures gracefully (adoption succeeds even if index creation fails)
- Support dry-run mode (show what index would be created, zero writes)

**Requirements Addressed**:
- FR-002: Initialize baseline index during `library adopt` using baseline scan results
- FR-008: Ensure index creation is idempotent
- FR-009: Ensure dry-run performs zero writes to `index.json`

**Key Decisions**:
- How to integrate index creation into adoption workflow (add index creation step after baseline scan)
- How to check if index is valid (use `IndexValidator` before creating)
- How to collect file metadata efficiently (for each path in baseline scan, get size and mtime)
- How to handle index creation failure (log error, continue adoption, index is optional)
- How to support dry-run (build index structure in memory, show preview, do not write)

**File Touch List**:
- `Sources/MediaHub/LibraryAdoption.swift` - Modify to:
  - Add index creation step after baseline scan
  - Check if index exists and is valid (idempotent check)
  - Collect file metadata for baseline scan paths
  - Create index entries and write atomically
  - Handle index creation failures gracefully
  - Support dry-run mode (preview without writes)

**Validation Points**:
- Index is created during adoption using baseline scan results (no double scan)
- Idempotent adoption preserves valid existing index
- Idempotent adoption recreates index if absent or invalid
- Index creation failure does not cause adoption to fail
- Dry-run shows index preview without writing `index.json`
- Index entries match baseline scan results (same paths, correct metadata)

**Risks & Open Questions**:
- How to efficiently collect file metadata for 10,000+ files? (Use `FileManager.attributesOfItem()` in batch, O(n) operation)
- Should index creation be synchronous or async? (Synchronous for P1, adoption already waits for baseline scan)
- How to handle partial index creation on interruption? (Atomic write prevents partial files, temp file cleanup on failure)

**NON-NEGOTIABLE CONSTRAINTS**:
- Index creation MUST reuse baseline scan results (no double scan)
- Index creation MUST be idempotent (preserve valid index, recreate if absent/invalid)
- Index creation MUST be atomic (write-then-rename pattern)
- Index creation failure MUST NOT cause adoption to fail (index is optional, adoption metadata is primary)
- Dry-run MUST perform zero writes to `index.json`

---

### Component 3: Index Integration in Import

**Purpose**: Integrate incremental index updates into `import` workflow, updating index with newly imported files atomically, with fallback to full scan if index is missing/invalid.

**Responsibilities**:
- Check if index exists and is valid at start of import
- Use index for library comparison during import planning (if valid)
- Update index incrementally after successful imports (add entries for imported files)
- Batch index updates (update once per import operation, not per file)
- Remove duplicate entries (idempotent: same path = update entry)
- Sort entries by path for determinism
- Write updated index atomically (write-then-rename)
- Handle index update failures gracefully (import succeeds even if index update fails)
- Support dry-run mode (show what index updates would be performed, zero writes)
- Fallback to full scan if index is missing/invalid (report fallback reason)

**Requirements Addressed**:
- FR-003: Update baseline index incrementally during `import` operations
- FR-004: Use baseline index in `import` operations (fallback to full scan if missing/invalid)
- FR-007: Ensure index updates are atomic (write-then-rename pattern)
- FR-008: Ensure index updates are idempotent (no duplicate entries)
- FR-009: Ensure dry-run performs zero writes to `index.json`
- FR-006: Support graceful degradation (fallback to full scan, report fallback reason)

**Key Decisions**:
- How to integrate index updates into import workflow (check index at start, update after successful imports)
- How to batch index updates (collect all imported files, update index once at end of import)
- How to handle index missing/invalid at start (fallback to full scan, do not update index)
- How to handle index update failure (log error, continue import, index is optional)
- How to support dry-run (build index update preview, show what would be updated, do not write)

**File Touch List**:
- `Sources/MediaHub/ImportExecution.swift` - Modify to:
  - Check index at start of import (load and validate)
  - Use index for library comparison if valid (extract paths from index)
  - Fallback to full scan if index missing/invalid (report fallback reason)
  - Collect successfully imported files during import
  - Update index incrementally after import completes (batch update)
  - Handle index update failures gracefully
  - Support dry-run mode (preview index updates without writes)

**Validation Points**:
- Index is checked at start of import (load and validate)
- Index is used for library comparison if valid (extract paths, compare with candidates)
- Fallback to full scan works if index missing/invalid (report fallback reason)
- Index is updated incrementally after successful imports (new entries added)
- Index updates are batched (update once per import operation)
- Index updates are atomic (write-then-rename pattern)
- Index update failure does not cause import to fail
- Dry-run shows index update preview without writing `index.json`

**Risks & Open Questions**:
- How to efficiently update index with new entries? (Load index, add entries, sort, write - O(n log n) for sort, acceptable for 10k entries)
- Should index updates be synchronous or async? (Synchronous for P1, import already waits for file copies)
- How to handle index becoming invalid during import? (Use index state from start of import, do not re-check mid-import)

**NON-NEGOTIABLE CONSTRAINTS**:
- Index updates MUST be incremental (add entries for imported files, no full re-scan)
- Index updates MUST be atomic (write-then-rename pattern)
- Index updates MUST be idempotent (no duplicate entries, same path = update entry)
- Index update failure MUST NOT cause import to fail (index is optional, import is primary)
- Dry-run MUST perform zero writes to `index.json`
- Import MUST fallback to full scan if index missing/invalid (report fallback reason)

---

### Component 4: Index Integration in Detection (Read-Only)

**Purpose**: Integrate index usage into `detect` workflow for fast library content queries, with read-only guarantee (never create or modify index), fallback to full scan if missing/invalid, and fallback reason reporting.

**Responsibilities**:
- Check if index exists and is valid at start of detection
- Use index for library comparison if valid (extract normalized paths from index)
- Fallback to full scan if index missing/invalid (use `LibraryContentQuery.scanLibraryContents()`)
- Report fallback reason in output (human-readable and JSON)
- Ensure detection never creates or modifies `index.json` (read-only guarantee)
- Ensure index-based detection produces identical results to full-scan detection

**Requirements Addressed**:
- FR-004: Use baseline index in `detect` operations (fallback to full scan if missing/invalid)
- FR-005: Ensure index-based detection produces identical results to full-scan detection
- FR-006: Support graceful degradation (fallback to full scan, report fallback reason)
- FR-011: Include index information in JSON output formats

**Key Decisions**:
- How to integrate index usage into detection workflow (check index at start, use if valid, fallback if not)
- How to extract paths from index (read index entries, extract normalized paths, create Set<String>)
- How to report fallback reason (add `indexUsed: false`, `indexFallbackReason: "missing"|"corrupted"|"invalid"` to JSON output)
- How to ensure read-only guarantee (never call index writer from detection code path)

**File Touch List**:
- `Sources/MediaHub/DetectionOrchestration.swift` - Modify to:
  - Check index at start of detection (load and validate)
  - Use index for library comparison if valid (extract paths, use instead of `LibraryContentQuery.scanLibraryContents()`)
  - Fallback to full scan if index missing/invalid (use existing `LibraryContentQuery.scanLibraryContents()`)
  - Track index usage state (used/fallback, fallback reason)
  - Pass index usage state to detection result
- `Sources/MediaHub/DetectionResult.swift` - Modify to:
  - Add index usage fields (`indexUsed: Bool`, `indexFallbackReason: String?`)

**Validation Points**:
- Index is checked at start of detection (load and validate)
- Index is used for library comparison if valid (extract paths, compare with candidates)
- Fallback to full scan works if index missing/invalid (use `LibraryContentQuery.scanLibraryContents()`)
- Detection results are identical with and without index (100% accuracy)
- Fallback reason is reported in output (human-readable and JSON)
- Detection never creates or modifies `index.json` (read-only guarantee)

**Risks & Open Questions**:
- How to ensure index-based detection produces identical results? (Use same path normalization, same comparison logic)
- How to efficiently extract paths from index? (Read index entries, extract paths, create Set - O(n) operation)
- Should detection cache index in memory? (Load once per detection run, acceptable for 10k entries)

**NON-NEGOTIABLE CONSTRAINTS**:
- Detection MUST be read-only (never create or modify `index.json`)
- Detection MUST fallback to full scan if index missing/invalid (use `LibraryContentQuery.scanLibraryContents()`)
- Detection MUST report fallback reason in output (human-readable and JSON)
- Index-based detection MUST produce identical results to full-scan detection (deterministic behavior)

---

### Component 5: Index Information in Status

**Purpose**: Add index metadata to `status` command output (human-readable and JSON), including presence, version, entry count, and last update time.

**Responsibilities**:
- Check if index exists and is valid
- Extract index metadata (version, entry count, last update time)
- Format index information for human-readable output
- Format index information for JSON output (add `index.present`, `index.version`, `index.entryCount`, `index.lastUpdated`, `index.valid` fields)
- Handle missing/invalid index gracefully (report clearly, not an error)

**Requirements Addressed**:
- FR-010: Include index metadata in `status` command output
- FR-011: Include index information in JSON output formats (backward compatible)

**Key Decisions**:
- How to structure index metadata in status output (separate section for index information)
- How to format index information (human-readable: clear summary, JSON: structured fields)
- How to handle missing/invalid index (report clearly, not an error, just informational)

**File Touch List**:
- `Sources/MediaHubCLI/StatusCommand.swift` - Modify to:
  - Check index existence and validity
  - Extract index metadata
  - Format index information for output (human-readable and JSON)
- `Sources/MediaHubCLI/OutputFormatting.swift` - Add index formatting functions (if needed)

**Validation Points**:
- Index information is included in status output (presence, version, entry count, last update time)
- Index information is formatted correctly (human-readable and JSON)
- Missing/invalid index is reported clearly (not an error, just informational)
- JSON output is backward compatible (add index fields without breaking existing schema)

**Risks & Open Questions**:
- How to ensure JSON output is backward compatible? (Add optional index fields, existing fields unchanged)
- Should status command validate index integrity? (Check if index is valid, report status)

**NON-NEGOTIABLE CONSTRAINTS**:
- Status output MUST include index information (presence, version, entry count, last update time)
- JSON output MUST be backward compatible (add index fields without breaking existing schema)
- Missing/invalid index MUST be reported clearly (not an error, just informational)

---

### Component 6: Tests and Validation

**Purpose**: Implement comprehensive tests for baseline index feature, including unit tests for core components, integration tests for adopt/import/detect workflows, performance tests, and non-regression tests.

**Responsibilities**:
- Test index reader/writer (load, parse, validate, write atomically)
- Test index creation during adoption (reuses baseline scan, idempotent, dry-run)
- Test incremental index updates during import (atomic, batched, idempotent, dry-run)
- Test index usage in detection (read-only, fallback, identical results)
- Test index information in status (presence, metadata, JSON output)
- Test fallback behavior (missing/invalid index triggers fallback, not failure)
- Test path validation (never write outside library root)
- Test deterministic format (same library state produces identical JSON)
- Test performance (index-based detection >=5x faster than full-scan on 10k+ files)
- Ensure all existing tests still pass (no regression)

**Requirements Addressed**:
- SC-001 through SC-015: All success criteria from spec

**Key Decisions**:
- How to structure tests (unit tests for core components, integration tests for workflows)
- How to create test datasets (synthetic libraries with 10k+ files for performance tests)
- How to test atomic writes (verify temp file + rename pattern, no partial writes)
- How to test deterministic format (same inputs produce identical JSON)
- How to test performance (measure detection time with and without index)

**File Touch List**:
- `Tests/MediaHubTests/BaselineIndexTests.swift` - New file with:
  - Index reader/writer tests
  - Index validator tests
  - Index format tests (deterministic, path normalization)
  - Atomic write tests
  - Path validation tests
- `Tests/MediaHubTests/LibraryAdoptionTests.swift` - Modify to:
  - Test index creation during adoption
  - Test idempotent adoption with index
  - Test dry-run with index preview
- `Tests/MediaHubTests/ImportExecutionTests.swift` - Modify to:
  - Test incremental index updates during import
  - Test index usage in import (fallback if missing/invalid)
  - Test dry-run with index update preview
- `Tests/MediaHubTests/DetectionOrchestrationTests.swift` - Modify to:
  - Test index usage in detection (read-only, fallback)
  - Test identical results with and without index
  - Test fallback reason reporting
- `Tests/MediaHubTests/StatusCommandTests.swift` - New or modify to:
  - Test index information in status output
  - Test JSON output with index metadata

**Validation Points**:
- All unit tests pass (index reader/writer, validator, format)
- All integration tests pass (adopt/import/detect workflows)
- Performance tests show >=5x speedup for 10k+ files (optional/non-blocking, measured on same machine and dataset)
- All existing tests still pass (no regression)
- Dry-run tests verify zero writes to `index.json`
- Atomic write tests verify temp file + rename pattern
- Deterministic format tests verify same inputs produce identical JSON

**Risks & Open Questions**:
- How to create test datasets with 10k+ files efficiently? (Use synthetic file creation, mock file system if needed)
- How to measure performance accurately? (Use `measure` blocks, run multiple times, average results)
- How to test atomic writes? (Verify temp file exists before rename, verify no partial writes on interruption)

**NON-NEGOTIABLE CONSTRAINTS**:
- Tests MUST cover all success criteria from spec (SC-001 through SC-015)
- Tests MUST verify read-only guarantee for detection (never create or modify index)
- Tests MUST verify atomic writes (temp file + rename pattern)
- Tests MUST verify deterministic format (same inputs produce identical JSON)
- Tests MUST verify no regression (all existing tests still pass)

---

## Execution Sequences

### Sequence 1: Library Adoption with Index Creation

1. **Adoption Start**: User runs `mediahub library adopt <path> [--dry-run] [--yes]`
2. **Baseline Scan**: Perform baseline scan of existing media files (existing logic, no change)
3. **Index Check**: Check if `.mediahub/registry/index.json` exists and is valid
   - If valid: Skip index creation (idempotent: preserve existing index)
   - If absent/invalid: Proceed to index creation
4. **Index Creation** (if needed):
   - For each path in baseline scan results, collect file metadata (size, mtime)
   - Create index entries sorted by normalized path
   - Write index atomically (temp file + rename to `.mediahub/registry/index.json`)
5. **Dry-Run Handling**: If `--dry-run`, show index preview (entry count, structure) but do not write
6. **Adoption Complete**: Report adoption success, index creation status (if applicable)

**Fallback Decisions**:
- If index creation fails: Log error, continue adoption (index is optional)
- If baseline scan fails: Adoption fails (baseline scan is required)

### Sequence 2: Import with Index Updates

1. **Import Start**: User runs `mediahub import <source-id> --all --library <path> [--dry-run]`
2. **Index Check**: Check if `.mediahub/registry/index.json` exists and is valid
   - If valid: Load index, extract paths for library comparison
   - If missing/invalid: Fallback to `LibraryContentQuery.scanLibraryContents()`, report fallback reason
3. **Detection**: Run detection using index (if valid) or full scan (if fallback)
4. **Import Execution**: Import selected items, track successfully imported files
5. **Index Update** (if index was valid at start):
   - Load existing index
   - Add entries for successfully imported files (normalized relative paths, size, mtime)
   - Remove duplicates (idempotent: same path = update entry)
   - Sort entries by path
   - Write updated index atomically (temp file + rename)
6. **Dry-Run Handling**: If `--dry-run`, show index update preview but do not write
7. **Import Complete**: Report import success, index update status (if applicable)

**Fallback Decisions**:
- If index missing/invalid at start: Fallback to full scan, do not update index
- If index update fails: Log error, continue import (index is optional)
- If import fails: Do not update index (only update on successful imports)

### Sequence 3: Detection with Index Usage

1. **Detection Start**: User runs `mediahub detect <source-id> --library <path> [--json]`
2. **Index Check**: Check if `.mediahub/registry/index.json` exists and is valid
   - If valid: Load index, extract normalized paths, use for library comparison
   - If missing/invalid: Fallback to `LibraryContentQuery.scanLibraryContents()`, report fallback reason
3. **Library Comparison**: Compare source candidates against library contents (from index or full scan)
4. **Detection Complete**: Report detection results, index usage status (`indexUsed: true/false`, `indexFallbackReason` if applicable)

**Fallback Decisions**:
- If index missing: Fallback to full scan, report `indexFallbackReason: "missing"`
- If index corrupted: Fallback to full scan, report `indexFallbackReason: "corrupted"`
- If index invalid version: Fallback to full scan, report `indexFallbackReason: "invalid_version"`
- Detection never creates or modifies index (read-only guarantee)

### Sequence 4: Status with Index Information

1. **Status Start**: User runs `mediahub status --library <path> [--json]`
2. **Index Check**: Check if `.mediahub/registry/index.json` exists and is valid
3. **Index Metadata Extraction**: If index exists, extract metadata (version, entry count, last update time)
4. **Status Output**: Format index information for output (human-readable or JSON)
5. **Status Complete**: Report status with index information

**Fallback Decisions**:
- If index missing: Report `index.present: false`, other fields omitted
- If index invalid: Report `index.present: true`, `index.valid: false`, other fields if available

---

## Atomic Write Strategy

### Write-Then-Rename Pattern

**Strategy**: Temporary file + atomic rename (reuse pattern from `AtomicFileCopy`)

**Process**:
1. Create temporary file in same directory as target (`.mediahub/registry/.index.json.mediahub-tmp-{UUID}`)
2. Write JSON content to temporary file
3. Verify write integrity (file exists, size matches)
4. Atomically rename temporary file to final destination (`.mediahub/registry/index.json`)
5. Cleanup temporary file on failure (if rename fails, remove temp file)

**Rationale**:
- Atomic rename is filesystem-level operation (prevents partial files)
- Temporary file in same directory ensures rename is atomic
- Verification ensures data integrity
- Standard approach for atomic writes (consistent with `AtomicFileCopy`)

### Error Handling

**Index Creation/Update Failures**:
- Index is optional: operations (adopt/import) succeed even if index creation/update fails
- Log errors: report index failures but do not fail operations
- Clear error messages: inform users if index operations fail (non-fatal)

**Index Read Failures**:
- Fallback to full scan: if index cannot be read, use `LibraryContentQuery.scanLibraryContents()`
- Report fallback reason: include `indexFallbackReason` in output (human-readable and JSON)
- Operations succeed: detection/import succeed even if index read fails

**Path Validation Failures**:
- Strict validation: never write index outside library root
- Clear error messages: report path validation failures clearly
- Fail fast: if path validation fails, do not attempt write

---

## Test Plan

### Unit Tests

**BaselineIndexTests.swift**:
- Test index reader (load valid JSON, parse correctly)
- Test index reader (handle missing file, corrupted JSON, invalid version)
- Test index writer (serialize to JSON, deterministic format)
- Test index writer (atomic write-then-rename pattern)
- Test index validator (validate file exists, JSON valid, version supported, entries present)
- Test path normalization (relative paths, symlink resolution, consistent separators)
- Test path validation (never write outside library root)
- Test deterministic format (same inputs produce identical JSON)

### Integration Tests

**LibraryAdoptionTests.swift** (modify):
- Test index creation during adoption (reuses baseline scan, no double scan)
- Test idempotent adoption with valid index (preserves existing index)
- Test idempotent adoption with missing index (creates index)
- Test idempotent adoption with invalid index (recreates index)
- Test index creation failure (adoption succeeds, index is optional)
- Test dry-run with index preview (zero writes, preview shown)

**ImportExecutionTests.swift** (modify):
- Test incremental index updates during import (add entries for imported files)
- Test index usage in import (use index for comparison if valid)
- Test fallback to full scan if index missing/invalid (report fallback reason)
- Test batched index updates (update once per import operation)
- Test index update failure (import succeeds, index is optional)
- Test dry-run with index update preview (zero writes, preview shown)

**DetectionOrchestrationTests.swift** (modify):
- Test index usage in detection (use index if valid, extract paths)
- Test fallback to full scan if index missing/invalid (report fallback reason)
- Test identical results with and without index (100% accuracy)
- Test read-only guarantee (detection never creates or modifies index)
- Test fallback reason reporting (human-readable and JSON)

**StatusCommandTests.swift** (new or modify):
- Test index information in status output (presence, version, entry count, last update time)
- Test JSON output with index metadata (backward compatible)
- Test missing/invalid index handling (reported clearly, not an error)

### Performance Tests

**BaselineIndexPerformanceTests.swift** (new, optional/non-blocking):
- Test index load performance (measure relative to full-scan time on same dataset and machine — indicative, not contractual)
- Test index write performance (measure relative to import operation time on same dataset — indicative, not contractual)
- Test detection performance with index (target: >=5x faster than full-scan on 10k+ files, measured on same machine and dataset)
- Test detection performance without index (baseline for comparison on same dataset)

**Test Datasets**:
- Synthetic library with 10,000+ media files (for performance tests)
- Use temporary directories, create files programmatically
- Measure detection time with and without index on same dataset

### Non-Regression Tests

**Existing Test Suite**:
- Run `swift test` to ensure all existing tests still pass
- Verify no breaking changes to existing functionality
- Verify backward compatibility (JSON output schema)

---

## Validation Checklist

### Functional Validation

- [ ] Index is created during `library adopt` using baseline scan results (no double scan)
- [ ] Idempotent adoption preserves valid existing index
- [ ] Idempotent adoption recreates index if absent/invalid
- [ ] Index is updated incrementally during `import` (add entries for imported files)
- [ ] Index updates are atomic (write-then-rename pattern, no partial writes)
- [ ] Index updates are idempotent (no duplicate entries)
- [ ] Index is used in `detect` if valid (extract paths, use for comparison)
- [ ] Detection falls back to full scan if index missing/invalid (report fallback reason)
- [ ] Detection never creates or modifies index (read-only guarantee)
- [ ] Detection results are identical with and without index (100% accuracy)
- [ ] Index information is included in `status` output (presence, version, entry count, last update time)
- [ ] JSON output includes index metadata (backward compatible)

### Safety Validation

- [ ] Dry-run performs zero writes to `index.json` (verified by tests)
- [ ] Index file paths are validated (never write outside library root)
- [ ] Index creation failure does not cause adoption to fail (index is optional)
- [ ] Index update failure does not cause import to fail (index is optional)
- [ ] Index read failure triggers fallback, not failure (operations succeed)

### Performance Validation

- [ ] Detection with index is >=5x faster than full-scan on 10k+ files (measured on same machine)
- [ ] Index load time is reasonable (measured on reference dataset)
- [ ] Index write time is reasonable (measured on reference dataset)
- [ ] Index operations do not block adoption/import operations (measured on reference dataset)

### Determinism Validation

- [ ] Index format is deterministic (same library state produces identical JSON)
- [ ] Entries are sorted by normalized path (deterministic order)
- [ ] JSON encoding uses stable options (sorted keys, consistent format)

### Non-Regression Validation

- [ ] All existing tests still pass (`swift test`)
- [ ] CLI smoke tests pass (`scripts/smoke_cli.sh`)
- [ ] JSON output schema is backward compatible (existing fields unchanged)

---

## Implementation Notes

### JSON Encoding Determinism

**Strategy**: Use `JSONEncoder` with sorted keys option and sort entries array by path

**Implementation**:
- Sort index entries by normalized path before encoding (deterministic order)
- Use `JSONEncoder` with stable options (documented in code — key order is not a contract)
- Determinism achieved through sorted entries and normalized paths, not through key order

### Path Normalization

**Strategy**: Relative paths from library root, resolved symlinks, consistent separators

**Implementation**:
- Use `URL.resolvingSymlinksInPath()` to resolve symlinks
- Convert absolute paths to relative paths (relative to library root)
- Use consistent path separators (`/` on all platforms)
- Store normalized paths in index entries

### Index Version Support

**Strategy**: Simple version field, support version 1.0 only for P1

**Implementation**:
- Check version field on index load
- Support version "1.0" only (reject other versions for P1)
- Future versions can add fields (additive changes, backward compatible)

### Registry Directory Creation

**Strategy**: Ensure `.mediahub/registry/` directory exists before writing index

**Implementation**:
- Check if `.mediahub/registry/` exists before writing index
- Create directory if missing (with intermediate directories)
- Handle directory creation failures gracefully

---

**Last Updated**: 2026-01-27  
**Next Review**: After implementation or after real-world usage
