# Implementation Tasks: Library Adoption (Slice 6)

**Feature**: Library Adoption  
**Specification**: `specs/006-library-adoption/spec.md`  
**Plan**: `specs/006-library-adoption/plan.md`  
**Slice**: 6 - Library Adoption  
**Created**: 2026-01-27

## Task Organization

Tasks are organized by component and follow the implementation sequence defined in the plan. Each task is:
- Small and focused on a single deliverable
- Sequential (dependencies are clear)
- Traceable to plan components (referenced by component number)
- Includes only P1 scope: adoption metadata creation, baseline scan, dry-run preview, confirmation prompts, safety-first error handling

## NON-NEGOTIABLE CONSTRAINTS FOR SLICE 6

**CRITICAL**: The following constraints MUST be followed during Slice 6 implementation:

1. **Code Location**:
   - Majority of changes MUST be in `Sources/MediaHubCLI/` (new `adopt` subcommand, confirmation handling, dry-run preview)
   - Core changes allowed but must be minimal and adoption-only; prefer a single new file, but allow minimal touches if required

2. **File Protection**:
   - NO modification, move, rename, or deletion of existing media files during adoption
   - NO changes to existing CLI command structure beyond adding new `adopt` subcommand
   - NO changes to existing error types beyond adding adoption-specific error messages
   - NO refactors of existing core logic

3. **Safety First**:
   - Adoption MUST create only `.mediahub/` metadata (no media file modifications)
   - Dry-run MUST perform zero file system writes (read-only operations allowed for preview)
   - Confirmation MUST be skipped for dry-run operations
   - Error handling MUST preserve library integrity (atomic writes, rollback on failure)

4. **Backward Compatibility**:
   - NO breaking changes to existing CLI behavior when adoption is not used
   - All existing tests MUST still pass after implementation

---

## Component 2: Core Adoption Operations

**Plan Reference**: Component 2 (lines 95-145)  
**Dependencies**: None (Foundation)

### Task 2.1: Create LibraryAdoption.swift File Structure
**Priority**: P1
- **Objective**: Create new `LibraryAdoption.swift` file with `LibraryAdopter` struct and basic error types
- **Deliverable**: New file with struct definition and `LibraryAdoptionError` enum
- **Files**: `Sources/MediaHub/LibraryAdoption.swift`
- **Dependencies**: None
- **Acceptance**: File compiles, struct and error enum are defined, follows existing code patterns

### Task 2.2: Implement Idempotent Check
**Priority**: P1
- **Objective**: Add method to check if library is already adopted (detect existing `.mediahub/library.json`)
- **Deliverable**: `LibraryAdopter.isAlreadyAdopted(at:)` method that returns boolean
- **Files**: `Sources/MediaHub/LibraryAdoption.swift`
- **Dependencies**: Task 2.1
- **Acceptance**: Method correctly detects existing `.mediahub/library.json`, returns `true` if exists, `false` otherwise

### Task 2.3: Implement Path Validation
**Priority**: P1
- **Objective**: Add validation for target path (exists, is directory, has write permissions)
- **Deliverable**: `LibraryAdopter.validatePath(_:)` method that throws `LibraryAdoptionError` on validation failure
- **Files**: `Sources/MediaHub/LibraryAdoption.swift`
- **Dependencies**: Task 2.1
- **Acceptance**: Method validates path exists, is directory, has write permissions; throws clear errors for each failure case

### Task 2.4: Implement Metadata Creation (Reuse Existing Components)
**Priority**: P1
- **Objective**: Implement adoption logic that reuses `LibraryStructureCreator`, `LibraryIdentifierGenerator`, `LibraryMetadata`, and `LibraryMetadataSerializer` to create `.mediahub/` directory and `library.json`
- **Deliverable**: `LibraryAdopter.adoptLibrary(at:)` method that creates metadata using existing components
- **Files**: `Sources/MediaHub/LibraryAdoption.swift`
- **Dependencies**: Task 2.1, Task 2.2, Task 2.3
- **Acceptance**: Method creates `.mediahub/` directory and `library.json` using existing components, returns `LibraryMetadata`, does not modify existing media files

### Task 2.5: Implement Atomic Metadata Write
**Priority**: P1
- **Objective**: Ensure metadata write is atomic (write to temp file, then move atomically) to prevent partial/corrupted files
- **Deliverable**: Atomic metadata write implementation using temp file + atomic move
- **Files**: `Sources/MediaHub/LibraryAdoption.swift`
- **Dependencies**: Task 2.4
- **Acceptance**: Metadata write uses temp file then atomic move, no partial `library.json` files can exist

### Task 2.6: Implement Rollback on Failure
**Priority**: P1
- **Objective**: Add rollback logic that deletes `.mediahub/` directory if metadata creation fails
- **Deliverable**: Rollback cleanup that removes `.mediahub/` directory on error
- **Files**: `Sources/MediaHub/LibraryAdoption.swift`
- **Dependencies**: Task 2.4
- **Acceptance**: On metadata creation failure, `.mediahub/` directory is cleaned up, no partial metadata remains

### Task 2.7: Add Core Adoption Unit Tests
**Priority**: P1
- **Objective**: Add unit tests for core adoption operations (metadata creation, idempotent check, validation, rollback)
- **Deliverable**: Test suite covering adoption operations
- **Files**: `Tests/MediaHubTests/LibraryAdoptionTests.swift`
- **Dependencies**: Task 2.6
- **Acceptance**: Tests verify metadata creation, idempotent check, path validation, atomic writes, rollback on failure, zero media file modifications

---

## Component 3: Baseline Scan Integration

**Plan Reference**: Component 3 (lines 149-194)  
**Dependencies**: Component 2 (core adoption operations)

### Task 3.1: Integrate Baseline Scan into Adoption
**Priority**: P1
- **Objective**: Add baseline scan call to adoption workflow using `LibraryContentQuery.scanLibraryContents()`
- **Deliverable**: Adoption performs baseline scan and returns scan summary (file count, paths)
- **Files**: `Sources/MediaHub/LibraryAdoption.swift`
- **Dependencies**: Task 2.4
- **Acceptance**: Adoption calls `LibraryContentQuery.scanLibraryContents()` and returns baseline scan results (file count, path set). Slice 6 does not create persistent heavy index; baseline scan serves only to establish minimal "known" state required by spec. No hashing, no performance index (deferred to Slice 7).

### Task 3.2: Ensure Baseline Scan Determinism
**Priority**: P1
- **Objective**: Verify baseline scan results are deterministic (same library state produces same results)
- **Deliverable**: Baseline scan that returns sorted/deterministic results
- **Files**: `Sources/MediaHub/LibraryAdoption.swift`
- **Dependencies**: Task 3.1
- **Acceptance**: Baseline scan results are deterministic (same library state produces identical path sets, sorted consistently)

### Task 3.3: Add Baseline Scan Summary Structure
**Priority**: P1
- **Objective**: Create structure to hold baseline scan summary (file count, scan scope) for output formatting
- **Deliverable**: `BaselineScanSummary` struct with file count and scope information
- **Files**: `Sources/MediaHub/LibraryAdoption.swift`
- **Dependencies**: Task 3.1
- **Acceptance**: Structure holds baseline scan summary data (file count, scan scope), can be serialized for output. Slice 6 does not create persistent heavy index; baseline serves only to establish minimal "known" state. No hashing, no performance index (deferred to Slice 7).

### Task 3.4: Add Baseline Scan Unit Tests
**Priority**: P1
- **Objective**: Add unit tests for baseline scan integration (determinism, path-based only, no hashing)
- **Deliverable**: Test suite covering baseline scan behavior
- **Files**: `Tests/MediaHubTests/LibraryAdoptionTests.swift`
- **Dependencies**: Task 3.2
- **Acceptance**: Tests verify baseline scan is deterministic, path-based only (no hashing), excludes `.mediahub/` directory

---

## Component 1: CLI Adoption Command Wiring

**Plan Reference**: Component 1 (lines 38-91)  
**Dependencies**: Component 2, Component 3 (core adoption operations)

### Task 1.1: Add LibraryAdoptCommand to CLI
**Priority**: P1
- **Objective**: Add `LibraryAdoptCommand` as new subcommand of `LibraryCommand` with path argument
- **Deliverable**: CLI command `mediahub library adopt <path>` that is recognized and routed
- **Files**: `Sources/MediaHubCLI/LibraryCommand.swift`
- **Dependencies**: Task 2.7, Task 3.4
- **Acceptance**: `mediahub library adopt --help` shows command, command accepts path argument, routes to adoption execution

### Task 1.2: Add --dry-run Flag to LibraryAdoptCommand
**Priority**: P1
- **Objective**: Add `--dry-run` flag to `LibraryAdoptCommand` using Swift Argument Parser
- **Deliverable**: `LibraryAdoptCommand` with `@Flag(name: .long, help: "Preview adoption operations without creating metadata") var dryRun: Bool`
- **Files**: `Sources/MediaHubCLI/LibraryCommand.swift`
- **Dependencies**: Task 1.1
- **Acceptance**: `--dry-run` flag is recognized, can be used in command, flag value is accessible in command execution

### Task 1.3: Add --yes Flag to LibraryAdoptCommand
**Priority**: P1
- **Objective**: Add `--yes` flag to `LibraryAdoptCommand` to bypass confirmation prompts
- **Deliverable**: `LibraryAdoptCommand` with `@Flag(name: .long, help: "Skip confirmation prompt") var yes: Bool`
- **Files**: `Sources/MediaHubCLI/LibraryCommand.swift`
- **Dependencies**: Task 1.1
- **Acceptance**: `--yes` flag is recognized, can be used in command, flag value is accessible in command execution

### Task 1.4: Add --json Flag to LibraryAdoptCommand
**Priority**: P1
- **Objective**: Add `--json` flag to `LibraryAdoptCommand` for JSON output format
- **Deliverable**: `LibraryAdoptCommand` with `@Flag(name: .shortAndLong, help: "Output results in JSON format") var json: Bool`
- **Files**: `Sources/MediaHubCLI/LibraryCommand.swift`
- **Dependencies**: Task 1.1
- **Acceptance**: `--json` flag is recognized, can be used in command, flag value is accessible in command execution

### Task 1.5: Implement Path Validation in CLI
**Priority**: P1
- **Objective**: Add user-facing path validation in CLI command (quick checks for obvious errors, clear error messages) before calling adoption
- **Deliverable**: CLI performs quick user-facing validation and reports clear errors before adoption execution
- **Files**: `Sources/MediaHubCLI/LibraryCommand.swift`
- **Dependencies**: Task 1.1, Task 2.3
- **Acceptance**: CLI performs quick user-facing validation (path exists, is directory), reports clear error messages for obvious issues. Core performs authoritative validation before metadata writes (Task 2.3). CLI does not reimplement core validation logic.

### Task 1.6: Implement Non-Interactive Mode Detection
**Priority**: P1
- **Objective**: Detect non-interactive mode (no TTY) and require `--yes` flag, fail with clear error if not provided
- **Deliverable**: TTY detection that requires `--yes` flag in non-interactive mode
- **Files**: `Sources/MediaHubCLI/LibraryCommand.swift`
- **Dependencies**: Task 1.1, Task 1.3
- **Acceptance**: Non-interactive mode detected, requires `--yes` flag, fails with clear error message if not provided

### Task 1.7: Route to Adoption Execution
**Priority**: P1
- **Objective**: Connect CLI command to core adoption execution, pass dry-run flag, handle results
- **Deliverable**: CLI command calls `LibraryAdopter` methods and handles results
- **Files**: `Sources/MediaHubCLI/LibraryCommand.swift`
- **Dependencies**: Task 1.1, Task 2.4, Task 3.1
- **Acceptance**: CLI command calls adoption execution, passes dry-run flag, handles success/error results

---

## Component 5: Output Formatting and JSON Support

**Plan Reference**: Component 5 (lines 246-288)  
**Dependencies**: Component 1 (CLI command wiring)

### Task 5.1: Format Human-Readable Adoption Success Output
**Priority**: P1
- **Objective**: Format human-readable output for successful adoption (metadata location, baseline scan summary)
- **Deliverable**: Clear success message showing library ID, metadata location, baseline scan summary
- **Files**: `Sources/MediaHubCLI/LibraryCommand.swift` or `Sources/MediaHubCLI/OutputFormatting.swift`
- **Dependencies**: Task 1.7
- **Acceptance**: Success output shows library ID, metadata location (`.mediahub/library.json`), baseline scan summary (file count), clear "no media files modified" message

### Task 5.2: Format Human-Readable Idempotent Adoption Output
**Priority**: P1
- **Objective**: Format human-readable output for idempotent adoption (library already adopted)
- **Deliverable**: Clear message indicating library is already adopted
- **Files**: `Sources/MediaHubCLI/LibraryCommand.swift` or `Sources/MediaHubCLI/OutputFormatting.swift`
- **Dependencies**: Task 1.7
- **Acceptance**: Idempotent adoption shows clear "library already adopted" message, exit code 0 (not error)

### Task 5.3: Format Human-Readable Error Messages
**Priority**: P1
- **Objective**: Format clear, actionable error messages for adoption failures (path validation, permission errors, etc.)
- **Deliverable**: Error messages that are clear and actionable (no technical jargon)
- **Files**: `Sources/MediaHubCLI/LibraryCommand.swift` or `Sources/MediaHubCLI/OutputFormatting.swift`
- **Dependencies**: Task 1.7
- **Acceptance**: Error messages are clear, actionable, explain what went wrong and how to resolve

### Task 5.4: Implement JSON Output Format
**Priority**: P1
- **Objective**: Format JSON output for adoption results (metadata, baseline scan summary, dry-run flag when applicable)
- **Deliverable**: JSON output with structured data including `dryRun: true` field when `--dry-run` is used
- **Files**: `Sources/MediaHubCLI/LibraryCommand.swift` or `Sources/MediaHubCLI/OutputFormatting.swift`
- **Dependencies**: Task 1.7, Task 1.2
- **Acceptance**: JSON output includes library metadata, baseline scan summary, `dryRun: true` field when applicable, properly formatted JSON

### Task 5.5: Format Confirmation Prompt
**Priority**: P1
- **Objective**: Format confirmation prompt showing what will be created (metadata location, baseline scan summary)
- **Deliverable**: Clear confirmation prompt with adoption summary
- **Files**: `Sources/MediaHubCLI/LibraryCommand.swift`
- **Dependencies**: Task 1.7, Task 3.3
- **Acceptance**: Confirmation prompt shows metadata location, baseline scan summary (file count), clear "no media files will be modified" message

---

## Component 4: Dry-Run Preview Support

**Plan Reference**: Component 4 (lines 198-242)  
**Dependencies**: Component 1, Component 2, Component 3 (CLI command, core adoption, baseline scan)

### Task 4.1: Add Dry-Run Parameter to Core Adoption
**Priority**: P1
- **Objective**: Add `dryRun: Bool` parameter to `LibraryAdopter.adoptLibrary(at:dryRun:)` method
- **Deliverable**: Adoption method accepts dry-run parameter
- **Files**: `Sources/MediaHub/LibraryAdoption.swift`
- **Dependencies**: Task 2.4
- **Acceptance**: Method signature includes `dryRun: Bool = false` parameter, defaults to `false` for backward compatibility

### Task 4.2: Implement Dry-Run Preview Logic
**Priority**: P1
- **Objective**: Implement preview logic that performs all operations except file writes (read-only baseline scan, preview metadata structure)
- **Deliverable**: Dry-run mode that performs read-only operations and returns preview results without creating files
- **Files**: `Sources/MediaHub/LibraryAdoption.swift`
- **Dependencies**: Task 4.1, Task 3.1
- **Acceptance**: Dry-run performs read-only baseline scan, previews metadata structure, performs zero file system writes

### Task 4.3: Ensure Dry-Run Uses Same Logic as Actual Adoption
**Priority**: P1
- **Objective**: Verify dry-run uses identical logic for metadata structure and baseline scan (reuse same code paths, disable writes only)
- **Deliverable**: Dry-run preview that matches actual adoption results (same metadata structure, same baseline scan scope)
- **Files**: `Sources/MediaHub/LibraryAdoption.swift`
- **Dependencies**: Task 4.2
- **Acceptance**: Dry-run preview metadata structure and baseline scan scope match actual adoption exactly

### Task 4.4: Format Dry-Run Preview Output (Human-Readable)
**Priority**: P1
- **Objective**: Format human-readable dry-run preview output showing "DRY-RUN" indicator and what would be created
- **Deliverable**: Clear preview output with "DRY-RUN" indicator, metadata preview, baseline scan summary
- **Files**: `Sources/MediaHubCLI/LibraryCommand.swift` or `Sources/MediaHubCLI/OutputFormatting.swift`
- **Dependencies**: Task 4.2, Task 5.1
- **Acceptance**: Dry-run output shows "DRY-RUN" indicator, preview of metadata that would be created, baseline scan summary, clear "no files will be created" message

### Task 4.5: Format Dry-Run Preview Output (JSON)
**Priority**: P1
- **Objective**: Format JSON dry-run preview output with `dryRun: true` field and preview information
- **Deliverable**: JSON output with `dryRun: true` field and preview data
- **Files**: `Sources/MediaHubCLI/LibraryCommand.swift` or `Sources/MediaHubCLI/OutputFormatting.swift`
- **Dependencies**: Task 4.2, Task 5.4
- **Acceptance**: JSON output includes `dryRun: true` field, preview metadata structure, baseline scan summary

### Task 4.6: Add Dry-Run Unit Tests
**Priority**: P1
- **Objective**: Add unit tests for dry-run mode (zero writes, preview accuracy, read-only baseline scan)
- **Deliverable**: Test suite covering dry-run behavior
- **Files**: `Tests/MediaHubTests/LibraryAdoptionTests.swift`
- **Dependencies**: Task 4.3
- **Acceptance**: Tests verify zero file system writes in dry-run, preview matches actual adoption, read-only baseline scan works

---

## Component 1 (continued): Confirmation Prompts

**Plan Reference**: Component 1 (lines 38-91)  
**Dependencies**: Component 5 (output formatting)

### Task 1.8: Implement Confirmation Prompt Logic
**Priority**: P1
- **Objective**: Implement confirmation prompt that appears when not dry-run and not `--yes`, waits for user input (yes/y, no/n, Ctrl+C)
- **Deliverable**: Interactive confirmation prompt with user input handling
- **Files**: `Sources/MediaHubCLI/LibraryCommand.swift`
- **Dependencies**: Task 1.7, Task 5.5
- **Acceptance**: Confirmation prompt appears when appropriate (not dry-run, not `--yes`, interactive mode), accepts yes/y to proceed, no/n or Ctrl+C to cancel

### Task 1.9: Handle User Cancellation
**Priority**: P1
- **Objective**: Handle user cancellation (no/n or Ctrl+C) gracefully, exit with code 0 (not an error)
- **Deliverable**: Cancellation handling that exits cleanly with code 0
- **Files**: `Sources/MediaHubCLI/LibraryCommand.swift`
- **Dependencies**: Task 1.8
- **Acceptance**: User cancellation (no/n or Ctrl+C) exits with code 0, shows cancellation message, does not treat cancellation as error

### Task 1.10: Ensure Dry-Run Skips Confirmation
**Priority**: P1
- **Objective**: Verify dry-run mode always skips confirmation (dry-run is always safe, no prompts)
- **Deliverable**: Dry-run mode that never prompts for confirmation
- **Files**: `Sources/MediaHubCLI/LibraryCommand.swift`
- **Dependencies**: Task 1.8, Task 4.4
- **Acceptance**: Dry-run mode never shows confirmation prompt, proceeds directly to preview

### Task 1.11: Add Confirmation Prompt Tests (Automated)
**Priority**: P1
- **Objective**: Add automated tests for confirmation logic (branches skip/require, TTY detection mockable/injectable)
- **Deliverable**: Test suite covering confirmation branches and TTY detection (automated only)
- **Files**: `Tests/MediaHubTests/LibraryAdoptionTests.swift`
- **Dependencies**: Task 1.9
- **Acceptance**: Tests verify confirmation is skipped for dry-run and `--yes`, required otherwise, TTY detection is mockable/injectable. Full interactive prompt testing (yes/y, no/n, Ctrl+C) is covered by manual testing (Task VAL-2).

---

## Component 6: Tests and Validation

**Plan Reference**: Component 6 (lines 292-341)  
**Dependencies**: All previous components

### Task 6.1: Add Idempotent Adoption Tests
**Priority**: P1
- **Objective**: Add tests for idempotent adoption (re-running on already adopted library)
- **Deliverable**: Test suite covering idempotent adoption behavior
- **Files**: `Tests/MediaHubTests/LibraryAdoptionTests.swift`
- **Dependencies**: Task 2.7
- **Acceptance**: Tests verify idempotent adoption works (re-running produces consistent results, no duplicate metadata, clear messaging)

### Task 6.2: Add Error Handling Tests
**Priority**: P1
- **Objective**: Add tests for error handling (path validation, permission errors, rollback on failure)
- **Deliverable**: Test suite covering error scenarios
- **Files**: `Tests/MediaHubTests/LibraryAdoptionTests.swift`
- **Dependencies**: Task 2.7
- **Acceptance**: Tests verify path validation errors, permission errors, rollback on failure, library integrity preservation

### Task 6.3: Add JSON Output Format Tests
**Priority**: P1
- **Objective**: Add tests for JSON output format (includes `dryRun: true` when applicable, proper structure)
- **Deliverable**: Test suite covering JSON output
- **Files**: `Tests/MediaHubTests/LibraryAdoptionTests.swift`
- **Dependencies**: Task 5.4, Task 4.5
- **Acceptance**: Tests verify JSON output includes `dryRun: true` when `--dry-run` is used, proper JSON structure, all required fields

### Task 6.4: Add Compatibility Tests
**Priority**: P1
- **Objective**: Add tests for compatibility with existing commands (`library open`, `detect`, `import`) on adopted libraries
- **Deliverable**: Test suite covering compatibility scenarios
- **Files**: `Tests/MediaHubTests/LibraryAdoptionTests.swift`
- **Dependencies**: Task 2.7, Task 3.4
- **Acceptance**: Tests verify `library open` works on adopted library, `detect` excludes existing files, `import` works correctly

### Task 6.5: Add Zero Media File Modification Tests
**Priority**: P1
- **Objective**: Add comprehensive tests that verify zero media file modifications during adoption
- **Deliverable**: Test suite that verifies no media files are modified, moved, renamed, or deleted
- **Files**: `Tests/MediaHubTests/LibraryAdoptionTests.swift`
- **Dependencies**: Task 2.7
- **Acceptance**: Tests verify zero media file modifications (before/after file comparison, file system monitoring if possible)

### Task 6.6: Add Dry-Run Accuracy Tests
**Priority**: P1
- **Objective**: Add tests that verify dry-run preview matches actual adoption results
- **Deliverable**: Test suite comparing dry-run preview with actual adoption
- **Files**: `Tests/MediaHubTests/LibraryAdoptionTests.swift`
- **Dependencies**: Task 4.6
- **Acceptance**: Tests verify dry-run preview metadata structure and baseline scan scope match actual adoption exactly

---

## Validation Tasks

**Plan Reference**: Implementation Sequence Phase 4 (lines 426-449)  
**Dependencies**: All implementation tasks

### Task VAL-1: Run All Existing Tests
**Priority**: P1
- **Objective**: Run all existing MediaHub tests to ensure no regression
- **Deliverable**: All existing tests pass after adoption implementation
- **Files**: N/A (test execution)
- **Dependencies**: All tasks
- **Acceptance**: `swift test` passes all existing tests, no test failures or regressions

### Task VAL-2: Manual Testing - Confirmation Prompts
**Priority**: P1
- **Objective**: Manual testing of confirmation prompts in interactive mode (full prompt, yes/y, no/n, Ctrl+C)
- **Deliverable**: Manual test verification of confirmation prompt behavior
- **Files**: N/A (manual testing)
- **Dependencies**: Task 1.8, Task 1.9
- **Acceptance**: Manual testing confirms confirmation prompt appears correctly, accepts yes/y, no/n, Ctrl+C, exits appropriately

### Task VAL-3: Manual Testing - Non-Interactive Mode
**Priority**: P1
- **Objective**: Manual testing of non-interactive mode detection and `--yes` flag requirement
- **Deliverable**: Manual test verification of non-interactive mode behavior
- **Files**: N/A (manual testing)
- **Dependencies**: Task 1.6
- **Acceptance**: Manual testing confirms non-interactive mode requires `--yes` flag, fails with clear error if not provided

### Task VAL-4: Manual Testing - Dry-Run Preview
**Priority**: P1
- **Objective**: Manual testing of dry-run preview accuracy (compare preview with actual adoption)
- **Deliverable**: Manual test verification that dry-run preview matches actual adoption
- **Files**: N/A (manual testing)
- **Dependencies**: Task 4.6
- **Acceptance**: Manual testing confirms dry-run preview matches actual adoption results (same metadata structure, same baseline scan)

### Task VAL-5: Smoke Test - End-to-End Adoption
**Priority**: P1
- **Objective**: End-to-end smoke test of adoption workflow (adopt library, verify metadata, test detection/import)
- **Deliverable**: Complete adoption workflow verification
- **Files**: N/A (smoke testing)
- **Dependencies**: All tasks
- **Acceptance**: Smoke test confirms adoption creates metadata, baseline scan works, `detect` excludes existing files, `import` works correctly

### Task VAL-6: Smoke Test - CLI Help and Commands
**Priority**: P1
- **Objective**: Verify CLI help and command recognition work correctly
- **Deliverable**: CLI help and command verification
- **Files**: N/A (smoke testing)
- **Dependencies**: Task 1.1, Task 1.2, Task 1.3, Task 1.4
- **Acceptance**: `mediahub library adopt --help` shows correct help, command is recognized, flags work correctly

---

## Task Summary

**Total Tasks**: 36 P1 tasks
- Component 2 (Core Adoption): 7 tasks
- Component 3 (Baseline Scan): 4 tasks
- Component 1 (CLI Wiring): 11 tasks (including confirmation)
- Component 5 (Output Formatting): 5 tasks
- Component 4 (Dry-Run): 6 tasks
- Component 6 (Tests): 6 tasks
- Validation: 6 tasks

**Implementation Order**:
1. Phase 1: Core Adoption Operations (Tasks 2.1-2.7, 3.1-3.4)
2. Phase 2: CLI Command Wiring and Output (Tasks 1.1-1.7, 5.1-5.5)
3. Phase 3: Dry-Run Preview Support (Tasks 4.1-4.6)
4. Phase 4: Confirmation Prompts (Tasks 1.8-1.11)
5. Phase 5: Comprehensive Testing (Tasks 6.1-6.6)
6. Phase 6: Validation (Tasks VAL-1 to VAL-6)
