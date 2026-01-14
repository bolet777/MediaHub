# Implementation Tasks: Baseline Index (Slice 7)

**Feature**: Baseline Index  
**Specification**: `specs/007-baseline-index/spec.md`  
**Plan**: `specs/007-baseline-index/plan.md`  
**Slice**: 7 - Baseline Index  
**Created**: 2026-01-27

## Task Organization

Tasks are organized by component and follow the implementation sequence defined in the plan. Each task is:
- Small and focused on a single deliverable
- Sequential (dependencies are clear)
- Traceable to plan components (referenced by component number)
- Includes only P1 scope: baseline index creation, incremental updates, read-only detection usage, status information, safety-first error handling

## NON-NEGOTIABLE CONSTRAINTS FOR SLICE 7

**CRITICAL**: The following constraints MUST be followed during Slice 7 implementation:

1. **Code Location**:
   - Core index implementation MUST be in `Sources/MediaHub/` (new `BaselineIndex.swift`)
   - CLI changes MUST be minimal (status command, JSON output formatting only)
   - Tests MUST be in `Tests/MediaHubTests/` (new `BaselineIndexTests.swift`)

2. **Read-Only Guarantee**:
   - `detect` operations MUST never create or modify `index.json` (read-only guarantee)
   - Detection code path MUST never call index writer functions

3. **Write Safety**:
   - All index writes MUST be atomic (write-then-rename pattern, reuse `AtomicFileCopy` pattern)
   - Index writes MUST be limited to `.mediahub/**` directory
   - Path validation MUST ensure never writing outside library root
   - Dry-run MUST perform zero writes to `index.json` (preview only)

4. **Idempotence**:
   - `library adopt` MUST preserve valid existing index (do not overwrite)
   - `library adopt` MUST recreate index if absent or invalid
   - Index updates MUST be idempotent (no duplicate entries)

5. **Fallback Behavior**:
   - Operations MUST fallback to `LibraryContentQuery.scanLibraryContents()` if index missing/invalid
   - Fallback reason MUST be reported in output (human-readable and JSON)
   - Operations MUST succeed even if index operations fail (index is optional)

6. **Determinism**:
   - Index entries MUST be sorted by normalized path (deterministic order)
   - JSON encoding MUST use stable options (documented in code)
   - Determinism achieved through sorted entries and normalized paths, not key order

7. **Backward Compatibility**:
   - NO breaking changes to existing CLI behavior when index is not present
   - JSON output MUST be backward compatible (add index fields without breaking existing schema)
   - All existing tests MUST still pass after implementation

---

## Component 1: Baseline Index Core (Reader/Writer/Validator)

**Plan Reference**: Component 1 (lines 41-95)  
**Dependencies**: None (Foundation, reuse `AtomicFileCopy` pattern)

### Task 1.1: Create BaselineIndex.swift File Structure
**Priority**: P1
- **Objective**: Create new `BaselineIndex.swift` file with data structures matching spec format (`BaselineIndex`, `IndexEntry`, error types)
- **Deliverable**: New file with struct definitions, Codable conformance, error enum
- **Files**: `Sources/MediaHub/BaselineIndex.swift`
- **Dependencies**: None
- **Acceptance**: File compiles, structs match spec format (version, created, lastUpdated, entryCount, entries), follows existing code patterns
- **Validation**: `swift build` succeeds, structs are Codable

### Task 1.2: Implement Index Entry Structure
**Priority**: P1
- **Objective**: Implement `IndexEntry` struct with normalized path (relative to library root), size (bytes), mtime (ISO8601 timestamp)
- **Deliverable**: `IndexEntry` struct with Codable conformance, path normalization logic
- **Files**: `Sources/MediaHub/BaselineIndex.swift`
- **Dependencies**: Task 1.1
- **Acceptance**: `IndexEntry` stores normalized relative paths, sizes, and timestamps; paths are normalized (resolved symlinks, consistent separators)
- **Validation**: Unit test creates `IndexEntry` with normalized path, verifies path is relative to library root

### Task 1.3: Implement Path Normalization
**Priority**: P1
- **Objective**: Add path normalization function that converts absolute paths to relative paths (relative to library root), resolves symlinks, uses consistent separators
- **Deliverable**: `normalizePath(_:relativeTo:)` function that returns normalized relative path
- **Files**: `Sources/MediaHub/BaselineIndex.swift`
- **Dependencies**: Task 1.2
- **Acceptance**: Function converts absolute paths to relative paths, resolves symlinks using `URL.resolvingSymlinksInPath()`, uses consistent separators (`/` on all platforms)
- **Validation**: Unit test normalizes paths, verifies relative paths, symlink resolution, consistent separators

### Task 1.4: Implement Index Validator
**Priority**: P1
- **Objective**: Implement `IndexValidator` struct that validates index file (exists, readable, valid JSON, supported version, entries present)
- **Deliverable**: `IndexValidator.validate(_:at:)` method that returns validation result (valid/invalid with reason)
- **Files**: `Sources/MediaHub/BaselineIndex.swift`
- **Dependencies**: Task 1.1
- **Acceptance**: Validator checks file exists, JSON is valid and parseable, version is "1.0" (support version 1.0 only for P1), entries array present (can be empty)
- **Validation**: Unit tests validate missing file, corrupted JSON, invalid version, missing entries array, empty entries array (valid case)

### Task 1.5: Implement Index Reader
**Priority**: P1
- **Objective**: Implement `BaselineIndexReader` struct that loads index from JSON file, parses, validates
- **Deliverable**: `BaselineIndexReader.load(from:)` method that returns `BaselineIndex` or throws error
- **Files**: `Sources/MediaHub/BaselineIndex.swift`
- **Dependencies**: Task 1.1, Task 1.4
- **Acceptance**: Reader loads JSON file, parses using `JSONDecoder`, validates using `IndexValidator`, returns `BaselineIndex` or throws `BaselineIndexError`
- **Validation**: Unit tests load valid index, handle missing file, corrupted JSON, invalid version

### Task 1.6: Implement Index Writer (Atomic Write)
**Priority**: P1
- **Objective**: Implement `BaselineIndexWriter` struct that serializes index to JSON and writes atomically using write-then-rename pattern (reuse `AtomicFileCopy` pattern)
- **Deliverable**: `BaselineIndexWriter.write(_:to:)` method that writes index atomically (temp file + rename)
- **Files**: `Sources/MediaHub/BaselineIndex.swift`
- **Dependencies**: Task 1.1, Task 1.2
- **Acceptance**: Writer creates temp file in same directory, writes JSON content, atomically renames to final destination, cleans up temp file on failure; uses `FileManager.moveItem()` for atomic rename
- **Validation**: Unit tests verify atomic write with robust assertions: final file exists after write, final file decodes to valid index, no temp file leftovers, repeat write keeps valid file (no corruption)

### Task 1.7: Implement Deterministic JSON Encoding
**Priority**: P1
- **Objective**: Ensure index JSON encoding is deterministic (entries sorted by normalized path, stable JSON encoder options documented)
- **Deliverable**: JSON encoding that produces identical output for same library state
- **Files**: `Sources/MediaHub/BaselineIndex.swift`
- **Dependencies**: Task 1.6
- **Acceptance**: Entries are sorted by normalized path before encoding, JSON encoder uses stable options (documented in code comments), same library state produces identical JSON
- **Validation**: Unit test encodes same index twice, verifies identical JSON output

### Task 1.8: Implement Path Validation
**Priority**: P1
- **Objective**: Add path validation that ensures index file path is strictly within library root (never write outside library boundaries)
- **Deliverable**: `validateIndexPath(_:libraryRoot:)` function that throws error if path is outside library root
- **Files**: `Sources/MediaHub/BaselineIndex.swift`
- **Dependencies**: Task 1.6
- **Acceptance**: Validation checks that index file path is within library root directory, throws `BaselineIndexError` if path is outside library root
- **Validation**: Unit tests verify path validation (rejects paths outside library root, accepts paths within library root)

### Task 1.9: Implement Registry Directory Creation
**Priority**: P1
- **Objective**: Ensure `.mediahub/registry/` directory exists before writing index (create if missing)
- **Deliverable**: Function that creates registry directory if missing (with intermediate directories)
- **Files**: `Sources/MediaHub/BaselineIndex.swift`
- **Dependencies**: Task 1.6
- **Acceptance**: Function checks if `.mediahub/registry/` exists, creates directory if missing using `FileManager.createDirectory()`, handles creation failures gracefully
- **Validation**: Unit test verifies registry directory is created if missing, handles creation failures

### Task 1.10: Add Core Index Unit Tests
**Priority**: P1
- **Objective**: Add comprehensive unit tests for index reader, writer, validator, path normalization, deterministic encoding
- **Deliverable**: Test suite covering all core index operations
- **Files**: `Tests/MediaHubTests/BaselineIndexTests.swift`
- **Dependencies**: Task 1.1 through Task 1.9
- **Acceptance**: Tests cover index load/save, validation (including empty entries array), path normalization, atomic writes (with robust assertions: final file exists, decodes, no temp leftovers, repeat write keeps valid file), deterministic encoding, path validation
- **Validation**: `swift test --filter BaselineIndexTests` passes

---

## Component 2: Index Integration in Library Adoption

**Plan Reference**: Component 2 (lines 97-160)  
**Dependencies**: Component 1 (BaselineIndex core)

### Task 2.1: Add Index Creation to Adoption Workflow
**Priority**: P1
- **Objective**: Integrate index creation into `library adopt` workflow, after baseline scan completes
- **Deliverable**: Index creation step in adoption that uses baseline scan results
- **Files**: `Sources/MediaHub/LibraryAdoption.swift`
- **Dependencies**: Component 1 (all tasks)
- **Acceptance**: Adoption checks if index exists and is valid, creates index from baseline scan results if absent/invalid, preserves valid existing index (idempotent)
- **Validation**: Integration test adopts library, verifies index is created, verifies idempotent adoption preserves index

### Task 2.2: Implement Index Creation from Baseline Scan
**Priority**: P1
- **Objective**: Collect file metadata (size, mtime) for each path in baseline scan results, create index entries sorted by normalized path
- **Deliverable**: Function that creates `BaselineIndex` from baseline scan paths
- **Files**: `Sources/MediaHub/LibraryAdoption.swift`
- **Dependencies**: Task 2.1
- **Acceptance**: Function iterates through baseline scan paths, collects file metadata using `FileManager.attributesOfItem()`, creates index entries sorted by normalized path, creates `BaselineIndex` with entries
- **Validation**: Unit test creates index from baseline scan paths, verifies entries match paths, sorted by normalized path

### Task 2.3: Implement Idempotent Index Creation
**Priority**: P1
- **Objective**: Ensure index creation is idempotent (preserve valid existing index, recreate if absent/invalid)
- **Deliverable**: Idempotent index creation logic in adoption
- **Files**: `Sources/MediaHub/LibraryAdoption.swift`
- **Dependencies**: Task 2.1, Task 1.4
- **Acceptance**: Adoption checks if index exists and is valid using `IndexValidator`, preserves valid index (skip creation), recreates index if absent or invalid
- **Validation**: Integration test verifies idempotent adoption preserves valid index, recreates invalid index

### Task 2.4: Handle Index Creation Failures Gracefully
**Priority**: P1
- **Objective**: Ensure adoption succeeds even if index creation fails (index is optional, adoption metadata is primary)
- **Deliverable**: Error handling that logs index creation failures but does not fail adoption
- **Files**: `Sources/MediaHub/LibraryAdoption.swift`
- **Dependencies**: Task 2.1
- **Acceptance**: If index creation fails, error is logged, adoption continues and succeeds, clear error message is reported
- **Validation**: Integration test simulates index creation failure, verifies adoption succeeds, error is logged

### Task 2.5: Support Dry-Run for Index Creation
**Priority**: P1
- **Objective**: Show index creation preview in dry-run mode without writing `index.json`
- **Deliverable**: Dry-run preview that shows what index would be created (entry count, structure preview)
- **Files**: `Sources/MediaHub/LibraryAdoption.swift`
- **Dependencies**: Task 2.1
- **Acceptance**: Dry-run mode builds index structure in memory, shows preview (entry count, structure), does not write `index.json` (zero writes)
- **Validation**: Integration test verifies dry-run shows index preview, no `index.json` file is created

### Task 2.6: Add Adoption Index Integration Tests
**Priority**: P1
- **Objective**: Add integration tests for index creation during adoption (idempotent, dry-run, failure handling)
- **Deliverable**: Test suite covering adoption index integration
- **Files**: `Tests/MediaHubTests/LibraryAdoptionTests.swift` (modify)
- **Dependencies**: Task 2.1 through Task 2.5
- **Acceptance**: Tests cover index creation during adoption, idempotent adoption with index, dry-run with index preview, index creation failure handling
- **Validation**: `swift test --filter LibraryAdoptionTests` passes

---

## Component 3: Index Integration in Import

**Plan Reference**: Component 3 (lines 162-230)  
**Dependencies**: Component 1 (BaselineIndex core)

### Task 3.1: Add Index Check at Start of Import
**Priority**: P1
- **Objective**: Check if index exists and is valid at start of import, load index if valid, fallback to full scan if missing/invalid
- **Deliverable**: Index check logic at start of import workflow
- **Files**: `Sources/MediaHub/ImportExecution.swift`
- **Dependencies**: Component 1 (all tasks)
- **Acceptance**: Import checks index using `IndexValidator`, loads index if valid, falls back to `LibraryContentQuery.scanLibraryContents()` if missing/invalid, tracks index usage state (used/fallback, fallback reason)
- **Validation**: Integration test verifies index is checked at start, fallback works if missing/invalid

### Task 3.2: Use Index for Library Comparison in Import
**Priority**: P1
- **Objective**: Extract normalized paths from index entries and use for library comparison during import planning (if index is valid)
- **Deliverable**: Function that extracts paths from index and uses for comparison
- **Files**: `Sources/MediaHub/ImportExecution.swift`
- **Dependencies**: Task 3.1
- **Acceptance**: If index is valid, extract normalized paths from index entries, create `Set<String>` of library paths, use for comparison with source candidates
- **Validation**: Integration test verifies index paths are used for comparison, results match full-scan results

### Task 3.3: Implement Incremental Index Updates
**Priority**: P1
- **Objective**: Update index incrementally after successful imports, adding entries for imported files (batched: update once per import operation)
- **Deliverable**: Function that updates index with new entries after import completes
- **Files**: `Sources/MediaHub/ImportExecution.swift`
- **Dependencies**: Task 3.1, Component 1 (all tasks)
- **Acceptance**: After successful imports, only write/update index if the index was valid at the start of the import run (indexStateAtStart == .valid). If valid: load existing index, add entries for imported files (normalized relative paths, size, mtime), remove duplicates (idempotent: same path = update entry), sort entries by path, write updated index atomically. If fallback at start (missing/invalid): import can succeed, but no write to `index.json` (even after successful copies)
- **Validation**: Integration test verifies index is updated after import only if index was valid at start, new entries are added, duplicates are removed, entries are sorted; verifies no index write if fallback occurred at start

### Task 3.4: Implement Batched Index Updates
**Priority**: P1
- **Objective**: Batch index updates (update once per import operation, not per file) for performance
- **Deliverable**: Batched update logic that collects imported files and updates index once
- **Files**: `Sources/MediaHub/ImportExecution.swift`
- **Dependencies**: Task 3.3
- **Acceptance**: Import collects successfully imported files during import, updates index once at end of import operation (not per file), batched update is atomic
- **Validation**: Integration test verifies index is updated once per import operation, not per file

### Task 3.5: Handle Index Update Failures Gracefully
**Priority**: P1
- **Objective**: Ensure import succeeds even if index update fails (index is optional, import is primary)
- **Deliverable**: Error handling that logs index update failures but does not fail import
- **Files**: `Sources/MediaHub/ImportExecution.swift`
- **Dependencies**: Task 3.3
- **Acceptance**: If index update fails, error is logged, import continues and succeeds, clear error message is reported
- **Validation**: Integration test simulates index update failure, verifies import succeeds, error is logged

### Task 3.6: Support Dry-Run for Index Updates
**Priority**: P1
- **Objective**: Show index update preview in dry-run mode without writing `index.json`
- **Deliverable**: Dry-run preview that shows what index updates would be performed
- **Files**: `Sources/MediaHub/ImportExecution.swift`
- **Dependencies**: Task 3.3
- **Acceptance**: Dry-run mode builds index update preview in memory, shows what entries would be added, does not write `index.json` (zero writes). Only shows preview if index was valid at start of import (indexStateAtStart == .valid); if fallback occurred, no index update preview shown
- **Validation**: Integration test verifies dry-run shows index update preview only if index was valid at start, no `index.json` file is modified

### Task 3.7: Add Import Index Integration Tests
**Priority**: P1
- **Objective**: Add integration tests for index usage and updates during import (incremental updates, batched updates, dry-run, failure handling)
- **Deliverable**: Test suite covering import index integration
- **Files**: `Tests/MediaHubTests/ImportExecutionTests.swift` (modify)
- **Dependencies**: Task 3.1 through Task 3.6
- **Acceptance**: Tests cover index usage in import, incremental updates, batched updates, dry-run with index update preview, index update failure handling
- **Validation**: `swift test --filter ImportExecutionTests` passes

---

## Component 4: Index Integration in Detection (Read-Only)

**Plan Reference**: Component 4 (lines 232-275)  
**Dependencies**: Component 1 (BaselineIndex core)

### Task 4.1: Add Index Check at Start of Detection
**Priority**: P1
- **Objective**: Check if index exists and is valid at start of detection, load index if valid, fallback to full scan if missing/invalid
- **Deliverable**: Index check logic at start of detection workflow
- **Files**: `Sources/MediaHub/DetectionOrchestration.swift`
- **Dependencies**: Component 1 (all tasks)
- **Acceptance**: Detection checks index using `IndexValidator`, loads index if valid, falls back to `LibraryContentQuery.scanLibraryContents()` if missing/invalid, tracks index usage state (used/fallback, fallback reason)
- **Validation**: Integration test verifies index is checked at start, fallback works if missing/invalid

### Task 4.2: Use Index for Library Comparison in Detection
**Priority**: P1
- **Objective**: Extract normalized paths from index entries and use for library comparison (if index is valid)
- **Deliverable**: Function that extracts paths from index and uses for comparison
- **Files**: `Sources/MediaHub/DetectionOrchestration.swift`
- **Dependencies**: Task 4.1
- **Acceptance**: If index is valid, extract normalized paths from index entries, create `Set<String>` of library paths, use for comparison with source candidates (instead of `LibraryContentQuery.scanLibraryContents()`)
- **Validation**: Integration test verifies index paths are used for comparison, results match full-scan results (identical results)

### Task 4.3: Ensure Read-Only Guarantee
**Priority**: P1
- **Objective**: Ensure detection never creates or modifies `index.json` (read-only guarantee)
- **Deliverable**: Detection code path that never calls index writer functions
- **Files**: `Sources/MediaHub/DetectionOrchestration.swift`
- **Dependencies**: Task 4.1
- **Acceptance**: Detection code path only calls index reader functions, never calls index writer functions, read-only guarantee is enforced by code structure
- **Validation**: Code review verifies no index writer calls in detection code path, integration test verifies detection never modifies `index.json`

### Task 4.4: Add Fallback Reason Reporting
**Priority**: P1
- **Objective**: Report fallback reason in detection output (human-readable and JSON) when index is missing/invalid
- **Deliverable**: Fallback reason tracking and reporting in detection results
- **Files**: `Sources/MediaHub/DetectionOrchestration.swift`, `Sources/MediaHub/DetectionResult.swift`
- **Dependencies**: Task 4.1
- **Acceptance**: Detection tracks fallback reason (`missing`, `corrupted`, `invalid_version`), adds `indexUsed: Bool` and `indexFallbackReason: String?` to `DetectionResult`, reports in output
- **Validation**: Integration test verifies fallback reason is reported, JSON output includes `indexUsed` and `indexFallbackReason` fields

### Task 4.5: Verify Identical Results with and without Index
**Priority**: P1
- **Objective**: Ensure index-based detection produces identical results to full-scan detection (100% accuracy)
- **Deliverable**: Tests that verify identical results
- **Files**: `Tests/MediaHubTests/DetectionOrchestrationTests.swift` (modify)
- **Dependencies**: Task 4.1, Task 4.2
- **Acceptance**: Tests run detection with and without index on same library, verify results are identical (same candidates, same comparison results)
- **Validation**: Integration test verifies identical results with and without index

### Task 4.6: Add Detection Index Integration Tests
**Priority**: P1
- **Objective**: Add integration tests for index usage in detection (read-only, fallback, identical results, fallback reason reporting)
- **Deliverable**: Test suite covering detection index integration
- **Files**: `Tests/MediaHubTests/DetectionOrchestrationTests.swift` (modify)
- **Dependencies**: Task 4.1 through Task 4.5
- **Acceptance**: Tests cover index usage in detection, fallback behavior, read-only guarantee, identical results, fallback reason reporting
- **Validation**: `swift test --filter DetectionOrchestrationTests` passes

---

## Component 5: Index Information in Status

**Plan Reference**: Component 5 (lines 277-310)  
**Dependencies**: Component 1 (BaselineIndex core)

### Task 5.1: Add Index Check to Status Command
**Priority**: P1
- **Objective**: Check if index exists and is valid in status command
- **Deliverable**: Index check logic in status workflow
- **Files**: `Sources/MediaHubCLI/StatusCommand.swift`
- **Dependencies**: Component 1 (all tasks)
- **Acceptance**: Status checks index using `IndexValidator`, extracts metadata (version, entry count, last update time) if index exists
- **Validation**: Integration test verifies status checks index, extracts metadata

### Task 5.2: Format Index Information for Human-Readable Output
**Priority**: P1
- **Objective**: Format index information for human-readable status output (presence, version, entry count, last update time)
- **Deliverable**: Human-readable index information formatting
- **Files**: `Sources/MediaHubCLI/StatusCommand.swift`
- **Dependencies**: Task 5.1
- **Acceptance**: Status displays index information in clear format (presence, version, entry count, last update time), handles missing/invalid index gracefully (reports clearly, not an error)
- **Validation**: Integration test verifies human-readable output includes index information, missing index is reported clearly

### Task 5.3: Format Index Information for JSON Output
**Priority**: P1
- **Objective**: Format index information for JSON status output (backward compatible: add index fields without breaking existing schema)
- **Deliverable**: JSON output with index metadata (`index.present`, `index.version`, `index.entryCount`, `index.lastUpdated`, `index.valid`)
- **Files**: `Sources/MediaHubCLI/StatusCommand.swift`
- **Dependencies**: Task 5.1
- **Acceptance**: JSON output includes index fields, existing fields unchanged (backward compatible), missing/invalid index is reported with `index.present: false` or `index.valid: false`
- **Validation**: Integration test verifies JSON output includes index fields, backward compatible (existing fields unchanged)

### Task 5.4: Add Status Index Integration Tests
**Priority**: P1
- **Objective**: Add integration tests for index information in status output (human-readable and JSON)
- **Deliverable**: Test suite covering status index integration
- **Files**: `Tests/MediaHubTests/StatusCommandTests.swift` (new or modify)
- **Dependencies**: Task 5.1 through Task 5.3
- **Acceptance**: Tests cover index information in status output, human-readable and JSON formats, missing/invalid index handling
- **Validation**: `swift test --filter StatusCommandTests` passes

---

## Component 6: Tests and Validation

**Plan Reference**: Component 6 (lines 312-390)  
**Dependencies**: All previous components

### Task 6.1: Add Comprehensive Unit Tests
**Priority**: P1
- **Objective**: Add comprehensive unit tests for all core index operations (reader, writer, validator, path normalization, deterministic encoding, atomic writes, path validation)
- **Deliverable**: Complete unit test suite for baseline index core
- **Files**: `Tests/MediaHubTests/BaselineIndexTests.swift`
- **Dependencies**: Component 1 (all tasks)
- **Acceptance**: Unit tests cover all core index operations, all tests pass
- **Validation**: `swift test --filter BaselineIndexTests` passes

### Task 6.2: Add Integration Tests for Adoption Index
**Priority**: P1
- **Objective**: Add integration tests for index creation during adoption (idempotent, dry-run, failure handling)
- **Deliverable**: Integration test suite for adoption index
- **Files**: `Tests/MediaHubTests/LibraryAdoptionTests.swift` (modify)
- **Dependencies**: Component 2 (all tasks)
- **Acceptance**: Integration tests cover adoption index creation, idempotent behavior, dry-run, failure handling, all tests pass
- **Validation**: `swift test --filter LibraryAdoptionTests` passes

### Task 6.3: Add Integration Tests for Import Index
**Priority**: P1
- **Objective**: Add integration tests for index usage and updates during import (incremental updates, batched updates, dry-run, failure handling)
- **Deliverable**: Integration test suite for import index
- **Files**: `Tests/MediaHubTests/ImportExecutionTests.swift` (modify)
- **Dependencies**: Component 3 (all tasks)
- **Acceptance**: Integration tests cover import index usage, incremental updates, batched updates, dry-run, failure handling, all tests pass
- **Validation**: `swift test --filter ImportExecutionTests` passes

### Task 6.4: Add Integration Tests for Detection Index
**Priority**: P1
- **Objective**: Add integration tests for index usage in detection (read-only, fallback, identical results, fallback reason reporting)
- **Deliverable**: Integration test suite for detection index
- **Files**: `Tests/MediaHubTests/DetectionOrchestrationTests.swift` (modify)
- **Dependencies**: Component 4 (all tasks)
- **Acceptance**: Integration tests cover detection index usage, read-only guarantee, fallback behavior, identical results, fallback reason reporting, all tests pass
- **Validation**: `swift test --filter DetectionOrchestrationTests` passes

### Task 6.5: Add Integration Tests for Status Index
**Priority**: P1
- **Objective**: Add integration tests for index information in status output (human-readable and JSON)
- **Deliverable**: Integration test suite for status index
- **Files**: `Tests/MediaHubTests/StatusCommandTests.swift` (new or modify)
- **Dependencies**: Component 5 (all tasks)
- **Acceptance**: Integration tests cover status index information, human-readable and JSON formats, missing/invalid index handling, all tests pass
- **Validation**: `swift test --filter StatusCommandTests` passes

### Task 6.6: Verify Non-Regression
**Priority**: P1
- **Objective**: Ensure all existing tests still pass after index implementation (no regression)
- **Deliverable**: All existing tests pass
- **Files**: All test files
- **Dependencies**: All previous tasks
- **Acceptance**: All existing tests pass, no breaking changes to existing functionality
- **Validation**: `swift test` passes (all tests), `scripts/smoke_cli.sh` passes

### Task 6.7: Add Performance Tests (Optional/Non-Blocking)
**Priority**: P2 (optional, non-blocking)
- **Objective**: Add performance tests for index operations (load, write, detection speedup) — optional, non-blocking, run locally, not in CI
- **Deliverable**: Performance test suite (optional)
- **Files**: `Tests/MediaHubTests/BaselineIndexPerformanceTests.swift` (new, optional)
- **Dependencies**: All previous tasks
- **Acceptance**: Performance tests measure index load/write time relative to full-scan time, detection speedup >=5x on 10k+ files (indicative, not contractual), tests are optional and non-blocking
- **Validation**: Performance tests run locally (not in CI), measure relative performance on same dataset and machine

---

## Implementation Notes

### Atomic Write Pattern (Reuse AtomicFileCopy)

**Strategy**: Reuse write-then-rename pattern from `AtomicFileCopy`

**Implementation**:
- Create temporary file in same directory as target (`.mediahub/registry/.index.json.mediahub-tmp-{UUID}`)
- Write JSON content to temporary file
- Verify write integrity (file exists, size matches)
- Atomically rename temporary file to final destination using `FileManager.moveItem()`
- Cleanup temporary file on failure (if rename fails, remove temp file)

### Path Normalization

**Strategy**: Relative paths from library root, resolved symlinks, consistent separators

**Implementation**:
- Use `URL.resolvingSymlinksInPath()` to resolve symlinks
- Convert absolute paths to relative paths (relative to library root)
- Use consistent path separators (`/` on all platforms)
- Store normalized paths in index entries

### Deterministic JSON Encoding

**Strategy**: Sort entries by normalized path, use stable JSON encoder options (documented)

**Implementation**:
- Sort index entries by normalized path before encoding (deterministic order)
- Use `JSONEncoder` with stable options (documented in code comments)
- Determinism achieved through sorted entries and normalized paths, not through key order
- Key order is not a contract (JSON spec does not guarantee key order)

### Registry Directory Creation

**Strategy**: Ensure `.mediahub/registry/` directory exists before writing index

**Implementation**:
- Check if `.mediahub/registry/` exists before writing index
- Create directory if missing using `FileManager.createDirectory()` with intermediate directories
- Handle directory creation failures gracefully

---

**Last Updated**: 2026-01-27  
**Next Review**: After implementation or after real-world usage
