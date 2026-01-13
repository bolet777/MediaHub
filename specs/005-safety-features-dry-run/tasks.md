# Implementation Tasks: Safety Features & Dry-Run Operations (Slice 5)

**Feature**: Safety Features & Dry-Run Operations  
**Specification**: `specs/005-safety-features-dry-run/spec.md`  
**Plan**: `specs/005-safety-features-dry-run/plan.md`  
**Slice**: 5 - Safety Features & Dry-Run Operations  
**Created**: 2026-01-27

## Task Organization

Tasks are organized by component and follow the implementation sequence defined in the plan. Each task is:
- Small and focused on a single deliverable
- Sequential (dependencies are clear)
- Traceable to plan components (referenced by component number)
- Includes only P1 scope: dry-run mode, confirmation prompts, read-only guarantees documentation, safety-first error handling

## NON-NEGOTIABLE CONSTRAINTS FOR SLICE 5

**CRITICAL**: The following constraints MUST be followed during Slice 5 implementation:

1. **CLI Code Location**:
   - CLI changes MUST be in `Sources/MediaHubCLI/` (NOT `Sources/MediaHub/`)
   - Core changes MUST be minimal and focused on safety only (dry-run mode in `ImportExecution.swift`)

2. **File Protection**:
   - NO files in `Sources/MediaHub/` may be deleted, moved, or renamed (except minimal changes to `ImportExecution.swift` for dry-run)
   - NO changes to existing CLI command structure beyond adding new flags
   - NO changes to existing error types beyond adding safety-specific error messages

3. **Safety First**:
   - Dry-run MUST perform zero file system modifications to source files or library media files
   - Dry-run preview MUST match actual import results (same inputs produce same preview/execution)
   - Confirmation MUST be skipped for dry-run operations
   - Error handling MUST preserve library integrity

4. **Backward Compatibility**:
   - NO breaking changes to existing CLI behavior when safety features are not used
   - All existing tests MUST still pass after implementation

---

## Component 1: Dry-Run Mode in Import Execution

**Plan Reference**: Component 1 (lines 45-79)  
**Dependencies**: None (Foundation)

### Task 1.1: Add Dry-Run Parameter to ImportExecution
**Priority**: P1
- **Objective**: Add `dryRun: Bool` parameter to `ImportExecution.execute()` method signature
- **Deliverable**: Updated `ImportExecution.execute()` method signature with optional `dryRun` parameter (defaults to `false` for backward compatibility)
- **File**: `Sources/MediaHub/ImportExecution.swift`
- **Test**: Verify method signature compiles and existing calls still work (backward compatible)
- **Acceptance**: Method signature includes `dryRun: Bool = false` parameter, all existing code compiles without changes

### Task 1.2: Implement Dry-Run Logic in ImportExecution
**Priority**: P1
- **Objective**: Modify import execution logic to skip file operations on source files or library media files when `dryRun` is `true`, but perform all other operations (validation, destination mapping, collision handling)
- **Deliverable**: Import execution that performs all logic except file copy when `dryRun` is `true`
- **File**: `Sources/MediaHub/ImportExecution.swift`
- **Test**: Unit test that verifies dry-run performs zero file operations on source files or library media files but returns same result structure
- **Acceptance**: When `dryRun` is `true`, no source files or library media files are created/modified/deleted, but `ImportResult` is returned with same structure as actual import. Note: Dry-run may create temporary files or logs, but never modifies source files or copies media files.

### Task 1.3: Ensure Dry-Run Uses Same Logic as Actual Import
**Priority**: P1
- **Objective**: Verify that dry-run uses identical logic for destination mapping and collision handling (reuse same code paths)
- **Deliverable**: Dry-run preview that matches actual import results (same destination paths, same collision handling decisions)
- **File**: `Sources/MediaHub/ImportExecution.swift`
- **Test**: Integration test that compares dry-run preview with actual import results (same inputs produce same preview/execution)
- **Acceptance**: Dry-run preview destination paths and collision handling match actual import results exactly

### Task 1.4: Add Dry-Run Validation (File Accessibility)
**Priority**: P1
- **Objective**: Ensure dry-run validates file accessibility to catch errors early (same validation as actual import)
- **Deliverable**: Dry-run that validates source file accessibility and reports errors in preview
- **File**: `Sources/MediaHub/ImportExecution.swift`
- **Test**: Unit test that verifies dry-run reports validation errors (e.g., inaccessible source file)
- **Acceptance**: Dry-run preview includes validation errors that would occur during actual import

### Task 1.5: Add Dry-Run Unit Tests
**Priority**: P1
- **Objective**: Add comprehensive unit tests for dry-run mode in import execution
- **Deliverable**: Test suite covering dry-run with various scenarios (normal import, collisions, errors)
- **File**: `Tests/MediaHubTests/ImportExecutionTests.swift`
- **Test**: All dry-run unit tests pass
- **Acceptance**: Tests verify zero file operations on source files or library media files, preview accuracy, validation error reporting

---

## Component 2: CLI Dry-Run Flag and Preview Output

**Plan Reference**: Component 2 (lines 81-120)  
**Dependencies**: Component 1 (dry-run mode in core)

### Task 2.1: Add --dry-run Flag to ImportCommand
**Priority**: P1
- **Objective**: Add `--dry-run` flag to `ImportCommand` using Swift Argument Parser
- **Deliverable**: `ImportCommand` with `@Flag(name: .long, help: "Preview import operations without copying files") var dryRun: Bool`
- **File**: `Sources/MediaHubCLI/ImportCommand.swift`
- **Test**: Verify `--dry-run` flag is recognized by CLI help and argument parsing
- **Acceptance**: `mediahub import --help` shows `--dry-run` flag, flag can be used in command

### Task 2.2: Pass Dry-Run Flag to Import Execution
**Priority**: P1
- **Objective**: Pass `dryRun` flag from CLI command to `ImportExecution.execute()` call
- **Deliverable**: `ImportCommand` that calls `ImportExecution.execute()` with `dryRun` parameter from CLI flag
- **File**: `Sources/MediaHubCLI/ImportCommand.swift`
- **Test**: Integration test that verifies dry-run flag is passed correctly to import execution
- **Acceptance**: CLI `--dry-run` flag correctly enables dry-run mode in import execution

### Task 2.3: Format Preview Output in Human-Readable Mode
**Priority**: P1
- **Objective**: Format dry-run preview output with clear "DRY-RUN" indicator and "Would import" language
- **Deliverable**: Human-readable output that shows "DRY-RUN: Would import N items" and preview details
- **File**: `Sources/MediaHubCLI/OutputFormatting.swift`
- **Test**: Manual test that verifies preview output is clearly marked as dry-run
- **Acceptance**: Preview output shows "DRY-RUN" indicator and uses "Would import" language (not "Imported")

### Task 2.4: Format Preview Output in JSON Mode
**Priority**: P1
- **Objective**: Include `dryRun: true` field in JSON output when `--dry-run` flag is used
- **Deliverable**: JSON output that includes `"dryRun": true` field in import results. Strategy: Wrap the existing `ImportResult` JSON output in an envelope object with `dryRun: true` field (CLI-only, no changes to core `ImportResult` type)
- **File**: `Sources/MediaHubCLI/OutputFormatting.swift` (modify `ImportResultFormatter` to add `dryRun` field to JSON envelope)
- **Test**: Unit test that verifies JSON output includes `dryRun: true` field in the envelope
- **Acceptance**: JSON output contains `"dryRun": true` field at the top level when `--dry-run` flag is used (e.g., `{"dryRun": true, "result": {...}}`)

### Task 2.5: Show Preview Details (Source Paths, Destination Paths, Collisions)
**Priority**: P1
- **Objective**: Display detailed preview information including source paths, destination paths, and collision handling decisions
- **Deliverable**: Preview output that shows what would be imported, where files would be placed, and what collisions would occur
- **File**: `Sources/MediaHubCLI/OutputFormatting.swift`
- **Test**: Manual test that verifies preview shows all relevant details
- **Acceptance**: Preview output includes source paths, destination paths, and collision handling preview

### Task 2.6: Add CLI Dry-Run Integration Tests
**Priority**: P1
- **Objective**: Add integration tests for CLI dry-run functionality
- **Deliverable**: Test suite covering CLI dry-run with various scenarios
- **File**: `Tests/MediaHubTests/ImportExecutionTests.swift` (add CLI dry-run tests to existing test file)
- **Test**: All CLI dry-run integration tests pass
- **Acceptance**: Tests verify CLI dry-run flag works correctly, output formatting is correct, zero file operations on source files or library media files

---

## Component 3: Confirmation Prompts for Import Operations

**Plan Reference**: Component 3 (lines 122-170)  
**Dependencies**: Component 2 (dry-run must skip confirmation)

### Task 3.1: Add --yes Flag to ImportCommand
**Priority**: P1
- **Objective**: Add `--yes` flag to `ImportCommand` using Swift Argument Parser
- **Deliverable**: `ImportCommand` with `@Flag(name: .long, help: "Skip confirmation prompt (non-interactive mode)") var yes: Bool`
- **File**: `Sources/MediaHubCLI/ImportCommand.swift`
- **Test**: Verify `--yes` flag is recognized by CLI help and argument parsing
- **Acceptance**: `mediahub import --help` shows `--yes` flag, flag can be used in command

### Task 3.2: Implement TTY Detection
**Priority**: P1
- **Objective**: Detect whether CLI is running in interactive mode (TTY available) or non-interactive mode (no TTY)
- **Deliverable**: Function that detects TTY using Swift/Foundation APIs (e.g., `FileHandle.standardInput.isTTY` or `isatty()` via C interop). Make TTY detection injectable for testing (optional parameter with default)
- **File**: `Sources/MediaHubCLI/ImportCommand.swift`
- **Test**: Manual test for TTY detection in interactive and non-interactive modes. Unit test with injected TTY state (if testable without complex infrastructure)
- **Acceptance**: TTY detection correctly identifies interactive vs non-interactive mode. Manual testing required for full validation.

### Task 3.3: Implement Confirmation Prompt Logic
**Priority**: P1
- **Objective**: Display confirmation prompt with import summary (item count, source, destination) and wait for user input
- **Deliverable**: Confirmation prompt that shows "Import N items from <source> to <library>? [yes/no]: " and reads user input
- **File**: `Sources/MediaHubCLI/ImportCommand.swift`
- **Test**: Manual test that verifies confirmation prompt appears and accepts user input
- **Acceptance**: Confirmation prompt displays import summary and waits for user input

### Task 3.4: Handle User Confirmation Input
**Priority**: P1
- **Objective**: Process user input for confirmation (yes/y to proceed, no/n to cancel, Ctrl+C to cancel)
- **Deliverable**: Logic that accepts "yes"/"y" to proceed, "no"/"n" to cancel, handles Ctrl+C gracefully
- **File**: `Sources/MediaHubCLI/ImportCommand.swift`
- **Test**: Manual test that verifies confirmation input handling works correctly
- **Acceptance**: User can confirm with "yes"/"y", cancel with "no"/"n", and Ctrl+C cancels gracefully

### Task 3.5: Skip Confirmation for Dry-Run
**Priority**: P1
- **Objective**: Ensure confirmation prompt is skipped when `--dry-run` flag is used (dry-run is always safe)
- **Deliverable**: Logic that skips confirmation when `dryRun` is `true`
- **File**: `Sources/MediaHubCLI/ImportCommand.swift`
- **Test**: Unit test that verifies confirmation is skipped for dry-run
- **Acceptance**: Confirmation prompt does not appear when `--dry-run` flag is used

### Task 3.6: Skip Confirmation with --yes Flag
**Priority**: P1
- **Objective**: Ensure confirmation prompt is skipped when `--yes` flag is provided
- **Deliverable**: Logic that skips confirmation when `yes` flag is `true`
- **File**: `Sources/MediaHubCLI/ImportCommand.swift`
- **Test**: Unit test that verifies confirmation is skipped when `--yes` flag is used
- **Acceptance**: Confirmation prompt does not appear when `--yes` flag is used

### Task 3.7: Require --yes Flag in Non-Interactive Mode
**Priority**: P1
- **Objective**: Detect non-interactive mode and require `--yes` flag (fail with clear error if not provided)
- **Deliverable**: Logic that detects non-interactive mode and fails with error message if `--yes` is not provided
- **File**: `Sources/MediaHubCLI/ImportCommand.swift`, `Sources/MediaHubCLI/CLIError.swift`
- **Test**: Unit test that verifies non-interactive mode requires `--yes` flag
- **Acceptance**: Non-interactive mode fails with clear error message if `--yes` flag is not provided

### Task 3.8: Handle User Cancellation Gracefully
**Priority**: P1
- **Objective**: Ensure user cancellation (typing "no"/"n" or Ctrl+C) exits with code 0 (cancellation is not an error)
- **Deliverable**: Logic that exits with code 0 when user cancels confirmation. Display cancellation message to stdout (e.g., "Import cancelled.")
- **File**: `Sources/MediaHubCLI/ImportCommand.swift`
- **Test**: Manual test that verifies cancellation exits with code 0 and displays message
- **Acceptance**: User cancellation exits with code 0 and displays cancellation message to stdout

### Task 3.9: Add Confirmation Prompt Tests
**Priority**: P1
- **Objective**: Add tests for confirmation prompt functionality (where possible with test infrastructure)
- **Deliverable**: Test suite covering confirmation prompts. Strategy: Test confirmation logic branches (skip for dry-run, skip for --yes, require --yes in non-interactive mode) with injected TTY state and stdin simulation where feasible. Full interactive prompt testing requires manual validation.
- **File**: `Tests/MediaHubTests/ImportExecutionTests.swift` (add confirmation logic tests to existing test file)
- **Test**: Automated tests for confirmation logic branches pass. Manual testing required for full interactive prompt validation.
- **Acceptance**: Tests verify confirmation logic works correctly (skip for dry-run, skip for --yes, require --yes in non-interactive mode). Manual testing confirms interactive prompts work correctly.

---

## Component 4: Read-Only Guarantees Documentation

**Plan Reference**: Component 4 (lines 172-200)  
**Dependencies**: None (documentation only)

### Task 4.1: Update DetectCommand Help Text
**Priority**: P1
- **Objective**: Update CLI help text for `detect` command to explicitly state that detection is read-only for source and media files
- **Deliverable**: Help text that includes "Read-only operation: detection does not modify source files or copy media files (may write result files in `.mediahub` directory)"
- **File**: `Sources/MediaHubCLI/DetectCommand.swift`
- **Test**: Verify help text includes read-only guarantee message
- **Acceptance**: `mediahub detect --help` shows explicit read-only guarantee message

### Task 4.2: Add Read-Only Indicator to Detection Output (Optional)
**Priority**: P1
- **Objective**: Optionally add read-only indicator to detection command output (e.g., "Read-only: No files modified")
- **Deliverable**: Detection output that optionally includes read-only guarantee message
- **File**: `Sources/MediaHubCLI/DetectCommand.swift` or `OutputFormatting.swift`
- **Test**: Manual test that verifies read-only indicator appears in detection output (if implemented)
- **Acceptance**: Detection output optionally includes read-only guarantee message (optional for P1)

### Task 4.3: Verify Detection Read-Only Guarantee
**Priority**: P1
- **Objective**: Verify that detection operations perform zero file system modifications to source files or media files (already enforced by core, but verify)
- **Deliverable**: Test or verification that confirms detection is read-only for source and media files
- **File**: `Tests/MediaHubTests/` (existing detection tests)
- **Test**: Verify existing detection tests confirm read-only behavior for source and media files
- **Acceptance**: Detection operations perform zero file system modifications to source files or media files (verified by tests; detection may write result files in `.mediahub` directory)

---

## Component 5: Safety-First Error Handling

**Plan Reference**: Component 5 (lines 202-250)  
**Dependencies**: Component 1-2 (error handling must work with dry-run)

### Task 5.1: Verify Import Error Handling Preserves Library Integrity
**Priority**: P1
- **Objective**: Verify that import error handling doesn't leave partial files (atomic file copy should handle this, but verify)
- **Deliverable**: Test or verification that confirms import errors don't leave partial files
- **File**: `Tests/MediaHubTests/ImportExecutionTests.swift`
- **Test**: Test that simulates import errors and verifies no partial files are left
- **Acceptance**: Import errors don't leave partial files in library (verified by tests)

### Task 5.2: Add Interruption Handling (SIGINT) to ImportCommand
**Priority**: P1
- **Objective**: Catch SIGINT signal during import and handle interruption gracefully
- **Deliverable**: Signal handler that catches SIGINT, displays interruption message, and exits cleanly. Strategy: CLI-only signal handling (no core changes). Display message like "Interrupted: import cancelled. Library integrity preserved." without requiring exact item count (which would need core progress API)
- **File**: `Sources/MediaHubCLI/ImportCommand.swift`
- **Test**: Manual test that verifies interruption handling works correctly (Ctrl+C during import)
- **Acceptance**: Interruption during import displays cancellation message and exits cleanly (exit code 0). Library integrity preserved (atomic file copy in core handles partial writes).

### Task 5.3: Report Progress on Interruption
**Priority**: P1
- **Objective**: Display interruption message when user cancels import (Ctrl+C)
- **Deliverable**: Interruption handler that shows "Interrupted: import cancelled. Library integrity preserved." (CLI-only message, no exact item count required to avoid core progress API dependency)
- **File**: `Sources/MediaHubCLI/ImportCommand.swift`
- **Test**: Manual test that verifies interruption displays message correctly
- **Acceptance**: Interruption displays cancellation message before exiting. Note: Exact item count is not required for P1 (would need core progress API); focus on safety message and integrity preservation.

### Task 5.4: Format Error Messages for Safety
**Priority**: P1
- **Objective**: Ensure error messages are clear, actionable, and safety-focused (no technical jargon)
- **Deliverable**: Error message formatting that provides clear, actionable guidance
- **File**: `Sources/MediaHubCLI/CLIError.swift`, `Sources/MediaHubCLI/OutputFormatting.swift`
- **Test**: Manual test that verifies error messages are clear and actionable
- **Acceptance**: Error messages are user-friendly and provide actionable guidance

### Task 5.5: Add Safety-Specific Error Types
**Priority**: P1
- **Objective**: Add error types for safety-specific scenarios (e.g., non-interactive mode without --yes)
- **Deliverable**: Error types in `CLIError.swift` for safety scenarios (CLI-only, no changes to core error types)
- **File**: `Sources/MediaHubCLI/CLIError.swift` (add new cases to existing `CLIError` enum, no changes to core error types)
- **Test**: Verify error types are used correctly in confirmation logic
- **Acceptance**: Safety-specific error types are defined in `CLIError.swift` and used appropriately. No changes to core error types.

### Task 5.6: Test Error Handling with Dry-Run
**Priority**: P1
- **Objective**: Verify that error handling works correctly with dry-run mode (errors shown in preview)
- **Deliverable**: Test that verifies error handling in dry-run mode
- **File**: `Tests/MediaHubTests/ImportExecutionTests.swift`
- **Test**: Test that simulates errors in dry-run mode and verifies errors are shown in preview
- **Acceptance**: Dry-run preview shows errors that would occur during actual import

### Task 5.7: Add Error Handling Tests
**Priority**: P1
- **Objective**: Add comprehensive tests for error handling and interruption handling
- **Deliverable**: Test suite covering error scenarios. Interruption handling requires manual testing (signal simulation is complex)
- **File**: `Tests/MediaHubTests/ImportExecutionTests.swift`
- **Test**: All error handling tests pass. Manual testing for interruption handling.
- **Acceptance**: Tests verify error handling preserves library integrity. Manual testing confirms interruption handling works correctly.

---

## Validation Tasks

### Task V.1: Run All Existing Tests
**Priority**: P1
- **Objective**: Verify that all existing tests still pass after Slice 5 implementation
- **Deliverable**: All existing tests pass (no regressions)
- **Command**: `swift test`
- **Acceptance**: All existing tests pass, no test failures

### Task V.2: Run CLI Smoke Tests
**Priority**: P1
- **Objective**: Verify that CLI smoke tests pass with new safety features
- **Deliverable**: CLI smoke tests pass with dry-run and confirmation features
- **Command**: `scripts/smoke_cli.sh`
- **Acceptance**: All CLI smoke tests pass

### Task V.3: Manual Testing of Dry-Run Accuracy
**Priority**: P1
- **Objective**: Manually verify that dry-run preview matches actual import results
- **Deliverable**: Verification that dry-run preview is accurate (same inputs produce same preview/execution)
- **Procedure**: Run dry-run, then actual import, compare results
- **Acceptance**: Dry-run preview matches actual import results exactly

### Task V.4: Manual Testing of Confirmation Prompts
**Priority**: P1
- **Objective**: Manually test confirmation prompts in interactive and non-interactive modes
- **Deliverable**: Verification that confirmation prompts work correctly
- **Procedure**: Test confirmation in interactive terminal, test --yes flag, test non-interactive mode
- **Acceptance**: Confirmation prompts work correctly in all scenarios

### Task V.5: Manual Testing of Interruption Handling
**Priority**: P1
- **Objective**: Manually test interruption handling (Ctrl+C during import)
- **Deliverable**: Verification that interruption handling works correctly
- **Procedure**: Start import, press Ctrl+C, verify progress is reported
- **Acceptance**: Interruption handling reports progress and exits cleanly

---

## Task Summary

- **Total P1 Tasks**: 35 tasks
- **Component 1 (Dry-Run Core)**: 5 tasks
- **Component 2 (CLI Dry-Run)**: 6 tasks
- **Component 3 (Confirmation)**: 9 tasks
- **Component 4 (Read-Only Docs)**: 3 tasks
- **Component 5 (Error Handling)**: 7 tasks
- **Validation Tasks**: 5 tasks

## Implementation Order

1. **Phase 1**: Component 1 (Tasks 1.1-1.5) → Component 2 (Tasks 2.1-2.6)
2. **Phase 2**: Component 3 (Tasks 3.1-3.9)
3. **Phase 3**: Component 4 (Tasks 4.1-4.3)
4. **Phase 4**: Component 5 (Tasks 5.1-5.7)
5. **Validation**: All validation tasks (V.1-V.5)
