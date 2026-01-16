# Slice 9b — Duplicate Reporting & Audit

**Document Type**: Slice Implementation Tasks
**Slice Number**: 9b
**Title**: Duplicate Reporting & Audit
**Author**: Spec-Kit Orchestrator
**Date**: 2026-01-15
**Status**: Draft

---

## Task Overview

This document breaks down the implementation of Slice 9b into 8 main tasks, designed as SAFE implementation passes. All tasks maintain strict read-only behavior, deterministic ordering guarantees, and zero state mutations.

**Key Constraints Applied**:
- Exact duplicates by content hash only (no "potential duplicates")
- Read-only operations end-to-end (zero writes, zero mutations)
- Deterministic ordering: groups by hash, files within groups by relative path lexicographic ascending
- No refactors outside identified touchpoints
- Memory usage proportional to duplicate set size

---

## Task 1: CLI Command Scaffolding

**Purpose**: Establish the new `mediahub duplicates` command with proper CLI integration, help text, and flag parsing.

**Expected Files/Touchpoints**:
- `Sources/MediaHubCLI/DuplicatesCommand.swift` (new)
- `Sources/MediaHubCLI/main.swift` (add command registration)

**Subtasks**:
- Implement `DuplicatesCommand` struct conforming to CLI command patterns
- Add flag parsing for `--format` (text/json/csv) and `--output` (optional file path)
- Integrate with existing library selection mechanism
- Add command registration in main.swift
- Implement basic help text and usage examples

**Done When**:
- `mediahub duplicates --help` displays proper usage information
- `mediahub duplicates` (without args) succeeds with default behavior
- Command appears in general help output alongside other commands
- Invalid flags are rejected with clear error messages

**References**: spec.md sections "CLI Integration", "Safety & Operational Requirements"

---

## Task 2: Core Duplicate Grouping Logic

**Purpose**: Implement the core logic to load BaselineIndex and build hash-based duplicate groupings.

**Expected Files/Touchpoints**:
- `Sources/MediaHub/DuplicateReporting.swift` (new)

**Subtasks**:
- Create `DuplicateReporting` component with BaselineIndex loading
- Implement single pass over BaselineIndex entries to build hash → files mapping
- Filter out entries with nil hash values (skip without warning)
- Group files by SHA-256 hash, filtering for groups with fileCount > 1
- Return immutable duplicate groups without applying sorting yet

**Done When**:
- `DuplicateReporting` can load a BaselineIndex and identify all duplicate groups
- Memory usage scales with duplicate set size (not total library size)
- Nil hash entries are silently skipped
- Groups contain correct file metadata (paths, sizes, timestamps)
- No sorting applied at this stage (raw grouping only)

**References**: spec.md sections "Duplicate Detection & Grouping", "Performance Considerations"

---

## Task 3: Deterministic Ordering Implementation

**Purpose**: Implement and test deterministic ordering guarantees for duplicate groups and files within groups.

**Expected Files/Touchpoints**:
- `Sources/MediaHub/DuplicateReporting.swift` (extend)
- `Tests/MediaHubTests/DuplicateReportingTests.swift` (new)

**Subtasks**:
- Implement group sorting: lexicographic ascending by SHA-256 hash
- Implement file sorting within groups: relative path lexicographic ascending
- Ensure timestamps are display-only metadata (no ordering influence)
- Add dedicated unit tests verifying ordering stability across multiple runs

**Done When**:
- Same BaselineIndex input produces identical group/file ordering every time
- Groups are sorted by hash lexicographically (a000... before b000...)
- Files within groups are sorted by relative path (2023/01/file.jpg before 2023/02/file.jpg)
- Unit tests verify ordering determinism with multiple identical inputs
- Timestamps appear in output but do not affect sort order

**References**: spec.md sections "Deterministic Behavior", "Edge Cases & Failure Modes"

---

## Task 4: Text Output Formatting

**Purpose**: Implement human-readable text format for duplicate reports.

**Expected Files/Touchpoints**:
- `Sources/MediaHub/DuplicateFormatter.swift` (new protocol + implementations)
- `Tests/MediaHubTests/DuplicateFormatterTests.swift` (new)

**Subtasks**:
- Create `DuplicateFormatter` protocol for consistent output interface
- Implement `TextDuplicateFormatter` with grouped display
- Include library name, generation timestamp, and summary statistics
- Format individual duplicate groups with hash, file count, and total size
- Display file details with indented paths, sizes, and timestamps

**Done When**:
- Text output matches the format specified in spec.md examples
- `mediahub duplicates --format text` produces readable console output
- Summary statistics (groups, files, sizes, savings) are accurate
- File listing within groups follows deterministic ordering
- Unit tests verify text formatting accuracy against known inputs

**References**: spec.md section "Output Formats" (Text Format)

---

## Task 5: JSON Output Formatting

**Purpose**: Implement structured JSON format for programmatic duplicate report consumption.

**Expected Files/Touchpoints**:
- `Sources/MediaHub/DuplicateFormatter.swift` (extend)
- `Tests/MediaHubTests/DuplicateFormatterTests.swift` (extend)

**Subtasks**:
- Implement `JsonDuplicateFormatter` extending the protocol
- Generate JSON structure with library metadata, summary, and duplicate groups
- Include all required fields: paths, sizes, timestamps, hash values
- Ensure deterministic ordering is preserved in JSON output
- Handle edge cases (empty results, large duplicate sets)

**Done When**:
- `mediahub duplicates --format json` produces valid JSON matching spec examples
- JSON structure includes library name, generation timestamp, and summary statistics
- Duplicate groups and files maintain deterministic ordering in JSON arrays
- Unit tests validate JSON schema compliance and content accuracy
- JSON output can be parsed and processed by external tools

**References**: spec.md section "Output Formats" (JSON Format)

---

## Task 6: CSV Output Formatting

**Purpose**: Implement tabular CSV format for spreadsheet analysis of duplicate reports.

**Expected Files/Touchpoints**:
- `Sources/MediaHub/DuplicateFormatter.swift` (extend)
- `Tests/MediaHubTests/DuplicateFormatterTests.swift` (extend)

**Subtasks**:
- Implement `CsvDuplicateFormatter` extending the protocol
- Generate CSV with header row and denormalized duplicate data
- One row per file with group metadata repeated
- Preserve deterministic ordering in row sequence
- Handle CSV escaping for paths containing special characters

**Done When**:
- `mediahub duplicates --format csv` produces CSV matching spec examples
- Header row includes all required columns (group_hash, file_count, etc.)
- Rows maintain deterministic ordering (groups then files within groups)
- CSV can be imported into spreadsheet applications without formatting issues
- Unit tests verify CSV structure and content accuracy

**References**: spec.md section "Output Formats" (CSV Format)

---

## Task 7: Edge Cases and Error Handling

**Purpose**: Implement robust handling of edge cases and failure modes with appropriate error messages.

**Expected Files/Touchpoints**:
- `Sources/MediaHub/DuplicateReporting.swift` (extend)
- `Sources/MediaHubCLI/DuplicatesCommand.swift` (extend)
- `Tests/MediaHubTests/DuplicateReportingTests.swift` (extend)

**Subtasks**:
- Handle missing/invalid BaselineIndex with clear error messages
- Generate appropriate output when no duplicates are found
- Validate output file paths before processing (fail fast for unwritable paths)
- Ensure incomplete hash coverage doesn't break processing
- Provide user-friendly error messages following MediaHub patterns

**Done When**:
- Missing BaselineIndex produces clear error directing user to run library operations
- No duplicates scenario generates empty report with "no duplicates" summary
- Unwritable output paths fail before processing begins
- Incomplete hash coverage continues processing (skipping nil hashes)
- All error messages are user-friendly and actionable

**References**: spec.md section "Edge Cases & Failure Modes"

---

## Task 8: Comprehensive Testing and Validation Mapping

**Purpose**: Implement comprehensive test coverage and map implementation to validation requirements.

**Expected Files/Touchpoints**:
- `Tests/MediaHubTests/DuplicateReportingTests.swift` (extend)
- `Tests/MediaHubTests/DuplicateFormatterTests.swift` (extend)
- Integration tests via CLI command testing

**Subtasks**:
- Unit tests for all core components (grouping, ordering, formatting)
- Integration tests for end-to-end CLI behavior
- Edge case testing (empty libraries, no duplicates, large sets)
- Deterministic ordering verification across multiple test runs
- Performance testing for memory usage and execution time

**Done When**:
- All unit tests pass with comprehensive coverage (>90%)
- Integration tests verify CLI behavior matches spec requirements
- Deterministic ordering tests pass consistently across multiple runs
- Edge cases are covered with appropriate test scenarios
- Performance benchmarks meet spec targets (< 30 seconds, proportional memory usage)

**References**: spec.md sections "Success Metrics", "Testing"

---

## Validation Mapping (Light Preview)

**Mapping to validation.md requirements** (detailed implementation in Phase 4):
- **Functional**: Tasks 2, 4, 5, 6 verify duplicate detection, grouping, and all output formats
- **Safety**: All tasks enforce read-only behavior, zero writes verified in tests
- **Determinism**: Task 3 + tests ensure identical output for identical library state
- **Performance**: Task 2 + integration tests verify memory usage and execution time targets
- **Edge Cases**: Task 7 covers all failure modes from spec.md
- **Integration**: Task 1 + CLI tests verify seamless MediaHub command integration

---

## Implementation Order and Dependencies

**Sequential Implementation Order**:
1. CLI scaffolding (enables testing)
2. Core duplicate grouping (foundation)
3. Deterministic ordering (refines grouping)
4. Output formatters (parallelizable: text, JSON, CSV)
5. Edge cases (integrates with all components)
6. Testing (continuous throughout)

**Parallel Opportunities**:
- Text, JSON, and CSV formatters can be implemented in parallel after Task 3
- Unit tests can be developed alongside implementation tasks

**No Circular Dependencies**: Each task builds incrementally on previous tasks with clear interfaces.
