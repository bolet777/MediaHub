# Implementation Tasks: UI Sources + Detect + Import (P1)

**Feature**: UI Sources + Detect + Import (P1)  
**Specification**: `specs/013-ui-sources-detect-import-p1/spec.md`  
**Plan**: `specs/013-ui-sources-detect-import-p1/plan.md`  
**Slice**: 13 - Source management (attach/detach with media types), detect preview/run, and import preview/confirm/run workflows  
**Created**: 2026-01-27

## Task Organization

Tasks are organized by phase and user story, following the implementation sequence defined in the plan. Each task is:
- Small and focused on a single deliverable (1–2 commands max per pass)
- Sequential with explicit dependencies
- Traceable to plan phases and spec requirements
- Read-only preview operations first; writes only after explicit user confirmation

---

## Phase 1 — Source List Display

**Plan Reference**: Phase 1 (lines 440-450)  
**Goal**: Display attached sources in UI  
**Dependencies**: None (Foundation)

### T-001: Create Source State Management
**Priority**: P1  
**Summary**: Create source state management class for source list and operations.

**Expected Files Touched**:
- `Sources/MediaHubUI/SourceState.swift` (new)

**Steps**:
1. Create `SourceState` class conforming to `ObservableObject` with `@MainActor`
2. Add `@Published` properties:
   - `sources: [Source] = []`
   - `isAttaching: Bool = false`
   - `isDetaching: Bool = false`
   - `errorMessage: String? = nil`
3. Add method `refreshSources()` (placeholder, will be implemented in T-002)

**Done When**:
- State class compiles
- All properties are `@Published` and accessible

**Dependencies**: None

---

### T-002: Implement Source List Loading
**Priority**: P1  
**Summary**: Implement source list loading from Core API.

**Expected Files Touched**:
- `Sources/MediaHubUI/SourceOrchestrator.swift` (new)

**Steps**:
1. Create `SourceOrchestrator` struct with static methods
2. Implement `loadSources(libraryRootURL:libraryId:) async throws -> [Source]`
3. Call `SourceAssociationManager.retrieveSources(for:libraryId:)` off MainActor using `Task.detached`
4. Return array of `Source` objects
5. Update `SourceState.refreshSources()` to call `SourceOrchestrator.loadSources` off MainActor
6. Update `SourceState.sources` on MainActor after loading completes

**Done When**:
- Source list loading works off MainActor
- Sources are loaded and stored in state
- Error handling is in place

**Dependencies**: T-001

---

### T-003: Create Source List View
**Priority**: P1  
**Summary**: Create SwiftUI view for displaying source list.

**Expected Files Touched**:
- `Sources/MediaHubUI/SourceListView.swift` (new)

**Steps**:
1. Create `SourceListView` struct conforming to `View`
2. Add `@StateObject private var state = SourceState()`
3. Implement list display using `List` or `ForEach` showing:
   - Source path
   - Media types (images, videos, both)
   - Last detection timestamp (or "Never" if nil)
4. Add empty state view when `state.sources.isEmpty`
5. Add "Attach Source" button
6. Add "Detach Source" action per source (button or context menu)

**Done When**:
- Source list view compiles
- Sources are displayed with correct information
- Empty state is shown when no sources
- Actions are visible (not yet functional)

**Dependencies**: T-001, T-002

---

## Phase 2 — Attach Source Interface

**Plan Reference**: Phase 2 (lines 452-463)  
**Goal**: UI for attaching sources with media type selection  
**Dependencies**: Phase 1 (source list display)

### T-004: Create Attach Source View Skeleton
**Priority**: P1  
**Summary**: Create basic attach source view structure with folder picker.

**Expected Files Touched**:
- `Sources/MediaHubUI/AttachSourceView.swift` (new)

**Steps**:
1. Create `AttachSourceView` struct conforming to `View`
2. Add parameters: `libraryRootURL: URL`, `libraryId: String`, `onComplete: () -> Void`
3. Add `@State private var selectedPath: String? = nil`
4. Add `@State private var selectedMediaTypes: SourceMediaTypes = .both`
5. Add `@State private var errorMessage: String? = nil`
6. Implement folder picker button using `NSOpenPanel`
7. Configure `NSOpenPanel` with `.canChooseDirectories = true`, `.canChooseFiles = false`
8. On folder selection, update `selectedPath`

**Done When**:
- Attach source view compiles
- Folder picker opens and allows directory selection
- Selected path is stored in state

**Dependencies**: T-003

---

### T-005: Implement Path Validation for Source Attachment
**Priority**: P1  
**Summary**: Create path validation logic for source attachment.

**Expected Files Touched**:
- `Sources/MediaHubUI/SourcePathValidator.swift` (new)

**Steps**:
1. Create `SourcePathValidator` struct with static validation methods
2. Implement `validateSourcePath(_ path: String, existingSources: [Source]) -> ValidationResult`
3. Validation checks:
   - Path exists and is accessible
   - Path is a directory
   - Read permissions available
   - Path is not already attached (check against `existingSources`)
4. Return `ValidationResult` enum with cases: `.valid`, `.invalid(String)` (error message)
5. Create user-facing error messages for each validation failure

**Done When**:
- Path validation works for source attachment
- All validation checks are implemented
- Clear error messages are returned for each failure case
- Duplicate source detection works correctly

**Dependencies**: T-004

---

### T-006: Implement Media Type Selection
**Priority**: P1  
**Summary**: Add media type selection UI (images, videos, both).

**Expected Files Touched**:
- `Sources/MediaHubUI/AttachSourceView.swift` (update)

**Steps**:
1. Add media type selection UI (segmented control or picker)
2. Options: "Images", "Videos", "Both"
3. Bind selection to `selectedMediaTypes` state
4. Map UI selection to `SourceMediaTypes` enum:
   - "Images" → `.images`
   - "Videos" → `.videos`
   - "Both" → `.both`
5. Default to "Both" (`.both`)

**Done When**:
- Media type selection UI is visible
- Selection is stored in state
- All three options work correctly

**Dependencies**: T-004

---

### T-007: Integrate Source Attachment Orchestration
**Priority**: P1  
**Summary**: Implement source attachment Core API call.

**Expected Files Touched**:
- `Sources/MediaHubUI/SourceOrchestrator.swift` (update)

**Steps**:
1. Implement `attachSource(path:mediaTypes:libraryRootURL:libraryId:) async throws -> Source`
2. Create `Source` object with:
   - `sourceId: UUID().uuidString`
   - `type: .folder`
   - `path: (path as NSString).standardizingPath`
   - `mediaTypes: mediaTypes` (optional, defaults to nil which means `.both`)
3. Call `SourceAssociationManager.attach(source:to:libraryId:)` off MainActor using `Task.detached`
4. Return created `Source` object
5. Handle `SourceAssociationError` and map to user-facing error messages

**Done When**:
- Source attachment works off MainActor
- Source object is created with correct media types
- Error handling is in place

**Dependencies**: T-005, T-006

---

### T-008: Wire Source Attachment to UI
**Priority**: P1  
**Summary**: Connect attach source view to orchestration and state.

**Expected Files Touched**:
- `Sources/MediaHubUI/AttachSourceView.swift` (update)
- `Sources/MediaHubUI/SourceState.swift` (update)

**Steps**:
1. Add `@Binding var sourceState: SourceState` parameter to `AttachSourceView`
2. On "Attach" button click:
   - Validate path using `SourcePathValidator`
   - If invalid: set `errorMessage`, return
   - If valid: set `sourceState.isAttaching = true`
   - Call `SourceOrchestrator.attachSource` off MainActor
   - On success: refresh source list, call `onComplete()`
   - On failure: set `errorMessage`, set `isAttaching = false`
3. Show progress indicator when `isAttaching` is true
4. Disable "Attach" button when `isAttaching` is true

**Done When**:
- Source attachment works from UI
- Progress indicator shows during attachment
- Source list refreshes after successful attachment
- Errors are displayed to user

**Dependencies**: T-007

---

## Phase 3 — Detach Source Interface

**Plan Reference**: Phase 3 (lines 465-472)  
**Goal**: UI for detaching sources with explicit confirmation  
**Dependencies**: Phase 1 (source list display)

### T-009: Create Detach Source Confirmation Dialog
**Priority**: P1  
**Summary**: Create confirmation dialog for source detachment.

**Expected Files Touched**:
- `Sources/MediaHubUI/DetachSourceView.swift` (new)

**Steps**:
1. Create `DetachSourceView` struct conforming to `View`
2. Add parameters: `source: Source`, `onConfirm: () -> Void`, `onCancel: () -> Void`
3. Display source information (path, media types)
4. Add "Detach" button (primary action)
5. Add "Cancel" button (secondary action)
6. Show clear message: "Are you sure you want to detach this source?"

**Done When**:
- Detach source dialog compiles
- Source information is displayed
- Confirm and cancel buttons are visible

**Dependencies**: T-003

---

### T-010: Implement Source Detachment Orchestration
**Priority**: P1  
**Summary**: Implement source detachment Core API call.

**Expected Files Touched**:
- `Sources/MediaHubUI/SourceOrchestrator.swift` (update)

**Steps**:
1. Implement `detachSource(sourceId:libraryRootURL:libraryId:) async throws`
2. Call `SourceAssociationManager.detach(sourceId:from:libraryId:)` off MainActor using `Task.detached`
3. Handle `SourceAssociationError` and map to user-facing error messages
4. Return void on success

**Done When**:
- Source detachment works off MainActor
- Error handling is in place

**Dependencies**: T-009

---

### T-011: Wire Source Detachment to UI
**Priority**: P1  
**Summary**: Connect detach source dialog to orchestration and state.

**Expected Files Touched**:
- `Sources/MediaHubUI/DetachSourceView.swift` (update)
- `Sources/MediaHubUI/SourceListView.swift` (update)

**Steps**:
1. Add `@Binding var sourceState: SourceState` parameter to `DetachSourceView`
2. On "Detach" button click:
   - Set `sourceState.isDetaching = true`
   - Call `SourceOrchestrator.detachSource` off MainActor
   - On success: refresh source list, call `onConfirm()`
   - On failure: show error message, set `isDetaching = false`
3. Show progress indicator when `isDetaching` is true
4. Disable "Detach" button when `isDetaching` is true
5. Integrate detach dialog with source list (present as sheet or alert)

**Done When**:
- Source detachment works from UI
- Progress indicator shows during detachment
- Source list refreshes after successful detachment
- Errors are displayed to user

**Dependencies**: T-010

---

## Phase 4 — Detection Preview

**Plan Reference**: Phase 4 (lines 474-485)  
**Goal**: UI for previewing detection results without updating metadata  
**Dependencies**: Phase 1 (source list display)

### T-012: Create Detection State Management
**Priority**: P1  
**Summary**: Create detection state management class.

**Expected Files Touched**:
- `Sources/MediaHubUI/DetectionState.swift` (new)

**Steps**:
1. Create `DetectionState` class conforming to `ObservableObject` with `@MainActor`
2. Add `@Published` properties:
   - `previewResult: DetectionResult? = nil`
   - `runResult: DetectionResult? = nil`
   - `isPreviewing: Bool = false`
   - `isRunning: Bool = false`
   - `errorMessage: String? = nil`

**Done When**:
- State class compiles
- All properties are `@Published` and accessible

**Dependencies**: None

---

### T-013: Implement Detection Preview Orchestration
**Priority**: P1  
**Summary**: Implement detection preview Core API call (accepts that metadata is updated).

**Expected Files Touched**:
- `Sources/MediaHubUI/DetectionOrchestrator.swift` (new)

**Steps**:
1. Create `DetectionOrchestrator` struct with static methods
2. Implement `previewDetection(source:libraryRootURL:libraryId:) async throws -> DetectionResult`
3. Call `DetectionOrchestrator.executeDetection(source:libraryRootURL:libraryId:)` off MainActor using `Task.detached`
4. Capture detection result (metadata is updated by Core API, which is acceptable for preview)
5. Return detection result
6. Handle errors and map to user-facing error messages

**Done When**:
- Detection preview works off MainActor
- Detection results are returned
- Error handling is in place
- Note: Metadata is updated (Core API constraint, acceptable for preview)

**Dependencies**: T-012

---

### T-014: Create Detection Preview View
**Priority**: P1  
**Summary**: Create SwiftUI view for displaying detection preview results.

**Expected Files Touched**:
- `Sources/MediaHubUI/DetectionPreviewView.swift` (new)

**Steps**:
1. Create `DetectionPreviewView` struct conforming to `View`
2. Add parameters: `detectionResult: DetectionResult`, `onRunDetection: () -> Void`
3. Display "Preview" badge/indicator prominently
4. Display note: "Preview has updated detection timestamp" (transparency)
5. Display detection statistics:
   - Total scanned items
   - New items count
   - Known items count
   - Duplicates count (if available)
6. Display new items list (lazy loading for large lists)
7. Add "Run Detection" button (will produce identical results)

**Done When**:
- Detection preview view compiles
- Detection results are displayed with statistics
- "Preview" indicator is visible
- Transparency note about metadata update is shown
- "Run Detection" button is enabled

**Dependencies**: T-013

---

### T-015: Wire Detection Preview to UI
**Priority**: P1  
**Summary**: Connect detection preview to source list and state.

**Expected Files Touched**:
- `Sources/MediaHubUI/SourceListView.swift` (update)
- `Sources/MediaHubUI/DetectionState.swift` (update)

**Steps**:
1. Add "Preview Detection" action to source list (button or context menu)
2. On "Preview Detection" click:
   - Set `detectionState.isPreviewing = true`
   - Call `DetectionOrchestrator.previewDetection` off MainActor
   - On success: update `detectionState.previewResult`, refresh source list (to show updated lastDetectedAt), set `isPreviewing = false`
   - On failure: set `errorMessage`, set `isPreviewing = false`
3. Present `DetectionPreviewView` as sheet when `previewResult` is not nil
4. Show progress indicator when `isPreviewing` is true

**Done When**:
- Detection preview works from UI
- Progress indicator shows during preview
- Preview results are displayed
- Source list shows updated lastDetectedAt (transparency)
- Errors are displayed to user

**Dependencies**: T-014

---

## Phase 5 — Detection Run

**Plan Reference**: Phase 5 (lines 487-497)  
**Goal**: UI for running detection and updating source metadata  
**Dependencies**: Phase 4 (detection preview)

### T-017: Implement Detection Run Orchestration
**Priority**: P1  
**Summary**: Implement detection run Core API call.

**Expected Files Touched**:
- `Sources/MediaHubUI/DetectionOrchestrator.swift` (update)

**Steps**:
1. Implement `runDetection(source:libraryRootURL:libraryId:) async throws -> DetectionResult`
2. Call `DetectionOrchestrator.executeDetection(source:libraryRootURL:libraryId:)` off MainActor using `Task.detached`
3. Return detection result (metadata is updated by Core API)
4. Handle errors and map to user-facing error messages

**Done When**:
- Detection run works off MainActor
- Detection results are returned
- Error handling is in place

**Dependencies**: T-014

---

### T-018: Create Detection Run View
**Priority**: P1  
**Summary**: Create SwiftUI view for displaying detection run results.

**Expected Files Touched**:
- `Sources/MediaHubUI/DetectionRunView.swift` (new)

**Steps**:
1. Create `DetectionRunView` struct conforming to `View`
2. Add parameters: `detectionResult: DetectionResult`
3. Display detection statistics (same as preview view)
4. Display new items list
5. Show success message
6. Add "Preview Import" button (if new items detected)

**Done When**:
- Detection run view compiles
- Detection results are displayed
- Success message is shown
- "Preview Import" button is visible when applicable

**Dependencies**: T-017

---

### T-019: Wire Detection Run to UI
**Priority**: P1  
**Summary**: Connect detection run to preview view and state.

**Expected Files Touched**:
- `Sources/MediaHubUI/DetectionPreviewView.swift` (update)
- `Sources/MediaHubUI/DetectionState.swift` (update)
- `Sources/MediaHubUI/SourceState.swift` (update)

**Steps**:
1. On "Run Detection" button click in `DetectionPreviewView`:
   - Set `detectionState.isRunning = true`
   - Call `DetectionOrchestrator.runDetection` off MainActor
   - On success: update `detectionState.runResult`, refresh source list, set `isRunning = false`
   - On failure: set `errorMessage`, set `isRunning = false`
2. Present `DetectionRunView` when `runResult` is not nil
3. Show progress indicator when `isRunning` is true
4. Refresh source list after successful detection run (to show updated lastDetectedAt)

**Done When**:
- Detection run works from UI
- Progress indicator shows during run
- Detection results are displayed
- Source list refreshes with updated metadata
- Errors are displayed to user

**Dependencies**: T-018

---

## Phase 6 — Import Preview

**Plan Reference**: Phase 6 (lines 499-509)  
**Goal**: UI for previewing import operations without copying files  
**Dependencies**: Phase 5 (detection run)

### T-020: Create Import State Management
**Priority**: P1  
**Summary**: Create import state management class.

**Expected Files Touched**:
- `Sources/MediaHubUI/ImportState.swift` (new)

**Steps**:
1. Create `ImportState` class conforming to `ObservableObject` with `@MainActor`
2. Add `@Published` properties:
   - `previewResult: ImportResult? = nil`
   - `executionResult: ImportResult? = nil`
   - `isPreviewing: Bool = false`
   - `isExecuting: Bool = false`
   - `errorMessage: String? = nil`

**Done When**:
- State class compiles
- All properties are `@Published` and accessible

**Dependencies**: None

---

### T-021: Implement Import Preview Orchestration
**Priority**: P1  
**Summary**: Implement import preview Core API call with dry-run.

**Expected Files Touched**:
- `Sources/MediaHubUI/ImportOrchestrator.swift` (new)

**Steps**:
1. Create `ImportOrchestrator` struct with static methods
2. Implement `previewImport(detectionResult:libraryRootURL:libraryId:) async throws -> ImportResult`
3. Get all candidate items from detection result (matching CLI `import --all` behavior)
4. Call `ImportExecutor.executeImport(detectionResult:selectedItems:libraryRootURL:libraryId:options:dryRun:)` with `dryRun: true` off MainActor using `Task.detached`
5. Return import result
6. Handle errors and map to user-facing error messages

**Done When**:
- Import preview works off MainActor
- Dry-run mode is used correctly
- Import results are returned
- Error handling is in place

**Dependencies**: T-020

---

### T-022: Create Import Preview View
**Priority**: P1  
**Summary**: Create SwiftUI view for displaying import preview results.

**Expected Files Touched**:
- `Sources/MediaHubUI/ImportPreviewView.swift` (new)

**Steps**:
1. Create `ImportPreviewView` struct conforming to `View`
2. Add parameters: `importResult: ImportResult`, `onConfirmImport: () -> Void`
3. Display "Preview" badge/indicator
4. Display import statistics:
   - Items to import count
   - Total size (if available)
   - Destination summary
5. Display import operations list (items to copy, destination paths) - lazy loading for large lists
6. Add "Confirm Import" button

**Done When**:
- Import preview view compiles
- Import results are displayed with statistics
- "Preview" indicator is visible
- "Confirm Import" button is enabled

**Dependencies**: T-021

---

### T-023: Wire Import Preview to UI
**Priority**: P1  
**Summary**: Connect import preview to detection results and state.

**Expected Files Touched**:
- `Sources/MediaHubUI/DetectionRunView.swift` (update)
- `Sources/MediaHubUI/ImportState.swift` (update)

**Steps**:
1. On "Preview Import" button click in `DetectionRunView`:
   - Set `importState.isPreviewing = true`
   - Call `ImportOrchestrator.previewImport` off MainActor
   - On success: update `importState.previewResult`, set `isPreviewing = false`
   - On failure: set `errorMessage`, set `isPreviewing = false`
2. Present `ImportPreviewView` as sheet when `previewResult` is not nil
3. Show progress indicator when `isPreviewing` is true

**Done When**:
- Import preview works from UI
- Progress indicator shows during preview
- Preview results are displayed
- Errors are displayed to user

**Dependencies**: T-022

---

## Phase 7 — Import Confirmation Dialog

**Plan Reference**: Phase 7 (lines 511-520)  
**Goal**: Explicit confirmation before import execution  
**Dependencies**: Phase 6 (import preview)

### T-024: Create Import Confirmation Dialog
**Priority**: P1  
**Summary**: Create confirmation dialog for import execution.

**Expected Files Touched**:
- `Sources/MediaHubUI/ImportConfirmationView.swift` (new)

**Steps**:
1. Create `ImportConfirmationView` struct conforming to `View`
2. Add parameters: `importResult: ImportResult`, `onConfirm: () -> Void`, `onCancel: () -> Void`
3. Display summary:
   - Item count
   - Total size (if available)
   - Destination summary
4. Add "Import" button (primary action)
5. Add "Cancel" button (secondary action)
6. Show clear message: "Are you sure you want to import these items?"

**Done When**:
- Import confirmation dialog compiles
- Summary information is displayed
- Confirm and cancel buttons are visible

**Dependencies**: T-022

---

### T-025: Wire Import Confirmation to UI
**Priority**: P1  
**Summary**: Connect import confirmation to preview view.

**Expected Files Touched**:
- `Sources/MediaHubUI/ImportPreviewView.swift` (update)

**Steps**:
1. On "Confirm Import" button click:
   - Present `ImportConfirmationView` as sheet or alert
2. On confirmation dialog "Import" click:
   - Call `onConfirmImport()` callback
3. On confirmation dialog "Cancel" click:
   - Dismiss dialog, no action

**Done When**:
- Import confirmation dialog is presented
- Confirmation and cancellation work correctly

**Dependencies**: T-024

---

## Phase 8 — Import Execution

**Plan Reference**: Phase 8 (lines 522-532)  
**Goal**: UI for executing import operations  
**Dependencies**: Phase 7 (import confirmation dialog)

### T-026: Implement Import Execution Orchestration
**Priority**: P1  
**Summary**: Implement import execution Core API call.

**Expected Files Touched**:
- `Sources/MediaHubUI/ImportOrchestrator.swift` (update)

**Steps**:
1. Implement `executeImport(detectionResult:libraryRootURL:libraryId:) async throws -> ImportResult`
2. Get all candidate items from detection result (matching CLI `import --all` behavior)
3. Call `ImportExecutor.executeImport(detectionResult:selectedItems:libraryRootURL:libraryId:options:dryRun:)` with `dryRun: false` off MainActor using `Task.detached`
4. Return import result
5. Handle errors and map to user-facing error messages

**Done When**:
- Import execution works off MainActor
- Files are copied correctly
- Import results are returned
- Error handling is in place

**Dependencies**: T-021

---

### T-027: Create Import Execution View
**Priority**: P1  
**Summary**: Create SwiftUI view for displaying import execution results.

**Expected Files Touched**:
- `Sources/MediaHubUI/ImportExecutionView.swift` (new)

**Steps**:
1. Create `ImportExecutionView` struct conforming to `View`
2. Add parameters: `importResult: ImportResult`
3. Display import statistics:
   - Successful imports count
   - Failed imports count
   - Collisions count (if any)
4. Display import results list (successful, failures, collisions) - lazy loading for large lists
5. Show success message
6. Add "Done" button to close view

**Done When**:
- Import execution view compiles
- Import results are displayed
- Success message is shown
- "Done" button is visible

**Dependencies**: T-026

---

### T-028: Wire Import Execution to UI
**Priority**: P1  
**Summary**: Connect import execution to confirmation dialog and state.

**Expected Files Touched**:
- `Sources/MediaHubUI/ImportConfirmationView.swift` (update)
- `Sources/MediaHubUI/ImportState.swift` (update)

**Steps**:
1. On "Import" button click in `ImportConfirmationView`:
   - Set `importState.isExecuting = true`
   - Call `ImportOrchestrator.executeImport` off MainActor
   - On success: update `importState.executionResult`, set `isExecuting = false`
   - On failure: set `errorMessage`, set `isExecuting = false`
2. Present `ImportExecutionView` when `executionResult` is not nil
3. Show progress indicator when `isExecuting` is true
4. Disable "Import" button when `isExecuting` is true

**Done When**:
- Import execution works from UI
- Progress indicator shows during execution
- Import results are displayed
- Errors are displayed to user

**Dependencies**: T-027

---


## Dependencies

### User Story Completion Order

1. **Phase 1 (Source List Display)**: Must complete before all source management workflows
2. **Phase 2 (Attach Source)**: Must complete before source attachment workflows
3. **Phase 3 (Detach Source)**: Can be implemented independently after Phase 1
4. **Phase 4 (Detection Preview)**: Must complete before detection run
5. **Phase 5 (Detection Run)**: Must complete before import workflows
6. **Phase 6 (Import Preview)**: Must complete before import execution
7. **Phase 7 (Import Confirmation)**: Must complete before import execution
8. **Phase 8 (Import Execution)**: Depends on all previous phases

### Parallel Execution Opportunities

- **T-002 and T-004**: Can be implemented in parallel (different components)
- **T-005 and T-006**: Can be implemented in parallel (different UI components)
- **T-012 and T-020**: Can be implemented in parallel (different state classes)
- **T-013 and T-021**: Can be implemented in parallel (different orchestrators)
- **T-015 and T-018**: Can be implemented in parallel (different views)
- **T-022 and T-027**: Can be implemented in parallel (different views)

## Implementation Strategy

### MVP Scope

**Minimum Viable Product**: Source List Display + Attach Source

**MVP Tasks**: T-001 through T-008

**MVP Deliverable**: Users can view attached sources and attach new sources through the UI.

### Incremental Delivery

1. **Increment 1**: MVP (Source List + Attach Source) - T-001 through T-008
2. **Increment 2**: Detach Source - T-009 through T-011
3. **Increment 3**: Detection Preview and Run - T-012 through T-019
4. **Increment 4**: Import Preview, Confirmation, and Execution - T-020 through T-028

## Summary

- **Total Tasks**: 28 (all P1)
- **Tasks per Phase**:
  - Phase 1 (Source List Display): 3 tasks
  - Phase 2 (Attach Source): 5 tasks
  - Phase 3 (Detach Source): 3 tasks
  - Phase 4 (Detection Preview): 4 tasks
  - Phase 5 (Detection Run): 3 tasks
  - Phase 6 (Import Preview): 4 tasks
  - Phase 7 (Import Confirmation): 2 tasks
  - Phase 8 (Import Execution): 3 tasks
- **Parallel Opportunities**: 6 pairs of tasks can be implemented in parallel
- **Independent Test Criteria**: Each phase has clear independent test criteria
- **Suggested MVP Scope**: Source List Display + Attach Source - 8 tasks (T-001 through T-008)
- **SAFE PASS Compliance**: All tasks fit in single SAFE PASS (1-2 commands max per task)

---

## Slice 13b — UI Integration & UX Polish (Post-Freeze)

**Status**: Optional / Post-Freeze  
**Note**: These tasks are moved from Slice 13 Phase 9. Slice 13 is complete without these tasks. MVP can be delivered with workflows accessible via separate views/sheets.

### T-029: Integrate Source Management with Library View
**Priority**: P2  
**Summary**: Add source management section to library view.

**Expected Files Touched**:
- `Sources/MediaHubUI/ContentView.swift` (update)

**Steps**:
1. Add source management section to library view (when library is open)
2. Display `SourceListView` in library view
3. Integrate source state with app state
4. Handle source list refresh after attachment/detachment

**Done When**:
- Source management section is visible in library view
- Source list displays correctly
- Source operations work from library view

**Dependencies**: T-003, T-008, T-011

---

### T-030: Integrate Detection Workflows with Source List
**Priority**: P2  
**Summary**: Add detection actions to source list.

**Expected Files Touched**:
- `Sources/MediaHubUI/SourceListView.swift` (update)

**Steps**:
1. Add "Preview Detection" action to each source in list
2. Add "Run Detection" action to each source in list (or show after preview)
3. Integrate detection state with source list
4. Present detection views as sheets when appropriate

**Done When**:
- Detection actions are visible in source list
- Detection workflows work from source list
- Detection views are presented correctly

**Dependencies**: T-015, T-019

---

### T-031: Integrate Import Workflows with Detection Results
**Priority**: P2  
**Summary**: Add import actions to detection results.

**Expected Files Touched**:
- `Sources/MediaHubUI/DetectionRunView.swift` (update)

**Steps**:
1. Add "Preview Import" action to detection run results
2. Integrate import state with detection state
3. Present import views as sheets when appropriate

**Done When**:
- Import actions are visible in detection results
- Import workflows work from detection results
- Import views are presented correctly

**Dependencies**: T-023, T-028
