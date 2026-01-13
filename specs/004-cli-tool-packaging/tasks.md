# Implementation Tasks: MediaHub CLI Tool & Packaging (Slice 4)

**Feature**: MediaHub CLI Tool & Packaging  
**Specification**: `specs/004-cli-tool-packaging/spec.md`  
**Plan**: `specs/004-cli-tool-packaging/plan.md`  
**Slice**: 4 - CLI Tool & Packaging  
**Created**: 2026-01-13

## Task Organization

Tasks are organized by component and follow the implementation sequence defined in the plan. Each task is:
- Small and focused on a single deliverable
- Sequential (dependencies are clear)
- Traceable to plan components (referenced by component number)
- Includes only P1 scope: stateless CLI tool with explicit library context, library/source/detect/import/status commands, human-readable and JSON output, progress indicators, error handling, and help system

## NON-NEGOTIABLE CONSTRAINTS FOR SLICE 4

**CRITICAL**: The following constraints MUST be followed during Slice 4 implementation:

1. **CLI Target Structure**:
   - CLI MUST be a separate executable target (NOT part of MediaHub library target)
   - CLI source code MUST be in `Sources/MediaHubCLI/` (NOT `Sources/MediaHub/` or `Sources/mediahub/`)
   - CLI entry point `main.swift` MUST be at `Sources/MediaHubCLI/main.swift`
   - `main.swift` MUST NEVER exist under `Sources/MediaHub/`

2. **File Protection**:
   - NO files in `Sources/MediaHub/` may be deleted, moved, or renamed during Slice 4
   - If duplicates are found, STOP and report; do NOT delete or "clean up" files
   - NO "deduplication" or "cleanup" operations on existing files

3. **Stateless CLI**:
   - CLI is stateless: no library state persists across invocations
   - Each command requiring library context MUST receive it explicitly via `--library` argument or `MEDIAHUB_LIBRARY` environment variable
   - Remove any wording implying "active library persists across commands"

4. **Case-Sensitivity**:
   - Use `Sources/MediaHubCLI/` (NOT `Sources/mediahub/`) to avoid case-insensitive filesystem collisions with `Sources/MediaHub/` on macOS

---

## Component 1: CLI Executable Target & Package Structure

**Plan Reference**: Component 1 (lines 45-79)  
**Dependencies**: None (Foundation)

### Task 1.1: Add Swift Argument Parser Dependency
**Priority**: P1
- **Objective**: Add Swift Argument Parser as a package dependency to Package.swift
- **Deliverable**: Updated Package.swift with Swift Argument Parser dependency
- **Traceability**: Plan Component 1, Key Decision: "Which argument parsing library to use (Swift Argument Parser recommended)" and FR-017
- **Acceptance**: Package.swift includes Swift Argument Parser dependency; dependency resolves correctly; supports FR-001 and FR-017

### Task 1.2: Add CLI Executable Target to Package.swift
**Priority**: P1
- **Objective**: Add executable target named `mediahub` to Package.swift with dependency on MediaHub library. The CLI target MUST be a separate executable target (NOT part of the MediaHub library target).
- **Deliverable**: Updated Package.swift with executable target
- **Traceability**: Plan Component 1, Responsibility: "Add executable target to Package.swift" and Key Decision: "CLI executable name (e.g., `mediahub`)" and FR-001
- **Acceptance**: Package.swift includes `mediahub` executable target as a separate target (NOT part of MediaHub library target); target depends on MediaHub library; supports FR-001
- **CRITICAL CONSTRAINT**: The executable target MUST have its source code in `Sources/MediaHubCLI/` (NOT `Sources/MediaHub/` or `Sources/mediahub/`)

### Task 1.3: Create CLI Entry Point Structure
**Priority**: P1
- **Objective**: Create main.swift file as CLI entry point with basic command structure setup. The entry point MUST be located at `Sources/MediaHubCLI/main.swift` and MUST NEVER exist under `Sources/MediaHub/`.
- **Deliverable**: CLI entry point file at `Sources/MediaHubCLI/main.swift`
- **Traceability**: Plan Component 1, Responsibility: "Create main CLI entry point" and "Establish CLI command structure and hierarchy"
- **Acceptance**: Entry point file exists at `Sources/MediaHubCLI/main.swift`; basic structure is established; can be built successfully; NO main.swift exists under `Sources/MediaHub/`
- **CRITICAL CONSTRAINT**: main.swift MUST be at `Sources/MediaHubCLI/main.swift` and MUST NEVER be created under `Sources/MediaHub/` (library target must not contain executable entry point)

### Task 1.4: Implement Basic Root Command
**Priority**: P1
- **Objective**: Create root command structure using Swift Argument Parser with top-level command hierarchy
- **Deliverable**: Root command implementation
- **Traceability**: Plan Component 1, Responsibility: "Establish CLI command structure and hierarchy" and Component 2, Responsibility: "Define top-level command structure"
- **Acceptance**: Root command structure includes library, source, detect, import, status commands; supports FR-010 (help system)

### Task 1.5: Validate CLI Build and Execution
**Priority**: P1
- **Objective**: Verify CLI executable can be built and executed from command line. Validate that structure is correct: `Sources/MediaHubCLI/main.swift` exists, `Sources/MediaHub/` has NO main.swift, and Package.swift has separate executable target.
- **Deliverable**: Validated CLI build and execution
- **Traceability**: Plan Component 1, Validation Point: "CLI executable can be built successfully" and "CLI executable can be run from command line"
- **Acceptance**: `swift build` succeeds; `swift run mediahub` executes; CLI responds to basic commands; structure validation passes (Sources/MediaHubCLI/main.swift exists, Sources/MediaHub/ has NO main.swift, executable target is separate from library target)
- **CRITICAL VALIDATION**: Before building, verify: (1) `Sources/MediaHubCLI/main.swift` exists, (2) `Sources/MediaHub/` has NO main.swift, (3) Package.swift has separate executable target

---

## Component 2: Command Structure & Help System

**Plan Reference**: Component 2 (lines 82-119)  
**Dependencies**: Component 1 (CLI executable target must be set up)

### Task 2.1: Implement Library Command Structure
**Priority**: P1
- **Objective**: Create `mediahub library` command with create, open, and list subcommands
- **Deliverable**: Library command structure implementation
- **Traceability**: Plan Component 2, Responsibility: "Define top-level command structure (`mediahub library`, `mediahub source`, `mediahub detect`, `mediahub import`, `mediahub status`)" and FR-010
- **Acceptance**: `mediahub library` command exists with create, open, list subcommands; help system works for all subcommands

### Task 2.2: Implement Source Command Structure
**Priority**: P1
- **Objective**: Create `mediahub source` command with attach and list subcommands
- **Deliverable**: Source command structure implementation
- **Traceability**: Plan Component 2, Responsibility: "Define top-level command structure" and FR-010
- **Acceptance**: `mediahub source` command exists with attach, list subcommands; help system works for all subcommands

### Task 2.3: Implement Detect Command Structure
**Priority**: P1
- **Objective**: Create `mediahub detect` command with source-id argument
- **Deliverable**: Detect command structure implementation
- **Traceability**: Plan Component 2, Responsibility: "Define top-level command structure" and FR-010
- **Acceptance**: `mediahub detect` command exists; accepts source-id argument; help system works

### Task 2.4: Implement Import Command Structure
**Priority**: P1
- **Objective**: Create `mediahub import` command with source-id argument and --all flag
- **Deliverable**: Import command structure implementation
- **Traceability**: Plan Component 2, Responsibility: "Define top-level command structure" and FR-010
- **Acceptance**: `mediahub import` command exists; accepts source-id and --all flag; help system works

### Task 2.5: Implement Status Command Structure
**Priority**: P1
- **Objective**: Create `mediahub status` command
- **Deliverable**: Status command structure implementation
- **Traceability**: Plan Component 2, Responsibility: "Define top-level command structure" and FR-010
- **Acceptance**: `mediahub status` command exists; help system works

### Task 2.6: Implement Comprehensive Help System
**Priority**: P1
- **Objective**: Ensure all commands and subcommands support --help flag with comprehensive help text
- **Deliverable**: Help system implementation for all commands
- **Traceability**: Plan Component 2, Responsibility: "Implement help system for all commands and subcommands" and "Generate help text automatically from command definitions" and FR-010, User Story 5 (all acceptance scenarios), SC-002, SC-013
- **Acceptance**: All commands respond to --help; help text includes descriptions, arguments, options, and examples; 100% coverage (SC-013)

### Task 2.7: Validate Help System Coverage
**Priority**: P1
- **Objective**: Verify help system covers all commands and subcommands (100% coverage)
- **Deliverable**: Validated help system coverage
- **Traceability**: Plan Component 2, Validation Point: "Help system covers 100% of commands and subcommands" and SC-013
- **Acceptance**: All commands and subcommands have help text; help is accessible via --help flag; coverage is 100%

---

## Component 3: Active Library Context Management

**Plan Reference**: Component 3 (lines 122-161)  
**Dependencies**: Component 1 (CLI executable target must be set up)

### Task 3.1: Design Active Library Context Resolution Strategy
**Priority**: P1
- **Objective**: Document strategy for resolving active library context from command-line argument or environment variable. The CLI is stateless: no library state persists across invocations. Each command requiring library context MUST receive it explicitly.
- **Deliverable**: Active library context resolution strategy documentation
- **Traceability**: Plan Component 3, Key Decision: "How to specify active library (command-line argument vs. environment variable vs. both)" and "Precedence when both argument and environment variable are provided" and FR-018
- **Acceptance**: Strategy defines argument name (--library), environment variable name (MEDIAHUB_LIBRARY), precedence rules (argument overrides environment variable), and explicitly states CLI is stateless (no persistent state across invocations)

### Task 3.2: Implement Library Context Argument Parsing
**Priority**: P1
- **Objective**: Add --library argument support to commands that require active library context
- **Deliverable**: Library context argument parsing implementation
- **Traceability**: Plan Component 3, Responsibility: "Accept library path via command-line argument (e.g., `--library <path>`)" and FR-018
- **Acceptance**: Commands accept --library argument; argument is parsed correctly

### Task 3.3: Implement Library Context Environment Variable Support
**Priority**: P1
- **Objective**: Add support for reading active library path from MEDIAHUB_LIBRARY environment variable
- **Deliverable**: Environment variable support implementation
- **Traceability**: Plan Component 3, Responsibility: "Accept library path via environment variable (e.g., `MEDIAHUB_LIBRARY`)" and FR-018
- **Acceptance**: Commands read MEDIAHUB_LIBRARY environment variable; variable is used when argument is not provided

### Task 3.4: Implement Context Resolution with Precedence
**Priority**: P1
- **Objective**: Implement context resolution logic with precedence (argument overrides environment variable)
- **Deliverable**: Context resolution implementation with precedence
- **Traceability**: Plan Component 3, Key Decision: "Precedence when both argument and environment variable are provided" and FR-018
- **Acceptance**: Argument takes precedence over environment variable; resolution works correctly in all cases

### Task 3.5: Implement Library Path Validation
**Priority**: P1
- **Objective**: Create function to validate active library path before use
- **Deliverable**: Library path validation function/module
- **Traceability**: Plan Component 3, Responsibility: "Validate active library path before use" and Key Decision: "How to handle library path validation and error reporting"
- **Acceptance**: Function validates library paths; handles relative and absolute paths; validates library exists and is accessible

### Task 3.6: Implement Context Error Messages
**Priority**: P1
- **Objective**: Create clear error messages when no active library is set or library path is invalid
- **Deliverable**: Context error message implementation
- **Traceability**: Plan Component 3, Responsibility: "Provide clear error messages when no active library is set" and FR-014, FR-015, User Story 1 (acceptance scenario 5), User Story 2 (acceptance scenario 4)
- **Acceptance**: Error messages are clear and actionable; messages explain what went wrong and how to fix it; supports SC-003

### Task 3.7: Integrate Context Management with Commands
**Priority**: P1
- **Objective**: Ensure all commands that require active library context use the context resolution mechanism
- **Deliverable**: Context integration with commands
- **Traceability**: Plan Component 3, Responsibility: "Ensure active library context is used correctly by all commands" and SC-011
- **Acceptance**: All commands requiring library context use resolution mechanism; context is used correctly; supports SC-011

### Task 3.8: Validate Active Library Context Management
**Priority**: P1
- **Objective**: Create tests to verify active library context resolution works correctly
- **Deliverable**: Context management test suite
- **Traceability**: Plan Component 3, Validation Point: "Active library context is correctly resolved from arguments or environment variable" and "Precedence rules are followed correctly" and SC-011
- **Acceptance**: Context resolution works correctly; precedence rules are followed; commands use correct context

---

## Component 4: Library Management Commands

**Plan Reference**: Component 4 (lines 164-204)  
**Dependencies**: Components 1, 2, 3, 9, 10 (CLI structure, help system, context management, output formatting, error handling must be implemented)

### Task 4.1: Implement Library Create Command
**Priority**: P1
- **Objective**: Implement `mediahub library create <path>` command that creates a new library
- **Deliverable**: Library create command implementation
- **Traceability**: Plan Component 4, Responsibility: "Implement `mediahub library create <path>` command" and FR-002, User Story 1 (acceptance scenarios 1, 4)
- **Acceptance**: Command creates library successfully; reports success; handles errors clearly; integrates with existing Library core APIs

### Task 4.2: Implement Library Open Command
**Priority**: P1
- **Objective**: Implement `mediahub library open <path>` command that validates and displays library information (does not persist active library state)
- **Deliverable**: Library open command implementation
- **Traceability**: Plan Component 4, Responsibility: "Implement `mediahub library open <path>` command" and FR-003, User Story 1 (acceptance scenarios 2, 5)
- **Acceptance**: Command validates library; displays library information; does not persist active library state; handles errors clearly

### Task 4.3: Implement Library List Command
**Priority**: P1
- **Objective**: Implement `mediahub library list` command that lists all discoverable libraries
- **Deliverable**: Library list command implementation
- **Traceability**: Plan Component 4, Responsibility: "Implement `mediahub library list` command" and FR-004, User Story 1 (acceptance scenario 3)
- **Acceptance**: Command lists all discoverable libraries; displays library paths and identifiers; supports human-readable and JSON output

### Task 4.4: Implement Library Command Error Handling
**Priority**: P1
- **Objective**: Implement clear error messages for library command failures (path exists, permission denied, library not found, etc.)
- **Deliverable**: Library command error handling implementation
- **Traceability**: Plan Component 4, Responsibility: "Validate library paths and report clear errors" and FR-014, FR-015, User Story 1 (acceptance scenarios 4, 5)
- **Acceptance**: Error messages are clear and actionable; errors are mapped from core error types; supports SC-003

### Task 4.5: Implement Library List JSON Output
**Priority**: P1
- **Objective**: Add JSON output support to library list command via --json flag
- **Deliverable**: Library list JSON output implementation
- **Traceability**: Plan Component 4, Responsibility: "Support JSON output format for list command" and FR-012
- **Acceptance**: --json flag produces valid JSON output; JSON is parseable; supports SC-007

### Task 4.6: Validate Library Management Commands
**Priority**: P1
- **Objective**: Create tests to verify library management commands work correctly
- **Deliverable**: Library management command test suite
- **Traceability**: Plan Component 4, Validation Points: "Library creation works correctly and reports success", "Library open validates and displays library information", "Library list displays all discoverable libraries" and SC-001
- **Acceptance**: All library commands work correctly; error handling works; JSON output is valid; commands integrate with core APIs

---

## Component 5: Source Management Commands

**Plan Reference**: Component 5 (lines 207-247)  
**Dependencies**: Components 1, 2, 3, 4, 9, 10 (CLI structure, help system, context management, library commands, output formatting, error handling must be implemented)

### Task 5.1: Implement Source Attach Command
**Priority**: P1
- **Objective**: Implement `mediahub source attach <path>` command that attaches a Source to the active library
- **Deliverable**: Source attach command implementation
- **Traceability**: Plan Component 5, Responsibility: "Implement `mediahub source attach <path>` command" and FR-005, User Story 2 (acceptance scenarios 1, 3, 4)
- **Acceptance**: Command attaches Source successfully; validates Source path; reports success; requires active library context; integrates with existing Source core APIs

### Task 5.2: Implement Source List Command
**Priority**: P1
- **Objective**: Implement `mediahub source list` command that lists all Sources attached to the active library
- **Deliverable**: Source list command implementation
- **Traceability**: Plan Component 5, Responsibility: "Implement `mediahub source list` command" and FR-006, User Story 2 (acceptance scenario 2)
- **Acceptance**: Command lists all attached Sources; displays Source paths and identifiers; requires active library context; supports human-readable and JSON output

### Task 5.3: Implement Source Command Error Handling
**Priority**: P1
- **Objective**: Implement clear error messages for source command failures (path doesn't exist, permission denied, no active library, etc.)
- **Deliverable**: Source command error handling implementation
- **Traceability**: Plan Component 5, Responsibility: "Validate Source paths and report clear errors" and FR-014, FR-015, FR-019, User Story 2 (acceptance scenarios 3, 4)
- **Acceptance**: Error messages are clear and actionable; errors are mapped from core error types; supports SC-003

### Task 5.4: Implement Source List JSON Output
**Priority**: P1
- **Objective**: Add JSON output support to source list command via --json flag
- **Deliverable**: Source list JSON output implementation
- **Traceability**: Plan Component 5, Responsibility: "Support JSON output format for list command" and FR-012
- **Acceptance**: --json flag produces valid JSON output; JSON is parseable; supports SC-007

### Task 5.5: Validate Source Management Commands
**Priority**: P1
- **Objective**: Create tests to verify source management commands work correctly
- **Deliverable**: Source management command test suite
- **Traceability**: Plan Component 5, Validation Points: "Source attachment works correctly and reports success", "Source list displays all attached Sources for active library" and SC-001
- **Acceptance**: All source commands work correctly; error handling works; JSON output is valid; commands integrate with core APIs

---

## Component 6: Detection Command

**Plan Reference**: Component 6 (lines 250-298)  
**Dependencies**: Components 1, 2, 3, 5, 9, 10, 11, 12 (CLI structure, help system, context management, source commands, output formatting, error handling, progress indicators, core API integration must be implemented)

### Task 6.1: Implement Detect Command Execution
**Priority**: P1
- **Objective**: Implement `mediahub detect <source-id>` command that runs detection on a Source
- **Deliverable**: Detect command implementation
- **Traceability**: Plan Component 6, Responsibility: "Implement `mediahub detect <source-id>` command" and FR-007, User Story 3 (acceptance scenarios 1, 5)
- **Acceptance**: Command runs detection successfully; accepts source-id argument; requires active library context; integrates with existing Detection core APIs

### Task 6.2: Implement Detection Progress Indicators
**Priority**: P1
- **Objective**: Display progress feedback during detection (operation stages, item counts) in human-readable mode
- **Deliverable**: Detection progress indicator implementation
- **Traceability**: Plan Component 6, Responsibility: "Display progress feedback during detection (operation stages, item counts)" and FR-013, User Story 3 (acceptance scenario 2)
- **Acceptance**: Progress shows operation stages and item counts; progress is suppressed in JSON mode and when output is redirected; supports SC-008

### Task 6.3: Implement Detection Result Human-Readable Formatting
**Priority**: P1
- **Objective**: Format detection results in clear, tabular, or structured format for human-readable output
- **Deliverable**: Detection result human-readable formatter
- **Traceability**: Plan Component 6, Responsibility: "Format detection results in human-readable format (tables, lists, structured text)" and FR-011, FR-024, User Story 3 (acceptance scenario 3)
- **Acceptance**: Results are formatted clearly; output uses tables, lists, or structured text; shows candidate items, known items excluded, and errors; supports SC-006

### Task 6.4: Implement Detection Result JSON Output
**Priority**: P1
- **Objective**: Add JSON output support to detect command via --json flag
- **Deliverable**: Detection result JSON serialization implementation
- **Traceability**: Plan Component 6, Responsibility: "Support JSON output format via `--json` flag" and FR-012, User Story 3 (acceptance scenario 4)
- **Acceptance**: --json flag produces valid JSON output; JSON serializes DetectionResult correctly; JSON is parseable; supports SC-007

### Task 6.5: Implement Detection Error Handling
**Priority**: P1
- **Objective**: Implement clear error messages for detection failures (inaccessible Source, invalid source-id, etc.)
- **Deliverable**: Detection error handling implementation
- **Traceability**: Plan Component 6, Responsibility: "Handle detection errors and report clear error messages" and FR-014, FR-015, User Story 3 (acceptance scenario 5)
- **Acceptance**: Error messages are clear and actionable; errors are mapped from core error types; supports SC-003

### Task 6.6: Implement Detection Interruption Handling
**Priority**: P1
- **Objective**: Handle detection interruptions gracefully (Ctrl+C) with cleanup
- **Deliverable**: Detection interruption handling implementation
- **Traceability**: Plan Component 6, Key Decision: "How to handle detection interruptions (Ctrl+C)" and FR-013
- **Acceptance**: Interruptions are handled gracefully; detection can be safely interrupted; cleanup is performed

### Task 6.7: Validate Detection Command
**Priority**: P1
- **Objective**: Create tests to verify detection command works correctly
- **Deliverable**: Detection command test suite
- **Traceability**: Plan Component 6, Validation Points: "Detection command runs successfully and displays results", "Progress feedback is shown during detection", "Human-readable output is clear and well-formatted", "JSON output is valid and parseable" and SC-001, SC-006, SC-007, SC-008
- **Acceptance**: Detection command works correctly; progress indicators work; output formatting works; JSON output is valid; error handling works

---

## Component 7: Import Command

**Plan Reference**: Component 7 (lines 301-353)  
**Dependencies**: Components 1, 2, 3, 5, 6, 9, 10, 11, 12 (CLI structure, help system, context management, source commands, detection command, output formatting, error handling, progress indicators, core API integration must be implemented)

### Task 7.1: Implement Import Command Execution
**Priority**: P1
- **Objective**: Implement `mediahub import <source-id> --all` command that imports all detected candidate items
- **Deliverable**: Import command implementation
- **Traceability**: Plan Component 7, Responsibility: "Implement `mediahub import <source-id> --all` command" and FR-008, User Story 4 (acceptance scenarios 1, 5)
- **Acceptance**: Command imports all detected items successfully; accepts source-id and --all flag; requires active library context; integrates with existing Import core APIs

### Task 7.2: Implement Import Progress Indicators
**Priority**: P1
- **Objective**: Display progress feedback during import (operation stages, item counts) in human-readable mode
- **Deliverable**: Import progress indicator implementation
- **Traceability**: Plan Component 7, Responsibility: "Display progress feedback during import (operation stages, item counts)" and FR-013, User Story 4 (acceptance scenario 2)
- **Acceptance**: Progress shows operation stages and item counts; progress is suppressed in JSON mode and when output is redirected; supports SC-008

### Task 7.3: Implement Import Result Human-Readable Formatting
**Priority**: P1
- **Objective**: Format import results with clear status indicators (imported, skipped, failed) and reasons in human-readable format
- **Deliverable**: Import result human-readable formatter
- **Traceability**: Plan Component 7, Responsibility: "Format import results in human-readable format (tables, lists, structured text)" and FR-011, FR-025, User Story 4 (acceptance scenario 3)
- **Acceptance**: Results show imported, skipped, and failed items with reasons; output uses tables, lists, or structured text; supports SC-006

### Task 7.4: Implement Import Result JSON Output
**Priority**: P1
- **Objective**: Add JSON output support to import command via --json flag
- **Deliverable**: Import result JSON serialization implementation
- **Traceability**: Plan Component 7, Responsibility: "Support JSON output format via `--json` flag" and FR-012, User Story 4 (acceptance scenario 4)
- **Acceptance**: --json flag produces valid JSON output; JSON serializes ImportResult correctly; JSON is parseable; supports SC-007

### Task 7.5: Implement Import Error Handling
**Priority**: P1
- **Objective**: Implement clear error messages for import failures (no detection result, inaccessible Source, import errors, etc.)
- **Deliverable**: Import error handling implementation
- **Traceability**: Plan Component 7, Responsibility: "Handle import errors and report clear error messages" and FR-014, FR-015, User Story 4 (acceptance scenario 5)
- **Acceptance**: Error messages are clear and actionable; errors are mapped from core error types; supports SC-003

### Task 7.6: Implement Import Interruption Handling
**Priority**: P1
- **Objective**: Handle import interruptions gracefully (Ctrl+C) with cleanup
- **Deliverable**: Import interruption handling implementation
- **Traceability**: Plan Component 7, Key Decision: "How to handle import interruptions (Ctrl+C)" and FR-013
- **Acceptance**: Interruptions are handled gracefully; import can be safely interrupted; cleanup is performed; Library remains consistent

### Task 7.7: Implement Import Validation (--all Required)
**Priority**: P1
- **Objective**: Validate that --all flag is provided and report clear error if item selection is missing
- **Deliverable**: Import validation implementation
- **Traceability**: Plan Component 7, Responsibility: "For P1, support importing all detected items only (fine-grained selection deferred to P2)" and User Story 4 (acceptance scenario 5)
- **Acceptance**: Command requires --all flag; clear error message if flag is missing; supports FR-008 (P1 scope)

### Task 7.8: Validate Import Command
**Priority**: P1
- **Objective**: Create tests to verify import command works correctly
- **Deliverable**: Import command test suite
- **Traceability**: Plan Component 7, Validation Points: "Import command runs successfully and displays results", "Progress feedback is shown during import", "Human-readable output is clear and well-formatted", "JSON output is valid and parseable" and SC-001, SC-006, SC-007, SC-008
- **Acceptance**: Import command works correctly; progress indicators work; output formatting works; JSON output is valid; error handling works; --all flag validation works

---

## Component 8: Status Command

**Plan Reference**: Component 8 (lines 356-394)  
**Dependencies**: Components 1, 2, 3, 4, 9, 10 (CLI structure, help system, context management, library commands, output formatting, error handling must be implemented)

### Task 8.1: Implement Status Command Execution
**Priority**: P1
- **Objective**: Implement `mediahub status` command that displays active library information
- **Deliverable**: Status command implementation
- **Traceability**: Plan Component 8, Responsibility: "Implement `mediahub status` command" and FR-009, User Story 5 (acceptance scenarios 1, 4)
- **Acceptance**: Command displays active library path, identifier, and basic information; requires active library context; integrates with existing Library core APIs

### Task 8.2: Implement Status Information Display
**Priority**: P1
- **Objective**: Display library state information (number of sources, last detection time, etc.) in status output
- **Deliverable**: Status information display implementation
- **Traceability**: Plan Component 8, Responsibility: "Display active library information (path, identifier, basic metadata)" and "Show library state (number of sources, last detection time, etc.)" and User Story 5 (acceptance scenario 1)
- **Acceptance**: Status shows library path, identifier, source count, and other relevant information; output is clear and well-formatted

### Task 8.3: Implement Status Error Handling
**Priority**: P1
- **Objective**: Handle case when no library is active with clear error message
- **Deliverable**: Status error handling implementation
- **Traceability**: Plan Component 8, Responsibility: "Handle case when no library is active (clear error message)" and User Story 5 (acceptance scenario 4)
- **Acceptance**: Clear error message when no library is active; error is actionable; supports SC-003

### Task 8.4: Implement Status JSON Output
**Priority**: P1
- **Objective**: Add JSON output support to status command via --json flag
- **Deliverable**: Status JSON output implementation
- **Traceability**: Plan Component 8, Responsibility: "Support JSON output format via `--json` flag" and FR-012
- **Acceptance**: --json flag produces valid JSON output; JSON is parseable; supports SC-007

### Task 8.5: Validate Status Command
**Priority**: P1
- **Objective**: Create tests to verify status command works correctly
- **Deliverable**: Status command test suite
- **Traceability**: Plan Component 8, Validation Points: "Status command displays active library information correctly", "Clear error message when no library is active" and SC-001
- **Acceptance**: Status command works correctly; displays accurate information; error handling works; JSON output is valid

---

## Component 9: Output Formatting & Serialization

**Plan Reference**: Component 9 (lines 397-438)  
**Dependencies**: Component 1 (CLI structure must be set up)

### Task 9.1: Design Output Formatting Strategy
**Priority**: P1
- **Objective**: Document strategy for human-readable and JSON output formatting
- **Deliverable**: Output formatting strategy documentation
- **Traceability**: Plan Component 9, Key Decision: "Human-readable format style (tables, lists, structured text)" and "JSON output schema for each command result type" and FR-011, FR-012
- **Acceptance**: Strategy defines human-readable format style and JSON schema for all command result types

### Task 9.2: Implement Human-Readable Formatter Base
**Priority**: P1
- **Objective**: Create base formatter infrastructure for human-readable output (tables, lists, structured text)
- **Deliverable**: Human-readable formatter base implementation
- **Traceability**: Plan Component 9, Responsibility: "Implement human-readable output formatters for all command results" and FR-011
- **Acceptance**: Base formatter supports tables, lists, and structured text; can be extended for specific command results

### Task 9.3: Implement JSON Serialization Base
**Priority**: P1
- **Objective**: Create base JSON serialization infrastructure for command results
- **Deliverable**: JSON serialization base implementation
- **Traceability**: Plan Component 9, Responsibility: "Implement JSON serialization for structured result data" and FR-012
- **Acceptance**: Base serialization supports encoding command results to JSON; produces valid JSON

### Task 9.4: Implement Output Format Selection
**Priority**: P1
- **Objective**: Implement logic to select output format based on --json flag (human-readable by default, JSON when flag is present)
- **Deliverable**: Output format selection implementation
- **Traceability**: Plan Component 9, Responsibility: "Support `--json` flag for commands that produce structured results" and FR-011, FR-012
- **Acceptance**: Format selection works correctly; human-readable is default; JSON is used when --json flag is present

### Task 9.5: Implement Error Message Formatting
**Priority**: P1
- **Objective**: Format error messages consistently across output formats
- **Deliverable**: Error message formatting implementation
- **Traceability**: Plan Component 9, Responsibility: "Format error messages consistently across output formats" and FR-014
- **Acceptance**: Error messages are formatted consistently; work in both human-readable and JSON formats

### Task 9.6: Validate Output Formatting
**Priority**: P1
- **Objective**: Create tests to verify output formatting works correctly for all commands
- **Deliverable**: Output formatting test suite
- **Traceability**: Plan Component 9, Validation Points: "Human-readable output is clear and well-formatted", "JSON output is valid JSON and parseable", "Both output formats contain equivalent information" and SC-006, SC-007
- **Acceptance**: All commands produce correct output formats; human-readable is clear; JSON is valid and parseable; formats contain equivalent information

---

## Component 10: Error Handling & Message Formatting

**Plan Reference**: Component 10 (lines 441-486)  
**Dependencies**: Component 1 (CLI structure must be set up)

### Task 10.1: Design Error Message Mapping Strategy
**Priority**: P1
- **Objective**: Document strategy for mapping existing MediaHub error types to user-friendly CLI error messages
- **Deliverable**: Error message mapping strategy documentation
- **Traceability**: Plan Component 10, Key Decision: "How to map core error types to CLI messages (one-to-one, many-to-one, or contextual)" and FR-014, FR-015
- **Acceptance**: Strategy defines mapping from core error types to CLI messages; messages are clear and actionable

### Task 10.2: Implement Error Type Mapping
**Priority**: P1
- **Objective**: Create function to map existing MediaHub error types to user-friendly CLI error messages
- **Deliverable**: Error type mapping implementation
- **Traceability**: Plan Component 10, Responsibility: "Map existing MediaHub error types to user-friendly CLI error messages" and FR-015
- **Acceptance**: All core error types are mapped to clear CLI messages; messages are actionable

### Task 10.3: Implement Error Message Formatting
**Priority**: P1
- **Objective**: Format error messages for terminal output with clear, actionable format
- **Deliverable**: Error message formatting implementation
- **Traceability**: Plan Component 10, Responsibility: "Format error messages for terminal output" and FR-014
- **Acceptance**: Error messages are formatted clearly; include context about what failed and how to resolve; supports SC-003

### Task 10.4: Implement Exit Code Strategy
**Priority**: P1
- **Objective**: Implement exit code logic (0 for success, non-zero for errors)
- **Deliverable**: Exit code implementation
- **Traceability**: Plan Component 10, Responsibility: "Provide appropriate exit codes (0 for success, non-zero for errors) for scriptability" and FR-021, SC-005
- **Acceptance**: Exit codes are appropriate (0 for success, non-zero for errors); supports scriptability

### Task 10.5: Implement Argument Validation Error Handling
**Priority**: P1
- **Objective**: Implement clear error messages for invalid CLI command arguments
- **Deliverable**: Argument validation error handling implementation
- **Traceability**: Plan Component 10, Responsibility: "Handle validation errors and report clear messages" and FR-019, SC-012
- **Acceptance**: Invalid arguments are detected and reported clearly; errors are reported within 1 second (SC-012)

### Task 10.6: Implement JSON Error Output
**Priority**: P1
- **Objective**: Format errors in JSON output format for scriptability
- **Deliverable**: JSON error output implementation
- **Traceability**: Plan Component 10, Key Decision: "How to format errors in JSON output (structured error objects)" and FR-012
- **Acceptance**: Errors are formatted as structured JSON objects; JSON is parseable; supports scriptability

### Task 10.7: Validate Error Handling
**Priority**: P1
- **Objective**: Create tests to verify error handling works correctly
- **Deliverable**: Error handling test suite
- **Traceability**: Plan Component 10, Validation Points: "Error messages are clear and actionable", "Exit codes are appropriate for success and failure", "Argument validation errors are reported clearly and quickly" and SC-003, SC-005, SC-012
- **Acceptance**: Error messages are clear and actionable; exit codes are appropriate; argument validation is fast and clear

---

## Component 11: Progress Indicators

**Plan Reference**: Component 11 (lines 489-527)  
**Dependencies**: Component 9 (output formatting must be implemented)

### Task 11.1: Design Progress Indicator Strategy
**Priority**: P1
- **Objective**: Document strategy for progress indicators (stage messages, item counts, no percentages for P1)
- **Deliverable**: Progress indicator strategy documentation
- **Traceability**: Plan Component 11, Key Decision: "Progress indicator format (stage messages, item counts, no percentages for P1)" and FR-013
- **Acceptance**: Strategy defines progress format (stages and item counts); no percentage calculations for P1

### Task 11.2: Implement Progress Indicator Base
**Priority**: P1
- **Objective**: Create base progress indicator infrastructure for displaying operation stages and item counts
- **Deliverable**: Progress indicator base implementation
- **Traceability**: Plan Component 11, Responsibility: "Display progress feedback during detection operations" and "Display progress feedback during import operations" and FR-013
- **Acceptance**: Base infrastructure supports stage messages and item counts; can be used by detection and import commands

### Task 11.3: Implement Progress Suppression Logic
**Priority**: P1
- **Objective**: Suppress progress indicators in JSON mode and when output is redirected
- **Deliverable**: Progress suppression implementation
- **Traceability**: Plan Component 11, Responsibility: "Suppress progress indicators in JSON mode or when output is redirected" and Key Decision: "How to detect when output is redirected (suppress progress)"
- **Acceptance**: Progress is suppressed in JSON mode; progress is suppressed when output is redirected; detection works correctly

### Task 11.4: Implement Progress Update Handling
**Priority**: P1
- **Objective**: Handle progress updates gracefully without overwhelming terminal output
- **Deliverable**: Progress update handling implementation
- **Traceability**: Plan Component 11, Responsibility: "Handle progress updates gracefully without overwhelming terminal output" and Key Decision: "How frequently to update progress (per item, per batch, per stage)"
- **Acceptance**: Progress updates are displayed at reasonable intervals; terminal output is not overwhelmed; updates are clear

### Task 11.5: Implement Interruption Handling for Progress
**Priority**: P1
- **Objective**: Handle interruption (Ctrl+C) gracefully during progress display with cleanup
- **Deliverable**: Progress interruption handling implementation
- **Traceability**: Plan Component 11, Responsibility: "Support interruption handling (Ctrl+C) with cleanup" and Key Decision: "How to handle interruption during progress display"
- **Acceptance**: Interruptions are handled gracefully; cleanup is performed; progress display doesn't interfere with interruption

### Task 11.6: Validate Progress Indicators
**Priority**: P1
- **Objective**: Create tests to verify progress indicators work correctly
- **Deliverable**: Progress indicator test suite
- **Traceability**: Plan Component 11, Validation Points: "Progress indicators are shown during long-running operations", "Progress indicators are suppressed in JSON mode", "Progress indicators are suppressed when output is redirected" and SC-008
- **Acceptance**: Progress indicators work correctly; suppression works; interruption handling works

---

## Component 12: CLI Integration with Core APIs

**Plan Reference**: Component 12 (lines 530-568)  
**Dependencies**: All other components (ongoing integration throughout implementation)

### Task 12.1: Design CLI-Core API Integration Strategy
**Priority**: P1
- **Objective**: Document strategy for integrating CLI commands with existing MediaHub core APIs without modifying core logic
- **Deliverable**: CLI-core API integration strategy documentation
- **Traceability**: Plan Component 12, Key Decision: "How to structure CLI code to avoid duplicating core logic" and "How to ensure CLI commands are thin wrappers around core APIs" and FR-022, FR-023
- **Acceptance**: Strategy ensures CLI is a thin orchestration layer; core logic is not modified; CLI reuses existing APIs

### Task 12.2: Integrate Library Commands with Core APIs
**Priority**: P1
- **Objective**: Ensure library management commands use existing Library core APIs correctly
- **Deliverable**: Library command core API integration
- **Traceability**: Plan Component 12, Responsibility: "Integrate CLI commands with existing Library core APIs" and FR-022
- **Acceptance**: Library commands use core APIs correctly; no core logic is modified; integration is correct

### Task 12.3: Integrate Source Commands with Core APIs
**Priority**: P1
- **Objective**: Ensure source management commands use existing Source core APIs correctly
- **Deliverable**: Source command core API integration
- **Traceability**: Plan Component 12, Responsibility: "Integrate CLI commands with existing Source core APIs" and FR-022
- **Acceptance**: Source commands use core APIs correctly; no core logic is modified; integration is correct

### Task 12.4: Integrate Detection Command with Core APIs
**Priority**: P1
- **Objective**: Ensure detection command uses existing Detection core APIs correctly
- **Deliverable**: Detection command core API integration
- **Traceability**: Plan Component 12, Responsibility: "Integrate CLI commands with existing Detection core APIs" and FR-022
- **Acceptance**: Detection command uses core APIs correctly; no core logic is modified; integration is correct

### Task 12.5: Integrate Import Command with Core APIs
**Priority**: P1
- **Objective**: Ensure import command uses existing Import core APIs correctly
- **Deliverable**: Import command core API integration
- **Traceability**: Plan Component 12, Responsibility: "Integrate CLI commands with existing Import core APIs" and FR-022
- **Acceptance**: Import command uses core APIs correctly; no core logic is modified; integration is correct

### Task 12.6: Validate Deterministic Behavior
**Priority**: P1
- **Objective**: Verify CLI commands produce deterministic results consistent with programmatic API
- **Deliverable**: Deterministic behavior validation
- **Traceability**: Plan Component 12, Responsibility: "Maintain deterministic behavior when accessed via CLI" and FR-023, SC-009
- **Acceptance**: CLI commands produce identical results for identical inputs; behavior is consistent with programmatic API; supports SC-009

### Task 12.7: Validate No Core Regression
**Priority**: P1
- **Objective**: Run all existing core tests to verify no regression in core functionality
- **Deliverable**: Core regression validation
- **Traceability**: Plan Component 12, Responsibility: "Ensure CLI does not modify core logic or behavior" and SC-010
- **Acceptance**: All existing core tests still pass; no regression in core functionality; supports SC-010

### Task 12.8: Validate CLI as Thin Layer
**Priority**: P1
- **Objective**: Verify CLI is a thin orchestration and presentation layer with no business logic
- **Deliverable**: CLI layer validation
- **Traceability**: Plan Component 12, Responsibility: "Ensure CLI is a thin orchestration and presentation layer" and Key Decision: "How to ensure CLI does not accidentally modify core logic"
- **Acceptance**: CLI code is verified to be thin orchestration layer; no business logic is embedded in CLI; all logic comes from core APIs

---

## Validation Deliverable

### Task V.1: Create Validation Document
**Priority**: P1
- **Objective**: Create validation checklist document for Slice 4 including CLI smoke test checklist
- **Deliverable**: `specs/004-cli-tool-packaging/validation.md`
- **Traceability**: Plan Validation & Testing Strategy (lines 733-796) and user request for "CLI smoke test" checklist
- **Acceptance**: Document includes validation commands, acceptance scenarios, success criteria validation, edge case testing guidance, and CLI smoke test checklist (swift build, swift test, swift run mediahub --help, end-to-end workflow using temp library + temp source)

### Task V.2: Implement Unit Tests
**Priority**: P1
- **Objective**: Create unit tests covering key acceptance scenarios for all CLI components
- **Deliverable**: Unit test suite under `Tests/MediaHubTests/`
- **Traceability**: Plan Unit Testing Focus Areas (lines 735-743) and all User Story acceptance scenarios
- **Acceptance**: Tests cover command argument parsing, active library context resolution, output formatting, error message formatting, progress indicator logic, and CLI command execution; all tests pass

### Task V.3: Implement Integration Tests
**Priority**: P1
- **Objective**: Create integration tests covering end-to-end CLI workflows and key scenarios
- **Deliverable**: Integration test suite under `Tests/MediaHubTests/`
- **Traceability**: Plan Integration Testing Focus Areas (lines 744-753)
- **Acceptance**: Tests cover end-to-end CLI workflows (create library → attach source → detect → import), CLI integration with core APIs, active library context management, output formatting, error handling, progress indicators, and JSON output validity; all tests pass

### Task V.4: Implement Acceptance Test Scenarios
**Priority**: P1
- **Objective**: Create tests covering all acceptance scenarios from User Stories 1-5
- **Deliverable**: Acceptance test suite under `Tests/MediaHubTests/`
- **Traceability**: Plan Acceptance Testing Scenarios (lines 754-762) and all User Story acceptance scenarios
- **Acceptance**: All acceptance scenarios from User Stories 1-5 are testable and pass

### Task V.5: Implement Edge Case Tests
**Priority**: P1
- **Objective**: Create tests covering edge cases from specification
- **Deliverable**: Edge case test suite under `Tests/MediaHubTests/`
- **Traceability**: Plan Edge Case Testing (lines 763-778) and specification Edge Cases (lines 102-116)
- **Acceptance**: Edge cases are tested; tests handle scenarios gracefully; all edge case tests pass

---

## P2 Tasks (Out of Scope for Slice 4)

The following tasks are explicitly out of scope for Slice 4 but are documented for future reference:

### Persistent CLI State (P2)

**Note**: Persistent active library state across invocations is P2 and explicitly out of scope for Slice 4.

#### Task P2.1: Implement Persistent Active Library State (P2)
- **Objective**: Create mechanism to persist active library state across CLI invocations
- **Deliverable**: Persistent state mechanism implementation
- **Traceability**: Plan P2 Responsibilities (lines 835-846)
- **Acceptance**: Active library state persists across invocations; state is stored in config file or similar

### Interactive Features (P2)

**Note**: Interactive prompts and user input are P2 and explicitly out of scope for Slice 4.

#### Task P2.2: Implement Interactive Prompts (P2)
- **Objective**: Add support for interactive prompts and user input in CLI commands
- **Deliverable**: Interactive prompt implementation
- **Traceability**: Plan P2 Responsibilities (lines 835-846)
- **Acceptance**: CLI supports interactive prompts; user input is handled correctly

### Fine-Grained Import Selection (P2)

**Note**: Fine-grained item selection for import (beyond --all) is P2 and explicitly out of scope for Slice 4.

#### Task P2.3: Implement Fine-Grained Import Selection (P2)
- **Objective**: Add support for selecting individual items or item paths for import
- **Deliverable**: Fine-grained import selection implementation
- **Traceability**: Plan P2 Responsibilities (lines 835-846)
- **Acceptance**: Import command supports selecting individual items; selection is flexible

### Advanced CLI Features (P2)

**Note**: Advanced CLI features (completion, aliases, configuration files) are P2 and explicitly out of scope for Slice 4.

#### Task P2.4: Implement Shell Completion (P2)
- **Objective**: Add shell completion support for CLI commands
- **Deliverable**: Shell completion implementation
- **Traceability**: Plan P2 Responsibilities (lines 835-846)
- **Acceptance**: Shell completion works for all commands; supports common shells

#### Task P2.5: Implement CLI Configuration Files (P2)
- **Objective**: Add support for CLI configuration files
- **Deliverable**: Configuration file implementation
- **Traceability**: Plan P2 Responsibilities (lines 835-846)
- **Acceptance**: CLI supports configuration files; configuration is applied correctly

### Advanced Progress Indicators (P2)

**Note**: Progress indicators with percentage calculations and time estimates are P2 and explicitly out of scope for Slice 4.

#### Task P2.6: Implement Percentage-Based Progress Indicators (P2)
- **Objective**: Add percentage calculations and time estimates to progress indicators
- **Deliverable**: Advanced progress indicator implementation
- **Traceability**: Plan P2 Responsibilities (lines 835-846)
- **Acceptance**: Progress indicators show percentages and time estimates; calculations are accurate

### Colored Output (P2)

**Note**: Colored output for human-readable format is P2 and explicitly out of scope for Slice 4.

#### Task P2.7: Implement Colored Output (P2)
- **Objective**: Add colored output support for human-readable format
- **Deliverable**: Colored output implementation
- **Traceability**: Plan P2 Responsibilities (lines 835-846)
- **Acceptance**: Colored output works correctly; colors improve readability

---

## Task Summary

**Total Tasks**: 79 tasks across 12 components (P1) + 5 validation tasks + 7 P2 tasks (documented but out of scope)

**Implementation Sequence** (as per plan):
1. Component 1: CLI Executable Target & Package Structure (5 tasks)
2. Component 2: Command Structure & Help System (7 tasks)
3. Component 3: Active Library Context Management (8 tasks)
4. Component 10: Error Handling & Message Formatting (7 tasks) - can be developed early
5. Component 9: Output Formatting & Serialization (6 tasks) - can be developed early
6. Component 4: Library Management Commands (6 tasks)
7. Component 5: Source Management Commands (5 tasks)
8. Component 11: Progress Indicators (6 tasks) - can be developed in parallel
9. Component 6: Detection Command (7 tasks)
10. Component 7: Import Command (8 tasks)
11. Component 8: Status Command (5 tasks)
12. Component 12: CLI Integration with Core APIs (8 tasks) - ongoing throughout
13. Validation Deliverable (5 tasks)

**P1 Task Count**: 74 implementation tasks + 5 validation tasks = 79 total P1 tasks

**Exclusions** (as requested):
- No persistent CLI state across invocations (active library context is explicit per-invocation for P1)
- No interactive prompts or user input (non-interactive mode only for P1)
- No fine-grained item selection for import (deferred to P2; P1 supports --all only)
- No advanced CLI features (completion, aliases, configuration files)
- No GUI or visual interfaces
- No background execution or daemon mode
- No CLI-specific caching or optimization beyond core functionality
- No percentage calculations or time estimates in progress indicators (P1 uses stage messages and item counts only)
- No colored output for human-readable format (P1)
- P2 tasks are documented but out of scope

**Traceability**: Each task references specific plan components, requirements (FR-XXX), success criteria (SC-XXX), user stories, and acceptance scenarios where applicable.
