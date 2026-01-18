# Implementation Tasks: UI Hash Maintenance + Coverage

**Feature**: UI Hash Maintenance + Coverage  
**Specification**: `specs/016-ui-hash-maintenance-coverage/spec.md`  
**Plan**: `specs/016-ui-hash-maintenance-coverage/plan.md`  
**Slice**: 16 - Hash maintenance UI (batch/limit operations) and coverage insights with duplicate detection (read-only)  
**Created**: 2026-01-17

## Task Organization

Tasks are organized by phase and user story, following the implementation sequence defined in the plan. Each task is:
- Small and focused on a single deliverable (1–2 commands max per pass)
- Sequential with explicit dependencies
- Traceable to plan phases and spec requirements
- Read-only preview operations first; writes only after explicit user confirmation

---

## Phase 1 — Hash Coverage Statistics Display

**Plan Reference**: Phase 1 (lines 232-251)  
**Goal**: Display hash coverage statistics in library status view  
**Dependencies**: None (Foundation)

### T-001: Extend StatusView with Hash Coverage Display
**Priority**: P1  
**Summary**: Add hash coverage statistics display to StatusView.

**Expected Files Touched**:
- `Sources/MediaHubUI/StatusView.swift` (update)

**Steps**:
1. Locate `StatusView.swift` and identify where library statistics are displayed
2. Add hash coverage section to display:
   - Hash coverage percentage (e.g., "75% coverage")
   - Total entries count
   - Entries with hash count
   - Entries missing hash count
3. Extract hash coverage data from `LibraryStatus.hashCoverage` (already available from Slice 9)
4. Handle graceful degradation: if `hashCoverage` is nil, display "N/A" or "Not available"
5. Format percentage display (e.g., "75.5%" or "100%")

**Done When**:
- Hash coverage statistics display correctly when library is opened
- Graceful degradation works when index is missing/invalid (shows "N/A")
- Statistics are formatted clearly

**Dependencies**: None

---

## Phase 2 — Hash Maintenance State and Orchestrator

**Plan Reference**: Phase 2 (lines 255-279)  
**Goal**: Implement hash maintenance state management and orchestrator  
**Dependencies**: Phase 1 (for state management pattern)

### T-002: Create Hash Maintenance State Management
**Priority**: P1  
**Summary**: Create hash maintenance state management class.

**Expected Files Touched**:
- `Sources/MediaHubUI/HashMaintenanceState.swift` (new)

**Steps**:
1. Create `HashMaintenanceState` class conforming to `ObservableObject` with `@MainActor`
2. Add `@Published` properties:
   - `var previewCandidates: HashCoverageCandidates? = nil`
   - `var isPreviewing: Bool = false`
   - `var hashComputationResult: HashComputationResult? = nil`
   - `var isComputing: Bool = false`
   - `var progressStage: String? = nil`
   - `var progressCurrent: Int? = nil`
   - `var progressTotal: Int? = nil`
   - `var progressMessage: String? = nil`
   - `var cancellationToken: CancellationToken? = nil`
   - `var isCanceling: Bool = false`
   - `var limit: Int? = nil`
   - `var errorMessage: String? = nil`

**Done When**:
- State class compiles
- All properties are `@Published` and accessible
- All properties are `@MainActor` safe

**Dependencies**: None

---

### T-003: Create Hash Maintenance Orchestrator Skeleton
**Priority**: P1  
**Summary**: Create hash maintenance orchestrator struct with method stubs.

**Expected Files Touched**:
- `Sources/MediaHubUI/HashMaintenanceOrchestrator.swift` (new)

**Steps**:
1. Create `HashMaintenanceOrchestrator` struct with static methods
2. Add method stub `previewCandidates(libraryRoot:limit:) async throws -> HashCoverageCandidates` (placeholder)
3. Add method stub `computeMissingHashes(libraryRoot:limit:progress:cancellationToken:) async throws -> HashComputationResult` (placeholder)

**Done When**:
- Orchestrator struct compiles
- Method stubs are in place

**Dependencies**: T-002

---

### T-004: Implement Hash Maintenance Preview Orchestration
**Priority**: P1  
**Summary**: Implement preview candidate selection Core API call.

**Expected Files Touched**:
- `Sources/MediaHubUI/HashMaintenanceOrchestrator.swift` (update)

**Steps**:
1. Implement `previewCandidates(libraryRoot:limit:) async throws -> HashCoverageCandidates`
2. Call `HashCoverageMaintenance.selectCandidates(libraryRoot:limit:)` off MainActor using `Task.detached`
3. Return `HashCoverageCandidates` result
4. Handle `HashCoverageMaintenanceError` and map to user-facing error messages

**Done When**:
- Preview candidate selection works off MainActor
- Errors are mapped to user-facing messages
- Method returns `HashCoverageCandidates` correctly

**Dependencies**: T-003

---

### T-005: Implement Hash Maintenance Execution Orchestration
**Priority**: P1  
**Summary**: Implement hash computation Core API call with progress/cancellation.

**Expected Files Touched**:
- `Sources/MediaHubUI/HashMaintenanceOrchestrator.swift` (update)

**Steps**:
1. Implement `computeMissingHashes(libraryRoot:limit:progress:cancellationToken:) async throws -> HashComputationResult`
2. Create progress callback that forwards Core progress updates to MainActor:
   - Use `Task { @MainActor in ... }` to update state on MainActor
   - Update `HashMaintenanceState` progress fields (stage, current, total, message)
3. Call `HashCoverageMaintenance.computeMissingHashes(libraryRoot:limit:progress:cancellationToken:)` off MainActor using `Task.detached`
4. Pass progress callback and cancellation token to Core API
5. Return `HashComputationResult` result
6. Handle `HashCoverageMaintenanceError` and `CancellationError` and map to user-facing error messages

**Done When**:
- Hash computation works off MainActor
- Progress callbacks forward to MainActor correctly
- Cancellation tokens are passed to Core API
- Errors are mapped to user-facing messages
- Method returns `HashComputationResult` correctly

**Dependencies**: T-003

---

## Phase 3 — Hash Maintenance Preview View

**Plan Reference**: Phase 3 (lines 283-299)  
**Goal**: Implement hash maintenance preview UI  
**Dependencies**: Phase 2 (orchestrator and state)

### T-006: Create Hash Maintenance Preview View Skeleton
**Priority**: P1  
**Summary**: Create basic hash maintenance preview view structure.

**Expected Files Touched**:
- `Sources/MediaHubUI/HashMaintenancePreviewView.swift` (new)

**Steps**:
1. Create `HashMaintenancePreviewView` struct conforming to `View`
2. Add parameters: `libraryRootURL: URL`, `onComplete: () -> Void`
3. Add `@StateObject private var state = HashMaintenanceState()`
4. Add `@State private var limit: Int? = nil`
5. Add basic view structure with title and placeholder content

**Done When**:
- Preview view compiles
- View structure is in place

**Dependencies**: T-002

---

### T-007: Implement Preview Candidate Display
**Priority**: P1  
**Summary**: Display candidate files and statistics in preview view.

**Expected Files Touched**:
- `Sources/MediaHubUI/HashMaintenancePreviewView.swift` (update)

**Steps**:
1. Display candidate statistics from `state.previewCandidates?.statistics`:
   - Total candidates count
   - Limit if specified
   - Hash coverage percentage
2. Display "Preview" badge/indicator clearly
3. Display candidate file list or summary (optional: show first N candidates or summary only)
4. Show loading indicator when `state.isPreviewing` is true
5. Show error message when `state.errorMessage` is not nil

**Done When**:
- Candidate statistics are displayed correctly
- Preview badge is visible
- Loading and error states are handled

**Dependencies**: T-006

---

### T-008: Wire Preview Orchestration to View
**Priority**: P1  
**Summary**: Connect preview view to orchestrator for candidate selection.

**Expected Files Touched**:
- `Sources/MediaHubUI/HashMaintenancePreviewView.swift` (update)

**Steps**:
1. Add "Preview" button that triggers preview operation
2. On button click, call `HashMaintenanceOrchestrator.previewCandidates` off MainActor:
   - Set `state.isPreviewing = true` on MainActor
   - Call orchestrator method using `Task.detached` with limit from `state.limit` (source of truth, reused consistently)
   - Update `state.previewCandidates` on MainActor when complete
   - Set `state.isPreviewing = false` on MainActor
   - Handle errors and update `state.errorMessage` on MainActor
3. Enable "Run Hash Maintenance" button when `state.previewCandidates` is not nil and `state.isPreviewing` is false

**Done When**:
- Preview button triggers candidate selection
- Preview results are displayed
- Execution button enables when preview completes successfully
- Errors are handled gracefully

**Dependencies**: T-004, T-007

---

## Phase 4 — Hash Maintenance Execution View

**Plan Reference**: Phase 4 (lines 301-320)  
**Goal**: Implement hash maintenance execution UI with progress/cancellation  
**Dependencies**: Phase 2 (orchestrator and state), Slice 15 (progress/cancellation UI pattern)

### T-009: Create Hash Maintenance Execution View Skeleton
**Priority**: P1  
**Summary**: Create basic hash maintenance execution view structure.

**Expected Files Touched**:
- `Sources/MediaHubUI/HashMaintenanceExecutionView.swift` (new)

**Steps**:
1. Create `HashMaintenanceExecutionView` struct conforming to `View`
2. Add parameters: `libraryRootURL: URL`, `limit: Int?`, `onComplete: () -> Void`
3. Add `@StateObject private var state = HashMaintenanceState()`
4. Add basic view structure with title and placeholder content

**Done When**:
- Execution view compiles
- View structure is in place

**Dependencies**: T-002

---

### T-010: Implement Progress Bar and Cancel Button
**Priority**: P1  
**Summary**: Add progress bar and cancel button to execution view (from Slice 15 pattern).

**Expected Files Touched**:
- `Sources/MediaHubUI/HashMaintenanceExecutionView.swift` (update)

**Steps**:
1. Add progress bar using `ProgressView`:
   - Use `value: Double(state.progressCurrent ?? 0) / Double(state.progressTotal ?? 1)`
   - Display progress message from `state.progressMessage` or `state.progressStage`
   - Display current/total counts (e.g., "50 of 200 files")
2. Add cancel button:
   - Enabled when `state.isComputing` is true` and `state.isCanceling` is false
   - Calls `state.cancellationToken?.cancel()` when clicked
   - Shows "Canceling..." text when `state.isCanceling` is true
   - Disabled when operation is not in progress

**Done When**:
- Progress bar displays correctly during hash computation
- Cancel button works correctly
- Progress updates smoothly (throttled by Core to 1 update/second)

**Dependencies**: T-009, Slice 15 (progress/cancellation UI pattern)

---

### T-011: Implement Limit Configuration Input
**Priority**: P1  
**Summary**: Add optional limit configuration input for batch operations.

**Expected Files Touched**:
- `Sources/MediaHubUI/HashMaintenanceExecutionView.swift` (update)

**Steps**:
1. Add limit input field (TextField or Stepper):
   - Optional limit value (nil means process all)
   - Allow user to specify batch size (e.g., "Process first 100 files")
   - Store limit in `state.limit` (source of truth: defined once by user, reused consistently for preview and execution unless changed by user)
2. Display limit in preview/execution (e.g., "Processing first 100 of 200 candidates")

**Done When**:
- Limit input is visible and functional
- Limit is stored in state
- Limit is passed to orchestrator correctly

**Dependencies**: T-009

---

### T-012: Wire Execution Orchestration to View
**Priority**: P1  
**Summary**: Connect execution view to orchestrator for hash computation.

**Expected Files Touched**:
- `Sources/MediaHubUI/HashMaintenanceExecutionView.swift` (update)

**Steps**:
1. Add "Run Hash Maintenance" button that triggers execution
2. On button click:
   - Create `CancellationToken` and store in `state.cancellationToken` on MainActor
   - Set `state.isComputing = true` on MainActor
   - Call `HashMaintenanceOrchestrator.computeMissingHashes` off MainActor:
     - Pass progress callback and cancellation token
     - Pass limit from `state.limit` (source of truth, reused consistently from preview)
     - Update `state.hashComputationResult` on MainActor when complete
     - Set `state.isComputing = false` on MainActor
     - Clear `state.cancellationToken` on MainActor
     - Handle `CancellationError` and update `state.isCanceling` on MainActor
     - Handle other errors and update `state.errorMessage` on MainActor
3. Display results when complete:
   - Show hashes computed count
   - Show coverage improvement message
   - Enable completion callback

**Done When**:
- Execution button triggers hash computation
- Progress updates during computation
- Cancel button stops operation gracefully
- Results are displayed when complete
- Errors are handled gracefully

**Dependencies**: T-005, T-010, T-011

---

### T-013: Add Explicit Confirmation Dialog
**Priority**: P1  
**Summary**: Add explicit confirmation dialog before hash computation execution.

**Expected Files Touched**:
- `Sources/MediaHubUI/HashMaintenanceExecutionView.swift` (update)

**Steps**:
1. Add confirmation dialog that appears before execution:
   - Show summary of what will be computed (candidate count, limit if specified)
   - Show explicit "Confirm" and "Cancel" buttons
   - Only proceed with execution if user confirms
2. Display safety messaging: "This will compute hashes and update the index. No media files will be modified."

**Done When**:
- Confirmation dialog appears before execution
- Execution only proceeds if user confirms
- Safety messaging is clear

**Dependencies**: T-012

---

## Phase 5 — Duplicate Detection State and Orchestrator

**Plan Reference**: Phase 5 (lines 322-340)  
**Goal**: Implement duplicate detection state management and orchestrator  
**Dependencies**: None (independent from hash maintenance)

### T-014: Create Duplicate Detection State Management
**Priority**: P1  
**Summary**: Create duplicate detection state management class.

**Expected Files Touched**:
- `Sources/MediaHubUI/DuplicateDetectionState.swift` (new)

**Steps**:
1. Create `DuplicateDetectionState` class conforming to `ObservableObject` with `@MainActor`
2. Add `@Published` properties:
   - `var duplicateGroups: [DuplicateGroup]? = nil`
   - `var duplicateSummary: DuplicateSummary? = nil`
   - `var isAnalyzing: Bool = false`
   - `var errorMessage: String? = nil`

**Done When**:
- State class compiles
- All properties are `@Published` and accessible
- All properties are `@MainActor` safe

**Dependencies**: None

---

### T-015: Create Duplicate Detection Orchestrator
**Priority**: P1  
**Summary**: Create duplicate detection orchestrator with Core API integration.

**Expected Files Touched**:
- `Sources/MediaHubUI/DuplicateDetectionOrchestrator.swift` (new)

**Steps**:
1. Create `DuplicateDetectionOrchestrator` struct with static methods
2. Implement `analyzeDuplicates(libraryRoot:) async throws -> ([DuplicateGroup], DuplicateSummary)`
3. Call `DuplicateReporting.analyzeDuplicates(in: libraryRoot)` off MainActor using `Task.detached`
4. Return tuple of `([DuplicateGroup], DuplicateSummary)`
5. Handle `DuplicateReportingError` and map to user-facing error messages

**Done When**:
- Duplicate detection orchestrator calls Core API correctly
- Errors are mapped to user-facing messages
- Method returns duplicate groups and summary correctly

**Dependencies**: T-014

---

## Phase 6 — Duplicate Detection View

**Plan Reference**: Phase 6 (lines 342-361)  
**Goal**: Implement duplicate detection display UI (read-only)  
**Dependencies**: Phase 5 (orchestrator and state)

### T-016: Create Duplicate Detection View Skeleton
**Priority**: P1  
**Summary**: Create basic duplicate detection view structure.

**Expected Files Touched**:
- `Sources/MediaHubUI/DuplicateDetectionView.swift` (new)

**Steps**:
1. Create `DuplicateDetectionView` struct conforming to `View`
2. Add parameters: `libraryRootURL: URL`, `onComplete: () -> Void`
3. Add `@StateObject private var state = DuplicateDetectionState()`
4. Add basic view structure with title and placeholder content

**Done When**:
- Duplicate detection view compiles
- View structure is in place

**Dependencies**: T-014

---

### T-017: Implement Duplicate Groups Display
**Priority**: P1  
**Summary**: Display duplicate groups and file details in read-only view.

**Expected Files Touched**:
- `Sources/MediaHubUI/DuplicateDetectionView.swift` (update)

**Steps**:
1. Display duplicate groups from `state.duplicateGroups`:
   - Sort groups by hash (deterministically)
   - For each group, display:
     - Hash value (truncated for display)
     - File count
     - Total size
   - For each file in group, display:
     - Path (relative to library root)
     - File size
     - Timestamp (formatted for display)
     - Sort files by path (deterministically)
2. Display summary statistics from `state.duplicateSummary`:
   - Total duplicate groups
   - Total duplicate files
   - Total duplicate size
   - Potential savings
3. Display "No duplicates found" message when `state.duplicateGroups` is empty or nil
4. Show loading indicator when `state.isAnalyzing` is true
5. Show error message when `state.errorMessage` is not nil

**Done When**:
- Duplicate groups and files are displayed accurately
- Sorting is deterministic (by hash for groups, by path for files)
- Statistics match CLI output format
- Empty state is handled correctly

**Dependencies**: T-016

---

### T-018: Wire Duplicate Detection Orchestration to View
**Priority**: P1  
**Summary**: Connect duplicate detection view to orchestrator.

**Expected Files Touched**:
- `Sources/MediaHubUI/DuplicateDetectionView.swift` (update)

**Steps**:
1. Add "Analyze Duplicates" button or auto-trigger analysis on view appear
2. On analysis trigger:
   - Set `state.isAnalyzing = true` on MainActor
   - Call `DuplicateDetectionOrchestrator.analyzeDuplicates` off MainActor using `Task.detached`
   - Update `state.duplicateGroups` and `state.duplicateSummary` on MainActor when complete
   - Set `state.isAnalyzing = false` on MainActor
   - Handle errors and update `state.errorMessage` on MainActor

**Done When**:
- Duplicate analysis triggers correctly
- Results are displayed
- Errors are handled gracefully

**Dependencies**: T-015, T-017

---

## Phase 7 — UI Integration

**Plan Reference**: Phase 7 (lines 363-380)  
**Goal**: Integrate hash maintenance and duplicate detection workflows into main library interface  
**Dependencies**: Phases 1-6 (all components)

### T-019: Add Hash Maintenance Entry Points to Library View
**Priority**: P1  
**Summary**: Add hash maintenance entry points (preview and execution) to library detail view.

**Expected Files Touched**:
- `Sources/MediaHubUI/ContentView.swift` or library detail view (modify)

**Steps**:
1. Locate library detail view (where library status is displayed)
2. Add "Hash Maintenance" button or menu item
3. Wire to present `HashMaintenancePreviewView` sheet
4. Wire preview view "Run Hash Maintenance" button to present `HashMaintenanceExecutionView` sheet
5. Ensure hash coverage statistics refresh after hash maintenance operations complete

**Done When**:
- Hash maintenance entry points are accessible from library view
- Preview and execution workflows are wired correctly
- Hash coverage statistics update after operations

**Dependencies**: T-008, T-013, T-001

---

### T-020: Add Duplicate Detection Entry Point to Library View
**Priority**: P1  
**Summary**: Add duplicate detection entry point to library detail view.

**Expected Files Touched**:
- `Sources/MediaHubUI/ContentView.swift` or library detail view (modify)

**Steps**:
1. Locate library detail view
2. Add "View Duplicates" button or menu item
3. Wire to present `DuplicateDetectionView` sheet

**Done When**:
- Duplicate detection entry point is accessible from library view
- Duplicate detection workflow is wired correctly

**Dependencies**: T-018

---

## Phase 9 — Optional Polish (P2)

**Plan Reference**: N/A (optional)  
**Goal**: Optional UI polish and enhancements  
**Dependencies**: Phases 1-7 (all P1 tasks complete)

### T-021: [P2] Enhance Hash Coverage Display with Visual Indicators
**Priority**: P2  
**Summary**: Add visual indicators (progress bars, color coding) to hash coverage display.

**Expected Files Touched**:
- `Sources/MediaHubUI/StatusView.swift` (update)

**Steps**:
1. Add progress bar visualization for hash coverage percentage
2. Add color coding (green for high coverage, yellow for medium, red for low)
3. Add tooltips or help text explaining hash coverage

**Done When**:
- Visual indicators enhance hash coverage display
- Color coding is clear and accessible

**Dependencies**: T-001

**Note**: Optional/post-freeze. Slice is complete without Phase 9.

---

### T-022: [P2] Enhance Duplicate Detection Display with Grouping UI
**Priority**: P2  
**Summary**: Add improved grouping and filtering UI for duplicate detection view.

**Expected Files Touched**:
- `Sources/MediaHubUI/DuplicateDetectionView.swift` (update)

**Steps**:
1. Add expandable/collapsible groups for duplicate groups
2. Add filtering options (by size, by count, etc.)
3. Add sorting options (by size, by count, by hash)

**Done When**:
- Grouping UI improves duplicate detection display
- Filtering and sorting work correctly

**Dependencies**: T-017

**Note**: Optional/post-freeze. Slice is complete without Phase 9.
