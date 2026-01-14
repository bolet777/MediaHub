# Feature Specification: Advanced Hashing & Deduplication

**Feature Branch**: `008-advanced-hashing-dedup`  
**Created**: 2026-01-27  
**Status**: Ready for Plan  
**Input**: User description: "Define a safe, deterministic, and incremental hashing-based deduplication mechanism to identify duplicate media files across sources and libraries, based on file content rather than paths."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Content-Based Duplicate Detection in Detect (Priority: P1)

A user has multiple sources (e.g., Photos.app export, iPhone folder, external drive) that may contain duplicate media files with different paths or names. When running `mediahub detect <source-id> --library <path>`, the user wants MediaHub to identify files that are duplicates based on content (file hash) rather than just path, so they can see which files are truly new versus duplicates of existing library content.

**Why this priority**: Path-based detection (Slice 2-7) only identifies duplicates when paths match exactly. Content-based hashing enables detection of duplicates even when files have different names or paths, which is common when importing from multiple sources or after file renames.

**Independent Test**: Can be fully tested by:
1. Creating a library with a media file (e.g., `2024/01/IMG_1234.jpg`)
2. Creating a source with the same file content but different name (e.g., `DSC_5678.jpg`)
3. Running `detect` and verifying that the duplicate is identified by hash, not path
4. Verifying that detection results show the duplicate relationship

**Acceptance Scenarios**:

1. **Given** a user runs `mediahub detect <source-id> --library <path>` on a source containing files, **When** some source files have the same content hash as files already in the library (different paths), **Then** MediaHub identifies these as duplicates and excludes them from candidate lists (content-based deduplication)
2. **Given** a user runs detection with content hashing, **When** detection completes, **Then** detection results include hash-based duplicate information (e.g., `duplicateOf: <hash>` or `duplicateOf: <library-path>`) in addition to path-based known items
3. **Given** a user runs detection with content hashing, **When** detection completes, **Then** detection results are deterministic (same source/library state produces same duplicate detection results)
4. **Given** a user runs detection with `--dry-run` flag, **When** detection executes, **Then** MediaHub computes hashes for source files and performs hash-based duplicate detection (read-only operation) but performs zero writes (no index updates, no file modifications)
5. **Given** a user runs detection on a library without hash data in baseline index, **When** detection executes, **Then** MediaHub falls back to path-based detection only (graceful degradation, no failure)

---

### User Story 2 - Incremental Hash Computation and Storage (Priority: P1)

A user wants MediaHub to compute and store content hashes incrementally during import operations so that future detection runs can use hash-based deduplication without re-computing hashes for already-imported files. Hash computation should be efficient and should not significantly slow down import operations.

**Why this priority**: Computing hashes for all library files on every detection run would be prohibitively slow for large libraries. Incremental hash computation during import enables efficient hash-based deduplication in future runs.

**Independent Test**: Can be fully tested by:
1. Importing files into a library
2. Verifying that baseline index entries include hash fields after import
3. Running detection again and verifying that hashes are read from index (not recomputed)
4. Measuring import time to verify hash computation does not significantly slow imports

**Acceptance Scenarios**:

1. **Given** a user runs `mediahub import <source-id> --all --library <path>` on a library with baseline index, **When** import completes successfully, **Then** MediaHub computes content hashes for newly imported files and stores them in baseline index entries (incremental hash computation)
2. **Given** a user runs import with hash computation, **When** import completes, **Then** baseline index entries for imported files include hash fields (e.g., `hash: "sha256:abc123..."`) in addition to existing path, size, mtime fields
3. **Given** a user runs import with `--dry-run` flag, **When** import preview completes, **Then** MediaHub shows what hash computations would be performed but does not compute hashes or update index (zero writes, zero hash computations in dry-run mode)
4. **Given** a user runs import and hash computation fails for a file, **When** import completes, **Then** MediaHub reports the hash computation failure but import still succeeds (hash is optional, import is primary operation)
5. **Given** a user runs import multiple times, **When** imports complete, **Then** hash computation is idempotent (same file content produces same hash, no duplicate hash computations for same file)

---

### User Story 3 - Cross-Source Duplicate Detection (Priority: P1)

A user has multiple sources attached to the same library, and some files may appear in multiple sources with different paths. When running detection on a source, the user wants MediaHub to identify files that are duplicates of content already in the library (regardless of which source they were originally imported from) by comparing source file hashes against the library's baseline index hash set.

**Why this priority**: Users often import from multiple sources (Photos.app, iPhone, external drives) that may contain overlapping content. Hash-based duplicate detection against the library's baseline index prevents importing the same file multiple times from different sources, even when files have different paths or names.

**Independent Test**: Can be fully tested by:
1. Importing files from Source A into a library
2. Attaching Source B that contains some of the same files (different paths)
3. Running detection on Source B and verifying that duplicates are identified by comparing source file hashes against library baseline index hashes
4. Verifying that detection results show duplicate relationships to library content

**Acceptance Scenarios**:

1. **Given** a user has imported files from Source A into a library, **When** they run detection on Source B containing files with same content hash as library files, **Then** MediaHub identifies these as duplicates by comparing source file hashes against the library's baseline index hash set and excludes them from candidate lists
2. **Given** a user runs detection with hash-based deduplication, **When** detection completes, **Then** detection results include duplicate information indicating the file is a duplicate of library content (e.g., `duplicateOf: <hash>`, `duplicateOfPath: <library-path>`, `duplicateReason: "content_hash"`)
3. **Given** a user runs detection with hash-based deduplication, **When** detection completes, **Then** detection results are deterministic (same source/library state produces same duplicate detection results)
4. **Given** a user runs detection on multiple sources, **When** detection completes, **Then** MediaHub correctly identifies duplicates by comparing source file hashes against the library's baseline index hash set (hash-based comparison works across sources)
5. **Given** a user runs detection with `--dry-run` flag, **When** detection executes, **Then** MediaHub computes hashes for source files and performs hash-based duplicate detection against library baseline index but performs zero writes (no index updates, no file modifications)

---

### User Story 4 - Optional Hash Computation During Library Adoption (Priority: P2 - Optional)

A user may want MediaHub to compute content hashes for existing media files during `library adopt` operations so that adopted libraries immediately support hash-based deduplication without requiring a separate hash computation pass. However, hash computation during adoption is optional and requires an explicit flag due to performance implications for large libraries.

**Why this priority**: Adopted libraries may contain many existing files. Computing hashes during adoption can be slow for large libraries (10,000+ files), so it should be opt-in rather than default behavior. Default adoption should complete quickly without hash computation.

**Independent Test**: Can be fully tested by:
1. Running `library adopt <path>` on a library with existing media files (default: no hash computation)
2. Running `library adopt <path> --with-hashes` and verifying that baseline index entries include hash fields after adoption
3. Verifying that adoption with `--with-hashes` completes in reasonable time (hash computation does not make adoption prohibitively slow)
4. Running detection after adoption and verifying hash-based deduplication works when hashes are present

**Acceptance Scenarios**:

1. **Given** a user runs `mediahub library adopt <path>` on a library with existing media files (default, no flag), **When** adoption completes, **Then** MediaHub creates baseline index without hash fields (default adoption does not compute hashes, fast completion)
2. **Given** a user runs `mediahub library adopt <path> --with-hashes` on a library with existing media files, **When** adoption completes, **Then** MediaHub computes content hashes for all existing media files and stores them in baseline index entries (optional hash computation during adoption)
3. **Given** a user runs adoption with `--with-hashes` flag, **When** adoption completes, **Then** baseline index entries include hash fields (e.g., `hash: "sha256:abc123..."`) for all existing media files
4. **Given** a user runs adoption with `--dry-run` flag, **When** adoption preview completes, **Then** MediaHub shows what would be created but does not compute hashes or create index (zero writes, zero hash computations in dry-run mode)
5. **Given** a user runs adoption with `--with-hashes` and hash computation fails for some files, **When** adoption completes, **Then** MediaHub reports hash computation failures but adoption still succeeds (hash is optional, adoption metadata is primary)
6. **Given** a user runs adoption with `--with-hashes` on an already adopted library (idempotent), **When** adoption completes, **Then** MediaHub does not recompute hashes for files that already have hashes in index (idempotent hash computation)

---

### User Story 5 - Hash-Based Deduplication Information in CLI Output (Priority: P1)

A user wants to see hash-based duplicate detection information in CLI output (both human-readable and JSON) so they can understand which files are duplicates and why they are excluded from import candidates.

**Why this priority**: Visibility into duplicate detection helps users understand detection results and make informed decisions about imports. JSON output enables automation and tooling.

**Independent Test**: Can be fully tested by:
1. Running detection on a source with duplicate files
2. Verifying that CLI output shows duplicate information
3. Verifying that JSON output includes duplicate metadata
4. Verifying that duplicate information is clear and actionable

**Acceptance Scenarios**:

1. **Given** a user runs `mediahub detect <source-id> --library <path>`, **When** detection identifies hash-based duplicates, **Then** MediaHub displays duplicate information in human-readable output (e.g., "File X is duplicate of library file Y (hash: abc123...)")
2. **Given** a user runs detection with `--json` flag, **When** detection completes, **Then** MediaHub JSON output includes duplicate metadata (e.g., `duplicateOf: <hash>`, `duplicateOfPath: <library-path>`, `duplicateReason: "content_hash"`)
3. **Given** a user runs detection with hash-based duplicates, **When** detection completes, **Then** MediaHub clearly distinguishes between path-based known items and hash-based duplicates in output
4. **Given** a user runs `mediahub status --library <path>`, **When** status completes, **Then** MediaHub displays hash index statistics (e.g., "Hash index: 10,000 entries, 95% coverage") in human-readable and JSON output
5. **Given** a user runs detection on a library without hash data, **When** detection completes, **Then** MediaHub clearly indicates that hash-based deduplication is not available (fallback to path-based only)

---

### Edge Cases

- What happens when a user runs detection and hash computation fails for a source file (I/O error, permission denied)?
- What happens when a user runs import and hash computation is slower than file copy (performance regression)?
- What happens when a user runs detection on a library with partial hash coverage (some files have hashes, others don't)?
- What happens when a user runs detection and two different files have the same hash (hash collision, extremely rare)?
- What happens when a user runs adoption with `--with-hashes` on a library with 100,000+ files (hash computation performance)?
- What happens when a user runs detection and the baseline index has hash data but some library files are missing (stale index)?
- What happens when a user runs import and hash computation fails due to disk space (temporary files)?
- What happens when a user runs detection with `--dry-run` and hash computation is performed (read-only operation, zero writes)?
- What happens when a user runs detection and hash computation is interrupted (Ctrl+C)?
- What happens when a user runs import and hash computation succeeds but index update fails (partial failure)?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: MediaHub MUST compute content hashes (SHA-256) for media files during import operations and store them in baseline index entries (incremental hash computation)
- **FR-002**: MediaHub MAY support optional hash computation during `library adopt` operations via explicit flag (e.g., `--with-hashes`). Default adoption MUST NOT compute hashes (fast adoption without performance impact). If implemented, hash computation during adoption MUST be explicitly requested and MUST document performance implications for large libraries.
- **FR-003**: MediaHub MUST use content hashes for duplicate detection in `detect` operations, identifying files with same content hash as duplicates regardless of path or name
- **FR-004**: MediaHub MUST support hash-based duplicate detection by comparing source file hashes against the library's baseline index hash set, identifying files that are duplicates of content already in the library (regardless of which source they were originally imported from)
- **FR-005**: MediaHub MUST ensure that hash-based duplicate detection produces deterministic results (same source/library state produces same duplicate detection results)
- **FR-006**: MediaHub MUST ensure that hash computation is idempotent (same file content produces same hash, no duplicate hash computations for same file)
- **FR-007**: MediaHub MUST ensure that `--dry-run` operations perform zero writes to baseline index (dry-run never modifies index). For `detect --dry-run`, MediaHub MUST allow hash computation for source files (read-only operation) to enable hash-based duplicate detection. For `import --dry-run`, MediaHub MUST skip hash computation and index updates (preview only, zero hash computations, zero writes)
- **FR-008**: MediaHub MUST ensure that hash computation failures do not cause import or adoption operations to fail (hash is optional, import/adoption are primary operations)
- **FR-009**: MediaHub MUST ensure that hash-based deduplication does not break existing path-based known-items logic (both path-based and hash-based detection work together)
- **FR-010**: MediaHub MUST include hash-based duplicate information in detection results (both human-readable and JSON output)
- **FR-011**: MediaHub MUST include hash index statistics in `status` command output (hash coverage, entry count with hashes)
- **FR-012**: MediaHub MUST support graceful degradation: if hash data is missing or incomplete, operations MUST fall back to path-based detection only (no failure, clear reporting)
- **FR-013**: MediaHub MUST ensure that baseline index format is backward compatible (version 1.0 indexes without hashes remain valid, version 1.1 indexes add optional hash fields)
- **FR-014**: MediaHub MUST ensure that hash computation does not modify source files (read-only hash computation)
- **FR-015**: MediaHub MUST ensure that hash storage in baseline index is atomic and interruption-safe (write-then-rename pattern, same as existing index updates)
- **FR-016**: MediaHub MUST validate that hash computation is deterministic (same file content always produces same hash, verified by tests)
- **FR-017**: MediaHub MUST ensure that hash-based duplicate detection works with existing baseline index read/update rules (hash data is stored and retrieved using existing index infrastructure)
- **FR-018**: MediaHub MUST ensure that hash computation is incremental (only compute hashes for new files, not re-compute for existing files with hashes)
- **FR-019**: MediaHub MUST ensure that hash computation handles large files efficiently (streaming hash computation, not load entire file into memory)
- **FR-020**: MediaHub MUST ensure that hash computation handles file I/O errors gracefully (report errors but do not fail operations)

### Non-Functional Requirements

- **NFR-001**: Hash computation during import MUST not significantly slow down import operations (target: hash computation adds <10% overhead to import time, measured on reference dataset)
- **NFR-002**: If hash computation during adoption is implemented (via `--with-hashes` flag), it MUST complete in reasonable time (target: O(n) where n is number of files, measured on reference dataset with 10,000+ files). Default adoption without hash computation MUST complete quickly (fast adoption without performance impact)
- **NFR-003**: Hash-based duplicate detection in detect operations MUST be fast (target: hash lookup is O(1) per candidate, hash computation for source files is O(n) where n is number of source files)
- **NFR-004**: Hash storage in baseline index MUST be efficient (target: hash field adds <100 bytes per entry on average, or index size growth remains reasonable for libraries up to 50,000 files, JSON encoding remains compact)
- **NFR-005**: Hash computation MUST handle large files efficiently (target: streaming hash computation, constant memory usage regardless of file size)
- **NFR-006**: Hash computation MUST be deterministic (same file content always produces same hash, verified by tests with known test vectors)
- **NFR-007**: Hash-based duplicate detection MUST maintain 100% accuracy (hash-based duplicates are correctly identified, no false positives or false negatives)
- **NFR-008**: Hash computation MUST not impact existing functionality (backward compatible, no breaking changes to existing commands or output formats)

### Key Entities *(include if feature involves data)*

- **Content Hash**: A SHA-256 hash of file content used to identify duplicate files regardless of path or name. Hashes are computed incrementally during import and adoption, stored in baseline index entries, and used for duplicate detection in detect operations.

- **Hash-Based Duplicate Detection**: The process of identifying files with the same content hash as duplicates, regardless of path or name. Hash-based duplicate detection works alongside path-based known-items tracking to provide comprehensive duplicate detection.

- **Baseline Index Entry (v1.1)**: An extended baseline index entry that includes optional hash fields in addition to existing path, size, mtime fields. Version 1.1 entries are backward compatible with version 1.0 (hash field is optional).

- **Hash Index**: The collection of content hashes stored in baseline index entries. The hash index enables fast hash-based duplicate detection by providing pre-computed hashes for library files.

- **Cross-Source Deduplication**: The process of identifying files that are duplicates of content already in the library by comparing source file hashes against the library's baseline index hash set. This enables duplicate detection across sources even when files have different paths or names, since comparison is based on content hash rather than path.

- **Incremental Hash Computation**: The process of computing content hashes only for new files during import and adoption, not re-computing hashes for existing files that already have hashes in the baseline index.

## Hash Computation Strategy

### Algorithm Choice

**SHA-256** is chosen as the content hashing algorithm.

**Rationale**:
- Cryptographically secure (collision-resistant)
- Standard and widely supported (Foundation framework)
- Deterministic (same content always produces same hash)
- Fast enough for practical use (streaming computation)
- 256-bit output (32 bytes) is sufficient for duplicate detection

**Alternative Considered**: MD5, SHA-1
- **Rejected**: MD5 and SHA-1 are cryptographically broken (collision attacks possible)
- **Future**: SHA-256 is sufficient for P1; future slices may add additional hash algorithms if needed

### When Hashing Occurs

**During Import**: Content hashes are computed for each file being imported, after file copy succeeds and before index update.

**During Adoption**: Content hashes MAY be computed for existing media files during baseline scan if explicitly requested via flag (e.g., `--with-hashes`). Default adoption does not compute hashes (fast adoption without performance impact).

**During Detection**: Content hashes are computed for source files being detected, compared against hashes in baseline index. Hashes are NOT stored during detection (detection is read-only).

**Rationale**:
- Incremental computation during import/adoption avoids re-computing hashes for existing files
- Detection computes hashes for source files only (not library files, which already have hashes in index)
- Hash computation during import/adoption enables future detection runs to use pre-computed hashes

### Streaming Hash Computation

**Implementation**: Use Foundation's `CryptoKit` or `CommonCrypto` to compute SHA-256 hash in streaming fashion (read file in chunks, update hash incrementally).

**Rationale**:
- Constant memory usage regardless of file size
- Efficient for large files (video files, high-resolution images)
- No need to load entire file into memory

**Target**: Hash computation should handle files up to 10GB without memory issues (measured on reference dataset).

## Baseline Index Integration

### Index Format Extension (v1.1)

**Version 1.1** extends baseline index format to include optional hash fields in entries.

**Backward Compatibility**: Version 1.0 indexes (without hashes) remain valid. Version 1.1 indexes add optional `hash` field to entries.

**Proposed `index.json` Format (v1.1)**:

```json
{
  "version": "1.1",
  "created": "2026-01-27T10:00:00Z",
  "lastUpdated": "2026-01-27T15:30:00Z",
  "entryCount": 12543,
  "entries": [
    {
      "path": "2024/01/IMG_1234.jpg",
      "size": 2456789,
      "mtime": "2024-01-15T14:30:00Z",
      "hash": "sha256:abc123def456..."
    },
    {
      "path": "2024/01/VID_5678.mov",
      "size": 15678901,
      "mtime": "2024-01-15T14:35:00Z",
      "hash": "sha256:789ghi012jkl..."
    }
  ]
}
```

**Field Descriptions**:
- `version`: Index format version (string, "1.1" for hash support)
- `hash`: Optional SHA-256 hash of file content (string, format: "sha256:hexdigest", e.g., "sha256:abc123...")
- Other fields remain unchanged from version 1.0

**Design Decisions**:
- Hash field is optional (backward compatible with v1.0)
- Hash format includes algorithm prefix ("sha256:") for future extensibility
- Hash is stored as hex string (readable, debuggable)
- Entries without hash field are valid (graceful degradation)

### Index Read/Update Rules

**Reading Hashes**: When loading baseline index, hash fields are read if present. If hash field is missing, entry is valid but hash-based deduplication is not available for that file.

**Updating Hashes**: When updating baseline index during import or adoption, hash fields are added to new entries. Existing entries without hashes are not updated (incremental hash computation only for new files).

**Version Migration**: Version 1.0 indexes are automatically upgraded to version 1.1 format when first updated with hash data. Existing entries without hashes remain valid (no forced re-computation).

**Rationale**:
- Incremental hash computation avoids re-computing hashes for existing files
- Backward compatibility ensures existing indexes remain valid
- Version migration is automatic and transparent

## Behavior in Detect vs Import

### Detect Operations

**Hash Computation**: During detect operations, content hashes are computed for source files being detected (not library files, which already have hashes in index).

**Hash Comparison**: Source file hashes are compared against hashes in baseline index to identify duplicates. If baseline index entry has no hash, path-based comparison is used (graceful degradation).

**Hash Storage**: Hashes are NOT stored during detect operations (detect is read-only). Source file hashes are computed on-the-fly for comparison only.

**Duplicate Reporting**: Detection results include hash-based duplicate information (e.g., `duplicateOf: <hash>`, `duplicateOfPath: <library-path>`, `duplicateReason: "content_hash"`).

**Dry-Run**: In dry-run mode, hash computation for source files is allowed (read-only operation) to enable hash-based duplicate detection. Zero writes are performed (no index updates, no file modifications). Hash-based duplicate detection works in dry-run mode.

**Rationale**:
- Detect is read-only (no index updates)
- Hash computation for source files enables duplicate detection
- Dry-run allows read-only hash computation (zero writes, hash-based duplicate detection works)

### Import Operations

**Hash Computation**: During import operations, content hashes are computed for each file being imported, after file copy succeeds and before index update.

**Hash Storage**: Hashes are stored in baseline index entries for imported files (incremental hash computation and storage).

**Hash Comparison**: Source file hashes are compared against hashes in baseline index to identify duplicates before import. Duplicates are excluded from import candidates (same as detect).

**Index Update**: Baseline index is updated with hash fields for newly imported files (atomic update, write-then-rename pattern).

**Dry-Run**: In dry-run mode, hash computation is skipped (zero hash computations, zero writes). Dry-run shows what hash computations would be performed but does not compute hashes or update index.

**Rationale**:
- Import computes and stores hashes for future detection runs
- Hash computation after copy ensures file integrity
- Dry-run guarantees zero writes and zero hash computations

## Dry-Run Guarantees

### Zero Writes Guarantee

**Requirement**: `--dry-run` operations MUST perform zero writes to baseline index (no index updates, no file modifications).

**Implementation for Detect**:
- `detect --dry-run` allows hash computation for source files (read-only operation) to enable hash-based duplicate detection
- `detect --dry-run` performs zero writes (no index updates, no file modifications)
- Hash-based duplicate detection works in dry-run mode (read-only hash computation and comparison)

**Implementation for Import**:
- `import --dry-run` skips hash computation entirely (no file I/O for hashing, preview only)
- `import --dry-run` skips index updates (no index writes)
- `import --dry-run` shows what hash computations would be performed (preview only)

**Rationale**:
- Zero writes guarantee ensures dry-run never modifies index or files
- `detect --dry-run` benefits from hash-based duplicate detection (read-only operation)
- `import --dry-run` is preview-only (no hash computation, no writes)

### Preview Information

**Requirement**: Dry-run mode MUST show what operations would be performed (file count, estimated time, etc.).

**Implementation for Detect**:
- `detect --dry-run` output shows hash-based duplicate detection results (read-only operation)
- `detect --dry-run` JSON output includes hash-based duplicate information

**Implementation for Import**:
- `import --dry-run` output includes hash computation preview (e.g., "Would compute hashes for 100 files")
- `import --dry-run` output shows what index updates would be performed (e.g., "Would update index with 100 hash entries")
- `import --dry-run` JSON output includes `hashComputationPreview` field

**Rationale**:
- Users need visibility into what would happen
- Preview information helps users understand dry-run results
- JSON output enables automation and tooling

## Determinism and Idempotence Rules

### Determinism

**Requirement**: Hash-based duplicate detection MUST produce deterministic results (same source/library state produces same duplicate detection results).

**Implementation**:
- Hash computation is deterministic (same file content always produces same hash)
- Hash comparison is deterministic (same hashes always produce same comparison results)
- Detection results are deterministic (same inputs produce same outputs)

**Verification**: Tests verify that same file content produces same hash, and same source/library state produces same detection results.

### Idempotence

**Requirement**: Hash computation MUST be idempotent (same file content produces same hash, no duplicate hash computations for same file).

**Implementation**:
- Hash computation checks if hash already exists in index before computing (incremental computation)
- Re-running import/adoption on same files does not re-compute hashes (idempotent)
- Hash storage is idempotent (same file content produces same hash entry)

**Verification**: Tests verify that re-running import/adoption on same files does not re-compute hashes.

## Failure Modes and Fallback Behavior

### Hash Computation Failures

**Failure Modes**:
- File I/O errors (permission denied, file not found, disk errors)
- Hash computation errors (crypto library errors, memory errors)
- Interruption (Ctrl+C, system shutdown)

**Fallback Behavior**:
- Hash computation failures do not cause import/adoption to fail (hash is optional, import/adoption are primary operations)
- Failed hash computations are reported in output (error messages, JSON output)
- Files without hashes are still imported/adopted (graceful degradation)
- Future detection runs fall back to path-based detection for files without hashes

**Rationale**:
- Hash is performance optimization, not critical path
- Graceful degradation ensures operations succeed even if hashing fails
- Clear error reporting helps users understand failures

### Missing or Incomplete Hash Data

**Failure Modes**:
- Baseline index missing hash data (version 1.0 index, or hash computation not performed)
- Partial hash coverage (some files have hashes, others don't)
- Corrupted hash data (invalid hash format, hash mismatch)

**Fallback Behavior**:
- Operations fall back to path-based detection for files without hashes (graceful degradation)
- Operations report hash coverage in output (e.g., "Hash index: 10,000 entries, 95% coverage")
- Operations do not fail due to missing hash data (hash is optional)

**Rationale**:
- Backward compatibility with version 1.0 indexes
- Graceful degradation ensures operations work with partial hash data
- Clear reporting helps users understand hash coverage

### Index Update Failures

**Failure Modes**:
- Index write failures (disk full, permission denied, file system errors)
- Index corruption during write (interruption, disk errors)

**Fallback Behavior**:
- Index update failures do not cause import/adoption to fail (index is performance optimization, not critical path)
- Failed index updates are reported in output (error messages, JSON output)
- Future operations fall back to full scan if index is missing or corrupted

**Rationale**:
- Index is performance optimization, not critical path
- Graceful degradation ensures operations succeed even if index update fails
- Clear error reporting helps users understand failures

## Explicit Non-Goals

### No Deletion

**Non-Goal**: MediaHub MUST NOT delete duplicate files automatically. Hash-based deduplication identifies duplicates but does not remove them.

**Rationale**:
- Deletion is destructive action (requires explicit user confirmation per Constitution 3.3)
- Users may want to keep duplicates for backup or organizational reasons
- Deletion is out of scope for P1 (may be considered in future slices)

### No Auto-Merge

**Non-Goal**: MediaHub MUST NOT automatically merge or consolidate duplicate files. Hash-based deduplication identifies duplicates but does not modify files.

**Rationale**:
- Auto-merge is destructive action (requires explicit user confirmation per Constitution 3.3)
- Users may want to keep duplicates for backup or organizational reasons
- Auto-merge is out of scope for P1 (may be considered in future slices)

### No Media Modification

**Non-Goal**: MediaHub MUST NOT modify media files during hash computation or duplicate detection. Hash computation is read-only.

**Rationale**:
- Media files must remain unmodified (Constitution 4.1 Data Safety)
- Hash computation is read-only operation (no file modifications)
- Media modification is out of scope for P1 (may be considered in future slices)

### No Fuzzy or Perceptual Hashing

**Non-Goal**: MediaHub MUST NOT use fuzzy or perceptual hashing for duplicate detection. Only exact content hashing (SHA-256) is used.

**Rationale**:
- Fuzzy hashing is complex and may produce false positives/negatives
- Exact content hashing is sufficient for P1 (identifies exact duplicates)
- Fuzzy hashing is out of scope for P1 (may be considered in future slices)

**Exception**: If explicitly justified, perceptual hashing may be considered in future slices for near-duplicate detection (e.g., edited versions of same photo).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Content hashes are computed and stored in baseline index entries during import operations (100% of successfully imported files have hashes in index)
- **SC-002**: Content hashes MAY be computed and stored in baseline index entries during adoption operations if `--with-hashes` flag is used (100% of adopted files have hashes in index when flag is used). Default adoption does not compute hashes (fast adoption without performance impact)
- **SC-003**: Hash-based duplicate detection identifies duplicates correctly (100% accuracy: files with same content hash are identified as duplicates)
- **SC-004**: Hash-based duplicate detection produces deterministic results (same source/library state produces same duplicate detection results, verified by tests)
- **SC-005**: Hash computation is idempotent (same file content produces same hash, no duplicate hash computations for same file, verified by tests)
- **SC-006**: Dry-run operations perform zero writes to baseline index (verified by tests: no index writes in dry-run mode). `detect --dry-run` allows hash computation for source files (read-only operation, verified by tests). `import --dry-run` skips hash computation (zero hash computations, zero writes, verified by tests)
- **SC-007**: Hash computation does not significantly slow down import operations (measured: hash computation adds <10% overhead to import time on reference dataset)
- **SC-008**: Hash computation handles large files efficiently (measured: streaming hash computation, constant memory usage regardless of file size, verified with 10GB+ files)
- **SC-009**: Hash-based duplicate detection works with existing path-based known-items logic (both path-based and hash-based detection work together, verified by tests)
- **SC-010**: Baseline index format is backward compatible (version 1.0 indexes without hashes remain valid, version 1.1 indexes add optional hash fields, verified by tests)
- **SC-011**: Hash computation failures do not cause import or adoption operations to fail (hash is optional, import/adoption succeed even if hashing fails, verified by tests)
- **SC-012**: Operations gracefully degrade when hash data is missing or incomplete (fall back to path-based detection, no failure, clear reporting, verified by tests)
- **SC-013**: Hash-based duplicate information is included in detection results (both human-readable and JSON output, verified by tests)
- **SC-014**: Hash index statistics are included in status command output (hash coverage, entry count with hashes, verified by tests)
- **SC-015**: All existing core tests still pass after hash feature implementation (no regression in core functionality, verified by test suite)
- **SC-016**: Hash computation is deterministic (same file content always produces same hash, verified by tests with known test vectors)
- **SC-017**: Hash storage in baseline index is atomic and interruption-safe (write-then-rename pattern, no partial writes, verified by tests)
- **SC-018**: Hash computation does not modify source files (read-only hash computation, verified by tests)
- **SC-019**: Hash-based duplicate detection works correctly by comparing source file hashes against library baseline index hash set (files with same content hash are identified as duplicates regardless of source, verified by tests)
- **SC-020**: Hash computation during adoption with `--with-hashes` flag completes in reasonable time (measured: O(n) where n is number of files, verified on reference dataset with 10,000+ files). Default adoption without hash computation completes quickly (fast adoption without performance impact)

## Assumptions

- Users will primarily benefit from hash-based deduplication for libraries with 1,000+ files (smaller libraries may not show significant benefit)
- Hash computation will be performed incrementally during import (not as separate pass). Hash computation during adoption is optional and requires explicit flag (default adoption does not compute hashes)
- Hash computation will use streaming approach (constant memory usage regardless of file size)
- SHA-256 hash algorithm will be sufficient for P1 (no need for additional hash algorithms)
- Hash storage in baseline index will remain efficient (<100 bytes per entry on average, or index size growth remains reasonable)
- Hash computation failures will be rare (I/O errors, permission issues are uncommon)
- Users will not manually modify hash data in baseline index (hash is managed automatically by MediaHub)
- Library structure remains stable (files are not moved/renamed outside of MediaHub operations)
- Hash computation will not significantly slow down import operations (<10% overhead target)
- Users will understand hash-based duplicate detection as enhancement to path-based detection (not replacement)

## Safety Constraints

### Explicit Target Directories

- **Core Code**: Hash computation implementation MUST be in `Sources/MediaHub/` (new `ContentHashing.swift` or similar)
- **Core Code**: Baseline index extension (v1.1) MUST be in `Sources/MediaHub/BaselineIndex.swift` (extend existing `IndexEntry` struct)
- **CLI Code**: Hash information display MAY require changes in `Sources/MediaHubCLI/` (detect command, status command, JSON output)
- **Tests**: Hash feature tests MUST be in `Tests/MediaHubTests/` (new `ContentHashingTests.swift`, extend `BaselineIndexTests.swift`)
- **Documentation**: Hash feature documentation updates MAY be in `docs/` but MUST NOT modify existing ADRs without explicit justification

### Explicit "No Touch" Rules

- **DO NOT** modify existing path-based known-items logic (both path-based and hash-based detection work together)
- **DO NOT** modify existing baseline index read/update infrastructure (extend format, don't replace)
- **DO NOT** modify existing detection/import logic beyond adding hash computation calls (hash is transparent enhancement)
- **DO NOT** change existing JSON output schema (add hash fields without breaking existing fields)
- **DO NOT** modify Package.swift beyond adding dependencies if absolutely necessary (CryptoKit is part of Foundation)
- **DO NOT** modify existing specs/ or docs/ except for this Slice 8 spec
- **DO NOT** change existing CLI command structure beyond adding hash information to output
- **DO NOT** modify existing error types beyond adding hash-specific error messages
- **DO NOT** delete or modify source files during hash computation (read-only operation)
- **DO NOT** automatically delete or merge duplicate files (deduplication identifies duplicates, does not remove them)

### Explicit Validation Commands

- **Validation**: Run `swift test` to ensure all existing tests pass
- **Validation**: Run `scripts/smoke_cli.sh` to ensure CLI smoke tests pass with hash feature
- **Validation**: Performance testing: measure hash computation overhead on import operations (target: <10% overhead)
- **Validation**: Performance testing: measure hash computation time during adoption with `--with-hashes` flag on 10,000+ file library (target: O(n) performance). Verify default adoption completes quickly without hash computation
- **Validation**: Manual testing of hash-based duplicate detection (verify duplicates are identified correctly)
- **Validation**: Manual testing of dry-run operations (verify zero hash computations and zero writes)
- **Validation**: Manual testing of hash computation failures (verify graceful degradation, no operation failures)
- **Validation**: Manual testing of backward compatibility (verify version 1.0 indexes without hashes remain valid)
- **Validation**: Verify that hash computation is deterministic (same file content produces same hash, test with known test vectors)
- **Validation**: Verify that hash computation handles large files efficiently (test with 10GB+ files, verify constant memory usage)

## Non-Goals

- **P2 Features**: Automatic deletion of duplicate files (deletion requires explicit user confirmation)
- **P2 Features**: Automatic merging or consolidation of duplicate files (merge requires explicit user confirmation)
- **P2 Features**: Fuzzy or perceptual hashing for near-duplicate detection (exact content hashing only for P1)
- **P2 Features**: Hash computation as separate command or pass (hash computation is incremental during import, optional during adoption with explicit flag)
- **P2 Features**: Default hash computation during library adoption (default adoption does not compute hashes; optional `--with-hashes` flag may be implemented if needed)
- **P2 Features**: Multiple hash algorithms (SHA-256 only for P1)
- **P2 Features**: Hash-based file organization or renaming (hash is for deduplication only, not file organization)
- **P2 Features**: Hash-based file integrity verification (hash is for deduplication only, not integrity checking)
- **P2 Features**: Hash index optimization or compression beyond efficient JSON encoding
- **P2 Features**: Hash computation progress indicators or detailed progress reporting (basic progress is sufficient for P1)
- **P2 Features**: Hash computation cancellation or pause/resume (interruption handling is sufficient for P1)

## Risks & Mitigations

### Risk 1: Hash Computation Performance

**Description**: Hash computation may significantly slow down import and adoption operations, especially for large files or large libraries.

**Impact**: Import and adoption operations may become prohibitively slow, degrading user experience.

**Mitigation**:
- Streaming hash computation (constant memory usage, efficient for large files)
- Incremental hash computation (only compute for new files, not re-compute for existing files)
- Performance testing: measure hash computation overhead and optimize if needed
- Target: <10% overhead to import time (measured on reference dataset)
- Hash computation is optional: operations succeed even if hashing fails

**Acceptance**: Hash computation adds <10% overhead to import time, measured on reference dataset.

### Risk 2: Hash Storage Overhead

**Description**: Hash storage in baseline index may significantly increase index file size, impacting read/write performance.

**Impact**: Index file size may become large, slowing down index read/write operations.

**Mitigation**:
- Efficient JSON encoding (compact format, no unnecessary whitespace)
- Hash field is optional (backward compatible with v1.0)
- Target: <100 bytes per entry on average (SHA-256 hex string is 64 characters + "sha256:" prefix = ~71 bytes, plus JSON encoding overhead, acceptable for P1)
- Performance testing: measure index file size and operations for large libraries

**Acceptance**: Index file size remains reasonable for libraries up to 50,000 files (P1 target).

### Risk 3: Hash Collision (Extremely Rare)

**Description**: Two different files may have the same SHA-256 hash (hash collision), causing incorrect duplicate detection.

**Impact**: Incorrect duplicate detection may cause files to be incorrectly excluded from imports.

**Mitigation**:
- SHA-256 is cryptographically secure (collision probability is 2^-256, extremely rare)
- Hash collision is theoretical risk, not practical concern for P1
- If hash collision occurs, path-based detection may still identify files as different (both detection methods work together)
- Future enhancement: additional hash algorithms or file size comparison to reduce collision risk

**Acceptance**: Hash collision risk is acceptable for P1 (extremely rare, theoretical risk only).

### Risk 4: Hash Computation Failures

**Description**: Hash computation may fail due to I/O errors, permission issues, or interruptions, causing operations to fail or produce incomplete results.

**Impact**: Import and adoption operations may fail or produce incomplete hash data.

**Mitigation**:
- Hash computation failures do not cause operations to fail (hash is optional, import/adoption are primary operations)
- Failed hash computations are reported in output (error messages, JSON output)
- Graceful degradation: operations fall back to path-based detection for files without hashes
- Clear error reporting: users understand hash computation failures

**Acceptance**: Hash computation failures do not cause import/adoption to fail (hash is optional, graceful degradation).

### Risk 5: Backward Compatibility

**Description**: Baseline index format extension (v1.1) may break backward compatibility with version 1.0 indexes.

**Impact**: Existing version 1.0 indexes may become invalid, causing operations to fail.

**Mitigation**:
- Hash field is optional (version 1.0 indexes without hashes remain valid)
- Version migration is automatic and transparent (v1.0 indexes are upgraded to v1.1 when first updated)
- Existing entries without hashes remain valid (no forced re-computation)
- Backward compatibility testing: verify version 1.0 indexes work correctly

**Acceptance**: Version 1.0 indexes remain valid and work correctly with hash feature (backward compatible).

### Risk 6: Hash Computation During Adoption Performance

**Description**: Hash computation during adoption may be prohibitively slow for libraries with 100,000+ files.

**Impact**: Adoption operations may become prohibitively slow, degrading user experience.

**Mitigation**:
- Default adoption does not compute hashes (fast adoption without performance impact)
- Hash computation during adoption is optional and requires explicit flag (e.g., `--with-hashes`)
- If implemented, streaming hash computation (constant memory usage, efficient for large files)
- If implemented, performance testing: measure hash computation time during adoption on large libraries
- If implemented, target: O(n) performance where n is number of files (measured on reference dataset)
- If implemented, progress indicators: show hash computation progress during adoption (basic progress is sufficient for P1)
- Document performance implications for large libraries when using `--with-hashes` flag

**Acceptance**: Default adoption completes quickly without hash computation. If `--with-hashes` flag is implemented, hash computation during adoption completes in reasonable time (O(n) performance, measured on reference dataset with 10,000+ files).

## Constitutional Compliance

This specification adheres to the MediaHub Constitution:

- **3.3 Safe Operations**: Hash computation is read-only (no file modifications), dry-run performs zero writes always, `detect --dry-run` allows read-only hash computation, `import --dry-run` skips hash computation, graceful degradation on errors
- **4.1 Data Safety**: Hash computation does not modify source files, hash failures do not cause data loss, fallback ensures correctness
- **3.4 Deterministic Behavior**: Hash computation is deterministic (same file content produces same hash), hash-based duplicate detection produces identical results for same inputs
- **3.2 Transparent Storage**: Hash data is stored in human-readable JSON format in baseline index, can be inspected without MediaHub
- **3.1 Simplicity of User Experience**: Hash-based deduplication is transparent enhancement to path-based detection, no manual hash management required
- **4.2 Determinism**: Hash computation is idempotent (same file content produces same hash), hash-based duplicate detection is deterministic
- **3.5 Interoperability First**: Hash computation does not modify files, external tools can still read/write media files without affecting hash data
