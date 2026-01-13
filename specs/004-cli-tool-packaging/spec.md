# Feature Specification: MediaHub CLI Tool & Packaging

**Feature Branch**: `004-cli-tool-packaging`  
**Created**: 2026-01-13  
**Status**: Ready for Plan  
**Input**: User description: "Provide a command-line interface (CLI) that exposes the existing MediaHub core capabilities to users without requiring Swift code or Xcode."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Create and Open Libraries via CLI (Priority: P1)

A user wants to create new MediaHub libraries and open existing libraries from the command line without writing Swift code. The CLI should provide clear feedback about library creation and opening operations, and should support discovering and listing existing libraries.

**Why this priority**: Library management is the foundational workflow. Without the ability to create and open libraries via CLI, users cannot begin using MediaHub from the terminal.

**Independent Test**: Can be fully tested by creating a new library via CLI, verifying it exists, opening it, and listing known libraries. This delivers the core capability of library lifecycle management via CLI.

**Acceptance Scenarios**:

1. **Given** a user wants to create a new library, **When** they run `mediahub library create <path>`, **Then** MediaHub creates a new library at the specified path and reports success
2. **Given** a user wants to open an existing library, **When** they run `mediahub library open <path>`, **Then** MediaHub opens the library and displays library information (does not persist active library state; subsequent commands require explicit `--library` argument or environment variable)
3. **Given** a user wants to see all known libraries, **When** they run `mediahub library list`, **Then** MediaHub lists all discoverable libraries with their paths and identifiers
4. **Given** a user attempts to create a library at an invalid path, **When** the creation fails, **Then** MediaHub reports a clear, actionable error message explaining why creation failed
5. **Given** a user attempts to open a library that doesn't exist, **When** the opening fails, **Then** MediaHub reports a clear error message indicating the library was not found

---

### User Story 2 - Attach and List Sources via CLI (Priority: P1)

A user wants to attach folder-based Sources to a library and list attached Sources from the command line. The CLI should validate Source paths and provide clear feedback about attachment operations. Each command requires explicit library context via `--library` argument or `MEDIAHUB_LIBRARY` environment variable.

**Why this priority**: Source attachment is required before detection can be performed. Without CLI support for attaching Sources, users cannot proceed with the detection workflow.

**Independent Test**: Can be fully tested by attaching a Source to a library (with explicit `--library` context) via CLI, listing attached Sources, and verifying the association persists. This delivers the core capability of Source management via CLI.

**Acceptance Scenarios**:

1. **Given** a user provides library context via `--library` argument or `MEDIAHUB_LIBRARY` environment variable, **When** they run `mediahub source attach <path> --library <path>`, **Then** MediaHub validates the Source path, attaches it to the library, and reports success
2. **Given** a user provides library context via `--library` argument or `MEDIAHUB_LIBRARY` environment variable, **When** they run `mediahub source list --library <path>`, **Then** MediaHub lists all Sources attached to the library with their paths and identifiers
3. **Given** a user attempts to attach an invalid Source path, **When** the attachment fails, **Then** MediaHub reports a clear error message explaining why attachment failed (path doesn't exist, permission denied, etc.)
4. **Given** a user attempts to attach a Source when no library context is provided, **When** the command runs, **Then** MediaHub reports a clear error indicating that a library must be provided via `--library` argument or `MEDIAHUB_LIBRARY` environment variable
5. **Given** a user attaches a Source, **When** they run `mediahub source list` with the same library context (via `--library` argument or environment variable), **Then** the Source association persists and is visible in `mediahub source list` (Source associations are stored in the library, not in CLI state)

---

### User Story 3 - Run Detection via CLI (Priority: P1)

A user wants to run detection on an attached Source from the command line to discover new media items available for import. The CLI should provide progress feedback during detection and display results in a clear, human-readable format.

**Why this priority**: Detection is the core workflow that identifies new media items. Without CLI support for detection, users cannot see what's available for import.

**Independent Test**: Can be fully tested by running detection on a Source via CLI and verifying that results are displayed correctly and match the programmatic API results. This delivers the detection capability via CLI.

**Acceptance Scenarios**:

1. **Given** a user has an attached Source and provides library context via `--library` argument or `MEDIAHUB_LIBRARY` environment variable, **When** they run `mediahub detect <source-id> --library <path>`, **Then** MediaHub runs detection on the Source and displays a summary of candidate items found
2. **Given** a user runs detection, **When** detection is in progress, **Then** MediaHub displays progress feedback (e.g., "Scanning source...", "Comparing with library...", "Found N candidates")
3. **Given** a user runs detection, **When** detection completes, **Then** MediaHub displays results showing the number of new candidate items, known items excluded, and any errors encountered
4. **Given** a user runs detection with `--json` flag, **When** detection completes, **Then** MediaHub outputs results in JSON format suitable for scripting
5. **Given** a user runs detection on an inaccessible Source, **When** detection fails, **Then** MediaHub reports a clear error message explaining why detection failed

---

### User Story 4 - Import Items via CLI (Priority: P1)

A user wants to import candidate items from a detection result into their library via the command line. For P1, the CLI supports importing all detected items; fine-grained item selection is deferred to P2. The CLI should provide progress feedback during the import operation.

**Why this priority**: Import execution is the final step in the workflow. Without CLI support for import, users cannot actually import media into their libraries from the terminal.

**Independent Test**: Can be fully tested by running detection, then importing all items via CLI, and verifying that files are copied to the library and import results are displayed correctly. This delivers the import capability via CLI.

**Acceptance Scenarios**:

1. **Given** a user has run detection and has candidate items, and provides library context via `--library` argument or `MEDIAHUB_LIBRARY` environment variable, **When** they run `mediahub import <source-id> --all --library <path>`, **Then** MediaHub imports all detected candidate items for the specified Source and displays a summary of imported, skipped, and failed items
2. **Given** a user runs import, **When** import is in progress, **Then** MediaHub displays progress feedback (e.g., "Importing item 1 of N...", "Copying file...")
3. **Given** a user runs import, **When** import completes, **Then** MediaHub displays results showing what was imported, what was skipped (with reasons), and what failed (with error messages)
4. **Given** a user runs import with `--json` flag, **When** import completes, **Then** MediaHub outputs results in JSON format suitable for scripting
5. **Given** a user runs import without specifying `--all`, **When** the command runs, **Then** MediaHub reports a clear error indicating that item selection is required

*Fine-grained item selection is out of scope for P1 and deferred to P2.*

---

### User Story 5 - View Library Status and Get Help via CLI (Priority: P1)

A user wants to check the status of a library and get help about CLI commands. The CLI should provide a status command showing the library and its state (with explicit library context via `--library` argument or `MEDIAHUB_LIBRARY` environment variable), and a comprehensive help system for all commands.

**Why this priority**: Status and help are essential for CLI usability. Users need to know what library is active and how to use commands effectively.

**Independent Test**: Can be fully tested by running status and help commands and verifying that output is clear and accurate. This delivers essential CLI usability features.

**Acceptance Scenarios**:

1. **Given** a user provides library context via `--library` argument or `MEDIAHUB_LIBRARY` environment variable, **When** they run `mediahub status --library <path>`, **Then** MediaHub displays the library path, identifier, and basic information (number of sources, last detection time, etc.)
2. **Given** a user wants help with a command, **When** they run `mediahub <command> --help`, **Then** MediaHub displays comprehensive help text explaining the command, its options, and usage examples
3. **Given** a user runs `mediahub --help`, **When** the command executes, **Then** MediaHub displays an overview of all available commands and their purposes
4. **Given** a user runs status when no library context is provided, **When** the command executes, **Then** MediaHub clearly indicates that a library must be provided via `--library` argument or `MEDIAHUB_LIBRARY` environment variable
5. **Given** a user wants help with a subcommand, **When** they run `mediahub library create --help`, **Then** MediaHub displays help specific to that subcommand

---

### Edge Cases

- What happens when a user runs CLI commands without providing library context (no `--library` argument or `MEDIAHUB_LIBRARY` environment variable)?
- What happens when a user runs CLI commands with an invalid library path?
- What happens when a user runs detection or import on a Source that becomes inaccessible during the operation?
- What happens when a user runs CLI commands in a non-interactive environment (scripting)?
- What happens when a user runs CLI commands with invalid arguments or options?
- What happens when a user runs CLI commands that require long-running operations (detection, import) and the process is interrupted (Ctrl+C)?
- What happens when a user runs CLI commands with conflicting options?
- What happens when a user runs CLI commands with malformed JSON output requests?
- What happens when a user runs CLI commands on a library that has been moved or renamed?
- What happens when a user runs CLI commands with insufficient permissions?
- What happens when a user runs CLI commands with invalid Source identifiers?
- What happens when a user runs import with invalid source-id or when no detection has been run? (Note: P1 supports `--all` only; fine-grained item selection is P2)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: MediaHub MUST provide an executable CLI target in the Swift Package. The CLI target MUST be a separate executable target (NOT part of the MediaHub library target). The CLI source code MUST be located in `Sources/MediaHubCLI/` (NOT `Sources/MediaHub/` or `Sources/mediahub/`). The entry point `main.swift` MUST be located at `Sources/MediaHubCLI/main.swift` and MUST NEVER exist under `Sources/MediaHub/`.
- **FR-002**: MediaHub MUST support creating libraries via CLI command `mediahub library create <path>`
- **FR-003**: MediaHub MUST support opening libraries via CLI command `mediahub library open <path>` and displaying library information. The command does NOT persist active library state across CLI invocations. Each CLI command invocation is stateless and requires explicit library context via `--library` argument or `MEDIAHUB_LIBRARY` environment variable.
- **FR-004**: MediaHub MUST support listing discoverable libraries via CLI command `mediahub library list`
- **FR-005**: MediaHub MUST support attaching Sources to a library via CLI command `mediahub source attach <path>`. The library context MUST be provided explicitly via `--library` argument or `MEDIAHUB_LIBRARY` environment variable.
- **FR-006**: MediaHub MUST support listing attached Sources for a library via CLI command `mediahub source list`. The library context MUST be provided explicitly via `--library` argument or `MEDIAHUB_LIBRARY` environment variable.
- **FR-007**: MediaHub MUST support running detection on a Source via CLI command `mediahub detect <source-id>`. The library context MUST be provided explicitly via `--library` argument or `MEDIAHUB_LIBRARY` environment variable.
- **FR-008**: MediaHub MUST support importing all detected items from detection results via CLI command `mediahub import <source-id> --all`. For P1, only `--all` flag is supported; fine-grained item selection (e.g., `--items <paths>`) is out of scope and deferred to P2.
- **FR-009**: MediaHub MUST support viewing library status via CLI command `mediahub status`
- **FR-010**: MediaHub MUST provide a help system accessible via `--help` flag for all commands and subcommands
- **FR-011**: MediaHub MUST support human-readable output format by default for all CLI commands
- **FR-012**: MediaHub MUST support machine-readable JSON output format via `--json` flag for commands that produce structured result data (e.g., detection results, import results, list commands)
- **FR-013**: MediaHub MUST provide progress feedback for long-running operations (detection, import) in human-readable mode using operation stages and item counts (no percentage calculation required for P1)
- **FR-014**: MediaHub MUST format error messages in a user-friendly, actionable format for CLI output
- **FR-015**: MediaHub MUST map existing error types to clear CLI error messages
- **FR-016**: MediaHub MUST support non-interactive usage (scriptable mode) where commands do not prompt for user input
- **FR-017**: MediaHub MUST use Swift Argument Parser or equivalent for CLI argument parsing and help generation
- **FR-018**: MediaHub MUST support an explicit active library context provided per CLI invocation (e.g., command-line argument `--library <path>` or environment variable `MEDIAHUB_LIBRARY`). The CLI is stateless: no library state persists across invocations. Each command that requires a library context MUST receive it explicitly via argument or environment variable.
- **FR-019**: MediaHub MUST validate CLI command arguments and report clear errors for invalid inputs
- **FR-020**: MediaHub MUST ensure CLI commands can be used in scripts without requiring user interaction
- **FR-021**: MediaHub MUST provide appropriate exit codes (0 for success, non-zero for errors) for scriptability
- **FR-022**: MediaHub MUST reuse existing MediaHub core APIs without modifying core logic or behavior
- **FR-023**: MediaHub MUST maintain deterministic behavior when accessed via CLI (same inputs produce same outputs)
- **FR-024**: MediaHub MUST support displaying detection results in a clear, tabular, or structured format in human-readable mode
- **FR-025**: MediaHub MUST support displaying import results with clear status indicators (imported, skipped, failed) and reasons in human-readable mode

### Key Entities *(include if feature involves data)*

- **CLI Command**: A single executable command in the MediaHub CLI (e.g., `mediahub library create`). Commands are structured hierarchically with top-level commands and subcommands. Each command has a clear purpose, accepts arguments and options, and produces output in human-readable or JSON format.

-- **Active Library**: The library context for CLI operations, provided explicitly per CLI invocation. The active library is used as the context for Source attachment, detection, and import operations. For P1, the active library context MUST be provided explicitly per CLI invocation (via `--library <path>` command-line argument or `MEDIAHUB_LIBRARY` environment variable). No implicit or persisted active-library state is maintained across CLI invocations in P1. The CLI is stateless: each command invocation is independent and requires explicit library context.

-- **CLI Output Format**: The format in which CLI commands present results to users. Two formats are supported: human-readable (default) for interactive use, and JSON (via `--json` flag) for scripting and automation. Human-readable format uses tables, lists, and structured text. JSON format uses standard JSON serialization of result models. For P1, JSON output is only required for commands that produce structured result data; help and purely informational commands may remain human-readable only.

-- **Progress Indicator**: A mechanism for providing feedback during long-running CLI operations (detection, import). Progress indicators show operation status, current step, and item counts and stage-based messages only for P1. Progress indicators are only shown in human-readable mode and are suppressed in JSON mode or when output is redirected to a file.

- **CLI Error Message**: A user-friendly error message formatted for terminal output. CLI error messages are derived from existing MediaHub error types but are formatted to be clear and actionable for CLI users. Error messages include context about what operation failed and how to resolve the issue.

- **Command Help System**: A comprehensive help system accessible via `--help` flag that explains command syntax, options, arguments, and provides usage examples. Help text is generated automatically from command definitions (using Swift Argument Parser) and may include additional documentation.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can perform the complete workflow (create library → attach source → detect → import) via CLI without writing Swift code
- **SC-002**: All CLI commands are discoverable via `--help` and provide clear, comprehensive help text
- **SC-003**: CLI error messages are clear and actionable (users can understand what went wrong and how to fix it)
- **SC-004**: CLI commands can be used in scripts without requiring user interaction (non-interactive mode)
- **SC-005**: CLI commands produce appropriate exit codes (0 for success, non-zero for errors) for scriptability
- **SC-006**: CLI human-readable output is clear and well-formatted (tables, lists, structured text)
- **SC-007**: CLI JSON output is valid JSON and can be parsed by standard JSON parsers
- **SC-008**: CLI progress indicators provide meaningful feedback during long-running operations (detection, import)
- **SC-009**: CLI commands maintain deterministic behavior (same inputs produce same outputs) consistent with programmatic API
- **SC-010**: All existing core tests still pass after CLI implementation (no regression in core functionality)
- **SC-011**: CLI library context is managed correctly (commands receive and use the correct library context provided explicitly per invocation)
- **SC-012**: CLI commands validate arguments and report clear errors for invalid inputs within 1 second
- **SC-013**: CLI help system is accessible for all commands and subcommands (100% coverage)

## Assumptions

- CLI will be used primarily on macOS (Swift Package executable)
- Users have basic familiarity with command-line interfaces
- CLI will be invoked from terminal environments (Terminal.app, iTerm, scripts)
- Active library context is provided explicitly per CLI invocation; persistent CLI state is out of scope for P1
- CLI target is a separate executable target (NOT part of the MediaHub library target)
- CLI source code is located in `Sources/MediaHubCLI/` (NOT `Sources/MediaHub/` or `Sources/mediahub/`) to avoid case-insensitive filesystem collisions on macOS
- CLI entry point `main.swift` is located at `Sources/MediaHubCLI/main.swift` and MUST NEVER exist under `Sources/MediaHub/`
- No files in `Sources/MediaHub/` (the library target) may be deleted, moved, or renamed during Slice 4 implementation
- Swift Argument Parser or equivalent library is available for CLI argument parsing
- CLI output will be displayed in terminal environments that support standard output and error streams
- Long-running operations (detection, import) may be interrupted by user (Ctrl+C), and CLI should handle interruption gracefully
- CLI commands will be used in both interactive and non-interactive (scripted) contexts
- JSON output format will be used primarily for scripting and automation
- Human-readable output format will be used primarily for interactive use
- CLI commands will reuse existing MediaHub core APIs without modification
- Core MediaHub behavior (determinism, safety, transparency) must be preserved when accessed via CLI
- CLI is a thin orchestration and presentation layer; no business logic should be embedded in CLI code
- CLI commands may be chained or used in scripts, so each command must be independent and stateless. Library context must be provided explicitly per command invocation (via `--library` argument or `MEDIAHUB_LIBRARY` environment variable); no state persists across invocations.
- Error handling in CLI should map existing error types to user-friendly messages without changing core error behavior