# Implementation Tasks: UI Operations UX (progress / cancel)

**Feature**: UI Operations UX (progress / cancel)  
**Specification**: `specs/015-ui-operations-ux/spec.md`  
**Plan**: `specs/015-ui-operations-ux/plan.md`  
**Slice**: 15 - Progress bars, step indicators, and cancellation UI for detect/import/hash operations  
**Created**: 2026-01-17

## Task Organization

Tasks are organized by phase, following the implementation sequence defined in the plan. Each task is:
- Small and focused on a single deliverable (1–2 commands max per pass)
- Sequential with explicit dependencies
- Traceable to plan phases and spec requirements
- Read-only state extensions first; Core API wiring after; UI components last

---

## Phase 1 — State Management Extensions (Read-Only First)

**Plan Reference**: Phase 1 (lines 191-204)  
**Goal**: Add progress fields to `DetectionState` and `ImportState` without wiring to Core APIs yet  
**Dependencies**: None (Foundation)

### T-001: Add Progress Fields to DetectionState
**Priority**: P1  
**Summary**: Add progress fields to `DetectionState` class.

**Expected Files Touched**:
- `Sources/MediaHubUI/DetectionState.swift` (update)

**Steps**:
1. Add `@Published var progressStage: String? = nil` property
2. Add `@Published var progressCurrent: Int? = nil` property
3. Add `@Published var progressTotal: Int? = nil` property
4. Add `@Published var progressMessage: String? = nil` property
5. Add `var cancellationToken: CancellationToken? = nil` property (not `@Published`, stored reference)
6. Add `@Published var isCanceling: Bool = false` property
7. Ensure all properties are accessible on `@MainActor`

**Done When**:
- `DetectionState` compiles with new progress fields
- All properties are properly initialized (nil/false defaults)
- Existing state management continues to work

**Dependencies**: None

---

### T-002: Add Progress Fields to ImportState
**Priority**: P1  
**Summary**: Add progress fields to `ImportState` class.

**Expected Files Touched**:
- `Sources/MediaHubUI/ImportState.swift` (update)

**Steps**:
1. Add `@Published var progressStage: String? = nil` property
2. Add `@Published var progressCurrent: Int? = nil` property
3. Add `@Published var progressTotal: Int? = nil` property
4. Add `@Published var progressMessage: String? = nil` property
5. Add `var cancellationToken: CancellationToken? = nil` property (not `@Published`, stored reference)
6. Add `@Published var isCanceling: Bool = false` property
7. Ensure all properties are accessible on `@MainActor`

**Done When**:
- `ImportState` compiles with new progress fields
- All properties are properly initialized (nil/false defaults)
- Existing state management continues to work

**Dependencies**: None

---

## Phase 2 — DetectionOrchestrator Progress/Cancel Integration

**Plan Reference**: Phase 2 (lines 206-225)  
**Goal**: Wire Core progress callbacks and cancellation tokens to `DetectionState` in `DetectionOrchestrator.runDetection`  
**Dependencies**: Phase 1 (State Management Extensions)

### T-003: Create Cancellation Token in DetectionOrchestrator
**Priority**: P1  
**Summary**: Create `CancellationToken` when detection operation starts and store in `DetectionState`.

**Expected Files Touched**:
- `Sources/MediaHubUI/DetectionOrchestrator.swift` (update)

**Steps**:
1. In `runDetection` method, create `CancellationToken()` when operation starts (before Core API call)
2. Store cancellation token in `detectionState.cancellationToken` on MainActor
3. Clear cancellation token (`detectionState.cancellationToken = nil`) when operation completes (success or failure)

**Done When**:
- Cancellation token is created when detection starts
- Token is stored in `DetectionState`
- Token is cleared when operation completes

**Dependencies**: T-001

---

### T-004: Create Progress Callback in DetectionOrchestrator
**Priority**: P1  
**Summary**: Create progress callback that forwards Core progress updates to MainActor.

**Expected Files Touched**:
- `Sources/MediaHubUI/DetectionOrchestrator.swift` (update)

**Steps**:
1. In `runDetection` method, create progress callback closure
2. Callback receives `ProgressUpdate` from Core on background thread
3. Forward progress update to MainActor using `Task { @MainActor in ... }` or `await MainActor.run { ... }`
4. Update `detectionState.progressStage` on MainActor from `progressUpdate.stage`
5. Update `detectionState.progressCurrent` on MainActor from `progressUpdate.current`
6. Update `detectionState.progressTotal` on MainActor from `progressUpdate.total`
7. Update `detectionState.progressMessage` on MainActor from `progressUpdate.message`

**Done When**:
- Progress callback forwards updates to MainActor
- `DetectionState` progress fields are updated on MainActor
- Callback handles nil values gracefully

**Dependencies**: T-001, T-003

---

### T-005: Wire Progress and Cancel to Core Detection API
**Priority**: P1  
**Summary**: Pass progress callback and cancellation token to Core `DetectionOrchestrator.executeDetection`.

**Expected Files Touched**:
- `Sources/MediaHubUI/DetectionOrchestrator.swift` (update)

**Steps**:
1. In `runDetection` method, pass progress callback to Core `MediaHub.DetectionOrchestrator.executeDetection` as `progress:` parameter
2. Pass cancellation token to Core `MediaHub.DetectionOrchestrator.executeDetection` as `cancellationToken:` parameter
3. Verify Core API call compiles with new parameters

**Done When**:
- Progress callback is passed to Core API
- Cancellation token is passed to Core API
- Core API call compiles successfully

**Dependencies**: T-004

---

### T-006: Handle CancellationError in DetectionOrchestrator
**Priority**: P1  
**Summary**: Catch `CancellationError` and update `DetectionState.isCanceling` on MainActor.

**Expected Files Touched**:
- `Sources/MediaHubUI/DetectionOrchestrator.swift` (update)

**Steps**:
1. In `runDetection` method, wrap Core API call in try/catch
2. Catch `CancellationError.cancelled` specifically
3. Update `detectionState.isCanceling = true` on MainActor when cancellation error is caught
4. Update `detectionState.errorMessage` on MainActor with user-facing "Operation canceled" message
5. Clear cancellation token (`detectionState.cancellationToken = nil`) after cancellation

**Done When**:
- `CancellationError` is caught and handled
- `DetectionState.isCanceling` is updated on MainActor
- User-facing error message is set
- Cancellation token is cleared

**Dependencies**: T-005

---

## Phase 3 — ImportOrchestrator Progress/Cancel Integration

**Plan Reference**: Phase 3 (lines 227-246)  
**Goal**: Wire Core progress callbacks and cancellation tokens to `ImportState` in `ImportOrchestrator.executeImport`  
**Dependencies**: Phase 2 (DetectionOrchestrator Integration)

### T-007: Create Cancellation Token in ImportOrchestrator
**Priority**: P1  
**Summary**: Create `CancellationToken` when import operation starts and store in `ImportState`.

**Expected Files Touched**:
- `Sources/MediaHubUI/ImportOrchestrator.swift` (update)

**Steps**:
1. In `executeImport` method, create `CancellationToken()` when operation starts (before Core API call)
2. Store cancellation token in `importState.cancellationToken` on MainActor
3. Clear cancellation token (`importState.cancellationToken = nil`) when operation completes (success or failure)

**Done When**:
- Cancellation token is created when import starts
- Token is stored in `ImportState`
- Token is cleared when operation completes

**Dependencies**: T-002

---

### T-008: Create Progress Callback in ImportOrchestrator
**Priority**: P1  
**Summary**: Create progress callback that forwards Core progress updates to MainActor.

**Expected Files Touched**:
- `Sources/MediaHubUI/ImportOrchestrator.swift` (update)

**Steps**:
1. In `executeImport` method, create progress callback closure
2. Callback receives `ProgressUpdate` from Core on background thread
3. Forward progress update to MainActor using `Task { @MainActor in ... }` or `await MainActor.run { ... }`
4. Update `importState.progressStage` on MainActor from `progressUpdate.stage`
5. Update `importState.progressCurrent` on MainActor from `progressUpdate.current`
6. Update `importState.progressTotal` on MainActor from `progressUpdate.total`
7. Update `importState.progressMessage` on MainActor from `progressUpdate.message`

**Done When**:
- Progress callback forwards updates to MainActor
- `ImportState` progress fields are updated on MainActor
- Callback handles nil values gracefully

**Dependencies**: T-002, T-007

---

### T-009: Wire Progress and Cancel to Core Import API
**Priority**: P1  
**Summary**: Pass progress callback and cancellation token to Core `ImportExecutor.executeImport`.

**Expected Files Touched**:
- `Sources/MediaHubUI/ImportOrchestrator.swift` (update)

**Steps**:
1. In `executeImport` method, pass progress callback to Core `ImportExecutor.executeImport` as `progress:` parameter
2. Pass cancellation token to Core `ImportExecutor.executeImport` as `cancellationToken:` parameter
3. Verify Core API call compiles with new parameters

**Done When**:
- Progress callback is passed to Core API
- Cancellation token is passed to Core API
- Core API call compiles successfully

**Dependencies**: T-008

---

### T-010: Handle CancellationError in ImportOrchestrator
**Priority**: P1  
**Summary**: Catch `CancellationError` and update `ImportState.isCanceling` on MainActor.

**Expected Files Touched**:
- `Sources/MediaHubUI/ImportOrchestrator.swift` (update)

**Steps**:
1. In `executeImport` method, wrap Core API call in try/catch
2. Catch `CancellationError.cancelled` specifically
3. Update `importState.isCanceling = true` on MainActor when cancellation error is caught
4. Update `importState.errorMessage` on MainActor with user-facing "Operation canceled" message
5. Clear cancellation token (`importState.cancellationToken = nil`) after cancellation

**Done When**:
- `CancellationError` is caught and handled
- `ImportState.isCanceling` is updated on MainActor
- User-facing error message is set
- Cancellation token is cleared

**Dependencies**: T-009

---

## Phase 4 — DetectionRunView Progress UI

**Plan Reference**: Phase 4 (lines 248-269)  
**Goal**: Add progress bars, step indicators, and cancel buttons to `DetectionRunView`  
**Dependencies**: Phase 2 (DetectionOrchestrator Integration)

### T-011: Add Progress Bar to DetectionRunView
**Priority**: P1  
**Summary**: Add progress bar showing current/total counts during detection.

**Expected Files Touched**:
- `Sources/MediaHubUI/DetectionRunView.swift` (update)

**Steps**:
1. Add `ProgressView` component to `DetectionRunView` body
2. Wire progress bar to `detectionState.progressCurrent` and `detectionState.progressTotal`
3. Calculate progress value: `Double(detectionState.progressCurrent ?? 0) / Double(detectionState.progressTotal ?? 1)`
4. Handle nil values gracefully (show indeterminate progress when nil)
5. Display progress bar only when detection is in progress

**Done When**:
- Progress bar is visible in `DetectionRunView`
- Progress bar updates when `detectionState.progressCurrent` and `detectionState.progressTotal` change
- Progress bar handles nil values gracefully

**Dependencies**: T-001, T-004

---

### T-012: Add Step Indicator to DetectionRunView
**Priority**: P1  
**Summary**: Add step indicator showing current stage ("scanning", "comparing").

**Expected Files Touched**:
- `Sources/MediaHubUI/DetectionRunView.swift` (update)

**Steps**:
1. Add `Text` component showing current stage to `DetectionRunView` body
2. Wire step indicator to `detectionState.progressStage`
3. Display stage name (e.g., "Scanning...", "Comparing...") or "Complete" when stage is nil
4. Display step indicator only when detection is in progress

**Done When**:
- Step indicator is visible in `DetectionRunView`
- Step indicator updates when `detectionState.progressStage` changes
- Step indicator shows appropriate stage names

**Dependencies**: T-001, T-004

---

### T-013: Add Cancel Button to DetectionRunView
**Priority**: P1  
**Summary**: Add cancel button that is enabled during operation.

**Expected Files Touched**:
- `Sources/MediaHubUI/DetectionRunView.swift` (update)

**Steps**:
1. Add `Button("Cancel")` component to `DetectionRunView` body
2. Wire cancel button to call `detectionState.cancellationToken?.cancel()` when clicked
3. Enable cancel button when `detectionState.cancellationToken != nil` and operation is in progress
4. Disable cancel button when `detectionState.cancellationToken == nil` or operation is complete
5. Show "Canceling..." text when `detectionState.isCanceling` is true

**Done When**:
- Cancel button is visible in `DetectionRunView`
- Cancel button calls cancellation token when clicked
- Cancel button is enabled/disabled appropriately
- "Canceling..." feedback is shown during cancellation

**Dependencies**: T-001, T-003

---

### T-014: Add Error Message Display to DetectionRunView
**Priority**: P1  
**Summary**: Display error message when operation fails or is canceled.

**Expected Files Touched**:
- `Sources/MediaHubUI/DetectionRunView.swift` (update)

**Steps**:
1. Add error message display to `DetectionRunView` body (if not already present)
2. Display `detectionState.errorMessage` when non-nil
3. Style error message appropriately (red text, clear visibility)
4. Clear error message when new operation starts

**Done When**:
- Error messages are displayed when operations fail or are canceled
- Error messages are user-facing and clear
- Error messages are cleared appropriately

**Dependencies**: T-001, T-006

---

## Phase 5 — ImportExecutionView Progress UI

**Plan Reference**: Phase 5 (lines 271-289)  
**Goal**: Add progress bars and cancel buttons to `ImportExecutionView`  
**Dependencies**: Phase 3 (ImportOrchestrator Integration)

### T-015: Add Progress Bar to ImportExecutionView
**Priority**: P1  
**Summary**: Add progress bar showing current/total counts during import.

**Expected Files Touched**:
- `Sources/MediaHubUI/ImportExecutionView.swift` (update)

**Steps**:
1. Add `ProgressView` component to `ImportExecutionView` body
2. Wire progress bar to `importState.progressCurrent` and `importState.progressTotal`
3. Calculate progress value: `Double(importState.progressCurrent ?? 0) / Double(importState.progressTotal ?? 1)`
4. Handle nil values gracefully (show indeterminate progress when nil)
5. Display progress bar only when import is in progress

**Done When**:
- Progress bar is visible in `ImportExecutionView`
- Progress bar updates when `importState.progressCurrent` and `importState.progressTotal` change
- Progress bar handles nil values gracefully

**Dependencies**: T-002, T-008

---

### T-016: Add Cancel Button to ImportExecutionView
**Priority**: P1  
**Summary**: Add cancel button that is enabled during operation.

**Expected Files Touched**:
- `Sources/MediaHubUI/ImportExecutionView.swift` (update)

**Steps**:
1. Add `Button("Cancel")` component to `ImportExecutionView` body
2. Wire cancel button to call `importState.cancellationToken?.cancel()` when clicked
3. Enable cancel button when `importState.cancellationToken != nil` and operation is in progress
4. Disable cancel button when `importState.cancellationToken == nil` or operation is complete
5. Show "Canceling..." text when `importState.isCanceling` is true

**Done When**:
- Cancel button is visible in `ImportExecutionView`
- Cancel button calls cancellation token when clicked
- Cancel button is enabled/disabled appropriately
- "Canceling..." feedback is shown during cancellation

**Dependencies**: T-002, T-007

---

### T-017: Add Error Message Display to ImportExecutionView
**Priority**: P1  
**Summary**: Display error message when operation fails or is canceled.

**Expected Files Touched**:
- `Sources/MediaHubUI/ImportExecutionView.swift` (update)

**Steps**:
1. Add error message display to `ImportExecutionView` body (if not already present)
2. Display `importState.errorMessage` when non-nil
3. Style error message appropriately (red text, clear visibility)
4. Clear error message when new operation starts

**Done When**:
- Error messages are displayed when operations fail or are canceled
- Error messages are user-facing and clear
- Error messages are cleared appropriately

**Dependencies**: T-002, T-010

---

## Phase 6 — Error Handling and Polish

**Plan Reference**: Phase 6 (lines 291-307)  
**Goal**: Ensure error handling is graceful and user-facing messages are clear  
**Dependencies**: Phases 4-5 (View Extensions)

### T-018: Verify CancellationError Handling
**Priority**: P1  
**Summary**: Verify `CancellationError` is caught and mapped to user-facing "Operation canceled" message.

**Expected Files Touched**:
- No code changes (manual verification only)

**Steps**:
1. Run detection operation and click cancel button
2. Verify `CancellationError` is caught in `DetectionOrchestrator`
3. Verify `DetectionState.isCanceling` is set to `true`
4. Verify "Operation canceled" message is displayed in `DetectionRunView`
5. Run import operation and click cancel button
6. Verify `CancellationError` is caught in `ImportOrchestrator`
7. Verify `ImportState.isCanceling` is set to `true`
8. Verify "Operation canceled" message is displayed in `ImportExecutionView`

**Done When**:
- Cancellation errors are caught and handled correctly
- User-facing "Operation canceled" messages are displayed
- Verification documented (no code commit required)

**Dependencies**: T-006, T-010, T-014, T-017

---

### T-019: Verify Progress UI Edge Cases
**Priority**: P1  
**Summary**: Verify progress UI handles nil values and edge cases gracefully.

**Expected Files Touched**:
- No code changes (manual verification only)

**Steps**:
1. Run detection operation and verify progress bar handles nil `progressCurrent`/`progressTotal` (shows indeterminate progress)
2. Run import operation and verify progress bar handles nil `progressCurrent`/`progressTotal` (shows indeterminate progress)
3. Verify cancel button is disabled when `cancellationToken` is nil
4. Verify cancel button is disabled when operation is complete
5. Verify progress updates are smooth (no flickering, respects Core throttling)

**Done When**:
- Progress UI handles edge cases gracefully
- Cancel button handles edge cases gracefully
- Progress updates are smooth
- Verification documented (no code commit required)

**Dependencies**: T-011, T-012, T-013, T-015, T-016

---

### T-020: Verify Backward Compatibility
**Priority**: P1  
**Summary**: Verify existing UI workflows continue to work without modification.

**Expected Files Touched**:
- No code changes (manual verification only)

**Steps**:
1. Run existing detection workflow (without progress/cancel UI changes)
2. Verify detection completes successfully
3. Run existing import workflow (without progress/cancel UI changes)
4. Verify import completes successfully
5. Verify no regressions in existing functionality

**Done When**:
- Existing workflows continue to work unchanged
- No regressions detected
- Verification documented (no code commit required)

**Dependencies**: All previous tasks

---

## Phase 9 — Optional / Post-Freeze

**Note**: Slice is complete without Phase 9. All P1 tasks (T-001 through T-020) are required for slice completion.

### T-021: Hash Maintenance Progress UI (Future)
**Priority**: P2  
**Summary**: Add progress/cancellation UI for hash maintenance operations (deferred to Slice 16).

**Expected Files Touched**:
- Deferred to Slice 16

**Steps**:
- Deferred to Slice 16

**Done When**:
- Deferred to Slice 16

**Dependencies**: Slice 16 (Hash Maintenance UI workflow)

**Note**: Hash maintenance UI workflow is deferred to Slice 16. This task is optional and not required for slice completion.
