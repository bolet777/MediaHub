# Implementation Plan: MediaHub CLI Tool & Packaging (Slice 4)

**Feature**: MediaHub CLI Tool & Packaging  
**Specification**: `specs/004-cli-tool-packaging/spec.md`  
**Slice**: 4 - CLI Tool & Packaging  
**Created**: 2026-01-13

## Plan Scope

This plan implements **Slice 4 only**, which provides a command-line interface (CLI) that exposes MediaHub core capabilities to users without requiring Swift code or Xcode. This includes:

- CLI executable target in Swift Package
- Library management commands (create, open, list)
- Source management commands (attach, list)
- Detection command with progress feedback
- Import command with progress feedback
- Status command
- Comprehensive help system
- Human-readable and JSON output formats
- Progress indicators for long-running operations
- Error message formatting and mapping
- Active library context management (explicit per-invocation)

**Explicitly out of scope**:
- Persistent CLI state across invocations (active library context is explicit per-invocation for P1)
- Interactive prompts or user input (non-interactive mode only for P1)
- Fine-grained item selection for import (deferred to P2; P1 supports `--all` only)
- Advanced CLI features (completion, aliases, configuration files)
- GUI or visual interfaces
- Background execution or daemon mode
- CLI-specific caching or optimization beyond core functionality

## Constitutional Compliance

This plan adheres to the MediaHub Constitution:

- **Transparent Storage**: CLI does not introduce new storage mechanisms; uses existing Library and Source storage
- **Safe Operations**: CLI operations are read-only where appropriate (detection) and safe (import); no CLI-specific side effects
- **Deterministic Behavior**: CLI commands produce identical results for identical inputs, consistent with programmatic API
- **Interoperability First**: CLI output formats (JSON, human-readable) are standard and scriptable
- **Scalability by Design**: CLI supports all Library and Source operations without CLI-specific limitations

## Work Breakdown

### Component 1: CLI Executable Target & Package Structure

**Purpose**: Set up the CLI executable target in the Swift Package and establish the basic CLI infrastructure.

**Responsibilities**:
- Add executable target to Package.swift
- Create main CLI entry point
- Set up Swift Argument Parser or equivalent dependency
- Establish CLI command structure and hierarchy
- Ensure CLI can be built and executed independently
- Support installation and distribution of CLI executable

**Requirements Addressed**:
- FR-001: Provide an executable CLI target in the Swift Package
- FR-017: Use Swift Argument Parser or equivalent for CLI argument parsing and help generation

**Key Decisions**:
- Which argument parsing library to use (Swift Argument Parser recommended)
- CLI executable name: `mediahub` (user-facing command name)
- Package structure for CLI code: **MUST be a separate executable target** (NOT within MediaHub library target)
- CLI source directory: **MUST be `Sources/MediaHubCLI/`** (NOT `Sources/MediaHub/` or `Sources/mediahub/`) to avoid case-insensitive filesystem collisions on macOS
- CLI entry point: **MUST be `Sources/MediaHubCLI/main.swift`** and **MUST NEVER exist under `Sources/MediaHub/`**
- How to handle CLI installation (manual, Homebrew, or other distribution method)
- CLI is a separate executable product (NOT part of MediaHub library)

**Validation Points**:
- CLI executable can be built successfully
- CLI executable can be run from command line
- CLI responds to `--help` with basic information
- CLI executable is properly packaged and distributable

**Risks & Open Questions**:
- ~~Should CLI be a separate Swift Package or part of MediaHub package?~~ **RESOLVED**: CLI is a separate executable target within MediaHub package (NOT part of MediaHub library target)
- How to handle CLI installation and PATH setup?
- Should CLI support version information (`--version`)?
- How to ensure CLI executable is compatible across macOS versions?

**NON-NEGOTIABLE CONSTRAINTS**:
- CLI target MUST be a separate executable target (NOT part of MediaHub library target)
- CLI source code MUST be in `Sources/MediaHubCLI/` (NOT `Sources/MediaHub/` or `Sources/mediahub/`)
- CLI entry point `main.swift` MUST be at `Sources/MediaHubCLI/main.swift` and MUST NEVER exist under `Sources/MediaHub/`
- NO files in `Sources/MediaHub/` may be deleted, moved, or renamed during Slice 4 implementation
- If duplicates are found, STOP and report; do NOT delete or "clean up" files

---

### Component 2: Command Structure & Help System

**Purpose**: Define the hierarchical command structure and implement comprehensive help system for all commands and subcommands.

**Responsibilities**:
- Define top-level command structure (`mediahub library`, `mediahub source`, `mediahub detect`, `mediahub import`, `mediahub status`)
- Implement help system for all commands and subcommands
- Generate help text automatically from command definitions
- Support `--help` flag for all commands and subcommands
- Provide usage examples in help text
- Ensure help text is clear and comprehensive

**Requirements Addressed**:
- FR-010: Provide a help system accessible via `--help` flag for all commands and subcommands
- FR-017: Use Swift Argument Parser or equivalent for CLI argument parsing and help generation
- User Story 5: Get help about CLI commands (all acceptance scenarios)
- SC-002: All CLI commands are discoverable via `--help` and provide clear, comprehensive help text
- SC-013: CLI help system is accessible for all commands and subcommands (100% coverage)

**Key Decisions**:
- Command hierarchy structure (top-level commands and subcommands)
- Help text format and style (brief vs. detailed, examples included)
- Whether to support `--help` and `-h` flags
- How to organize help text (command description, arguments, options, examples)
- Whether to support help for specific subcommands (e.g., `mediahub library create --help`)

**Validation Points**:
- All commands respond to `--help` with appropriate help text
- Help text includes command descriptions, arguments, options, and examples
- Help text is clear and comprehensive
- Help system covers 100% of commands and subcommands

**Risks & Open Questions**:
- How detailed should help text be (brief vs. comprehensive)?
- Should help text include examples for all commands?
- How to handle help text for nested subcommands?
- Should help text be generated automatically or manually maintained?

---

### Component 3: Active Library Context Management

**Purpose**: Manage the active library context for CLI operations, supporting explicit per-invocation context (command-line argument or environment variable).

**Responsibilities**:
- Support explicit active library context per CLI invocation
- Accept library path via command-line argument (e.g., `--library <path>`)
- Accept library path via environment variable (e.g., `MEDIAHUB_LIBRARY`)
- Validate active library path before use
- Provide clear error messages when no active library is set
- Ensure active library context is used correctly by all commands

**Requirements Addressed**:
- FR-018: Support an explicit active library context provided per CLI invocation (e.g., command-line argument or environment variable)
- FR-003: Support opening libraries via CLI command `mediahub library open <path>` and displaying library information (does not persist active library state)
- User Story 1: Open existing libraries (acceptance scenarios 2, 5)
- User Story 2: Attach Sources (acceptance scenario 4)
- SC-011: CLI active library state is managed correctly (commands use the correct library context)

**Key Decisions**:
- How to specify active library: **BOTH command-line argument AND environment variable** (explicit per-invocation, stateless CLI)
- Argument name for library path: `--library <path>`
- Environment variable name: `MEDIAHUB_LIBRARY`
- Precedence: **Command-line argument takes precedence over environment variable**
- Whether to support library identifier in addition to path (out of scope for P1; use path only)
- How to handle library path validation and error reporting
- **CRITICAL**: CLI is stateless; no library state persists across invocations. Each command requiring library context MUST receive it explicitly.

**Validation Points**:
- Active library context is correctly resolved from arguments or environment variable
- Commands use active library context correctly
- Clear error messages when no active library is set
- Library path validation works correctly
- Precedence rules are followed correctly

**Risks & Open Questions**:
- Should active library context support library identifiers in addition to paths?
- How to handle relative vs. absolute library paths?
- Should CLI support opening library and setting it as active in one command?
- How to handle library path resolution (symlinks, tilde expansion)?

---

### Component 4: Library Management Commands

**Purpose**: Implement CLI commands for creating, opening, and listing libraries.

**Responsibilities**:
- Implement `mediahub library create <path>` command
- Implement `mediahub library open <path>` command
- Implement `mediahub library list` command
- Validate library paths and report clear errors
- Provide success/error feedback for library operations
- Support JSON output format for list command
- Ensure commands integrate with existing Library core APIs

**Requirements Addressed**:
- FR-002: Support creating libraries via CLI command `mediahub library create <path>`
- FR-003: Support opening libraries via CLI command `mediahub library open <path>` and displaying library information (does not persist active library state)
- FR-004: Support listing discoverable libraries via CLI command `mediahub library list`
- FR-012: Support machine-readable JSON output format via `--json` flag for commands that produce structured result data
- User Story 1: Create and open libraries via CLI (all acceptance scenarios)
- SC-001: Users can perform the complete workflow (create library → attach source → detect → import) via CLI without writing Swift code

**Key Decisions**:
- How to handle library creation errors (path exists, permission denied, etc.)
- How to format library list output (table, list, JSON)
- `library open` validates and displays library information but does NOT persist active library state. The CLI is stateless: subsequent commands MUST receive the library context explicitly via `--library` argument or `MEDIAHUB_LIBRARY` environment variable.
- How to display library information in list command (path, identifier, metadata)
- Whether to support library validation in create/open commands

**Validation Points**:
- Library creation works correctly and reports success
- Library open validates and displays library information (does not persist active library state)
- Library list displays all discoverable libraries
- Error messages are clear and actionable
- JSON output is valid and parseable

**Risks & Open Questions**:
- How to handle library creation when path already exists?
- Should library list include metadata (creation date, source count, etc.)?
- How to handle library discovery across different volumes or network locations?
- Should library open validate library before displaying information?

---

### Component 5: Source Management Commands

**Purpose**: Implement CLI commands for attaching and listing Sources.

**Responsibilities**:
- Implement `mediahub source attach <path>` command
- Implement `mediahub source list` command
- Validate Source paths and report clear errors
- Ensure active library context is required for Source operations
- Provide success/error feedback for Source operations
- Support JSON output format for list command
- Ensure commands integrate with existing Source core APIs

**Requirements Addressed**:
- FR-005: Support attaching Sources to the active library via CLI command `mediahub source attach <path>`
- FR-006: Support listing attached Sources for the active library via CLI command `mediahub source list`
- FR-012: Support machine-readable JSON output format via `--json` flag for commands that produce structured result data
- FR-019: Validate CLI command arguments and report clear errors for invalid inputs
- User Story 2: Attach and list Sources via CLI (all acceptance scenarios)
- SC-001: Users can perform the complete workflow (create library → attach source → detect → import) via CLI without writing Swift code

**Key Decisions**:
- How to handle Source attachment errors (path doesn't exist, permission denied, already attached, etc.)
- How to format Source list output (table, list, JSON)
- Whether to display Source metadata in list command (identifier, attachment date, status)
- How to validate Source paths before attachment
- Whether to support Source detachment command (out of scope for P1)

**Validation Points**:
- Source attachment works correctly and reports success
- Source list displays all attached Sources for active library
- Error messages are clear and actionable
- Active library context is required and validated
- JSON output is valid and parseable

**Risks & Open Questions**:
- How to handle Sources that are already attached to the library?
- Should Source list include Source status (accessible, inaccessible)?
- How to handle Source path validation (symlinks, network volumes)?
- Should Source attachment validate Source before attaching?

---

### Component 6: Detection Command

**Purpose**: Implement CLI command for running detection on a Source with progress feedback and result display.

**Responsibilities**:
- Implement `mediahub detect <source-id>` command
- Display progress feedback during detection (operation stages, item counts)
- Format detection results in human-readable format (tables, lists, structured text)
- Support JSON output format via `--json` flag
- Handle detection errors and report clear error messages
- Ensure command integrates with existing Detection core APIs
- Support non-interactive usage (no prompts)

**Requirements Addressed**:
- FR-007: Support running detection on a Source via CLI command `mediahub detect <source-id>`
- FR-011: Support human-readable output format by default for all CLI commands
- FR-012: Support machine-readable JSON output format via `--json` flag for commands that produce structured result data
- FR-013: Provide progress feedback for long-running operations (detection, import) in human-readable mode using operation stages and item counts
- FR-016: Support non-interactive usage (scriptable mode) where commands do not prompt for user input
- FR-024: Support displaying detection results in a clear, tabular, or structured format in human-readable mode
- User Story 3: Run detection via CLI (all acceptance scenarios)
- SC-001: Users can perform the complete workflow (create library → attach source → detect → import) via CLI without writing Swift code
- SC-006: CLI human-readable output is clear and well-formatted (tables, lists, structured text)
- SC-007: CLI JSON output is valid JSON and can be parsed by standard JSON parsers
- SC-008: CLI progress indicators provide meaningful feedback during long-running operations (detection, import)

**Key Decisions**:
- How to identify Sources in CLI (identifier, path, or both)
- Progress indicator format (stage messages, item counts, no percentages for P1)
- Human-readable result format (table, list, structured text)
- JSON output schema (how to serialize DetectionResult)
- How to handle detection interruptions (Ctrl+C)
- Whether to support detection on multiple Sources (out of scope for P1)

**Validation Points**:
- Detection command runs successfully and displays results
- Progress feedback is shown during detection
- Human-readable output is clear and well-formatted
- JSON output is valid and parseable
- Error messages are clear and actionable
- Detection interruptions are handled gracefully

**Risks & Open Questions**:
- How to format detection results in a clear, readable way?
- Should progress indicators show estimated time remaining (out of scope for P1)?
- How to handle very large detection results (thousands of items)?
- Should JSON output include all detection result fields or a subset?
- How to handle detection on inaccessible Sources?

---

### Component 7: Import Command

**Purpose**: Implement CLI command for importing candidate items from detection results with progress feedback and result display.

**Responsibilities**:
- Implement `mediahub import <source-id> --all` command
- Display progress feedback during import (operation stages, item counts)
- Format import results in human-readable format (tables, lists, structured text)
- Support JSON output format via `--json` flag
- Handle import errors and report clear error messages
- Ensure command integrates with existing Import core APIs
- Support non-interactive usage (no prompts)
- For P1, support importing all detected items only (fine-grained selection deferred to P2)

**Requirements Addressed**:
- FR-008: Support importing all detected items from detection results via CLI command `mediahub import <source-id> --all` (fine-grained item selection is out of scope for P1 and deferred to P2)
- FR-011: Support human-readable output format by default for all CLI commands
- FR-012: Support machine-readable JSON output format via `--json` flag for commands that produce structured result data
- FR-013: Provide progress feedback for long-running operations (detection, import) in human-readable mode using operation stages and item counts
- FR-016: Support non-interactive usage (scriptable mode) where commands do not prompt for user input
- FR-025: Support displaying import results with clear status indicators (imported, skipped, failed) and reasons in human-readable mode
- User Story 4: Import items via CLI (all acceptance scenarios)
- SC-001: Users can perform the complete workflow (create library → attach source → detect → import) via CLI without writing Swift code
- SC-006: CLI human-readable output is clear and well-formatted (tables, lists, structured text)
- SC-007: CLI JSON output is valid JSON and can be parsed by standard JSON parsers
- SC-008: CLI progress indicators provide meaningful feedback during long-running operations (detection, import)

**Key Decisions**:
- How to identify Sources in CLI (identifier, path, or both)
- Progress indicator format (stage messages, item counts, no percentages for P1)
- Human-readable result format (table, list, structured text)
- JSON output schema (how to serialize ImportResult)
- How to handle import interruptions (Ctrl+C)
- How to handle import when no detection has been run (error vs. auto-detect)
- Whether to support importing from latest detection result automatically

**Validation Points**:
- Import command runs successfully and displays results
- Progress feedback is shown during import
- Human-readable output is clear and well-formatted
- JSON output is valid and parseable
- Error messages are clear and actionable
- Import interruptions are handled gracefully
- Import results show imported, skipped, and failed items with reasons

**Risks & Open Questions**:
- How to format import results in a clear, readable way?
- Should progress indicators show estimated time remaining (out of scope for P1)?
- How to handle very large import jobs (thousands of items)?
- Should JSON output include all import result fields or a subset?
- How to handle import when detection result is stale or missing?
- Should import automatically run detection if no detection result exists?

---

### Component 8: Status Command

**Purpose**: Implement CLI command for viewing library status and active library information.

**Responsibilities**:
- Implement `mediahub status` command
- Display active library information (path, identifier, basic metadata)
- Show library state (number of sources, last detection time, etc.)
- Handle case when no library is active (clear error message)
- Support JSON output format via `--json` flag
- Ensure command integrates with existing Library core APIs

**Requirements Addressed**:
- FR-009: Support viewing library status via CLI command `mediahub status`
- FR-011: Support human-readable output format by default for all CLI commands
- FR-012: Support machine-readable JSON output format via `--json` flag for commands that produce structured result data
- User Story 5: View library status and get help via CLI (acceptance scenarios 1, 4)
- SC-001: Users can perform the complete workflow (create library → attach source → detect → import) via CLI without writing Swift code

**Key Decisions**:
- What information to display in status (path, identifier, source count, last detection, etc.)
- How to format status output (structured text, table, JSON)
- Whether to include library metadata (creation date, size, etc.)
- How to handle status when no library is active
- Whether to support status for specific library (via argument) or only active library

**Validation Points**:
- Status command displays active library information correctly
- Status output is clear and well-formatted
- JSON output is valid and parseable
- Clear error message when no library is active
- Status information is accurate and up-to-date

**Risks & Open Questions**:
- What level of detail should status include?
- Should status include library health or validation status?
- How to format status output for readability?
- Should status support querying specific library in addition to active library?

---

### Component 9: Output Formatting & Serialization

**Purpose**: Implement human-readable and JSON output formatting for CLI commands.

**Responsibilities**:
- Implement human-readable output formatters for all command results
- Implement JSON serialization for structured result data
- Support `--json` flag for commands that produce structured results
- Format tables, lists, and structured text for human-readable output
- Ensure JSON output is valid and parseable
- Format error messages consistently across output formats
- Support progress indicators in human-readable mode (suppressed in JSON mode)

**Requirements Addressed**:
- FR-011: Support human-readable output format by default for all CLI commands
- FR-012: Support machine-readable JSON output format via `--json` flag for commands that produce structured result data (e.g., detection results, import results, list commands)
- FR-013: Provide progress feedback for long-running operations (detection, import) in human-readable mode using operation stages and item counts (no percentage calculation required for P1)
- SC-006: CLI human-readable output is clear and well-formatted (tables, lists, structured text)
- SC-007: CLI JSON output is valid JSON and can be parsed by standard JSON parsers

**Key Decisions**:
- Human-readable format style (tables, lists, structured text)
- JSON output schema for each command result type
- How to handle progress indicators in JSON mode (suppress or include as events)
- How to format error messages in both output formats
- Whether to support colored output for human-readable format (optional for P1)
- How to handle very large result sets in both formats

**Validation Points**:
- Human-readable output is clear and well-formatted
- JSON output is valid JSON and parseable
- Progress indicators work correctly in human-readable mode
- Error messages are formatted consistently
- Both output formats contain equivalent information

**Risks & Open Questions**:
- How to format complex nested data structures in human-readable format?
- Should JSON output include metadata (timestamps, command arguments, etc.)?
- How to handle very large result sets without overwhelming output?
- Should human-readable format support colored output for better readability?
- How to ensure JSON output is compatible with standard JSON parsers?

---

### Component 10: Error Handling & Message Formatting

**Purpose**: Map existing MediaHub error types to clear, actionable CLI error messages and ensure consistent error handling.

**Responsibilities**:
- Map existing MediaHub error types to user-friendly CLI error messages
- Format error messages for terminal output
- Ensure error messages are clear and actionable
- Provide appropriate exit codes (0 for success, non-zero for errors)
- Handle validation errors and report clear messages
- Support error messages in both human-readable and JSON formats

**Requirements Addressed**:
- FR-014: Format error messages in a user-friendly, actionable format for CLI output
- FR-015: Map existing error types to clear CLI error messages
- FR-019: Validate CLI command arguments and report clear errors for invalid inputs
- FR-021: Provide appropriate exit codes (0 for success, non-zero for errors) for scriptability
- User Story 1: Create and open libraries (acceptance scenarios 4, 5)
- User Story 2: Attach Sources (acceptance scenarios 3, 4)
- User Story 3: Run detection (acceptance scenario 5)
- SC-003: CLI error messages are clear and actionable (users can understand what went wrong and how to fix it)
- SC-005: CLI commands produce appropriate exit codes (0 for success, non-zero for errors) for scriptability
- SC-012: CLI commands validate arguments and report clear errors for invalid inputs within 1 second

**Key Decisions**:
- Error message format and style (brief vs. detailed, actionable vs. technical)
- Exit code strategy (0 for success, different codes for different error types, or single non-zero code)
- How to map core error types to CLI messages (one-to-one, many-to-one, or contextual)
- Whether to include error codes or just descriptive messages
- How to format errors in JSON output (structured error objects)
- Whether to support verbose error output (`--verbose` flag)

**Validation Points**:
- Error messages are clear and actionable
- Exit codes are appropriate for success and failure
- Argument validation errors are reported clearly and quickly
- Error messages help users understand what went wrong and how to fix it
- Errors are formatted consistently across commands

**Risks & Open Questions**:
- How detailed should error messages be (brief vs. comprehensive)?
- Should error messages include suggested fixes or just describe the problem?
- How to handle nested or chained errors?
- Should CLI support different error verbosity levels?
- How to format errors in JSON output for scriptability?

---

### Component 11: Progress Indicators

**Purpose**: Implement progress feedback for long-running operations (detection, import) in human-readable mode.

**Responsibilities**:
- Display progress feedback during detection operations
- Display progress feedback during import operations
- Show operation stages and item counts (no percentage calculation for P1)
- Suppress progress indicators in JSON mode or when output is redirected
- Handle progress updates gracefully without overwhelming terminal output
- Support interruption handling (Ctrl+C) with cleanup

**Requirements Addressed**:
- FR-013: Provide progress feedback for long-running operations (detection, import) in human-readable mode using operation stages and item counts (no percentage calculation required for P1)
- User Story 3: Run detection via CLI (acceptance scenario 2)
- User Story 4: Import items via CLI (acceptance scenario 2)
- SC-008: CLI progress indicators provide meaningful feedback during long-running operations (detection, import)

**Key Decisions**:
- Progress indicator format (stage messages, item counts, no percentages for P1)
- How frequently to update progress (per item, per batch, per stage)
- How to detect when output is redirected (suppress progress)
- How to handle progress updates without overwhelming terminal
- Whether to support progress in JSON mode (suppress for P1)
- How to handle interruption during progress display

**Validation Points**:
- Progress indicators are shown during long-running operations
- Progress feedback is meaningful and helpful
- Progress indicators are suppressed in JSON mode
- Progress indicators are suppressed when output is redirected
- Interruption handling works correctly during progress display

**Risks & Open Questions**:
- How to update progress without causing terminal flicker or performance issues?
- Should progress indicators show estimated time remaining (out of scope for P1)?
- How to detect when output is redirected to a file?
- Should progress indicators be customizable (verbosity levels)?

---

### Component 12: CLI Integration with Core APIs

**Purpose**: Ensure CLI commands properly integrate with existing MediaHub core APIs without modifying core logic.

**Responsibilities**:
- Integrate CLI commands with existing Library core APIs
- Integrate CLI commands with existing Source core APIs
- Integrate CLI commands with existing Detection core APIs
- Integrate CLI commands with existing Import core APIs
- Ensure CLI does not modify core logic or behavior
- Maintain deterministic behavior when accessed via CLI
- Ensure CLI is a thin orchestration and presentation layer

**Requirements Addressed**:
- FR-022: Reuse existing MediaHub core APIs without modifying core logic or behavior
- FR-023: Maintain deterministic behavior when accessed via CLI (same inputs produce same outputs)
- SC-009: CLI commands maintain deterministic behavior (same inputs produce same outputs) consistent with programmatic API
- SC-010: All existing core tests still pass after CLI implementation (no regression in core functionality)

**Key Decisions**:
- How to structure CLI code to avoid duplicating core logic
- How to ensure CLI commands are thin wrappers around core APIs
- How to handle CLI-specific concerns (output formatting, progress) without affecting core
- Whether to create CLI-specific adapters or use core APIs directly
- How to ensure core behavior is not modified by CLI implementation

**Validation Points**:
- CLI commands use existing core APIs correctly
- Core behavior is not modified by CLI implementation
- CLI produces deterministic results consistent with programmatic API
- All existing core tests still pass
- CLI is a thin orchestration layer with no business logic

**Risks & Open Questions**:
- How to ensure CLI does not accidentally modify core logic?
- Should CLI code be in a separate module or within MediaHub target?
- How to test CLI integration with core APIs?
- Should CLI have its own test suite or rely on core tests?

---

## Implementation Sequence

The components should be implemented in the following order to manage dependencies:

1. **Component 1: CLI Executable Target & Package Structure** (Foundation)
   - Must be set up first as all other components depend on it
   - Establishes the basic CLI infrastructure and build system

2. **Component 2: Command Structure & Help System** (Foundation)
   - Depends on Component 1
   - Establishes command hierarchy and help system framework

3. **Component 3: Active Library Context Management** (Foundation)
   - Depends on Component 1
   - Enables library context resolution for all commands

4. **Component 10: Error Handling & Message Formatting** (Foundation)
   - Can be developed early as it's used by all commands
   - Establishes error handling patterns

5. **Component 9: Output Formatting & Serialization** (Foundation)
   - Can be developed early as it's used by all commands
   - Establishes output formatting patterns

6. **Component 4: Library Management Commands** (Core Functionality)
   - Depends on Components 1, 2, 3, 9, 10
   - Enables basic library operations via CLI

7. **Component 5: Source Management Commands** (Core Functionality)
   - Depends on Components 1, 2, 3, 4, 9, 10
   - Enables Source operations via CLI

8. **Component 11: Progress Indicators** (Core Functionality)
   - Can be developed in parallel with other components
   - Enables progress feedback for long-running operations

9. **Component 6: Detection Command** (Core Functionality)
   - Depends on Components 1, 2, 3, 5, 9, 10, 11, 12
   - Enables detection operations via CLI

10. **Component 7: Import Command** (Core Functionality)
    - Depends on Components 1, 2, 3, 5, 6, 9, 10, 11, 12
    - Enables import operations via CLI

11. **Component 8: Status Command** (Core Functionality)
    - Depends on Components 1, 2, 3, 4, 9, 10
    - Enables status viewing via CLI

12. **Component 12: CLI Integration with Core APIs** (Integration)
    - Ongoing throughout implementation
    - Ensures proper integration with core APIs

## Traceability Matrix

| Component | Functional Requirements | User Stories | Success Criteria |
|-----------|------------------------|--------------|------------------|
| Component 1: CLI Executable Target | FR-001, FR-017 | - | - |
| Component 2: Command Structure & Help | FR-010, FR-017 | Story 5 | SC-002, SC-013 |
| Component 3: Active Library Context | FR-003, FR-018 | Story 1, Story 2 | SC-011 |
| Component 4: Library Management | FR-002, FR-003, FR-004, FR-012 | Story 1 | SC-001 |
| Component 5: Source Management | FR-005, FR-006, FR-012, FR-019 | Story 2 | SC-001 |
| Component 6: Detection Command | FR-007, FR-011, FR-012, FR-013, FR-016, FR-024 | Story 3 | SC-001, SC-006, SC-007, SC-008 |
| Component 7: Import Command | FR-008, FR-011, FR-012, FR-013, FR-016, FR-025 | Story 4 | SC-001, SC-006, SC-007, SC-008 |
| Component 8: Status Command | FR-009, FR-011, FR-012 | Story 5 | SC-001 |
| Component 9: Output Formatting | FR-011, FR-012, FR-013 | - | SC-006, SC-007 |
| Component 10: Error Handling | FR-014, FR-015, FR-019, FR-021 | Story 1, Story 2, Story 3 | SC-003, SC-005, SC-012 |
| Component 11: Progress Indicators | FR-013 | Story 3, Story 4 | SC-008 |
| Component 12: Core API Integration | FR-022, FR-023 | - | SC-009, SC-010 |

## Risks & Mitigations

### High Risk Items

1. **CLI Integration with Core APIs**
   - **Risk**: CLI implementation may accidentally modify core logic or behavior, causing regressions
   - **Mitigation**: Ensure CLI is a thin orchestration layer; all core logic remains in core modules; comprehensive testing of core APIs after CLI implementation
   - **Validation**: All existing core tests still pass; CLI produces deterministic results consistent with programmatic API

2. **Output Formatting Complexity**
   - **Risk**: Complex result structures (detection results, import results) may be difficult to format clearly in human-readable format
   - **Mitigation**: Design clear formatting strategies early; use tables and structured text; test with various result sizes
   - **Validation**: Human-readable output is clear and well-formatted; JSON output is valid and parseable

3. **Progress Indicator Performance**
   - **Risk**: Progress indicators may cause performance issues or terminal flicker during long-running operations
   - **Mitigation**: Update progress at reasonable intervals (per stage, per batch); suppress when output is redirected; test with large operations
   - **Validation**: Progress indicators provide meaningful feedback without performance degradation

### Medium Risk Items

1. **Active Library Context Management**
   - **Risk**: Active library context resolution may be confusing or error-prone
   - **Mitigation**: Clear precedence rules (argument over environment variable); clear error messages when context is missing; validate library paths
   - **Validation**: Active library context is correctly resolved and used by all commands

2. **Error Message Clarity**
   - **Risk**: Error messages may not be clear or actionable enough for CLI users
   - **Mitigation**: Map core errors to user-friendly messages; include context and suggested fixes; test error scenarios
   - **Validation**: Error messages are clear and actionable (SC-003)

3. **JSON Output Schema Design**
   - **Risk**: JSON output schema may not be well-designed for scripting or may not match human-readable output
   - **Mitigation**: Design JSON schema early; ensure it's complete and parseable; test with standard JSON parsers
   - **Validation**: JSON output is valid JSON and can be parsed by standard JSON parsers (SC-007)

4. **Help System Completeness**
   - **Risk**: Help system may not cover all commands or may not be comprehensive enough
   - **Mitigation**: Use Swift Argument Parser for automatic help generation; add manual documentation where needed; test help coverage
   - **Validation**: Help system is accessible for all commands and subcommands (100% coverage, SC-013)

## Open Questions Requiring Resolution

1. **Argument Parsing Library**
   - Which library should be used for argument parsing (Swift Argument Parser recommended)?
   - Should argument parsing library be added as a dependency or implemented manually?
   - How to handle argument parsing library version compatibility?

2. **CLI Installation & Distribution**
   - How should CLI be installed (manual copy, Homebrew, or other method)?
   - Should CLI be distributed separately or as part of MediaHub package?
   - How to handle PATH setup for CLI executable?

3. **Active Library Context Strategy**
   - Should active library context support library identifiers in addition to paths?
   - How to handle relative vs. absolute library paths?
   - Should CLI support opening library and setting it as active in one command?

4. **Output Formatting Details**
   - How to format complex nested data structures in human-readable format?
   - Should human-readable format support colored output for better readability?
   - How to handle very large result sets without overwhelming output?

5. **Progress Indicator Design**
   - How frequently should progress be updated (per item, per batch, per stage)?
   - How to detect when output is redirected to a file?
   - Should progress indicators show estimated time remaining (out of scope for P1)?

6. **Error Message Strategy**
   - How detailed should error messages be (brief vs. comprehensive)?
   - Should error messages include suggested fixes or just describe the problem?
   - How to format errors in JSON output for scriptability?

7. **JSON Output Schema**
   - Should JSON output include metadata (timestamps, command arguments, etc.)?
   - How to structure JSON output for complex result types (detection results, import results)?
   - Should JSON output be compatible with specific JSON schema standards?

8. **Source Identification in CLI**
   - How should Sources be identified in CLI commands (identifier, path, or both)?
   - Should CLI support listing Sources by identifier or path?
   - How to handle Sources with duplicate paths or identifiers?

9. **Import Command Design**
   - How to handle import when no detection has been run (error vs. auto-detect)?
   - Should import automatically run detection if no detection result exists?
   - How to handle import when detection result is stale or missing?

10. **CLI Code Organization**
    - ~~Should CLI code be in a separate module or within MediaHub target?~~ **RESOLVED**: CLI code MUST be in a separate executable target with source code in `Sources/MediaHubCLI/` (NOT within MediaHub library target)
    - How to structure CLI code to avoid duplicating core logic?
    - Should CLI have its own test suite or rely on core tests?

## Validation & Testing Strategy

### Unit Testing Focus Areas

- CLI command argument parsing and validation
- Active library context resolution (argument, environment variable, precedence)
- Output formatting (human-readable and JSON)
- Error message formatting and mapping
- Progress indicator logic
- CLI command execution (without full integration)

### Integration Testing Focus Areas

- End-to-end CLI workflows (create library → attach source → detect → import)
- CLI integration with core APIs (Library, Source, Detection, Import)
- Active library context management across commands
- Output formatting for all command result types
- Error handling and exit codes
- Progress indicators during long-running operations
- JSON output validity and parseability

### Acceptance Testing Scenarios

All acceptance scenarios from the specification should be testable:
- User Story 1: All 5 acceptance scenarios (Create and open libraries)
- User Story 2: All 5 acceptance scenarios (Attach and list Sources)
- User Story 3: All 5 acceptance scenarios (Run detection)
- User Story 4: All 5 acceptance scenarios (Import items)
- User Story 5: All 5 acceptance scenarios (View status and get help)

### Edge Case Testing

- CLI commands without active library context
- CLI commands with invalid library paths
- CLI commands with invalid Source identifiers
- CLI commands with inaccessible Sources or Libraries
- CLI commands in non-interactive environment (scripting)
- CLI commands with invalid arguments or options
- CLI commands with conflicting options
- CLI commands with malformed JSON output requests
- CLI commands on moved or renamed libraries
- CLI commands with insufficient permissions
- CLI commands interrupted during long-running operations (Ctrl+C)
- CLI commands with very large result sets
- CLI commands with redirected output (progress suppression)

## Success Criteria Validation

Each success criterion must be validated:

- **SC-001** (Complete workflow via CLI): Test end-to-end workflow (create library → attach source → detect → import) via CLI
- **SC-002** (Help system discoverability): Test `--help` for all commands and verify comprehensive help text
- **SC-003** (Error message clarity): Test error scenarios and verify messages are clear and actionable
- **SC-004** (Non-interactive usage): Test CLI commands in scripts without user interaction
- **SC-005** (Appropriate exit codes): Test success and failure scenarios and verify exit codes
- **SC-006** (Human-readable output clarity): Test all commands and verify output is clear and well-formatted
- **SC-007** (JSON output validity): Test JSON output for all commands and verify it's valid and parseable
- **SC-008** (Progress indicator feedback): Test detection and import commands and verify progress feedback
- **SC-009** (Deterministic behavior): Test CLI commands multiple times with same inputs and verify identical outputs
- **SC-010** (No core regression): Run all existing core tests and verify they still pass
- **SC-011** (Active library context): Test active library context management and verify commands use correct context
- **SC-012** (Argument validation speed): Test argument validation and verify errors reported within 1 second
- **SC-013** (Help system coverage): Test help system for all commands and subcommands and verify 100% coverage

## Dependencies & Prerequisites

### External Dependencies

- Swift Argument Parser or equivalent argument parsing library
- Swift standard library (for JSON encoding/decoding, file I/O, etc.)
- Terminal output APIs (standard output, standard error)
- Environment variable access APIs

### Internal Dependencies

- **Slice 1 (Library Entity)**: Library structure, identity, validation, discovery, creation, opening
- **Slice 2 (Sources & Import Detection)**: Source model, validation, association, scanning, detection, detection results
- **Slice 3 (Import Execution & Media Organization)**: Import execution, import results, known-items tracking

### Future Dependencies Created

- Slice 5+ may depend on CLI for automation or scripting
- Pipeline system may depend on CLI for command execution
- Advanced features may extend CLI with additional commands

## P1 vs P2 Responsibilities

### P1 (Required for Slice 4)

- All Components 1-12 (CLI executable through core API integration)
- Basic CLI command structure and help system
- Library management commands (create, open, list)
- Source management commands (attach, list)
- Detection command with progress feedback
- Import command with `--all` flag (fine-grained selection deferred to P2)
- Status command
- Human-readable and JSON output formats
- Progress indicators (stage-based, no percentages)
- Error handling and message formatting
- Active library context (explicit per-invocation)
- Non-interactive usage (no prompts)

### P2 (Future Enhancements, Out of Scope)

- Persistent CLI state across invocations (active library context persistence)
- Interactive prompts or user input
- Fine-grained item selection for import (individual item paths)
- Advanced CLI features (completion, aliases, configuration files)
- Progress indicators with percentage calculations and time estimates
- Colored output for human-readable format
- CLI-specific caching or optimization
- Background execution or daemon mode
- Advanced help features (interactive help, examples, tutorials)

## Notes

- This plan intentionally avoids specifying implementation technologies (languages, frameworks, storage formats) except where unavoidable for clarity (e.g., Swift Argument Parser)
- All components should be designed with future extensibility in mind (e.g., additional commands, output formats, interactive features)
- The plan focuses on correctness, usability, and scriptability over advanced features (advanced features are deferred to P2)
- Each component should be independently testable where possible
- CLI must maintain deterministic behavior consistent with programmatic API
- CLI is a thin orchestration and presentation layer; no business logic should be embedded in CLI code
- CLI commands MUST be stateless and independent. Active library context is explicit per-invocation for P1 (via `--library` argument or `MEDIAHUB_LIBRARY` environment variable). No library state persists across CLI invocations.
- Error handling in CLI should map existing error types to user-friendly messages without changing core error behavior
- CLI output formats (human-readable and JSON) must be standard and scriptable
- Progress indicators are stage-based and item-count-based for P1; percentage calculations and time estimates are out of scope