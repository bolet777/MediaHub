# Feature Specification: Safety Features & Dry-Run Operations

**Feature Branch**: `005-safety-features-dry-run`  
**Created**: 2026-01-27  
**Status**: Ready for Plan  
**Input**: User description: "Add safety features to prevent accidental data loss and enable safe exploration of import operations before execution."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Preview Import Operations with Dry-Run (Priority: P1)

A user wants to preview what would happen during an import operation without actually copying any files. The CLI should support a `--dry-run` flag that shows exactly what would be imported, where files would be placed, and what collisions would occur, without performing any file system modifications.

**Why this priority**: Dry-run is the foundational safety feature that enables users to explore and understand import operations before committing to them. Without dry-run, users must rely on detection results alone, which don't show the full import execution details (destination paths, collision handling, etc.).

**Independent Test**: Can be fully tested by running `mediahub import <source-id> --all --dry-run --library <path>` and verifying that:
- No files are copied
- Output shows what would be imported
- Destination paths are displayed
- Collision handling preview is shown
- Exit code is 0 (successful preview)

**Acceptance Scenarios**:

1. **Given** a user has run detection and has candidate items, **When** they run `mediahub import <source-id> --all --dry-run --library <path>`, **Then** MediaHub displays a detailed preview of what would be imported (source paths, destination paths, collision handling decisions) without copying any files
2. **Given** a user runs import with `--dry-run` flag, **When** the preview completes, **Then** MediaHub shows a summary indicating this was a dry-run (e.g., "DRY-RUN: Would import N items") and no source files or library media files are modified
3. **Given** a user runs import with `--dry-run` flag and JSON output, **When** the preview completes, **Then** MediaHub outputs JSON results with a `dryRun: true` field and all preview information in machine-readable format
4. **Given** a user runs import with `--dry-run` flag, **When** collision scenarios would occur, **Then** MediaHub preview shows what collision handling policy would be applied and what the resulting filenames would be
5. **Given** a user runs import with `--dry-run` flag, **When** the preview completes, **Then** MediaHub exit code is 0 (successful preview) and no file system modifications to source files or library media files occur

---

### User Story 2 - Explicit Confirmation for Import Operations (Priority: P1)

A user wants explicit confirmation before MediaHub performs actual file copy operations. The CLI should prompt for explicit user confirmation before proceeding with import operations that modify the file system, with a `--yes` flag available to bypass confirmation for non-interactive scripts.

**Why this priority**: Explicit confirmation prevents accidental imports and gives users a final checkpoint before file system modifications. This aligns with Constitution principle 3.3 "Safe Operations" which requires explicit user confirmation for destructive actions.

**Independent Test**: Can be fully tested by running `mediahub import <source-id> --all --library <path>` (without `--yes`) and verifying that:
- CLI prompts for confirmation
- Import does not proceed without confirmation
- `--yes` flag bypasses confirmation for scripting
- Confirmation prompt shows summary of what will be imported

**Acceptance Scenarios**:

1. **Given** a user runs `mediahub import <source-id> --all --library <path>` without `--yes` flag, **When** the command executes, **Then** MediaHub displays a confirmation prompt showing what will be imported (item count, source, destination) and waits for user input
2. **Given** a user is prompted for confirmation, **When** they type "yes" or "y", **Then** MediaHub proceeds with the import operation
3. **Given** a user is prompted for confirmation, **When** they type "no" or "n" or press Ctrl+C, **Then** MediaHub cancels the import operation, displays a cancellation message, and exits with code 0 (user cancellation is not an error)
4. **Given** a user runs import with `--yes` flag, **When** the command executes, **Then** MediaHub proceeds with import without prompting (suitable for scripting)
5. **Given** a user runs import with `--dry-run` flag, **When** the command executes, **Then** MediaHub does not prompt for confirmation (dry-run is always safe and requires no confirmation)
6. **Given** a user runs import in a non-interactive environment (no TTY), **When** the command executes without `--yes`, **Then** MediaHub detects non-interactive mode and fails with a clear error message instructing the user to use `--yes` flag

---

### User Story 3 - Read-Only Guarantees for Detection (Priority: P1)

A user wants assurance that detection operations never modify source files or copy media files. The CLI should make read-only guarantees explicit and provide mechanisms to verify that detection operations cannot accidentally modify source files or copy media. Note: Detection may write result files and update source metadata within the library (`.mediahub/` directory), but it never modifies source files or copies media.

**Why this priority**: Detection is already read-only in the core implementation, but users need explicit CLI guarantees and documentation. This builds trust and aligns with Constitution principle 3.3 "Safe Operations".

**Independent Test**: Can be fully tested by running detection operations and verifying that:
- No files are created or modified
- No library metadata is modified
- CLI documentation explicitly states read-only guarantee
- Detection can be run safely on read-only sources

**Acceptance Scenarios**:

1. **Given** a user runs `mediahub detect <source-id> --library <path>`, **When** detection completes, **Then** MediaHub guarantees that no source files were modified and no media files were copied (detection may write result files in `.mediahub/` directory but never modifies source files)
2. **Given** a user runs detection on a read-only source (e.g., mounted read-only volume), **When** detection executes, **Then** MediaHub successfully performs detection without attempting any write operations
3. **Given** a user runs detection, **When** detection completes, **Then** MediaHub CLI help and documentation explicitly state that detection is read-only and safe to run
4. **Given** a user runs detection with invalid library path, **When** detection fails, **Then** MediaHub does not create or modify any files during the error handling process

---

### User Story 4 - Safety-First Error Handling (Priority: P1)

A user wants MediaHub to fail safely when errors occur during import operations, ensuring that partial imports don't leave the library in an inconsistent state. The CLI should provide clear error messages and ensure that import operations are atomic where possible.

**Why this priority**: Safe error handling prevents library corruption and data loss. This aligns with Constitution principle 4.1 "Data Safety" which requires file integrity and recoverability.

**Independent Test**: Can be fully tested by simulating error conditions during import (e.g., insufficient disk space, permission errors) and verifying that:
- Import fails gracefully
- No partial files are left in inconsistent state
- Error messages are clear and actionable
- Library state remains valid

**Acceptance Scenarios**:

1. **Given** a user runs import and encounters an error (e.g., disk full, permission denied), **When** the error occurs, **Then** MediaHub stops the import operation, reports the error clearly, and ensures no partial files are left in an inconsistent state
2. **Given** a user runs import and the process is interrupted (Ctrl+C), **When** interruption occurs, **Then** MediaHub handles the interruption gracefully, reports what was imported before interruption, and exits cleanly
3. **Given** a user runs import and an error occurs, **When** the error is reported, **Then** MediaHub provides actionable error messages that explain what went wrong and how to resolve the issue
4. **Given** a user runs import with `--dry-run` flag, **When** an error would occur during actual import, **Then** MediaHub preview shows what errors would occur (e.g., "Would fail: insufficient disk space")

---

### Edge Cases

- What happens when a user runs `--dry-run` and `--yes` together? (dry-run should not require confirmation, but --yes should be accepted)
- What happens when a user runs import with `--dry-run` on a source that becomes inaccessible during preview?
- What happens when a user runs import with confirmation prompt in a script that doesn't have TTY?
- What happens when a user cancels confirmation (Ctrl+C) - is this an error or successful cancellation?
- What happens when a user runs detection on a source that has write permissions but they want read-only guarantee?
- What happens when a user runs import and library becomes read-only during import?
- What happens when a user runs import with `--dry-run` and the preview shows collisions that would require user input in actual import?
- What happens when a user runs import with `--yes` but there are validation errors before import starts?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: MediaHub CLI MUST support a `--dry-run` flag on the `import` command that previews import operations without copying any files
- **FR-002**: MediaHub CLI MUST display detailed preview information when `--dry-run` is used, including source paths, destination paths, and collision handling decisions
- **FR-003**: MediaHub CLI MUST ensure that `--dry-run` operations perform zero file system modifications to source files or library media files (no file copying, modification, or deletion of source or media files)
- **FR-004**: MediaHub CLI MUST support a `--yes` flag on the `import` command that bypasses confirmation prompts for non-interactive usage
- **FR-005**: MediaHub CLI MUST prompt for explicit confirmation before performing import operations (when `--yes` is not provided and not in dry-run mode)
- **FR-006**: MediaHub CLI MUST display a clear confirmation prompt showing what will be imported (item count, source, destination summary) before proceeding
- **FR-007**: MediaHub CLI MUST handle user cancellation of confirmation (typing "no", "n", or Ctrl+C) gracefully and exit with code 0 (cancellation is not an error)
- **FR-008**: MediaHub CLI MUST detect non-interactive environments (no TTY) and require `--yes` flag for import operations (fail with clear error if `--yes` is not provided)
- **FR-009**: MediaHub CLI MUST explicitly document that `detect` operations are read-only and safe to run
- **FR-010**: MediaHub CLI MUST ensure that detection operations never modify source files or copy media files (read-only guarantee for source and media files; detection may write result files in `.mediahub/` directory)
- **FR-011**: MediaHub CLI MUST provide clear, actionable error messages when import operations fail
- **FR-012**: MediaHub CLI MUST handle import interruptions (Ctrl+C) gracefully and report what was imported before interruption
- **FR-013**: MediaHub CLI MUST ensure that import errors do not leave the library in an inconsistent state (atomic operations where possible)
- **FR-014**: MediaHub CLI MUST support `--dry-run` flag with JSON output format, including a `dryRun: true` field in JSON results
- **FR-015**: MediaHub CLI MUST ensure that `--dry-run` preview accurately reflects what would happen during actual import (same collision handling, same destination mapping)
- **FR-016**: MediaHub CLI MUST validate that `--dry-run` and actual import produce consistent results (same inputs produce same preview/execution)

### Key Entities *(include if feature involves data)*

- **Dry-Run Mode**: A CLI mode that previews import operations without performing any file system modifications to source files or library media files. Dry-run mode shows what would be imported, where files would be placed, and what collision handling would be applied, but performs zero file operations on sources or media.

- **Confirmation Prompt**: An interactive prompt that requires explicit user confirmation before proceeding with import operations that modify the file system. The prompt displays a summary of what will be imported and waits for user input ("yes"/"y" to proceed, "no"/"n" to cancel).

- **Read-Only Guarantee**: An explicit guarantee that certain operations (detection) will never modify source files or copy media files. This guarantee is documented in CLI help and enforced by the implementation. Note: Detection may write result files and update source metadata within the library (`.mediahub/` directory), but it never modifies source files or copies media.

- **Safety-First Error Handling**: Error handling that prioritizes data safety and library integrity. When errors occur during import, MediaHub ensures no partial files are left in inconsistent state and provides clear, actionable error messages.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can preview import operations with `--dry-run` flag and see accurate preview of what would be imported (100% accuracy: dry-run preview matches actual import results)
- **SC-002**: Users can run `--dry-run` operations without any file system modifications to source files or library media files (zero file operations on sources/media verified by tests)
- **SC-003**: Users are prompted for explicit confirmation before import operations (when `--yes` is not provided and not in dry-run mode)
- **SC-004**: Users can bypass confirmation with `--yes` flag for scripting (non-interactive usage works correctly)
- **SC-005**: Users receive clear error messages when running import in non-interactive mode without `--yes` flag (error message instructs user to use `--yes`)
- **SC-006**: Detection operations are explicitly documented as read-only for source and media files (documentation in CLI help and user-facing messages clarifies that detection never modifies source files or copies media, though it may write result files in `.mediahub/` directory)
- **SC-007**: Import operations handle errors gracefully without leaving library in inconsistent state (no partial files, valid library state after errors)
- **SC-008**: Import operations handle interruptions (Ctrl+C) gracefully and report what was imported before interruption
- **SC-009**: Dry-run preview accurately reflects actual import behavior (same collision handling, same destination mapping - verified by tests)
- **SC-010**: JSON output format includes `dryRun: true` field when `--dry-run` flag is used
- **SC-011**: All existing core tests still pass after safety features implementation (no regression in core functionality)
- **SC-012**: Safety features work correctly with all existing CLI commands and options (compatibility with `--json`, `--library`, etc.)

## Assumptions

- Users will primarily use `--dry-run` to preview imports before executing them
- Users will use `--yes` flag in scripts and automation workflows
- Interactive confirmation is suitable for terminal environments (Terminal.app, iTerm)
- Non-interactive detection (no TTY) should fail gracefully with clear error message requiring `--yes` flag
- Dry-run operations should be fast (no actual file I/O, so should complete quickly)
- Confirmation prompts should be clear and show actionable information (item count, source, destination summary)
- Detection operations are already read-only for source and media files in core implementation (detection never modifies source files or copies media, though it may write result files in `.mediahub/` directory); CLI needs to make this explicit and document it
- Import operations already have atomic file copy in core implementation; CLI needs to ensure error handling preserves this
- Safety features should not break existing CLI workflows (backward compatibility)
- Dry-run preview should use the same logic as actual import (same collision handling, same destination mapping) to ensure accuracy

## Safety Constraints

### Explicit Target Directories

- **CLI Code**: All CLI changes MUST be in `Sources/MediaHubCLI/` (NOT `Sources/MediaHub/`)
- **Core Code**: Core safety features (dry-run mode in import execution) MAY require changes in `Sources/MediaHub/` but MUST be minimal and focused on safety only
- **Tests**: CLI safety feature tests MUST be in `Tests/MediaHubTests/` or new `Tests/MediaHubCLITests/` if created
- **Documentation**: Safety feature documentation updates MAY be in `docs/` but MUST NOT modify existing ADRs without explicit justification

### Explicit "No Touch" Rules

- **DO NOT** modify existing core import logic beyond adding dry-run support
- **DO NOT** change existing detection behavior (it's already read-only)
- **DO NOT** modify Package.swift beyond adding dependencies if absolutely necessary
- **DO NOT** modify existing specs/ or docs/ except for this Slice 5 spec
- **DO NOT** change existing CLI command structure or argument parsing beyond adding new flags
- **DO NOT** modify existing error types or error handling beyond adding safety-specific error messages

### Explicit Validation Commands

- **Validation**: Run `swift test` to ensure all existing tests pass
- **Validation**: Run `scripts/smoke_cli.sh` to ensure CLI smoke tests pass with new safety features
- **Validation**: Manual testing of `--dry-run` flag to verify zero file operations
- **Validation**: Manual testing of confirmation prompts in interactive and non-interactive modes
- **Validation**: Verify that dry-run preview matches actual import results (same inputs produce same preview/execution)

## Non-Goals

- **P2 Features**: Fine-grained item selection for import (deferred from Slice 4, still out of scope)
- **P2 Features**: Interactive item-by-item confirmation (P1 supports all-or-nothing confirmation only)
- **P2 Features**: Import rollback or undo functionality (out of scope for Slice 5)
- **P2 Features**: Safety features for other operations beyond import (detection is already read-only, library/source operations are out of scope)
- **P2 Features**: Advanced dry-run features (e.g., dry-run with different collision policies, dry-run simulation of errors)
- **P2 Features**: Safety audit logs or safety event tracking (out of scope for Slice 5)
- **P2 Features**: Read-only mode for entire CLI (P1 focuses on detection read-only guarantee and import safety)

## Constitutional Compliance

This specification adheres to the MediaHub Constitution:

- **3.3 Safe Operations**: Explicit confirmation for destructive actions, dry-run preview, read-only guarantees
- **4.1 Data Safety**: Safety-first error handling, no partial files, library integrity preservation
- **3.4 Deterministic Behavior**: Dry-run preview must match actual import results (same inputs produce same outputs)
- **3.2 Transparent Storage**: Safety features don't introduce opaque behaviors; all safety mechanisms are explicit and understandable
