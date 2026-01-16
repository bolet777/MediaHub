# Implementation Tasks: UI Create / Adopt Wizard v1

**Feature**: UI Create / Adopt Wizard v1  
**Specification**: `specs/012-ui-create-adopt-wizard-v1/spec.md`  
**Plan**: `specs/012-ui-create-adopt-wizard-v1/plan.md`  
**Slice**: 12 - Unified wizard for library creation and adoption with preview and confirmation  
**Created**: 2026-01-27

## Task Organization

Tasks are organized by phase and user story, following the implementation sequence defined in the plan. Each task is:
- Small and focused on a single deliverable (1–2 commands max per pass)
- Sequential with explicit dependencies
- Traceable to plan phases and spec requirements
- Read-only preview operations first; writes only after explicit user confirmation

---

## Phase 1 — Setup: Wizard Foundation

**Plan Reference**: Phase 1 (lines 337-346)  
**Goal**: Basic wizard structure and navigation  
**Dependencies**: None (Foundation)

### T-001: Create Wizard State Models
**Priority**: P1  
**Summary**: Create wizard state management classes for create and adopt operations.

**Expected Files Touched**:
- `Sources/MediaHubUI/CreateWizardState.swift` (new)
- `Sources/MediaHubUI/AdoptWizardState.swift` (new)

**Steps**:
1. Create `CreateWizardState` class conforming to `ObservableObject` with `@MainActor`
2. Add `@Published` properties:
   - `currentStep: WizardStep = .pathSelection`
   - `selectedPath: String? = nil`
   - `previewResult: CreatePreviewResult? = nil`
   - `isExecuting: Bool = false`
   - `errorMessage: String? = nil`
3. Create `AdoptWizardState` class conforming to `ObservableObject` with `@MainActor`
4. Add `@Published` properties:
   - `currentStep: WizardStep = .pathSelection`
   - `selectedPath: String? = nil`
   - `previewResult: AdoptPreviewResult? = nil`
   - `isExecuting: Bool = false`
   - `errorMessage: String? = nil`
5. Create `WizardStep` enum with cases: `pathSelection`, `preview`, `confirmation`, `executing`
6. Create placeholder types: `CreatePreviewResult`, `AdoptPreviewResult` (structs, will be filled in later phases)

**Done When**:
- Both state classes compile
- All properties are `@Published` and accessible
- `WizardStep` enum is defined

**Dependencies**: None

---

### T-002: Create Wizard Entry Point Views
**Priority**: P1  
**Summary**: Create basic wizard SwiftUI views with step navigation structure.

**Expected Files Touched**:
- `Sources/MediaHubUI/CreateLibraryWizard.swift` (new)
- `Sources/MediaHubUI/AdoptLibraryWizard.swift` (new)

**Steps**:
1. Create `CreateLibraryWizard` struct conforming to `View`
2. Add `@StateObject private var state = CreateWizardState()`
3. Implement basic step navigation structure (switch on `state.currentStep`)
4. Add placeholder views for each step (path selection, preview, confirmation, executing)
5. Create `AdoptLibraryWizard` struct conforming to `View`
6. Add `@StateObject private var state = AdoptWizardState()`
7. Implement same step navigation structure
8. Add placeholder views for each step
9. Implement wizard cancellation (dismiss sheet, reset state)

**Done When**:
- Both wizard views compile
- Step navigation structure is in place
- Placeholder views are visible for each step
- Cancellation works (can be tested with mock sheet presentation)

**Dependencies**: T-001

---

### T-003: Implement Wizard Step Navigation
**Priority**: P1  
**Summary**: Implement "Next" and "Back" button navigation between wizard steps.

**Expected Files Touched**:
- `Sources/MediaHubUI/CreateLibraryWizard.swift` (update)
- `Sources/MediaHubUI/AdoptLibraryWizard.swift` (update)

**Steps**:
1. Add "Next" button that advances to next step (pathSelection → preview → confirmation)
2. Add "Back" button that appears on step 2 and later (preview, confirmation)
3. Implement step validation before allowing "Next" (e.g., path must be selected before preview)
4. Update state when navigating forward/backward
5. Clear preview result when navigating back to path selection
6. Implement same navigation logic for both wizards

**Done When**:
- "Next" button advances to next step when valid
- "Back" button returns to previous step
- Step validation prevents invalid navigation
- Preview result is cleared when path changes

**Dependencies**: T-002

---

## Phase 2 — Foundational: Path Selection

**Plan Reference**: Phase 2 (lines 348-357)  
**Goal**: Folder picker and path validation  
**Dependencies**: Phase 1 (wizard foundation)

### T-004: Implement Wizard Path Selection View
**Priority**: P1  
**Summary**: Create shared path selection view with folder picker integration.

**Expected Files Touched**:
- `Sources/MediaHubUI/WizardPathSelectionView.swift` (new)

**Steps**:
1. Create `WizardPathSelectionView` struct conforming to `View`
2. Add parameters: `selectedPath: Binding<String?>`, `errorMessage: Binding<String?>`, `isForAdopt: Bool`
3. Implement folder picker button that opens `NSOpenPanel`
4. Configure `NSOpenPanel`:
   - `.canChooseDirectories = true`
   - `.canChooseFiles = false`
   - `.allowsMultipleSelection = false`
5. On folder selection, update `selectedPath` binding
6. Display selected path in text field or label
7. Display `errorMessage` if present (inline error message)

**Done When**:
- Folder picker opens and allows directory selection
- Selected path is displayed
- Error message is displayed when present
- Works for both create and adopt wizards (via `isForAdopt` parameter)

**Dependencies**: T-002

---

### T-005: Implement Path Validation Logic
**Priority**: P1  
**Summary**: Create path validation service that checks path validity, permissions, and library status.

**Expected Files Touched**:
- `Sources/MediaHubUI/WizardPathValidator.swift` (new)

**Steps**:
1. Create `WizardPathValidator` struct with static validation methods
2. Implement `validatePath(_ path: String, isForAdopt: Bool) -> ValidationResult`
3. Validation checks:
   - Path exists and is accessible
   - Path is a directory (for adopt) or can be created (for create)
   - Write permissions available
   - Check if path already contains MediaHub library (use `LibraryStructureValidator.isLibraryStructure` or `LibraryAdopter.isAlreadyAdopted`)
   - For create: If path already contains library, return `.invalid("This location already contains a MediaHub library")`
   - For adopt: If path already contains library, return `.alreadyAdopted` (idempotent case, not an error)
   - For create: Check if path contains files but is not a library
4. Return `ValidationResult` enum with cases: `.valid`, `.invalid(String)` (error message), `.alreadyAdopted` (for adopt operations only, idempotent case)
5. Create user-facing error messages for each validation failure

**Done When**:
- Path validation works for both create and adopt operations
- All validation checks are implemented
- Clear error messages are returned for each failure case
- Library detection works correctly
- Already-adopted libraries are detected during validation (primary path)
- For adopt: Already-adopted returns `.alreadyAdopted` (idempotent, not error)
- For create: Already-adopted returns `.invalid` (error)

**Dependencies**: T-004

---

### T-006: Integrate Path Selection with Wizard State
**Priority**: P1  
**Summary**: Connect path selection view to wizard state with validation.

**Expected Files Touched**:
- `Sources/MediaHubUI/CreateLibraryWizard.swift` (update)
- `Sources/MediaHubUI/AdoptLibraryWizard.swift` (update)

**Steps**:
1. Replace placeholder path selection view with `WizardPathSelectionView`
2. Bind `state.selectedPath` and `state.errorMessage` to path selection view
3. On path selection, call `WizardPathValidator.validatePath`
4. Handle validation results:
   - If `.valid`: Clear error message, enable "Next" button
   - If `.invalid(String)`: Set `state.errorMessage`, disable "Next" button
   - If `.alreadyAdopted` (for adopt only): Show idempotent message (not error), enable "Next" button to proceed to open existing library
5. Enable "Next" button only when path is valid or already-adopted (for adopt)
6. Clear error message when path changes
7. Implement same integration for both wizards (create shows error for already-adopted, adopt shows message)

**Done When**:
- Path selection updates wizard state
- Validation runs on path selection
- Error messages are displayed in wizard
- "Next" button is enabled only when path is valid

**Dependencies**: T-004, T-005

---

## Phase 3 — User Story 1: Create a New Library via Wizard

**Plan Reference**: Phases 3, 4, 6, 7, 8 (lines 359-418)  
**Goal**: Complete create library wizard with preview, confirmation, and execution  
**Dependencies**: Phase 2 (path selection)  
**Independent Test**: Launch wizard, select folder, preview, confirm, create library

### T-007: [US1] Implement Create Preview Result Model
**Priority**: P1  
**Summary**: Create data model for create preview results.

**Expected Files Touched**:
- `Sources/MediaHubUI/CreatePreviewResult.swift` (new)

**Steps**:
1. Create `CreatePreviewResult` struct
2. Add properties:
   - `metadataLocation: String` (path to `.mediahub/library.json`)
   - `libraryId: String` (simulated)
   - `libraryVersion: String` (default "1.0")
3. Make struct `Codable` and `Equatable` for testing

**Done When**:
- `CreatePreviewResult` struct compiles
- All properties are defined
- Can be used in `CreateWizardState.previewResult`

**Dependencies**: T-001

---

### T-008: [US1] Implement Create Preview Simulator
**Priority**: P1  
**Summary**: Create in-memory preview simulation for create operations.

**Expected Files Touched**:
- `Sources/MediaHubUI/CreatePreviewSimulator.swift` (new)

**Steps**:
1. Create `CreatePreviewSimulator` struct with static method `simulatePreview(at path: String) -> CreatePreviewResult?`
2. Use `LibraryPathValidator.validatePath(path:)` to validate path (read-only)
3. Generate simulated library ID using `LibraryIdentifierGenerator.generate()` (same as Core API)
4. Create simulated metadata structure:
   - Metadata location: `path + "/.mediahub/library.json"`
   - Library version: "1.0"
5. Return `CreatePreviewResult` with simulated data
6. Return `nil` if validation fails (caller handles error)

**Done When**:
- Preview simulation works without calling Core API
- Simulated preview matches what Core API would create (same libraryId generation, same structure)
- Validation is performed (read-only)
- Returns `nil` on validation failure

**Dependencies**: T-005, T-007

---

### T-009: [US1] Implement Preview Display View
**Priority**: P1  
**Summary**: Create preview view that displays what will be created.

**Expected Files Touched**:
- `Sources/MediaHubUI/WizardPreviewView.swift` (new)

**Steps**:
1. Create `WizardPreviewView` struct conforming to `View`
2. Add parameters: `previewResult: CreatePreviewResult?`, `isForAdopt: Bool`
3. Display "Preview" badge/indicator at top
4. Display preview information:
   - Metadata location (`.mediahub/library.json` path)
   - Library ID (for create) or baseline scan summary (for adopt, will be added in US2)
   - Operation type ("Create Library" or "Adopt Library")
5. Show loading state while preview is being generated
6. Show error message if preview generation fails

**Done When**:
- Preview view displays preview information
- "Preview" indicator is visible
- Loading and error states are handled
- Works for both create and adopt (via `isForAdopt` parameter)

**Dependencies**: T-007

---

### T-010: [US1] Integrate Create Preview with Wizard Flow
**Priority**: P1  
**Summary**: Connect preview simulation to create wizard.

**Expected Files Touched**:
- `Sources/MediaHubUI/CreateLibraryWizard.swift` (update)

**Steps**:
1. When user navigates to preview step, call `CreatePreviewSimulator.simulatePreview`
2. Update `state.previewResult` with preview result
3. Update `state.errorMessage` if preview generation fails
4. Replace placeholder preview view with `WizardPreviewView`
5. Pass `state.previewResult` to preview view
6. Enable "Next" button only when preview is available
7. Clear preview result when path changes (navigate back)

**Done When**:
- Preview is generated when navigating to preview step
- Preview view displays preview information
- Error handling works (shows error if preview fails)
- Preview is cleared when path changes

**Dependencies**: T-008, T-009

---

### T-011: [US1] Implement Confirmation Dialog View
**Priority**: P1  
**Summary**: Create confirmation view with summary and explicit confirm/cancel buttons.

**Expected Files Touched**:
- `Sources/MediaHubUI/WizardConfirmationView.swift` (new)

**Steps**:
1. Create `WizardConfirmationView` struct conforming to `View`
2. Add parameters: `previewResult: CreatePreviewResult?`, `isForAdopt: Bool`, `onConfirm: () -> Void`, `onCancel: () -> Void`
3. Display summary of what will be created:
   - Metadata location
   - Operation type
   - Preview information (library ID for create, baseline scan for adopt)
4. For adopt: Display "No media files will be modified; only .mediahub metadata will be created"
5. Add "Create"/"Adopt" button (calls `onConfirm`)
6. Add "Cancel" button (calls `onCancel`)
7. Disable confirm button when `isExecuting` is true

**Done When**:
- Confirmation view displays summary
- Confirm and cancel buttons work
- Safety messaging is shown for adopt operations
- Confirm button is disabled during execution

**Dependencies**: T-007

---

### T-012: [US1] Integrate Confirmation Dialog with Create Wizard
**Priority**: P1  
**Summary**: Connect confirmation view to create wizard flow.

**Expected Files Touched**:
- `Sources/MediaHubUI/CreateLibraryWizard.swift` (update)

**Steps**:
1. Replace placeholder confirmation view with `WizardConfirmationView`
2. Pass `state.previewResult` to confirmation view
3. Implement `onConfirm` handler: set `state.currentStep = .executing`
4. Implement `onCancel` handler: close wizard, reset state
5. Display confirmation view when `state.currentStep == .confirmation`

**Done When**:
- Confirmation view is displayed at confirmation step
- Confirm button proceeds to execution step
- Cancel button closes wizard
- Preview information is displayed in confirmation

**Dependencies**: T-011

---

### T-013: [US1] Implement Custom Confirmation Handler
**Priority**: P1  
**Summary**: Create custom confirmation handler that bypasses Core-level confirmations.

**Expected Files Touched**:
- `Sources/MediaHubUI/WizardConfirmationHandler.swift` (new)

**Steps**:
1. Create `WizardConfirmationHandler` struct conforming to `LibraryCreationConfirmationHandler`
2. Implement `requestConfirmationForNonEmptyDirectory(at:completion:)`:
   - Immediately call `completion(true)` (auto-confirm, wizard handles confirmation)
3. Implement `requestConfirmationForExistingLibrary(at:completion:)`:
   - Immediately call `completion(false)` (don't open existing library, wizard shows error)
4. Add tests to verify handler bypasses confirmations correctly

**Done When**:
- Custom handler conforms to `LibraryCreationConfirmationHandler` protocol
- Both confirmation methods immediately call completion callbacks
- Handler bypasses Core-level confirmations (wizard handles all confirmation in UI)

**Dependencies**: None (uses existing Core API protocol)

---

### T-014: [US1] Create Create Execution Orchestrator Skeleton
**Priority**: P1  
**Summary**: Create orchestrator struct skeleton with method signature.

**Expected Files Touched**:
- `Sources/MediaHubUI/CreateExecutionOrchestrator.swift` (new)

**Steps**:
1. Create `CreateExecutionOrchestrator` struct
2. Add static method `executeCreate(at path: String, completion: @escaping (Result<LibraryMetadata, Error>) -> Void)`
3. Add placeholder implementation that immediately calls `completion(.failure(NSError(domain: "MediaHub", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not implemented"])))`

**Done When**:
- Orchestrator struct compiles
- Method signature is correct
- Placeholder implementation exists

**Dependencies**: T-013

---

### T-014b: [US1] Integrate Core API Call in Create Execution Orchestrator
**Priority**: P1  
**Summary**: Add Core API invocation to orchestrator.

**Expected Files Touched**:
- `Sources/MediaHubUI/CreateExecutionOrchestrator.swift` (update)

**Steps**:
1. Create `WizardConfirmationHandler` instance
2. Create `LibraryCreator` with custom confirmation handler
3. Invoke `LibraryCreator.createLibrary(at:libraryVersion:completion:)` off MainActor (wrap in `Task.detached`)
4. Handle completion callback:
   - On success: call completion with `.success(metadata)`
   - On failure: call completion with `.failure(error)` (pass through raw error for now)

**Done When**:
- Core API is invoked correctly
- Custom confirmation handler is used
- Async operation is handled off MainActor
- Success and failure callbacks are wired

**Dependencies**: T-014

---

### T-014c: [US1] Map Errors to User-Facing Messages in Create Execution Orchestrator
**Priority**: P1  
**Summary**: Map Core API errors to user-facing error messages.

**Expected Files Touched**:
- `Sources/MediaHubUI/CreateExecutionOrchestrator.swift` (update)

**Steps**:
1. Create helper function `mapError(_ error: Error) -> Error` that converts `LibraryCreationError` to user-facing `NSError`
2. Map all `LibraryCreationError` cases to clear, actionable messages
3. Update failure callback to call `completion(.failure(mapError(error)))`

**Done When**:
- All `LibraryCreationError` cases are mapped to user-facing messages
- Error messages are clear and actionable
- Failure callback uses mapped errors

**Dependencies**: T-014b

---

### T-015: [US1] Integrate Create Execution with Wizard
**Priority**: P1  
**Summary**: Connect execution orchestrator to create wizard and handle success/failure.

**Expected Files Touched**:
- `Sources/MediaHubUI/CreateLibraryWizard.swift` (update)

**Steps**:
1. When user confirms, set `state.currentStep = .executing` and `state.isExecuting = true`
2. Call `CreateExecutionOrchestrator.executeCreate` off MainActor
3. On success:
   - Close wizard (dismiss sheet)
   - Open newly created library (call completion handler with library path)
   - Reset wizard state
4. On failure:
   - Set `state.errorMessage` with user-facing error message
   - Set `state.currentStep = .confirmation` (allow retry)
   - Set `state.isExecuting = false`
5. Show progress indicator during execution (when `state.isExecuting == true`)

**Done When**:
- Execution is triggered on confirmation
- Progress indicator is shown during execution
- Success closes wizard and opens library
- Failure shows error and allows retry
- Wizard state is managed correctly

**Dependencies**: T-014c

---

## Phase 4 — User Story 2: Adopt Existing Directory via Wizard

**Plan Reference**: Phases 3, 5, 6, 9 (lines 359-430)  
**Goal**: Complete adopt library wizard with preview, confirmation, and execution  
**Dependencies**: Phase 2 (path selection), Phase 3 (preview display, confirmation view)  
**Independent Test**: Launch wizard, select directory, preview with baseline scan, confirm, adopt library

### T-016: [US2] Implement Adopt Preview Result Model
**Priority**: P1  
**Summary**: Create data model for adopt preview results.

**Expected Files Touched**:
- `Sources/MediaHubUI/AdoptPreviewResult.swift` (new)

**Steps**:
1. Create `AdoptPreviewResult` struct
2. Add properties:
   - `metadataLocation: String` (path to `.mediahub/library.json`)
   - `libraryId: String`
   - `libraryVersion: String`
   - `baselineScanSummary: BaselineScanSummary` (from Core API)
3. Make struct `Codable` and `Equatable` for testing

**Done When**:
- `AdoptPreviewResult` struct compiles
- All properties are defined
- Can be used in `AdoptWizardState.previewResult`

**Dependencies**: T-001

---

### T-017: [US2] Implement Adopt Preview Orchestrator
**Priority**: P1  
**Summary**: Create orchestrator that invokes Core API dry-run for adopt preview.

**Expected Files Touched**:
- `Sources/MediaHubUI/AdoptPreviewOrchestrator.swift` (new)

**Steps**:
1. Create `AdoptPreviewOrchestrator` struct with static method `generatePreview(at path: String) async throws -> AdoptPreviewResult`
2. Wrap Core API call in async context (since it's sync throwing):
   ```swift
   do {
       let result = try await Task.detached {
           try LibraryAdopter.adoptLibrary(at: path, dryRun: true)
       }.value
       // Convert LibraryAdoptionResult to AdoptPreviewResult
       return AdoptPreviewResult(...)
   } catch LibraryAdoptionError.alreadyAdopted {
       // Defensive catch: if validation (T-005) missed it, open existing library for preview
       let openedLibrary = try await Task.detached {
           try LibraryOpener().openLibrary(at: path)
       }.value
       // Construct preview result from opened library (idempotent case)
       // Use empty baseline scan for preview (library already exists)
       let baselineScan = BaselineScanSummary(fileCount: 0, filePaths: [])
       return AdoptPreviewResult(
           metadataLocation: path + "/.mediahub/library.json",
           libraryId: openedLibrary.metadata.libraryId,
           libraryVersion: openedLibrary.metadata.libraryVersion,
           baselineScanSummary: baselineScan
       )
   }
   ```
3. Convert `LibraryAdoptionResult` to `AdoptPreviewResult`:
   - Extract metadata location, library ID, version
   - Extract baseline scan summary
4. Return `AdoptPreviewResult`
5. Propagate other errors (let them throw)

**Done When**:
- Preview orchestrator invokes Core API dry-run correctly
- Async operation is handled off MainActor
- Preview result is converted correctly
- Idempotent already-adopted case is handled defensively (opens existing library for preview)
- Other errors are propagated

**Dependencies**: T-016

---

### T-018: [US2] Update Preview View for Adopt Operations
**Priority**: P1  
**Summary**: Extend preview view to display baseline scan summary for adopt operations.

**Expected Files Touched**:
- `Sources/MediaHubUI/WizardPreviewView.swift` (update)

**Steps**:
1. Update `WizardPreviewView` to accept `AdoptPreviewResult?` in addition to `CreatePreviewResult?`
2. When `isForAdopt == true` and `adoptPreviewResult` is provided:
   - Display baseline scan summary (file count, scan scope)
   - Display metadata location
   - Display library ID
3. Keep existing create preview display logic

**Done When**:
- Preview view displays baseline scan summary for adopt operations
- Both create and adopt previews work correctly
- Preview information is displayed clearly

**Dependencies**: T-009, T-016

---

### T-019: [US2] Integrate Adopt Preview with Wizard Flow
**Priority**: P1  
**Summary**: Connect preview orchestrator to adopt wizard.

**Expected Files Touched**:
- `Sources/MediaHubUI/AdoptLibraryWizard.swift` (update)

**Steps**:
1. When user navigates to preview step, call `AdoptPreviewOrchestrator.generatePreview` off MainActor
2. Update `state.previewResult` with preview result
3. Update `state.errorMessage` if preview generation fails
4. Replace placeholder preview view with `WizardPreviewView`
5. Pass `state.previewResult` to preview view (as `AdoptPreviewResult`)
6. Enable "Next" button only when preview is available
7. Clear preview result when path changes (navigate back)

**Done When**:
- Preview is generated when navigating to preview step
- Preview view displays preview information including baseline scan
- Error handling works (shows error if preview fails)
- Preview is cleared when path changes

**Dependencies**: T-017, T-018

---

### T-020: [US2] Update Confirmation View for Adopt Operations
**Priority**: P1  
**Summary**: Extend confirmation view to display adopt-specific information.

**Expected Files Touched**:
- `Sources/MediaHubUI/WizardConfirmationView.swift` (update)

**Steps**:
1. Update `WizardConfirmationView` to accept `AdoptPreviewResult?` in addition to `CreatePreviewResult?`
2. When `isForAdopt == true` and `adoptPreviewResult` is provided:
   - Display baseline scan summary in confirmation summary
   - Display "No media files will be modified; only .mediahub metadata will be created" message prominently
3. Keep existing create confirmation display logic

**Done When**:
- Confirmation view displays adopt-specific information
- Safety messaging is shown prominently for adopt operations
- Both create and adopt confirmations work correctly

**Dependencies**: T-011, T-016

---

### T-021: [US2] Integrate Confirmation Dialog with Adopt Wizard
**Priority**: P1  
**Summary**: Connect confirmation view to adopt wizard flow.

**Expected Files Touched**:
- `Sources/MediaHubUI/AdoptLibraryWizard.swift` (update)

**Steps**:
1. Replace placeholder confirmation view with `WizardConfirmationView`
2. Pass `state.previewResult` to confirmation view (as `AdoptPreviewResult`)
3. Implement `onConfirm` handler: set `state.currentStep = .executing`
4. Implement `onCancel` handler: close wizard, reset state
5. Display confirmation view when `state.currentStep == .confirmation`

**Done When**:
- Confirmation view is displayed at confirmation step
- Confirm button proceeds to execution step
- Cancel button closes wizard
- Preview information including baseline scan is displayed in confirmation

**Dependencies**: T-020

---

### T-022: [US2] Create Adopt Execution Orchestrator Skeleton
**Priority**: P1  
**Summary**: Create orchestrator struct skeleton with method signature.

**Expected Files Touched**:
- `Sources/MediaHubUI/AdoptExecutionOrchestrator.swift` (new)

**Steps**:
1. Create `AdoptExecutionOrchestrator` struct
2. Add static method `executeAdopt(at path: String) async throws -> LibraryAdoptionResult`
3. Add placeholder implementation that immediately throws `NSError(domain: "MediaHub", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not implemented"])`

**Done When**:
- Orchestrator struct compiles
- Method signature is correct
- Placeholder implementation exists

**Dependencies**: T-016

---

### T-022b: [US2] Integrate Core API Call with Already-Adopted Handling in Adopt Execution Orchestrator
**Priority**: P1  
**Summary**: Add Core API invocation with already-adopted error handling.

**Expected Files Touched**:
- `Sources/MediaHubUI/AdoptExecutionOrchestrator.swift` (update)

**Steps**:
1. Wrap Core API call in async context (since it's sync throwing):
   ```swift
   do {
       return try await Task.detached {
           try LibraryAdopter.adoptLibrary(at: path, dryRun: false)
       }.value
   } catch LibraryAdoptionError.alreadyAdopted {
       // Defensive catch: if validation missed it, open existing library and return its metadata
       let openedLibrary = try await Task.detached {
           try LibraryOpener().openLibrary(at: path)
       }.value
       // Construct LibraryAdoptionResult from opened library metadata
       // Use empty baseline scan (library already exists, no new scan needed)
       let baselineScan = BaselineScanSummary(fileCount: 0, filePaths: [])
       return LibraryAdoptionResult(
           metadata: openedLibrary.metadata,
           baselineScan: baselineScan,
           indexCreated: false,
           indexSkippedReason: "already_adopted",
           indexMetadata: nil
       )
   }
   ```
2. Handle `LibraryAdoptionError.alreadyAdopted` by catching it, opening the existing library, and constructing a `LibraryAdoptionResult` from the opened library's metadata (idempotent success case)
3. Propagate other errors (let them throw, pass through raw errors for now)

**Done When**:
- Core API is invoked correctly
- Async operation is handled off MainActor
- Idempotent already-adopted case is handled correctly: catches error, opens existing library, returns result with its metadata (not treated as error)
- Defensive handling works if validation (T-005) missed already-adopted detection
- Other errors are propagated

**Dependencies**: T-022

---

### T-022c: [US2] Map Errors to User-Facing Messages in Adopt Execution Orchestrator
**Priority**: P1  
**Summary**: Map Core API errors to user-facing error messages.

**Expected Files Touched**:
- `Sources/MediaHubUI/AdoptExecutionOrchestrator.swift` (update)

**Steps**:
1. Create helper function `mapError(_ error: Error) -> Error` that converts `LibraryAdoptionError` to user-facing `NSError`
2. Map all `LibraryAdoptionError` cases to clear, actionable messages (except `alreadyAdopted` which is handled in T-022b)
3. Wrap Core API call in try-catch that maps errors before rethrowing

**Done When**:
- All `LibraryAdoptionError` cases are mapped to user-facing messages (except `alreadyAdopted`)
- Error messages are clear and actionable
- Errors are mapped before propagation

**Dependencies**: T-022b

---

### T-023: [US2] Integrate Adopt Execution with Wizard
**Priority**: P1  
**Summary**: Connect execution orchestrator to adopt wizard and handle success/failure.

**Expected Files Touched**:
- `Sources/MediaHubUI/AdoptLibraryWizard.swift` (update)

**Steps**:
1. When user confirms, set `state.currentStep = .executing` and `state.isExecuting = true`
2. Call `AdoptExecutionOrchestrator.executeAdopt` off MainActor
3. On success:
   - Close wizard (dismiss sheet)
   - Open newly adopted library (call completion handler with library path)
   - Reset wizard state
4. On failure:
   - Set `state.errorMessage` with user-facing error message
   - Set `state.currentStep = .confirmation` (allow retry)
   - Set `state.isExecuting = false`
5. Handle idempotent already-adopted case: if orchestrator returns result with `indexSkippedReason: "already_adopted"`, show idempotent message (not error), close wizard, open library
6. Show progress indicator during execution (when `state.isExecuting == true`)

**Done When**:
- Execution is triggered on confirmation
- Progress indicator is shown during execution
- Success closes wizard and opens library
- Failure shows error and allows retry
- Idempotent already-adopted case is handled correctly
- Wizard state is managed correctly

**Dependencies**: T-022c

---

## Phase 5 — User Story 3: Preview Operations with Dry-Run

**Plan Reference**: Phases 3, 4, 5 (lines 359-387)  
**Goal**: Ensure preview operations show accurate information without file system writes  
**Dependencies**: Phases 3, 4 (preview implementations)  
**Independent Test**: Verify preview shows accurate information and performs zero writes

**Note**: Most preview functionality is implemented in US1 and US2 phases. This phase focuses on validation and testing.

### T-024: [US3] Add Preview Indicator to Preview View
**Priority**: P1  
**Summary**: Ensure "Preview" badge/indicator is clearly visible in preview view.

**Expected Files Touched**:
- `Sources/MediaHubUI/WizardPreviewView.swift` (update)

**Steps**:
1. Ensure "Preview" badge/indicator is prominently displayed at top of preview view
2. Use visual styling (badge, color, icon) to make it clear this is a preview
3. Add text: "This is a preview" or similar messaging
4. Verify indicator is visible for both create and adopt previews

**Done When**:
- "Preview" indicator is clearly visible
- Users can easily identify preview vs. actual execution
- Works for both create and adopt operations

**Dependencies**: T-009

---

### T-025: [US3] Verify Preview Accuracy for Create Operations
**Priority**: P1  
**Summary**: Manual verification that create preview simulation matches actual execution results.

**Expected Files Touched**:
- No code changes (manual verification only)

**Steps**:
1. Manually test: Generate preview for a path using wizard
2. Manually test: Execute actual library creation for same path
3. Manually verify: Compare preview metadata (library ID, version, location) with actual created metadata
4. Manually verify: Preview matches execution results
5. Manually test: Various path scenarios (empty directory, non-empty directory)

**Done When**:
- Manual verification confirms preview simulation matches actual execution results
- Manual verification confirms library ID generation is consistent
- Manual verification confirms metadata structure matches
- Verification documented (no code commit required)

**Dependencies**: T-008, T-014c

---

### T-026: [US3] Verify Preview Accuracy for Adopt Operations
**Priority**: P1  
**Summary**: Manual verification that adopt preview (dry-run) matches actual execution results.

**Expected Files Touched**:
- No code changes (manual verification only)

**Steps**:
1. Manually test: Generate preview (dry-run) for a directory using wizard
2. Manually test: Execute actual library adoption for same directory
3. Manually verify: Compare preview metadata and baseline scan with actual adoption results
4. Manually verify: Preview matches execution results
5. Manually test: Various directory scenarios (empty, with media files, already adopted)

**Done When**:
- Manual verification confirms preview (dry-run) matches actual execution results
- Manual verification confirms baseline scan summary is accurate
- Manual verification confirms metadata structure matches
- Verification documented (no code commit required)

**Dependencies**: T-017, T-022c

---

## Phase 6 — User Story 4: Explicit Confirmation Dialogs

**Plan Reference**: Phase 6 (lines 389-397)  
**Goal**: Ensure explicit confirmation dialogs are displayed before execution  
**Dependencies**: Phases 3, 4 (confirmation views)  
**Independent Test**: Verify confirmation dialogs appear with accurate information

**Note**: Most confirmation functionality is implemented in US1 and US2 phases. This phase focuses on validation and polish.

### T-027: [US4] Verify Confirmation Dialog Displays Accurate Information
**Priority**: P1  
**Summary**: Manual verification that confirmation dialog shows correct summary.

**Expected Files Touched**:
- No code changes (manual verification only)

**Steps**:
1. Manually verify: Confirmation dialog displays:
   - Metadata location (accurate path)
   - Operation type (Create/Adopt)
   - Preview information (library ID for create, baseline scan for adopt)
2. Manually verify: For adopt, "No media files will be modified" message is displayed
3. Manually test: Various scenarios to ensure information is always accurate

**Done When**:
- Manual verification confirms confirmation dialog shows accurate information
- Manual verification confirms safety messaging is displayed for adopt operations
- Manual verification confirms information matches preview
- Verification documented (no code commit required)

**Dependencies**: T-011, T-020

---

### T-028: [US4] Verify Confirmation Button Behavior
**Priority**: P1  
**Summary**: Manual verification that confirmation buttons work correctly.

**Expected Files Touched**:
- No code changes (manual verification only)

**Steps**:
1. Manually verify: "Create"/"Adopt" button proceeds with execution when clicked
2. Manually verify: "Cancel" button closes wizard without creating files
3. Manually verify: Confirm button is disabled when `isExecuting == true`
4. Manually verify: Progress indicator is shown during execution
5. Manually test: Duplicate operations are prevented (button disabled during execution)

**Done When**:
- Manual verification confirms confirmation buttons work correctly
- Manual verification confirms button is disabled during execution
- Manual verification confirms progress indicator is shown
- Manual verification confirms duplicate operations are prevented
- Verification documented (no code commit required)

**Dependencies**: T-011, T-015, T-023

---

## Phase 7 — User Story 5: Wizard Navigation and Error Handling

**Plan Reference**: Phase 1, 2 (lines 337-357)  
**Goal**: Ensure wizard navigation and error handling work correctly  
**Dependencies**: All previous phases  
**Independent Test**: Navigate wizard, trigger errors, verify error handling

### T-029: [US5] Verify Back Button Navigation
**Priority**: P2  
**Summary**: Manual verification that "Back" button appears and works correctly.

**Expected Files Touched**:
- No code changes (manual verification only)

**Steps**:
1. Manually verify: "Back" button appears on preview step (step 2)
2. Manually verify: "Back" button appears on confirmation step (step 3)
3. Manually verify: "Back" button does not appear on path selection step (step 1)
4. Manually verify: "Back" button returns to previous step correctly
5. Manually verify: Preview and confirmation information updates when navigating back and changing path

**Done When**:
- Manual verification confirms "Back" button appears on correct steps
- Manual verification confirms navigation works correctly
- Manual verification confirms state updates correctly when navigating back
- Verification documented (no code commit required)

**Dependencies**: T-003

---

### T-030: [US5] Verify Error Handling and Recovery
**Priority**: P2  
**Summary**: Manual verification that errors are displayed clearly and users can retry.

**Expected Files Touched**:
- No code changes (manual verification only)

**Steps**:
1. Manually test: Path validation errors (invalid path, permission denied, already exists)
2. Manually verify: Clear, user-facing error messages are displayed
3. Manually verify: Errors are displayed inline (not blocking alerts)
4. Manually verify: User can correct errors and retry without restarting wizard
5. Manually test: Execution errors (permission denied, etc.)
6. Manually verify: Error recovery works correctly

**Done When**:
- Manual verification confirms all error cases are handled with clear messages
- Manual verification confirms users can retry without restarting wizard
- Manual verification confirms error display is user-friendly
- Verification documented (no code commit required)

**Dependencies**: T-005, T-006, T-015, T-023

---

### T-031: [US5] Verify Cancellation at Any Step
**Priority**: P2  
**Summary**: Manual verification that cancellation works at any step with zero file modifications.

**Expected Files Touched**:
- No code changes (manual verification only)

**Steps**:
1. Manually test: Cancellation at path selection step
2. Manually test: Cancellation at preview step
3. Manually test: Cancellation at confirmation step
4. Manually verify: Cancellation closes wizard and resets state
5. Manually verify: No files are created or modified on cancellation (check file system)
6. Manually verify: Wizard returns to previous screen (library list or empty state)

**Done When**:
- Manual verification confirms cancellation works at all steps
- Manual verification confirms no files are created or modified on cancellation
- Manual verification confirms wizard state is reset correctly
- Verification documented (no code commit required)

**Dependencies**: T-002, T-003

---

## Phase 8 — Integration: App Shell Integration

**Plan Reference**: Phase 10 (lines 432-440)  
**Goal**: Integrate wizards with existing UI shell  
**Dependencies**: All previous phases  
**Independent Test**: Launch app, click "Create Library" or "Adopt Library", verify wizards open and work

### T-032: Add Wizard Entry Points to ContentView
**Priority**: P1  
**Summary**: Add "Create Library" and "Adopt Library" actions to main content view.

**Expected Files Touched**:
- `Sources/MediaHubUI/ContentView.swift` (update)

**Steps**:
1. Add "Create Library" button or menu item to `ContentView`
2. Add "Adopt Library" button or menu item to `ContentView`
3. Add `@State` variables for wizard sheet presentation:
   - `@State private var showCreateWizard = false`
   - `@State private var showAdoptWizard = false`
4. Present `CreateLibraryWizard` as sheet when `showCreateWizard == true`
5. Present `AdoptLibraryWizard` as sheet when `showAdoptWizard == true`

**Done When**:
- "Create Library" and "Adopt Library" actions are visible in UI
- Wizards open as sheets when actions are clicked
- Sheet presentation works correctly

**Dependencies**: T-002

---

### T-033: Handle Wizard Completion and Library Opening
**Priority**: P1  
**Summary**: Open newly created/adopted library after wizard completion.

**Expected Files Touched**:
- `Sources/MediaHubUI/ContentView.swift` (update)
- `Sources/MediaHubUI/CreateLibraryWizard.swift` (update)
- `Sources/MediaHubUI/AdoptLibraryWizard.swift` (update)

**Steps**:
1. Add completion handler parameter to both wizards: `onCompletion: (String) -> Void` (library path)
2. In create wizard, call completion handler with library path on success
3. In adopt wizard, call completion handler with library path on success
4. In `ContentView`, implement completion handler:
   - Close wizard sheet
   - Open library using `LibraryStatusService.openLibrary(at:)`
   - Update `AppState` with opened library
   - Display library status view

**Done When**:
- Newly created/adopted libraries are automatically opened
- Library status view is displayed after wizard completion
- App state is updated correctly

**Dependencies**: T-015, T-023, T-032

---

### T-034: Update AppState for Wizard Integration
**Priority**: P1  
**Summary**: Ensure AppState supports wizard integration (if needed).

**Expected Files Touched**:
- `Sources/MediaHubUI/AppState.swift` (update, if needed)

**Steps**:
1. Review `AppState` from Slice 11
2. Verify it supports opening libraries (should already exist)
3. Add any needed properties for wizard state (if not already covered)
4. Ensure wizard completion can trigger library opening

**Done When**:
- AppState supports wizard integration
- Library opening works after wizard completion

**Dependencies**: T-033

---

## Phase 9 — Polish & Cross-Cutting Concerns (Optional/Post-Freeze)

**Plan Reference**: All phases  
**Goal**: Final polish, error handling, and cross-cutting concerns  
**Dependencies**: All previous phases  
**Note**: Phase 9 tasks are optional and can be completed post-freeze. Slice 12 is complete without Phase 9.

### T-035: Add Progress Indicators During Execution
**Priority**: P2 (Optional)  
**Summary**: Ensure progress indicators are shown during all async operations.

**Expected Files Touched**:
- `Sources/MediaHubUI/CreateLibraryWizard.swift` (update, if needed)
- `Sources/MediaHubUI/AdoptLibraryWizard.swift` (update, if needed)

**Steps**:
1. Verify progress indicators are shown during:
   - Preview generation (for adopt, async)
   - Execution (create and adopt)
2. Use SwiftUI `ProgressView` or similar
3. Disable buttons during async operations
4. Test with slow operations to verify progress indicators work

**Done When**:
- Progress indicators are shown during all async operations
- Buttons are disabled during operations
- User experience is smooth
- Changes committed (or explicit "no changes required" if already implemented)

**Dependencies**: T-010, T-015, T-019, T-023

---

### T-036: Verify Error Message Mapping
**Priority**: P2 (Optional)  
**Summary**: Manual verification that all Core API errors are mapped to user-facing messages.

**Expected Files Touched**:
- No code changes (manual verification only)

**Steps**:
1. Review all `LibraryCreationError` cases in `CreateExecutionOrchestrator`
2. Review all `LibraryAdoptionError` cases in `AdoptExecutionOrchestrator`
3. Manually verify: All errors are mapped to clear, user-facing messages
4. Manually test: Error scenarios to verify messages are helpful
5. Manually verify: Error messages are actionable (tell user what to do)

**Done When**:
- Manual verification confirms all Core API errors are mapped to user-facing messages
- Manual verification confirms error messages are clear and actionable
- Manual verification confirms error handling is comprehensive
- Verification documented (no code commit required)

**Dependencies**: T-014c, T-022c

---

### T-037: Verify Deterministic Behavior
**Priority**: P2 (Optional)  
**Summary**: Manual verification that wizard operations are deterministic.

**Expected Files Touched**:
- No code changes (manual verification only)

**Steps**:
1. Manually test: Preview operations - same path produces same preview
2. Manually test: Path validation - same path produces same validation result
3. Manually test: Error messages - same error conditions produce same messages
4. Manually verify: Library ID generation is deterministic (for create preview)
5. Manually test: Multiple wizard runs with same inputs

**Done When**:
- Manual verification confirms preview operations are deterministic
- Manual verification confirms path validation is deterministic
- Manual verification confirms error messages are deterministic
- Manual verification confirms wizard behavior is consistent
- Verification documented (no code commit required)

**Dependencies**: All previous tasks

---

### T-038: Verify Zero Writes During Preview
**Priority**: P2 (Optional)  
**Summary**: Manual verification that preview operations perform zero file system writes.

**Expected Files Touched**:
- No code changes (manual verification only)

**Steps**:
1. Manually test: Create preview - verify no files created (check file system before/after)
2. Manually test: Adopt preview (dry-run) - verify no files created (check file system before/after)
3. Manually test: Various paths and scenarios
4. Manually verify: Directory state before and after preview (no changes)

**Done When**:
- Manual verification confirms preview operations perform zero writes
- Manual verification confirms safety guarantee is maintained
- Verification documented (no code commit required)

**Dependencies**: T-008, T-017

---

## Dependencies

### User Story Completion Order

1. **Phase 1 (Setup)**: Must complete before all user stories
2. **Phase 2 (Foundational)**: Must complete before user stories (path selection is first step)
3. **Phase 3 (US1 - Create)**: Can be implemented independently after Phase 2
4. **Phase 4 (US2 - Adopt)**: Can be implemented independently after Phase 2 (shares preview/confirmation views from US1)
5. **Phase 5 (US3 - Preview)**: Mostly validation, depends on US1 and US2
6. **Phase 6 (US4 - Confirmation)**: Mostly validation, depends on US1 and US2
7. **Phase 7 (US5 - Navigation)**: Depends on all previous phases
8. **Phase 8 (Integration)**: Depends on all previous phases
9. **Phase 9 (Polish)**: Depends on all previous phases

### Parallel Execution Opportunities

- **T-007 and T-016**: Can be implemented in parallel (different result models)
- **T-008 and T-017**: Can be implemented in parallel (different preview orchestrators)
- **T-013 and T-016**: Can be implemented in parallel (different components)
- **T-014 and T-022**: Can be implemented in parallel (different execution orchestrator skeletons)
- **T-014b and T-022b**: Can be implemented in parallel (different Core API integrations)
- **T-014c and T-022c**: Can be implemented in parallel (different error mappings)

## Implementation Strategy

### MVP Scope

**Minimum Viable Product**: User Story 1 (Create Library via Wizard)

**MVP Tasks**: T-001 through T-015

**MVP Deliverable**: Users can create a new library through the UI wizard with preview and confirmation.

### Incremental Delivery

1. **Increment 1**: MVP (US1 - Create Library)
2. **Increment 2**: US2 (Adopt Library)
3. **Increment 3**: US3, US4 (Preview and Confirmation validation)
4. **Increment 4**: US5 (Navigation and Error Handling)
5. **Increment 5**: Integration and Polish

## Summary

- **Total Tasks**: 42 (38 core + 4 optional Phase 9)
- **Tasks per User Story**:
  - Setup: 3 tasks
  - Foundational: 3 tasks
  - US1 (Create): 11 tasks (T-001 through T-015, including split T-014)
  - US2 (Adopt): 10 tasks (T-016 through T-023, including split T-022)
  - US3 (Preview): 3 tasks (manual verification)
  - US4 (Confirmation): 2 tasks (manual verification)
  - US5 (Navigation): 3 tasks (manual verification)
  - Integration: 3 tasks
  - Polish: 4 tasks (P2, optional/post-freeze)
- **Parallel Opportunities**: 6 pairs of tasks can be implemented in parallel
- **Independent Test Criteria**: Each user story has clear independent test criteria
- **Suggested MVP Scope**: User Story 1 (Create Library via Wizard) - 15 tasks (T-001 through T-015)
- **SAFE PASS Compliance**: All tasks fit in single SAFE PASS (1-2 commands max per task)
