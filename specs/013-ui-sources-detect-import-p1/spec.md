# Feature Specification: UI Sources + Detect + Import (P1)

**Feature Branch**: `013-ui-sources-detect-import-p1`  
**Created**: 2026-01-27  
**Status**: Draft  
**Input**: User description: "Source management (attach/detach with media types), detect preview/run, and import preview/confirm/run workflows"

## Overview

This slice adds UI workflows for source management (attach/detach with media types), detection operations (preview/run), and import operations (preview/confirm/run). The UI orchestrates existing Core APIs (`SourceAssociation`, `DetectionOrchestrator`, `ImportExecutor`) to provide user-friendly workflows that match the safety guarantees of the CLI commands.

**Problem Statement**: Users need visual interfaces to manage sources, preview detection results, and execute imports through the desktop app. The desktop app must provide safe, guided workflows that preview operations before execution and require explicit confirmation, matching the CLI's dry-run and confirmation behavior.

**Architecture Principle**: The desktop application is a UI orchestrator. All business logic, data validation, and operations remain in the Core layer. The UI invokes Core APIs directly (e.g., `SourceAssociationManager.attach`, `DetectionOrchestrator.executeDetection`, `ImportExecutor.executeImport`) but never implements its own source management, detection, or import logic. The UI provides visual feedback, progress indicators, and confirmation dialogs, but all actual operations are performed by Core APIs.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Attach Source with Media Types (Priority: P1)

A user wants to attach a source folder to a library through the desktop app. They need a guided interface that lets them select a folder, choose media types (images, videos, or both), and confirm the attachment.

**Why this priority**: Source attachment is a foundational action that enables detection and import workflows. Without a UI interface, users must use the CLI, which is less accessible for non-technical users.

**Independent Test**: Can be fully tested by launching the attach source interface, selecting a folder, choosing media types, and confirming to attach the source. This delivers the core capability of attaching sources through the UI.

**Acceptance Scenarios**:

1. **Given** the user clicks "Attach Source" or similar action in the app, **When** the interface opens, **Then** the app displays a folder picker and media type selection (images, videos, both)
2. **Given** the user selects a folder path in the interface, **When** the path is valid and accessible, **Then** the app enables the attach button and shows a preview of what will be attached
3. **Given** the user selects a folder path that is already attached to the library, **When** the interface validates the path, **Then** the app displays a clear message indicating the source is already attached (idempotent behavior)
4. **Given** the user selects a folder path that doesn't exist or is not accessible, **When** the interface validates the path, **Then** the app displays a clear error message explaining the issue
5. **Given** the user selects media types (images, videos, or both) and confirms attachment, **When** the source is attached successfully, **Then** the app displays success feedback and updates the source list
6. **Given** the user confirms attachment, **When** the source attachment fails (e.g., permission error), **Then** the app displays a clear, user-facing error message explaining what went wrong
7. **Given** the user cancels the attach interface at any step, **When** cancellation occurs, **Then** no source is attached and no files are modified

---

### User Story 2 - Detach Source (Priority: P1)

A user wants to detach a source from a library through the desktop app. They need a simple interface that lets them select a source and confirm detachment.

**Why this priority**: Source detachment enables users to manage their source associations without using the CLI. This is a common maintenance operation.

**Independent Test**: Can be fully tested by selecting a source and confirming detachment, verifying the source is removed from the library. This delivers the core capability of detaching sources through the UI.

**Acceptance Scenarios**:

1. **Given** the user clicks "Detach Source" or similar action for a source, **When** the confirmation dialog opens, **Then** the app displays a clear message showing which source will be detached
2. **Given** the user views the detach confirmation dialog, **When** they click "Cancel" or close the dialog, **Then** the source remains attached and no changes are made
3. **Given** the user views the detach confirmation dialog, **When** they click "Confirm" or "Detach", **Then** the source is detached and removed from the source list
4. **Given** the user confirms detachment, **When** the source detachment fails (e.g., permission error), **Then** the app displays a clear, user-facing error message explaining what went wrong
5. **Given** a source is detached, **When** the source list is refreshed, **Then** the detached source no longer appears in the list

---

### User Story 3 - Detect Preview (Priority: P1)

A user wants to preview what new items would be detected from a source before running detection. The UI must support a preview mode that shows detection results without updating source metadata.

**Why this priority**: Preview enables users to explore detection results before committing. This matches the CLI's read-only detection behavior and provides transparency.

**Independent Test**: Can be fully tested by launching detection preview for a source and verifying the preview shows accurate detection results without updating source metadata. This delivers the core capability of safe preview.

**Acceptance Scenarios**:

1. **Given** the user clicks "Preview Detection" or similar action for a source, **When** the preview runs, **Then** the app displays detection results (new items, duplicates, etc.) without updating source metadata
2. **Given** the user views detection preview results, **When** the preview completes, **Then** the app shows a clear indication that this is a preview (e.g., "Preview" badge or "This is a preview" message)
3. **Given** the user views detection preview results, **When** the preview completes, **Then** the app enables the "Run Detection" button, allowing the user to proceed with actual detection
4. **Given** the user views detection preview results, **When** the preview fails (e.g., source inaccessible), **Then** the app displays a clear error message and disables the "Run Detection" button
5. **Given** detection preview runs, **When** the preview completes, **Then** the app shows detection statistics (new items count, duplicates count, etc.) matching CLI `detect` output

---

### User Story 4 - Run Detection (Priority: P1)

A user wants to run detection on a source to identify new items and update source metadata. The UI must support running detection after preview, or directly without preview.

**Why this priority**: Detection execution updates source metadata and enables import workflows. This is a core operation that must be accessible through the UI.

**Independent Test**: Can be fully tested by running detection for a source and verifying detection results are displayed and source metadata is updated. This delivers the core capability of detection execution.

**Acceptance Scenarios**:

1. **Given** the user clicks "Run Detection" or similar action for a source, **When** detection runs, **Then** the app shows a progress indicator and displays detection results when complete
2. **Given** the user runs detection, **When** detection completes successfully, **Then** the app displays detection results (new items, duplicates, etc.) and updates source metadata (lastDetectedAt timestamp)
3. **Given** the user runs detection, **When** detection fails (e.g., source inaccessible), **Then** the app displays a clear, user-facing error message explaining what went wrong
4. **Given** the user runs detection, **When** detection is in progress, **Then** the app shows a progress indicator and disables the "Run Detection" button to prevent duplicate operations
5. **Given** detection completes successfully, **When** the source list is refreshed, **Then** the app shows updated lastDetectedAt timestamp for the source

---

### User Story 5 - Import Preview (Priority: P1)

A user wants to preview what would be imported from a detection result before executing import. The UI must support a preview mode that shows import operations without copying files.

**Why this priority**: Preview enables users to explore import operations before committing. This matches the CLI's `--dry-run` flag behavior and provides transparency.

**Independent Test**: Can be fully tested by launching import preview for a detection result and verifying the preview shows accurate import operations without copying files. This delivers the core capability of safe import preview.

**Acceptance Scenarios**:

1. **Given** the user clicks "Preview Import" or similar action for a detection result, **When** the preview runs, **Then** the app displays import operations (items to copy, destination paths, collision handling) without copying files
2. **Given** the user views import preview results, **When** the preview completes, **Then** the app shows a clear indication that this is a preview (e.g., "Preview" badge or "This is a preview" message)
3. **Given** the user views import preview results, **When** the preview completes, **Then** the app enables the "Confirm Import" button, allowing the user to proceed with actual import
4. **Given** the user views import preview results, **When** the preview fails (e.g., invalid detection result), **Then** the app displays a clear error message and disables the "Confirm Import" button
5. **Given** import preview runs, **When** the preview completes, **Then** the app shows import statistics (items to import, total size, etc.) matching CLI `import --dry-run` output

---

### User Story 6 - Confirm and Run Import (Priority: P1)

A user wants to confirm and execute import operations after preview. The UI must display explicit confirmation dialogs that show what will be imported and require explicit user action to proceed.

**Why this priority**: Explicit confirmation prevents accidental imports and gives users a final checkpoint before file operations. This aligns with Constitution principle 3.3 "Safe Operations" and matches CLI confirmation behavior.

**Independent Test**: Can be fully tested by proceeding through import preview and verifying confirmation dialogs appear with accurate information and require explicit user action. This delivers the core capability of safe import execution.

**Acceptance Scenarios**:

1. **Given** the user proceeds through import preview to the confirmation step, **When** the confirmation dialog is displayed, **Then** the app shows a clear summary of what will be imported (item count, total size, destination summary)
2. **Given** the user views the import confirmation dialog, **When** they click "Cancel" or close the dialog, **Then** the import is cancelled and no files are copied
3. **Given** the user views the import confirmation dialog, **When** they click "Confirm" or "Import", **Then** the import proceeds with actual file operations
4. **Given** the user confirms import, **When** the import is in progress, **Then** the app shows a progress indicator and disables the confirmation button to prevent duplicate operations
5. **Given** the user confirms import, **When** the import completes successfully, **Then** the app displays success feedback and updates library status
6. **Given** the user confirms import, **When** the import fails (e.g., permission error, disk full), **Then** the app displays a clear, user-facing error message explaining what went wrong

---

### User Story 7 - Source List Display (Priority: P1)

A user wants to view all sources attached to a library, including their media types and last detection status. The UI must display source information in a clear, organized list.

**Why this priority**: Source list display enables users to understand their library's source configuration and status. This is foundational for source management workflows.

**Independent Test**: Can be fully tested by opening a library and verifying the source list displays all attached sources with correct information. This delivers the core capability of source visibility.

**Acceptance Scenarios**:

1. **Given** a library is opened with attached sources, **When** the source list is displayed, **Then** the app shows all attached sources with their paths, media types, and last detection timestamps
2. **Given** a library is opened with no attached sources, **When** the source list is displayed, **Then** the app shows an empty state or appropriate message
3. **Given** a library is opened, **When** the source list is displayed, **Then** the displayed information matches the output of `mediahub source list --json` for the same library (when JSON output is used)
4. **Given** a source has never been detected, **When** the source list is displayed, **Then** the app shows "Never" or appropriate indicator for last detection timestamp
5. **Given** a source has media types configured, **When** the source list is displayed, **Then** the app shows the media types (images, videos, or both) clearly

---

## Requirements *(mandatory)*

### Functional Requirements

#### Source Management

- **FR-001**: The app MUST provide a UI interface for attaching sources to a library with folder picker and media type selection (images, videos, both)
- **FR-002**: The app MUST validate source paths before attachment (exists, accessible, not already attached)
- **FR-003**: The app MUST support media type selection during source attachment (images, videos, both)
- **FR-004**: The app MUST display attached sources in a list with path, media types, and last detection timestamp
- **FR-005**: The app MUST provide a UI interface for detaching sources from a library with explicit confirmation
- **FR-006**: The app MUST handle source attachment/detachment errors gracefully and display clear, user-facing error messages
- **FR-007**: The app MUST call Core API `SourceAssociationManager.attach(source:to:libraryId:)` for attachment operations
- **FR-008**: The app MUST call Core API `SourceAssociationManager.detach(sourceId:from:libraryId:)` for detachment operations
- **FR-009**: The app MUST display source information that matches CLI `mediahub source list --json` output (when JSON output is used)

#### Detection Operations

- **FR-010**: The app MUST provide a UI interface for previewing detection results (read-only, no source metadata updates)
- **FR-011**: The app MUST provide a UI interface for running detection (updates source metadata, lastDetectedAt timestamp)
- **FR-012**: The app MUST call Core API `DetectionOrchestrator.executeDetection` for detection operations
- **FR-013**: The app MUST display detection results (new items, duplicates, statistics) matching CLI `mediahub detect --json` output
- **FR-014**: The app MUST show progress indicators during detection operations
- **FR-015**: The app MUST handle detection errors gracefully and display clear, user-facing error messages
- **FR-016**: The app MUST distinguish between preview mode (read-only) and run mode (updates metadata) clearly in the UI

#### Import Operations

- **FR-017**: The app MUST provide a UI interface for previewing import operations (dry-run, no file copies)
- **FR-018**: The app MUST provide a UI interface for confirming and executing import operations (actual file copies)
- **FR-019**: The app MUST call Core API `ImportExecutor.executeImport` with `dryRun: true` for preview operations
- **FR-020**: The app MUST call Core API `ImportExecutor.executeImport` with `dryRun: false` for execution operations
- **FR-021**: The app MUST display explicit confirmation dialogs before import execution with summary of what will be imported
- **FR-022**: The app MUST display import results (successful imports, failures, collisions) matching CLI `mediahub import --json` output
- **FR-023**: The app MUST show progress indicators during import operations
- **FR-024**: The app MUST handle import errors gracefully and display clear, user-facing error messages
- **FR-025**: The app MUST distinguish between preview mode (dry-run) and execution mode (actual imports) clearly in the UI

### Safety Rules

- **SR-001**: Import preview MUST perform zero filesystem writes. Detection preview updates metadata (Core API constraint), but UI must show transparency note)
- **SR-002**: Detection preview SHOULD ideally not update source metadata, but Core API constraint means metadata will be updated. UI must show transparency note that preview updates metadata.
- **SR-003**: Import preview MUST NOT copy files or modify library contents
- **SR-004**: Import execution MUST require explicit user confirmation before proceeding
- **SR-005**: The app MUST handle permission errors gracefully without crashing or corrupting state
- **SR-006**: The app MUST validate all inputs (source paths, library state) before operations
- **SR-007**: The app MUST NOT allow duplicate operations (e.g., running detection twice simultaneously)
- **SR-008**: The app MUST display clear error messages for all error conditions (source inaccessible, library invalid, etc.)
- **SR-009**: The app MUST handle cancellation gracefully (user cancels operation, no partial state)

### Determinism & Idempotence Rules

- **DR-001**: Detection results MUST be deterministic (same source state produces same detection results)
- **DR-002**: Source list display MUST match CLI `mediahub source list` output semantically (same values, not exact JSON schema) for the same library state
- **DR-003**: Detection preview and run MUST produce identical detection results for the same source state (preview updates metadata but results are identical)
- **DR-004**: Import preview and execution MUST produce identical import plans for the same detection result (preview doesn't change state)
- **DR-005**: Error messages MUST be deterministic and reproducible for the same error conditions

### Data/IO Boundaries

- **IO-001**: The app MUST read only the following files during source management: library metadata (`.mediahub/library.json`), source associations (`.mediahub/registry/sources.json`)
- **IO-002**: The app MUST write only the following files during source attachment: source associations (`.mediahub/registry/sources.json`)
- **IO-003**: The app MUST write only the following files during source detachment: source associations (`.mediahub/registry/sources.json`)
- **IO-004**: The app MUST read only the following files during detection: source folder contents, library baseline index (`.mediahub/registry/index.json`), library contents
- **IO-005**: The app MUST write only the following files during detection preview/run: source associations (`.mediahub/registry/sources.json` to update lastDetectedAt), detection result files (`.mediahub/registry/detections/`)
- **IO-006**: The app MUST read only the following files during import preview: detection results, library baseline index
- **IO-007**: The app MUST write only the following files during import execution: library media files (copied from source), baseline index (`.mediahub/registry/index.json`), import results (`.mediahub/registry/imports.json`)
- **IO-008**: The app MUST NOT modify source files (source files are read-only)
- **IO-009**: The app MUST NOT create, modify, or delete files outside library directories

### Core API Integration Approach

- **API-001**: The app MUST call Core API `SourceAssociationManager.attach(source:to:libraryId:)` for source attachment (creates Source object with media types, then attaches)
- **API-002**: The app MUST call Core API `SourceAssociationManager.detach(sourceId:from:libraryId:)` for source detachment
- **API-003**: The app MUST call Core API `DetectionOrchestrator.executeDetection(source:libraryRootURL:libraryId:)` for detection operations (synchronous, throws)
- **API-004**: The app MUST call Core API `ImportExecutor.executeImport(detectionResult:selectedItems:libraryRootURL:libraryId:options:dryRun:)` for import operations (synchronous, throws)
- **API-005**: The app MUST handle Core API errors and map them to user-facing error messages
- **API-006**: The app MUST call Core APIs off MainActor (using `Task.detached` or equivalent) for long-running operations (detection, import)
- **API-007**: The app MUST update UI state on MainActor after Core API calls complete
- **API-009**: The app MUST create `Source` objects with media types (`SourceMediaTypes`) before calling `SourceAssociationManager.attach` (matching CLI behavior)
- **API-008**: The app MUST NOT introduce new Core APIs, CLI commands, or data models in this slice

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The app can attach a source to a library within 2 seconds of user confirmation (for valid source paths)
- **SC-002**: The app can detach a source from a library within 1 second of user confirmation
- **SC-003**: The app can display detection preview results within 10 seconds for sources containing up to 1000 items
- **SC-004**: The app can run detection and display results within 10 seconds for sources containing up to 1000 items
- **SC-005**: The app can display import preview results within 5 seconds for detection results containing up to 100 items
- **SC-006**: The app can execute import and display results within 30 seconds for imports containing up to 100 items (actual file copy time depends on file sizes)
- **SC-007**: The app displays source information that matches CLI `mediahub source list --json` output semantically (same values, not exact JSON schema) for the same library state
- **SC-008**: The app displays detection results that match CLI `mediahub detect --json` output semantically (same values, not exact JSON schema) for the same source state
- **SC-009**: The app displays import preview results that match CLI `mediahub import --dry-run --json` output semantically (same values, not exact JSON schema) for the same detection result
- **SC-010**: The app handles all error conditions (source inaccessible, library invalid, permission errors) with clear error messages in 100% of error cases
- **SC-011**: The app maintains deterministic behavior across multiple runs (same source state produces same detection/import results)

## Non-Goals

- **No source modification UI**: This slice does not provide UI for modifying media types of existing sources (users must detach and re-attach)
- **No batch operations**: This slice does not provide UI for attaching/detecting/importing multiple sources simultaneously
- **No import item selection UI**: This slice assumes import of all detected items (matching CLI `import --all` behavior); selective import is out of scope
- **No progress cancellation UI**: This slice does not provide UI for cancelling in-progress detection or import operations (cancellation support is planned for Slice 14)
- **No advanced collision handling UI**: This slice uses default collision policy (rename); advanced collision handling UI is out of scope
- **No import history UI**: This slice does not provide UI for viewing import history or past import results (planned for Slice 17)
- **No performance optimizations**: This slice does not optimize Core API performance; performance improvements are out of scope
- **No new Core APIs**: This slice uses existing Core APIs only; no new Core functionality is introduced

## Dependencies

- **Slice 2** (Sources & Import Detection): Source model, source association, detection orchestration
- **Slice 3** (Import Execution & Media Organization): Import execution, import results
- **Slice 10** (Source Media Types + Library Statistics): Media type filtering, source media types support
- **Slice 11** (UI Shell v1 + Library Discovery): App shell, library opening, status display
- **Slice 12** (UI Create / Adopt Wizard v1): Wizard patterns, confirmation dialogs, Core API orchestration

## Backward Compatibility

- **BC-001**: The app MUST work with libraries created/adopted by slices 1–12 (backward compatibility)
- **BC-002**: The app MUST handle sources without media types (defaults to "both" behavior, matching Slice 10)
- **BC-003**: The app MUST handle libraries without baseline index (detection falls back to full scan, matching Slice 7)
- **BC-004**: The app MUST handle sources that have never been detected (shows "Never" or appropriate indicator)

## Open Questions & Risks

### Open Questions

1. **Source modification workflow**: Should the UI allow modifying media types of existing sources, or require detach/re-attach? (Decision: Require detach/re-attach for P1, matches CLI behavior)
2. **Import item selection**: Should the UI allow selecting specific items to import, or always import all detected items? (Decision: Import all items for P1, matches CLI `import --all` behavior)
3. **Progress cancellation**: Should the UI support cancelling in-progress operations? (Decision: Out of scope for P1, planned for Slice 14)
4. **Error recovery**: How should the UI handle partial failures during import? (Decision: Display error summary, allow retry for failed items)

### Risks

- **Risk 1**: Long-running detection/import operations may block UI if not properly handled off MainActor
  - **Mitigation**: All Core API calls must be off MainActor, UI updates on MainActor
- **Risk 2**: Large detection/import results may cause UI performance issues
  - **Mitigation**: Use lazy loading, pagination, or virtual scrolling for large result lists
- **Risk 3**: Source attachment validation may be slow for large source folders
  - **Mitigation**: Validate path accessibility only, defer full scan to detection operation
- **Risk 4**: Import confirmation dialogs may be overwhelming for large imports
  - **Mitigation**: Show summary statistics, allow expanding detailed view

## Notes

- This slice focuses on P1 workflows only; advanced features (batch operations, item selection, cancellation) are deferred to future slices
- All Core API calls must be properly handled off MainActor to prevent UI blocking
- Error messages must be user-facing and actionable, not technical error codes
- Preview operations must be clearly distinguished from execution operations in the UI
- Confirmation dialogs must show accurate summaries of what will happen
- **Detection preview implementation note**: The Core API `DetectionOrchestrator.executeDetection` always updates source metadata (lastDetectedAt) and writes detection result files. For detection preview (SR-002: no metadata updates), the plan phase must determine how to implement preview. Since Core API does not support true read-only preview, the UI will call detection and accept that metadata is updated, but clearly indicate in the UI that this is a "preview" operation. The preview results are accurate and can be used to decide whether to run detection again (which will produce identical results). This is a pragmatic approach that maintains preview functionality while working within Core API constraints.
