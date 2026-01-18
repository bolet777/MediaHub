# Feature Specification: UI Hash Maintenance + Coverage

**Feature Branch**: `016-ui-hash-maintenance-coverage`  
**Created**: 2026-01-17  
**Status**: Draft  
**Input**: User description: "Hash maintenance UI (batch/limit operations) and coverage insights with duplicate detection (read-only)"

## Overview

This slice adds UI workflows for hash maintenance operations (batch/limit hash computation), hash coverage insights, and read-only duplicate detection display. The UI orchestrates existing Core APIs (`HashCoverageMaintenance`, `DuplicateReporting`) to provide user-friendly workflows that match the safety guarantees of the CLI commands.

**Problem Statement**: Users need visual interfaces to trigger hash computation operations, view hash coverage statistics, and explore duplicate files through the desktop app. The desktop app must provide safe, guided workflows that preview operations before execution and require explicit confirmation, matching the CLI's dry-run and confirmation behavior.

**Architecture Principle**: The desktop application is a UI orchestrator. All business logic, data validation, and operations remain in the Core layer. The UI invokes Core APIs directly (e.g., `HashCoverageMaintenance.selectCandidates`, `HashCoverageMaintenance.computeMissingHashes`, `DuplicateReporting.analyzeDuplicates`) but never implements its own hash computation or duplicate detection logic. The UI provides visual feedback, progress indicators, and confirmation dialogs, but all actual operations are performed by Core APIs.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View Hash Coverage Insights (Priority: P1)

A user wants to see hash coverage statistics for their library to understand how many files have hashes and how many are missing hashes.

**Why this priority**: Hash coverage visibility enables users to understand library state and make informed decisions about hash maintenance operations. This is foundational for hash maintenance workflows.

**Independent Test**: Can be fully tested by opening a library and verifying hash coverage statistics are displayed accurately. This delivers the core capability of coverage visibility.

**Acceptance Scenarios**:

1. **Given** the user opens a library in the app, **When** the library status is displayed, **Then** the app shows hash coverage statistics (total entries, entries with hash, entries missing hash, coverage percentage)
2. **Given** the user views hash coverage statistics, **When** the library has complete hash coverage (100%), **Then** the app displays "100% coverage" or similar positive indicator
3. **Given** the user views hash coverage statistics, **When** the library has partial hash coverage (e.g., 50%), **Then** the app displays coverage percentage and candidate count (files that can be hashed)
4. **Given** the user views hash coverage statistics, **When** the baseline index is missing or invalid, **Then** the app displays "N/A" or "Not available" for hash coverage (graceful degradation)
5. **Given** the user views hash coverage statistics, **When** the library has no entries, **Then** the app displays "0 entries" or similar appropriate message

---

### User Story 2 - Preview Hash Maintenance Operation (Priority: P1)

A user wants to preview what hash computation operation would do before executing it. The UI must support a preview mode that shows candidate files and statistics without computing hashes.

**Why this priority**: Preview enables users to explore hash maintenance operations before committing. This matches the CLI's `--dry-run` flag behavior and provides transparency.

**Independent Test**: Can be fully tested by launching hash maintenance preview and verifying the preview shows accurate candidate information without computing hashes. This delivers the core capability of safe preview.

**Acceptance Scenarios**:

1. **Given** the user clicks "Preview Hash Maintenance" or similar action, **When** the preview runs, **Then** the app displays candidate files (files missing hashes) and statistics without computing any hashes
2. **Given** the user views hash maintenance preview results, **When** the preview completes, **Then** the app shows a clear indication that this is a preview (e.g., "Preview" badge or "This is a preview" message)
3. **Given** the user views hash maintenance preview results, **When** the preview completes, **Then** the app enables the "Run Hash Maintenance" button, allowing the user to proceed with actual hash computation
4. **Given** the user views hash maintenance preview results, **When** the preview fails (e.g., library inaccessible), **Then** the app displays a clear error message and disables the "Run Hash Maintenance" button
5. **Given** hash maintenance preview runs, **When** the preview completes, **Then** the app shows candidate statistics (total candidates, limit if specified) matching CLI `index hash --dry-run` output semantically (same counts and values, not exact formatting)

---

### User Story 3 - Run Hash Maintenance with Batch/Limit (Priority: P1)

A user wants to trigger hash computation operations through the UI with optional batch/limit controls. The UI must support running hash computation after preview, or directly without preview, with progress feedback and cancellation support.

**Why this priority**: Hash computation execution enables users to improve hash coverage incrementally. This is a core operation that must be accessible through the UI with progress/cancellation support (from Slice 15).

**Independent Test**: Can be fully tested by running hash computation through the UI and verifying hashes are computed and progress is displayed. This delivers the core capability of hash computation execution.

**Acceptance Scenarios**:

1. **Given** the user clicks "Run Hash Maintenance" or similar action, **When** hash computation runs, **Then** the app shows a progress indicator with current/total counts (e.g., "Computing hashes: 50 of 200 files") and displays results when complete
2. **Given** the user runs hash computation, **When** hash computation completes successfully, **Then** the app displays success feedback (hashes computed, coverage improved) and updates hash coverage statistics
3. **Given** the user runs hash computation, **When** hash computation fails (e.g., permission error), **Then** the app displays a clear, user-facing error message explaining what went wrong
4. **Given** the user runs hash computation, **When** hash computation is in progress, **Then** the app shows a progress indicator and cancel button (from Slice 15) and disables the "Run Hash Maintenance" button to prevent duplicate operations
5. **Given** the user configures hash maintenance with a limit (e.g., "Process first 100 files"), **When** hash computation runs, **Then** the app processes only the specified number of files and shows progress accordingly

---

### User Story 4 - View Duplicate Detection Results (Priority: P1)

A user wants to view duplicate files in their library through the UI. The UI must display duplicate groups and file details in a read-only view.

**Why this priority**: Duplicate visibility enables users to understand duplicate content and make informed decisions about content management. This is a read-only operation that provides transparency.

**Independent Test**: Can be fully tested by launching duplicate detection and verifying duplicate groups and file details are displayed accurately. This delivers the core capability of duplicate visibility.

**Acceptance Scenarios**:

1. **Given** the user clicks "View Duplicates" or similar action, **When** duplicate detection runs, **Then** the app displays duplicate groups (files with same hash) and file details (path, size, timestamp) in a read-only view
2. **Given** the user views duplicate detection results, **When** duplicate detection completes, **Then** the app shows duplicate statistics (total groups, total files, potential savings) matching CLI `duplicates` output semantically (same counts and values, not exact formatting)
3. **Given** the user views duplicate detection results, **When** no duplicates are found, **Then** the app displays "No duplicates found" message
4. **Given** the user views duplicate detection results, **When** duplicate detection fails (e.g., library inaccessible), **Then** the app displays a clear, user-facing error message explaining what went wrong
5. **Given** duplicate detection runs, **When** duplicate detection completes, **Then** the app shows duplicate groups sorted deterministically (by hash) and files within groups sorted by path

---

## Success Criteria

### SC-001: Hash Coverage Display
- **Requirement**: Library status view displays hash coverage statistics (total entries, entries with hash, entries missing hash, coverage percentage)
- **Validation**: UI shows hash coverage statistics accurately when library is opened, with graceful degradation when index is missing/invalid
- **Priority**: P1

### SC-002: Hash Maintenance Preview
- **Requirement**: Hash maintenance preview displays candidate files and statistics without computing hashes
- **Validation**: Preview shows accurate candidate information, clearly marked as preview, enables execution button
- **Priority**: P1

### SC-003: Hash Maintenance Execution
- **Requirement**: Hash maintenance execution computes hashes with progress feedback and cancellation support
- **Validation**: Hash computation runs with progress bars, cancel button works, results update coverage statistics
- **Priority**: P1

### SC-004: Hash Maintenance Batch/Limit Controls
- **Requirement**: Hash maintenance UI supports optional limit configuration (process first N files)
- **Validation**: Limit configuration works correctly, only specified number of files are processed
- **Priority**: P1

### SC-005: Duplicate Detection Display
- **Requirement**: Duplicate detection displays duplicate groups and file details in read-only view
- **Validation**: Duplicate groups and files are displayed accurately, sorted deterministically, statistics match CLI output
- **Priority**: P1

### SC-006: Progress and Cancellation Integration
- **Requirement**: Hash maintenance operations display progress bars and support cancellation (from Slice 15)
- **Validation**: Progress bars update during hash computation, cancel button stops operation gracefully
- **Priority**: P1

### SC-007: Error Handling
- **Requirement**: All operations handle errors gracefully and display user-facing, stable, and actionable error messages
- **Validation**: Error messages are clear and actionable when operations fail
- **Priority**: P1

### SC-008: Backward Compatibility
- **Requirement**: Existing UI workflows continue to work unchanged. Hash maintenance and duplicate detection are additive features.
- **Validation**: All existing UI workflows continue to work without modification
- **Priority**: P1

---

## Non-Goals

- **Core API changes**: This slice does NOT modify Core hash maintenance or duplicate detection APIs. Core APIs from Slices 9 and 9b are consumed as-is.
- **CLI changes**: This slice does NOT change CLI hash maintenance or duplicate detection commands. CLI continues to work as before.
- **Duplicate resolution**: This slice does NOT add duplicate deletion or merging capabilities. Duplicate detection is read-only.
- **Automatic hash computation**: This slice does NOT add automatic or scheduled hash computation. All hash computation is user-initiated.
- **Hash computation history**: This slice does NOT persist hash computation history or audit trail (deferred to Slice 17).
- **Export capabilities**: This slice does NOT add export capabilities for duplicate reports (deferred to Slice 17).

---

## API Requirements

### API-001: HashCoverageMaintenance.selectCandidates Integration
- **Location**: `Sources/MediaHubUI/` (new orchestrator or existing)
- **Method**: Call `HashCoverageMaintenance.selectCandidates(libraryRoot:limit:)` for preview
- **Behavior**:
  - Call Core API with library root path and optional limit
  - Receive `HashCoverageCandidates` with statistics and candidate entries
  - Update UI state with preview results on MainActor
  - Handle errors and map to user-facing messages

### API-002: HashCoverageMaintenance.computeMissingHashes Integration
- **Location**: `Sources/MediaHubUI/` (new orchestrator or existing)
- **Method**: Call `HashCoverageMaintenance.computeMissingHashes(libraryRoot:limit:progress:cancellationToken:)` for execution
- **Behavior**:
  - Create `CancellationToken` internally when operation starts
  - Store cancellation token in hash maintenance state
  - Create progress callback that forwards Core progress updates to MainActor
  - Update hash maintenance state progress fields on MainActor when progress callbacks are received
  - Pass progress callback and cancellation token to Core API
  - Handle `CancellationError` and update state on MainActor
  - Clear cancellation token when operation completes (success or failure)

### API-003: DuplicateReporting.analyzeDuplicates Integration
- **Location**: `Sources/MediaHubUI/` (new orchestrator or existing)
- **Method**: Call `DuplicateReporting.analyzeDuplicates(in:)` for duplicate detection
- **Behavior**:
  - Call Core API with library root path
  - Receive `([DuplicateGroup], DuplicateSummary)` tuple
  - Update UI state with duplicate results on MainActor
  - Handle errors and map to user-facing messages

### API-004: Hash Maintenance State
- **Location**: `Sources/MediaHubUI/` (new state file or existing)
- **New Properties**:
  - `var previewCandidates: HashCoverageCandidates?` - Preview candidate results
  - `var isPreviewing: Bool` - Whether preview is in progress
  - `var hashComputationResult: HashComputationResult?` - Hash computation results
  - `var isComputing: Bool` - Whether hash computation is in progress
  - `var progressStage: String?` - Current operation stage (e.g., "computing")
  - `var progressCurrent: Int?` - Current file count (optional)
  - `var progressTotal: Int?` - Total file count (optional)
  - `var progressMessage: String?` - Optional progress message
  - `var cancellationToken: CancellationToken?` - Cancellation token for current operation
  - `var isCanceling: Bool` - Whether cancellation is in progress
  - `var limit: Int?` - Optional limit for batch operations (source of truth: defined once by user, stored in state, reused consistently for preview and execution unless changed by user)
- **Thread Safety**: All properties are `@MainActor` and updated on MainActor

### API-005: Duplicate Detection State
- **Location**: `Sources/MediaHubUI/` (new state file or existing)
- **New Properties**:
  - `var duplicateGroups: [DuplicateGroup]?` - Duplicate groups (read-only)
  - `var duplicateSummary: DuplicateSummary?` - Duplicate summary statistics
  - `var isAnalyzing: Bool` - Whether duplicate analysis is in progress
- **Thread Safety**: All properties are `@MainActor` and updated on MainActor

### API-006: Hash Coverage Statistics Display
- **Location**: `Sources/MediaHubUI/StatusView.swift` or new view
- **Integration**: Display hash coverage statistics from `LibraryStatus` (already available from Slice 9)
- **Behavior**:
  - Display hash coverage percentage, total entries, entries with hash, entries missing hash
  - Show "N/A" when baseline index is missing/invalid (graceful degradation)
  - Update when hash maintenance operations complete

### API-007: Hash Maintenance Preview View
- **Location**: `Sources/MediaHubUI/` (new view)
- **Components**:
  - Candidate file list or summary
  - Statistics display (total candidates, limit if specified)
  - "Preview" badge or indicator
  - "Run Hash Maintenance" button
- **Behavior**:
  - Display preview results from `HashCoverageMaintenance.selectCandidates`
  - Show clear "Preview" indication
  - Enable execution button when preview completes successfully

### API-008: Hash Maintenance Execution View
- **Location**: `Sources/MediaHubUI/` (new view or extend existing)
- **Components**:
  - Progress bar showing current/total counts during hash computation
  - Cancel button that is enabled during operation (from Slice 15)
  - Limit configuration input (optional, for batch operations)
  - Results display when complete
- **Behavior**:
  - Progress bar updates when hash maintenance state progress fields change
  - Cancel button calls `hashMaintenanceState.cancellationToken?.cancel()` when clicked
  - Cancel button shows "Canceling..." state when `hashMaintenanceState.isCanceling` is true
  - Limit input allows user to specify batch size (optional)

### API-009: Duplicate Detection View
- **Location**: `Sources/MediaHubUI/` (new view)
- **Components**:
  - Duplicate groups list (sorted by hash)
  - File details within each group (path, size, timestamp)
  - Summary statistics (total groups, total files, potential savings)
  - "No duplicates found" message when empty
- **Behavior**:
  - Display duplicate groups and files from `DuplicateReporting.analyzeDuplicates`
  - Show statistics matching CLI output
  - Read-only view (no deletion or merging capabilities)

---

## Safety Rules

### SR-001: Read-Only Duplicate Detection
- **Rule**: Duplicate detection UI is read-only. Duplicate detection displays Core analysis results but does not modify library state, delete files, or perform any mutations.
- **Enforcement**: Duplicate detection UI only reads from `DuplicateReporting.analyzeDuplicates`. No Core APIs that mutate library state are called from duplicate detection UI.

### SR-002: Hash Maintenance Preview Safety
- **Rule**: Hash maintenance preview performs zero hash computation and zero writes. Preview only calls `HashCoverageMaintenance.selectCandidates` which is read-only.
- **Enforcement**: Preview UI only calls `selectCandidates` API. No hash computation or index writes occur during preview.

### SR-003: Hash Maintenance Execution Safety
- **Rule**: Hash maintenance execution only computes hashes and updates index. No media files are modified. Explicit confirmation required before execution.
- **Enforcement**: Execution UI requires explicit confirmation before calling `HashCoverageMaintenance.computeMissingHashes`. Core API guarantees no media file modifications.

### SR-004: MainActor State Updates
- **Rule**: All UI state updates occur on MainActor. Core API calls are made from background threads and results are forwarded to MainActor.
- **Enforcement**: All state updates in orchestrators use `Task { @MainActor in ... }` or `await MainActor.run { ... }` to update UI state.

### SR-005: Error Handling
- **Rule**: All operations handle errors gracefully and display user-facing, stable, and actionable error messages.
- **Enforcement**: Error handling in orchestrators maps Core errors to user-facing messages and updates UI state on MainActor.

### SR-006: Backward Compatibility
- **Rule**: Existing UI workflows continue to work unchanged. Hash maintenance and duplicate detection are additive features.
- **Enforcement**: New features are additive. Existing UI workflows without hash maintenance/duplicate detection continue to work.

---

## Determinism & Idempotence

### DI-001: Hash Maintenance Determinism
- **Rule**: Hash maintenance operations are deterministic. Same library state produces same candidate selection and hash computation results.
- **Enforcement**: Hash maintenance UI reflects Core API determinism. Core APIs guarantee deterministic behavior (Slice 9 guarantees).

### DI-002: Duplicate Detection Determinism
- **Rule**: Duplicate detection results are deterministic. Same library state produces same duplicate groups and statistics.
- **Enforcement**: Duplicate detection UI reflects Core API determinism. Core APIs guarantee deterministic ordering (Slice 9b guarantees).

### DI-003: Operation Idempotence Preserved
- **Rule**: Adding hash maintenance/duplicate detection UI does not change operation idempotence. Operations remain idempotent as before.
- **Enforcement**: Hash maintenance/duplicate detection UI is additive. Operation logic (hash computation, duplicate analysis) remains unchanged. Only UI orchestration is added.

---

## Backward Compatibility

### BC-001: UI Workflow Backward Compatibility
- **Guarantee**: Existing UI workflows continue to work unchanged. Hash maintenance and duplicate detection are additive features.
- **Enforcement**: New features are additive. Existing UI workflows without hash maintenance/duplicate detection continue to work.

### BC-002: Core API Backward Compatibility
- **Guarantee**: UI orchestrators consume Core hash maintenance and duplicate detection APIs from Slices 9 and 9b. Core APIs remain unchanged.
- **Enforcement**: UI orchestrators call Core APIs with existing signatures. Core API signatures remain unchanged.

### BC-003: State Management Backward Compatibility
- **Guarantee**: Existing UI state properties remain unchanged. New hash maintenance and duplicate detection state properties are additive.
- **Enforcement**: New state properties are optional and do not affect existing state properties. Existing UI components continue to work.

---

## Implementation Notes

### Hash Maintenance Workflow
- Preview: Call `HashCoverageMaintenance.selectCandidates` to show what would be computed
- Execution: Call `HashCoverageMaintenance.computeMissingHashes` with progress/cancellation support
- Limit: Limit value is defined once by the user, stored in `HashMaintenanceState.limit`, and reused consistently for both preview and execution unless changed by the user
- Progress: Use progress callbacks from Core (Slice 14) to update UI state on MainActor
- Cancellation: Use cancellation tokens from Core (Slice 14) to allow user cancellation

### Duplicate Detection Workflow
- Analysis: Call `DuplicateReporting.analyzeDuplicates` to get duplicate groups and summary
- Display: Show duplicate groups and files in read-only view
- Statistics: Display summary statistics matching CLI output semantically (same counts and values, not exact formatting)

### Hash Coverage Statistics
- Source: Hash coverage statistics are already available in `LibraryStatus` from Slice 9
- Display: Integrate hash coverage display into existing status view or create dedicated view
- Update: Refresh hash coverage statistics after hash maintenance operations complete

### Progress and Cancellation
- Integration: Use progress/cancellation API from Slice 15 for hash maintenance operations
- Threading: Core progress callbacks are invoked on background threads, forward to MainActor
- Throttling: Core progress callbacks are throttled to maximum 1 update per second (Slice 14 guarantee)

### Error Handling
- Core operations throw domain-specific errors (`HashCoverageMaintenanceError`, `DuplicateReportingError`)
- UI orchestrators catch errors and map to user-facing messages
- Error messages are stable and actionable

---

## Dependencies

- **Slice 9**: Core hash maintenance API (`HashCoverageMaintenance`) must be implemented and available
- **Slice 9b**: Core duplicate detection API (`DuplicateReporting`) must be implemented and available
- **Slice 14**: Core progress/cancellation API (`ProgressUpdate`, `CancellationToken`, `CancellationError`) must be implemented and available
- **Slice 15**: UI progress/cancellation components must be implemented (progress bars, cancel buttons)
- **Slice 13**: UI source/detection/import workflows must be implemented (for UI pattern consistency)

---

## Out of Scope

- Core API changes (Core APIs from Slices 9, 9b, 14 are consumed as-is)
- CLI changes (CLI continues to work as before)
- Duplicate resolution (deletion, merging)
- Automatic or scheduled hash computation
- Hash computation history or audit trail (deferred to Slice 17)
- Export capabilities for duplicate reports (deferred to Slice 17)
