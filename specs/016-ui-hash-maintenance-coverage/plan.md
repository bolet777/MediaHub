# Implementation Plan: UI Hash Maintenance + Coverage

**Feature**: UI Hash Maintenance + Coverage  
**Specification**: `specs/016-ui-hash-maintenance-coverage/spec.md`  
**Slice**: 16 - Hash maintenance UI (batch/limit operations) and coverage insights with duplicate detection (read-only)  
**Created**: 2026-01-17

## Plan Scope

This plan implements **Slice 16 only**, which adds UI workflows for hash maintenance operations, hash coverage insights, and read-only duplicate detection display. This includes:

- Hash coverage statistics display in library status view
- Hash maintenance preview UI (shows candidates without computing hashes)
- Hash maintenance execution UI with progress/cancellation support (from Slice 15)
- Hash maintenance batch/limit controls (optional limit configuration)
- Duplicate detection display UI (read-only view of duplicate groups and files)

**Explicitly out of scope**:
- Core API changes (Core APIs from Slices 9, 9b, 14 are consumed as-is)
- CLI changes (CLI continues to work as before)
- Duplicate resolution (deletion, merging)
- Automatic or scheduled hash computation
- Hash computation history or audit trail (deferred to Slice 17)
- Export capabilities for duplicate reports (deferred to Slice 17)
- Progress/cancellation API changes (uses existing API from Slice 14/15)

## Goals / Non-Goals

### Goals
- Provide UI interfaces for hash maintenance operations (preview and execution with batch/limit)
- Display hash coverage statistics in library status view
- Enable duplicate detection display through the UI (read-only)
- Maintain safety guarantees (preview operations perform zero writes, explicit confirmations)
- Integrate progress/cancellation UI from Slice 15 for hash maintenance operations
- Maintain backward compatibility with existing Core APIs
- Integrate seamlessly with existing UI shell from Slices 11-15

### Non-Goals
- Implement new business logic (all logic remains in Core layer)
- Support duplicate resolution (deletion, merging - read-only display only)
- Support automatic or scheduled hash computation (user-initiated only)
- Support hash computation history (deferred to Slice 17)
- Support export capabilities (deferred to Slice 17)
- Optimize for very large operations beyond basic async handling

## Proposed Architecture

### Module Structure

The implementation extends the existing `MediaHubUI` app target with new hash maintenance and duplicate detection components. All components link against the existing `MediaHub` framework (Core APIs).

**Targets**:
- `MediaHubUI` (macOS app target, existing from Slices 11-15)
  - Links against `MediaHub` framework (Core APIs)
  - New hash maintenance SwiftUI views and view models
  - New duplicate detection SwiftUI views and view models
  - Core API orchestration for hash maintenance/duplicate detection operations

**Boundaries**:
- **UI Layer**: SwiftUI views, view models, state management
- **Orchestration Layer**: Thin wrappers that invoke Core APIs (`HashCoverageMaintenance`, `DuplicateReporting`)
- **Core Layer**: Existing MediaHub framework (frozen, no changes)
- **CLI Layer**: Not used by UI (UI uses Core APIs directly)

### Component Overview

#### Hash Coverage Display Components

1. **Hash Coverage Statistics Display** (extend `StatusView.swift` or new component)
   - Displays hash coverage percentage, total entries, entries with hash, entries missing hash
   - Shows "N/A" when baseline index is missing/invalid (graceful degradation)
   - Updates when hash maintenance operations complete
   - Integrates with existing `LibraryStatus` from Slice 9

#### Hash Maintenance Components

2. **Hash Maintenance Preview View** (`HashMaintenancePreviewView.swift`)
   - Displays candidate files (files missing hashes) and statistics
   - "Preview" badge/indicator
   - Candidate statistics display (total candidates, limit if specified)
   - "Run Hash Maintenance" button

3. **Hash Maintenance Execution View** (`HashMaintenanceExecutionView.swift`)
   - Progress bar showing current/total counts during hash computation
   - Cancel button that is enabled during operation (from Slice 15)
   - Limit configuration input (optional, for batch operations)
   - Results display when complete

4. **Hash Maintenance State Management** (`HashMaintenanceState.swift`)
   - Preview candidate results caching
   - Hash computation state (in progress, results)
   - Progress state (stage, current, total, message)
   - Cancellation token management
   - Limit configuration (source of truth: defined once by user, stored in state, reused consistently for preview and execution unless changed by user)
   - Error state management

5. **Hash Maintenance Orchestrator** (`HashMaintenanceOrchestrator.swift`)
   - `HashCoverageMaintenance.selectCandidates` invocation for preview
   - `HashCoverageMaintenance.computeMissingHashes` invocation for execution
   - Progress callback integration (forwards Core progress to MainActor)
   - Cancellation token integration (creates token, wires to Core API, handles CancellationError)
   - Async operation handling (off MainActor)
   - Error handling and user-facing error messages

#### Duplicate Detection Components

6. **Duplicate Detection View** (`DuplicateDetectionView.swift`)
   - Displays duplicate groups (sorted by hash)
   - File details within each group (path, size, timestamp)
   - Summary statistics (total groups, total files, potential savings)
   - "No duplicates found" message when empty
   - Read-only view (no deletion or merging capabilities)

7. **Duplicate Detection State Management** (`DuplicateDetectionState.swift`)
   - Duplicate groups caching
   - Duplicate summary statistics
   - Analysis state (in progress, results)
   - Error state management

8. **Duplicate Detection Orchestrator** (`DuplicateDetectionOrchestrator.swift`)
   - `DuplicateReporting.analyzeDuplicates` invocation
   - Async operation handling (off MainActor)
   - Error handling and user-facing error messages

### Data Flow

#### Hash Coverage Display Flow
```
User opens library
  ↓
StatusView loads LibraryStatus (from Slice 9)
  ↓
Hash coverage statistics extracted from LibraryStatus.hashCoverage
  ↓
Display hash coverage percentage, total entries, entries with hash, entries missing hash
  ↓
If baseline index missing/invalid: show "N/A" (graceful degradation)
  ↓
After hash maintenance operations: refresh hash coverage statistics
```

#### Hash Maintenance Preview Flow
```
User clicks "Preview Hash Maintenance" action
  ↓
Present HashMaintenancePreviewView sheet
  ↓
HashMaintenanceOrchestrator calls HashCoverageMaintenance.selectCandidates
  - Off MainActor (Task.detached)
  - With limit from HashMaintenanceState.limit (source of truth, reused consistently)
  ↓
Receive HashCoverageCandidates (statistics + candidate entries)
  ↓
Update HashMaintenanceState.previewCandidates on MainActor
  ↓
Display candidate statistics and list
  ↓
Show "Preview" badge/indicator
  ↓
Enable "Run Hash Maintenance" button
```

#### Hash Maintenance Execution Flow
```
User clicks "Run Hash Maintenance" (from preview or directly)
  ↓
Present HashMaintenanceExecutionView sheet
  ↓
If limit configured: show limit input, allow user to specify batch size
  ↓
User confirms execution (explicit confirmation dialog)
  ↓
HashMaintenanceOrchestrator creates CancellationToken
  ↓
HashMaintenanceOrchestrator creates progress callback
  - Progress callback forwards Core progress updates to MainActor
  - Updates HashMaintenanceState progress fields on MainActor
  ↓
HashMaintenanceOrchestrator calls HashCoverageMaintenance.computeMissingHashes
  - Off MainActor (Task.detached)
  - With progress callback and cancellation token
  - With limit from HashMaintenanceState.limit (source of truth, reused consistently from preview)
  ↓
Progress updates received from Core (throttled to 1 update/second)
  - Forwarded to MainActor
  - Update HashMaintenanceState progress fields
  - Update progress bar in HashMaintenanceExecutionView
  ↓
If user clicks cancel:
  - Call cancellationToken.cancel()
  - Update HashMaintenanceState.isCanceling on MainActor
  - Show "Canceling..." feedback
  ↓
Operation completes (success or cancellation)
  ↓
If CancellationError: handle gracefully, show "Operation canceled" message
  ↓
If success: update HashMaintenanceState.hashComputationResult on MainActor
  ↓
Display results (hashes computed, coverage improved)
  ↓
Refresh hash coverage statistics in StatusView
  ↓
Clear cancellation token
```

#### Duplicate Detection Flow
```
User clicks "View Duplicates" action
  ↓
Present DuplicateDetectionView sheet
  ↓
DuplicateDetectionOrchestrator calls DuplicateReporting.analyzeDuplicates
  - Off MainActor (Task.detached)
  - With library root path
  ↓
Receive ([DuplicateGroup], DuplicateSummary) tuple
  ↓
Update DuplicateDetectionState.duplicateGroups and duplicateSummary on MainActor
  ↓
Display duplicate groups (sorted by hash)
  ↓
Display file details within each group (sorted by path)
  ↓
Display summary statistics (total groups, total files, potential savings)
  ↓
If no duplicates: show "No duplicates found" message
```

## Implementation Phases

### Phase 1: Hash Coverage Statistics Display

**Goal**: Display hash coverage statistics in library status view.

**Tasks**:
- Extend `StatusView.swift` or create new component to display hash coverage statistics
- Integrate with existing `LibraryStatus` from Slice 9 (hash coverage already available)
- Display hash coverage percentage, total entries, entries with hash, entries missing hash
- Handle graceful degradation when baseline index is missing/invalid (show "N/A")
- Update hash coverage statistics after hash maintenance operations complete

**Validation**:
- Hash coverage statistics display correctly when library is opened
- Graceful degradation works when index is missing/invalid
- Statistics update after hash maintenance operations

**Files**:
- `Sources/MediaHubUI/StatusView.swift` (modify) or new component

**Dependencies**: None (uses existing `LibraryStatus` from Slice 9)

---

### Phase 2: Hash Maintenance State and Orchestrator

**Goal**: Implement hash maintenance state management and orchestrator for Core API integration.

**Tasks**:
- Create `HashMaintenanceState.swift` with state properties (preview candidates, computation results, progress, cancellation token, limit)
- Create `HashMaintenanceOrchestrator.swift` with Core API integration
- Implement `selectCandidates` invocation for preview (read-only)
- Implement `computeMissingHashes` invocation for execution
- Implement progress callback integration (forwards Core progress to MainActor)
- Implement cancellation token integration (creates token, wires to Core API, handles CancellationError)
- Implement async operation handling (off MainActor)
- Implement error handling and user-facing error messages

**Validation**:
- Hash maintenance orchestrator calls Core APIs correctly
- Progress callbacks forward to MainActor correctly
- Cancellation tokens work correctly
- Error handling maps Core errors to user-facing messages

**Files**:
- `Sources/MediaHubUI/HashMaintenanceState.swift` (new)
- `Sources/MediaHubUI/HashMaintenanceOrchestrator.swift` (new)

**Dependencies**: Phase 1 (for state management pattern)

---

### Phase 3: Hash Maintenance Preview View

**Goal**: Implement hash maintenance preview UI that shows candidates without computing hashes.

**Tasks**:
- Create `HashMaintenancePreviewView.swift` or similar view
- Display candidate files (files missing hashes) and statistics
- Show "Preview" badge/indicator
- Display candidate statistics (total candidates, limit if specified)
- Enable "Run Hash Maintenance" button when preview completes successfully
- Handle preview errors gracefully

**Validation**:
- Preview shows accurate candidate information
- Preview is clearly marked as preview
- Execution button enables when preview completes
- Preview errors are handled gracefully

**Files**:
- `Sources/MediaHubUI/HashMaintenancePreviewView.swift` (new)

**Dependencies**: Phase 2 (orchestrator and state)

---

### Phase 4: Hash Maintenance Execution View

**Goal**: Implement hash maintenance execution UI with progress/cancellation support.

**Tasks**:
- Create `HashMaintenanceExecutionView.swift` or extend existing view
- Display progress bar showing current/total counts during hash computation
- Display cancel button that is enabled during operation (from Slice 15 pattern)
- Display limit configuration input (optional, for batch operations)
- Display results when complete (hashes computed, coverage improved)
- Integrate with progress/cancellation from Slice 15
- Handle cancellation gracefully (show "Canceling..." state, handle CancellationError)

**Validation**:
- Progress bars update during hash computation
- Cancel button stops operation gracefully
- Limit configuration works correctly
- Results display correctly when complete

**Files**:
- `Sources/MediaHubUI/HashMaintenanceExecutionView.swift` (new)

**Dependencies**: Phase 2 (orchestrator and state), Slice 15 (progress/cancellation UI pattern)

---

### Phase 5: Duplicate Detection State and Orchestrator

**Goal**: Implement duplicate detection state management and orchestrator for Core API integration.

**Tasks**:
- Create `DuplicateDetectionState.swift` with state properties (duplicate groups, summary, analysis state)
- Create `DuplicateDetectionOrchestrator.swift` with Core API integration
- Implement `analyzeDuplicates` invocation
- Implement async operation handling (off MainActor)
- Implement error handling and user-facing error messages

**Validation**:
- Duplicate detection orchestrator calls Core API correctly
- Error handling maps Core errors to user-facing messages

**Files**:
- `Sources/MediaHubUI/DuplicateDetectionState.swift` (new)
- `Sources/MediaHubUI/DuplicateDetectionOrchestrator.swift` (new)

**Dependencies**: None (independent from hash maintenance)

---

### Phase 6: Duplicate Detection View

**Goal**: Implement duplicate detection display UI (read-only view).

**Tasks**:
- Create `DuplicateDetectionView.swift`
- Display duplicate groups (sorted by hash, deterministically)
- Display file details within each group (path, size, timestamp, sorted by path)
- Display summary statistics (total groups, total files, potential savings)
- Display "No duplicates found" message when empty
- Ensure read-only view (no deletion or merging capabilities)

**Validation**:
- Duplicate groups and files are displayed accurately
- Sorting is deterministic (by hash for groups, by path for files)
- Statistics match CLI output
- Empty state is handled correctly

**Files**:
- `Sources/MediaHubUI/DuplicateDetectionView.swift` (new)

**Dependencies**: Phase 5 (orchestrator and state)

---

### Phase 7: UI Integration

**Goal**: Integrate hash maintenance and duplicate detection workflows into main library interface.

**Tasks**:
- Add hash maintenance entry points to library detail view (e.g., "Hash Maintenance" button or menu item)
- Add duplicate detection entry point to library detail view (e.g., "View Duplicates" button or menu item)
- Wire hash maintenance workflows (preview → execution)
- Wire duplicate detection workflow (view duplicates)
- Ensure hash coverage statistics update after hash maintenance operations
- Ensure all workflows are accessible from integrated locations

**Validation**:
- Hash maintenance workflows are accessible from library view
- Duplicate detection workflow is accessible from library view
- Hash coverage statistics update after hash maintenance operations
- All workflows work end-to-end

**Files**:
- `Sources/MediaHubUI/ContentView.swift` or library detail view (modify)
- Integration wiring in existing views

**Dependencies**: Phases 1-6 (all components)

---

## Sequencing and Safety

### Read-Only Operations First
- **Phase 1**: Hash coverage display (read-only, uses existing `LibraryStatus`)
- **Phase 5**: Duplicate detection (read-only, uses `DuplicateReporting.analyzeDuplicates`)

### Preview Before Execution
- **Phase 3**: Hash maintenance preview (read-only, uses `HashCoverageMaintenance.selectCandidates`)
- **Phase 4**: Hash maintenance execution (mutating, uses `HashCoverageMaintenance.computeMissingHashes`)

### State Management Before Views
- **Phase 2**: Hash maintenance state and orchestrator (foundation for preview/execution views)
- **Phase 5**: Duplicate detection state and orchestrator (foundation for duplicate view)

### Integration Last
- **Phase 7**: UI integration (wires all components together)

## Async Handling

All Core API calls must occur off MainActor:

- **Hash Maintenance Orchestrator**: Use `Task.detached` for `selectCandidates` and `computeMissingHashes` calls
- **Limit Consistency**: Limit value is defined once by the user, stored in `HashMaintenanceState.limit`, and reused consistently for both preview (`selectCandidates`) and execution (`computeMissingHashes`) unless changed by the user
- **Duplicate Detection Orchestrator**: Use `Task.detached` for `analyzeDuplicates` calls
- **Progress Callbacks**: Core progress callbacks are invoked on background threads, forward to MainActor using `Task { @MainActor in ... }` or `await MainActor.run { ... }`
- **State Updates**: All UI state updates occur on MainActor

## Error Handling

- **Core Errors**: Map `HashCoverageMaintenanceError` and `DuplicateReportingError` to user-facing messages
- **Cancellation Errors**: Handle `CancellationError.cancelled` gracefully (show "Operation canceled" message)
- **Error Display**: Display errors in UI with clear, actionable messages
- **Error Recovery**: Allow users to retry operations or cancel gracefully

## Progress and Cancellation Integration

- **Progress Callbacks**: Use progress callbacks from Core (Slice 14) to update UI state on MainActor
- **Cancellation Tokens**: Create cancellation tokens when operations start, wire to Core API, handle CancellationError
- **Progress UI**: Use progress bars and cancel buttons from Slice 15 pattern
- **Throttling**: Core progress callbacks are throttled to maximum 1 update per second (Slice 14 guarantee)

## Backward Compatibility

- **Existing UI Workflows**: All existing UI workflows continue to work unchanged
- **Core APIs**: Core APIs remain unchanged (consumed as-is)
- **State Management**: New state properties are additive, do not affect existing state
- **Additive Features**: Hash maintenance and duplicate detection are additive features, not required for existing workflows

## Constitutional Compliance

This plan adheres to the MediaHub Constitution:

- **Safe Operations (3.3)**: Preview operations perform zero writes; explicit confirmation for execution; progress/cancellation support
- **Data Safety (4.1)**: Hash computation only updates index (no media file modifications); duplicate detection is read-only
- **Deterministic Behavior (3.4)**: Hash maintenance and duplicate detection results are deterministic (Core API guarantees)
- **Transparent Storage (3.2)**: All operations use existing transparent Core APIs
- **Simplicity of User Experience (3.1)**: UI workflows are simple and explicit; clear messaging about operations
