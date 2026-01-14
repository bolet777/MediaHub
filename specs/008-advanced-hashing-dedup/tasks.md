# Implementation Tasks: Advanced Hashing & Deduplication (Slice 8)

**Feature**: Advanced Hashing & Deduplication
**Specification**: `specs/008-advanced-hashing-dedup/spec.md`
**Plan**: `specs/008-advanced-hashing-dedup/plan.md`
**Slice**: 8 - Advanced Hashing & Deduplication
**Created**: 2026-01-14

## Task Organization

Tasks are organized by component and follow the implementation sequence defined in the plan. Each task is:
- Small and focused on a single deliverable
- Sequential (dependencies are clear)
- Traceable to plan components (referenced by component number)
- Traceable to success criteria (SC-XXX from spec)
- Includes explicit dry-run behavior where applicable

## NON-NEGOTIABLE CONSTRAINTS FOR SLICE 8

**CRITICAL**: The following constraints MUST be followed during Slice 8 implementation:

1. **Code Location**:
   - Core hashing implementation MUST be in `Sources/MediaHub/ContentHashing.swift` (new file)
   - Index extension MUST be in `Sources/MediaHub/BaselineIndex.swift` (modify existing)
   - CLI changes MUST be minimal (detect output, status output, JSON formatting)
   - Tests MUST be in `Tests/MediaHubTests/` (new `ContentHashingTests.swift`, extend existing)

2. **Hash Computation Safety**:
   - Hash computation MUST be read-only (never modify source files)
   - Hash computation MUST use streaming (constant memory regardless of file size)
   - Symlinks MUST be validated: resolve target, verify within allowed root, throw if outside
   - Hash computation failures MUST NOT cause operations to fail (hash is optional)

3. **Dry-Run Guarantees**:
   - `detect --dry-run`: ALLOWS hash computation (read-only, enables duplicate detection preview)
   - `import --dry-run`: ZERO hash computations (preview only, no file I/O for hashing)
   - `adopt --dry-run`: ZERO hash computations (even with `--with-hashes` flag)
   - All dry-run modes: ZERO writes to index

4. **Import Behavior**:
   - Import does NOT hash source files (that is `detect`'s responsibility)
   - Import hashes destination files ONLY (after successful copy)
   - Import uses path-based known-items filtering only (no hash-based dedup in import)

5. **Index v1.1 Migration**:
   - v1.0 indexes MUST remain valid and readable (backward compatibility)
   - Hash field MUST be optional (entries without hash are valid)
   - Version auto-upgrade to "1.1" when writing indexes with hash data
   - JSON encoding MUST omit nil hash fields (deterministic)

6. **Backward Compatibility**:
   - NO breaking changes to existing CLI behavior
   - JSON output MUST be backward compatible (add fields, don't modify existing)
   - All existing tests MUST still pass after implementation
   - Path-based detection MUST continue to work alongside hash-based detection

---

## Component 1: Content Hashing Core

**Plan Reference**: Component 1 (lines 42-99)
**Dependencies**: CryptoKit (imported alongside Foundation)
**Success Criteria**: SC-001, SC-005, SC-007, SC-008, SC-011, SC-016, SC-018

### Task 1.1: Create ContentHashing.swift File Structure
**Priority**: P1
- **Objective**: Create new `ContentHashing.swift` file with `ContentHasher` struct, `ContentHashError` enum
- **Deliverable**: New file with struct/enum definitions
- **Files**: `Sources/MediaHub/ContentHashing.swift`
- **Dependencies**: None
- **Acceptance**: File compiles, `ContentHasher` struct defined, `ContentHashError` enum includes: `fileNotFound`, `permissionDenied`, `ioError`, `computationFailed`, `symlinkOutsideRoot`
- **Validation**: `swift build` succeeds

### Task 1.2: Implement Streaming SHA-256 Hash Computation
**Priority**: P1
- **Objective**: Implement `computeHash(for:allowedRoot:) throws -> String` using CryptoKit SHA256 with streaming file reads (64KB chunks)
- **Deliverable**: Method that computes SHA-256 hash with constant memory usage
- **Files**: `Sources/MediaHub/ContentHashing.swift`
- **Dependencies**: Task 1.1
- **Acceptance**: Method reads file in 64KB chunks, updates SHA256 incrementally, returns hash in format `sha256:<hexdigest>` (64 hex chars), throws `ContentHashError` on failure
- **Validation**: Unit test computes hash of known test vector, verifies format and correctness

### Task 1.3: Implement Symlink Safety Validation
**Priority**: P1
- **Objective**: Add symlink validation that resolves symlinks and verifies target is within allowed root directory
- **Deliverable**: Symlink resolution and validation logic in `computeHash`
- **Files**: `Sources/MediaHub/ContentHashing.swift`
- **Dependencies**: Task 1.2
- **Acceptance**: Method resolves symlinks using `URL.resolvingSymlinksInPath()`, validates resolved path is within `allowedRoot`, throws `symlinkOutsideRoot` if target is outside root
- **Validation**: Unit test verifies symlink within root resolves and hashes target; symlink outside root throws error

### Task 1.4: Implement Error Handling for Hash Computation
**Priority**: P1
- **Objective**: Implement graceful error handling for all hash computation failure modes (file not found, permission denied, I/O errors)
- **Deliverable**: Complete error handling in `computeHash`
- **Files**: `Sources/MediaHub/ContentHashing.swift`
- **Dependencies**: Task 1.2
- **Acceptance**: Method throws appropriate `ContentHashError` for each failure mode, errors include context (file path, underlying error)
- **Validation**: Unit tests verify correct errors thrown for missing file, permission denied scenarios

### Task 1.5: Add Content Hashing Unit Tests
**Priority**: P1
- **Objective**: Add comprehensive unit tests for hash computation (correctness, determinism, streaming, error handling, symlink safety)
- **Deliverable**: Test suite covering all hash computation scenarios
- **Files**: `Tests/MediaHubTests/ContentHashingTests.swift` (new)
- **Dependencies**: Tasks 1.1-1.4
- **Acceptance**: Tests verify:
  - Correct SHA-256 output for known test vectors (empty file, "hello world\n", binary data)
  - Deterministic output (same file = same hash)
  - Hash format is correct (`sha256:` prefix + 64 hex chars)
  - Error handling (missing file throws, permission denied throws)
  - Symlink safety (within root resolves, outside root throws)
- **Validation**: `swift test --filter ContentHashingTests` passes

---

## Component 2: Baseline Index v1.1 Extension

**Plan Reference**: Component 2 (lines 102-158)
**Dependencies**: Component 1, existing `BaselineIndex.swift`
**Success Criteria**: SC-010, SC-017

### Task 2.1: Add Optional Hash Field to IndexEntry
**Priority**: P1
- **Objective**: Extend `IndexEntry` struct with optional `hash: String?` field
- **Deliverable**: Updated `IndexEntry` with hash field, Codable conformance
- **Files**: `Sources/MediaHub/BaselineIndex.swift`
- **Dependencies**: None
- **Acceptance**: `IndexEntry` has `hash: String?` field, JSON encoding omits nil hash fields (uses `encodeIfPresent`), existing indexes without hash load correctly
- **Validation**: Unit test creates entry with/without hash, verifies JSON encoding/decoding

### Task 2.2: Implement Index Version Handling for v1.1
**Priority**: P1
- **Objective**: Update version handling to read "1.0"/"1.1", write "1.1" when any entry has hash data
- **Deliverable**: Version detection and auto-upgrade logic
- **Files**: `Sources/MediaHub/BaselineIndex.swift`
- **Dependencies**: Task 2.1
- **Acceptance**: Reader accepts version "1.0" and "1.1", writer sets version to "1.1" if any entry has hash, "1.0" if no entries have hashes
- **Validation**: Unit test verifies v1.0 loads correctly, v1.1 loads correctly, version auto-upgrade on write

### Task 2.3: Implement Hash-to-Path Lookup
**Priority**: P1
- **Objective**: Add computed property `hashToAnyPath: [String: String]` for mapping a content hash to a representative library path (for duplicate reporting)
- **Deliverable**: Hash-to-path lookup computed property
- **Files**: `Sources/MediaHub/BaselineIndex.swift`
- **Dependencies**: Task 2.1
- **Acceptance**: Property iterates entries with non-nil hashes and builds a dictionary keyed by hash; for hashes that appear multiple times, keep the first encountered path deterministically (stable iteration order). Skips entries without hashes.
- **Validation**: Unit test verifies mapping for unique hashes and deterministic choice for collisions

### Task 2.4: Implement Hash Set for Duplicate Detection
**Priority**: P1
- **Objective**: Add computed property `hashSet: Set<String>` that collects all hashes for O(1) duplicate detection
- **Deliverable**: Hash set computed property
- **Files**: `Sources/MediaHub/BaselineIndex.swift`
- **Dependencies**: Task 2.1
- **Acceptance**: Property collects all non-nil hashes into a Set for O(1) membership checks during duplicate detection
- **Validation**: Unit test verifies set construction, membership check performance

### Task 2.5: Add Index v1.1 Unit Tests
**Priority**: P1
- **Objective**: Add unit tests for index v1.1 features (hash field, version handling, hash lookup, hash set)
- **Deliverable**: Test suite covering index v1.1 functionality
- **Files**: `Tests/MediaHubTests/BaselineIndexTests.swift` (extend)
- **Dependencies**: Tasks 2.1-2.4
- **Acceptance**: Tests verify:
  - v1.0 indexes load correctly (backward compatible)
  - v1.1 indexes load correctly (hash field parsed)
  - Optional hash field (nil hash is valid)
  - Version auto-upgrade (v1.0 -> v1.1 on hash write)
  - JSON encoding omits nil hash fields
  - Hash lookup dictionary is O(1)
  - Hash set construction is correct
- **Validation**: `swift test --filter BaselineIndexTests` passes

---

## Component 3: Hash Computation in Import

**Plan Reference**: Component 3 (lines 161-215)
**Dependencies**: Components 1, 2
**Success Criteria**: SC-001, SC-006, SC-007, SC-011, SC-015

### Task 3.1: Add Hash Computation After File Copy
**Priority**: P1
- **Objective**: Compute hash for each file AFTER successful copy (hash destination file, not source)
- **Deliverable**: Hash computation step integrated into import workflow
- **Files**: `Sources/MediaHub/ImportExecution.swift`
- **Dependencies**: Component 1 (all tasks)
- **Acceptance**: After file copy succeeds, compute hash of destination file, catch errors and omit hash on failure (log warning, continue import), create `IndexEntry` with hash field populated (or nil if failed)
- **Validation**: Integration test imports files, verifies index entries have hash field

### Task 3.2: Implement Graceful Hash Failure Handling in Import
**Priority**: P1
- **Objective**: Ensure hash computation failures do not cause import to fail (hash is optional)
- **Deliverable**: Error handling that logs failures but continues import
- **Files**: `Sources/MediaHub/ImportExecution.swift`
- **Dependencies**: Task 3.1
- **Acceptance**: If hash computation throws, log warning with file path and error, set hash to nil in index entry, continue import, import succeeds even if all hashes fail
- **Validation**: Integration test simulates hash failure, verifies import succeeds, warning logged

### Task 3.3: Skip Hash Computation in Import Dry-Run
**Priority**: P1
- **Objective**: Ensure `import --dry-run` performs zero hash computations (preview only)
- **Deliverable**: Dry-run check that skips hash computation entirely
- **Files**: `Sources/MediaHub/ImportExecution.swift`
- **Dependencies**: Task 3.1
- **Acceptance**: In dry-run mode, skip file copy AND hash computation, show preview "Would import N files, would compute hashes for N imported files", zero file I/O for hashing
- **Validation**: Integration test verifies dry-run skips hash computation, no file reads for hashing

### Task 3.4: Update Index with Hash Data (Atomic Write)
**Priority**: P1
- **Objective**: Update baseline index with hash data for imported files using existing atomic write pattern
- **Deliverable**: Index update includes hash fields for newly imported files
- **Files**: `Sources/MediaHub/ImportExecution.swift`
- **Dependencies**: Tasks 3.1, 2.2
- **Acceptance**: Index entries for imported files include hash field, version upgraded to "1.1" if needed, atomic write-then-rename pattern, existing entries without hash preserved
- **Validation**: Integration test verifies index has hash data after import, version is "1.1"

### Task 3.5: Add Import Hash Integration Tests
**Priority**: P1
- **Objective**: Add integration tests for hash computation during import (success, failure, dry-run)
- **Deliverable**: Test suite covering import hash integration
- **Files**: `Tests/MediaHubTests/ImportExecutionTests.swift` (extend)
- **Dependencies**: Tasks 3.1-3.4
- **Acceptance**: Tests verify:
  - Hashes computed for imported files (index entries have hash field)
  - Hash computed from destination file (not source)
  - Hash computation failure does not fail import
  - Dry-run skips hash computation entirely (zero hash computations)
  - Index entries include hash field after import
- **Validation**: `swift test --filter ImportExecutionTests` passes

---

## Component 4: Hash-Based Duplicate Detection in Detect

**Plan Reference**: Component 4 (lines 218-281)
**Dependencies**: Components 1, 2
**Success Criteria**: SC-003, SC-004, SC-006, SC-009, SC-012, SC-019

### Task 4.1: Load Library Hash Set for Detection
**Priority**: P1
- **Objective**: Load library baseline index and extract hash set for O(1) duplicate detection
- **Deliverable**: Hash set loading at start of detection
- **Files**: `Sources/MediaHub/DetectionOrchestration.swift`
- **Dependencies**: Component 2 (Task 2.4)
- **Acceptance**: Detection loads index, extracts `hashSet` if available, tracks hash coverage (entries with hash / total entries), graceful degradation if no hashes (hash set is empty)
- **Validation**: Integration test verifies hash set loaded from index

### Task 4.2: Compute Hashes for Source Files During Detection
**Priority**: P1
- **Objective**: Compute hash for each source file candidate (streaming, constant memory)
- **Deliverable**: Source file hash computation in detection workflow
- **Files**: `Sources/MediaHub/DetectionOrchestration.swift`
- **Dependencies**: Component 1 (all tasks)
- **Acceptance**: For each source candidate, compute hash using `ContentHasher`, catch errors and classify as "new" on failure (conservative), hashes computed for all source files
- **Validation**: Integration test verifies source files are hashed during detection

### Task 4.3: Implement Hash-Based Duplicate Detection
**Priority**: P1
- **Objective**: Compare source file hashes against library hash set, identify duplicates by hash match
- **Deliverable**: Hash comparison logic that identifies duplicates
- **Files**: `Sources/MediaHub/DetectionOrchestration.swift`
- **Dependencies**: Tasks 4.1, 4.2
- **Acceptance**: If source hash exists in library hash set, mark as duplicate (reported as duplicate in results; excluded from the "to import" candidate set), track duplicate relationship (hash, library path if available), path-based and hash-based detection work together (union of exclusions)
- **Validation**: Integration test verifies duplicates identified by hash match

### Task 4.4: Implement Graceful Degradation for Detection
**Priority**: P1
- **Objective**: Fall back to path-based detection only when library has no hash data
- **Deliverable**: Graceful degradation logic with clear reporting
- **Files**: `Sources/MediaHub/DetectionOrchestration.swift`
- **Dependencies**: Task 4.1
- **Acceptance**: If library index has no hashes (empty hash set), skip hash-based detection, use path-based only, report "Hash-based deduplication not available" in output, operation succeeds (no failure)
- **Validation**: Integration test verifies graceful degradation, clear message reported

### Task 4.5: Allow Hash Computation in Detect Dry-Run
**Priority**: P1
- **Objective**: Ensure `detect --dry-run` allows hash computation (read-only operation)
- **Deliverable**: Dry-run behavior that computes hashes for preview
- **Files**: `Sources/MediaHub/DetectionOrchestration.swift`
- **Dependencies**: Task 4.2
- **Acceptance**: In dry-run mode, hash computation for source files is ALLOWED (read-only), hash-based duplicate detection works in dry-run, zero writes (detection is always read-only)
- **Validation**: Integration test verifies detect dry-run computes hashes, shows duplicate detection results

### Task 4.6: Ensure Detection is Read-Only
**Priority**: P1
- **Objective**: Ensure detection never creates or modifies index (read-only guarantee)
- **Deliverable**: Code structure that enforces read-only guarantee
- **Files**: `Sources/MediaHub/DetectionOrchestration.swift`
- **Dependencies**: Tasks 4.1-4.5
- **Acceptance**: Detection code path only reads index, never calls index writer, source file hashes are computed on-the-fly (not stored)
- **Validation**: Integration test verifies detection never modifies index file

### Task 4.7: Update Detection Result with Duplicate Metadata
**Priority**: P1
- **Objective**: Add duplicate metadata fields to detection result (`duplicateOfHash`, `duplicateOfLibraryPath`, `duplicateReason`, `hashCoverage`)
- **Deliverable**: Extended `DetectionResult` with duplicate information
- **Files**: `Sources/MediaHub/DetectionResult.swift`
- **Dependencies**: Task 4.3
- **Acceptance**: `DetectionResult` includes:
  - `duplicateOfHash: String?` (hash of duplicate)
  - `duplicateOfLibraryPath: String?` (library path of duplicate, if available)
  - `duplicateReason: String?` ("content_hash" or "path_match")
  - `hashCoverage: Double?` (percentage of library files with hashes)
- **Validation**: Unit test verifies detection result includes duplicate metadata

### Task 4.8: Add Detection Hash Integration Tests
**Priority**: P1
- **Objective**: Add integration tests for hash-based duplicate detection (success, graceful degradation, dry-run)
- **Deliverable**: Test suite covering detection hash integration
- **Files**: `Tests/MediaHubTests/DetectionOrchestrationTests.swift` (extend)
- **Dependencies**: Tasks 4.1-4.7
- **Acceptance**: Tests verify:
  - Source files hashed during detection
  - Duplicates identified by hash match (different path, same hash)
  - Path-based and hash-based work together (both exclusions apply)
  - Detection is read-only (index not modified)
  - Dry-run allows hash computation (read-only)
  - Graceful degradation (no library hashes = path-based only)
  - Determinism (same inputs = same detection results)
- **Validation**: `swift test --filter DetectionOrchestrationTests` passes

---

## Component 5: Optional Hash Computation in Adoption (--with-hashes)

**Plan Reference**: Component 5 (lines 284-344)
**Dependencies**: Components 1, 2
**Success Criteria**: SC-002, SC-006, SC-011, SC-020

### Task 5.1: Add --with-hashes Flag to Adopt Command
**Priority**: P1
- **Objective**: Add `--with-hashes` flag to `library adopt` command (default: false)
- **Deliverable**: CLI flag definition and parsing
- **Files**: `Sources/MediaHubCLI/LibraryCommands.swift`
- **Dependencies**: None
- **Acceptance**: `--with-hashes` flag defined, default is false, help text includes performance warning for large libraries
- **Validation**: CLI help shows `--with-hashes` flag with description

### Task 5.2: Pass --with-hashes Flag to Adoption Workflow
**Priority**: P1
- **Objective**: Pass `withHashes` parameter from CLI to adoption workflow
- **Deliverable**: Parameter flow from CLI to adoption logic
- **Files**: `Sources/MediaHubCLI/LibraryCommands.swift`, `Sources/MediaHub/LibraryAdoption.swift`
- **Dependencies**: Task 5.1
- **Acceptance**: `LibraryAdoption` accepts `withHashes: Bool` parameter, default is false
- **Validation**: Unit test verifies parameter is passed correctly

### Task 5.3: Implement Hash Computation During Adoption
**Priority**: P1
- **Objective**: When `--with-hashes` is set, compute hash for each existing media file during baseline scan
- **Deliverable**: Hash computation integrated into adoption workflow
- **Files**: `Sources/MediaHub/LibraryAdoption.swift`
- **Dependencies**: Task 5.2, Component 1
- **Acceptance**: When flag is true, compute hash for each file in baseline scan, catch errors and omit hash on failure (log warning, continue), create index entries with hash field populated
- **Validation**: Integration test adopts with `--with-hashes`, verifies index has hashes

### Task 5.4: Implement Idempotent Hash Computation in Adoption
**Priority**: P1
- **Objective**: Do not re-compute hashes for files that already have hashes in index (idempotent)
- **Deliverable**: Idempotent check before hash computation
- **Files**: `Sources/MediaHub/LibraryAdoption.swift`
- **Dependencies**: Task 5.3
- **Acceptance**: On re-adoption with `--with-hashes`, check if entry already has hash, skip hash computation for files with existing hashes, only compute for files without hashes
- **Validation**: Integration test verifies idempotent adoption does not re-hash

### Task 5.5: Skip Hash Computation in Adopt Dry-Run
**Priority**: P1
- **Objective**: Ensure `adopt --dry-run` skips hash computation (even with `--with-hashes`)
- **Deliverable**: Dry-run check that skips hash computation
- **Files**: `Sources/MediaHub/LibraryAdoption.swift`
- **Dependencies**: Task 5.3
- **Acceptance**: In dry-run mode, skip hash computation even if `--with-hashes` is set, show preview "Would compute hashes for N files", zero file I/O for hashing
- **Validation**: Integration test verifies dry-run skips hash computation with `--with-hashes`

### Task 5.6: Handle Hash Failures Gracefully in Adoption
**Priority**: P1
- **Objective**: Ensure hash computation failures do not cause adoption to fail (hash is optional)
- **Deliverable**: Error handling that logs failures but continues adoption
- **Files**: `Sources/MediaHub/LibraryAdoption.swift`
- **Dependencies**: Task 5.3
- **Acceptance**: If hash computation throws, log warning with file path and error, set hash to nil in index entry, continue adoption, adoption succeeds even if all hashes fail
- **Validation**: Integration test simulates hash failure, verifies adoption succeeds

### Task 5.7: Add Adoption Hash Integration Tests
**Priority**: P1
- **Objective**: Add integration tests for optional hash computation during adoption
- **Deliverable**: Test suite covering adoption hash integration
- **Files**: `Tests/MediaHubTests/LibraryAdoptionTests.swift` (extend)
- **Dependencies**: Tasks 5.1-5.6
- **Acceptance**: Tests verify:
  - Default adoption does not compute hashes
  - `--with-hashes` triggers hash computation
  - Idempotent adoption does not re-hash existing
  - Hash computation failure does not fail adoption
  - Dry-run skips hash computation (even with `--with-hashes`)
- **Validation**: `swift test --filter LibraryAdoptionTests` passes

---

## Component 6: CLI Output Enhancement

**Plan Reference**: Component 6 (lines 347-402)
**Dependencies**: Components 3, 4
**Success Criteria**: SC-013, SC-014

### Task 6.1: Format Hash-Based Duplicate Information in Detect Output
**Priority**: P1
- **Objective**: Display hash-based duplicate information in human-readable detect output
- **Deliverable**: Formatted duplicate information in CLI output
- **Files**: `Sources/MediaHubCLI/DetectCommand.swift`
- **Dependencies**: Component 4 (Task 4.7)
- **Acceptance**: Output shows "File X is duplicate of library file Y (hash: abc123...)" for hash-based duplicates, distinguishes between path-based known items and hash-based duplicates
- **Validation**: Manual test verifies human-readable output format

### Task 6.2: Add Duplicate Metadata to Detect JSON Output
**Priority**: P1
- **Objective**: Include duplicate metadata in JSON detect output (backward compatible)
- **Deliverable**: JSON output with duplicate fields
- **Files**: `Sources/MediaHubCLI/DetectCommand.swift`
- **Dependencies**: Task 6.1
- **Acceptance**: JSON output includes `duplicateOfHash`, `duplicateOfLibraryPath`, `duplicateReason`, `hashCoverage` fields, existing fields unchanged (backward compatible)
- **Validation**: Integration test verifies JSON output includes duplicate metadata

### Task 6.3: Add Hash Index Statistics to Status Output
**Priority**: P1
- **Objective**: Display hash index statistics in status command output (human-readable and JSON)
- **Deliverable**: Hash statistics in status output
- **Files**: `Sources/MediaHubCLI/StatusCommand.swift`
- **Dependencies**: Component 2
- **Acceptance**: Status output shows "Hash index: X entries, Y% coverage", JSON output includes `hashEntryCount` and `hashCoverage` fields, handles libraries without hashes gracefully
- **Validation**: Integration test verifies status output includes hash statistics

### Task 6.4: Report Graceful Degradation in Output
**Priority**: P1
- **Objective**: Clearly report when hash-based deduplication is not available (fallback to path-based)
- **Deliverable**: Fallback message in detect output
- **Files**: `Sources/MediaHubCLI/DetectCommand.swift`
- **Dependencies**: Component 4 (Task 4.4)
- **Acceptance**: When library has no hash data, output shows "Hash-based deduplication not available (no hash data in library)", JSON includes `hashBasedDeduplicationAvailable: false`
- **Validation**: Integration test verifies fallback message displayed

### Task 6.5: Add CLI Output Integration Tests
**Priority**: P1
- **Objective**: Add integration tests for CLI output (detect output, status output, JSON format)
- **Deliverable**: Test suite covering CLI output
- **Files**: `Tests/MediaHubTests/` (appropriate test files)
- **Dependencies**: Tasks 6.1-6.4
- **Acceptance**: Tests verify:
  - Hash-based duplicates displayed in detect output
  - JSON output includes duplicate metadata
  - Path-based and hash-based duplicates distinguished
  - Status output includes hash statistics
  - Fallback to path-based is clearly reported
  - JSON output is backward compatible
- **Validation**: `swift test` passes for CLI output tests

---

## Component 7: Final Validation and Non-Regression

**Plan Reference**: Component 7 (lines 405-489)
**Dependencies**: All previous components
**Success Criteria**: SC-015 (all existing tests pass)

### Task 7.1: Verify Non-Regression
**Priority**: P1
- **Objective**: Ensure all existing tests still pass after Slice 8 implementation
- **Deliverable**: All existing tests pass
- **Files**: All test files
- **Dependencies**: All previous tasks
- **Acceptance**: All existing tests pass, no breaking changes to existing functionality
- **Validation**: `swift test` passes (all tests)

### Task 7.2: Run CLI Smoke Tests
**Priority**: P1
- **Objective**: Run CLI smoke tests to verify end-to-end functionality
- **Deliverable**: Smoke tests pass
- **Files**: `scripts/smoke_cli.sh`
- **Dependencies**: Task 7.1
- **Acceptance**: CLI smoke tests pass with hash feature
- **Validation**: `scripts/smoke_cli.sh` passes

### Task 7.3: Add Performance Tests (Optional/Non-Blocking)
**Priority**: P2 (optional, non-blocking)
- **Objective**: Add performance tests for hash computation (throughput, memory usage, import overhead)
- **Deliverable**: Performance test suite (optional)
- **Files**: `Tests/MediaHubTests/ContentHashingPerformanceTests.swift` (new, optional)
- **Dependencies**: All previous tasks
- **Acceptance**: Performance tests measure:
  - Hash throughput (MB/s)
  - Memory usage for large files (constant, <100MB for 1GB file)
  - Import overhead with hashing (<10% target)
- **Validation**: Performance tests run locally (not in CI), measure indicative performance

### Task 7.4: Manual Validation of Hash Feature
**Priority**: P1
- **Objective**: Manual testing of hash feature end-to-end (detection, import, adoption, status)
- **Deliverable**: Manual validation completed
- **Files**: N/A (manual testing)
- **Dependencies**: All previous tasks
- **Acceptance**: Manual verification of:
  - Hash-based duplicate detection works correctly
  - Dry-run behavior is correct (detect allows hashing, import/adopt skip hashing)
  - Graceful degradation when hash data unavailable
  - Backward compatibility (v1.0 indexes work correctly)
  - Hash computation handles large files
- **Validation**: Manual testing checklist completed

---

## Implementation Sequence Summary

**Phase 1: Core Infrastructure** (Tasks 1.1-1.5, 2.1-2.5)
- ContentHashing.swift (streaming SHA-256, symlink safety)
- BaselineIndex v1.1 (hash field, version handling, hash lookup/set)

**Phase 2: Import Integration** (Tasks 3.1-3.5)
- Hash destination files after copy
- Skip hashing in dry-run
- Graceful failure handling

**Phase 3: Detection Integration** (Tasks 4.1-4.8)
- Hash source files during detection
- Hash-based duplicate detection
- Graceful degradation
- Allow hashing in dry-run

**Phase 4: Adoption Integration** (Tasks 5.1-5.7)
- `--with-hashes` flag
- Optional hash computation
- Skip hashing in dry-run

**Phase 5: CLI Output** (Tasks 6.1-6.5)
- Duplicate information in detect output
- Hash statistics in status output
- JSON backward compatibility

**Phase 6: Validation** (Tasks 7.1-7.4)
- Non-regression testing
- Smoke tests
- Performance tests (optional)
- Manual validation

---

## Success Criteria Mapping

| Success Criteria | Tasks |
|-----------------|-------|
| SC-001 (hashes in import) | 3.1, 3.4 |
| SC-002 (hashes in adopt) | 5.3, 5.4 |
| SC-003 (duplicate detection) | 4.3 |
| SC-004 (deterministic) | 4.8 |
| SC-005 (idempotent) | 5.4 |
| SC-006 (dry-run) | 3.3, 4.5, 5.5 |
| SC-007 (performance) | 7.3 |
| SC-008 (large files) | 1.2, 7.3 |
| SC-009 (path+hash together) | 4.3 |
| SC-010 (backward compat) | 2.2, 2.5 |
| SC-011 (failure handling) | 3.2, 5.6 |
| SC-012 (graceful degradation) | 4.4 |
| SC-013 (CLI output) | 6.1, 6.2 |
| SC-014 (status output) | 6.3 |
| SC-015 (non-regression) | 7.1 |
| SC-016 (deterministic hash) | 1.5 |
| SC-017 (atomic write) | 3.4 |
| SC-018 (read-only hash) | 1.3, 4.6 |
| SC-019 (cross-source dedup) | 4.3 |
| SC-020 (adopt performance) | 5.3, 7.3 |

---

**Last Updated**: 2026-01-14
**Next Review**: After implementation or after real-world usage
