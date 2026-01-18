# Implementation Plan: UI Operations UX (progress / cancel)

**Feature**: UI Operations UX (progress / cancel)  
**Specification**: `specs/015-ui-operations-ux/spec.md`  
**Slice**: 15 - Progress bars, step indicators, and cancellation UI for detect/import/hash operations  
**Created**: 2026-01-17

## Plan Scope

This plan implements **Slice 15 only**, which adds UI components for progress reporting and cancellation to long-running operations (detection, import, hash maintenance). This includes:

- Progress state fields in `DetectionState` and `ImportState`
- Progress callback integration in `DetectionOrchestrator` and `ImportOrchestrator`
- Cancellation token integration in `DetectionOrchestrator` and `ImportOrchestrator`
- Progress bars and step indicators in `DetectionRunView`
- Progress bars and cancel buttons in `ImportExecutionView`
- Error handling for cancellation and operation failures

**Explicitly out of scope**:
- Core API changes (Core API from Slice 14 is consumed as-is)
- CLI progress changes (CLI continues to use `ProgressIndicator`)
- Hash maintenance UI workflow (deferred to Slice 16; only progress/cancellation UI components are in scope)
- Progress persistence across app restarts
- Batch progress reporting (e.g., "library 1 of 3")
- Time-based progress estimation (e.g., "5 minutes remaining")
- Progress animations or complex visual effects

## Goals / Non-Goals

### Goals
- Display progress bars and step indicators during detection operations
- Display progress bars during import operations
- Provide cancel buttons for detection and import operations
- Wire Core progress callbacks to SwiftUI progress indicators
- Wire cancel buttons to Core cancellation tokens
- Handle cancellation errors gracefully with user-facing messages
- Maintain backward compatibility (existing workflows continue to work)

### Non-Goals
- Implement new business logic (all logic remains in Core layer from Slice 14)
- Modify Core progress/cancellation API (Core API from Slice 14 is consumed as-is)
- Add hash maintenance UI workflow (deferred to Slice 16)
- Support progress persistence across app restarts
- Support batch progress reporting
- Support time-based progress estimation
- Add complex progress animations

## Proposed Architecture

### Module Structure

The implementation extends the existing `MediaHubUI` app target with progress/cancellation UI components. All components consume the Core progress/cancellation API from Slice 14.

**Targets**:
- `MediaHubUI` (macOS app target, existing from Slices 11-13)
  - Links against `MediaHub` framework (Core APIs from Slice 14)
  - Modified state management (`DetectionState`, `ImportState`) with progress fields
  - Modified orchestrators (`DetectionOrchestrator`, `ImportOrchestrator`) with progress/cancel integration
  - Modified views (`DetectionRunView`, `ImportExecutionView`) with progress UI components

**Boundaries**:
- **UI Layer**: SwiftUI views with progress bars, step indicators, cancel buttons
- **Orchestration Layer**: Thin wrappers that wire Core progress callbacks to UI state and cancel buttons to Core cancellation tokens
- **Core Layer**: Existing MediaHub framework (Slice 14 progress/cancellation API, frozen, no changes)
- **CLI Layer**: Not used by UI (UI uses Core APIs directly)

### Component Overview

#### State Management Extensions

1. **DetectionState Progress Fields** (`DetectionState.swift`)
   - Add `var progressStage: String?` - Current operation stage (e.g., "scanning", "comparing")
   - Add `var progressCurrent: Int?` - Current item count (optional)
   - Add `var progressTotal: Int?` - Total item count (optional)
   - Add `var progressMessage: String?` - Optional progress message
   - Add `var cancellationToken: CancellationToken?` - Cancellation token for current operation
   - Add `var isCanceling: Bool` - Whether cancellation is in progress
   - All properties are `@MainActor` and updated on MainActor

2. **ImportState Progress Fields** (`ImportState.swift`)
   - Add `var progressStage: String?` - Current operation stage (e.g., "importing")
   - Add `var progressCurrent: Int?` - Current item count (optional)
   - Add `var progressTotal: Int?` - Total item count (optional)
   - Add `var progressMessage: String?` - Optional progress message
   - Add `var cancellationToken: CancellationToken?` - Cancellation token for current operation
   - Add `var isCanceling: Bool` - Whether cancellation is in progress
   - All properties are `@MainActor` and updated on MainActor

#### Orchestrator Extensions

3. **DetectionOrchestrator Progress/Cancel Integration** (`DetectionOrchestrator.swift`)
   - Create `CancellationToken` internally when operation starts (no public signature change)
   - Store cancellation token in `DetectionState.cancellationToken`
   - Create progress callback internally that forwards Core progress updates to MainActor
   - Update `DetectionState` progress fields on MainActor when progress callbacks are received
   - Pass progress callback and cancellation token to Core `DetectionOrchestrator.executeDetection`
   - Handle `CancellationError` and update `DetectionState.isCanceling` on MainActor
   - Clear cancellation token when operation completes (success or failure)

4. **ImportOrchestrator Progress/Cancel Integration** (`ImportOrchestrator.swift`)
   - Create `CancellationToken` internally when operation starts (no public signature change)
   - Store cancellation token in `ImportState.cancellationToken`
   - Create progress callback internally that forwards Core progress updates to MainActor
   - Update `ImportState` progress fields on MainActor when progress callbacks are received
   - Pass progress callback and cancellation token to Core `ImportExecutor.executeImport`
   - Handle `CancellationError` and update `ImportState.isCanceling` on MainActor
   - Clear cancellation token when operation completes (success or failure)

#### View Extensions

5. **DetectionRunView Progress UI** (`DetectionRunView.swift`)
   - Add progress bar showing current/total counts during detection
   - Add step indicator showing current stage ("scanning", "comparing")
   - Add cancel button that is enabled during operation
   - Progress bar updates when `detectionState.progressCurrent` and `detectionState.progressTotal` change
   - Step indicator updates when `detectionState.progressStage` changes
   - Cancel button calls `detectionState.cancellationToken?.cancel()` when clicked
   - Cancel button shows "Canceling..." state when `detectionState.isCanceling` is true

6. **ImportExecutionView Progress UI** (`ImportExecutionView.swift`)
   - Add progress bar showing current/total counts during import
   - Add cancel button that is enabled during operation
   - Progress bar updates when `importState.progressCurrent` and `importState.progressTotal` change
   - Cancel button calls `importState.cancellationToken?.cancel()` when clicked
   - Cancel button shows "Canceling..." state when `importState.isCanceling` is true

### Data Flow

#### Detection Progress Flow
```
User starts detection operation
  ↓
DetectionOrchestrator.runDetection called
  ↓
Create CancellationToken, store in DetectionState
  ↓
Call Core DetectionOrchestrator.executeDetection with:
  - progress callback (forwards to MainActor, updates DetectionState)
  - cancellation token (wired to cancel button)
  ↓
Core invokes progress callback on background thread
  ↓
Orchestrator forwards progress update to MainActor
  ↓
DetectionState.progressStage/Current/Total updated on MainActor
  ↓
DetectionRunView observes state changes, updates progress bar and step indicator
  ↓
User clicks cancel button
  ↓
Cancel button calls DetectionState.cancellationToken?.cancel()
  ↓
Core checks cancellation token, throws CancellationError
  ↓
Orchestrator catches CancellationError, updates DetectionState.isCanceling
  ↓
DetectionRunView shows "Operation canceled" message
```

#### Import Progress Flow
```
User starts import operation
  ↓
ImportOrchestrator.executeImport called
  ↓
Create CancellationToken, store in ImportState
  ↓
Call Core ImportExecutor.executeImport with:
  - progress callback (forwards to MainActor, updates ImportState)
  - cancellation token (wired to cancel button)
  ↓
Core invokes progress callback on background thread
  ↓
Orchestrator forwards progress update to MainActor
  ↓
ImportState.progressCurrent/Total updated on MainActor
  ↓
ImportExecutionView observes state changes, updates progress bar
  ↓
User clicks cancel button
  ↓
Cancel button calls ImportState.cancellationToken?.cancel()
  ↓
Core checks cancellation token, throws CancellationError
  ↓
Orchestrator catches CancellationError, updates ImportState.isCanceling
  ↓
ImportExecutionView shows "Operation canceled" message
```

## Implementation Phases

### Phase 1: State Management Extensions (Read-Only First)

**Goal**: Add progress fields to `DetectionState` and `ImportState` without wiring to Core APIs yet.

**Steps**:
1. Add progress fields to `DetectionState` (`progressStage`, `progressCurrent`, `progressTotal`, `progressMessage`, `cancellationToken`, `isCanceling`)
2. Add progress fields to `ImportState` (`progressStage`, `progressCurrent`, `progressTotal`, `progressMessage`, `cancellationToken`, `isCanceling`)
3. Ensure all properties are `@MainActor` and properly initialized
4. Verify existing state management continues to work (backward compatibility)

**Validation**:
- `DetectionState` and `ImportState` compile with new progress fields
- Existing UI workflows continue to work without modification
- Progress fields are properly initialized (nil by default)

### Phase 2: DetectionOrchestrator Progress/Cancel Integration

**Goal**: Wire Core progress callbacks and cancellation tokens to `DetectionState` in `DetectionOrchestrator.runDetection`.

**Steps**:
1. In `DetectionOrchestrator.runDetection`, create `CancellationToken` internally when operation starts (no public signature change)
2. Store cancellation token in `DetectionState.cancellationToken`
3. Create progress callback internally that forwards Core progress updates to MainActor
4. Update `DetectionState` progress fields on MainActor when progress callbacks are received
5. Pass progress callback and cancellation token to Core `DetectionOrchestrator.executeDetection`
6. Handle `CancellationError` and update `DetectionState.isCanceling` on MainActor
7. Clear cancellation token when operation completes (success or failure)
8. Verify backward compatibility (existing callers continue to work unchanged)

**Validation**:
- Cancellation token is created internally and stored in `DetectionState`
- Progress callbacks are forwarded to MainActor and update `DetectionState`
- `CancellationError` is caught and handled gracefully
- Existing callers continue to work unchanged (no signature changes)

### Phase 3: ImportOrchestrator Progress/Cancel Integration

**Goal**: Wire Core progress callbacks and cancellation tokens to `ImportState` in `ImportOrchestrator.executeImport`.

**Steps**:
1. In `ImportOrchestrator.executeImport`, create `CancellationToken` internally when operation starts (no public signature change)
2. Store cancellation token in `ImportState.cancellationToken`
3. Create progress callback internally that forwards Core progress updates to MainActor
4. Update `ImportState` progress fields on MainActor when progress callbacks are received
5. Pass progress callback and cancellation token to Core `ImportExecutor.executeImport`
6. Handle `CancellationError` and update `ImportState.isCanceling` on MainActor
7. Clear cancellation token when operation completes (success or failure)
8. Verify backward compatibility (existing callers continue to work unchanged)

**Validation**:
- Cancellation token is created internally and stored in `ImportState`
- Progress callbacks are forwarded to MainActor and update `ImportState`
- `CancellationError` is caught and handled gracefully
- Existing callers continue to work unchanged (no signature changes)

### Phase 4: DetectionRunView Progress UI

**Goal**: Add progress bars, step indicators, and cancel buttons to `DetectionRunView`.

**Steps**:
1. Add progress bar (`ProgressView`) showing current/total counts during detection
2. Add step indicator (`Text`) showing current stage ("scanning", "comparing")
3. Add cancel button that is enabled during operation
4. Wire progress bar to `detectionState.progressCurrent` and `detectionState.progressTotal`
5. Wire step indicator to `detectionState.progressStage`
6. Wire cancel button to call `detectionState.cancellationToken?.cancel()` when clicked
7. Show "Canceling..." state when `detectionState.isCanceling` is true
8. Hide/disable cancel button when operation completes
9. Display error message when operation fails or is canceled

**Validation**:
- Progress bar updates during detection operations
- Step indicator shows current stage ("scanning", "comparing")
- Cancel button is enabled during operation and disabled when complete
- Cancel button stops operation when clicked
- "Canceling..." feedback is shown during cancellation
- Error messages are displayed when operations fail or are canceled

### Phase 5: ImportExecutionView Progress UI

**Goal**: Add progress bars and cancel buttons to `ImportExecutionView`.

**Steps**:
1. Add progress bar (`ProgressView`) showing current/total counts during import
2. Add cancel button that is enabled during operation
3. Wire progress bar to `importState.progressCurrent` and `importState.progressTotal`
4. Wire cancel button to call `importState.cancellationToken?.cancel()` when clicked
5. Show "Canceling..." state when `importState.isCanceling` is true
6. Hide/disable cancel button when operation completes
7. Display error message when operation fails or is canceled

**Validation**:
- Progress bar updates during import operations
- Cancel button is enabled during operation and disabled when complete
- Cancel button stops operation when clicked
- "Canceling..." feedback is shown during cancellation
- Error messages are displayed when operations fail or are canceled

### Phase 6: Error Handling and Polish

**Goal**: Ensure error handling is graceful and user-facing messages are clear.

**Steps**:
1. Verify `CancellationError` is caught and mapped to user-facing "Operation canceled" message
2. Verify other errors are mapped to user-facing messages using existing error mapping logic
3. Verify progress UI handles nil progress values gracefully (shows indeterminate progress)
4. Verify cancel button handles nil cancellation token gracefully (disabled)
5. Verify progress updates are smooth (no flickering, respects Core throttling)

**Validation**:
- Cancellation errors show "Operation canceled" message
- Other errors show user-facing, stable, and actionable messages
- Progress UI handles edge cases gracefully (nil values, no progress updates)
- Cancel button handles edge cases gracefully (nil token, operation complete)
- Progress updates are smooth (no flickering)

## Sequencing & Safety

### Read-Only First
- Phase 1 (State Management Extensions) is read-only: adds fields without wiring to Core APIs
- Phases 2-3 (Orchestrator Integration) wire Core APIs but don't modify Core behavior
- Phases 4-5 (View Extensions) add UI components that observe state changes

### Atomic Operations
- Progress updates are atomic (single MainActor update per progress callback)
- Cancellation token creation is atomic (created when operation starts)
- Cancellation token clearing is atomic (cleared when operation completes)

### Backward Compatibility
- All progress/cancel parameters are optional with `nil` defaults
- Existing UI workflows without progress/cancel continue to work unchanged
- New progress fields in state are optional and don't affect existing properties

### Error Handling
- All Core API calls are wrapped in try/catch
- `CancellationError` is caught and mapped to user-facing message
- Other errors are mapped using existing error mapping logic
- UI state is updated on MainActor for all error handling

## Dependencies

- **Slice 14**: Core progress/cancellation API (`ProgressUpdate`, `CancellationToken`, `CancellationError`) must be implemented and available
- **Slice 13**: UI detection and import workflows must be implemented (DetectionRunView, ImportExecutionView, orchestrators)

## Out of Scope

- Core API changes (Core API from Slice 14 is consumed as-is)
- CLI progress changes (CLI continues to use `ProgressIndicator`)
- Hash maintenance UI workflow (deferred to Slice 16; only progress/cancellation UI components are in scope)
- Progress persistence across app restarts
- Batch progress reporting (e.g., "library 1 of 3")
- Time-based progress estimation (e.g., "5 minutes remaining")
- Progress animations or complex visual effects
