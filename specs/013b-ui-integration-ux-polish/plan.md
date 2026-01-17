# Implementation Plan: UI Integration & UX Polish

**Feature**: UI Integration & UX Polish  
**Specification**: `specs/013b-ui-integration-ux-polish/spec.md`  
**Slice**: 13b - Integrate source/detection/import workflows with library view and source list (optional UX polish)  
**Created**: 2026-01-27

## Plan Scope

This plan implements **Slice 13b only**, which integrates the source management, detection, and import workflows (from Slice 13) into the main library view and source list. This includes:

- Displaying `SourceListView` in the library detail view when a library is open
- Integrating `SourceState`, `DetectionState`, and `ImportState` with library view state management
- Adding detection actions to the source list (context menu or buttons)
- Adding import actions to detection result views
- Refreshing source list and library status after operations complete
- Presenting existing views (from Slice 13) as sheets from the integrated locations

**Explicitly out of scope**:
- New source/detection/import functionality (all functionality exists in Slice 13)
- New Core APIs or business logic
- New views beyond integrating existing views
- Performance optimizations
- Workflow modifications (only integration, not workflow changes)

## Goals / Non-Goals

### Goals
- Integrate source list display into library detail view
- Integrate source management actions (attach/detach) into library view
- Integrate detection workflows (preview/run) into source list
- Integrate import workflows (preview/confirmation/execution) into detection results
- Maintain state synchronization (source list refresh, library status refresh)
- Preserve all safety guarantees from Slice 13

### Non-Goals
- Implement new business logic (all logic remains in Core layer from Slice 13)
- Create new views (only integrate existing views from Slice 13)
- Modify existing workflows (only connect them to library view)
- Optimize performance (performance work out of scope)
- Add new Core APIs (uses existing Core APIs from Slice 13)

## Proposed Architecture

### Module Structure

The implementation extends the existing `MediaHubUI` app target by integrating existing components from Slice 13 into `ContentView`. All components already exist; this slice only adds integration logic.

**Targets**:
- `MediaHubUI` (macOS app target, existing from Slices 11-13)
  - Uses existing views from Slice 13 (`SourceListView`, `AttachSourceView`, `DetachSourceView`, `DetectionPreviewView`, `DetectionRunView`, `ImportPreviewView`, `ImportConfirmationView`, `ImportExecutionView`)
  - Uses existing state management from Slice 13 (`SourceState`, `DetectionState`, `ImportState`)
  - Uses existing orchestrators from Slice 13 (`SourceOrchestrator`, `DetectionOrchestrator`, `ImportOrchestrator`)
  - Adds integration logic to `ContentView` to display source list and connect workflows

**Boundaries**:
- **UI Layer**: Integration logic in `ContentView`, existing views from Slice 13
- **State Management**: Existing state classes from Slice 13, integrated with `AppState`
- **Orchestration Layer**: Existing orchestrators from Slice 13 (no changes)
- **Core Layer**: Existing MediaHub framework (frozen, no changes)
- **CLI Layer**: Not used by UI (UI uses Core APIs directly)

### Component Overview

#### Integration Components

1. **ContentView Integration** (`ContentView.swift` - update)
   - Add source list section to library detail view
   - Integrate `SourceState` with library view state
   - Present source management views as sheets
   - Handle source list refresh after operations

2. **SourceListView Integration** (`SourceListView.swift` - update)
   - Add detection actions to source list (context menu or buttons)
   - Integrate `DetectionState` with source list
   - Present detection views as sheets
   - Refresh source list after detection operations

3. **DetectionRunView Integration** (`DetectionRunView.swift` - update)
   - Add import actions to detection results
   - Integrate `ImportState` with detection state
   - Present import views as sheets
   - Handle import workflow transitions

#### Existing Components (No Changes)

- All views from Slice 13: `AttachSourceView`, `DetachSourceView`, `DetectionPreviewView`, `DetectionRunView`, `ImportPreviewView`, `ImportConfirmationView`, `ImportExecutionView`
- All state management from Slice 13: `SourceState`, `DetectionState`, `ImportState`
- All orchestrators from Slice 13: `SourceOrchestrator`, `DetectionOrchestrator`, `ImportOrchestrator`

### Data Flow

#### Source List Display Flow
```
Library is opened in ContentView
  ↓
Load SourceState for library
  ↓
Display SourceListView in library detail view (below StatusView)
  ↓
SourceListView calls SourceOrchestrator.loadSources (existing from Slice 13)
  ↓
Source list displays with all attached sources
```

#### Source Management Integration Flow
```
User clicks "Attach Source" in SourceListView (in library view)
  ↓
Present AttachSourceView as sheet (existing from Slice 13)
  ↓
User completes attachment
  ↓
AttachSourceView calls SourceOrchestrator.attachSource (existing from Slice 13)
  ↓
On success: Refresh SourceState.sources, dismiss sheet
  ↓
SourceListView automatically updates (observes SourceState)
```

#### Detection Integration Flow
```
User clicks "Preview Detection" or "Run Detection" in SourceListView (context menu or button)
  ↓
Set DetectionState.isPreviewing or DetectionState.isRunning = true
  ↓
Call DetectionOrchestrator.previewDetection or DetectionOrchestrator.runDetection (existing from Slice 13)
  ↓
On success: Update DetectionState.previewResult or DetectionState.runResult
  ↓
Present DetectionPreviewView or DetectionRunView as sheet (existing from Slice 13)
  ↓
On completion: Refresh SourceState.sources (to show updated lastDetectedAt)
```

#### Import Integration Flow
```
User clicks "Preview Import" in DetectionRunView (existing from Slice 13)
  ↓
Set ImportState.isPreviewing = true
  ↓
Call ImportOrchestrator.previewImport (existing from Slice 13)
  ↓
On success: Update ImportState.previewResult
  ↓
Present ImportPreviewView as sheet (existing from Slice 13)
  ↓
User proceeds through import preview → confirmation → execution (existing workflow from Slice 13)
  ↓
On completion: Refresh library status (StatusViewModel.load)
```

## Implementation Phases

### Phase 1: Source List Integration

**Goal**: Display source list in library detail view and integrate source state management.

**Steps**:
1. Update `ContentView` to create and manage `SourceState` when library is opened
2. Add source list section to library detail view (below `StatusView`)
3. Display `SourceListView` in the source list section
4. Pass library context (`libraryRootURL`, `libraryId`) to `SourceListView`
5. Handle source list refresh when library is opened or when source operations complete

**Read-only steps**: None (all steps involve UI state management)

**Mutating steps**: None (only UI state changes, no filesystem mutations)

**Dependencies**: Slice 13 (SourceListView, SourceState, SourceOrchestrator)

---

### Phase 2: Source Management Actions Integration

**Goal**: Integrate attach/detach actions into library view.

**Steps**:
1. Update `SourceListView` to present `AttachSourceView` as sheet when "Attach Source" is clicked
2. Update `SourceListView` to present `DetachSourceView` as sheet when "Detach Source" is clicked
3. Handle sheet presentation state in `SourceListView` or `ContentView`
4. Refresh `SourceState.sources` after successful attachment/detachment
5. Dismiss sheets after operations complete

**Read-only steps**: None (all steps involve UI state management)

**Mutating steps**: None (only UI state changes, actual source operations handled by Slice 13)

**Dependencies**: Phase 1, Slice 13 (AttachSourceView, DetachSourceView, SourceOrchestrator)

---

### Phase 3: Detection Actions Integration

**Goal**: Add detection actions to source list and integrate detection state.

**Steps**:
1. Update `SourceListView` to create and manage `DetectionState` for detection operations
2. Add detection actions ("Preview Detection", "Run Detection") to source list (context menu or buttons)
3. On detection action click: Set detection state, call `DetectionOrchestrator` (existing from Slice 13)
4. Present `DetectionPreviewView` or `DetectionRunView` as sheet when detection completes
5. Refresh `SourceState.sources` after detection operations complete (to show updated lastDetectedAt)

**Read-only steps**: None (all steps involve UI state management)

**Mutating steps**: None (only UI state changes, actual detection operations handled by Slice 13)

**Dependencies**: Phase 1, Slice 13 (DetectionState, DetectionOrchestrator, DetectionPreviewView, DetectionRunView)

---

### Phase 4: Import Actions Integration

**Goal**: Add import actions to detection results and integrate import state.

**Steps**:
1. Update `DetectionRunView` to create and manage `ImportState` for import operations
2. Ensure "Preview Import" button is visible and functional (may already exist from Slice 13)
3. On import action click: Set import state, call `ImportOrchestrator` (existing from Slice 13)
4. Present import views (`ImportPreviewView`, `ImportConfirmationView`, `ImportExecutionView`) as sheets (existing from Slice 13)
5. Refresh library status (`StatusViewModel.load`) after import operations complete

**Read-only steps**: None (all steps involve UI state management)

**Mutating steps**: None (only UI state changes, actual import operations handled by Slice 13)

**Dependencies**: Phase 3, Slice 13 (ImportState, ImportOrchestrator, ImportPreviewView, ImportConfirmationView, ImportExecutionView)

---

## Core API Integration

**Approach**: Use existing Core API calls from Slice 13 (no new Core APIs).

All Core API integration already exists in Slice 13:
- `SourceOrchestrator` calls `SourceAssociationManager.attach`, `detach`, `retrieveSources`
- `DetectionOrchestrator` calls `DetectionOrchestrator.executeDetection`
- `ImportOrchestrator` calls `ImportExecutor.executeImport` with `dryRun: true/false`

This slice only uses these existing orchestrators; no new Core API calls are introduced.

**Async Handling**: All Core API calls are already handled off MainActor in Slice 13 orchestrators. This slice only needs to ensure UI state updates occur on MainActor (which is already handled by `@MainActor` on state classes).

## State Management

### SourceState Integration

- Create `SourceState` instance in `ContentView` when library is opened
- Pass `SourceState` to `SourceListView` as `@StateObject` or `@ObservedObject`
- Refresh `SourceState.sources` after source operations complete
- `SourceState` already handles async loading off MainActor (from Slice 13)

### DetectionState Integration

- Create `DetectionState` instance in `SourceListView` or `ContentView`
- Pass `DetectionState` to detection views as needed
- Update `DetectionState` after detection operations complete
- `DetectionState` already handles async operations off MainActor (from Slice 13)

### ImportState Integration

- Create `ImportState` instance in `DetectionRunView` or `ContentView`
- Pass `ImportState` to import views as needed
- Update `ImportState` after import operations complete
- `ImportState` already handles async operations off MainActor (from Slice 13)

## Error Handling

All error handling already exists in Slice 13:
- Orchestrators map Core API errors to user-facing messages
- State classes store error messages in `errorMessage` properties
- Views display error messages to users

This slice only needs to ensure error messages are displayed in the integrated views (which should already work since we're using existing views).

## Safety Guarantees

All safety guarantees from Slice 13 are preserved:
- Preview operations perform zero filesystem writes (import preview)
- Explicit confirmations before execution (import confirmation dialog)
- Error handling with clear messages
- State synchronization (source list refresh, library status refresh)

This slice does not introduce new safety concerns since it only integrates existing workflows.

## Testing Strategy

### Unit Testing
- Test `ContentView` integration logic (source state creation, sheet presentation)
- Test `SourceListView` integration (detection actions, state management)
- Test `DetectionRunView` integration (import actions, state management)

### Integration Testing
- Test source list display in library view
- Test source management workflows from library view
- Test detection workflows from source list
- Test import workflows from detection results
- Test state synchronization after operations

### Manual Testing
- Open library and verify source list displays
- Attach source from library view and verify list updates
- Run detection from source list and verify results
- Import from detection results and verify library status updates

## Dependencies

- **Slice 13** (UI Sources + Detect + Import P1): All views, state management, orchestrators
- **Slice 11** (UI Shell v1 + Library Discovery): `ContentView`, `AppState`, library opening
- **Slice 12** (UI Create / Adopt Wizard v1): Sheet presentation patterns

## Backward Compatibility

- Works with libraries created/adopted by slices 1–13
- Maintains compatibility with existing source/detection/import workflows from Slice 13
- Handles libraries without sources (empty state)
- Handles sources that have never been detected ("Never" indicator)

## Risks & Mitigations

### Risk 1: State Synchronization Issues
**Risk**: Source list and library status may become out of sync after operations.

**Mitigation**: 
- Refresh `SourceState.sources` after source operations
- Refresh `SourceState.sources` after detection operations (to show updated lastDetectedAt)
- Refresh library status (`StatusViewModel.load`) after import operations
- Use existing state management from Slice 13 which handles synchronization

### Risk 2: Sheet Presentation Conflicts
**Risk**: Multiple sheets may be presented simultaneously, causing navigation confusion.

**Mitigation**:
- Use single sheet presentation pattern (dismiss previous sheet before presenting new one)
- Track sheet presentation state in `ContentView` or individual views
- Follow existing patterns from Slice 12 (wizard sheet management)

### Risk 3: Performance Issues
**Risk**: Source list refresh may be too frequent, causing UI lag.

**Mitigation**:
- Refresh only after operations complete (not during operations)
- Use existing state management caching from Slice 13
- Defer refresh until operation completes successfully

## Notes

- This slice is **optional/post-freeze** and focuses on UX polish only
- All functionality already exists in Slice 13; this slice only integrates it
- No new Core APIs or business logic are introduced
- The slice can be skipped if UX polish is not a priority
- Slice 13 is complete without this slice; MVP can be delivered with workflows accessible via separate views/sheets
