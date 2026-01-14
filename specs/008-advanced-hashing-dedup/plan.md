# Implementation Plan: Advanced Hashing & Deduplication (Slice 8)

**Feature**: Advanced Hashing & Deduplication
**Specification**: `specs/008-advanced-hashing-dedup/spec.md`
**Slice**: 8 - Advanced Hashing & Deduplication
**Created**: 2026-01-14

## Plan Scope

This plan implements **Slice 8 only**, which adds content-based file hashing (SHA-256) to enable duplicate detection across sources regardless of file path or name. Hashes are computed incrementally during import, stored in the baseline index (v1.1 extension), and used for cross-source deduplication in detect operations.

**Key Features**:
- SHA-256 content hashing with streaming computation (constant memory)
- Baseline index v1.1 extension with optional `hash` field (backward compatible)
- Hash computation during `import` (after file copy, before index update)
- Hash-based duplicate detection in `detect` (compare source hashes against library index)
- Cross-source deduplication (identify duplicates regardless of source origin)
- Optional hash computation during `library adopt` with `--with-hashes` flag
- Hash-based duplicate information in CLI output (human-readable and JSON)
- Hash index statistics in `status` command output

**Explicitly out of scope**:
- Automatic deletion of duplicate files (requires explicit user confirmation per Constitution 3.3)
- Automatic merging or consolidation of duplicate files
- Fuzzy or perceptual hashing for near-duplicate detection
- Multiple hash algorithms (SHA-256 only for P1)
- Hash-based file integrity verification (hash is for deduplication only)
- Default hash computation during adoption (requires explicit `--with-hashes` flag)

## Constitutional Compliance

This plan adheres to the MediaHub Constitution:

- **Safe Operations (3.3)**: Hash computation is read-only (no file modifications), dry-run performs zero writes always, `detect --dry-run` allows read-only hash computation, `import --dry-run` skips hash computation, graceful degradation on errors
- **Data Safety (4.1)**: Hash computation does not modify source files, hash failures do not cause data loss or operation failures, fallback ensures correctness
- **Deterministic Behavior (3.4)**: Hash computation is deterministic (same file content always produces same hash), hash-based duplicate detection produces identical results for same inputs
- **Transparent Storage (3.2)**: Hash data is stored in human-readable JSON format in baseline index, can be inspected without MediaHub
- **Simplicity of User Experience (3.1)**: Hash-based deduplication is transparent enhancement to path-based detection, no manual hash management required

## Work Breakdown

### Component 1: Content Hashing Core

**Purpose**: Implement SHA-256 content hashing with streaming computation, constant memory usage, and graceful error handling.

**Responsibilities**:
- Implement SHA-256 hash computation using CryptoKit (Foundation)
- Use streaming hash computation (read file in chunks, update hash incrementally)
- Ensure constant memory usage regardless of file size
- Format hash output as `sha256:<hexdigest>` string (64 hex characters)
- Handle hash computation errors gracefully (I/O errors, permission denied)
- Ensure hash computation is deterministic (same content = same hash)
- Ensure hash computation is read-only (never modify source files)

**Requirements Addressed**:
- FR-001: Compute content hashes (SHA-256) for media files
- FR-006: Ensure hash computation is idempotent
- FR-014: Ensure hash computation does not modify source files
- FR-016: Validate that hash computation is deterministic
- FR-019: Ensure hash computation handles large files efficiently (streaming)
- FR-020: Ensure hash computation handles file I/O errors gracefully

**Key Decisions**:
- Hash algorithm: SHA-256 (cryptographically secure, collision-resistant, widely supported)
- Hash format: `sha256:<hexdigest>` (algorithm prefix for future extensibility)
- Chunk size: 64KB or 1MB for streaming (balance between I/O efficiency and memory usage)
- Error handling: `throws -> String` (callers catch and treat hash as optional)
- CryptoKit vs CommonCrypto: Prefer CryptoKit (modern Swift API, available on macOS 10.15+)

**File Touch List**:
- `Sources/MediaHub/ContentHashing.swift` - New file with:
  - `ContentHasher` struct (stateless, streaming hash computation)
  - `computeHash(for url: URL) throws -> String` method (throws on failure)
  - `ContentHashError` enum (fileNotFound, permissionDenied, ioError, computationFailed, symlinkOutsideRoot)
  - Internal streaming implementation (read chunks, update SHA256 digest)
  - Symlink safety: resolve symlink, verify target within allowed root, skip with error if outside

**Validation Points**:
- Hash computation produces correct SHA-256 hash (verified against known test vectors)
- Hash computation is deterministic (same file produces same hash)
- Hash computation handles large files efficiently (constant memory, tested with 1GB+ file)
- Hash computation throws on errors (missing file, permission denied, symlink outside root)
- Hash format is correct (`sha256:` prefix + 64 hex characters)
- Symlinks within allowed root resolve correctly and hash target content
- Symlinks outside allowed root throw `symlinkOutsideRoot` error

**Risks & Open Questions**:
- CryptoKit availability: macOS 10.15+ required (verify deployment target)
- Chunk size tuning: Need to benchmark for optimal performance
- Symlink handling: Resolve symlink and verify target remains within allowed root (library root for library files, source root for source files); if target is outside root, skip hashing with warning and throw `symlinkOutsideRoot` error

**NON-NEGOTIABLE CONSTRAINTS**:
- Hash computation MUST use streaming approach (constant memory regardless of file size)
- Hash computation MUST be deterministic (same content always produces same hash)
- Hash computation MUST be read-only (never modify source files)
- Hash format MUST include algorithm prefix (`sha256:`) for future extensibility
- Hash computation errors MUST NOT cause operation failures (hash is optional at call sites)
- Symlinks MUST be validated: resolve target, verify within allowed root, throw error if outside (never follow symlinks pointing outside allowed root)

---

### Component 2: Baseline Index v1.1 Extension

**Purpose**: Extend baseline index format to include optional hash field in entries, maintaining backward compatibility with v1.0 indexes.

**Responsibilities**:
- Extend `IndexEntry` struct with optional `hash: String?` field
- Update version to "1.1" when hash data is present
- Ensure v1.0 indexes (without hashes) remain valid and readable
- Ensure v1.1 indexes are backward compatible (hash field is optional)
- Auto-upgrade v1.0 to v1.1 on first update with hash data
- Maintain deterministic JSON encoding (hash field included only if present)
- Implement hash lookup by path (O(1) via dictionary)
- Implement hash set for duplicate detection (O(1) lookup)

**Requirements Addressed**:
- FR-013: Ensure baseline index format is backward compatible (v1.0 without hashes valid, v1.1 adds optional hash)
- FR-015: Ensure hash storage in baseline index is atomic and interruption-safe
- FR-017: Ensure hash-based duplicate detection works with existing baseline index infrastructure
- FR-018: Ensure hash computation is incremental (only new files, not re-compute)

**Key Decisions**:
- Hash field name: `hash` (simple, descriptive)
- Hash field type: Optional string (`String?`)
- Version upgrade: Auto-upgrade to "1.1" when writing indexes with hash data
- Version compatibility: Read both "1.0" and "1.1", write "1.1" when hash data present
- Hash lookup: Build in-memory dictionary (path -> hash) and hash set for O(1) lookups

**File Touch List**:
- `Sources/MediaHub/BaselineIndex.swift` - Modify:
  - Add `hash: String?` field to `IndexEntry` struct
  - Update `BaselineIndexReader` to handle optional hash field
  - Update `BaselineIndexWriter` to include hash field when present
  - Add `hashLookup: [String: String]` computed property (path -> hash)
  - Add `hashSet: Set<String>` computed property (all hashes for duplicate detection)
  - Update version handling: read "1.0"/"1.1", write "1.1" when hash data present

**Validation Points**:
- v1.0 indexes (without hashes) load correctly (backward compatible)
- v1.1 indexes (with hashes) load correctly (hash field parsed)
- Entries without hash field are valid (optional field)
- Hash lookup by path is O(1) (dictionary-based)
- Hash set for duplicate detection is O(1) per lookup
- Version auto-upgrade works correctly (v1.0 -> v1.1 on first hash write)
- JSON encoding is deterministic (hash field omitted when nil)

**Risks & Open Questions**:
- JSON encoding of optional fields: Verify `encodeIfPresent` behavior (omit nil fields)
- Index size growth: Estimate ~71 bytes per entry with hash (acceptable)
- Migration strategy: Auto-upgrade only, no forced re-computation

**NON-NEGOTIABLE CONSTRAINTS**:
- v1.0 indexes MUST remain valid and readable (backward compatibility)
- Hash field MUST be optional (entries without hash are valid)
- Version upgrade MUST be automatic and transparent (no manual migration)
- Hash lookup MUST be O(1) (dictionary-based, not linear scan)
- JSON encoding MUST be deterministic (optional fields omitted when nil)

---

### Component 3: Hash Computation in Import

**Purpose**: Integrate hash computation into import workflow, computing hashes for newly imported files after copy and storing them in baseline index.

**Responsibilities**:
- Compute hash for each file after successful copy (import destination path)
- Store hash in baseline index entry for imported file
- Handle hash computation failures gracefully (import succeeds, hash omitted)
- Skip hash computation in dry-run mode (zero writes, zero hash computations)
- Ensure hash computation is incremental (only for newly imported files)
- Update index atomically with hash data (existing write-then-rename pattern)
- Report hash computation failures in output (non-fatal warnings)

**Requirements Addressed**:
- FR-001: Compute content hashes during import and store in baseline index
- FR-007: Ensure dry-run performs zero writes (import --dry-run skips hash computation)
- FR-008: Ensure hash computation failures do not cause import to fail
- FR-018: Ensure hash computation is incremental (only new files)
- NFR-001: Hash computation during import adds <10% overhead

**Key Decisions**:
- Hash timing: After file copy succeeds, before index update (hash destination file)
- Hash source: Imported file in library (destination), not source file
- Failure handling: Log warning, continue import, omit hash from index entry
- Dry-run: Skip all hash computation (not just storage)
- Batch update: Compute all hashes, then batch update index once

**File Touch List**:
- `Sources/MediaHub/ImportExecution.swift` - Modify:
  - Add hash computation step after file copy
  - Create `IndexEntry` with hash field populated
  - Handle hash computation failures (log, continue, omit hash)
  - Skip hash computation entirely in dry-run mode
  - Update index with hash data (existing atomic write pattern)

**Validation Points**:
- Hashes are computed for all successfully imported files
- Hash is computed from destination file (after copy)
- Hash computation failures do not cause import to fail
- Dry-run skips hash computation entirely (zero hash computations)
- Index entries include hash field after import
- Performance: Hash computation adds <10% overhead (measured)

**Risks & Open Questions**:
- Hash computation order: After copy ensures file integrity, but adds latency
- Parallel hashing: Could compute hash while copying next file (optimization for P2)
- Verification hash: Could compute hash of source and verify against destination (P2)

**NON-NEGOTIABLE CONSTRAINTS**:
- Hash computation MUST occur after successful file copy (not before)
- Hash computation failures MUST NOT cause import to fail (hash is optional)
- Dry-run MUST skip all hash computation (zero writes, zero computations)
- Index update MUST be atomic (existing write-then-rename pattern)
- Performance target: <10% overhead to import time

---

### Component 4: Hash-Based Duplicate Detection in Detect

**Purpose**: Integrate hash-based duplicate detection into detect workflow, identifying source files that match library content by hash regardless of path.

**Responsibilities**:
- Load library baseline index and extract hash set (O(1) lookups)
- Compute hash for each source file candidate (streaming, constant memory)
- Compare source file hash against library hash set
- Identify duplicates by hash match (source hash exists in library hash set)
- Fall back to path-based detection when hash data unavailable (graceful degradation)
- Report hash-based duplicate information in detection results
- Allow hash computation in dry-run mode (read-only operation for detection)
- Ensure detection remains read-only (never update index during detect)

**Requirements Addressed**:
- FR-003: Use content hashes for duplicate detection in detect
- FR-004: Support hash-based duplicate detection by comparing source against library index
- FR-005: Ensure hash-based duplicate detection produces deterministic results
- FR-007: Ensure dry-run allows hash computation for source files (detect --dry-run)
- FR-009: Ensure hash-based deduplication does not break path-based known-items logic
- FR-012: Support graceful degradation (fall back to path-based when hash data missing)

**Key Decisions**:
- Hash computation target: Source files only (library hashes come from index)
- Duplicate identification: Source hash found in library hash set = duplicate
- Path-based + hash-based: Both detection methods work together (union)
- Graceful degradation: If library has no hashes, skip hash-based detection (no failure)
- Detection result: Include `duplicateOf`, `duplicateOfPath`, `duplicateReason` fields

**File Touch List**:
- `Sources/MediaHub/DetectionOrchestration.swift` - Modify:
  - Load library index hash set (if available)
  - Compute hash for each source file candidate
  - Compare against library hash set for duplicates
  - Track hash-based duplicates separately from path-based known items
  - Merge detection results (path-based + hash-based)
  - Ensure detection never modifies index
- `Sources/MediaHub/DetectionResult.swift` - Modify:
  - Add `duplicateOf: String?` field (hash of duplicate)
  - Add `duplicateOfPath: String?` field (library path of duplicate)
  - Add `duplicateReason: String?` field ("content_hash" or "path_match")
  - Add `hashCoverage: Double?` field (percentage of library files with hashes)

**Validation Points**:
- Source files are hashed during detection
- Source hashes are compared against library hash set
- Duplicates are identified by hash match
- Path-based and hash-based detection work together
- Detection never modifies index (read-only guarantee)
- Dry-run allows hash computation (read-only operation)
- Graceful degradation when library has no hash data

**Risks & Open Questions**:
- Performance: Hashing all source files may be slow for large sources
- Caching: Should computed source hashes be cached? (No, detect is stateless)
- Partial coverage: How to report when only some library files have hashes?

**NON-NEGOTIABLE CONSTRAINTS**:
- Detection MUST be read-only (never create or modify index)
- Detection MUST allow hash computation in dry-run mode (read-only operation)
- Detection MUST fall back gracefully when hash data unavailable
- Path-based and hash-based detection MUST work together (not replacement)
- Duplicate identification MUST be deterministic (same inputs = same results)

---

### Component 5: Optional Hash Computation in Adoption (--with-hashes)

**Purpose**: Add optional `--with-hashes` flag to `library adopt` command for computing hashes during adoption, with explicit opt-in due to performance implications.

**Responsibilities**:
- Add `--with-hashes` flag to `library adopt` command (default: false)
- When flag is set, compute hash for each existing media file during baseline scan
- Store hashes in baseline index entries created during adoption
- Report progress during hash computation (large libraries may take time)
- Handle hash computation failures gracefully (adoption succeeds, hash omitted)
- Skip hash computation in dry-run mode (zero writes, zero computations)
- Ensure idempotent adoption (do not re-compute hashes for files that already have them)
- Document performance implications for large libraries

**Requirements Addressed**:
- FR-002: Support optional hash computation during adoption via `--with-hashes` flag
- FR-007: Ensure dry-run performs zero writes (adopt --dry-run skips hash computation)
- FR-008: Ensure hash computation failures do not cause adoption to fail
- FR-018: Ensure hash computation is idempotent (no re-compute for existing hashes)
- NFR-002: Hash computation during adoption completes in O(n) time

**Key Decisions**:
- Flag name: `--with-hashes` (explicit, self-documenting)
- Default behavior: No hash computation (fast adoption, backward compatible)
- Idempotent: Check if hash exists before computing (re-adoption scenario)
- Progress: Show progress indicator for hash computation (file count/total)
- Documentation: Warn about performance implications in help text

**File Touch List**:
- `Sources/MediaHubCLI/LibraryCommands.swift` - Modify:
  - Add `--with-hashes` flag to `adopt` command
  - Pass flag to adoption workflow
  - Update help text with performance warning
- `Sources/MediaHub/LibraryAdoption.swift` - Modify:
  - Accept `withHashes: Bool` parameter
  - Compute hashes during baseline scan when flag is set
  - Create index entries with hash field populated
  - Skip hash computation in dry-run mode
  - Handle hash computation failures gracefully

**Validation Points**:
- Default adoption does not compute hashes (fast)
- `--with-hashes` flag triggers hash computation
- Hashes are stored in index entries after adoption with flag
- Idempotent adoption does not re-compute existing hashes
- Hash computation failures do not cause adoption to fail
- Dry-run skips hash computation entirely
- Performance: O(n) time for n files (measured on 10k+ files)

**Risks & Open Questions**:
- Progress reporting: How detailed should progress be? (file count/total, basic for P1)
- Large library handling: Should there be a warning for 100k+ files? (Yes, in help text)
- Incremental hashing: Could allow partial hashing in future (P2)

**NON-NEGOTIABLE CONSTRAINTS**:
- Default adoption MUST NOT compute hashes (fast, backward compatible)
- `--with-hashes` flag MUST be explicit opt-in
- Hash computation failures MUST NOT cause adoption to fail
- Dry-run MUST skip all hash computation
- Idempotent adoption MUST NOT re-compute existing hashes

---

### Component 6: CLI Output Enhancement

**Purpose**: Enhance CLI output to include hash-based duplicate detection information in human-readable and JSON formats.

**Responsibilities**:
- Display hash-based duplicate information in `detect` output
- Distinguish between path-based known items and hash-based duplicates
- Include duplicate metadata in JSON output (`duplicateOf`, `duplicateOfPath`, `duplicateReason`)
- Add hash index statistics to `status` command output
- Report hash coverage percentage in status (files with hashes / total files)
- Report fallback to path-based detection when hash data unavailable
- Ensure JSON output is backward compatible (add fields, don't break existing)

**Requirements Addressed**:
- FR-010: Include hash-based duplicate information in detection results
- FR-011: Include hash index statistics in status command output
- FR-012: Report graceful degradation clearly (fallback to path-based only)

**Key Decisions**:
- Human-readable format: "File X is duplicate of library file Y (hash: abc123...)"
- JSON format: Add `duplicateOf`, `duplicateOfPath`, `duplicateReason` fields
- Status format: "Hash index: X entries, Y% coverage"
- Backward compatibility: Add fields, don't modify existing fields
- Fallback message: "Hash-based deduplication not available (no hash data in library)"

**File Touch List**:
- `Sources/MediaHubCLI/DetectCommand.swift` - Modify:
  - Format hash-based duplicate information in output
  - Include duplicate metadata in JSON output
  - Report hash coverage and fallback status
- `Sources/MediaHubCLI/StatusCommand.swift` - Modify:
  - Add hash index statistics to output
  - Show hash coverage percentage
  - Format for human-readable and JSON output
- `Sources/MediaHubCLI/OutputFormatting.swift` - Modify (if needed):
  - Add formatting helpers for hash-based duplicate information

**Validation Points**:
- Hash-based duplicates are displayed in detect output
- JSON output includes duplicate metadata
- Path-based and hash-based duplicates are distinguished
- Status output includes hash index statistics
- Hash coverage percentage is accurate
- JSON output is backward compatible
- Fallback to path-based is reported clearly

**Risks & Open Questions**:
- Output verbosity: How much detail to show for duplicates? (Path, hash prefix, reason)
- Hash truncation: Should long hashes be truncated in human output? (Yes, first 8 chars)

**NON-NEGOTIABLE CONSTRAINTS**:
- JSON output MUST be backward compatible (add fields, don't break existing)
- Duplicate information MUST distinguish path-based vs hash-based
- Status output MUST include hash coverage statistics
- Fallback to path-based MUST be clearly reported

---

### Component 7: Tests and Validation

**Purpose**: Implement comprehensive tests for hash feature, including unit tests for core hashing, integration tests for import/detect/adopt workflows, performance tests, and non-regression tests.

**Responsibilities**:
- Test hash computation (correctness, determinism, streaming, error handling)
- Test baseline index v1.1 (hash field, backward compatibility, version upgrade)
- Test hash computation during import (after copy, failures, dry-run)
- Test hash-based duplicate detection (detect with hashes, graceful degradation)
- Test optional hash computation during adoption (--with-hashes flag)
- Test CLI output (human-readable, JSON, hash statistics)
- Test performance (hash computation overhead, detection speed)
- Ensure all existing tests still pass (no regression)

**Requirements Addressed**:
- SC-001 through SC-020: All success criteria from spec

**Test Strategy**:

**Unit Tests** (isolated component testing):
- `ContentHashingTests.swift`: Hash computation correctness, determinism, streaming, errors
- `BaselineIndexTests.swift` (extend): Hash field parsing, v1.1 format, backward compatibility

**Integration Tests** (workflow testing):
- `ImportExecutionTests.swift` (extend): Hash computation during import, failures, dry-run
- `DetectionOrchestrationTests.swift` (extend): Hash-based duplicate detection, graceful degradation
- `LibraryAdoptionTests.swift` (extend): --with-hashes flag, idempotent adoption

**Performance Tests** (non-blocking, indicative):
- `ContentHashingPerformanceTests.swift`: Hash computation throughput, memory usage
- Import overhead measurement: <10% target
- Detection speed with hash-based deduplication

**File Touch List**:
- `Tests/MediaHubTests/ContentHashingTests.swift` - New file with:
  - Test hash computation produces correct SHA-256 (known test vectors)
  - Test hash computation is deterministic (same file = same hash)
  - Test hash computation handles large files (streaming, constant memory)
  - Test hash computation handles errors gracefully (missing file, permission denied)
  - Test hash format is correct (`sha256:` prefix + 64 hex chars)
- `Tests/MediaHubTests/BaselineIndexTests.swift` - Modify to:
  - Test v1.0 indexes load correctly (backward compatible)
  - Test v1.1 indexes load correctly (hash field parsed)
  - Test hash field is optional (entries without hash are valid)
  - Test hash lookup is O(1) (dictionary-based)
  - Test version auto-upgrade (v1.0 -> v1.1)
- `Tests/MediaHubTests/ImportExecutionTests.swift` - Modify to:
  - Test hashes computed for imported files
  - Test hash computed from destination file (after copy)
  - Test hash computation failures do not fail import
  - Test dry-run skips hash computation
  - Test index entries include hash field after import
- `Tests/MediaHubTests/DetectionOrchestrationTests.swift` - Modify to:
  - Test source files are hashed during detection
  - Test duplicates identified by hash match
  - Test path-based and hash-based detection work together
  - Test detection never modifies index
  - Test dry-run allows hash computation
  - Test graceful degradation when no hash data
- `Tests/MediaHubTests/LibraryAdoptionTests.swift` - Modify to:
  - Test default adoption does not compute hashes
  - Test --with-hashes triggers hash computation
  - Test idempotent adoption does not re-compute hashes
  - Test dry-run skips hash computation
- `Tests/MediaHubTests/ContentHashingPerformanceTests.swift` - New file with:
  - Test hash computation throughput (MB/s)
  - Test memory usage is constant for large files
  - Test import overhead <10% (measured)

**Validation Points**:
- All unit tests pass (hash computation, index format)
- All integration tests pass (import, detect, adopt workflows)
- Performance tests show <10% import overhead (measured)
- All existing tests still pass (no regression)
- Dry-run tests verify zero writes and zero hash computations
- Determinism tests verify same inputs produce same hashes
- Graceful degradation tests verify fallback behavior

**NON-NEGOTIABLE CONSTRAINTS**:
- Tests MUST cover all success criteria from spec (SC-001 through SC-020)
- Tests MUST verify deterministic hash computation (known test vectors)
- Tests MUST verify dry-run guarantees (zero writes, zero hash computations for import)
- Tests MUST verify graceful degradation (fallback to path-based)
- Tests MUST verify no regression (all existing tests pass)

---

## Execution Sequences

### Sequence 1: Import with Hash Computation

1. **Import Start**: User runs `mediahub import <source-id> --all --library <path> [--dry-run]`
2. **Index Check**: Check if `.mediahub/registry/index.json` exists and is valid
   - If valid: Load index, extract paths for library comparison (path-based known-items)
   - If missing/invalid: Fallback to full scan (path-based only)
3. **Candidate Filtering**: For each source file candidate:
   - Check path against library paths (path-based known items, existing logic)
   - If path match: Mark as known item (exclude from import candidates)
   - **Note**: Import does NOT hash source files; hash-based deduplication is performed by `detect` command
4. **Import Execution**: For each import candidate:
   - Copy file to library (existing logic)
   - **NEW**: Compute hash of imported file (destination) — catch errors, omit hash on failure
   - Create index entry with hash field populated (or nil if hash failed)
5. **Index Update**:
   - Batch update index with new entries (including hashes where computed)
   - Write atomically (temp file + rename)
6. **Dry-Run Handling**: If `--dry-run`:
   - Skip file copy entirely
   - Skip hash computation entirely (zero hash computations)
   - Skip index update (zero writes)
   - Show preview: "Would import N files, would compute hashes for N imported files"
7. **Import Complete**: Report import success, hash statistics (files hashed, hash failures if any)

**Fallback Decisions**:
- Path-based known-items filtering only (import does not perform hash-based duplicate detection)
- If hash computation fails for imported file: Log warning, import succeeds, hash omitted from index entry

### Sequence 2: Detection with Hash-Based Deduplication

1. **Detection Start**: User runs `mediahub detect <source-id> --library <path> [--json] [--dry-run]`
2. **Index Check**: Check if `.mediahub/registry/index.json` exists and is valid
   - If valid: Load index, extract paths and build hash set
   - If missing/invalid: Fallback to full scan (path-based only)
3. **Library Comparison**: For each source file candidate:
   - Check path against library paths (path-based known items)
   - **NEW**: Compute hash for source file (streaming)
   - **NEW**: Check hash against library hash set (hash-based duplicates)
   - Classify: new, known item (path), or duplicate (hash)
4. **Detection Complete**: Report detection results:
   - New items (not in library by path or hash)
   - Known items (path match)
   - **NEW**: Duplicates (hash match, different path)
   - Hash coverage (percentage of library files with hashes)
   - Fallback status (if hash-based detection unavailable)

**Fallback Decisions**:
- If library index has no hashes: Report "Hash-based deduplication not available", use path-based only
- If hash computation fails for source file: Log warning, classify as "new" (conservative)
- Detection never modifies index (read-only guarantee)
- Dry-run allows hash computation (read-only operation)

### Sequence 3: Library Adoption with Optional Hashing

1. **Adoption Start**: User runs `mediahub library adopt <path> [--with-hashes] [--dry-run] [--yes]`
2. **Baseline Scan**: Perform baseline scan of existing media files (existing logic)
3. **Index Check**: Check if `.mediahub/registry/index.json` exists and is valid
   - If valid: Skip index creation (idempotent, preserve existing index)
   - If absent/invalid: Proceed to index creation
4. **Index Creation** (if needed):
   - For each path in baseline scan results:
     - Collect file metadata (size, mtime)
     - **NEW**: If `--with-hashes`: Compute hash for file (streaming)
   - Create index entries (with or without hash, depending on flag)
   - Sort entries by normalized path
   - Write index atomically
5. **Dry-Run Handling**: If `--dry-run`:
   - Show index preview (entry count, structure)
   - Do not write index
   - Do not compute hashes (even if `--with-hashes` specified)
6. **Adoption Complete**: Report adoption success, hash statistics (if `--with-hashes`)

**Fallback Decisions**:
- If hash computation fails for file: Log warning, continue adoption, hash omitted
- If index creation fails: Log error, adoption succeeds (index is optional)
- Idempotent adoption with `--with-hashes` on existing index: Skip files that already have hashes

### Sequence 4: Status with Hash Statistics

1. **Status Start**: User runs `mediahub status --library <path> [--json]`
2. **Index Check**: Check if `.mediahub/registry/index.json` exists and is valid
3. **Index Metadata Extraction**: If index exists:
   - Extract version, entry count, last update time
   - **NEW**: Count entries with hash field
   - **NEW**: Calculate hash coverage (entries with hash / total entries)
4. **Status Output**: Format status information:
   - Existing: Library path, source count, etc.
   - **NEW**: Hash index statistics (entry count with hashes, coverage percentage)
5. **Status Complete**: Report status with hash information

---

## Index v1.1 Migration Strategy

### Automatic Version Upgrade

**Strategy**: Auto-upgrade v1.0 to v1.1 when writing indexes with hash data

**Process**:
1. Read existing index (v1.0 or v1.1)
2. If adding hash data to entries: Set version to "1.1"
3. Write updated index with new version
4. Existing entries without hashes remain valid

**Rationale**:
- Transparent upgrade (no manual migration)
- Backward compatible (v1.0 indexes remain readable)
- Incremental (only upgrade when hash data added)

### Backward Compatibility Rules

**Reading**:
- Accept version "1.0" (entries without hash field)
- Accept version "1.1" (entries with optional hash field)
- Reject unknown versions (fail fast, clear error)

**Writing**:
- Write version "1.0" if no entries have hashes
- Write version "1.1" if any entries have hashes
- Include hash field only if present (omit nil)

**Rationale**:
- v1.0 indexes continue to work (no forced upgrade)
- v1.1 is backward compatible (hash is optional)
- Clear versioning for future extensibility

---

## Dry-Run Guarantees

### Zero Writes Guarantee

**Requirement**: `--dry-run` operations MUST perform zero writes to baseline index

**Implementation for Detect**:
- `detect --dry-run` allows hash computation for source files (read-only)
- `detect --dry-run` performs zero writes (detection is always read-only)
- Hash-based duplicate detection works in dry-run mode

**Implementation for Import**:
- `import --dry-run` skips hash computation entirely
- `import --dry-run` skips file copy entirely
- `import --dry-run` skips index update (zero writes)
- Shows preview: "Would compute hashes for N files"

**Implementation for Adopt**:
- `adopt --dry-run` skips hash computation (even with `--with-hashes`)
- `adopt --dry-run` skips index creation (zero writes)
- Shows preview: "Would compute hashes for N files" (if `--with-hashes`)

### Rationale for Asymmetric Dry-Run Behavior

**Detect dry-run allows hashing**: Detection is read-only by design. Computing hashes for source files enables hash-based duplicate detection preview without any writes. This is valuable for users to see what duplicates would be detected.

**Import dry-run skips all hashing**: Import performs writes (file copy, index update). In dry-run mode, zero writes and zero hash computations occur. Import does not hash source files (that is `detect`'s responsibility), and since no files are copied, there are no destination files to hash. The preview shows what *would* happen: "Would import N files, would compute hashes for N imported files".

---

## Failure Modes and Fallback Behavior

### Hash Computation Failures

**Failure Modes**:
- File I/O errors (permission denied, file not found, disk errors)
- Hash computation errors (crypto library errors, out of memory)
- Interruption (Ctrl+C, system shutdown)

**Fallback Behavior**:
- Hash computation failures do not cause operations to fail
- Failed hash computations are reported in output (warning level)
- Files without hashes are still imported/adopted
- Future detection falls back to path-based for files without hashes

### Missing or Incomplete Hash Data

**Failure Modes**:
- Library index has no hash data (v1.0 index, or hashes never computed)
- Partial hash coverage (some files have hashes, others don't)
- Corrupted hash data (invalid format)

**Fallback Behavior**:
- Operations fall back to path-based detection for files without hashes
- Hash coverage is reported in output (e.g., "50% hash coverage")
- Operations do not fail due to missing hash data
- Clear message: "Hash-based deduplication not available"

---

## Test Plan

### Unit Tests

**ContentHashingTests.swift** (new):
- Test hash produces correct SHA-256 (known test vectors: empty file, "hello world", etc.)
- Test hash is deterministic (same file content = same hash)
- Test streaming handles large files (1GB+ test file, verify constant memory)
- Test error handling (missing file throws, permission denied throws, symlink outside root throws)
- Test hash format (`sha256:` prefix + 64 hex characters)
- Test symlink safety (symlink within root resolves and hashes target; symlink outside root throws)

**BaselineIndexTests.swift** (extend):
- Test v1.0 index loads correctly (entries without hash field)
- Test v1.1 index loads correctly (entries with hash field)
- Test optional hash field (nil hash is valid)
- Test hash lookup by path (O(1) via dictionary)
- Test hash set construction (all hashes for duplicate detection)
- Test version auto-upgrade (v1.0 -> v1.1 on hash write)
- Test JSON encoding omits nil hash fields

### Integration Tests

**ImportExecutionTests.swift** (extend):
- Test hashes computed for imported files (index entries have hash field)
- Test hash computed from destination file (not source)
- Test hash computation failure does not fail import
- Test dry-run skips hash computation entirely
- Test incremental hashing (re-import does not re-hash existing)

**DetectionOrchestrationTests.swift** (extend):
- Test source files hashed during detection
- Test duplicate identified by hash match (different path, same hash)
- Test path-based and hash-based work together (both exclusions apply)
- Test detection is read-only (index not modified)
- Test dry-run allows hash computation (read-only)
- Test graceful degradation (no library hashes = path-based only)
- Test determinism (same inputs = same detection results)

**LibraryAdoptionTests.swift** (extend):
- Test default adoption does not compute hashes
- Test `--with-hashes` computes and stores hashes
- Test idempotent adoption does not re-hash files with existing hashes
- Test hash computation failure does not fail adoption
- Test dry-run skips hash computation (even with `--with-hashes`)

**StatusCommandTests.swift** (extend):
- Test hash statistics in status output (entry count, coverage)
- Test JSON output includes hash statistics
- Test status with no hash data (coverage = 0%)

### Performance Tests (Non-Blocking)

**ContentHashingPerformanceTests.swift** (new):
- Measure hash throughput (MB/s on reference hardware)
- Verify constant memory for large files (1GB file, <100MB memory)
- Measure import overhead with hashing (<10% target)

### Test Datasets

- Known test vectors for SHA-256 (empty file, "hello world", binary data)
- Synthetic files for performance testing (1KB, 1MB, 100MB, 1GB)
- Duplicate file pairs (same content, different names/paths)
- Library with 10,000+ files for performance benchmarks

---

## Validation Checklist

### Functional Validation

- [ ] Hash computation produces correct SHA-256 (verified against known test vectors)
- [ ] Hash computation is deterministic (same file content = same hash)
- [ ] Hash computation is streaming (constant memory for large files)
- [ ] Hashes stored in baseline index entries during import (destination files only)
- [ ] Import uses path-based known-items filtering only (no source file hashing)
- [ ] Hash-based duplicate detection in `detect` identifies duplicates by content
- [ ] Path-based and hash-based detection work together in `detect` (union)
- [ ] Detection results include duplicate metadata (hash, path, reason)
- [ ] `--with-hashes` flag computes hashes during adoption
- [ ] Default adoption does not compute hashes
- [ ] Status output includes hash statistics (coverage, count)

### Safety Validation

- [ ] Hash computation does not modify source files (read-only)
- [ ] Hash computation failures do not cause operations to fail
- [ ] Import dry-run skips hash computation entirely (zero hash computations)
- [ ] Detect dry-run allows hash computation (read-only)
- [ ] Adopt dry-run skips hash computation
- [ ] Index updates are atomic (write-then-rename pattern)
- [ ] Graceful degradation when hash data unavailable
- [ ] Symlinks within allowed root resolve and hash target content
- [ ] Symlinks outside allowed root throw error and skip hashing with warning

### Compatibility Validation

- [ ] v1.0 indexes remain valid and readable
- [ ] v1.1 indexes are backward compatible (hash optional)
- [ ] Version auto-upgrade works correctly (v1.0 -> v1.1)
- [ ] JSON output is backward compatible (add fields, don't break)
- [ ] All existing tests still pass (no regression)
- [ ] CLI smoke tests pass (`scripts/smoke_cli.sh`)

### Performance Validation

- [ ] Hash computation adds <10% overhead to import (measured)
- [ ] Hash computation handles 1GB+ files without memory issues
- [ ] Hash lookup is O(1) per candidate (dictionary-based)
- [ ] Adoption with `--with-hashes` is O(n) for n files

### Determinism Validation

- [ ] Same file content produces same hash (verified by tests)
- [ ] Same source/library state produces same detection results
- [ ] Hash format is deterministic (`sha256:` + hex)

---

## Implementation Notes

### CryptoKit Usage

**Implementation**: Use `CryptoKit.SHA256` for hash computation

```swift
import CryptoKit

/// Computes SHA-256 hash for file at URL.
/// - Parameter url: File URL to hash
/// - Parameter allowedRoot: Root directory for symlink validation
/// - Throws: ContentHashError on failure (fileNotFound, permissionDenied, ioError, symlinkOutsideRoot)
/// - Returns: Hash string in format "sha256:<hexdigest>"
func computeHash(for url: URL, allowedRoot: URL) throws -> String {
    // Resolve symlinks and validate target is within allowed root
    let resolvedURL = url.resolvingSymlinksInPath()
    guard resolvedURL.path.hasPrefix(allowedRoot.resolvingSymlinksInPath().path) else {
        throw ContentHashError.symlinkOutsideRoot(url)
    }

    let handle = try FileHandle(forReadingFrom: resolvedURL)
    defer { try? handle.close() }

    var hasher = SHA256()
    while let chunk = try handle.read(upToCount: 64 * 1024) {
        hasher.update(data: chunk)
        if chunk.isEmpty { break }
    }

    let digest = hasher.finalize()
    return "sha256:" + digest.map { String(format: "%02x", $0) }.joined()
}
```

**Notes**:
- CryptoKit requires macOS 10.15+ (verify deployment target)
- Streaming reads in 64KB chunks (balance between I/O efficiency and memory)
- FileHandle for large file support (no memory mapping)
- Callers catch errors and treat hash as optional (omit hash + log warning on failure)

### Known SHA-256 Test Vectors

**For Test Verification**:
- Empty file: `sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
- "hello world\n": `sha256:a948904f2f0f479b8f8564cbf12dace11e45b0c1f525f72f4a29f0d3f3b2c8d8`
- Binary null byte: `sha256:6e340b9cffb37a989ca544e6bb780a2c78901d3fb33738768511a30617afa01d`

### Index Entry Extension

**Current v1.0 Entry**:
```json
{
  "path": "2024/01/IMG_1234.jpg",
  "size": 2456789,
  "mtime": "2024-01-15T14:30:00Z"
}
```

**Extended v1.1 Entry**:
```json
{
  "path": "2024/01/IMG_1234.jpg",
  "size": 2456789,
  "mtime": "2024-01-15T14:30:00Z",
  "hash": "sha256:abc123def456..."
}
```

**Codable Implementation**:
```swift
struct IndexEntry: Codable {
    let path: String
    let size: Int64
    let mtime: Date
    var hash: String?  // Optional for backward compatibility
}
```

---

**Last Updated**: 2026-01-14
**Next Review**: After implementation or after real-world usage
