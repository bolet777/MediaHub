# Implementation Plan: Hash Coverage & Maintenance (Slice 9)

**Feature**: Hash Coverage & Maintenance  
**Specification**: `specs/009-hash-coverage-maintenance/spec.md`  
**Slice**: 9 - Hash Coverage & Maintenance  
**Created**: 2026-01-27

## Plan Scope

This plan implements **Slice 9 only**, which adds a CLI command to compute missing content hashes for existing library media files and update the baseline index. This enables users to improve hash coverage incrementally without rescanning or rewriting everything.

**Key Features**:
- New CLI command: `mediahub index hash [--dry-run] [--limit N] [--yes]`
- Index-driven candidate selection (entries missing hash values)
- SHA-256 hash computation using existing `ContentHasher` (Slice 8)
- Atomic index updates (write-then-rename pattern)
- Dry-run mode: enumerate candidates only, zero hash computation, zero writes
- Explicit confirmation for non-dry-run operations (or `--yes` flag)
- Deterministic and idempotent behavior
- Status command integration: hash coverage statistics reporting

**Explicitly out of scope**:
- Duplicate deletion or merging
- Automatic cleanup or mutation of media files
- UI or desktop app work
- Performance refactors (unless strictly required)
- Changes to existing slices' behavior (output additions allowed)

## Constitutional Compliance

This plan adheres to the MediaHub Constitution:

- **Safe Operations (3.3)**: Dry-run performs zero writes and zero hash computation; explicit confirmation for write operations; non-interactive requires `--yes` flag
- **Data Safety (4.1)**: Hash computation is read-only (no file modifications); atomic index updates prevent partial state; interruption-safe operations
- **Deterministic Behavior (3.4)**: Same library state produces same results; stable file ordering; consistent hash computation
- **Transparent Storage (3.2)**: Index updates use existing transparent JSON format; hash data is human-readable
- **Simplicity of User Experience (3.1)**: Command is simple and explicit; clear messaging about what will be computed

## Architecture / Touch Points

### Core Layer (`Sources/MediaHub/`)

**New File**: `HashCoverageMaintenance.swift`
- `HashCoverageMaintenance` struct with core logic
- Candidate selection from baseline index
- Hash computation orchestration
- Index update preparation
- Error handling and validation

**Reuses Existing**:
- `ContentHasher` (Slice 8) for SHA-256 hash computation
- `BaselineIndexReader` (Slice 7) for loading index
- `BaselineIndexWriter` (Slice 7) for atomic index updates
- `BaselineIndex` (Slice 7, Slice 8) for index structure
- `LibraryOpening` (Slice 1) for library validation

**Modifies Existing**:
- No changes to existing core files; adds new core module (`HashCoverageMaintenance`)

### CLI Layer (`Sources/MediaHubCLI/`)

**New File**: `IndexCommand.swift`
- `IndexCommand` struct (top-level command)
- `IndexHashCommand` struct (hash subcommand)
- Flag parsing (`--dry-run`, `--limit`, `--yes`)
- Library context resolution (reuse `LibraryContext`)
- Confirmation handling (reuse pattern from `ImportCommand`)
- Non-interactive mode detection
- Output formatting (human-readable and JSON)

**Modifies Existing**:
- `main.swift`: Add `IndexCommand` to subcommands list
- `StatusCommand.swift`: Load baseline index and add hash coverage to output
- `OutputFormatting.swift`: Extend `StatusFormatter` to include hash coverage statistics

**Reuses Existing**:
- `LibraryContext` for library path resolution
- `ProgressIndicator` for progress reporting
- `OutputFormatting` patterns for JSON/human-readable output
- Confirmation prompt pattern from `ImportCommand`

### Test Layer (`Tests/MediaHubTests/`)

**New File**: `HashCoverageMaintenanceTests.swift`
- Unit tests for candidate selection
- Unit tests for hash computation orchestration
- Unit tests for index update logic
- Unit tests for idempotence
- Unit tests for dry-run mode
- Integration tests for full workflow
- Integration tests for interruption safety
- Integration tests for error handling

**Modifies Existing**:
- `StatusCommandTests.swift`: Add tests for hash coverage reporting

## Data Flow

### Normal Execution Flow

1. **Library Validation**
   - Resolve library path via `LibraryContext.requireLibraryPath()`
   - Open library via `LibraryContext.openLibrary()`
   - Validate library structure (contains `.mediahub/library.json`)

2. **Index Loading**
   - Load baseline index via `BaselineIndexReader.load()`
   - Validate index version (v1.0 or v1.1)
   - Handle missing/invalid index (error and exit)

3. **Candidate Selection**
   - Filter index entries: `entry.hash == nil`
   - Sort candidates by normalized path (deterministic ordering)
   - For each candidate, validate file exists at `libraryRoot + entry.path` (existence check only, does not open/read file contents)
   - Apply `--limit` if specified (take first N candidates)
   - Build candidate list with file paths and index entry references

4. **Dry-Run Mode** (if `--dry-run` flag)
   - Enumerate candidates (count, list paths)
   - File existence checks are allowed (metadata-only, does not open/read file contents for hashing)
   - Calculate statistics (current coverage, would-be coverage)
   - Output preview (human-readable or JSON)
   - Exit with code 0 (zero writes, zero hash computation, no file content reads)

5. **Confirmation** (if not dry-run)
   - Check if interactive mode (TTY available)
   - If non-interactive and no `--yes`: error and exit
   - If interactive and no `--yes`: prompt for confirmation
   - If user cancels: exit with code 0 (not an error)

6. **Hash Computation**
   - For each candidate (in deterministic order):
     - Compute SHA-256 hash via `ContentHasher.computeHash()`
     - Handle errors gracefully (log, continue, skip hash for that file)
     - Build updated `IndexEntry` with hash field populated
     - Update progress indicator
   - Collect all updated entries

7. **Index Update**
   - Create updated `BaselineIndex` with new hash values
   - Preserve existing hash values (never overwrite)
   - Update index version if needed (v1.0 → v1.1)
   - Write atomically via `BaselineIndexWriter.write()` (write-then-rename)

8. **Result Reporting**
   - Format output (human-readable or JSON)
   - Display summary (files processed, hashes computed, coverage statistics)
   - Exit with code 0

### Interruption Safety

- Hash computation can be interrupted at any time (Ctrl+C)
- Partial progress is not persisted (no intermediate index writes)
- Re-running after interruption resumes from beginning (idempotent)
- Atomic index write ensures no partial state on interruption

### Idempotence Guarantees

- Files with existing hash values are skipped (candidate selection filters `hash == nil`)
- Re-running on complete coverage produces no changes (no-op)
- Existing hash values are never overwritten (preserved in index update)
- Same library state produces same results (deterministic ordering)

## Milestones

### Milestone 1: CLI Command Structure

**Goal**: Establish CLI command structure and argument parsing.

**Tasks**:
- Create `IndexCommand.swift` with `IndexCommand` and `IndexHashCommand` structs
- Add `IndexCommand` to `main.swift` subcommands list
- Implement flag parsing (`--dry-run`, `--limit`, `--yes`)
- Implement library context resolution (reuse `LibraryContext`)
- Implement basic command routing (validation → execution)
- Add placeholder output formatting

**Validation**:
- `mediahub index hash --help` displays correct usage
- Flags are parsed correctly
- Library path resolution works
- Command exits with appropriate error codes

**Files**:
- `Sources/MediaHubCLI/IndexCommand.swift` (new)
- `Sources/MediaHubCLI/main.swift` (modify)

**Dependencies**: None

---

### Milestone 2: Core Candidate Selection and Hash Computation

**Goal**: Implement core logic for candidate selection and hash computation.

**Tasks**:
- Create `HashCoverageMaintenance.swift` with core struct
- Implement candidate selection (filter entries with `hash == nil`, sort by path)
- Implement file existence validation for candidates
- Integrate `ContentHasher` for hash computation
- Implement `--limit` support (process first N candidates)
- Implement error handling (file missing, permission denied, I/O errors)
- Add progress reporting during hash computation

**Validation**:
- Candidate selection correctly identifies entries missing hashes
- File existence validation works (skips missing files with error)
- Hash computation works for valid files
- `--limit` correctly limits number of files processed
- Errors are handled gracefully (non-fatal, continue with remaining files)

**Files**:
- `Sources/MediaHub/HashCoverageMaintenance.swift` (new)

**Dependencies**: Milestone 1

---

### Milestone 3: Index Update and Atomic Writes

**Goal**: Implement atomic index updates with hash data.

**Tasks**:
- Implement index update logic (create updated `BaselineIndex` with new hashes)
- Preserve existing hash values (never overwrite)
- Handle index version upgrade (v1.0 → v1.1 if hashes added)
- Integrate `BaselineIndexWriter.write()` for atomic writes
- Implement write failure handling (atomic write failed, disk full, permission denied)
- Add index validation after update

**Validation**:
- Index updates correctly add hash values to entries
- Existing hash values are preserved (not overwritten)
- Index version is updated correctly (v1.0 → v1.1)
- Atomic writes work correctly (no partial state)
- Write failures are handled gracefully (error message, exit code 1)

**Files**:
- `Sources/MediaHub/HashCoverageMaintenance.swift` (modify)

**Dependencies**: Milestone 2

---

### Milestone 4: Dry-Run Mode and Confirmation

**Goal**: Implement dry-run mode and explicit confirmation.

**Tasks**:
- Implement dry-run mode (enumerate candidates only, file existence checks allowed but no file content reads for hashing, zero writes)
- Implement non-interactive mode detection (TTY check)
- Implement confirmation prompt (reuse pattern from `ImportCommand`)
- Implement `--yes` flag handling (bypass confirmation)
- Update output formatting for dry-run mode
- Handle user cancellation gracefully (exit code 0)

**Validation**:
- Dry-run enumerates candidates without computing hashes
- Dry-run performs file existence checks only (does not open/read file contents)
- Dry-run performs zero writes to index
- Confirmation prompt appears when appropriate (not dry-run, not `--yes`, interactive)
- Non-interactive mode requires `--yes` flag (error if missing)
- User cancellation exits with code 0 (not an error)

**Files**:
- `Sources/MediaHubCLI/IndexCommand.swift` (modify)
- `Sources/MediaHub/HashCoverageMaintenance.swift` (modify)

**Dependencies**: Milestone 3

---

### Milestone 5: Output Formatting and Status Integration

**Goal**: Implement output formatting and status command integration.

**Tasks**:
- Implement human-readable output formatting (dry-run, normal, idempotent no-op)
- Implement JSON output formatting (reuse existing pattern)
- Extend `StatusFormatter` to include hash coverage statistics
- Update `StatusCommand` to load baseline index and compute hash coverage
- Add hash coverage to status output (human-readable and JSON)

**Validation**:
- Human-readable output matches spec examples
- JSON output matches spec examples
- Status command displays hash coverage statistics
- Status JSON includes hash coverage data
- Output is deterministic (same inputs produce same output)

**Files**:
- `Sources/MediaHubCLI/IndexCommand.swift` (modify)
- `Sources/MediaHubCLI/OutputFormatting.swift` (modify)
- `Sources/MediaHubCLI/StatusCommand.swift` (modify)

**Dependencies**: Milestone 4

---

### Milestone 6: Testing and Validation

**Goal**: Comprehensive test coverage for all functionality.

**Tasks**:
- Unit tests for candidate selection logic
- Unit tests for hash computation orchestration
- Unit tests for index update logic
- Unit tests for idempotence (re-running produces no changes)
- Unit tests for dry-run mode (zero writes, zero hash computation)
- Integration tests for full workflow (normal execution)
- Integration tests for interruption safety (Ctrl+C handling)
- Integration tests for error handling (file missing, permission denied, I/O errors)
- Integration tests for status command hash coverage reporting
- Edge case tests (empty library, complete coverage, partial coverage with limit)

**Validation**:
- All unit tests pass
- All integration tests pass
- Idempotence is verified (re-running produces identical results)
- Dry-run is verified (zero writes, zero hash computation)
- Interruption safety is verified (safe to interrupt, re-run works)
- Error handling is verified (graceful degradation, clear error messages)

**Files**:
- `Tests/MediaHubTests/HashCoverageMaintenanceTests.swift` (new)
- `Tests/MediaHubTests/StatusCommandTests.swift` (modify)

**Dependencies**: Milestone 5

## Test Strategy

### Unit Tests

**Candidate Selection**:
- Test filtering entries with `hash == nil`
- Test deterministic sorting by normalized path
- Test file existence validation (skip missing files)
- Test `--limit` application (process first N candidates)
- Test empty library (no candidates)
- Test complete coverage (no candidates)

**Hash Computation**:
- Test hash computation for valid files
- Test error handling (file missing, permission denied, I/O errors)
- Test streaming hash computation (large files, constant memory)
- Test symlink handling (resolve symlinks, validate within root)

**Index Update**:
- Test index update with new hash values
- Test preservation of existing hash values (never overwrite)
- Test index version upgrade (v1.0 → v1.1)
- Test atomic write pattern (write-then-rename)

**Idempotence**:
- Test re-running on complete coverage (no-op, no changes)
- Test re-running after partial completion (processes remaining files)
- Test existing hash values are never overwritten

**Dry-Run Mode**:
- Test dry-run enumerates candidates without computing hashes
- Test dry-run performs file existence checks only (no file content reads)
- Test dry-run performs zero writes
- Test dry-run output format (human-readable and JSON)

### Integration Tests

**Full Workflow**:
- Test normal execution (load index → select candidates → compute hashes → update index)
- Test with `--limit` flag (processes first N files)
- Test with `--yes` flag (bypasses confirmation)
- Test idempotent no-op (complete coverage, no changes)

**Interruption Safety**:
- Test interruption during hash computation (Ctrl+C)
- Test re-running after interruption (resumes from beginning)
- Test no partial index state after interruption

**Error Handling**:
- Test missing index file (error and exit)
- Test invalid index (corrupted, unsupported version)
- Test file missing during computation (error for that file, continue)
- Test permission denied (error for that file, continue)
- Test index write failure (error and exit, no partial update)

**Status Command Integration**:
- Test status command displays hash coverage (human-readable)
- Test status command includes hash coverage in JSON
- Test hash coverage calculation (percentage, entries with hash, total entries)

**Edge Cases**:
- Test empty library (0% coverage, no-op)
- Test complete coverage (100% coverage, idempotent no-op)
- Test partial coverage with limit (processes subset, reports updated coverage)
- Test very large files (streaming hash computation)
- Test symlinks (resolve correctly, hash target)

### Test Data Requirements

- Library with v1.0 index (no hashes)
- Library with v1.1 index (partial hashes)
- Library with complete hash coverage (100%)
- Library with missing files (entries referencing non-existent files)
- Library with permission issues (some files unreadable)
- Library with symlinks (valid and invalid)
- Library with very large files (>1GB)

## Risks / Safety Checks

### Risk 1: Large Library Performance

**Risk**: Hash computation for very large libraries (50,000+ files) may be slow.

**Mitigation**:
- Use streaming hash computation (constant memory, already implemented in `ContentHasher`)
- Support `--limit` flag for incremental operation
- Progress reporting shows current file and estimated progress
- Interruption-safe (can be stopped and resumed)

**Validation**:
- Test with large library (10,000+ files)
- Verify constant memory usage (no memory leaks)
- Verify progress reporting works correctly
- Verify interruption and resume works

### Risk 2: Atomic Write Failures

**Risk**: Index write may fail (disk full, permission denied), leaving partial state.

**Mitigation**:
- Use atomic write-then-rename pattern (already implemented in `BaselineIndexWriter`)
- Validate index after write (ensure integrity)
- Handle write failures gracefully (error message, exit code 1, no partial update)
- No intermediate writes (only final atomic write)

**Validation**:
- Test write failure scenarios (disk full, permission denied)
- Verify no partial index state on failure
- Verify error messages are clear and actionable

### Risk 3: Interruption Handling

**Risk**: User interruption (Ctrl+C) may leave system in inconsistent state.

**Mitigation**:
- No intermediate index writes (only final atomic write)
- Interruption-safe design (can be interrupted at any time)
- Re-running after interruption resumes from beginning (idempotent)
- No partial state persisted

**Validation**:
- Test interruption at various points (during candidate selection, hash computation, index write)
- Verify no partial state after interruption
- Verify re-running works correctly after interruption

### Risk 4: Existing Hash Overwrite

**Risk**: Accidentally overwriting existing hash values.

**Mitigation**:
- Candidate selection filters `hash == nil` only
- Index update preserves existing hash values (never overwrite)
- Explicit validation: existing hashes are never modified
- Idempotence tests verify no overwrites

**Validation**:
- Test with library containing partial hashes
- Verify existing hashes are preserved
- Verify idempotence (re-running produces no changes)

### Risk 5: Status Command Regression

**Risk**: Modifying status command may break existing functionality.

**Mitigation**:
- Minimal changes to `StatusCommand` (only add hash coverage)
- Reuse existing baseline index loading logic
- Add hash coverage only if index is available (graceful degradation)
- Comprehensive tests for status command (existing + new functionality)

**Validation**:
- Test status command with v1.0 index (no hash coverage, backward compatible)
- Test status command with v1.1 index (hash coverage displayed)
- Test status command with missing index (graceful degradation)
- Verify existing status functionality still works

### Risk 6: Dry-Run Implementation

**Risk**: Dry-run may accidentally compute hashes or write to index.

**Mitigation**:
- Explicit dry-run flag check (early return, no hash computation)
- Zero writes guarantee (no index updates in dry-run)
- Zero hash computation guarantee (enumerate only, file existence checks allowed but no file content reads)
- Comprehensive tests for dry-run mode

**Validation**:
- Test dry-run performs zero writes (verify index unchanged)
- Test dry-run performs zero hash computation (file existence checks allowed, but no file content reads for hashing)
- Test dry-run output format (matches spec)
- Verify dry-run is safe to run multiple times

## Non-Negotiable Constraints

1. **Safety First**: Dry-run must perform zero writes and zero hash computation (file existence checks allowed, but no file content reads). Non-interactive execution requires `--yes` flag for non-dry-run operations.

2. **Determinism**: Same library state must produce same results. Files must be processed in deterministic order (sorted by normalized path).

3. **Idempotence**: Re-running must produce no changes once coverage is complete. Existing hash values must never be overwritten.

4. **Atomic Writes**: Index updates must use atomic write-then-rename pattern. No partial state on interruption or failure.

5. **Minimal Changes**: Changes to existing commands (status) must be minimal and safe. No breaking changes to existing functionality.

6. **Index-Driven**: Candidate selection must be index-driven (load index, filter entries), not filesystem scan. File existence validation is per-candidate only.

7. **Error Handling**: Hash computation errors must be non-fatal (log, continue, skip hash for that file). Index write failures must be fatal (error and exit).

8. **Backward Compatibility**: Must work with v1.0 indexes (no hashes) and v1.1 indexes (partial hashes). No breaking changes to existing index format.
