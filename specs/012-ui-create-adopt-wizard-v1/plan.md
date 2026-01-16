# Implementation Plan: UI Create / Adopt Wizard v1

**Feature**: UI Create / Adopt Wizard v1  
**Specification**: `specs/012-ui-create-adopt-wizard-v1/spec.md`  
**Slice**: 12 - Unified wizard for library creation and adoption with preview and confirmation  
**Created**: 2026-01-27

## Plan Scope

This plan implements **Slice 12 only**, which adds UI wizards for creating new MediaHub libraries and adopting existing directories as MediaHub libraries. This includes:

- "Create Library" wizard with folder selection, preview, and confirmation
- "Adopt Library" wizard with directory selection, preview (including baseline scan), and confirmation
- Dry-run preview for adopt operations (using Core API)
- In-memory preview simulation for create operations (since Core API doesn't support dry-run)
- Explicit confirmation dialogs before execution
- Automatic library opening after successful creation/adoption
- Custom `LibraryCreationConfirmationHandler` to bypass Core-level confirmations

**Explicitly out of scope**:
- Source attachment UI (Slice 13)
- Detection preview/run UI (Slice 13)
- Import preview/confirm/run UI (Slice 13)
- Progress bars and cancellation UI for long-running operations (Slices 14–15)
- Hash maintenance UI (Slice 16)
- History/audit timeline UI (Slice 17)
- Distribution/notarization work (Slice 18)
- Refactoring of core/CLI code (core/CLI remain frozen)
- New CLI commands or flags
- Advanced wizard features (templates, custom metadata, batch operations)
- Wizard state persistence across app launches

## Goals / Non-Goals

### Goals
- Provide unified wizard interface for creating and adopting libraries through the UI
- Enable safe preview of operations before execution (dry-run for adopt, simulation for create)
- Require explicit user confirmation before any file system modifications
- Automatically open newly created/adopted libraries after successful completion
- Maintain backward compatibility with existing Core APIs from slices 1, 4, and 6
- Integrate seamlessly with existing UI shell from Slice 11

### Non-Goals
- Implement new business logic (all logic remains in Core layer)
- Support mutating operations beyond create/adopt (detect, import deferred to Slice 13)
- Provide advanced wizard features (templates, batch operations)
- Persist wizard state across app launches (session-only)
- Optimize for very large baseline scans beyond basic async loading (performance work deferred)

## Proposed Architecture

### Module Structure

The wizard implementation extends the existing `MediaHubUI` app target with new wizard components. All wizard components link against the existing `MediaHub` framework (Core APIs).

**Targets**:
- `MediaHubUI` (macOS app target, existing from Slice 11)
  - Links against `MediaHub` framework (Core APIs)
  - New wizard SwiftUI views and view models
  - Wizard state management
  - Core API orchestration for create/adopt operations

**Boundaries**:
- **UI Layer**: SwiftUI wizard views, wizard view models, wizard state
- **Orchestration Layer**: Thin wrappers that invoke Core APIs (`LibraryCreator`, `LibraryAdopter`)
- **Core Layer**: Existing MediaHub framework (frozen, no changes)
- **CLI Layer**: Not used by UI (UI uses Core APIs directly)

### Component Overview

1. **Wizard Entry Points** (`CreateLibraryWizard.swift`, `AdoptLibraryWizard.swift`)
   - Wizard sheet presentation
   - Wizard state initialization
   - Navigation flow management

2. **Wizard State Management** (`CreateWizardState.swift`, `AdoptWizardState.swift`)
   - Current step tracking
   - Selected path storage
   - Preview results caching
   - Confirmation status

3. **Path Selection** (`WizardPathSelectionView.swift`)
   - Folder picker integration (`NSOpenPanel`)
   - Path validation
   - Error display for invalid paths

4. **Preview Display** (`WizardPreviewView.swift`)
   - Preview information display (metadata location, operation type, baseline scan summary)
   - "Preview" badge/indicator
   - Preview refresh on path change

5. **Confirmation Dialog** (`WizardConfirmationView.swift`)
   - Summary of what will be created
   - Explicit confirm/cancel buttons
   - Safety messaging (especially for adoption: "No media files will be modified")

6. **Core API Orchestration** (`WizardCoreAPIOrchestrator.swift`)
   - `LibraryCreator.createLibrary` invocation with custom confirmation handler
   - `LibraryAdopter.adoptLibrary` invocation (dry-run for preview, actual for execution)
   - Async operation handling (off MainActor)
   - Error handling and user-facing error messages

7. **Custom Confirmation Handler** (`WizardConfirmationHandler.swift`)
   - Implements `LibraryCreationConfirmationHandler` protocol
   - Automatically confirms all Core-level confirmation requests
   - Bypasses duplicate confirmation dialogs (wizard handles confirmation in UI)

8. **Preview Simulation** (`CreatePreviewSimulator.swift`)
   - In-memory preview for create operations (since Core API doesn't support dry-run)
   - Uses `LibraryPathValidator` to validate path
   - Simulates metadata structure that would be created
   - Shows preview without calling Core API

### Data Flow

#### Create Library Flow
```
User clicks "Create Library" action
  ↓
Present CreateLibraryWizard sheet
  ↓
Step 1: Path Selection
  - User selects folder via NSOpenPanel
  - Validate path (exists, writable, not already a library)
  - If invalid: show error, allow retry
  - If valid: proceed to preview
  ↓
Step 2: Preview (simulated in-memory)
  - Use CreatePreviewSimulator to generate preview
  - Show metadata location (.mediahub/library.json)
  - Show "Preview" indicator
  - Enable "Next" button
  ↓
Step 3: Confirmation
  - Show summary of what will be created
  - Show explicit "Create" and "Cancel" buttons
  - If user cancels: close wizard, no files created
  - If user confirms: proceed to execution
  ↓
Step 4: Execution
  - Show progress indicator
  - Invoke LibraryCreator.createLibrary with custom confirmation handler
  - Custom handler bypasses Core-level confirmations (wizard already handled)
  - If successful: close wizard, open newly created library
  - If failed: show error message, allow retry or cancel
```

#### Adopt Library Flow
```
User clicks "Adopt Library" action
  ↓
Present AdoptLibraryWizard sheet
  ↓
Step 1: Path Selection
  - User selects directory via NSOpenPanel
  - Validate path (exists, writable, is directory)
  - Check if already adopted (idempotent behavior)
  - If invalid: show error, allow retry
  - If valid: proceed to preview
  ↓
Step 2: Preview (Core API dry-run)
  - Invoke LibraryAdopter.adoptLibrary(at:dryRun: true) off MainActor
  - Show metadata location (.mediahub/library.json)
  - Show baseline scan summary (file count, scan scope)
  - Show "Preview" indicator
  - Enable "Next" button
  ↓
Step 3: Confirmation
  - Show summary of what will be created
  - Show "No media files will be modified; only .mediahub metadata will be created"
  - Show explicit "Adopt" and "Cancel" buttons
  - If user cancels: close wizard, no files created
  - If user confirms: proceed to execution
  ↓
Step 4: Execution
  - Show progress indicator
  - Invoke LibraryAdopter.adoptLibrary(at:dryRun: false) off MainActor
  - If successful: close wizard, open newly adopted library
  - If failed: show error message, allow retry or cancel
```

## Core API Integration Decision

**Primary Approach: Core API Direct Invocation**

The wizard will use Core APIs directly (`LibraryCreator.createLibrary`, `LibraryAdopter.adoptLibrary`) rather than invoking the CLI executable. This decision is justified by:

1. **Simplicity**: No process spawning, no JSON parsing, no CLI executable dependency
2. **Performance**: Direct function calls are faster than subprocess execution
3. **Error Handling**: Direct Swift error propagation vs. parsing CLI error output
4. **Code Reuse**: Same code path as CLI ensures identical behavior
5. **Availability**: Core APIs are always available (app links against MediaHub framework)

**Implementation Details**:

### Create Operations
- **API**: `LibraryCreator.createLibrary(at:libraryVersion:completion:)`
- **Confirmation Handler**: Custom `WizardConfirmationHandler` that automatically confirms all Core-level confirmation requests (non-empty directories, existing libraries) since the wizard handles confirmation in the UI
- **Async Pattern**: Completion callback, invoke off MainActor, update UI on MainActor
- **Preview**: In-memory simulation using `LibraryPathValidator` and metadata structure simulation (Core API doesn't support dry-run)

### Adopt Operations
- **API**: `LibraryAdopter.adoptLibrary(at:dryRun:)`
- **Preview**: Use `dryRun: true` for preview (Core API supports dry-run)
- **Execution**: Use `dryRun: false` for actual adoption
- **Async Pattern**: Synchronous throwing method, wrap in `Task.detached` to call off MainActor, update UI on MainActor
- **Idempotent Behavior**: Core API handles already-adopted libraries (throws `LibraryAdoptionError.alreadyAdopted`)

**Fallback Strategy**: None required. Core APIs are always available since the app links against the MediaHub framework. If Core APIs fail, it's a programming error (not a runtime dependency issue).

## File System Access

### Path Selection

1. **User Selection**: Use `NSOpenPanel` with `.canChooseDirectories = true` to let user select a folder/directory
2. **Path Validation**: 
   - Verify path exists and is accessible
   - Verify path is a directory (for adopt) or can be created (for create)
   - Verify write permissions
   - Check if path already contains a MediaHub library (error for create, idempotent message for adopt)
   - Check if path contains files but is not a library (warning for create)
3. **Error Display**: Show clear, user-facing error messages for validation failures
4. **Retry Support**: Allow user to correct path and retry without restarting wizard

### Preview Operations

1. **Create Preview**: In-memory simulation (no file system access beyond validation)
   - Use `LibraryPathValidator.validatePath(path:)` for validation
   - Simulate metadata structure (`.mediahub/` directory, `library.json` contents)
   - Show preview without calling Core API
2. **Adopt Preview**: Core API dry-run mode (read-only file system access)
   - Invoke `LibraryAdopter.adoptLibrary(at:dryRun: true)`
   - Core API performs baseline scan (read-only)
   - Core API returns preview results without creating files
   - Zero file system writes during preview

### Execution Operations

1. **Create Execution**: Core API invocation
   - Invoke `LibraryCreator.createLibrary(at:libraryVersion:completion:)` with custom confirmation handler
   - Core API creates `.mediahub/` directory and `library.json`
   - Handle errors gracefully with user-facing messages
2. **Adopt Execution**: Core API invocation
   - Invoke `LibraryAdopter.adoptLibrary(at:dryRun: false)`
   - Core API creates `.mediahub/` directory, `library.json`, and baseline index
   - Core API performs baseline scan and creates index
   - Handle errors gracefully (including idempotent already-adopted case)

### Sandbox Considerations

- Use `NSOpenPanel` for folder selection (system handles sandbox access automatically)
- Request appropriate entitlements: `com.apple.security.files.user-selected.read-write`
- Test with sandbox enabled and disabled

## State Management Approach

### Wizard State Structure

```swift
@MainActor
class CreateWizardState: ObservableObject {
    @Published var currentStep: WizardStep = .pathSelection
    @Published var selectedPath: String?
    @Published var previewResult: CreatePreviewResult?
    @Published var isExecuting: Bool = false
    @Published var errorMessage: String?
}

@MainActor
class AdoptWizardState: ObservableObject {
    @Published var currentStep: WizardStep = .pathSelection
    @Published var selectedPath: String?
    @Published var previewResult: AdoptPreviewResult? // Includes baseline scan summary
    @Published var isExecuting: Bool = false
    @Published var errorMessage: String?
}

enum WizardStep {
    case pathSelection
    case preview
    case confirmation
    case executing
}
```

### State Transitions

1. **Initial State**: `currentStep = .pathSelection`, no selected path, no preview, no error
2. **Path Selection**: User selects path → validate → if valid, proceed to preview
3. **Preview**: Generate preview (simulation for create, Core API dry-run for adopt) → update `previewResult` → proceed to confirmation
4. **Confirmation**: User views summary → user confirms or cancels
5. **Execution**: If confirmed, set `isExecuting = true` → invoke Core API → on success, close wizard and open library → on failure, show error and allow retry
6. **Cancellation**: At any step, user can cancel → reset state → close wizard

### Determinism Guarantees

- Preview results: Same path and settings produce same preview (deterministic)
- Path validation: Same path produces same validation result (deterministic)
- Error messages: Same error conditions produce same error messages (deterministic)

## Error Handling Strategy

### Error Categories

1. **Path Validation Errors**:
   - Path doesn't exist: "The selected path does not exist. Please select a valid folder."
   - Path is not a directory: "The selected path is not a directory. Please select a folder."
   - Permission denied: "You don't have permission to access this location. Please select a different folder."
   - Already a library (create): "This location already contains a MediaHub library. Please select a different folder."
   - Already a library (adopt): "This library is already adopted." (idempotent, not an error)

2. **Preview Errors**:
   - Create preview: Path validation errors (same as above)
   - Adopt preview: Core API errors (permission denied, invalid path, etc.)

3. **Execution Errors**:
   - Create execution: `LibraryCreationError` → map to user-facing messages
   - Adopt execution: `LibraryAdoptionError` → map to user-facing messages
   - Already adopted (adopt): Show idempotent message, not error

### Error Display

- Use inline error messages in wizard views (not blocking alerts)
- Show errors near the relevant input (path selection, preview, confirmation)
- Always provide actionable error messages (what went wrong, what user can do)
- Allow user to correct errors and retry without restarting wizard

### Error Recovery

- Path validation errors: User can select a different path
- Preview errors: User can correct path and regenerate preview
- Execution errors: User can retry execution or cancel wizard
- All errors: User can cancel wizard at any time (no files created)

## Sequencing

### Phase 1: Wizard Foundation (P1)
**Goal**: Basic wizard structure and navigation

1. Create `CreateLibraryWizard` and `AdoptLibraryWizard` SwiftUI views
2. Implement wizard state management (`CreateWizardState`, `AdoptWizardState`)
3. Implement step navigation (path selection → preview → confirmation → execution)
4. Implement "Back" button navigation (when applicable)
5. Implement wizard cancellation at any step

**Why First**: Establishes the foundation for all wizard functionality. Can be tested immediately with mock data.

### Phase 2: Path Selection (P1)
**Goal**: Folder picker and path validation

1. Implement `WizardPathSelectionView` with `NSOpenPanel` integration
2. Implement path validation logic (exists, writable, directory check)
3. Implement library detection (already a library check)
4. Implement error display for validation failures
5. Integrate with wizard state

**Why Second**: Path selection is the first step. Users need to select a path before preview/confirmation.

### Phase 3: Preview Display (P1)
**Goal**: Preview information display

1. Implement `WizardPreviewView` for displaying preview information
2. Implement "Preview" badge/indicator
3. Implement preview refresh on path change
4. Integrate with wizard state

**Why Third**: Preview is shown after path selection. Needed before confirmation.

### Phase 4: Create Preview Simulation (P1)
**Goal**: In-memory preview for create operations

1. Implement `CreatePreviewSimulator` using `LibraryPathValidator`
2. Simulate metadata structure that would be created
3. Generate preview result without calling Core API
4. Integrate with create wizard flow

**Why Fourth**: Create operations need preview simulation (Core API doesn't support dry-run).

### Phase 5: Adopt Preview (Core API Dry-Run) (P1)
**Goal**: Core API dry-run preview for adopt operations

1. Implement `AdoptPreviewOrchestrator` that invokes `LibraryAdopter.adoptLibrary(at:dryRun: true)`
2. Handle async operation (wrap sync API in `Task.detached`)
3. Parse preview results (metadata, baseline scan summary)
4. Integrate with adopt wizard flow

**Why Fifth**: Adopt operations use Core API dry-run mode for preview.

### Phase 6: Confirmation Dialog (P1)
**Goal**: Explicit confirmation before execution

1. Implement `WizardConfirmationView` with summary display
2. Implement "Create"/"Adopt" and "Cancel" buttons
3. Implement safety messaging (especially for adoption)
4. Integrate with wizard state

**Why Sixth**: Confirmation is required before execution. Needed after preview.

### Phase 7: Custom Confirmation Handler (P1)
**Goal**: Bypass Core-level confirmations

1. Implement `WizardConfirmationHandler` conforming to `LibraryCreationConfirmationHandler`
2. Implement automatic confirmation for non-empty directories
3. Implement automatic confirmation for existing libraries
4. Integrate with `LibraryCreator.createLibrary` invocation

**Why Seventh**: Custom handler is needed for create operations to prevent duplicate confirmations.

### Phase 8: Create Execution (P1)
**Goal**: Execute library creation

1. Implement `CreateExecutionOrchestrator` that invokes `LibraryCreator.createLibrary`
2. Handle async completion callback (off MainActor)
3. Show progress indicator during execution
4. Handle success (close wizard, open library) and failure (show error, allow retry)
5. Integrate with wizard state

**Why Eighth**: Create execution is the final step for create wizard.

### Phase 9: Adopt Execution (P1)
**Goal**: Execute library adoption

1. Implement `AdoptExecutionOrchestrator` that invokes `LibraryAdopter.adoptLibrary(at:dryRun: false)`
2. Handle sync throwing API (wrap in `Task.detached`, call off MainActor)
3. Show progress indicator during execution
4. Handle success (close wizard, open library) and failure (show error, allow retry)
5. Handle idempotent already-adopted case (show message, not error)
6. Integrate with wizard state

**Why Ninth**: Adopt execution is the final step for adopt wizard.

### Phase 10: Integration with App Shell (P1)
**Goal**: Integrate wizards with existing UI shell

1. Add "Create Library" and "Adopt Library" actions to `ContentView` (buttons or menu items)
2. Present wizards as sheets from main window
3. Handle wizard completion (open newly created/adopted library)
4. Update `AppState` with newly created/adopted library

**Why Last**: Integration connects wizards to the existing UI shell from Slice 11.

## Risks & Mitigations (Implementation Sequencing)

### Risk 1: Create Preview Simulation Accuracy
**Risk**: In-memory preview simulation may not accurately match what Core API actually creates, causing user confusion.

**Mitigation**:
- Use same `LibraryPathValidator` logic that Core API uses
- Simulate exact metadata structure (libraryId generation, libraryVersion)
- Test that preview matches actual execution results
- Display "Preview" indicator clearly to set expectations

**Sequencing Impact**: Phase 4 (Create Preview Simulation) must be tested thoroughly against actual Core API behavior.

### Risk 2: Custom Confirmation Handler Integration
**Risk**: Custom `LibraryCreationConfirmationHandler` may not properly bypass Core-level confirmations, causing duplicate dialogs or blocking wizard flow.

**Mitigation**:
- Test custom handler with all confirmation scenarios (non-empty directory, existing library)
- Ensure handler immediately calls completion callback with `confirmed: true`
- Test that wizard confirmation is the only confirmation shown to users
- Verify Core API proceeds without blocking

**Sequencing Impact**: Phase 7 (Custom Confirmation Handler) must be tested early with Phase 8 (Create Execution).

### Risk 3: Async Operation Handling Complexity
**Risk**: Different async patterns (completion callbacks for create, sync throwing for adopt) may cause UI state issues or race conditions.

**Mitigation**:
- Use consistent pattern: all Core API calls off MainActor, all UI updates on MainActor
- For sync APIs, wrap in `Task.detached` explicitly
- Show progress indicators during all async operations
- Handle cancellation and cleanup properly
- Test with slow operations and cancellation scenarios

**Sequencing Impact**: Phases 5, 8, and 9 must follow consistent async patterns.

### Risk 4: Preview Refresh on Path Change
**Risk**: When user navigates back and changes path, preview may not refresh correctly, showing stale information.

**Mitigation**:
- Clear preview result when path changes
- Regenerate preview when returning to preview step
- Validate wizard state before proceeding to next step
- Test navigation scenarios (back, forward, path change)

**Sequencing Impact**: Phase 3 (Preview Display) must handle state invalidation correctly.

### Risk 5: Idempotent Adoption Handling
**Risk**: Adoption wizard may not properly handle already-adopted libraries, showing errors instead of idempotent messages.

**Mitigation**:
- Use Core API `LibraryAdopter.adoptLibrary` which handles idempotent behavior
- Catch `LibraryAdoptionError.alreadyAdopted` and show appropriate message (not error)
- Test idempotent adoption scenarios
- Ensure wizard shows appropriate feedback for already-adopted libraries

**Sequencing Impact**: Phase 9 (Adopt Execution) must handle idempotent case correctly.

## Testing / Verification Hooks

### User Story 1: Create a New Library via Wizard

**Verification Steps**:
1. Launch UI app
2. Click "Create Library" action
3. Verify wizard opens with path selection step
4. Select a valid folder path
5. Verify preview step shows metadata location
6. Verify confirmation step shows summary
7. Confirm creation
8. Verify library is created
9. Verify newly created library is automatically opened

**CLI Commands for Test Setup**:
```bash
# Create test directory for library creation
mkdir -p /tmp/test-create-location
```

### User Story 2: Adopt Existing Directory via Wizard

**Verification Steps**:
1. Launch UI app
2. Click "Adopt Library" action
3. Verify wizard opens with path selection step
4. Select a directory containing media files organized in YYYY/MM
5. Verify preview step shows metadata location and baseline scan summary
6. Verify confirmation step shows summary and "No media files will be modified" message
7. Confirm adoption
8. Verify library is adopted successfully
9. Verify newly adopted library is automatically opened

**CLI Commands for Test Setup**:
```bash
# Create test directory with media files
mkdir -p /tmp/test-adopt-location/2024/01
touch /tmp/test-adopt-location/2024/01/test-photo.jpg
```

### User Story 3: Preview Operations with Dry-Run

**Verification Steps**:
1. Create wizard: Select path, verify preview shows metadata location without creating files
2. Adopt wizard: Select path, verify preview shows metadata location and baseline scan summary without creating files
3. Verify preview operations perform zero file system writes (check directory before/after)
4. Verify preview information matches actual execution results

**CLI Commands for Test Setup**:
```bash
# Create test directories
mkdir -p /tmp/test-preview-create
mkdir -p /tmp/test-preview-adopt/2024/01
touch /tmp/test-preview-adopt/2024/01/test-photo.jpg
```

### User Story 4: Explicit Confirmation Dialogs

**Verification Steps**:
1. Proceed through wizard to confirmation step
2. Verify confirmation dialog shows summary of what will be created
3. Verify "Cancel" button closes wizard without creating files
4. Verify "Confirm"/"Create"/"Adopt" button proceeds with execution
5. Verify progress indicator shows during execution
6. Verify confirmation button is disabled during execution

### User Story 5: Wizard Navigation and Error Handling

**Verification Steps**:
1. Navigate through wizard steps
2. Verify "Back" button appears on step 2 and later
3. Navigate back and change path
4. Verify preview and confirmation information updates
5. Trigger various errors (invalid path, permission denied)
6. Verify clear error messages displayed
7. Verify user can correct errors and retry without restarting wizard
8. Verify cancellation at any step performs zero file system modifications

## Success Criteria Verification

- **SC-001** (Create < 30 seconds): Measure time from wizard open to library creation completion
- **SC-002** (Adopt < 60 seconds): Measure time from wizard open to library adoption completion
- **SC-003** (Preview accuracy): Compare preview information with actual execution results (programmatic comparison)
- **SC-004** (Zero writes during preview): Verify no files created during preview operations (check directory before/after)
- **SC-005** (Confirmation accuracy): Verify confirmation dialogs show accurate information
- **SC-006** (Error handling): Test all error cases and verify clear messages displayed
- **SC-007** (Backward compatibility - create): Test created libraries with CLI commands
- **SC-008** (Backward compatibility - adopt): Test adopted libraries with CLI commands
- **SC-009** (Auto-open): Verify newly created/adopted libraries are automatically opened
- **SC-010** (Cancellation safety): Verify cancellation at any step performs zero file system modifications

## Implementation Notes

### Core API Usage Pattern

#### Create Operations
```swift
// Custom confirmation handler that bypasses Core-level confirmations
let confirmationHandler = WizardConfirmationHandler()
let creator = LibraryCreator(confirmationHandler: confirmationHandler)

// Invoke off MainActor
Task.detached {
    creator.createLibrary(at: path, libraryVersion: "1.0") { result in
        await MainActor.run {
            switch result {
            case .success(let metadata):
                // Close wizard, open library
            case .failure(let error):
                // Show error, allow retry
            }
        }
    }
}
```

#### Adopt Operations
```swift
// Preview: dry-run mode
Task.detached {
    do {
        let previewResult = try LibraryAdopter.adoptLibrary(at: path, dryRun: true)
        await MainActor.run {
            // Update wizard state with preview
        }
    } catch {
        await MainActor.run {
            // Show error
        }
    }
}

// Execution: actual adoption
Task.detached {
    do {
        let result = try LibraryAdopter.adoptLibrary(at: path, dryRun: false)
        await MainActor.run {
            // Close wizard, open library
        }
    } catch LibraryAdoptionError.alreadyAdopted {
        await MainActor.run {
            // Show idempotent message (not error)
        }
    } catch {
        await MainActor.run {
            // Show error, allow retry
        }
    }
}
```

### SwiftUI Concurrency

All Core API calls will be wrapped in `Task.detached` blocks and use `@MainActor` for state updates:

```swift
Task.detached {
    // Core API call off MainActor
    let result = try LibraryAdopter.adoptLibrary(at: path, dryRun: true)
    
    await MainActor.run {
        // Update UI state on MainActor
        wizardState.previewResult = result
        wizardState.currentStep = .confirmation
    }
}
```

### Error Message Mapping

Map Core API errors to user-facing messages:
- `LibraryCreationError.pathDoesNotExist` → "The selected path does not exist."
- `LibraryCreationError.permissionDenied` → "You don't have permission to access this location."
- `LibraryCreationError.existingLibraryFound` → "This location already contains a MediaHub library."
- `LibraryAdoptionError.pathDoesNotExist` → "The selected path does not exist."
- `LibraryAdoptionError.permissionDenied` → "You don't have permission to access this location."
- `LibraryAdoptionError.alreadyAdopted` → "This library is already adopted." (idempotent, not error)

## Dependencies

- **MediaHub Framework**: Core APIs (`LibraryCreator`, `LibraryAdopter`, `LibraryPathValidator`) - already exists, frozen
- **SwiftUI**: macOS 13.0+ (Ventura)
- **Foundation**: File system access, NSOpenPanel
- **No external dependencies**: Pure Swift/SwiftUI implementation

## Out of Scope (Reiterated)

- Source attachment UI
- Detection preview/run UI
- Import preview/confirm/run UI
- Progress bars and cancellation UI for long-running operations
- Hash maintenance UI
- History/audit timeline UI
- Distribution/notarization
- Mutating operations beyond create/adopt
- Core/CLI refactoring
- Advanced wizard features
- Wizard state persistence across app launches
