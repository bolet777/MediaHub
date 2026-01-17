# Implementation Plan: UI Sources + Detect + Import (P1)

**Feature**: UI Sources + Detect + Import (P1)  
**Specification**: `specs/013-ui-sources-detect-import-p1/spec.md`  
**Slice**: 13 - Source management (attach/detach with media types), detect preview/run, and import preview/confirm/run workflows  
**Created**: 2026-01-27

## Plan Scope

This plan implements **Slice 13 only**, which adds UI workflows for source management, detection operations, and import operations. This includes:

- Source attachment UI with media type selection (images, videos, both)
- Source detachment UI with explicit confirmation
- Source list display with media types and last detection status
- Detection preview UI (best-effort preview; Core API constraint means metadata is updated, but UI shows transparency note)
- Detection run UI (updates source metadata)
- Import preview UI (dry-run, no file copies)
- Import confirmation and execution UI (actual file copies)

**Explicitly out of scope**:
- Source modification UI (modifying media types of existing sources - users must detach/re-attach)
- Batch operations (attaching/detecting/importing multiple sources simultaneously)
- Import item selection UI (always imports all detected items, matching CLI `import --all`)
- Progress cancellation UI (cancellation support planned for Slice 14)
- Advanced collision handling UI (uses default collision policy)
- Import history UI (planned for Slice 17)
- Performance optimizations (Core API performance improvements out of scope)
- New Core APIs (uses existing Core APIs only)

## Goals / Non-Goals

### Goals
- Provide UI interfaces for source management (attach/detach) with media type selection
- Enable detection preview and run workflows through the UI
- Enable import preview and execution workflows through the UI
- Maintain safety guarantees (preview operations perform zero writes, explicit confirmations)
- Maintain backward compatibility with existing Core APIs
- Integrate seamlessly with existing UI shell from Slices 11-12

### Non-Goals
- Implement new business logic (all logic remains in Core layer)
- Support source modification (detach/re-attach required for media type changes)
- Support batch operations (one source at a time for P1)
- Support import item selection (always imports all detected items)
- Support operation cancellation (planned for Slice 14)
- Optimize for very large operations beyond basic async handling

## Proposed Architecture

### Module Structure

The implementation extends the existing `MediaHubUI` app target with new source management, detection, and import components. All components link against the existing `MediaHub` framework (Core APIs).

**Targets**:
- `MediaHubUI` (macOS app target, existing from Slices 11-12)
  - Links against `MediaHub` framework (Core APIs)
  - New source management SwiftUI views and view models
  - New detection SwiftUI views and view models
  - New import SwiftUI views and view models
  - Core API orchestration for source/detection/import operations

**Boundaries**:
- **UI Layer**: SwiftUI views, view models, state management
- **Orchestration Layer**: Thin wrappers that invoke Core APIs (`SourceAssociationManager`, `DetectionOrchestrator`, `ImportExecutor`)
- **Core Layer**: Existing MediaHub framework (frozen, no changes)
- **CLI Layer**: Not used by UI (UI uses Core APIs directly)

### Component Overview

#### Source Management Components

1. **Source List View** (`SourceListView.swift`)
   - Displays all attached sources with path, media types, last detection timestamp
   - Empty state when no sources attached
   - Actions: "Attach Source", "Detach Source" (per source)

2. **Attach Source Interface** (`AttachSourceView.swift`)
   - Folder picker integration (`NSOpenPanel`)
   - Media type selection (images, videos, both)
   - Path validation
   - Preview of what will be attached
   - Confirmation and execution

3. **Detach Source Interface** (`DetachSourceView.swift`)
   - Confirmation dialog showing which source will be detached
   - Explicit confirm/cancel buttons
   - Execution and error handling

4. **Source State Management** (`SourceState.swift`)
   - Source list caching
   - Source attachment/detachment state
   - Error state management

#### Detection Components

5. **Detection Preview View** (`DetectionPreviewView.swift`)
   - Displays detection results (new items, duplicates, statistics)
   - "Preview" badge/indicator
   - Detection statistics display
   - "Run Detection" button

6. **Detection Run View** (`DetectionRunView.swift`)
   - Progress indicator during detection
   - Detection results display
   - Error handling

7. **Detection State Management** (`DetectionState.swift`)
   - Detection preview/run state
   - Detection results caching
   - Error state management

#### Import Components

8. **Import Preview View** (`ImportPreviewView.swift`)
   - Displays import operations (items to copy, destination paths)
   - "Preview" badge/indicator
   - Import statistics display
   - "Confirm Import" button

9. **Import Confirmation Dialog** (`ImportConfirmationView.swift`)
   - Summary of what will be imported (item count, total size)
   - Explicit confirm/cancel buttons
   - Safety messaging

10. **Import Execution View** (`ImportExecutionView.swift`)
    - Progress indicator during import
    - Import results display (successful, failures, collisions)
    - Error handling

11. **Import State Management** (`ImportState.swift`)
    - Import preview/execution state
    - Import results caching
    - Error state management

#### Core API Orchestration

12. **Source Orchestrator** (`SourceOrchestrator.swift`)
    - `SourceAssociationManager.attach` invocation
    - `SourceAssociationManager.detach` invocation
    - `SourceAssociationManager.retrieveSources` invocation
    - Async operation handling (off MainActor)
    - Error handling and user-facing error messages

13. **Detection Orchestrator** (`DetectionOrchestrator.swift`)
    - `DetectionOrchestrator.executeDetection` invocation
    - Detection preview implementation (see Detection Preview Implementation section)
    - Async operation handling (off MainActor)
    - Error handling and user-facing error messages

14. **Import Orchestrator** (`ImportOrchestrator.swift`)
    - `ImportExecutor.executeImport` with `dryRun: true` for preview
    - `ImportExecutor.executeImport` with `dryRun: false` for execution
    - Async operation handling (off MainActor)
    - Error handling and user-facing error messages

### Data Flow

#### Attach Source Flow
```
User clicks "Attach Source" action
  ↓
Present AttachSourceView sheet
  ↓
Step 1: Path Selection
  - User selects folder via NSOpenPanel
  - Validate path (exists, accessible, not already attached)
  - If invalid: show error, allow retry
  - If valid: proceed to media type selection
  ↓
Step 2: Media Type Selection
  - User selects media types (images, videos, both)
  - Show preview of what will be attached
  - Enable "Attach" button
  ↓
Step 3: Confirmation and Execution
  - Show summary of source to attach
  - If user confirms: invoke SourceAssociationManager.attach off MainActor
  - If successful: close sheet, refresh source list
  - If failed: show error message, allow retry
```

#### Detach Source Flow
```
User clicks "Detach Source" for a source
  ↓
Present DetachSourceView confirmation dialog
  ↓
Confirmation Dialog
  - Show which source will be detached
  - Show explicit "Detach" and "Cancel" buttons
  - If user cancels: close dialog, no changes
  - If user confirms: invoke SourceAssociationManager.detach off MainActor
  - If successful: close dialog, refresh source list
  - If failed: show error message
```

#### Detection Preview Flow
```
User clicks "Preview Detection" for a source
  ↓
Show progress indicator
  ↓
Invoke DetectionOrchestrator.executeDetection off MainActor
  ↓
Display detection results (new items, duplicates, statistics)
  ↓
Show "Preview" indicator and note that metadata was updated
  ↓
Update source list (show updated lastDetectedAt for transparency)
  ↓
Enable "Run Detection" button (will produce identical results)
```

#### Detection Run Flow
```
User clicks "Run Detection" for a source (after preview or directly)
  ↓
Show progress indicator
  ↓
Invoke DetectionOrchestrator.executeDetection off MainActor
  ↓
Display detection results (new items, duplicates, statistics)
  ↓
Update source list (show updated lastDetectedAt timestamp)
  ↓
Enable "Preview Import" button (if new items detected)
```

#### Import Preview Flow
```
User clicks "Preview Import" for a detection result
  ↓
Show progress indicator
  ↓
Invoke ImportExecutor.executeImport with dryRun: true off MainActor
  ↓
Display import operations (items to copy, destination paths)
  ↓
Show "Preview" indicator
  ↓
Enable "Confirm Import" button
```

#### Import Confirmation and Execution Flow
```
User clicks "Confirm Import" for import preview
  ↓
Present ImportConfirmationView dialog
  ↓
Confirmation Dialog
  - Show summary (item count, total size, destination summary)
  - Show explicit "Import" and "Cancel" buttons
  - If user cancels: close dialog, no files copied
  - If user confirms: proceed to execution
  ↓
Execution
  - Show progress indicator
  - Invoke ImportExecutor.executeImport with dryRun: false off MainActor
  - If successful: display import results, update library status
  - If failed: show error message, allow retry
```

## Core API Integration Decision

**Primary Approach: Core API Direct Invocation**

The UI will use Core APIs directly (`SourceAssociationManager`, `DetectionOrchestrator`, `ImportExecutor`) rather than invoking the CLI executable. This decision is justified by:

1. **Simplicity**: No process spawning, no JSON parsing, no CLI executable dependency
2. **Performance**: Direct function calls are faster than subprocess execution
3. **Error Handling**: Direct Swift error propagation vs. parsing CLI error output
4. **Code Reuse**: Same code path as CLI ensures identical behavior
5. **Availability**: Core APIs are always available (app links against MediaHub framework)

**Implementation Details**:

### Source Management Operations
- **Attach API**: `SourceAssociationManager.attach(source:to:libraryId:)`
  - Create `Source` object with media types (`SourceMediaTypes`)
  - Invoke `attach` method (synchronous, throws)
  - Wrap in `Task.detached` to call off MainActor
  - Update UI on MainActor after completion
- **Detach API**: `SourceAssociationManager.detach(sourceId:from:libraryId:)`
  - Invoke `detach` method (synchronous, throws)
  - Wrap in `Task.detached` to call off MainActor
  - Update UI on MainActor after completion
- **Retrieve Sources API**: `SourceAssociationManager.retrieveSources(for:libraryId:)`
  - Invoke `retrieveSources` method (synchronous, throws)
  - Wrap in `Task.detached` to call off MainActor
  - Update UI on MainActor after completion

### Detection Operations
- **Detection API**: `DetectionOrchestrator.executeDetection(source:libraryRootURL:libraryId:)`
  - Invoke `executeDetection` method (synchronous, throws)
  - Wrap in `Task.detached` to call off MainActor
  - Update UI on MainActor after completion
- **Preview Implementation**: See "Detection Preview Implementation" section below

### Import Operations
- **Import API**: `ImportExecutor.executeImport(detectionResult:selectedItems:libraryRootURL:libraryId:options:dryRun:)`
  - Preview: Use `dryRun: true` (Core API supports dry-run)
  - Execution: Use `dryRun: false` for actual import
  - Invoke method (synchronous, throws)
  - Wrap in `Task.detached` to call off MainActor
  - Update UI on MainActor after completion

**Fallback Strategy**: None required. Core APIs are always available since the app links against the MediaHub framework. If Core APIs fail, it's a programming error (not a runtime dependency issue).

## Detection Preview Implementation

**Challenge**: The Core API `DetectionOrchestrator.executeDetection` always updates source metadata (lastDetectedAt timestamp) and writes detection result files. However, the spec requires that detection preview (SR-002) should ideally NOT update source metadata.

**Reality Check**: Since Core API does not support true read-only preview mode, and implementing a revert mechanism would violate the "zero writes" principle (even if we "undo" the write), we need a pragmatic approach.

**Decision**: Use **Pragmatic Preview Approach** for P1:
- Call `DetectionOrchestrator.executeDetection` for preview (same as run)
- Accept that preview updates metadata (lastDetectedAt timestamp is updated)
- Clearly indicate in UI that this is a "Preview" operation with a badge/indicator
- Display detection results accurately
- Note in UI that "Preview updates detection timestamp" (transparency)
- When user runs detection again after preview, results will be identical (deterministic)

**Rationale**:
- Core API constraint: No read-only preview mode available
- Revert approach violates "zero writes" principle (even if we undo)
- Preview results are accurate and deterministic (same source state → same results)
- User can see preview results before deciding to run detection again
- Transparency: UI clearly indicates preview has updated metadata

**Implementation**:
1. Call `DetectionOrchestrator.executeDetection` off MainActor
2. Capture detection results
3. Display results in UI with prominent "Preview" badge/indicator
4. Show note: "Preview has updated detection timestamp"
5. Update source list to show updated lastDetectedAt (transparency)

**Future Improvement**: Consider adding read-only preview mode to Core API in future slice if needed.

## File System Access

### Path Selection

1. **User Selection**: Use `NSOpenPanel` with `.canChooseDirectories = true` to let user select a folder
2. **Path Validation**:
   - Verify path exists and is accessible
   - Verify path is a directory
   - Verify read permissions (for source attachment)
   - Check if path is already attached to library (error for attach, idempotent message)
3. **Error Display**: Show clear, user-facing error messages for validation failures
4. **Retry Support**: Allow user to correct path and retry without restarting interface

### Preview Operations

1. **Detection Preview**: Core API invocation (see Detection Preview Implementation section)
   - Invoke `DetectionOrchestrator.executeDetection` off MainActor
   - Accept that metadata is updated (Core API constraint)
   - Display results in UI with "Preview" indicator
   - Show transparency note that preview updates metadata
2. **Import Preview**: Core API dry-run mode (read-only file system access)
   - Invoke `ImportExecutor.executeImport` with `dryRun: true` off MainActor
   - Core API performs preview without copying files
   - Zero file system writes during preview

### Execution Operations

1. **Source Attachment**: Core API invocation
   - Create `Source` object with media types
   - Invoke `SourceAssociationManager.attach` off MainActor
   - Core API writes source associations file
   - Handle errors gracefully with user-facing messages
2. **Source Detachment**: Core API invocation
   - Invoke `SourceAssociationManager.detach` off MainActor
   - Core API updates source associations file
   - Handle errors gracefully
3. **Detection Run**: Core API invocation
   - Invoke `DetectionOrchestrator.executeDetection` off MainActor
   - Core API updates source metadata and writes detection result file
   - Handle errors gracefully
4. **Import Execution**: Core API invocation
   - Invoke `ImportExecutor.executeImport` with `dryRun: false` off MainActor
   - Core API copies files and updates baseline index
   - Handle errors gracefully

### Sandbox Considerations

- Use `NSOpenPanel` for folder selection (system handles sandbox access automatically)
- Request appropriate entitlements: `com.apple.security.files.user-selected.read-write`
- Test with sandbox enabled and disabled

## State Management Approach

### Source State Structure

```swift
@MainActor
class SourceState: ObservableObject {
    @Published var sources: [Source] = []
    @Published var isAttaching: Bool = false
    @Published var isDetaching: Bool = false
    @Published var errorMessage: String?
}
```

### Detection State Structure

```swift
@MainActor
class DetectionState: ObservableObject {
    @Published var previewResult: DetectionResult?
    @Published var runResult: DetectionResult?
    @Published var isPreviewing: Bool = false
    @Published var isRunning: Bool = false
    @Published var errorMessage: String?
}
```

### Import State Structure

```swift
@MainActor
class ImportState: ObservableObject {
    @Published var previewResult: ImportResult?
    @Published var executionResult: ImportResult?
    @Published var isPreviewing: Bool = false
    @Published var isExecuting: Bool = false
    @Published var errorMessage: String?
}
```

### State Transitions

1. **Source Attachment**: User selects path → validates → selects media types → confirms → `isAttaching = true` → invoke Core API → on success, refresh source list → on failure, show error
2. **Source Detachment**: User clicks detach → confirmation dialog → user confirms → `isDetaching = true` → invoke Core API → on success, refresh source list → on failure, show error
3. **Detection Preview**: User clicks preview → `isPreviewing = true` → invoke Core API → update `previewResult` and source metadata → `isPreviewing = false`
4. **Detection Run**: User clicks run → `isRunning = true` → invoke Core API → update `runResult` → refresh source list → `isRunning = false`
5. **Import Preview**: User clicks preview → `isPreviewing = true` → invoke Core API with `dryRun: true` → update `previewResult` → `isPreviewing = false`
6. **Import Execution**: User confirms import → `isExecuting = true` → invoke Core API with `dryRun: false` → update `executionResult` → refresh library status → `isExecuting = false`

### Determinism Guarantees

- Source list: Same library state produces same source list (deterministic)
- Detection results: Same source state produces same detection results (deterministic)
- Import preview: Same detection result produces same import preview (deterministic)
- Error messages: Same error conditions produce same error messages (deterministic)

## Error Handling Strategy

### Error Categories

1. **Path Validation Errors**:
   - Path doesn't exist: "The selected path does not exist. Please select a valid folder."
   - Path is not a directory: "The selected path is not a directory. Please select a folder."
   - Permission denied: "You don't have permission to access this location. Please select a different folder."
   - Already attached (attach): "This source is already attached to the library."

2. **Source Management Errors**:
   - Attach errors: `SourceAssociationError` → map to user-facing messages
   - Detach errors: `SourceAssociationError` → map to user-facing messages

3. **Detection Errors**:
   - Detection errors: `DetectionOrchestrationError` → map to user-facing messages
   - Source inaccessible: "The source is not accessible. Please check the source path."

4. **Import Errors**:
   - Import errors: `ImportExecutionError` → map to user-facing messages
   - Invalid detection result: "The detection result is invalid. Please run detection again."
   - No items selected: "No items selected for import." (should not occur with `import --all` behavior)

### Error Display

- Use inline error messages in views (not blocking alerts)
- Show errors near the relevant action (source list, detection, import)
- Always provide actionable error messages (what went wrong, what user can do)
- Allow user to retry operations without restarting interface

### Error Recovery

- Path validation errors: User can select a different path
- Source management errors: User can retry attachment/detachment
- Detection errors: User can retry detection
- Import errors: User can retry import or run detection again
- All errors: User can cancel operations at any time

## Sequencing

### Phase 1: Source List Display (P1)
**Goal**: Display attached sources in UI

1. Implement `SourceListView` SwiftUI view
2. Implement `SourceState` for state management
3. Implement source list loading (`SourceAssociationManager.retrieveSources`)
4. Display source information (path, media types, last detection timestamp)
5. Integrate with existing UI shell

**Why First**: Source list is foundational for all source management workflows. Can be tested immediately.

### Phase 2: Attach Source Interface (P1)
**Goal**: UI for attaching sources with media type selection

1. Implement `AttachSourceView` with folder picker
2. Implement path validation logic
3. Implement media type selection (images, videos, both)
4. Implement source attachment orchestration (`SourceOrchestrator`)
5. Integrate with source list (refresh after attachment)

**Why Second**: Source attachment is the primary source management operation. Needed before detection/import workflows.

### Phase 3: Detach Source Interface (P1)
**Goal**: UI for detaching sources with explicit confirmation

1. Implement `DetachSourceView` confirmation dialog
2. Implement source detachment orchestration
3. Integrate with source list (refresh after detachment)

**Why Third**: Source detachment completes source management workflows.

### Phase 4: Detection Preview (P1)
**Goal**: UI for previewing detection results (best-effort preview; Core API constraint means metadata is updated)

1. Implement `DetectionPreviewView` for displaying detection results
2. Implement detection preview orchestration (call Core API, accept metadata update, show transparency note)
3. Implement "Preview" indicator and transparency note
4. Integrate with source list (show "Preview Detection" action)

**Why Fourth**: Detection preview enables safe exploration before committing to detection run.

### Phase 5: Detection Run (P1)
**Goal**: UI for running detection and updating source metadata

1. Implement `DetectionRunView` for displaying detection results
2. Implement detection run orchestration
3. Implement progress indicators
4. Integrate with detection preview (enable "Run Detection" button)
5. Update source list after detection run

**Why Fifth**: Detection run completes detection workflows and enables import workflows.

### Phase 6: Import Preview (P1)
**Goal**: UI for previewing import operations without copying files

1. Implement `ImportPreviewView` for displaying import preview results
2. Implement import preview orchestration (`ImportExecutor.executeImport` with `dryRun: true`)
3. Implement "Preview" indicator
4. Integrate with detection results (show "Preview Import" action)

**Why Sixth**: Import preview enables safe exploration before committing to import execution.

### Phase 7: Import Confirmation Dialog (P1)
**Goal**: Explicit confirmation before import execution

1. Implement `ImportConfirmationView` with summary display
2. Implement "Import" and "Cancel" buttons
3. Integrate with import preview (enable "Confirm Import" button)

**Why Seventh**: Confirmation is required before import execution.

### Phase 8: Import Execution (P1)
**Goal**: UI for executing import operations

1. Implement `ImportExecutionView` for displaying import results
2. Implement import execution orchestration (`ImportExecutor.executeImport` with `dryRun: false`)
3. Implement progress indicators
4. Integrate with import confirmation (proceed after confirmation)
5. Update library status after import execution

**Why Eighth**: Import execution completes import workflows.

### Phase 9: Integration with App Shell (P2, Optional/Post-Freeze)
**Goal**: Integrate source/detection/import workflows with existing UI shell  
**Note**: Phase 9 is optional/post-freeze. Slice is complete without Phase 9. MVP can be delivered with workflows accessible via separate views/sheets.

1. Add source management section to library view
2. Add detection actions to source list
3. Add import actions to detection results
4. Handle workflow completion (refresh UI state)

**Why Last**: Integration connects workflows to the existing UI shell from Slices 11-12.

## Risks & Mitigations (Implementation Sequencing)

### Risk 1: Detection Preview Transparency
**Risk**: Detection preview updates metadata (Core API constraint), which may confuse users who expect true zero-write preview.

**Mitigation**:
- Clearly indicate in UI that preview has updated metadata (transparency note)
- Show "Preview" badge prominently to distinguish from execution
- Explain that preview results are accurate and deterministic
- Note that running detection again will produce identical results

**Sequencing Impact**: Phase 4 (Detection Preview) must implement clear transparency messaging.

### Risk 2: Async Operation Handling Complexity
**Risk**: Multiple async operations (source management, detection, import) may cause UI state issues or race conditions.

**Mitigation**:
- Use consistent pattern: all Core API calls off MainActor, all UI updates on MainActor
- Show progress indicators during all async operations
- Disable actions during operations to prevent duplicate operations
- Handle cancellation and cleanup properly
- Test with slow operations and cancellation scenarios

**Sequencing Impact**: All phases must follow consistent async patterns.

### Risk 3: Large Detection/Import Results UI Performance
**Risk**: Large detection/import results may cause UI performance issues when displaying in lists.

**Mitigation**:
- Use lazy loading for result lists
- Use pagination or virtual scrolling for large lists
- Show summary statistics prominently, allow expanding detailed view
- Test with large result sets (1000+ items)

**Sequencing Impact**: Phases 4, 5, 6, and 8 must handle large result sets efficiently.

### Risk 4: Import Confirmation Dialog Information Overload
**Risk**: Import confirmation dialogs may be overwhelming for large imports (100+ items).

**Mitigation**:
- Show summary statistics prominently (item count, total size)
- Allow expanding detailed view for item-by-item breakdown
- Use clear, concise messaging
- Test with large imports

**Sequencing Impact**: Phase 7 (Import Confirmation Dialog) must handle large imports gracefully.

### Risk 5: Source List Refresh Timing
**Risk**: Source list may not refresh correctly after attachment/detachment/detection operations.

**Mitigation**:
- Explicitly refresh source list after operations
- Use `@Published` properties to trigger UI updates
- Test refresh scenarios thoroughly

**Sequencing Impact**: Phases 2, 3, and 5 must handle source list refresh correctly.

## Testing / Verification Hooks

### User Story 1: Attach Source with Media Types

**Verification Steps**:
1. Launch UI app and open a library
2. Click "Attach Source" action
3. Verify interface opens with folder picker
4. Select a valid folder path
5. Select media types (images, videos, or both)
6. Verify preview shows source information
7. Confirm attachment
8. Verify source appears in source list with correct media types

**CLI Commands for Test Setup**:
```bash
# Create test source directory
mkdir -p /tmp/test-source
touch /tmp/test-source/test-photo.jpg
```

### User Story 2: Detach Source

**Verification Steps**:
1. Launch UI app and open a library with attached sources
2. Click "Detach Source" for a source
3. Verify confirmation dialog shows source information
4. Confirm detachment
5. Verify source is removed from source list

### User Story 3: Detect Preview

**Verification Steps**:
1. Launch UI app and open a library with attached source
2. Click "Preview Detection" for a source
3. Verify preview shows detection results (new items, duplicates, statistics)
4. Verify "Preview" indicator is displayed
5. Verify source metadata IS updated (check lastDetectedAt timestamp; Core API constraint, acceptable for preview)
6. Verify UI shows transparency note that preview updated metadata
6. Verify "Run Detection" button is enabled

**CLI Commands for Test Setup**:
```bash
# Create test source with media files
mkdir -p /tmp/test-source-detection
touch /tmp/test-source-detection/new-photo.jpg
```

### User Story 4: Run Detection

**Verification Steps**:
1. Launch UI app and open a library with attached source
2. Click "Run Detection" for a source (after preview or directly)
3. Verify progress indicator shows during detection
4. Verify detection results are displayed
5. Verify source metadata is updated (check lastDetectedAt timestamp)
6. Verify "Preview Import" button is enabled (if new items detected)

### User Story 5: Import Preview

**Verification Steps**:
1. Launch UI app and open a library with detection results
2. Click "Preview Import" for a detection result
3. Verify preview shows import operations (items to copy, destination paths)
4. Verify "Preview" indicator is displayed
5. Verify no files are copied (check library directory)
6. Verify "Confirm Import" button is enabled

### User Story 6: Confirm and Run Import

**Verification Steps**:
1. Launch UI app and open a library with import preview
2. Click "Confirm Import"
3. Verify confirmation dialog shows summary (item count, total size)
4. Confirm import
5. Verify progress indicator shows during import
6. Verify import results are displayed (successful, failures, collisions)
7. Verify files are copied to library (check library directory)
8. Verify library status is updated

### User Story 7: Source List Display

**Verification Steps**:
1. Launch UI app and open a library with attached sources
2. Verify source list displays all attached sources
3. Verify source information (path, media types, last detection timestamp) is correct
4. Verify source list matches CLI `mediahub source list --json` output

## Success Criteria Verification

- **SC-001** (Attach < 2 seconds): Measure time from confirmation to source attachment completion
- **SC-002** (Detach < 1 second): Measure time from confirmation to source detachment completion
- **SC-003** (Detection preview < 10 seconds): Measure time for detection preview with 1000 items
- **SC-004** (Detection run < 10 seconds): Measure time for detection run with 1000 items
- **SC-005** (Import preview < 5 seconds): Measure time for import preview with 100 items
- **SC-006** (Import execution < 30 seconds): Measure time for import execution with 100 items
- **SC-007** (Source list accuracy): Compare UI source list with CLI `mediahub source list --json` output
- **SC-008** (Detection results accuracy): Compare UI detection results with CLI `mediahub detect --json` output
- **SC-009** (Import preview accuracy): Compare UI import preview with CLI `mediahub import --dry-run --json` output
- **SC-010** (Error handling): Test all error cases and verify clear messages displayed
- **SC-011** (Determinism): Run same operations multiple times and verify identical results

## Implementation Notes

### Core API Usage Pattern

#### Source Attachment
```swift
// Create Source object with media types
let source = Source(
    sourceId: UUID().uuidString,
    type: .folder,
    path: selectedPath,
    mediaTypes: selectedMediaTypes // .images, .videos, or .both
)

// Attach source off MainActor
Task.detached {
    do {
        try SourceAssociationManager.attach(
            source: source,
            to: libraryRootURL,
            libraryId: libraryId
        )
        
        // Update UI on MainActor
        await MainActor.run {
            // Refresh source list
            sourceState.refreshSources()
        }
    } catch {
        await MainActor.run {
            sourceState.errorMessage = mapErrorToUserMessage(error)
        }
    }
}
```

#### Detection Preview
```swift
// Run detection off MainActor (best-effort preview; Core API updates metadata)
Task.detached {
    do {
        // Execute detection (Core API updates metadata, which is acceptable for preview)
        let result = try DetectionOrchestrator.executeDetection(
            source: source,
            libraryRootURL: libraryRootURL,
            libraryId: libraryId
        )
        
        // Update UI on MainActor
        await MainActor.run {
            detectionState.previewResult = result
            detectionState.isPreviewing = false
            // Refresh source list to show updated lastDetectedAt (transparency)
            sourceState.refreshSources()
        }
    } catch {
        await MainActor.run {
            detectionState.errorMessage = mapErrorToUserMessage(error)
            detectionState.isPreviewing = false
        }
    }
}
```

#### Import Execution
```swift
// Execute import off MainActor
Task.detached {
    do {
        let result = try ImportExecutor.executeImport(
            detectionResult: detectionResult,
            selectedItems: detectionResult.candidates.map { $0.item }, // All items for P1
            libraryRootURL: libraryRootURL,
            libraryId: libraryId,
            options: ImportOptions.default, // Default collision policy
            dryRun: false
        )
        
        // Update UI on MainActor
        await MainActor.run {
            importState.executionResult = result
            importState.isExecuting = false
            // Refresh library status
        }
    } catch {
        await MainActor.run {
            importState.errorMessage = mapErrorToUserMessage(error)
            importState.isExecuting = false
        }
    }
}
```

### Error Mapping

All Core API errors must be mapped to user-facing error messages:

```swift
func mapErrorToUserMessage(_ error: Error) -> String {
    if let error = error as? SourceAssociationError {
        switch error {
        case .duplicateSource:
            return "This source is already attached to the library."
        case .sourceNotFound:
            return "Source not found."
        case .permissionDenied:
            return "You don't have permission to access this location."
        // ... other cases
        }
    }
    // ... other error types
    return "An unexpected error occurred: \(error.localizedDescription)"
}
```
