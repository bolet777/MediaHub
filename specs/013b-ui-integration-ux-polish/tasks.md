# Implementation Tasks: UI Integration & UX Polish

**Feature**: UI Integration & UX Polish  
**Specification**: `specs/013b-ui-integration-ux-polish/spec.md`  
**Plan**: `specs/013b-ui-integration-ux-polish/plan.md`  
**Slice**: 13b - Integrate source/detection/import workflows with library view and source list (optional UX polish)  
**Created**: 2026-01-27

## Task Organization

Tasks are organized by phase, following the implementation sequence defined in the plan. Each task is:
- Small and focused on a single deliverable (1–2 commands max per pass)
- Sequential with explicit dependencies
- Traceable to plan phases and spec requirements
- UI integration only (no filesystem mutations, no new Core APIs)

---

## Phase 1 — Source List Integration

**Plan Reference**: Phase 1 (lines 200-210)  
**Goal**: Display source list in library detail view and integrate source state management  
**Dependencies**: Slice 13 (SourceListView, SourceState, SourceOrchestrator)

### T-001: Create SourceState Instance in ContentView
**Priority**: P2  
**Summary**: Create and manage SourceState instance when library is opened.

**Expected Files Touched**:
- `Sources/MediaHubUI/ContentView.swift` (update)

**Steps**:
1. Add `@StateObject private var sourceState = SourceState()` property to `ContentView`
2. Initialize `sourceState` when library is opened (in `task(id: appState.openedLibraryPath)`)
3. Pass `libraryRootURL` and `libraryId` to `sourceState` for source loading
4. Call `sourceState.refreshSources()` when library is opened

**Done When**:
- SourceState instance is created when library opens
- SourceState is initialized with library context
- Source list loading is triggered on library open

**Dependencies**: None (uses existing SourceState from Slice 13)

---

### T-002: Add Source List Section to Library Detail View
**Priority**: P2  
**Summary**: Display SourceListView in library detail view below StatusView.

**Expected Files Touched**:
- `Sources/MediaHubUI/ContentView.swift` (update)

**Steps**:
1. Add source list section to library detail view (in `detail:` closure)
2. Display section below `StatusView` when library is open
3. Add section header: "Sources" or "Attached Sources"
4. Display `SourceListView` in the section, passing `sourceState` and library context

**Done When**:
- Source list section is visible in library detail view
- SourceListView is displayed when library is open
- Section appears below StatusView

**Dependencies**: T-001

---

### T-003: Handle Source List Refresh After Operations
**Priority**: P2  
**Summary**: Refresh source list after source attachment/detachment operations complete.

**Expected Files Touched**:
- `Sources/MediaHubUI/ContentView.swift` (update)

**Steps**:
1. Observe `sourceState.sources` changes to trigger UI updates
2. Call `sourceState.refreshSources()` after source attachment completes (via sheet completion handler)
3. Call `sourceState.refreshSources()` after source detachment completes (via sheet completion handler)
4. Ensure refresh happens on MainActor (SourceState already handles this)

**Done When**:
- Source list refreshes after attachment operations
- Source list refreshes after detachment operations
- UI updates automatically when sources change

**Dependencies**: T-002

---

## Phase 2 — Source Management Actions Integration

**Plan Reference**: Phase 2 (lines 212-222)  
**Goal**: Integrate attach/detach actions into library view  
**Dependencies**: Phase 1, Slice 13 (AttachSourceView, DetachSourceView)

### T-004: Add Attach Source Action to SourceListView
**Priority**: P2  
**Summary**: Present AttachSourceView as sheet when "Attach Source" is clicked.

**Expected Files Touched**:
- `Sources/MediaHubUI/SourceListView.swift` (update)

**Steps**:
1. Add `@State private var showAttachSource = false` to `SourceListView`
2. Update "Attach Source" button to set `showAttachSource = true`
3. Add `.sheet(isPresented: $showAttachSource)` modifier
4. Present `AttachSourceView` in sheet, passing library context and `sourceState`
5. Add completion handler to refresh source list and dismiss sheet

**Done When**:
- "Attach Source" button opens AttachSourceView as sheet
- Sheet presents correctly with library context
- Sheet dismisses after successful attachment

**Dependencies**: T-003

---

### T-005: Add Detach Source Action to SourceListView
**Priority**: P2  
**Summary**: Present DetachSourceView as sheet when "Detach Source" is clicked.

**Expected Files Touched**:
- `Sources/MediaHubUI/SourceListView.swift` (update)

**Steps**:
1. Add `@State private var selectedSourceForDetach: Source? = nil` to `SourceListView`
2. Add `@State private var showDetachSource = false` to `SourceListView`
3. Update "Detach Source" action (context menu or button) to set `selectedSourceForDetach` and `showDetachSource = true`
4. Add `.sheet(isPresented: $showDetachSource)` modifier
5. Present `DetachSourceView` in sheet, passing selected source, library context, and `sourceState`
6. Add completion handler to refresh source list and dismiss sheet

**Done When**:
- "Detach Source" action opens DetachSourceView as sheet
- Sheet presents correctly with selected source
- Sheet dismisses after successful detachment

**Dependencies**: T-003

---

## Phase 3 — Detection Actions Integration

**Plan Reference**: Phase 3 (lines 224-234)  
**Goal**: Add detection actions to source list and integrate detection state  
**Dependencies**: Phase 1, Slice 13 (DetectionState, DetectionOrchestrator)

### T-006: Create DetectionState Instance in SourceListView
**Priority**: P2  
**Summary**: Create and manage DetectionState instance for detection operations.

**Expected Files Touched**:
- `Sources/MediaHubUI/SourceListView.swift` (update)

**Steps**:
1. Add `@StateObject private var detectionState = DetectionState()` property to `SourceListView`
2. Pass library context (`libraryRootURL`, `libraryId`) to detection state when needed
3. Ensure detection state is accessible to detection action handlers

**Done When**:
- DetectionState instance is created in SourceListView
- DetectionState is accessible for detection operations

**Dependencies**: T-003

---

### T-007: Add Detection Actions to Source List
**Priority**: P2  
**Summary**: Add "Preview Detection" and "Run Detection" actions to each source in list.

**Expected Files Touched**:
- `Sources/MediaHubUI/SourceListView.swift` (update)

**Steps**:
1. Add context menu to each source row in list (or add action buttons)
2. Add "Preview Detection" menu item/button
3. Add "Run Detection" menu item/button
4. Store selected source for detection operations (`@State private var selectedSourceForDetection: Source? = nil`)

**Done When**:
- Detection actions are visible in source list
- Actions are associated with correct source
- Actions can be triggered from source list

**Dependencies**: T-006

---

### T-008: Wire Detection Preview Action
**Priority**: P2  
**Summary**: Call DetectionOrchestrator and present DetectionPreviewView when "Preview Detection" is clicked.

**Expected Files Touched**:
- `Sources/MediaHubUI/SourceListView.swift` (update)

**Steps**:
1. Add handler for "Preview Detection" action
2. Set `detectionState.isPreviewing = true` and `selectedSourceForDetection`
3. Call `DetectionOrchestrator.previewDetection` off MainActor using `Task.detached`
4. On success: Update `detectionState.previewResult`, refresh `sourceState.sources`, set `isPreviewing = false`
5. On failure: Set `detectionState.errorMessage`, set `isPreviewing = false`
6. Present `DetectionPreviewView` as sheet when `detectionState.previewResult` is not nil

**Done When**:
- Detection preview works from source list
- DetectionPreviewView is presented as sheet
- Source list refreshes after preview (to show updated lastDetectedAt)

**Dependencies**: T-007

---

### T-009: Wire Detection Run Action
**Priority**: P2  
**Summary**: Call DetectionOrchestrator and present DetectionRunView when "Run Detection" is clicked.

**Expected Files Touched**:
- `Sources/MediaHubUI/SourceListView.swift` (update)

**Steps**:
1. Add handler for "Run Detection" action
2. Set `detectionState.isRunning = true` and `selectedSourceForDetection`
3. Call `DetectionOrchestrator.runDetection` off MainActor using `Task.detached`
4. On success: Update `detectionState.runResult`, refresh `sourceState.sources`, set `isRunning = false`
5. On failure: Set `detectionState.errorMessage`, set `isRunning = false`
6. Present `DetectionRunView` as sheet when `detectionState.runResult` is not nil

**Done When**:
- Detection run works from source list
- DetectionRunView is presented as sheet
- Source list refreshes after run (to show updated lastDetectedAt)

**Dependencies**: T-007

---

## Phase 4 — Import Actions Integration

**Plan Reference**: Phase 4 (lines 236-246)  
**Goal**: Add import actions to detection results and integrate import state  
**Dependencies**: Phase 3, Slice 13 (ImportState, ImportOrchestrator)

### T-010: Create ImportState Instance in DetectionRunView
**Priority**: P2  
**Summary**: Create and manage ImportState instance for import operations.

**Expected Files Touched**:
- `Sources/MediaHubUI/DetectionRunView.swift` (update)

**Steps**:
1. Add `@StateObject private var importState = ImportState()` property to `DetectionRunView`
2. Pass library context (`libraryRootURL`, `libraryId`) to import state when needed
3. Ensure import state is accessible to import action handlers

**Done When**:
- ImportState instance is created in DetectionRunView
- ImportState is accessible for import operations

**Dependencies**: T-009

---

### T-011: Wire Import Preview Action
**Priority**: P2  
**Summary**: Call ImportOrchestrator and present ImportPreviewView when "Preview Import" is clicked.

**Expected Files Touched**:
- `Sources/MediaHubUI/DetectionRunView.swift` (update)

**Steps**:
1. Ensure "Preview Import" button exists in DetectionRunView (may already exist from Slice 13)
2. Add handler for "Preview Import" action
3. Set `importState.isPreviewing = true`
4. Call `ImportOrchestrator.previewImport` off MainActor using `Task.detached`
5. On success: Update `importState.previewResult`, set `isPreviewing = false`
6. On failure: Set `importState.errorMessage`, set `isPreviewing = false`
7. Present `ImportPreviewView` as sheet when `importState.previewResult` is not nil

**Done When**:
- Import preview works from detection results
- ImportPreviewView is presented as sheet
- Error handling works correctly

**Dependencies**: T-010

---

### T-012: Wire Import Execution Workflow
**Priority**: P2  
**Summary**: Ensure import confirmation and execution workflows are accessible from detection results.

**Expected Files Touched**:
- `Sources/MediaHubUI/DetectionRunView.swift` (update)
- `Sources/MediaHubUI/ImportPreviewView.swift` (update, if needed)

**Steps**:
1. Verify import workflow (preview → confirmation → execution) is functional (may already exist from Slice 13)
2. Ensure ImportConfirmationView and ImportExecutionView are presented correctly
3. Add completion handler to refresh library status after import execution completes
4. Call `StatusViewModel.load` after successful import execution

**Done When**:
- Import workflow is accessible from detection results
- Import confirmation and execution work correctly
- Library status refreshes after import execution

**Dependencies**: T-011

---

## Dependencies

### Task Completion Order

1. **Phase 1 (Source List Integration)**: T-001 → T-002 → T-003
2. **Phase 2 (Source Management Actions)**: T-004, T-005 (can be parallel after T-003)
3. **Phase 3 (Detection Actions)**: T-006 → T-007 → T-008, T-009 (can be parallel after T-007)
4. **Phase 4 (Import Actions)**: T-010 → T-011 → T-012

### Parallel Execution Opportunities

- **T-004 and T-005**: Can be implemented in parallel (different actions, same view)
- **T-008 and T-009**: Can be implemented in parallel (different actions, same view)

## Implementation Strategy

### MVP Scope

**Minimum Viable Product**: Source List Integration (Phase 1)

**MVP Tasks**: T-001 through T-003

**MVP Deliverable**: Users can view source list in library view.

### Incremental Delivery

1. **Increment 1**: MVP (Source List Display) - T-001 through T-003
2. **Increment 2**: Source Management Actions - T-004, T-005
3. **Increment 3**: Detection Actions - T-006 through T-009
4. **Increment 4**: Import Actions - T-010 through T-012

## Summary

- **Total Tasks**: 12 (all P2, optional/post-freeze)
- **Tasks per Phase**:
  - Phase 1 (Source List Integration): 3 tasks
  - Phase 2 (Source Management Actions): 2 tasks
  - Phase 3 (Detection Actions): 4 tasks
  - Phase 4 (Import Actions): 3 tasks
- **Parallel Opportunities**: 2 pairs of tasks can be implemented in parallel
- **Independent Test Criteria**: Each phase has clear independent test criteria
- **Suggested MVP Scope**: Source List Display - 3 tasks (T-001 through T-003)
- **SAFE PASS Compliance**: All tasks fit in single SAFE PASS (1-2 commands max per task)

---

## Notes

- This slice is **optional/post-freeze** and focuses on UX polish only
- All functionality already exists in Slice 13; this slice only integrates it
- No new Core APIs or business logic are introduced
- The slice can be skipped if UX polish is not a priority
- Slice 13 is complete without this slice; MVP can be delivered with workflows accessible via separate views/sheets
