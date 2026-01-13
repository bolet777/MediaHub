# Implementation Plan: Library Adoption (Slice 6)

**Feature**: Library Adoption  
**Specification**: `specs/006-library-adoption/spec.md`  
**Slice**: 6 - Library Adoption  
**Created**: 2026-01-27

## Plan Scope

This plan implements **Slice 6 only**, which adds a safe "library adopt" operation to bootstrap MediaHub metadata into an existing library directory that already contains the user's full, final media collection organized in YYYY/MM. This includes:

- New CLI command: `mediahub library adopt <path> [--dry-run] [--yes]`
- Dry-run preview: read-only scan allowed for preview; zero writes
- Real adoption: confirmation required unless `--yes`; creates only `.mediahub/` metadata
- Baseline scan establishes existing media as "known" (via existing `LibraryContentQuery` mechanism)
- Idempotent behavior: re-running adopt is safe and clearly reported
- Compatibility: after adoption, `library open`, `detect`, `import` operate normally

**Explicitly out of scope**:
- Any reorganization of existing media, creating YYYY/MM folders, renames, moves, deletions
- Performance index / persistent baseline index (Slice 7)
- Content hashing / dedup (Slice 8)
- Photos.app/iPhone direct ingestion and any GUI
- Modifications to existing media files (absolute no-touch rule)

## Constitutional Compliance

This plan adheres to the MediaHub Constitution:

- **Safe Operations (3.3)**: Explicit confirmation for metadata creation, dry-run preview, no-touch guarantee for existing media files
- **Data Safety (4.1)**: No modification of existing media files, library integrity preservation, safe error handling
- **Deterministic Behavior (3.4)**: Baseline scan must be deterministic (same inputs produce same outputs), adoption must be idempotent
- **Transparent Storage (3.2)**: Adoption metadata is transparent and readable without MediaHub; existing media files remain directly accessible
- **Simplicity of User Experience (3.1)**: Adoption command is simple and explicit, with clear messaging about what will be created

## Work Breakdown

### Component 1: CLI Adoption Command Wiring

**Purpose**: Add `library adopt` subcommand to CLI with `--dry-run` and `--yes` flags, argument parsing, and command routing.

**Responsibilities**:
- Add `LibraryAdoptCommand` as new subcommand of `LibraryCommand`
- Parse `--dry-run` and `--yes` flags
- Validate target path (exists, is directory, has write permissions)
- Route to adoption execution (dry-run or real)
- Handle confirmation prompts (when not dry-run and not `--yes`)
- Detect non-interactive mode and require `--yes` flag
- Format output (human-readable and JSON)

**Requirements Addressed**:
- FR-001: Support `library adopt <path>` command
- FR-003: Support `--dry-run` flag
- FR-006: Support `--yes` flag
- FR-007: Prompt for explicit confirmation (when appropriate)
- FR-010: Detect non-interactive mode and require `--yes`
- FR-015: Validate target path exists and is directory
- FR-016: Validate target directory has write permissions
- FR-019: Support `--dry-run` with JSON output format
- FR-021: Display clear messaging about no media file modifications

**Key Decisions**:
- How to structure `LibraryAdoptCommand` (follow pattern of `LibraryCreateCommand`)
- How to detect non-interactive mode (use `isatty()` or Swift equivalent, check stdin)
- What information to show in confirmation prompt (metadata location, baseline scan summary)
- How to handle `--dry-run` and `--yes` together (dry-run skips confirmation, but `--yes` is accepted)
- How to format adoption output (human-readable vs JSON)

**File Touch List**:
- `Sources/MediaHubCLI/LibraryCommand.swift` - Add `LibraryAdoptCommand` to subcommands list
- `Sources/MediaHubCLI/LibraryCommand.swift` - Add `LibraryAdoptCommand` struct (or new file if preferred)

**Validation Points**:
- `library adopt` command is recognized and routed correctly
- `--dry-run` and `--yes` flags are parsed correctly
- Path validation works (exists, is directory, has write permissions)
- Confirmation prompt appears when appropriate (not dry-run, not `--yes`, interactive mode)
- Non-interactive mode detection works and requires `--yes` flag
- Output formatting works for both human-readable and JSON modes

**Risks & Open Questions**:
- How to test confirmation prompts? (Automated tests: branches logiques skip/require, TTY detection injectable/mockable. Manual tests: prompt interactif complet, Ctrl+C)
- Should confirmation prompt show detailed baseline scan preview? (Summary only for P1)
- How to handle confirmation in scripts that redirect stdin? (Detect non-interactive mode)

**NON-NEGOTIABLE CONSTRAINTS**:
- Majority of changes MUST be in `Sources/MediaHubCLI/` (new `adopt` subcommand, confirmation handling, dry-run preview); core changes allowed but MUST be minimal and adoption-only
- NO changes to existing CLI command structure beyond adding new `adopt` subcommand
- Confirmation logic MUST be in CLI layer only
- Dry-run MUST skip confirmation (always safe, no prompts)
- User cancellation MUST exit with code 0 (not an error)

---

### Component 2: Core Adoption Operations

**Purpose**: Implement core adoption logic that creates MediaHub metadata (`.mediahub/` directory and `library.json`) in an existing directory without modifying existing media files.

**Responsibilities**:
- Check if library is already adopted (idempotent check)
- Validate target directory (exists, is directory, has write permissions)
- Create `.mediahub/` directory structure (reuse `LibraryStructureCreator`)
- Generate library identifier (reuse `LibraryIdentifierGenerator`)
- Create and write `library.json` metadata (reuse `LibraryMetadata` and `LibraryMetadataSerializer`)
- Handle errors gracefully with rollback (if metadata creation fails, clean up)
- Ensure atomic metadata creation (no partial metadata files)

**Requirements Addressed**:
- FR-002: Create ONLY MediaHub metadata files (`.mediahub/` directory, `library.json`)
- FR-013: Ensure adoption is idempotent
- FR-014: Detect when library is already adopted
- FR-015: Validate target path exists and is directory
- FR-016: Validate target directory has write permissions
- FR-017: Provide clear, actionable error messages

**Key Decisions**:
- How to structure adoption logic (new `LibraryAdopter` struct, or extend existing `LibraryCreator`?)
- Whether to reuse `LibraryStructureCreator` or create adoption-specific structure creation
- How to handle idempotent adoption (check for existing `.mediahub/library.json` before creating)
- How to ensure atomic metadata creation (write to temp file, then move atomically)
- How to handle rollback on failure (delete `.mediahub/` directory if metadata write fails)

**File Touch List**:
- `Sources/MediaHub/LibraryAdoption.swift` - New file with `LibraryAdopter` struct (minimal core changes)
- OR extend `Sources/MediaHub/LibraryCreation.swift` - Add adoption-specific method (if preferred)

**Validation Points**:
- Adoption creates only `.mediahub/` metadata without modifying existing media files
- Idempotent adoption works (re-running on already adopted library returns clear message)
- Error handling preserves library integrity (no partial metadata on failure)
- Atomic metadata creation works (no corrupted `library.json` files)
- Rollback works correctly (cleanup on failure)

**Risks & Open Questions**:
- Should adoption reuse `LibraryStructureCreator` or have separate logic? (Reuse to minimize changes)
- How to ensure atomic metadata write? (Write to temp file, then move atomically)
- Should adoption validate existing media files? (No, just create metadata - existing files are assumed valid)
- How to handle partial metadata creation on interruption? (Rollback cleanup)

**NON-NEGOTIABLE CONSTRAINTS**:
- Core changes MUST be minimal and focused on adoption metadata creation only
- MUST reuse existing components (`LibraryStructureCreator`, `LibraryMetadata`, `LibraryMetadataSerializer`)
- MUST NOT modify existing core library creation logic beyond reusing components
- MUST NOT modify, move, rename, or delete any existing media files
- MUST ensure atomic metadata creation (no partial files)

---

### Component 3: Baseline Scan Integration

**Purpose**: Integrate baseline scan of existing media files during adoption to establish them as "known" for future detection runs. Adoption must ensure that future `detect` and `import` operations do not attempt to re-import existing media files. The mechanism is to scan library contents as baseline during adoption, and reuse the same `LibraryContentQuery.scanLibraryContents()` mechanism during detection to exclude existing files.

**Responsibilities**:
- Perform baseline scan during adoption (using existing `LibraryContentQuery.scanLibraryContents()`)
- Display baseline scan summary in adoption output (file count, scan scope)
- Ensure baseline scan is deterministic (path-based only, no hashing for P1)
- Support baseline scan preview in dry-run mode (read-only scan for counts/preview)
- Ensure adoption enables future detection/import to exclude existing files (via `LibraryContentQuery` integration - no persistent index needed for P1)

**Requirements Addressed**:
- FR-011: Perform baseline scan of all existing media files during adoption
- FR-012: Ensure baseline scan results are deterministic
- FR-018: Ensure baseline scan does not require content hashing (path-based only)
- FR-004: Display baseline scan information in dry-run preview
- FR-020: Ensure dry-run preview accurately reflects baseline scan scope

**Key Decisions**:
- How to integrate baseline scan into adoption workflow (call `LibraryContentQuery.scanLibraryContents()` during adoption)
- What baseline scan information to display (file count, scan scope summary)
- How to handle baseline scan in dry-run mode (read-only scan for preview, no writes)
- Whether to store baseline scan results (No for P1 - `LibraryContentQuery` already handles this during detection)

**File Touch List**:
- `Sources/MediaHub/LibraryAdoption.swift` - Add baseline scan call during adoption
- `Sources/MediaHubCLI/LibraryCommand.swift` - Format baseline scan summary in output

**Validation Points**:
- Baseline scan is performed during adoption (using existing `LibraryContentQuery`)
- Baseline scan results are deterministic (same library state produces same results)
- Baseline scan is path-based only (no content hashing)
- Baseline scan preview works in dry-run mode (read-only scan for counts)
- Future detection runs exclude existing media files (verified via `LibraryContentQuery` integration)

**Risks & Open Questions**:
- Should baseline scan results be stored? (No for P1 - `LibraryContentQuery` already handles this)
- How to handle very large libraries during baseline scan? (Performance is addressed in Slice 7)
- Should baseline scan validate media files? (No, just scan paths - assume existing files are valid)

**NON-NEGOTIABLE CONSTRAINTS**:
- MUST reuse existing `LibraryContentQuery.scanLibraryContents()` (no new scanning logic)
- MUST NOT perform content hashing during baseline scan (path-based only for P1)
- MUST NOT create performance baseline index (deferred to Slice 7)
- MUST ensure baseline scan is deterministic (same inputs produce same outputs)
- Dry-run baseline scan MUST be read-only (scanning/counting only, no writes)

---

### Component 4: Dry-Run Preview Support

**Purpose**: Implement dry-run preview for adoption operations that shows what would be created without performing any file system writes.

**Responsibilities**:
- Support dry-run mode in adoption workflow (preview without writes)
- Perform read-only baseline scan in dry-run mode (for preview counts)
- Format preview output (what metadata would be created, baseline scan summary)
- Ensure dry-run performs zero file system writes (no metadata creation, no writes)
- Support JSON output format for dry-run (include `dryRun: true` field)

**Requirements Addressed**:
- FR-003: Support `--dry-run` flag on `library adopt` command
- FR-004: Display detailed preview information when `--dry-run` is used
- FR-005: Ensure `--dry-run` operations perform zero file system writes
- FR-019: Support `--dry-run` flag with JSON output format
- FR-020: Ensure `--dry-run` preview accurately reflects actual adoption

**Key Decisions**:
- How to structure dry-run preview (separate preview function or parameter to adoption function)
- What preview information to show (metadata location, baseline scan summary, file counts)
- How to format preview output (human-readable vs JSON)
- How to ensure dry-run uses same logic as actual adoption (reuse same code paths, disable writes)

**File Touch List**:
- `Sources/MediaHub/LibraryAdoption.swift` - Add dry-run parameter and preview logic
- `Sources/MediaHubCLI/LibraryCommand.swift` - Format dry-run preview output

**Validation Points**:
- Dry-run performs zero file system writes (no metadata creation, no writes)
- Dry-run preview shows accurate information (what would be created, baseline scan summary)
- Dry-run preview matches actual adoption results (same inputs produce same preview/execution)
- JSON output includes `dryRun: true` field
- Dry-run baseline scan is read-only (scanning/counting only, no writes)

**Risks & Open Questions**:
- How to ensure dry-run preview matches actual adoption? (Reuse same code paths, disable writes only)
- Should dry-run validate file accessibility? (Yes, to catch errors early in preview)
- How to handle dry-run on already adopted library? (Show that library is already adopted)

**NON-NEGOTIABLE CONSTRAINTS**:
- Dry-run MUST perform zero file system writes (no metadata creation, no writes)
- Dry-run MAY perform read-only operations (scanning, counting, previewing files)
- Dry-run preview MUST use same logic as actual adoption (same metadata structure, same baseline scan scope)
- Dry-run MUST skip confirmation (always safe, no prompts)

---

### Component 5: Output Formatting and JSON Support

**Purpose**: Format adoption output for human-readable and JSON modes, including dry-run previews and baseline scan summaries.

**Responsibilities**:
- Format human-readable adoption output (success messages, metadata location, baseline scan summary)
- Format JSON adoption output (structured data with `dryRun: true` when applicable)
- Format confirmation prompts (clear messaging about what will be created)
- Format error messages (clear, actionable error messages)
- Format idempotent adoption messages (library already adopted)

**Requirements Addressed**:
- FR-004: Display detailed preview information when `--dry-run` is used
- FR-008: Display clear confirmation prompt showing what will be created
- FR-017: Provide clear, actionable error messages
- FR-019: Support `--dry-run` flag with JSON output format
- FR-021: Display clear messaging about no media file modifications

**Key Decisions**:
- How to structure JSON output (new `AdoptionResult` type or extend existing types)
- What information to include in JSON output (metadata, baseline scan summary, dry-run flag)
- How to format confirmation prompts (summary of what will be created)
- How to format error messages (clear, actionable, no technical jargon)

**File Touch List**:
- `Sources/MediaHubCLI/LibraryCommand.swift` - Format adoption output (human-readable and JSON)
- `Sources/MediaHubCLI/OutputFormatting.swift` - Add adoption output formatting functions (if needed)

**Validation Points**:
- Human-readable output is clear and informative
- JSON output is properly structured with `dryRun: true` when applicable
- Confirmation prompts show clear information about what will be created
- Error messages are clear and actionable
- Idempotent adoption messages are clear

**Risks & Open Questions**:
- Should JSON output match existing JSON output format? (Yes, for consistency)
- How to format baseline scan summary in output? (File count, scan scope summary)

**NON-NEGOTIABLE CONSTRAINTS**:
- Output formatting MUST be in CLI layer only (`Sources/MediaHubCLI/`)
- JSON output MUST include `dryRun: true` field when `--dry-run` is used
- Output MUST clearly indicate that no media files will be modified

---

### Component 6: Tests and Validation

**Purpose**: Implement comprehensive tests for adoption feature, including dry-run, confirmation, idempotence, and error handling.

**Responsibilities**:
- Test adoption creates only metadata without modifying existing media files
- Test dry-run performs zero file system writes
- Test confirmation prompts (automated: branches logiques skip/require, TTY detection mockable; manual: prompt interactif complet, Ctrl+C)
- Test idempotent adoption (re-running on already adopted library)
- Test error handling (path validation, permission errors, rollback on failure)
- Test baseline scan integration (deterministic results, path-based only)
- Test JSON output format (includes `dryRun: true` when applicable)
- Test compatibility with existing commands (`library open`, `detect`, `import`)

**Requirements Addressed**:
- All FR requirements (test coverage for all functional requirements)
- All SC success criteria (testable success criteria)

**Key Decisions**:
- How to test confirmation prompts? (Automated tests: branches logiques skip/require, TTY detection injectable/mockable. Manual tests: prompt interactif complet, Ctrl+C)
- How to test non-interactive mode detection? (Mock TTY detection - injectable/mockable for automated tests)
- How to test dry-run accuracy? (Compare dry-run preview with actual adoption results)
- How to test idempotent adoption? (Run adoption twice, verify consistent results)

**File Touch List**:
- `Tests/MediaHubTests/LibraryAdoptionTests.swift` - New test file for adoption feature
- `Tests/MediaHubTests/LibraryAdoptionTests.swift` - Test dry-run, confirmation, idempotence, error handling
- `Tests/MediaHubTests/LibraryAdoptionTests.swift` - Test baseline scan integration
- `Tests/MediaHubTests/LibraryAdoptionTests.swift` - Test JSON output format
- `Tests/MediaHubTests/LibraryAdoptionTests.swift` - Test compatibility with existing commands

**Validation Points**:
- All adoption tests pass
- Dry-run tests verify zero file system writes
- Idempotent adoption tests verify consistent results
- Error handling tests verify library integrity preservation
- Baseline scan tests verify deterministic results
- Compatibility tests verify existing commands work with adopted libraries

**Risks & Open Questions**:
- How to test confirmation prompts? (Automated tests: branches logiques skip/require, TTY detection injectable/mockable. Manual tests: prompt interactif complet, Ctrl+C)
- How to test non-interactive mode detection? (Mock TTY detection - injectable/mockable for automated tests)
- How to test very large libraries? (Performance tests may be limited)

**NON-NEGOTIABLE CONSTRAINTS**:
- Tests MUST be deterministic and non-flaky
- Tests MUST verify zero media file modifications
- Tests MUST verify dry-run accuracy (preview matches actual adoption)
- Tests MUST verify idempotent adoption
- All existing tests MUST still pass after adoption implementation

---

## Implementation Sequence

### Phase 1: Core Adoption Operations (Components 2, 3)
**Goal**: Implement core adoption logic that creates metadata and performs baseline scan

1. Create `LibraryAdopter` struct with adoption logic (Component 2)
   - Reuse `LibraryStructureCreator`, `LibraryMetadata`, `LibraryMetadataSerializer`
   - Implement idempotent check (detect already adopted library)
   - Implement atomic metadata creation with rollback
2. Integrate baseline scan into adoption workflow (Component 3)
   - Call `LibraryContentQuery.scanLibraryContents()` during adoption
   - Format baseline scan summary for output
3. Test core adoption operations
   - Test metadata creation without modifying existing media files
   - Test idempotent adoption
   - Test error handling and rollback

**Dependencies**: None (foundation)

**Validation**:
- Adoption creates only `.mediahub/` metadata
- Baseline scan is performed and deterministic
- Idempotent adoption works correctly
- Error handling preserves library integrity

---

### Phase 2: CLI Command Wiring and Confirmation (Components 1, 5)
**Goal**: Add CLI command with confirmation prompts

1. Add `LibraryAdoptCommand` to CLI (Component 1)
   - Parse `--dry-run` and `--yes` flags
   - Validate target path (exists, is directory, has write permissions)
   - Route to adoption execution
2. Implement confirmation prompts (Component 1)
   - Detect non-interactive mode and require `--yes` flag
   - Format confirmation prompt with adoption summary
   - Handle user input (yes/y, no/n, Ctrl+C)
3. Format adoption output (Component 5)
   - Human-readable output (success messages, baseline scan summary)
   - Error messages (clear, actionable)
4. Test CLI command and confirmation
   - Test command parsing and routing
   - Test confirmation prompts (automated: branches logiques, TTY detection mockable; manual: prompt interactif)
   - Test non-interactive mode detection

**Dependencies**: Phase 1 (core adoption operations)

**Validation**:
- CLI command is recognized and routed correctly
- Confirmation prompts appear when appropriate
- Non-interactive mode requires `--yes` flag
- Output formatting works correctly

---

### Phase 3: Dry-Run Preview Support (Components 4, 5)
**Goal**: Implement dry-run preview for adoption operations

1. Add dry-run support to adoption workflow (Component 4)
   - Add dry-run parameter to adoption functions
   - Implement preview logic (read-only scan, no writes)
   - Ensure dry-run uses same logic as actual adoption
2. Format dry-run preview output (Component 5)
   - Human-readable preview (show "DRY-RUN" indicator, preview information)
   - JSON preview (include `dryRun: true` field)
3. Test dry-run preview
   - Test zero file system writes in dry-run
   - Test dry-run preview accuracy (matches actual adoption)
   - Test JSON output with `dryRun: true`

**Dependencies**: Phase 1-2 (core adoption and CLI command)

**Validation**:
- Dry-run performs zero file system writes
- Dry-run preview matches actual adoption results
- JSON output includes `dryRun: true` field
- Dry-run skips confirmation

---

### Phase 4: Comprehensive Testing and Validation (Component 6)
**Goal**: Complete test coverage and validation

1. Implement comprehensive tests (Component 6)
   - Test adoption creates only metadata without modifying existing media files
   - Test dry-run performs zero file system writes
   - Test confirmation prompts (automated: branches logiques, TTY detection mockable; manual: prompt interactif complet, Ctrl+C)
   - Test idempotent adoption
   - Test error handling and rollback
   - Test baseline scan integration
   - Test JSON output format
   - Test compatibility with existing commands
2. Validate all success criteria
   - Verify all SC success criteria are met
   - Run existing tests to ensure no regression
   - Manual testing of confirmation prompts and non-interactive mode

**Dependencies**: Phase 1-3 (all adoption features)

**Validation**:
- All adoption tests pass
- All existing tests still pass
- Success criteria are met
- Compatibility with existing commands verified

---

## File Touch Summary

### Core Files (Minimal Changes)
- `Sources/MediaHub/LibraryAdoption.swift` - **NEW FILE** - Core adoption logic (minimal, focused on metadata creation only)
  - Reuses: `LibraryStructureCreator`, `LibraryMetadata`, `LibraryMetadataSerializer`, `LibraryContentQuery`

### CLI Files (Primary Changes)
- `Sources/MediaHubCLI/LibraryCommand.swift` - Add `LibraryAdoptCommand` subcommand
  - Parse `--dry-run` and `--yes` flags
  - Implement confirmation prompts
  - Format adoption output (human-readable and JSON)
- `Sources/MediaHubCLI/OutputFormatting.swift` - Add adoption output formatting functions (if needed)
- `Sources/MediaHubCLI/CLIError.swift` - Add adoption-specific error types (if needed)

### Test Files
- `Tests/MediaHubTests/LibraryAdoptionTests.swift` - **NEW FILE** - Comprehensive adoption tests
  - Test metadata creation, dry-run, confirmation, idempotence, error handling, baseline scan, JSON output

### Documentation Files
- No changes to existing docs/ or specs/ (Slice 6 spec is new)

---

## Risk Mitigation

### Risk 1: Partial Metadata Creation on Failure
**Mitigation**: Implement atomic metadata creation (write to temp file, then move atomically). Implement rollback cleanup (delete `.mediahub/` directory if metadata write fails). Test error handling thoroughly.

### Risk 2: Dry-Run Logic Divergence from Actual Adoption
**Mitigation**: Reuse same code paths for dry-run and actual adoption, disable writes only. Add tests to verify dry-run preview matches actual adoption results.

### Risk 3: Confirmation Prompt Testing Difficulty
**Mitigation**: Automated tests focus on branches logiques (skip/require confirmation), TTY detection injectable/mockable. Manual tests cover full interactive prompts and Ctrl+C handling. Document manual testing procedures.

### Risk 4: Large Library Performance
**Mitigation**: Baseline scan uses existing `LibraryContentQuery` which is already optimized. Performance optimizations for very large libraries are deferred to Slice 7. Note performance expectations in spec (reasonable time for typical library sizes).

### Risk 5: Existing Media File Modification
**Mitigation**: Absolute no-touch rule enforced at code level. All file operations are restricted to `.mediahub/` directory only. Comprehensive tests verify zero media file modifications.

### Risk 6: Idempotent Adoption Edge Cases
**Mitigation**: Clear idempotent check (detect existing `.mediahub/library.json` before creating). Test idempotent adoption thoroughly (re-run multiple times, verify consistent results).

### Risk 7: Core Logic Changes
**Mitigation**: Keep core changes minimal and focused on adoption metadata creation only. Reuse existing components (`LibraryStructureCreator`, `LibraryMetadata`, etc.). Verify all existing tests still pass after changes.

---

## Success Criteria Validation

- **SC-001**: Test adoption creates only `.mediahub/` metadata without modifying existing media files (zero media file modifications verified by tests)
- **SC-002**: Test dry-run preview accuracy (dry-run preview matches actual adoption results)
- **SC-003**: Test zero file system writes in dry-run (zero file operations verified by tests)
- **SC-004**: Test confirmation prompts (manual testing and automated tests where possible)
- **SC-005**: Test `--yes` flag in non-interactive mode
- **SC-006**: Test non-interactive mode error message
- **SC-007**: Test baseline scan determinism (same library state produces identical results)
- **SC-008**: Test idempotent adoption (re-running produces consistent results)
- **SC-009**: Test future detection runs exclude existing media files (verified via `LibraryContentQuery` integration)
- **SC-010**: Test error handling preserves library integrity (no partial metadata)
- **SC-011**: Test dry-run preview accuracy (matches actual adoption behavior)
- **SC-012**: Test JSON output includes `dryRun: true` field
- **SC-013**: Run all existing tests to ensure no regression
- **SC-014**: Test compatibility with existing CLI commands and options

---

## Non-Negotiable Constraints

1. **CLI Code Location**: The majority of changes MUST be in `Sources/MediaHubCLI/` (new `adopt` subcommand, confirmation handling, dry-run preview)
2. **Core Code Changes**: Core changes MUST be minimal and focused strictly on adoption metadata creation and validation only (reuse existing `LibraryStructureCreator`, `LibraryMetadata`, etc., without refactoring existing core logic)
3. **No Media File Modifications**: Absolute no-touch rule - MUST NOT modify, move, rename, or delete any existing media files during adoption
4. **No Breaking Changes**: NO changes to existing CLI behavior when adoption is not used
5. **Test Coverage**: All adoption features MUST be tested (dry-run, confirmation, idempotence, error handling, baseline scan)
6. **Constitutional Compliance**: All adoption features MUST align with Constitution principles (Safe Operations, Data Safety, Deterministic Behavior)
7. **Baseline Scan**: MUST reuse existing `LibraryContentQuery.scanLibraryContents()` (no new scanning logic, path-based only, no hashing for P1)
8. **Dry-Run Safety**: Dry-run MUST perform zero file system writes (read-only operations allowed for preview, but no writes)
9. **Idempotent Adoption**: Adoption MUST be idempotent (re-running on already adopted library is safe and returns clear outcome)
10. **Atomic Metadata Creation**: Metadata creation MUST be atomic (no partial `library.json` files)
