# Validation: MediaHub CLI Tool & Packaging (Slice 4)

**Feature**: MediaHub CLI Tool & Packaging  
**Specification**: `specs/004-cli-tool-packaging/spec.md`  
**Plan**: `specs/004-cli-tool-packaging/plan.md`  
**Tasks**: `specs/004-cli-tool-packaging/tasks.md`  
**Created**: 2026-01-13

## CLI Smoke Test Checklist

This checklist provides a quick validation that the CLI tool is properly built, functional, and can execute a basic end-to-end workflow.

### Build and Test Validation

#### 1. Swift Build
- **Command**: `swift build`
- **Expected**: Build succeeds without errors
- **Validation**: CLI executable target builds successfully
- **Status**: ⬜ TODO

#### 2. Swift Test
- **Command**: `swift test`
- **Expected**: All tests pass (core tests + CLI tests)
- **Validation**: No regression in core functionality; CLI tests pass
- **Status**: ⬜ TODO

#### 3. CLI Help System
- **Command**: `swift run mediahub --help`
- **Expected**: Displays overview of all available commands
- **Validation**: Help system is accessible and comprehensive
- **Status**: ⬜ TODO

#### 4. Command Help System
- **Command**: `swift run mediahub library --help`
- **Expected**: Displays help for library command and subcommands
- **Validation**: Help system works for all commands and subcommands
- **Status**: ⬜ TODO

### End-to-End Workflow Validation

#### 5. Create Temporary Library
- **Command**: `swift run mediahub library create /tmp/test-library`
- **Expected**: Library is created successfully; success message displayed
- **Validation**: Library creation works via CLI
- **Status**: ⬜ TODO

#### 6. Open Library (Validate)
- **Command**: `swift run mediahub library open /tmp/test-library`
- **Expected**: Library information is displayed; library is validated
- **Validation**: Library open command works; displays library information
- **Status**: ⬜ TODO

#### 7. List Libraries
- **Command**: `swift run mediahub library list`
- **Expected**: Lists all discoverable libraries including test library
- **Validation**: Library list command works
- **Status**: ⬜ TODO

#### 8. Attach Temporary Source
- **Command**: `swift run mediahub source attach /tmp/test-source --library /tmp/test-library`
- **Expected**: Source is attached successfully; success message displayed
- **Validation**: Source attachment works via CLI; active library context works
- **Status**: ⬜ TODO

#### 9. List Sources
- **Command**: `swift run mediahub source list --library /tmp/test-library`
- **Expected**: Lists all attached sources including test source
- **Validation**: Source list command works; active library context works
- **Status**: ⬜ TODO

#### 10. Run Detection
- **Command**: `swift run mediahub detect <source-id> --library /tmp/test-library`
- **Expected**: Detection runs successfully; progress indicators shown; results displayed
- **Validation**: Detection command works; progress indicators work; results are displayed
- **Status**: ⬜ TODO

#### 11. Run Import
- **Command**: `swift run mediahub import <source-id> --all --library /tmp/test-library`
- **Expected**: Import runs successfully; progress indicators shown; results displayed
- **Validation**: Import command works; progress indicators work; results are displayed
- **Status**: ⬜ TODO

#### 12. Check Status
- **Command**: `swift run mediahub status --library /tmp/test-library`
- **Expected**: Displays active library information (path, identifier, source count, etc.)
- **Validation**: Status command works; displays accurate information
- **Status**: ⬜ TODO

### JSON Output Validation

#### 13. JSON Output - Library List
- **Command**: `swift run mediahub library list --json`
- **Expected**: Valid JSON output; parseable by standard JSON parsers
- **Validation**: JSON output is valid and parseable
- **Status**: ⬜ TODO

#### 14. JSON Output - Source List
- **Command**: `swift run mediahub source list --json --library /tmp/test-library`
- **Expected**: Valid JSON output; parseable by standard JSON parsers
- **Validation**: JSON output is valid and parseable
- **Status**: ⬜ TODO

#### 15. JSON Output - Detection
- **Command**: `swift run mediahub detect <source-id> --json --library /tmp/test-library`
- **Expected**: Valid JSON output; progress suppressed; parseable by standard JSON parsers
- **Validation**: JSON output is valid; progress is suppressed in JSON mode
- **Status**: ⬜ TODO

#### 16. JSON Output - Import
- **Command**: `swift run mediahub import <source-id> --all --json --library /tmp/test-library`
- **Expected**: Valid JSON output; progress suppressed; parseable by standard JSON parsers
- **Validation**: JSON output is valid; progress is suppressed in JSON mode
- **Status**: ⬜ TODO

### Error Handling Validation

#### 17. Error - No Active Library
- **Command**: `swift run mediahub source list`
- **Expected**: Clear error message indicating library context is required
- **Validation**: Error messages are clear and actionable
- **Status**: ⬜ TODO

#### 18. Error - Invalid Library Path
- **Command**: `swift run mediahub library open /nonexistent/path`
- **Expected**: Clear error message indicating library not found
- **Validation**: Error messages are clear and actionable
- **Status**: ⬜ TODO

#### 19. Error - Invalid Source Path
- **Command**: `swift run mediahub source attach /nonexistent/path --library /tmp/test-library`
- **Expected**: Clear error message indicating source path is invalid
- **Validation**: Error messages are clear and actionable
- **Status**: ⬜ TODO

#### 20. Exit Codes
- **Command**: `swift run mediahub library list && echo "Exit code: $?"`
- **Expected**: Exit code 0 for success
- **Validation**: Exit codes are appropriate (0 for success, non-zero for errors)
- **Status**: ⬜ TODO

### Environment Variable Validation

#### 21. Environment Variable - Active Library
- **Command**: `MEDIAHUB_LIBRARY=/tmp/test-library swift run mediahub source list`
- **Expected**: Command uses library from environment variable
- **Validation**: Environment variable support works; precedence rules are followed
- **Status**: ⬜ TODO

#### 22. Precedence - Argument Over Environment
- **Command**: `MEDIAHUB_LIBRARY=/tmp/library1 swift run mediahub source list --library /tmp/library2`
- **Expected**: Command uses library from argument (argument takes precedence)
- **Validation**: Precedence rules are followed correctly
- **Status**: ⬜ TODO

### Progress Indicator Validation

#### 23. Progress - Detection (Human-Readable)
- **Command**: `swift run mediahub detect <source-id> --library /tmp/test-library`
- **Expected**: Progress indicators shown (operation stages, item counts)
- **Validation**: Progress indicators work in human-readable mode
- **Status**: ⬜ TODO

#### 24. Progress - Import (Human-Readable)
- **Command**: `swift run mediahub import <source-id> --all --library /tmp/test-library`
- **Expected**: Progress indicators shown (operation stages, item counts)
- **Validation**: Progress indicators work in human-readable mode
- **Status**: ⬜ TODO

#### 25. Progress Suppression - JSON Mode
- **Command**: `swift run mediahub detect <source-id> --json --library /tmp/test-library`
- **Expected**: No progress indicators in output (only JSON)
- **Validation**: Progress is suppressed in JSON mode
- **Status**: ⬜ TODO

#### 26. Progress Suppression - Redirected Output
- **Command**: `swift run mediahub detect <source-id> --library /tmp/test-library > output.txt`
- **Expected**: No progress indicators in output file
- **Validation**: Progress is suppressed when output is redirected
- **Status**: ⬜ TODO

### Cleanup

#### 27. Cleanup Test Resources
- **Command**: `rm -rf /tmp/test-library /tmp/test-source`
- **Expected**: Test resources are cleaned up
- **Validation**: Temporary test resources are removed
- **Status**: ⬜ TODO

---

## Validation Checklist

### V.1: Create Validation Document
- ⬜ **Status**: TODO
- **Evidence**: This document exists and includes validation commands, acceptance scenarios, success criteria validation, edge case testing guidance, and CLI smoke test checklist.

### V.2: Implement Unit Tests
- ⬜ **Status**: TODO
- **Evidence**: Unit tests implemented for all CLI components:
  - Command argument parsing tests
  - Active library context resolution tests
  - Output formatting tests (human-readable and JSON)
  - Error message formatting tests
  - Progress indicator logic tests
  - CLI command execution tests

**Test Command**:
```bash
swift test --filter CLITests
```

### V.3: Implement Integration Tests
- ⬜ **Status**: TODO
- **Evidence**: Integration tests implemented:
  - End-to-end CLI workflow tests (create library → attach source → detect → import)
  - CLI integration with core APIs tests
  - Active library context management tests
  - Output formatting tests
  - Error handling tests
  - Progress indicator tests
  - JSON output validity tests

**Test Command**:
```bash
swift test --filter CLIIntegrationTests
```

### V.4: Implement Acceptance Test Scenarios
- ⬜ **Status**: TODO
- **Evidence**: Acceptance scenarios covered in integration tests:
  - User Story 1: Create and open libraries via CLI (all scenarios)
  - User Story 2: Attach and list Sources via CLI (all scenarios)
  - User Story 3: Run detection via CLI (all scenarios)
  - User Story 4: Import items via CLI (all scenarios)
  - User Story 5: View library status and get help via CLI (all scenarios)

**Test Command**:
```bash
swift test
```

### V.5: Implement Edge Case Tests
- ⬜ **Status**: TODO
- **Evidence**: Edge cases covered in unit and integration tests:
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

**Test Command**:
```bash
swift test
```

---

## Success Criteria Validation

### SC-001: Complete Workflow via CLI
- **Target**: Users can perform complete workflow (create library → attach source → detect → import) via CLI without writing Swift code
- **Status**: ⬜ TODO
- **Evidence**: End-to-end workflow test passes; all commands work correctly
- **Test Command**:
```bash
# Follow CLI smoke test checklist items 5-11
```

### SC-002: Help System Discoverability
- **Target**: All CLI commands are discoverable via `--help` and provide clear, comprehensive help text
- **Status**: ⬜ TODO
- **Evidence**: All commands respond to --help; help text is comprehensive
- **Test Command**:
```bash
swift run mediahub --help
swift run mediahub library --help
swift run mediahub library create --help
swift run mediahub source --help
swift run mediahub source attach --help
swift run mediahub detect --help
swift run mediahub import --help
swift run mediahub status --help
```

### SC-003: Error Message Clarity
- **Target**: CLI error messages are clear and actionable (users can understand what went wrong and how to fix it)
- **Status**: ⬜ TODO
- **Evidence**: Error messages are clear and actionable; tested in error handling validation
- **Test Command**:
```bash
# Follow CLI smoke test checklist items 17-19
```

### SC-004: Non-Interactive Usage
- **Target**: CLI commands can be used in scripts without requiring user interaction (non-interactive mode)
- **Status**: ⬜ TODO
- **Evidence**: All commands work in non-interactive mode; no prompts are shown
- **Test Command**:
```bash
#!/bin/bash
swift run mediahub library create /tmp/test-lib
swift run mediahub source attach /tmp/test-source --library /tmp/test-lib
# Script should complete without user interaction
```

### SC-005: Appropriate Exit Codes
- **Target**: CLI commands produce appropriate exit codes (0 for success, non-zero for errors) for scriptability
- **Status**: ⬜ TODO
- **Evidence**: Exit codes are appropriate; tested in exit code validation
- **Test Command**:
```bash
# Follow CLI smoke test checklist item 20
swift run mediahub library list && echo "Success: $?"
swift run mediahub library open /nonexistent && echo "Error: $?"
```

### SC-006: Human-Readable Output Clarity
- **Target**: CLI human-readable output is clear and well-formatted (tables, lists, structured text)
- **Status**: ⬜ TODO
- **Evidence**: Human-readable output is clear and well-formatted; tested in workflow validation
- **Test Command**:
```bash
swift run mediahub library list
swift run mediahub source list --library /tmp/test-library
swift run mediahub detect <source-id> --library /tmp/test-library
swift run mediahub import <source-id> --all --library /tmp/test-library
swift run mediahub status --library /tmp/test-library
```

### SC-007: JSON Output Validity
- **Target**: CLI JSON output is valid JSON and can be parsed by standard JSON parsers
- **Status**: ⬜ TODO
- **Evidence**: JSON output is valid and parseable; tested in JSON output validation
- **Test Command**:
```bash
# Follow CLI smoke test checklist items 13-16
swift run mediahub library list --json | python3 -m json.tool
swift run mediahub source list --json --library /tmp/test-library | python3 -m json.tool
swift run mediahub detect <source-id> --json --library /tmp/test-library | python3 -m json.tool
swift run mediahub import <source-id> --all --json --library /tmp/test-library | python3 -m json.tool
```

### SC-008: Progress Indicator Feedback
- **Target**: CLI progress indicators provide meaningful feedback during long-running operations (detection, import)
- **Status**: ⬜ TODO
- **Evidence**: Progress indicators work correctly; tested in progress indicator validation
- **Test Command**:
```bash
# Follow CLI smoke test checklist items 23-26
```

### SC-009: Deterministic Behavior
- **Target**: CLI commands maintain deterministic behavior (same inputs produce same outputs) consistent with programmatic API
- **Status**: ⬜ TODO
- **Evidence**: CLI commands produce identical results for identical inputs; behavior is consistent with programmatic API
- **Test Command**:
```bash
# Run same command multiple times and verify identical output
swift run mediahub detect <source-id> --library /tmp/test-library > output1.txt
swift run mediahub detect <source-id> --library /tmp/test-library > output2.txt
diff output1.txt output2.txt  # Should be identical
```

### SC-010: No Core Regression
- **Target**: All existing core tests still pass after CLI implementation (no regression in core functionality)
- **Status**: ⬜ TODO
- **Evidence**: All existing core tests pass; no regression detected
- **Test Command**:
```bash
swift test --filter MediaHubTests
```

### SC-011: Active Library Context
- **Target**: CLI active library state is managed correctly (commands use the correct library context)
- **Status**: ⬜ TODO
- **Evidence**: Active library context is managed correctly; tested in context validation
- **Test Command**:
```bash
# Follow CLI smoke test checklist items 8-9, 21-22
```

### SC-012: Argument Validation Speed
- **Target**: CLI commands validate arguments and report clear errors for invalid inputs within 1 second
- **Status**: ⬜ TODO
- **Evidence**: Argument validation is fast; errors are reported quickly
- **Test Command**:
```bash
time swift run mediahub library create invalid/path
time swift run mediahub source attach invalid/path --library /tmp/test-library
```

### SC-013: Help System Coverage
- **Target**: CLI help system is accessible for all commands and subcommands (100% coverage)
- **Status**: ⬜ TODO
- **Evidence**: Help system covers 100% of commands and subcommands; tested in help system validation
- **Test Command**:
```bash
# Follow CLI smoke test checklist items 3-4 and SC-002 test command
```

---

## Acceptance Scenarios Validation

### User Story 1: Create and Open Libraries via CLI

#### Scenario 1.1: Create New Library
- **Given**: User wants to create a new library
- **When**: They run `mediahub library create <path>`
- **Then**: MediaHub creates a new library at the specified path and reports success
- **Status**: ⬜ TODO
- **Test Command**:
```bash
swift run mediahub library create /tmp/test-library
```

#### Scenario 1.2: Open Existing Library
- **Given**: User wants to open an existing library
- **When**: They run `mediahub library open <path>`
- **Then**: MediaHub opens the library and displays library information (does not persist active library state)
- **Status**: ⬜ TODO
- **Test Command**:
```bash
swift run mediahub library open /tmp/test-library
```

#### Scenario 1.3: List Known Libraries
- **Given**: User wants to see all known libraries
- **When**: They run `mediahub library list`
- **Then**: MediaHub lists all discoverable libraries with their paths and identifiers
- **Status**: ⬜ TODO
- **Test Command**:
```bash
swift run mediahub library list
```

#### Scenario 1.4: Create Library Error Handling
- **Given**: User attempts to create a library at an invalid path
- **When**: The creation fails
- **Then**: MediaHub reports a clear, actionable error message explaining why creation failed
- **Status**: ⬜ TODO
- **Test Command**:
```bash
swift run mediahub library create /nonexistent/path/library
```

#### Scenario 1.5: Open Library Error Handling
- **Given**: User attempts to open a library that doesn't exist
- **When**: The opening fails
- **Then**: MediaHub reports a clear error message indicating the library was not found
- **Status**: ⬜ TODO
- **Test Command**:
```bash
swift run mediahub library open /nonexistent/library
```

### User Story 2: Attach and List Sources via CLI

#### Scenario 2.1: Attach Source
- **Given**: User has an active library (via --library argument or environment variable)
- **When**: They run `mediahub source attach <path>`
- **Then**: MediaHub validates the Source path, attaches it to the library, and reports success
- **Status**: ⬜ TODO
- **Test Command**:
```bash
swift run mediahub source attach /tmp/test-source --library /tmp/test-library
```

#### Scenario 2.2: List Sources
- **Given**: User wants to see attached Sources
- **When**: They run `mediahub source list`
- **Then**: MediaHub lists all Sources attached to the active library with their paths and identifiers
- **Status**: ⬜ TODO
- **Test Command**:
```bash
swift run mediahub source list --library /tmp/test-library
```

#### Scenario 2.3: Attach Source Error Handling
- **Given**: User attempts to attach an invalid Source path
- **When**: The attachment fails
- **Then**: MediaHub reports a clear error message explaining why attachment failed (path doesn't exist, permission denied, etc.)
- **Status**: ⬜ TODO
- **Test Command**:
```bash
swift run mediahub source attach /nonexistent/path --library /tmp/test-library
```

#### Scenario 2.4: No Active Library Error
- **Given**: User attempts to attach a Source when no library is active
- **When**: The command runs
- **Then**: MediaHub reports a clear error indicating that a library must be provided via --library argument or environment variable
- **Status**: ⬜ TODO
- **Test Command**:
```bash
swift run mediahub source attach /tmp/test-source
```

#### Scenario 2.5: Source Association Persistence
- **Given**: User attaches a Source
- **When**: They close and reopen the CLI session
- **Then**: The Source association persists and is visible in `mediahub source list`
- **Status**: ⬜ TODO
- **Test Command**:
```bash
swift run mediahub source attach /tmp/test-source --library /tmp/test-library
swift run mediahub source list --library /tmp/test-library
```

### User Story 3: Run Detection via CLI

#### Scenario 3.1: Run Detection
- **Given**: User has an attached Source
- **When**: They run `mediahub detect <source-id>`
- **Then**: MediaHub runs detection on the Source and displays a summary of candidate items found
- **Status**: ⬜ TODO
- **Test Command**:
```bash
swift run mediahub detect <source-id> --library /tmp/test-library
```

#### Scenario 3.2: Detection Progress Feedback
- **Given**: User runs detection
- **When**: Detection is in progress
- **Then**: MediaHub displays progress feedback (e.g., "Scanning source...", "Comparing with library...", "Found N candidates")
- **Status**: ⬜ TODO
- **Test Command**:
```bash
swift run mediahub detect <source-id> --library /tmp/test-library
```

#### Scenario 3.3: Detection Results Display
- **Given**: User runs detection
- **When**: Detection completes
- **Then**: MediaHub displays results showing the number of new candidate items, known items excluded, and any errors encountered
- **Status**: ⬜ TODO
- **Test Command**:
```bash
swift run mediahub detect <source-id> --library /tmp/test-library
```

#### Scenario 3.4: Detection JSON Output
- **Given**: User runs detection with `--json` flag
- **When**: Detection completes
- **Then**: MediaHub outputs results in JSON format suitable for scripting
- **Status**: ⬜ TODO
- **Test Command**:
```bash
swift run mediahub detect <source-id> --json --library /tmp/test-library
```

#### Scenario 3.5: Detection Error Handling
- **Given**: User runs detection on an inaccessible Source
- **When**: Detection fails
- **Then**: MediaHub reports a clear error message explaining why detection failed
- **Status**: ⬜ TODO
- **Test Command**:
```bash
swift run mediahub detect <invalid-source-id> --library /tmp/test-library
```

### User Story 4: Import Items via CLI

#### Scenario 4.1: Import All Items
- **Given**: User has run detection and has candidate items
- **When**: They run `mediahub import <source-id> --all`
- **Then**: MediaHub imports all detected candidate items for the specified Source and displays a summary of imported, skipped, and failed items
- **Status**: ⬜ TODO
- **Test Command**:
```bash
swift run mediahub import <source-id> --all --library /tmp/test-library
```

#### Scenario 4.2: Import Progress Feedback
- **Given**: User runs import
- **When**: Import is in progress
- **Then**: MediaHub displays progress feedback (e.g., "Importing item 1 of N...", "Copying file...")
- **Status**: ⬜ TODO
- **Test Command**:
```bash
swift run mediahub import <source-id> --all --library /tmp/test-library
```

#### Scenario 4.3: Import Results Display
- **Given**: User runs import
- **When**: Import completes
- **Then**: MediaHub displays results showing what was imported, what was skipped (with reasons), and what failed (with error messages)
- **Status**: ⬜ TODO
- **Test Command**:
```bash
swift run mediahub import <source-id> --all --library /tmp/test-library
```

#### Scenario 4.4: Import JSON Output
- **Given**: User runs import with `--json` flag
- **When**: Import completes
- **Then**: MediaHub outputs results in JSON format suitable for scripting
- **Status**: ⬜ TODO
- **Test Command**:
```bash
swift run mediahub import <source-id> --all --json --library /tmp/test-library
```

#### Scenario 4.5: Import Error Handling
- **Given**: User runs import without specifying `--all`
- **When**: The command runs
- **Then**: MediaHub reports a clear error indicating that item selection is required (--all flag)
- **Status**: ⬜ TODO
- **Test Command**:
```bash
swift run mediahub import <source-id> --library /tmp/test-library
```

### User Story 5: View Library Status and Get Help via CLI

#### Scenario 5.1: View Status
- **Given**: User wants to check their active library
- **When**: They run `mediahub status`
- **Then**: MediaHub displays the active library path, identifier, and basic information (number of sources, last detection time, etc.)
- **Status**: ⬜ TODO
- **Test Command**:
```bash
swift run mediahub status --library /tmp/test-library
```

#### Scenario 5.2: Get Command Help
- **Given**: User wants help with a command
- **When**: They run `mediahub <command> --help`
- **Then**: MediaHub displays comprehensive help text explaining the command, its options, and usage examples
- **Status**: ⬜ TODO
- **Test Command**:
```bash
swift run mediahub library create --help
```

#### Scenario 5.3: Get Root Help
- **Given**: User runs `mediahub --help`
- **When**: The command executes
- **Then**: MediaHub displays an overview of all available commands and their purposes
- **Status**: ⬜ TODO
- **Test Command**:
```bash
swift run mediahub --help
```

#### Scenario 5.4: Status Error Handling
- **Given**: User runs status when no library is active
- **When**: The command executes
- **Then**: MediaHub clearly indicates that no library is currently active
- **Status**: ⬜ TODO
- **Test Command**:
```bash
swift run mediahub status
```

#### Scenario 5.5: Get Subcommand Help
- **Given**: User wants help with a subcommand
- **When**: They run `mediahub library create --help`
- **Then**: MediaHub displays help specific to that subcommand
- **Status**: ⬜ TODO
- **Test Command**:
```bash
swift run mediahub library create --help
```

---

## Edge Case Testing

### Edge Case 1: CLI Commands Without Active Library
- **Scenario**: Run commands that require active library without providing --library argument or environment variable
- **Expected**: Clear error message indicating library context is required
- **Status**: ⬜ TODO
- **Test Command**:
```bash
swift run mediahub source list
swift run mediahub detect <source-id>
swift run mediahub import <source-id> --all
swift run mediahub status
```

### Edge Case 2: CLI Commands With Invalid Library Path
- **Scenario**: Run commands with invalid library path
- **Expected**: Clear error message indicating library path is invalid
- **Status**: ⬜ TODO
- **Test Command**:
```bash
swift run mediahub library open /nonexistent/library
swift run mediahub source list --library /nonexistent/library
```

### Edge Case 3: CLI Commands With Invalid Source Identifiers
- **Scenario**: Run detection or import with invalid source-id
- **Expected**: Clear error message indicating source-id is invalid
- **Status**: ⬜ TODO
- **Test Command**:
```bash
swift run mediahub detect invalid-source-id --library /tmp/test-library
swift run mediahub import invalid-source-id --all --library /tmp/test-library
```

### Edge Case 4: CLI Commands With Inaccessible Sources or Libraries
- **Scenario**: Run commands with inaccessible Sources or Libraries (permission denied, moved, etc.)
- **Expected**: Clear error message explaining accessibility issue
- **Status**: ⬜ TODO
- **Test Command**:
```bash
# Create library with restricted permissions
chmod 000 /tmp/test-library
swift run mediahub library open /tmp/test-library
```

### Edge Case 5: CLI Commands in Non-Interactive Environment
- **Scenario**: Run CLI commands in scripted/non-interactive environment
- **Expected**: Commands work without user interaction; no prompts are shown
- **Status**: ⬜ TODO
- **Test Command**:
```bash
#!/bin/bash
swift run mediahub library create /tmp/test-lib
swift run mediahub source attach /tmp/test-source --library /tmp/test-lib
```

### Edge Case 6: CLI Commands With Invalid Arguments or Options
- **Scenario**: Run commands with invalid arguments or options
- **Expected**: Clear error message indicating invalid argument/option
- **Status**: ⬜ TODO
- **Test Command**:
```bash
swift run mediahub library create
swift run mediahub import <source-id> --invalid-flag --library /tmp/test-library
```

### Edge Case 7: CLI Commands With Conflicting Options
- **Scenario**: Run commands with conflicting options
- **Expected**: Clear error message indicating conflicting options
- **Status**: ⬜ TODO
- **Test Command**:
```bash
# Test with conflicting options if applicable
```

### Edge Case 8: CLI Commands With Malformed JSON Output Requests
- **Scenario**: Request JSON output inappropriately (e.g., for help command)
- **Expected**: JSON output only for commands that support it; help remains human-readable
- **Status**: ⬜ TODO
- **Test Command**:
```bash
swift run mediahub --help --json  # Should ignore --json for help
```

### Edge Case 9: CLI Commands on Moved or Renamed Libraries
- **Scenario**: Run commands on library that has been moved or renamed
- **Expected**: Clear error message indicating library path is invalid
- **Status**: ⬜ TODO
- **Test Command**:
```bash
swift run mediahub library create /tmp/test-library
mv /tmp/test-library /tmp/test-library-moved
swift run mediahub library open /tmp/test-library
```

### Edge Case 10: CLI Commands With Insufficient Permissions
- **Scenario**: Run commands with insufficient permissions
- **Expected**: Clear error message indicating permission issue
- **Status**: ⬜ TODO
- **Test Command**:
```bash
swift run mediahub library create /root/test-library  # May require permissions
```

### Edge Case 11: CLI Commands Interrupted During Long-Running Operations
- **Scenario**: Interrupt detection or import operation (Ctrl+C)
- **Expected**: Operation is interrupted gracefully; cleanup is performed; Library remains consistent
- **Status**: ⬜ TODO
- **Test Command**:
```bash
# Start long-running operation and interrupt with Ctrl+C
swift run mediahub detect <source-id> --library /tmp/test-library
# Press Ctrl+C during execution
```

### Edge Case 12: CLI Commands With Very Large Result Sets
- **Scenario**: Run commands that produce very large result sets
- **Expected**: Commands handle large results correctly; output is manageable
- **Status**: ⬜ TODO
- **Test Command**:
```bash
# Create library with many sources and items
swift run mediahub library list  # With many libraries
swift run mediahub source list --library /tmp/test-library  # With many sources
```

### Edge Case 13: CLI Commands With Redirected Output (Progress Suppression)
- **Scenario**: Run commands with output redirected to file
- **Expected**: Progress indicators are suppressed when output is redirected
- **Status**: ⬜ TODO
- **Test Command**:
```bash
swift run mediahub detect <source-id> --library /tmp/test-library > output.txt
swift run mediahub import <source-id> --all --library /tmp/test-library > output.txt
```

---

## Build and Run Examples

### Build CLI Executable
```bash
swift build
```

### Run CLI Help
```bash
swift run mediahub --help
```

### Complete End-to-End Workflow Example
```bash
# Create temporary directories
mkdir -p /tmp/test-library /tmp/test-source

# Create library
swift run mediahub library create /tmp/test-library

# Attach source
swift run mediahub source attach /tmp/test-source --library /tmp/test-library

# List sources to get source-id
swift run mediahub source list --library /tmp/test-library

# Run detection (replace <source-id> with actual ID)
swift run mediahub detect <source-id> --library /tmp/test-library

# Run import
swift run mediahub import <source-id> --all --library /tmp/test-library

# Check status
swift run mediahub status --library /tmp/test-library

# Cleanup
rm -rf /tmp/test-library /tmp/test-source
```

### JSON Output Example
```bash
# Get JSON output for library list
swift run mediahub library list --json

# Get JSON output for detection
swift run mediahub detect <source-id> --json --library /tmp/test-library

# Get JSON output for import
swift run mediahub import <source-id> --all --json --library /tmp/test-library
```

### Environment Variable Example
```bash
# Set active library via environment variable
export MEDIAHUB_LIBRARY=/tmp/test-library

# Commands now use library from environment variable
swift run mediahub source list
swift run mediahub status

# Argument takes precedence over environment variable
swift run mediahub source list --library /tmp/other-library
```

---

## Notes

- All validation items should be checked off (✅) as they are completed
- CLI smoke test checklist provides quick validation of basic functionality
- Success criteria validation ensures all requirements are met
- Acceptance scenarios validation ensures all user stories are satisfied
- Edge case testing ensures robustness and error handling
- Build and run examples provide practical usage guidance
