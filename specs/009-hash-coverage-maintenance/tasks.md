# Implementation Tasks: Hash Coverage & Maintenance (Slice 9)

**Feature**: Hash Coverage & Maintenance  
**Specification**: `specs/009-hash-coverage-maintenance/spec.md`  
**Plan**: `specs/009-hash-coverage-maintenance/plan.md`  
**Slice**: 9 - Hash Coverage & Maintenance  
**Created**: 2026-01-27

## Task Organization

Tasks are organized by implementation sequence and follow the milestones defined in the plan. Each task is:
- Small and focused on a single deliverable
- Sequential (dependencies are clear)
- Traceable to spec sections (referenced by section name)
- Traceable to plan milestones (referenced by milestone number)
- Includes explicit safety, determinism, and idempotence verification

## NON-NEGOTIABLE CONSTRAINTS FOR SLICE 9

**CRITICAL**: The following constraints MUST be followed during Slice 9 implementation:

1. **Safety First**:
   - Dry-run MUST perform zero writes and zero hash computation (file existence checks allowed, but no file content reads)
   - Non-interactive execution requires `--yes` flag for non-dry-run operations
   - Atomic index updates only (write-then-rename pattern)

2. **Determinism & Idempotence**:
   - Files MUST be processed in deterministic order (sorted by normalized path)
   - Existing hash values MUST never be overwritten
   - Re-running on complete coverage MUST produce no changes (no-op)
   - Same library state MUST produce same results

3. **Index-Driven**:
   - Candidate selection MUST be index-driven (load index, filter entries), not filesystem scan
   - File existence validation is per-candidate only (metadata check)

4. **Minimal Changes**:
   - Status command changes MUST be minimal and additive only
   - No breaking changes to existing functionality
   - Reuse existing patterns (ContentHasher, BaselineIndexReader/Writer, confirmation handling)

---

## Task 1: CLI Scaffolding + Help Text

**Plan Reference**: Milestone 1 (lines 166-188)  
**Spec Reference**: User-Facing CLI Contract (lines 35-77)  
**Dependencies**: None

### Task 1.1: Create IndexCommand.swift Structure

**Objective**: Create new `IndexCommand.swift` file with `IndexCommand` and `IndexHashCommand` structs, basic argument parsing.

**Files**:
- `Sources/MediaHubCLI/IndexCommand.swift` (new)

**Implementation**:
- Create `IndexCommand` struct conforming to `ParsableCommand`
- Create `IndexHashCommand` struct as subcommand
- Add `@Flag` properties for `--dry-run`, `--yes`
- Add `@Option` property for `--limit` (optional Int)
- Add `@Flag` property for `--json` (or `-j`) following the same pattern as other MediaHubCLI commands (e.g., `detect --json`, `import --json`)
- Implement basic `run()` method with placeholder (library validation, error handling)

**Done when**:
- `swift build` succeeds
- `mediahub index hash --help` displays correct usage with all flags
- Command structure is recognized by ArgumentParser
- Flags are parsed correctly (verified by help text)

**Validation**:
- Run `swift build`
- Run `mediahub index hash --help` and verify output matches spec

---

### Task 1.2: Wire IndexCommand into main.swift

**Objective**: Add `IndexCommand` to CLI subcommands list.

**Files**:
- `Sources/MediaHubCLI/main.swift` (modify)

**Implementation**:
- Add `IndexCommand.self` to `MediaHubCommand.subcommands` array
- Ensure command is accessible at top level

**Done when**:
- `swift build` succeeds
- `mediahub index --help` displays `index` command with `hash` subcommand
- `mediahub index hash --help` works correctly

**Validation**:
- Run `swift build`
- Run `mediahub index --help` and verify `hash` subcommand is listed
- Run `mediahub index hash --help` and verify help text displays

---

### Task 1.3: Implement Library Context Resolution

**Objective**: Resolve library path using existing global library resolution mechanism.

**Files**:
- `Sources/MediaHubCLI/IndexCommand.swift` (modify)

**Implementation**:
- Resolve the library path using the existing global library resolution mechanism (env var / default / shared option group if already present), without introducing any new flags
- Use `LibraryContext.requireLibraryPath(from: nil)` or equivalent to leverage existing resolution
- Use `LibraryContext.openLibrary(at: libraryPath)` for library opening
- Handle library validation errors (not found, invalid structure)
- Exit with code 1 on library errors

**Done when**:
- Library path resolution works using existing global mechanism
- Library validation works (detects invalid libraries, reports clear errors)
- Error messages are clear and actionable
- Exit codes are correct (1 for errors)

**Validation**:
- Test with valid library (via existing resolution mechanism) → succeeds
- Test with invalid library → error message, exit code 1
- Test with `MEDIAHUB_LIBRARY` environment variable → resolves correctly

---

## Task 2: Core Candidate Selection (Index-Driven) + Deterministic Ordering

**Plan Reference**: Milestone 2 (lines 192-216)  
**Spec Reference**: Behavior - Candidate selection (line 59), Determinism - Stable file ordering (line 104)  
**Dependencies**: Task 1

### Task 2.1: Create HashCoverageMaintenance.swift Structure

**Objective**: Create new `HashCoverageMaintenance.swift` file with core struct and basic structure.

**Files**:
- `Sources/MediaHub/HashCoverageMaintenance.swift` (new)

**Implementation**:
- Create `HashCoverageMaintenance` struct
- Add initializer taking library root path
- Add placeholder methods for candidate selection
- Define result types for hash coverage operations

**Done when**:
- `swift build` succeeds
- `HashCoverageMaintenance` struct is defined
- File compiles without errors

**Validation**:
- Run `swift build`

---

### Task 2.2: Implement Index Loading and Candidate Selection

**Objective**: Load baseline index and select entries missing hash values, with deterministic ordering.

**Files**:
- `Sources/MediaHub/HashCoverageMaintenance.swift` (modify)

**Implementation**:
- Use `BaselineIndexReader.load()` to load index from library
- Filter index entries: `entry.hash == nil`
- Sort candidates by normalized path (deterministic ordering: `entries.sorted { $0.path < $1.path }`)
- Return candidate list with entry references and file paths
- Handle missing/invalid index (throw error)

**Done when**:
- Candidate selection correctly identifies entries with `hash == nil`
- Candidates are sorted by normalized path (deterministic order)
- Missing index throws appropriate error
- Invalid index (corrupted, unsupported version) throws appropriate error

**Validation**:
- Unit test: library with v1.0 index (all entries missing hashes) → all entries selected
- Unit test: library with v1.1 index (partial hashes) → only entries without hashes selected
- Unit test: candidates are sorted by path (deterministic ordering verified)
- Unit test: missing index throws error

---

### Task 2.3: Implement File Existence Validation

**Objective**: Validate that candidate files exist at referenced paths (metadata check only, no content reads).

**Files**:
- `Sources/MediaHub/HashCoverageMaintenance.swift` (modify)

**Implementation**:
- For each candidate entry, construct absolute path: `libraryRoot + entry.path`
- Use `FileManager.fileExists(atPath:)` to check existence (metadata-only check)
- Filter out candidates where file does not exist
- Collect validation errors for missing files (non-fatal, continue with remaining)

**Done when**:
- File existence validation works (skips missing files)
- Missing files are reported but do not stop processing
- Only metadata checks are performed (no file content reads)
- Validation errors are collected and can be reported

**Validation**:
- Unit test: candidate with existing file → included in validated candidates
- Unit test: candidate with missing file → excluded, error collected
- Unit test: mixed candidates (some missing) → only existing files included

---

### Task 2.4: Implement --limit Support

**Objective**: Apply `--limit` flag to process only first N candidates (deterministic ordering preserved).

**Files**:
- `Sources/MediaHub/HashCoverageMaintenance.swift` (modify)
- `Sources/MediaHubCLI/IndexCommand.swift` (modify)

**Implementation**:
- Add `limit: Int?` parameter to candidate selection method
- Apply `.prefix(limit)` to sorted candidate list if limit is specified
- Pass `--limit` value from CLI to core method
- Preserve deterministic ordering (limit applied after sorting)

**Done when**:
- `--limit` correctly limits number of candidates processed
- Deterministic ordering is preserved (first N by sorted path)
- Limit of 0 or negative values handled gracefully (error or no-op)

**Validation**:
- Unit test: `--limit 10` on library with 100 candidates → processes first 10 (by sorted path)
- Unit test: `--limit` not specified → processes all candidates
- Unit test: deterministic ordering preserved with limit

---

## Task 3: Hash Computation Orchestration (Non-Dry-Run Only)

**Plan Reference**: Milestone 2 (lines 192-216)  
**Spec Reference**: Behavior - Hash computation (line 60), Safety - Dry-run mode (line 83)  
**Dependencies**: Task 2

### Task 3.1: Integrate ContentHasher for Hash Computation

**Objective**: Integrate existing `ContentHasher` to compute SHA-256 hashes for candidate files.

**Files**:
- `Sources/MediaHub/HashCoverageMaintenance.swift` (modify)

**Implementation**:
- For each validated candidate (in deterministic order):
  - Construct file URL: `libraryRoot.appendingPathComponent(entry.path)`
  - Call `ContentHasher.computeHash(for: url, allowedRoot: libraryRootURL)`
  - Handle hash computation errors gracefully (log, continue, skip hash for that file)
  - Build updated `IndexEntry` with hash field populated
- Collect all successfully computed hashes
- Collect errors for failed hash computations (non-fatal)

**Done when**:
- Hash computation works for valid files
- Hash computation errors are handled gracefully (non-fatal, continue with remaining files)
- Updated entries include hash field in correct format (`sha256:<hexdigest>`)
- Errors are collected and can be reported

**Validation**:
- Unit test: valid file → hash computed successfully, entry updated with hash
- Unit test: file with permission error → error collected, processing continues
- Unit test: file with I/O error → error collected, processing continues
- Unit test: hash format is correct (`sha256:` prefix + 64 hex chars)

---

### Task 3.2: Add Progress Reporting During Hash Computation (OPTIONAL)

**Objective**: Display progress during hash computation (file count, current file). This is optional unless explicitly required by the spec.

**Files**:
- `Sources/MediaHubCLI/IndexCommand.swift` (modify)

**Implementation**:
- Use existing `ProgressIndicator` pattern (reuse from other commands)
- Display progress: `[████████████████████] 100% (X / Y files)`
- Display current file being processed: `Current: <path>`
- Update progress after each file hash computation
- Note: This task is optional; the slice can be completed without implementing progress output

**Done when**:
- Progress indicator displays correctly during hash computation (if implemented)
- Current file path is shown (if implemented)
- Progress updates incrementally (X / Y files) (if implemented)
- Progress works correctly with `--limit` (if implemented)

**Validation**:
- Manual test: run command on library with multiple files → progress displays correctly (if implemented)
- Test with `--limit` → progress shows correct total count (if implemented)

---

### Task 3.3: Enforce Dry-Run Zero Hash Computation

**Objective**: Ensure dry-run mode performs zero hash computation (enumerate only, no file content reads).

**Files**:
- `Sources/MediaHub/HashCoverageMaintenance.swift` (modify)
- `Sources/MediaHubCLI/IndexCommand.swift` (modify)

**Implementation**:
- Add `dryRun: Bool` parameter to hash computation method
- Early return in dry-run mode: skip hash computation entirely
- In dry-run mode, only enumerate candidates (count, list paths)
- Verify no calls to `ContentHasher.computeHash()` in dry-run mode

**Done when**:
- Dry-run mode skips all hash computation
- No file content reads occur in dry-run mode
- Dry-run only enumerates candidates (count, statistics)
- File existence checks are allowed (metadata-only)

**Validation**:
- Unit test: dry-run mode → no calls to `ContentHasher.computeHash()`
- Unit test: dry-run mode → candidates enumerated, statistics calculated
- Integration test: dry-run on library → zero file content reads (verified using mocks/spies or structured seams)

---

## Task 4: Atomic Index Update + Version Bump Rules

**Plan Reference**: Milestone 3 (lines 219-241)  
**Spec Reference**: Safety - Atomic index updates (line 84), Idempotence - No duplicate work (line 111)  
**Dependencies**: Task 3

### Task 4.1: Implement Index Update Logic

**Objective**: Create updated `BaselineIndex` with new hash values, preserving existing hashes.

**Files**:
- `Sources/MediaHub/HashCoverageMaintenance.swift` (modify)

**Implementation**:
- Use `BaselineIndex.updating(with: newEntries)` method (existing from Slice 7/8)
- Create updated entries with hash fields populated
- Preserve existing hash values (never overwrite: existing entries with hashes are not modified)
- Handle index version upgrade (v1.0 → v1.1 if hashes added, v1.1 → v1.1 if already v1.1)

**Done when**:
- Index update correctly adds hash values to entries missing hashes
- Existing hash values are preserved (not overwritten)
- Index version is updated correctly (v1.0 → v1.1 if hashes added)
- Index version remains v1.1 if already v1.1

**Validation**:
- Unit test: v1.0 index with new hashes → updated to v1.1, hashes added
- Unit test: v1.1 index with partial hashes → existing hashes preserved, new hashes added
- Unit test: existing hash values never overwritten (verify by comparing before/after)

---

### Task 4.2: Implement Atomic Index Write

**Objective**: Write updated index atomically using existing `BaselineIndexWriter` pattern.

**Files**:
- `Sources/MediaHub/HashCoverageMaintenance.swift` (modify)

**Implementation**:
- Use `BaselineIndexWriter.write(index, to: indexPath, libraryRoot: libraryRoot)` for atomic write
- Handle write failures gracefully (atomic write failed, disk full, permission denied)
- Validate index after write (ensure integrity)
- Only write if not in dry-run mode

**Done when**:
- Atomic writes work correctly (write-then-rename pattern)
- Write failures are handled gracefully (error message, exit code 1, no partial update)
- Index is validated after write
- Dry-run mode performs zero writes (verified)

**Validation**:
- Unit test: index write succeeds → index file updated atomically
- Unit test: write failure (disk full) → error thrown, no partial index file
- Unit test: dry-run mode → no calls to `BaselineIndexWriter.write()`
- Integration test: interrupted write → no partial index state

---

### Task 4.3: Verify Idempotence (No Overwrite of Existing Hashes)

**Objective**: Explicitly verify that existing hash values are never overwritten.

**Files**:
- `Sources/MediaHub/HashCoverageMaintenance.swift` (modify)
- `Tests/MediaHubTests/HashCoverageMaintenanceTests.swift` (new)

**Implementation**:
- Add explicit validation: before updating entry, check if hash already exists
- If hash exists, skip update for that entry (preserve existing)
- Add unit test: library with complete hash coverage → no changes, no-op

**Done when**:
- Existing hash values are explicitly preserved (validation check)
- Re-running on complete coverage produces no changes (no-op verified)
- Unit test passes: complete coverage → zero files processed, zero hashes computed

**Validation**:
- Unit test: library with 100% hash coverage → candidate selection returns empty list
- Unit test: re-running on complete coverage → no index writes, no changes
- Integration test: idempotent no-op verified end-to-end

---

## Task 5: Confirmation / --yes / Non-Interactive Guards

**Plan Reference**: Milestone 4 (lines 245-263)  
**Spec Reference**: Safety - Explicit confirmation (line 86), Error Conditions - Non-interactive (line 77)  
**Dependencies**: Task 4

### Task 5.1: Implement Non-Interactive Mode Detection

**Objective**: Detect non-interactive mode (no TTY) and require `--yes` flag for non-dry-run operations.

**Files**:
- `Sources/MediaHubCLI/IndexCommand.swift` (modify)

**Implementation**:
- Reuse non-interactive detection pattern from `ImportCommand` (use `isatty()` or equivalent)
- Check: if not dry-run AND not interactive AND no `--yes` → error and exit
- Error message: "Non-interactive mode requires --yes flag for index hash operations"
- Exit with code 1 on non-interactive error

**Done when**:
- Non-interactive mode is detected correctly (no TTY)
- Non-interactive without `--yes` → error message, exit code 1
- Dry-run mode bypasses non-interactive check (always safe)
- `--yes` flag bypasses non-interactive check

**Validation**:
- Manual test: run in non-interactive mode without `--yes` → error message
- Manual test: run in non-interactive mode with `--yes` → proceeds
- Manual test: run with `--dry-run` in non-interactive mode → proceeds (no confirmation needed)

---

### Task 5.2: Implement Confirmation Prompt

**Objective**: Prompt for explicit confirmation before writing to index (reuse pattern from `ImportCommand`).

**Files**:
- `Sources/MediaHubCLI/IndexCommand.swift` (modify)

**Implementation**:
- Reuse confirmation prompt pattern from `ImportCommand.promptForConfirmation()`
- Display confirmation message: "Will compute hashes for N files. This will update the baseline index. Proceed? (yes/no): "
- Handle user input: "yes"/"y" → proceed, "no"/"n" → cancel, Ctrl+C → cancel
- User cancellation exits with code 0 (not an error)
- Skip confirmation if `--yes` flag provided
- Skip confirmation if `--dry-run` flag provided

**Done when**:
- Confirmation prompt appears when appropriate (not dry-run, not `--yes`, interactive)
- User confirmation ("yes"/"y") → proceeds with hash computation
- User cancellation ("no"/"n" or Ctrl+C) → exits with code 0
- `--yes` flag bypasses confirmation
- `--dry-run` flag skips confirmation

**Validation**:
- Manual test: run without `--yes` in interactive mode → prompt appears
- Manual test: type "yes" → proceeds
- Manual test: type "no" → exits with code 0
- Manual test: Ctrl+C → exits with code 0
- Manual test: `--yes` flag → no prompt, proceeds

---

## Task 6: Output Formatting (Human + JSON Mode)

**Plan Reference**: Milestone 5 (lines 265-285)  
**Spec Reference**: Expected Outputs (lines 116-277)  
**Dependencies**: Task 5

### Task 6.1: Implement Human-Readable Output Formatting

**Objective**: Format output for human-readable mode (dry-run, normal, idempotent no-op).

**Files**:
- `Sources/MediaHubCLI/IndexCommand.swift` (modify)
- `Sources/MediaHubCLI/OutputFormatting.swift` (modify)

**Implementation**:
- Create `HashCoverageFormatter` struct conforming to `OutputFormatter` protocol
- Implement human-readable formatting for:
  - Dry-run mode: "Hash Coverage Preview", current coverage, files to process, "No hashes will be computed"
  - Normal mode (with confirmation): "Hash Coverage Update", current coverage, confirmation prompt
  - Normal mode (execution): "Hash Coverage Update", progress, completed summary
  - Idempotent no-op: "Hash Coverage Update", "All files already have hash values", no-op summary
- Format matches spec examples exactly

**Done when**:
- Human-readable output matches spec examples (dry-run, normal, idempotent no-op)
- Output includes all required information (library path, index version, coverage statistics, summary)
- Output is deterministic (same inputs produce same output format)

**Validation**:
- Manual test: dry-run mode → output matches spec example
- Manual test: normal mode → output matches spec example
- Manual test: idempotent no-op → output matches spec example
- Unit test: output format is deterministic (same inputs → same output)

---

### Task 6.2: Implement JSON Output Formatting

**Objective**: Format output for JSON mode using the `--json` flag (defined locally for index hash command, consistent with MediaHubCLI architecture).

**Files**:
- `Sources/MediaHubCLI/IndexCommand.swift` (modify)
- `Sources/MediaHubCLI/OutputFormatting.swift` (modify)

**Implementation**:
- Extend `HashCoverageFormatter` to support JSON output
- Implement JSON encoding for:
  - Dry-run mode: `dryRun: true`, current coverage, would-update statistics
  - Normal mode: `dryRun: false`, coverage before/after, summary
  - Idempotent no-op: `dryRun: false`, coverage unchanged, `reason: "all_files_already_have_hashes"`
- Use `JSONEncoder` with `.prettyPrinted` and `.sortedKeys` (existing pattern)
- JSON structure matches spec examples exactly

**Done when**:
- JSON output matches spec examples (dry-run, normal, idempotent no-op)
- JSON output is valid and parseable
- JSON output includes all required fields
- JSON output is deterministic (same inputs produce same JSON)

**Validation**:
- Manual test: `--json --dry-run` → JSON output matches spec example
- Manual test: `--json` (normal mode) → JSON output matches spec example
- Manual test: `--json` (idempotent no-op) → JSON output matches spec example
- Unit test: JSON output is valid JSON (parseable)
- Unit test: JSON output is deterministic

---

## Task 7: Status Hash Coverage Integration

**Plan Reference**: Milestone 5 (lines 265-285)  
**Spec Reference**: Integration with Status Command (lines 279-315)  
**Dependencies**: Task 6

### Task 7.1: Load Baseline Index in Status Command

**Objective**: Load baseline index in `StatusCommand` to compute hash coverage statistics.

**Files**:
- `Sources/MediaHubCLI/StatusCommand.swift` (modify)

**Implementation**:
- Use `BaselineIndexLoader.tryLoadBaselineIndex(libraryRoot:)` to load index
- Handle missing/invalid index gracefully (hash coverage not available, continue with existing status)
- Compute hash coverage statistics: `index.hashCoverage`, `index.hashEntryCount`, `index.entryCount`
- Pass hash coverage data to formatter

**Done when**:
- Baseline index is loaded in status command
- Missing/invalid index is handled gracefully (no hash coverage displayed, existing status still works)
- Hash coverage statistics are computed correctly (percentage, entries with hash, total entries)

**Validation**:
- Manual test: status command with v1.0 index → existing status works, no hash coverage (backward compatible)
- Manual test: status command with v1.1 index → hash coverage displayed
- Manual test: status command with missing index → existing status works, no hash coverage

---

### Task 7.2: Extend StatusFormatter to Include Hash Coverage

**Objective**: Add hash coverage statistics to status output (human-readable and JSON).

**Files**:
- `Sources/MediaHubCLI/OutputFormatting.swift` (modify)

**Implementation**:
- Extend `StatusFormatter` to accept optional hash coverage data
- Add hash coverage to human-readable output: "Hash Coverage: X% (Y / Z entries)"
- Add hash coverage to JSON output: `hashCoverage: { percentage, entriesWithHash, totalEntries }`
- Hash coverage is optional (only displayed if index is available)
- Output format matches spec examples exactly

**Done when**:
- Human-readable status output includes hash coverage (when available)
- JSON status output includes hash coverage (when available)
- Hash coverage is optional (missing index → no hash coverage, existing status still works)
- Output format matches spec examples

**Validation**:
- Manual test: `mediahub status` with v1.1 index → hash coverage displayed
- Manual test: `mediahub status --json` with v1.1 index → hash coverage in JSON
- Manual test: `mediahub status` with missing index → existing status works, no hash coverage
- Unit test: status formatter includes hash coverage when provided

---

## Task 8: Tests (Unit + Integration) Mapped to Success Criteria

**Plan Reference**: Milestone 6 (lines 287-318)  
**Spec Reference**: Success Criteria (lines 341-349), Edge Cases (lines 317-330), Failure Modes (lines 332-339)  
**Dependencies**: Task 7

### Task 8.1: Unit Tests for Candidate Selection

**Objective**: Unit tests for candidate selection logic, deterministic ordering, file existence validation.

**Files**:
- `Tests/MediaHubTests/HashCoverageMaintenanceTests.swift` (new)

**Implementation**:
- Test candidate selection filters entries with `hash == nil`
- Test deterministic ordering (sorted by normalized path)
- Test file existence validation (skips missing files)
- Test `--limit` support (processes first N candidates)
- Test empty library (no candidates)
- Test complete coverage (no candidates)

**Done when**:
- All unit tests pass
- Candidate selection logic is fully tested
- Deterministic ordering is verified
- Edge cases are covered (empty library, complete coverage)

**Validation**:
- Run `swift test` → all unit tests pass
- Test coverage includes all candidate selection scenarios

---

### Task 8.2: Unit Tests for Hash Computation and Index Update

**Objective**: Unit tests for hash computation orchestration, index update logic, idempotence.

**Files**:
- `Tests/MediaHubTests/HashCoverageMaintenanceTests.swift` (modify)

**Implementation**:
- Test hash computation for valid files
- Test error handling (file missing, permission denied, I/O errors)
- Test index update preserves existing hashes (never overwrite)
- Test index version upgrade (v1.0 → v1.1)
- Test idempotence (re-running on complete coverage → no-op)
- Test atomic write pattern

**Done when**:
- All unit tests pass
- Hash computation logic is fully tested
- Index update logic is fully tested
- Idempotence is verified

**Validation**:
- Run `swift test` → all unit tests pass
- Test coverage includes all hash computation and index update scenarios

---

### Task 8.3: Unit Tests for Dry-Run Mode

**Objective**: Unit tests verifying dry-run performs zero writes and zero hash computation.

**Files**:
- `Tests/MediaHubTests/HashCoverageMaintenanceTests.swift` (modify)

**Implementation**:
- Test dry-run enumerates candidates without computing hashes
- Test dry-run performs file existence checks only (no file content reads)
- Test dry-run performs zero writes to index
- Test dry-run output format (human-readable and JSON)
- Test dry-run is safe to run multiple times

**Done when**:
- All unit tests pass
- Dry-run safety is fully verified (zero writes, zero hash computation)
- Dry-run output format is verified

**Validation**:
- Run `swift test` → all unit tests pass
- Test coverage includes all dry-run scenarios
- Verify no file content reads in dry-run (mocks or file system monitoring)

---

### Task 8.4: Integration Tests for Full Workflow

**Objective**: Integration tests for complete workflow (normal execution, interruption safety, error handling).

**Files**:
- `Tests/MediaHubTests/HashCoverageMaintenanceTests.swift` (modify)

**Implementation**:
- Test full workflow: load index → select candidates → compute hashes → update index
- Test with `--limit` flag (processes first N files)
- Test with `--yes` flag (bypasses confirmation)
- Test idempotent no-op (complete coverage, no changes)
- Test interruption safety: simulate partial completion (process N of M files, then stop) and verify re-run idempotence (same results as if completed successfully)
- Test error handling (missing index, invalid index, file errors, write failures)

**Done when**:
- All integration tests pass
- Full workflow is tested end-to-end
- Interruption safety is verified (simulated partial completion, re-run idempotence)
- Error handling is verified

**Validation**:
- Run `swift test` → all integration tests pass
- Test coverage includes all workflow scenarios
- Interruption safety is verified (simulated partial completion, re-run produces same results)

---

### Task 8.5: Integration Tests for Status Command Hash Coverage

**Objective**: Integration tests for status command hash coverage reporting.

**Files**:
- `Tests/MediaHubTests/StatusCommandTests.swift` (modify)

**Implementation**:
- Test status command with v1.0 index (no hash coverage, backward compatible)
- Test status command with v1.1 index (hash coverage displayed)
- Test status command with missing index (existing status works, no hash coverage)
- Test status command JSON output includes hash coverage (when available)

**Done when**:
- All status command tests pass
- Hash coverage integration is verified
- Backward compatibility is verified (v1.0 index, missing index)

**Validation**:
- Run `swift test` → all status command tests pass
- Test coverage includes all status command scenarios
- Backward compatibility is verified

---

### Task 8.6: Edge Case and Failure Mode Tests

**Objective**: Tests for all edge cases and failure modes from spec.

**Files**:
- `Tests/MediaHubTests/HashCoverageMaintenanceTests.swift` (modify)

**Implementation**:
- Test empty library (0% coverage, no-op)
- Test complete coverage (100% coverage, idempotent no-op)
- Test partial coverage with limit (processes subset, reports updated coverage)
- Test file missing during computation (error for that file, continues)
- Test permission denied (error for that file, continues)
- Test index write failure (error and exit, no partial update)

**Done when**:
- All edge case tests pass
- All failure mode tests pass
- Edge cases and failure modes are fully covered

**Validation**:
- Run `swift test` → all edge case and failure mode tests pass
- Test coverage includes all edge cases and failure modes from spec

---

## Task Completion Checklist

Before considering Slice 9 complete, verify:

- [ ] All tasks completed (Tasks 1-8)
- [ ] All unit tests pass (`swift test`)
- [ ] All integration tests pass
- [ ] Dry-run performs zero writes and zero hash computation (verified)
- [ ] Determinism verified (same inputs → same results)
- [ ] Idempotence verified (re-running on complete coverage → no-op)
- [ ] Existing hash values never overwritten (verified)
- [ ] Status command hash coverage works (human-readable and JSON)
- [ ] Backward compatibility verified (v1.0 index, missing index)
- [ ] All safety guarantees met (dry-run, confirmation, atomic writes)
- [ ] All success criteria from spec met (lines 341-349)
