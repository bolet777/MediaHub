# Feature Specification: UI Operations UX (progress / cancel)

**Feature Branch**: `015-ui-operations-ux`  
**Created**: 2026-01-17  
**Status**: Draft  
**Input**: User description: "Progress bars, step indicators, and cancellation UI for detect/import/hash operations"

## Overview

This slice adds UI components for progress reporting and cancellation to long-running operations (detection, import, hash maintenance). The UI displays progress bars, step indicators, and cancel buttons that wire to the Core progress/cancellation API implemented in Slice 14.

**Problem Statement**: Long-running operations (detect, import, hash computation) currently show no progress feedback in the UI. Users cannot see operation progress or cancel operations mid-flight. Slice 14 added Core progress/cancellation API, but the UI does not yet consume these APIs to provide visual feedback and cancellation controls.

**Architecture Principle**: The UI is a read-only orchestrator. All progress and cancellation logic remains in Core (Slice 14). The UI wires Core progress callbacks to SwiftUI progress indicators and wires cancel buttons to Core cancellation tokens. The UI does not implement its own progress tracking or cancellation logic.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Detection Progress Display (Priority: P1)

A user wants to see progress during detection operations (scanning, comparing) to understand that the operation is progressing and not frozen.

**Why this priority**: Detection can take a long time for large sources. Users need visual feedback that the operation is progressing, not frozen or crashed.

**Independent Test**: Can be fully tested by running detection through the UI and verifying progress bars and step indicators update during scanning and comparison stages. This delivers the core capability of progress visibility.

**Acceptance Scenarios**:

1. **Given** the user starts a detection operation through the UI, **When** detection begins scanning, **Then** the UI displays a progress indicator with stage="scanning" and item count updates (e.g., "Scanning: 50 of 200 items")
2. **Given** the user views detection progress, **When** detection progresses from scanning to comparison, **Then** the UI updates the progress indicator to show stage="comparing" with item count updates (e.g., "Comparing: 30 of 200 items")
3. **Given** the user views detection progress, **When** detection completes, **Then** the UI shows completion (100% or "Complete") and transitions to detection results view
4. **Given** the user views detection progress, **When** progress updates are received from Core, **Then** the UI updates progress bars and step indicators smoothly (no flickering, throttled updates)
5. **Given** the user views detection progress, **When** detection fails or is canceled, **Then** the UI shows an appropriate error message and stops progress updates

---

### User Story 2 - Detection Cancellation (Priority: P1)

A user wants to cancel a detection operation in progress through the UI without corrupting library state.

**Why this priority**: Users may need to cancel long-running detection operations. Cancellation must be safe and provide clear feedback.

**Independent Test**: Can be fully tested by starting detection and clicking cancel, verifying the operation stops gracefully and the UI shows appropriate feedback. This delivers the core capability of cancellation control.

**Acceptance Scenarios**:

1. **Given** the user starts a detection operation through the UI, **When** detection is in progress, **Then** the UI displays a "Cancel" button that is enabled during operation
2. **Given** the user views detection progress with a cancel button, **When** the user clicks "Cancel", **Then** the UI requests cancellation from Core and shows "Canceling..." feedback
3. **Given** the user cancels detection, **When** cancellation completes, **Then** the UI shows "Operation canceled" message and stops progress updates
4. **Given** the user cancels detection, **When** cancellation completes, **Then** no source metadata is updated and the library remains in a consistent state (Core guarantees)
5. **Given** the user views detection progress, **When** detection completes successfully, **Then** the cancel button is disabled or hidden

---

### User Story 3 - Import Progress Display (Priority: P1)

A user wants to see progress during import operations to understand how many items have been imported (current/total).

**Why this priority**: Import operations can take a long time for large batches. Users need feedback showing import progress (e.g., "5 of 100 items imported").

**Independent Test**: Can be fully tested by running import through the UI and verifying progress bars update with current/total counts during import. This delivers the core capability of import progress visibility.

**Acceptance Scenarios**:

1. **Given** the user starts an import operation through the UI, **When** import begins, **Then** the UI displays a progress indicator with current/total counts (e.g., "Importing: 5 of 100 items")
2. **Given** the user views import progress, **When** import progresses through items, **Then** the UI updates the progress indicator with current/total counts (e.g., "Importing: 50 of 100 items")
3. **Given** the user views import progress, **When** import completes, **Then** the UI shows completion (100% or "Complete") and transitions to import results view
4. **Given** the user views import progress, **When** progress updates are received from Core, **Then** the UI updates progress bars smoothly (no flickering, throttled updates)
5. **Given** the user views import progress, **When** import fails or is canceled, **Then** the UI shows an appropriate error message and stops progress updates

---

### User Story 4 - Import Cancellation (Priority: P1)

A user wants to cancel an import operation in progress through the UI without corrupting library state or leaving partial imports.

**Why this priority**: Users may need to cancel long-running import operations. Cancellation must be safe: already-imported items remain, but no partial state is left.

**Independent Test**: Can be fully tested by starting import and clicking cancel, verifying the operation stops gracefully with already-imported items preserved. This delivers the core capability of import cancellation control.

**Acceptance Scenarios**:

1. **Given** the user starts an import operation through the UI, **When** import is in progress, **Then** the UI displays a "Cancel" button that is enabled during operation
2. **Given** the user views import progress with a cancel button, **When** the user clicks "Cancel", **Then** the UI requests cancellation from Core and shows "Canceling..." feedback
3. **Given** the user cancels import, **When** cancellation completes, **Then** the UI shows "Operation canceled" message and stops progress updates
4. **Given** the user cancels import, **When** cancellation completes, **Then** already-imported items remain in the library and no partial state is left (Core guarantees)
5. **Given** the user views import progress, **When** import completes successfully, **Then** the cancel button is disabled or hidden

---

### User Story 5 - Hash Maintenance Progress Display (Priority: P2 - Deferred to Slice 16)

A user wants to see progress during hash computation operations to understand how many hashes have been computed (current/total candidates).

**Why this priority**: Hash computation can take a long time for large libraries. Users need feedback showing progress (e.g., "50 of 200 hashes computed"). **Note**: Hash maintenance UI workflow is deferred to Slice 16. This user story is documented for future implementation.

**Independent Test**: Can be fully tested by running hash computation through the UI and verifying progress bars update with current/total counts during hash computation. This delivers the core capability of hash progress visibility.

**Acceptance Scenarios**:

1. **Given** the user starts a hash computation operation through the UI, **When** hash computation begins, **Then** the UI displays a progress indicator with current/total counts (e.g., "Computing hashes: 50 of 200 files")
2. **Given** the user views hash computation progress, **When** hash computation progresses through files, **Then** the UI updates the progress indicator with current/total counts (e.g., "Computing hashes: 150 of 200 files")
3. **Given** the user views hash computation progress, **When** hash computation completes, **Then** the UI shows completion (100% or "Complete") and transitions to results view
4. **Given** the user views hash computation progress, **When** progress updates are received from Core, **Then** the UI updates progress bars smoothly (no flickering, throttled updates)
5. **Given** the user views hash computation progress, **When** hash computation fails or is canceled, **Then** the UI shows an appropriate error message and stops progress updates

---

### User Story 6 - Hash Maintenance Cancellation (Priority: P2 - Deferred to Slice 16)

A user wants to cancel a hash computation operation in progress through the UI without corrupting the baseline index.

**Why this priority**: Users may need to cancel long-running hash computation operations. Cancellation must be safe: already-computed hashes are preserved in the index, but no partial state is left. **Note**: Hash maintenance UI workflow is deferred to Slice 16. This user story is documented for future implementation.

**Independent Test**: Can be fully tested by starting hash computation and clicking cancel, verifying the operation stops gracefully with already-computed hashes preserved. This delivers the core capability of hash cancellation control.

**Acceptance Scenarios**:

1. **Given** the user starts a hash computation operation through the UI, **When** hash computation is in progress, **Then** the UI displays a "Cancel" button that is enabled during operation
2. **Given** the user views hash computation progress with a cancel button, **When** the user clicks "Cancel", **Then** the UI requests cancellation from Core and shows "Canceling..." feedback
3. **Given** the user cancels hash computation, **When** cancellation completes, **Then** the UI shows "Operation canceled" message and stops progress updates
4. **Given** the user cancels hash computation, **When** cancellation completes, **Then** already-computed hashes remain in the baseline index and no partial state is left (Core guarantees)
5. **Given** the user views hash computation progress, **When** hash computation completes successfully, **Then** the cancel button is disabled or hidden

---

## Success Criteria

### SC-001: Detection Progress UI
- **Requirement**: Detection operations display progress bars and step indicators that update during scanning and comparison stages
- **Validation**: UI shows progress with stage names ("scanning", "comparing") and item counts during detection operations
- **Priority**: P1

### SC-002: Detection Cancellation UI
- **Requirement**: Detection operations display a "Cancel" button that allows users to cancel operations in progress
- **Validation**: Cancel button is enabled during detection, clicking cancel stops the operation and shows appropriate feedback
- **Priority**: P1

### SC-003: Import Progress UI
- **Requirement**: Import operations display progress bars that update with current/total counts during import
- **Validation**: UI shows progress with current/total counts (e.g., "5 of 100 items") during import operations
- **Priority**: P1

### SC-004: Import Cancellation UI
- **Requirement**: Import operations display a "Cancel" button that allows users to cancel operations in progress
- **Validation**: Cancel button is enabled during import, clicking cancel stops the operation and shows appropriate feedback
- **Priority**: P1

### SC-007: Progress Update Smoothness
- **Requirement**: Progress bars and indicators update smoothly without flickering, respecting Core throttling (max 1 update per second)
- **Validation**: Progress UI updates smoothly, no flickering or rapid updates that exceed Core throttling
- **Priority**: P1

### SC-008: Cancellation Feedback
- **Requirement**: When cancellation is requested, the UI shows "Canceling..." feedback and appropriate completion messages
- **Validation**: Cancel button shows "Canceling..." state, operation stops gracefully, completion message is displayed
- **Priority**: P1

### SC-009: Error Handling
- **Requirement**: Progress UI handles errors gracefully (operation failures, cancellation errors) and displays appropriate error messages
- **Validation**: Error messages are user-facing, stable, and actionable when operations fail or are canceled
- **Priority**: P1

### SC-010: Backward Compatibility
- **Requirement**: Existing UI workflows (detection, import) continue to work unchanged. Progress/cancellation is additive, not required.
- **Validation**: All existing UI workflows continue to work without modification. Progress/cancellation is optional enhancement.
- **Priority**: P1

---

## Success Criteria Deferred to Slice 16

The following success criteria are deferred to Slice 16 (Hash Maintenance UI workflow):

### SC-005: Hash Maintenance Progress UI (Deferred)
- **Requirement**: Hash computation operations display progress bars that update with current/total counts during hash computation
- **Validation**: UI shows progress with current/total counts (e.g., "50 of 200 files") during hash computation operations
- **Priority**: P2 - Deferred to Slice 16
- **Note**: Hash maintenance UI workflow must be implemented in Slice 16 before progress/cancellation UI can be added.

### SC-006: Hash Maintenance Cancellation UI (Deferred)
- **Requirement**: Hash computation operations display a "Cancel" button that allows users to cancel operations in progress
- **Validation**: Cancel button is enabled during hash computation, clicking cancel stops the operation and shows appropriate feedback
- **Priority**: P2 - Deferred to Slice 16
- **Note**: Hash maintenance UI workflow must be implemented in Slice 16 before progress/cancellation UI can be added.

---

## Non-Goals

- **Core API changes**: This slice does NOT modify Core progress/cancellation API. Core API from Slice 14 is consumed as-is.
- **CLI progress changes**: This slice does NOT change CLI progress output. CLI continues to use `ProgressIndicator` for stderr output.
- **Progress persistence**: This slice does NOT persist progress state across app restarts. Progress is ephemeral and only active during operation execution.
- **Batch progress**: This slice does NOT add progress reporting for batch operations (e.g., "library 1 of 3"). Only per-operation progress is supported.
- **Progress estimation**: This slice does NOT add time-based progress estimation (e.g., "5 minutes remaining"). Only item-based progress (current/total) is supported.
- **Hash maintenance UI workflow**: This slice does NOT add the initial hash maintenance UI workflow (triggering hash computation). Only progress/cancellation UI for existing hash maintenance operations is supported. Full hash maintenance UI is deferred to Slice 16.
- **Progress animations**: This slice does NOT add complex progress animations or visual effects. Simple progress bars and step indicators are sufficient.

---

## API Requirements

### API-001: DetectionOrchestrator Progress/Cancel Integration
- **Location**: `Sources/MediaHubUI/DetectionOrchestrator.swift`
- **Method**: `DetectionOrchestrator.runDetection`
- **Implementation**: Internally wire Core progress/cancel into UI state; no public signature change required.
- **Behavior**:
  - Create `CancellationToken` internally when operation starts
  - Store cancellation token in `DetectionState.cancellationToken`
  - Create progress callback internally that forwards Core progress updates to MainActor
  - Update `DetectionState` progress fields on MainActor when progress callbacks are received
  - Pass progress callback and cancellation token to Core `DetectionOrchestrator.executeDetection`
  - Handle `CancellationError` and update `DetectionState.isCanceling` on MainActor
  - Clear cancellation token when operation completes (success or failure)

### API-002: ImportOrchestrator Progress/Cancel Integration
- **Location**: `Sources/MediaHubUI/ImportOrchestrator.swift`
- **Method**: `ImportOrchestrator.executeImport`
- **Implementation**: Internally wire Core progress/cancel into UI state; no public signature change required.
- **Behavior**:
  - Create `CancellationToken` internally when operation starts
  - Store cancellation token in `ImportState.cancellationToken`
  - Create progress callback internally that forwards Core progress updates to MainActor
  - Update `ImportState` progress fields on MainActor when progress callbacks are received
  - Pass progress callback and cancellation token to Core `ImportExecutor.executeImport`
  - Handle `CancellationError` and update `ImportState.isCanceling` on MainActor
  - Clear cancellation token when operation completes (success or failure)

### API-003: DetectionState Progress Fields
- **Location**: `Sources/MediaHubUI/DetectionState.swift`
- **New Properties**:
  - `var progressStage: String?` - Current operation stage (e.g., "scanning", "comparing")
  - `var progressCurrent: Int?` - Current item count (optional)
  - `var progressTotal: Int?` - Total item count (optional)
  - `var progressMessage: String?` - Optional progress message
  - `var cancellationToken: CancellationToken?` - Cancellation token for current operation
  - `var isCanceling: Bool` - Whether cancellation is in progress
- **Thread Safety**: All properties are `@MainActor` and updated on MainActor

### API-004: ImportState Progress Fields
- **Location**: `Sources/MediaHubUI/ImportState.swift`
- **New Properties**:
  - `var progressStage: String?` - Current operation stage (e.g., "importing")
  - `var progressCurrent: Int?` - Current item count (optional)
  - `var progressTotal: Int?` - Total item count (optional)
  - `var progressMessage: String?` - Optional progress message
  - `var cancellationToken: CancellationToken?` - Cancellation token for current operation
  - `var isCanceling: Bool` - Whether cancellation is in progress
- **Thread Safety**: All properties are `@MainActor` and updated on MainActor

### API-005: DetectionRunView Progress UI
- **Location**: `Sources/MediaHubUI/DetectionRunView.swift`
- **New Components**:
  - Progress bar showing current/total counts during detection
  - Step indicator showing current stage ("scanning", "comparing")
  - Cancel button that is enabled during operation
- **Behavior**:
  - Progress bar updates when `detectionState.progressCurrent` and `detectionState.progressTotal` change
  - Step indicator updates when `detectionState.progressStage` changes
  - Cancel button calls `detectionState.cancellationToken?.cancel()` when clicked
  - Cancel button shows "Canceling..." state when `detectionState.isCanceling` is true

### API-006: ImportExecutionView Progress UI
- **Location**: `Sources/MediaHubUI/ImportExecutionView.swift`
- **New Components**:
  - Progress bar showing current/total counts during import
  - Cancel button that is enabled during operation
- **Behavior**:
  - Progress bar updates when `importState.progressCurrent` and `importState.progressTotal` change
  - Cancel button calls `importState.cancellationToken?.cancel()` when clicked
  - Cancel button shows "Canceling..." state when `importState.isCanceling` is true

### API-007: Hash Maintenance Progress UI (Future)
- **Location**: `Sources/MediaHubUI/` (new file or existing hash maintenance view)
- **Note**: Hash maintenance UI workflow is deferred to Slice 16. This slice only adds progress/cancellation UI components that can be wired when hash maintenance UI is implemented.
- **Future Components** (not implemented in this slice):
  - Progress bar showing current/total counts during hash computation
  - Cancel button that is enabled during operation
- **Future Behavior** (not implemented in this slice):
  - Progress bar updates when hash computation progress changes
  - Cancel button calls cancellation token when clicked

---

## Safety Rules

### SR-001: Read-Only Progress Display
- **Rule**: Progress UI is read-only. Progress UI displays Core progress updates but does not modify library state, source state, or any Core data structures.
- **Enforcement**: Progress UI only reads from `DetectionState` and `ImportState` progress fields. No Core APIs are called from progress UI components.

### SR-002: Cancellation Safety
- **Rule**: Cancellation UI only requests cancellation from Core. Core guarantees safe cancellation (atomic operations, no partial state).
- **Enforcement**: Cancel buttons only call `cancellationToken?.cancel()`. No additional cancellation logic is implemented in UI.

### SR-003: MainActor Progress Updates
- **Rule**: All progress UI updates occur on MainActor. Progress callbacks from Core are received on background threads and forwarded to MainActor.
- **Enforcement**: Progress callbacks in orchestrators use `Task { @MainActor in ... }` or `await MainActor.run { ... }` to update UI state.

### SR-004: Error Handling
- **Rule**: Progress UI handles errors gracefully (operation failures, cancellation errors) and displays user-facing, stable, and actionable error messages.
- **Enforcement**: Error handling in orchestrators maps Core errors to user-facing messages and updates UI state on MainActor.

### SR-005: Backward Compatibility
- **Rule**: Existing UI workflows continue to work unchanged. Progress/cancellation is additive, not required.
- **Enforcement**: Progress/cancellation parameters are optional with `nil` defaults. Existing UI workflows without progress/cancellation continue to work.

---

## Determinism & Idempotence

### DI-001: Progress Display Determinism
- **Rule**: Progress UI displays progress deterministically. Same operation produces same progress display sequence (stage names, counts).
- **Enforcement**: Progress UI reflects Core progress updates. Core progress updates are deterministic (Slice 14 guarantees).

### DI-002: Cancellation Idempotence
- **Rule**: Cancellation UI is idempotent. Clicking cancel multiple times has the same effect as clicking once.
- **Enforcement**: Cancel buttons check `cancellationToken?.isCanceled` before calling `cancel()`. Multiple clicks are safe.

### DI-003: Operation Idempotence Preserved
- **Rule**: Adding progress/cancellation UI does not change operation idempotence. Operations remain idempotent as before.
- **Enforcement**: Progress/cancellation UI is additive. Operation logic (detection, import) remains unchanged. Only progress display and cancellation controls are added.

---

## Backward Compatibility

### BC-001: UI Workflow Backward Compatibility
- **Guarantee**: Existing UI workflows (detection, import) continue to work unchanged. Progress/cancellation is additive, not required.
- **Enforcement**: Progress/cancellation parameters are optional with `nil` defaults. Existing UI workflows without progress/cancellation continue to work.

### BC-002: Core API Backward Compatibility
- **Guarantee**: UI orchestrators consume Core progress/cancellation API from Slice 14. Core API remains unchanged.
- **Enforcement**: UI orchestrators call Core APIs with optional progress/cancellation parameters. Core API signatures remain unchanged.

### BC-003: State Management Backward Compatibility
- **Guarantee**: Existing `DetectionState` and `ImportState` properties remain unchanged. New progress fields are additive.
- **Enforcement**: New progress fields are optional and do not affect existing state properties. Existing UI components continue to work.

---

## Implementation Notes

### Progress Callback Threading
- Core progress callbacks are invoked on background threads (from `Task.detached`).
- UI orchestrators must forward progress updates to MainActor using `Task { @MainActor in ... }` or `await MainActor.run { ... }`.
- Progress UI components observe `@ObservedObject` state and update automatically on MainActor.

### Cancellation Token Lifecycle
- Cancellation tokens are created when operations start and stored in `DetectionState` or `ImportState`.
- Cancellation tokens are cleared when operations complete (success or failure).
- Cancel buttons check `cancellationToken?.isCanceled` before calling `cancel()` to avoid redundant cancellation.

### Progress Update Throttling
- Core progress callbacks are throttled to maximum 1 update per second (Slice 14 guarantee).
- UI progress bars and indicators update smoothly without flickering due to Core throttling.
- No additional UI throttling is required.

### Error Handling
- Core operations throw `CancellationError.cancelled` when canceled.
- UI orchestrators catch `CancellationError` and update UI state to show "Operation canceled" message.
- Other errors are mapped to user-facing messages using existing error mapping logic.

### SwiftUI Progress Components
- Use `ProgressView` with `value: Double(current) / Double(total)` for progress bars.
- Use `Text` with `progressStage` for step indicators.
- Use `Button` with `disabled` state for cancel buttons.
- Use `@ObservedObject` to observe state changes automatically.

---

## Dependencies

- **Slice 14**: Core progress/cancellation API (`ProgressUpdate`, `CancellationToken`, `CancellationError`) must be implemented and available.
- **Slice 13**: UI detection and import workflows must be implemented (DetectionRunView, ImportExecutionView, orchestrators).

---

## Out of Scope

- Core API changes (Core API from Slice 14 is consumed as-is)
- CLI progress changes (CLI continues to use `ProgressIndicator`)
- Progress persistence across app restarts
- Batch progress reporting (e.g., "library 1 of 3")
- Time-based progress estimation (e.g., "5 minutes remaining")
- Hash maintenance UI workflow (deferred to Slice 16; only progress/cancellation UI components are in scope)
- Progress animations or complex visual effects
- Progress history or audit trail (deferred to Slice 17)
