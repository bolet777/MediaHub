# Feature Specification: UI Integration & UX Polish

**Feature Branch**: `013b-ui-integration-ux-polish`  
**Created**: 2026-01-27  
**Status**: Draft  
**Input**: User description: "Integrate source/detection/import workflows with library view and source list (optional UX polish)"

## Overview

This slice integrates the source management, detection, and import workflows (implemented in Slice 13) into the main library view and source list, providing a cohesive user experience. The workflows are already functional as separate views/sheets; this slice connects them to the primary library interface for easier access.

**Problem Statement**: Users can access source management, detection, and import workflows through separate views/sheets, but these workflows are not integrated into the main library view. Users must navigate through multiple interfaces to manage sources and perform detection/import operations. This slice integrates these workflows into the primary library interface for a more cohesive experience.

**Architecture Principle**: The desktop application is a UI orchestrator. All business logic remains in the Core layer (from Slice 13). This slice only adds UI integration and presentation logic, connecting existing workflows to the main library view. No new Core APIs or business logic are introduced.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Source Management in Library View (Priority: P2)

A user wants to view and manage sources directly from the library view without navigating to separate interfaces. They need the source list and source management actions (attach/detach) accessible from the main library interface.

**Why this priority**: This is a UX polish task that improves workflow cohesion. The functionality already exists (Slice 13); this makes it more accessible.

**Independent Test**: Can be fully tested by opening a library and verifying the source list is visible in the library view, and that attach/detach actions work from this integrated view.

**Acceptance Scenarios**:

1. **Given** a library is opened in the app, **When** the library view is displayed, **Then** the app shows a source management section with the source list
2. **Given** the source list is displayed in the library view, **When** the user views the list, **Then** the app shows all attached sources with their paths, media types, and last detection timestamps (matching Slice 13 behavior)
3. **Given** the source list is displayed in the library view, **When** the user clicks "Attach Source", **Then** the app opens the attach source interface (from Slice 13) as a sheet
4. **Given** the source list is displayed in the library view, **When** the user completes source attachment, **Then** the app refreshes the source list and shows the newly attached source
5. **Given** the source list is displayed in the library view, **When** the user clicks "Detach Source" for a source, **Then** the app opens the detach confirmation dialog (from Slice 13) and refreshes the list after detachment
6. **Given** the source list is displayed in the library view, **When** no sources are attached, **Then** the app shows an empty state with an "Attach Source" action

---

### User Story 2 - Detection Workflows from Source List (Priority: P2)

A user wants to run detection operations directly from the source list in the library view, without navigating to separate detection interfaces.

**Why this priority**: This is a UX polish task that improves workflow cohesion. Detection workflows already exist (Slice 13); this makes them more accessible from the source list.

**Independent Test**: Can be fully tested by opening a library, viewing the source list, and verifying that detection preview/run actions are available for each source.

**Acceptance Scenarios**:

1. **Given** the source list is displayed in the library view, **When** the user views a source, **Then** the app shows detection actions ("Preview Detection", "Run Detection") for that source
2. **Given** the user clicks "Preview Detection" for a source, **When** the preview runs, **Then** the app displays the detection preview view (from Slice 13) as a sheet
3. **Given** the user clicks "Run Detection" for a source, **When** detection runs, **Then** the app displays the detection run view (from Slice 13) as a sheet
4. **Given** detection completes successfully, **When** the detection view is dismissed, **Then** the app refreshes the source list to show updated lastDetectedAt timestamp
5. **Given** detection actions are available, **When** the user performs detection operations, **Then** the app shows progress indicators and handles errors (matching Slice 13 behavior)

---

### User Story 3 - Import Workflows from Detection Results (Priority: P2)

A user wants to proceed from detection results to import operations seamlessly, with import actions accessible from detection result views.

**Why this priority**: This is a UX polish task that improves workflow cohesion. Import workflows already exist (Slice 13); this ensures they are accessible from detection results.

**Independent Test**: Can be fully tested by running detection, viewing detection results, and verifying that import preview/confirm actions are available and work correctly.

**Acceptance Scenarios**:

1. **Given** detection results are displayed (from detection run), **When** the user views the results, **Then** the app shows import actions ("Preview Import") when new items are detected
2. **Given** the user clicks "Preview Import" from detection results, **When** the preview runs, **Then** the app displays the import preview view (from Slice 13) as a sheet
3. **Given** the user proceeds through import preview to confirmation, **When** the user confirms import, **Then** the app displays the import execution view (from Slice 13) and executes the import
4. **Given** import completes successfully, **When** the import view is dismissed, **Then** the app returns to the library view with updated status
5. **Given** import actions are available, **When** the user performs import operations, **Then** the app shows progress indicators and handles errors (matching Slice 13 behavior)

---

## Requirements *(mandatory)*

### Functional Requirements

#### Source Management Integration

- **FR-001**: The app MUST display `SourceListView` in the library detail view when a library is open
- **FR-002**: The app MUST integrate `SourceState` with the library view state management
- **FR-003**: The app MUST refresh the source list after source attachment/detachment operations
- **FR-004**: The app MUST present source management views (attach/detach) as sheets from the library view
- **FR-005**: The app MUST handle source list refresh when library is opened or when source operations complete

#### Detection Workflow Integration

- **FR-006**: The app MUST add detection actions ("Preview Detection", "Run Detection") to the source list in the library view
- **FR-007**: The app MUST integrate `DetectionState` with the source list state management
- **FR-008**: The app MUST present detection views (preview/run) as sheets from the source list
- **FR-009**: The app MUST refresh the source list after detection operations complete (to show updated lastDetectedAt)
- **FR-010**: The app MUST handle detection state transitions (preview → run → import) seamlessly

#### Import Workflow Integration

- **FR-011**: The app MUST add import actions ("Preview Import") to detection result views
- **FR-012**: The app MUST integrate `ImportState` with the detection state management
- **FR-013**: The app MUST present import views (preview/confirmation/execution) as sheets from detection results
- **FR-014**: The app MUST handle import state transitions (preview → confirmation → execution) seamlessly
- **FR-015**: The app MUST refresh library status after import operations complete

### Safety Rules

- **SR-001**: All source/detection/import operations MUST maintain the same safety guarantees as Slice 13 (preview operations, explicit confirmations, error handling)
- **SR-002**: The app MUST NOT introduce new filesystem mutations beyond what Slice 13 already provides
- **SR-003**: The app MUST handle state synchronization correctly (source list refresh, library status refresh)
- **SR-004**: The app MUST NOT allow duplicate operations (e.g., running detection twice simultaneously)
- **SR-005**: The app MUST display clear error messages for all error conditions (matching Slice 13 behavior)

### Determinism & Idempotence Rules

- **DR-001**: Source list display MUST match Slice 13 behavior (same source information, same ordering)
- **DR-002**: Detection workflows MUST produce identical results to Slice 13 (same Core API calls, same results)
- **DR-003**: Import workflows MUST produce identical results to Slice 13 (same Core API calls, same results)
- **DR-004**: State refresh operations MUST be idempotent (safe to refresh multiple times)

### Data/IO Boundaries

- **IO-001**: The app MUST read only the same files as Slice 13 (library metadata, source associations, detection results, import results)
- **IO-002**: The app MUST write only the same files as Slice 13 (source associations, detection results, import results, library media files)
- **IO-003**: The app MUST NOT modify source files (source files are read-only, matching Slice 13)
- **IO-004**: The app MUST NOT create, modify, or delete files outside library directories (matching Slice 13)

### Core API Integration Approach

- **API-001**: The app MUST use the same Core API calls as Slice 13 (no new Core APIs)
- **API-002**: The app MUST use existing orchestrators from Slice 13 (`SourceOrchestrator`, `DetectionOrchestrator`, `ImportOrchestrator`)
- **API-003**: The app MUST use existing state management from Slice 13 (`SourceState`, `DetectionState`, `ImportState`)
- **API-004**: The app MUST use existing views from Slice 13 (`SourceListView`, `AttachSourceView`, `DetachSourceView`, `DetectionPreviewView`, `DetectionRunView`, `ImportPreviewView`, `ImportConfirmationView`, `ImportExecutionView`)
- **API-005**: The app MUST NOT introduce new Core APIs, CLI commands, or data models
- **API-006**: The app MUST handle Core API calls off MainActor (matching Slice 13 behavior)
- **API-007**: The app MUST update UI state on MainActor after Core API calls complete (matching Slice 13 behavior)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The app displays the source list in the library view within 1 second of opening a library
- **SC-002**: The app refreshes the source list within 1 second after source attachment/detachment operations
- **SC-003**: The app presents detection workflows from the source list within 1 second of user action
- **SC-004**: The app presents import workflows from detection results within 1 second of user action
- **SC-005**: The app maintains state synchronization correctly (source list, library status) after all operations
- **SC-006**: The app handles all error conditions with clear error messages (matching Slice 13 behavior)
- **SC-007**: The app maintains deterministic behavior across multiple operations (same library state produces same UI state)

## Non-Goals

- **No new functionality**: This slice does not add new source/detection/import features beyond what Slice 13 provides
- **No Core API changes**: This slice does not introduce new Core APIs or modify existing Core APIs
- **No new views**: This slice does not create new views beyond integrating existing views from Slice 13
- **No performance optimizations**: This slice does not optimize Core API performance or UI rendering
- **No workflow changes**: This slice does not modify the source/detection/import workflows themselves, only their integration
- **No new state management**: This slice uses existing state management from Slice 13, only integrates it with library view state

## Dependencies

- **Slice 13** (UI Sources + Detect + Import P1): All source/detection/import workflows, views, orchestrators, and state management
- **Slice 11** (UI Shell v1 + Library Discovery): App shell, library opening, ContentView structure
- **Slice 12** (UI Create / Adopt Wizard v1): Wizard patterns, sheet presentation patterns

## Backward Compatibility

- **BC-001**: The app MUST work with libraries created/adopted by slices 1–13 (backward compatibility)
- **BC-002**: The app MUST maintain compatibility with existing source/detection/import workflows from Slice 13
- **BC-003**: The app MUST handle libraries without sources (shows empty state, matching Slice 13 behavior)
- **BC-004**: The app MUST handle sources that have never been detected (shows "Never", matching Slice 13 behavior)

## Open Questions & Risks

### Open Questions

1. **Source list placement**: Should the source list be in a separate section, tab, or integrated into the status view? (Decision: Separate section in library detail view, below status view)
2. **Detection action placement**: Should detection actions be in the source list row, context menu, or separate buttons? (Decision: Context menu for each source, matching common macOS patterns)
3. **Import workflow navigation**: Should import workflows be accessible only from detection results, or also from a separate import section? (Decision: Only from detection results, maintaining workflow coherence)

### Risks

- **Risk 1**: State synchronization between source list and library view may cause UI inconsistencies
  - **Mitigation**: Use existing state management from Slice 13, refresh source list after operations
- **Risk 2**: Sheet presentation may cause navigation confusion if multiple sheets are open
  - **Mitigation**: Use single sheet presentation pattern, dismiss previous sheets before presenting new ones
- **Risk 3**: Integration may introduce performance issues if source list refresh is too frequent
  - **Mitigation**: Refresh only after operations complete, use existing state management caching

## Notes

- This slice is **optional/post-freeze** and focuses on UX polish only
- All functionality already exists in Slice 13; this slice only integrates it into the main library view
- No new Core APIs or business logic are introduced
- The slice can be skipped if UX polish is not a priority
- Slice 13 is complete without this slice; MVP can be delivered with workflows accessible via separate views/sheets
