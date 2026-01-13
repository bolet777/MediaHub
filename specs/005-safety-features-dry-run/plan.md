# Implementation Plan: Safety Features & Dry-Run Operations (Slice 5)

**Feature**: Safety Features & Dry-Run Operations  
**Specification**: `specs/005-safety-features-dry-run/spec.md`  
**Slice**: 5 - Safety Features & Dry-Run Operations  
**Created**: 2026-01-27

## Plan Scope

This plan implements **Slice 5 only**, which adds safety features to prevent accidental data loss and enable safe exploration of import operations. This includes:

- Dry-run mode for import operations (preview without copying)
- Explicit confirmation prompts for import operations
- Read-only guarantees for detection operations (explicit documentation)
- Safety-first error handling and interruption handling
- JSON output support for dry-run mode

**Explicitly out of scope**:
- Fine-grained item selection for import (deferred from Slice 4, still P2)
- Interactive item-by-item confirmation (P1 supports all-or-nothing confirmation only)
- Import rollback or undo functionality
- Safety features for library/source operations beyond import
- Advanced dry-run features (different collision policies, error simulation)
- Safety audit logs or event tracking
- Read-only mode for entire CLI (P1 focuses on detection and import safety)

## Constitutional Compliance

This plan adheres to the MediaHub Constitution:

- **Safe Operations (3.3)**: Explicit confirmation for destructive actions, dry-run preview, read-only guarantees
- **Data Safety (4.1)**: Safety-first error handling, no partial files, library integrity preservation
- **Deterministic Behavior (3.4)**: Dry-run preview must match actual import results
- **Transparent Storage (3.2)**: Safety features are explicit and understandable

## Work Breakdown

### Component 1: Dry-Run Mode in Import Execution

**Purpose**: Add dry-run support to the core import execution logic, enabling preview of import operations without file system modifications.

**Responsibilities**:
- Extend `ImportExecution` to support dry-run mode
- Ensure dry-run uses same logic as actual import (collision handling, destination mapping)
- Prevent any file operations on source files or library media files when dry-run is enabled
- Return preview results that match actual import results structure

**Requirements Addressed**:
- FR-001: Support `--dry-run` flag on import command
- FR-002: Display detailed preview information
- FR-003: Ensure zero file system modifications in dry-run
- FR-015: Ensure dry-run preview accurately reflects actual import
- FR-016: Validate that dry-run and actual import produce consistent results

**Key Decisions**:
- How to pass dry-run flag through import execution pipeline (parameter to `ImportExecution.execute()`)
- Whether to create separate preview-only execution path or use same logic with file operations disabled
- How to structure preview results to match actual import results (reuse `ImportResult` type)
- Whether dry-run should validate file accessibility (yes, to catch errors early)

**File Touch List**:
- `Sources/MediaHub/ImportExecution.swift` - Add dry-run parameter and logic
- `Tests/MediaHubTests/ImportExecutionTests.swift` - Add dry-run tests

**Validation Points**:
- Dry-run performs zero file operations on source files or library media files (verified by tests)
- Dry-run preview matches actual import results (same inputs produce same preview/execution)
- Dry-run handles errors gracefully (validation errors shown in preview)
- Dry-run works with all collision handling policies

**Risks & Open Questions**:
- Should dry-run validate file accessibility? (Yes, to catch errors early)
- Should dry-run show what errors would occur? (Yes, for comprehensive preview)
- How to ensure dry-run logic matches actual import logic? (Reuse same code paths, disable file operations)

**NON-NEGOTIABLE CONSTRAINTS**:
- Dry-run MUST perform zero file system modifications
- Dry-run preview MUST use same logic as actual import (same collision handling, same destination mapping)
- Changes to `ImportExecution.swift` MUST be minimal and focused on safety only
- NO changes to existing import behavior when dry-run is not enabled

---

### Component 2: CLI Dry-Run Flag and Preview Output

**Purpose**: Add `--dry-run` flag to CLI import command and format preview output for human-readable and JSON modes.

**Responsibilities**:
- Add `--dry-run` flag to `ImportCommand`
- Pass dry-run flag to import execution
- Format preview output in human-readable mode (show "DRY-RUN" indicator)
- Format preview output in JSON mode (include `dryRun: true` field)
- Ensure preview output shows source paths, destination paths, collision handling decisions

**Requirements Addressed**:
- FR-001: Support `--dry-run` flag on import command
- FR-002: Display detailed preview information
- FR-014: Support `--dry-run` flag with JSON output format

**Key Decisions**:
- How to format preview output in human-readable mode (table format, clear "DRY-RUN" indicator)
- How to structure JSON output with `dryRun: true` field (add to existing `ImportResult` JSON structure)
- Whether to show preview summary differently from actual import summary (yes, show "Would import" vs "Imported")

**File Touch List**:
- `Sources/MediaHubCLI/ImportCommand.swift` - Add `--dry-run` flag and preview output formatting
- `Sources/MediaHubCLI/OutputFormatting.swift` - Add preview output formatting functions
- `Tests/MediaHubTests/ImportExecutionTests.swift` - Add CLI dry-run integration tests (if needed)

**Validation Points**:
- `--dry-run` flag is recognized and passed to import execution
- Preview output is clearly marked as dry-run in human-readable mode
- JSON output includes `dryRun: true` field
- Preview output shows all relevant information (source paths, destination paths, collisions)

**Risks & Open Questions**:
- Should preview output format match actual import output format? (Similar but with "Would" language)
- How to handle preview output in progress indicators? (Show preview progress, but mark as dry-run)

**NON-NEGOTIABLE CONSTRAINTS**:
- CLI changes MUST be in `Sources/MediaHubCLI/` only
- NO changes to existing CLI command structure beyond adding `--dry-run` flag
- Preview output MUST be clearly distinguishable from actual import output

---

### Component 3: Confirmation Prompts for Import Operations

**Purpose**: Add explicit confirmation prompts before import operations, with `--yes` flag for non-interactive usage.

**Responsibilities**:
- Add `--yes` flag to `ImportCommand`
- Implement confirmation prompt logic (detect TTY, prompt for confirmation)
- Format confirmation prompt with import summary (item count, source, destination)
- Handle user input (yes/y to proceed, no/n to cancel, Ctrl+C to cancel)
- Ensure confirmation is skipped for dry-run and when `--yes` is provided
- Detect non-interactive mode and require `--yes` flag

**Requirements Addressed**:
- FR-004: Support `--yes` flag to bypass confirmation
- FR-005: Prompt for explicit confirmation before import operations
- FR-006: Display clear confirmation prompt with import summary
- FR-007: Handle user cancellation gracefully (exit code 0)
- FR-008: Detect non-interactive mode and require `--yes` flag

**Key Decisions**:
- How to detect TTY/non-interactive mode (use `isatty()` or Swift equivalent)
- What information to show in confirmation prompt (item count, source path, destination summary)
- How to handle user input (read from stdin, handle Ctrl+C gracefully)
- Exit code for user cancellation (0, since cancellation is not an error)

**File Touch List**:
- `Sources/MediaHubCLI/ImportCommand.swift` - Add `--yes` flag and confirmation logic
- `Sources/MediaHubCLI/CLIError.swift` - Add error type for non-interactive mode without `--yes`
- `Tests/MediaHubTests/ImportExecutionTests.swift` - Add confirmation prompt tests (if possible with test infrastructure)

**Validation Points**:
- Confirmation prompt appears when `--yes` is not provided and not in dry-run mode
- `--yes` flag bypasses confirmation
- Confirmation is skipped for dry-run operations
- Non-interactive mode requires `--yes` flag (fails with clear error if not provided)
- User cancellation exits with code 0

**Risks & Open Questions**:
- How to test confirmation prompts in automated tests? (May require test infrastructure for stdin simulation)
- Should confirmation prompt show detailed item list? (No, summary only for P1)
- How to handle confirmation in scripts that redirect stdin? (Detect non-interactive mode)

**NON-NEGOTIABLE CONSTRAINTS**:
- Confirmation logic MUST be in CLI layer only (`Sources/MediaHubCLI/`)
- NO changes to core import execution for confirmation (confirmation is CLI-only)
- Confirmation MUST be skipped for dry-run operations
- User cancellation MUST exit with code 0 (not an error)

---

### Component 4: Read-Only Guarantees Documentation

**Purpose**: Explicitly document and enforce read-only guarantees for detection operations in CLI help and user-facing messages.

**Responsibilities**:
- Update CLI help text to explicitly state detection is read-only
- Add read-only guarantee messages to detection command output
- Ensure detection operations never modify source files or copy media files (already enforced by core, but make explicit; detection may write result files in `.mediahub/` directory)
- Document read-only guarantee in user-facing documentation

**Requirements Addressed**:
- FR-009: Explicitly document that detect operations are read-only
- FR-010: Ensure detection operations never modify files or library state

**Key Decisions**:
- How to communicate read-only guarantee in CLI help (add to command description)
- Whether to show read-only indicator in detection output (optional, but helpful)
- How to document read-only guarantee in user-facing messages (clear, explicit language)

**File Touch List**:
- `Sources/MediaHubCLI/DetectCommand.swift` - Update help text and add read-only guarantee messages
- `Sources/MediaHubCLI/OutputFormatting.swift` - Add read-only indicator to detection output (optional)

**Validation Points**:
- CLI help explicitly states detection is read-only
- Detection command output includes read-only guarantee message (optional)
- Detection operations perform zero file system modifications to source files or media files (already enforced by core; detection may write result files in `.mediahub/` directory)

**Risks & Open Questions**:
- Should read-only guarantee be shown in every detection output? (Optional for P1, but helpful)
- How to test read-only guarantee? (Already enforced by core, but verify with tests)

**NON-NEGOTIABLE CONSTRAINTS**:
- NO changes to core detection logic (it's already read-only)
- Documentation changes MUST be in CLI layer only
- Read-only guarantee MUST be explicit and clear in user-facing messages

---

### Component 5: Safety-First Error Handling

**Purpose**: Ensure import operations handle errors gracefully without leaving library in inconsistent state, and handle interruptions (Ctrl+C) cleanly.

**Responsibilities**:
- Ensure import error handling preserves library integrity (no partial files)
- Handle interruption signals (SIGINT) gracefully during import
- Report what was imported before interruption
- Provide clear, actionable error messages
- Ensure error handling works correctly with dry-run mode

**Requirements Addressed**:
- FR-011: Provide clear, actionable error messages
- FR-012: Handle import interruptions gracefully
- FR-013: Ensure import errors don't leave library in inconsistent state

**Key Decisions**:
- How to handle SIGINT during import (catch signal, report progress, exit cleanly)
- How to report what was imported before interruption (show summary of completed imports)
- How to ensure no partial files on error (already handled by atomic file copy in core, but verify)
- How to format error messages for safety (clear, actionable, no technical jargon)

**File Touch List**:
- `Sources/MediaHubCLI/ImportCommand.swift` - Add interruption handling (SIGINT)
- `Sources/MediaHubCLI/CLIError.swift` - Add safety-specific error messages
- `Sources/MediaHubCLI/OutputFormatting.swift` - Add error message formatting for safety
- `Sources/MediaHub/ImportExecution.swift` - Verify error handling preserves library integrity (may already be correct)

**Validation Points**:
- Import errors don't leave partial files (verified by tests)
- Interruption handling reports what was imported before interruption
- Error messages are clear and actionable
- Error handling works correctly with dry-run mode

**Risks & Open Questions**:
- How to test interruption handling in automated tests? (May require signal simulation)
- Should interruption handling be in CLI layer or core? (CLI layer for signal handling, core for atomic operations)
- How to ensure atomic file copy on interruption? (Already handled by core, but verify)

**NON-NEGOTIABLE CONSTRAINTS**:
- Error handling MUST preserve library integrity (no partial files)
- Interruption handling MUST report progress before exiting
- Error messages MUST be clear and actionable (no technical jargon)
- NO changes to core error handling beyond verification (core already handles atomic operations)

---

## Implementation Sequence

### Phase 1: Core Dry-Run Support (Components 1-2)
**Goal**: Enable dry-run mode in import execution and CLI

1. Implement dry-run mode in `ImportExecution` (Component 1)
2. Add `--dry-run` flag to CLI import command (Component 2)
3. Format preview output for human-readable and JSON modes (Component 2)
4. Test dry-run accuracy (dry-run preview matches actual import)

**Dependencies**: None (foundation)

**Validation**: 
- Dry-run performs zero file operations
- Dry-run preview matches actual import results
- CLI `--dry-run` flag works correctly

---

### Phase 2: Confirmation Prompts (Component 3)
**Goal**: Add explicit confirmation prompts for import operations

1. Add `--yes` flag to CLI import command
2. Implement confirmation prompt logic
3. Detect non-interactive mode and require `--yes` flag
4. Test confirmation prompts in interactive and non-interactive modes

**Dependencies**: Phase 1 (dry-run must skip confirmation)

**Validation**:
- Confirmation prompt appears when appropriate
- `--yes` flag bypasses confirmation
- Non-interactive mode requires `--yes` flag
- User cancellation exits with code 0

---

### Phase 3: Read-Only Documentation (Component 4)
**Goal**: Explicitly document read-only guarantees for detection

1. Update CLI help text for detection command
2. Add read-only guarantee messages to detection output (optional)
3. Verify detection operations are read-only (already enforced by core)

**Dependencies**: None (documentation only)

**Validation**:
- CLI help explicitly states detection is read-only
- Detection operations perform zero file system modifications

---

### Phase 4: Safety-First Error Handling (Component 5)
**Goal**: Ensure graceful error handling and interruption handling

1. Verify import error handling preserves library integrity
2. Add interruption handling (SIGINT) to CLI import command
3. Format error messages for safety (clear, actionable)
4. Test error handling and interruption handling

**Dependencies**: Phase 1-2 (error handling must work with dry-run and confirmation)

**Validation**:
- Import errors don't leave partial files
- Interruption handling reports progress
- Error messages are clear and actionable

---

## File Touch Summary

### Core Files (Minimal Changes)
- `Sources/MediaHub/ImportExecution.swift` - Add dry-run parameter and logic (minimal changes, safety-focused only)

### CLI Files (Primary Changes)
- `Sources/MediaHubCLI/ImportCommand.swift` - Add `--dry-run` and `--yes` flags, confirmation logic, interruption handling
- `Sources/MediaHubCLI/DetectCommand.swift` - Update help text for read-only guarantee
- `Sources/MediaHubCLI/OutputFormatting.swift` - Add preview output formatting, error message formatting
- `Sources/MediaHubCLI/CLIError.swift` - Add safety-specific error types

### Test Files
- `Tests/MediaHubTests/ImportExecutionTests.swift` - Add dry-run tests, confirmation tests (if possible), error handling tests

### Documentation Files
- No changes to existing docs/ or specs/ (Slice 5 spec is new)

---

## Risk Mitigation

### Risk 1: Dry-Run Logic Divergence from Actual Import
**Mitigation**: Reuse same code paths for dry-run and actual import, disable file operations only. Add tests to verify dry-run preview matches actual import results.

### Risk 2: Confirmation Prompt Testing Difficulty
**Mitigation**: Test confirmation logic with unit tests where possible, manual testing for TTY detection. Document manual testing procedures.

### Risk 3: Interruption Handling Complexity
**Mitigation**: Use Swift signal handling APIs, test with manual interruption, ensure atomic file copy in core handles interruption correctly.

### Risk 4: Core Import Logic Changes
**Mitigation**: Keep core changes minimal and focused on safety only. Verify all existing tests still pass after changes.

---

## Success Criteria Validation

- **SC-001**: Dry-run preview accuracy verified by tests (dry-run preview matches actual import results)
- **SC-002**: Zero file operations on source files or library media files in dry-run verified by tests
- **SC-003**: Confirmation prompts tested manually and in automated tests where possible
- **SC-004**: `--yes` flag tested in non-interactive mode
- **SC-005**: Non-interactive mode error message tested
- **SC-006**: Read-only guarantee documented in CLI help and verified
- **SC-007**: Error handling tested to ensure no partial files
- **SC-008**: Interruption handling tested manually
- **SC-009**: Dry-run accuracy verified by tests
- **SC-010**: JSON output with `dryRun: true` tested
- **SC-011**: All existing tests pass after implementation
- **SC-012**: Safety features tested with all existing CLI commands and options

---

## Non-Negotiable Constraints

1. **CLI Code Location**: All CLI changes MUST be in `Sources/MediaHubCLI/` (NOT `Sources/MediaHub/`)
2. **Core Code Changes**: Core changes MUST be minimal and focused on safety only (dry-run mode in `ImportExecution.swift`)
3. **No Breaking Changes**: NO changes to existing CLI behavior when safety features are not used
4. **Test Coverage**: All safety features MUST be tested (dry-run accuracy, confirmation prompts, error handling)
5. **Constitutional Compliance**: All safety features MUST align with Constitution principles (Safe Operations, Data Safety)
