# Feature Specification: UI Create / Adopt Wizard v1

**Feature Branch**: `012-ui-create-adopt-wizard-v1`  
**Created**: 2026-01-27  
**Status**: Draft  
**Input**: User description: "Unified wizard for library creation and adoption with preview dry-run and explicit confirmation"

## Overview

This slice adds UI wizards for creating new MediaHub libraries and adopting existing directories as MediaHub libraries. The wizards provide a unified, user-friendly interface that orchestrates existing Core APIs (`LibraryCreator`, `LibraryAdopter`) with dry-run preview and explicit confirmation dialogs. This enables users to set up libraries through the desktop app without using the command line.

**Problem Statement**: Users need a visual interface to create new libraries or adopt existing directories as MediaHub libraries. The desktop app must provide safe, guided workflows that preview operations before execution and require explicit confirmation, matching the safety guarantees of the CLI commands.

**Architecture Principle**: The desktop application is a UI orchestrator. All business logic, data validation, and library operations remain in the Core layer. The UI invokes Core APIs directly (e.g., `LibraryCreator.createLibrary`, `LibraryAdopter.adoptLibrary`) but never implements its own library management logic. The UI provides visual feedback, progress indicators, and confirmation dialogs, but all actual operations are performed by Core APIs.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Create a New Library via Wizard (Priority: P1)

A user wants to create a new MediaHub library at a chosen location through the desktop app. They need a guided wizard that lets them select a folder, preview what will be created, and confirm the operation before execution.

**Why this priority**: Library creation is a foundational action that enables users to start using MediaHub. Without a UI wizard, users must use the CLI, which is less accessible for non-technical users.

**Independent Test**: Can be fully tested by launching the wizard, selecting a folder, previewing the operation, and confirming to create a library. This delivers the core capability of creating libraries through the UI.

**Acceptance Scenarios**:

1. **Given** the user clicks "Create Library" or similar action in the app, **When** the wizard opens, **Then** the app displays a step-by-step wizard with folder selection, preview, and confirmation
2. **Given** the user selects a folder path in the wizard, **When** the path is valid and writable, **Then** the app enables the next step and shows a preview of what will be created
3. **Given** the user selects a folder path that already contains a MediaHub library, **When** the wizard validates the path, **Then** the app displays a clear error message indicating the library already exists
4. **Given** the user selects a folder path that contains files but is not a MediaHub library, **When** the wizard validates the path, **Then** the app shows a warning and requires explicit confirmation before proceeding (matching CLI behavior)
5. **Given** the user proceeds through the wizard and confirms creation, **When** the library is created successfully, **Then** the app displays success feedback and automatically opens the newly created library
6. **Given** the user proceeds through the wizard and confirms creation, **When** the library creation fails (e.g., permission error), **Then** the app displays a clear, user-facing error message explaining what went wrong
7. **Given** the user cancels the wizard at any step, **When** cancellation occurs, **Then** no library is created and no files are modified

---

### User Story 2 - Adopt Existing Directory via Wizard (Priority: P1)

A user has an existing media library directory organized in YYYY/MM folders and wants to adopt it as a MediaHub library. They need a guided wizard that lets them select the directory, preview the adoption operation (including baseline scan preview), and confirm before execution.

**Why this priority**: Library adoption enables users with existing organized libraries to use MediaHub without re-importing. This is a common use case for users migrating from other systems or organizing existing collections.

**Independent Test**: Can be fully tested by launching the adoption wizard, selecting an existing directory, previewing the operation, and confirming to adopt the library. This delivers the core capability of adopting libraries through the UI.

**Acceptance Scenarios**:

1. **Given** the user clicks "Adopt Library" or similar action in the app, **When** the wizard opens, **Then** the app displays a step-by-step wizard with directory selection, preview (including baseline scan preview), and confirmation
2. **Given** the user selects a directory path in the wizard, **When** the path is valid and contains media files, **Then** the app enables the next step and shows a preview of what will be created (metadata location, baseline scan summary)
3. **Given** the user selects a directory path that is already a MediaHub library, **When** the wizard validates the path, **Then** the app displays a clear message indicating the library is already adopted (idempotent behavior)
4. **Given** the user selects a directory path that doesn't exist or is not accessible, **When** the wizard validates the path, **Then** the app displays a clear error message explaining the issue
5. **Given** the user proceeds through the wizard and confirms adoption, **When** the library is adopted successfully, **Then** the app displays success feedback and automatically opens the newly adopted library
6. **Given** the user proceeds through the wizard and confirms adoption, **When** the library adoption fails (e.g., permission error), **Then** the app displays a clear, user-facing error message explaining what went wrong
7. **Given** the user cancels the wizard at any step, **When** cancellation occurs, **Then** no library is adopted and no files are modified

---

### User Story 3 - Preview Operations with Dry-Run (Priority: P1)

A user wants to preview what will happen during library creation or adoption before committing to the operation. The wizard must support dry-run preview that shows exactly what will be created without performing any file system modifications.

**Why this priority**: Dry-run preview is a foundational safety feature that enables users to explore and understand operations before committing. This matches the CLI's `--dry-run` flag behavior and provides transparency.

**Independent Test**: Can be fully tested by launching the wizard, selecting a path, and verifying the preview shows accurate information without creating any files. This delivers the core capability of safe preview.

**Acceptance Scenarios**:

1. **Given** the user selects a folder path in the create wizard, **When** the wizard performs preview (simulated in-memory), **Then** the app displays what metadata will be created (`.mediahub/` directory, `library.json` contents) without creating any files
2. **Given** the user selects a directory path in the adopt wizard, **When** the wizard performs dry-run preview, **Then** the app displays what metadata will be created and what baseline scan will be performed (file count, scan scope) without creating any files or performing the scan
3. **Given** the wizard performs dry-run preview, **When** the preview completes, **Then** the app shows a clear indication that this is a preview (e.g., "Preview" badge or "This is a preview" message)
4. **Given** the wizard performs dry-run preview, **When** the preview completes, **Then** the app enables the confirmation step, allowing the user to proceed with the actual operation
5. **Given** the wizard performs dry-run preview, **When** the preview fails (e.g., path validation error), **Then** the app displays a clear error message and disables the confirmation step

---

### User Story 4 - Explicit Confirmation Dialogs (Priority: P1)

A user wants explicit confirmation before MediaHub creates library metadata. The wizard must display clear confirmation dialogs that show what will be created and require explicit user action to proceed.

**Why this priority**: Explicit confirmation prevents accidental library creation/adoption and gives users a final checkpoint before metadata creation. This aligns with Constitution principle 3.3 "Safe Operations" and matches CLI confirmation behavior.

**Independent Test**: Can be fully tested by proceeding through the wizard and verifying confirmation dialogs appear with accurate information and require explicit user action. This delivers the core capability of safe confirmation.

**Acceptance Scenarios**:

1. **Given** the user proceeds through the wizard to the confirmation step, **When** the confirmation dialog is displayed, **Then** the app shows a clear summary of what will be created (metadata location, operation type, preview information)
2. **Given** the user views the confirmation dialog, **When** they click "Cancel" or close the dialog, **Then** the wizard cancels and no library is created or adopted
3. **Given** the user views the confirmation dialog, **When** they click "Confirm" or "Create" / "Adopt", **Then** the wizard proceeds with the actual operation
4. **Given** the user confirms the operation, **When** the operation is in progress, **Then** the app shows a progress indicator and disables the confirmation button to prevent duplicate operations
5. **Given** the user confirms adoption, **When** the confirmation dialog is displayed, **Then** the app shows a clear message that "No media files will be modified; only .mediahub metadata will be created"

---

### User Story 5 - Wizard Navigation and Error Handling (Priority: P2)

A user wants to navigate the wizard comfortably, go back to previous steps, and understand errors clearly. The wizard must provide intuitive navigation and handle errors gracefully.

**Why this priority**: While not immediately critical, proper navigation and error handling provide a professional user experience and prevent user frustration.

**Independent Test**: Can be fully tested by navigating through the wizard, going back to previous steps, and triggering various error conditions. This delivers the basic wizard navigation capability.

**Acceptance Scenarios**:

1. **Given** the user is in the wizard, **When** they are on step 2 or later, **Then** the app provides a "Back" button to return to previous steps
2. **Given** the user navigates back to a previous step, **When** they change the path or settings, **Then** the app updates the preview and confirmation information accordingly
3. **Given** the wizard encounters an error (e.g., permission denied, invalid path), **When** the error occurs, **Then** the app displays a clear, user-facing error message with actionable guidance
4. **Given** the wizard encounters an error, **When** the error is displayed, **Then** the app allows the user to correct the issue and retry without restarting the wizard
5. **Given** the user cancels the wizard, **When** cancellation occurs, **Then** the app returns to the previous screen (library list or empty state) without creating any files

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST provide a "Create Library" action (button or menu item) that opens a library creation wizard
- **FR-002**: The app MUST provide an "Adopt Library" action (button or menu item) that opens a library adoption wizard
- **FR-003**: The wizard MUST support step-by-step navigation with folder/directory selection, preview, and confirmation steps
- **FR-004**: The wizard MUST use Core APIs directly (`LibraryCreator.createLibrary`, `LibraryAdopter.adoptLibrary`) and MUST NOT invoke CLI commands
- **FR-005**: The wizard MUST perform preview operations before showing confirmation. For adopt operations, the wizard MUST use Core API dry-run mode (`LibraryAdopter.adoptLibrary(at:dryRun: true)`). For create operations, the wizard MUST simulate preview in-memory (using `LibraryPathValidator` and showing what metadata would be created) since `LibraryCreator.createLibrary` does not support dry-run mode
- **FR-006**: The wizard MUST display preview information showing what will be created (metadata location, operation type, baseline scan summary for adoption)
- **FR-007**: The wizard MUST display explicit confirmation dialogs before executing create or adopt operations
- **FR-008**: The wizard MUST show clear messaging that "No media files will be modified; only .mediahub metadata will be created" for adoption operations
- **FR-009**: The wizard MUST validate selected paths before proceeding to preview/confirmation steps
- **FR-010**: The wizard MUST handle path validation errors (non-existent, not a directory, permission denied) and display clear error messages
- **FR-011**: The wizard MUST detect when a selected path already contains a MediaHub library and display an appropriate message (idempotent behavior for adoption, error for create)
- **FR-012**: The wizard MUST detect when a selected path contains files but is not a MediaHub library and show a warning with confirmation requirement (for create operations)
- **FR-013**: The wizard MUST show progress indicators during actual operations (create/adopt execution)
- **FR-014**: The wizard MUST display success feedback when operations complete successfully
- **FR-015**: The wizard MUST automatically open the newly created or adopted library after successful completion
- **FR-016**: The wizard MUST handle operation failures gracefully and display clear, user-facing error messages
- **FR-017**: The wizard MUST support cancellation at any step without creating any files or modifying any data
- **FR-018**: The wizard MUST support navigation back to previous steps (when applicable)
- **FR-019**: The wizard MUST update preview and confirmation information when the user navigates back and changes settings
- **FR-020**: The wizard MUST work with existing Core APIs from slices 1, 4, and 6 (backward compatibility)

### Safety Rules

- **SR-001**: The wizard MUST NOT write to library directories during preview operations (preview must perform zero writes). For adopt operations, this is enforced by Core API dry-run mode. For create operations, this is enforced by in-memory simulation without calling the Core API
- **SR-002**: The wizard MUST NOT modify library metadata files (`.mediahub/library.json` or `.mediahub/registry/index.json`) during preview
- **SR-003**: The wizard MUST NOT create or modify any files until the user explicitly confirms the operation
- **SR-004**: The wizard MUST handle permission errors gracefully without crashing or corrupting state
- **SR-005**: The wizard MUST validate library metadata before attempting to open a newly created/adopted library
- **SR-006**: The wizard MUST handle sandbox restrictions appropriately (if sandbox is enabled): use security-scoped bookmarks for persistent library access, request folder access via NSOpenPanel
- **SR-007**: The wizard MUST NOT store sensitive information (e.g., library paths) in insecure locations
- **SR-008**: The wizard MUST ensure that adoption operations never modify, move, rename, or delete existing media files (only metadata creation)

### Determinism & Idempotence Rules

- **DR-001**: Wizard preview operations MUST produce the same preview information for the same path and settings (deterministic preview)
- **DR-002**: Wizard confirmation dialogs MUST show the same information as the preview (idempotent display)
- **DR-003**: Wizard error messages MUST be deterministic and reproducible for the same error conditions
- **DR-004**: Wizard path validation MUST be deterministic (same path produces same validation result)

### Data/IO Boundaries

- **IO-001**: The wizard MUST read only the following files during preview: selected path metadata (to check if library exists), directory contents (to validate path). For adopt operations, Core API dry-run mode performs baseline scan (read-only). For create operations, preview uses `LibraryPathValidator` (read-only path validation)
- **IO-002**: The wizard MUST write only the following files during actual operations: `.mediahub/` directory and `library.json` (for create), `.mediahub/` directory and `library.json` plus baseline index (for adopt)
- **IO-003**: The wizard MAY write to app-specific storage (UserDefaults, app support directory) for wizard state persistence (e.g., last selected folder)
- **IO-004**: The wizard MUST NOT write to library directories, library metadata files, or baseline index files during preview operations
- **IO-005**: The wizard MUST NOT create, modify, or delete any files in library directories during preview operations

### Core API Integration Approach

- **API-001**: The wizard MUST invoke `LibraryCreator.createLibrary(at:libraryVersion:completion:)` for create operations (with optional `libraryVersion` parameter, defaulting to "1.0")
- **API-002**: The wizard MUST invoke `LibraryAdopter.adoptLibrary(at:dryRun:)` for adopt operations (with `dryRun: true` for preview, `dryRun: false` for execution)
- **API-003**: The wizard MUST parse Core API results and handle errors gracefully
- **API-004**: The wizard MUST handle Core API operations asynchronously (off MainActor) and update UI on MainActor. For async APIs with completion callbacks (`LibraryCreator.createLibrary`), the wizard MUST invoke the API off MainActor and update UI state on MainActor. For synchronous throwing APIs (`LibraryAdopter.adoptLibrary`), the wizard MUST call the API off MainActor (e.g., using `Task.detached`) and update UI state on MainActor
- **API-005**: The wizard MUST NOT introduce new Core APIs, data models, or CLI commands in this slice
- **API-006**: The wizard MUST provide a custom `LibraryCreationConfirmationHandler` implementation that automatically confirms Core-level confirmation requests (for non-empty directories and existing libraries) since the wizard handles all confirmation in the UI. The custom handler MUST bypass Core-level confirmations by immediately calling the completion callback with `confirmed: true` (or appropriate response) to prevent duplicate confirmation dialogs

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can create a new library through the wizard in under 30 seconds for typical operations (path selection, preview, confirmation, execution)
- **SC-002**: Users can adopt an existing directory through the wizard in under 60 seconds for typical operations (path selection, preview with baseline scan, confirmation, execution)
- **SC-003**: Wizard preview operations show accurate information that matches actual operation results with 100% accuracy (same inputs produce same preview/execution)
- **SC-004**: Wizard preview operations perform zero file system writes (verified by tests)
- **SC-005**: Wizard confirmation dialogs display accurate information (metadata location, operation type, preview summary) in 100% of cases
- **SC-006**: Wizard handles path validation errors (non-existent, not a directory, permission denied, already exists) with clear error messages in 100% of error cases
- **SC-007**: Wizard successfully creates libraries that are compatible with existing CLI commands and Core APIs in 100% of cases (backward compatibility)
- **SC-008**: Wizard successfully adopts libraries that are compatible with existing CLI commands and Core APIs in 100% of cases (backward compatibility)
- **SC-009**: Wizard automatically opens newly created/adopted libraries after successful completion in 100% of cases
- **SC-010**: Wizard cancellation at any step performs zero file system modifications in 100% of cases

## Out of Scope

This slice explicitly does NOT include:

- **OOS-001**: Source attachment UI (deferred to Slice 13)
- **OOS-002**: Detection preview/run UI (deferred to Slice 13)
- **OOS-003**: Import preview/confirm/run UI (deferred to Slice 13)
- **OOS-004**: Progress bars and cancellation UI for long-running operations (deferred to Slices 14–15)
- **OOS-005**: Hash maintenance UI (deferred to Slice 16)
- **OOS-006**: History/audit timeline UI (deferred to Slice 17)
- **OOS-007**: Distribution/notarization work (deferred to Slice 18)
- **OOS-008**: Refactoring of core/CLI code (core/CLI remain frozen)
- **OOS-009**: New CLI commands or flags (CLI is source of truth, no changes)
- **OOS-010**: Advanced wizard features (e.g., library templates, custom metadata, batch operations)
- **OOS-011**: Wizard state persistence across app launches (wizard state is session-only)

## Risks & Mitigations

### Risk 1: macOS Sandbox Restrictions
**Risk**: macOS sandbox may restrict file access, preventing folder selection or library creation/adoption in user-selected locations.

**Mitigation**: 
- Use `NSOpenPanel` for folder selection (system handles sandbox access)
- Use security-scoped bookmarks for persistent library access (if sandbox is enabled)
- Request appropriate entitlements (e.g., `com.apple.security.files.user-selected.read-write`)
- Test with sandbox enabled and disabled

### Risk 2: Core API Integration Failures
**Risk**: Core API invocations may fail, return unexpected results, or have different error handling than expected.

**Mitigation**:
- Use Core APIs directly (no CLI invocation)
- Handle all Core API error types gracefully
- Display user-facing error messages for all error cases
- Test with various error conditions (permission denied, invalid paths, existing libraries)
- Validate Core API results before proceeding

### Risk 3: Async Operation Handling
**Risk**: Core API operations have different async patterns (completion callbacks for create, synchronous throwing for adopt), which may cause UI state issues or race conditions.

**Mitigation**:
- Run all Core API operations off MainActor (Task.detached or background queue)
- For async APIs (`LibraryCreator.createLibrary`), handle completion callbacks off MainActor
- For sync APIs (`LibraryAdopter.adoptLibrary`), wrap in Task.detached to call off MainActor
- Update UI state on MainActor only
- Show progress indicators during async operations
- Handle cancellation and cleanup properly
- Test with slow operations and cancellation scenarios

### Risk 4: Preview Accuracy
**Risk**: Preview may not accurately reflect actual operation results, causing user confusion. Create operations use simulated preview (not Core API dry-run), which may differ from actual execution.

**Mitigation**:
- Use Core API dry-run mode (`dryRun: true`) for adopt operation previews
- For create operations, use `LibraryPathValidator` and simulate metadata structure in-memory to match what Core API would create
- Display preview information clearly with "Preview" indicators
- Ensure preview and execution use the same Core API paths (for adopt) or same validation logic (for create)
- Test that preview matches execution results for various scenarios

### Risk 5: Wizard State Management
**Risk**: Wizard state may become inconsistent if user navigates back and forth or cancels mid-operation.

**Mitigation**:
- Maintain clear wizard state (current step, selected path, preview results)
- Reset wizard state on cancellation
- Validate wizard state before proceeding to next step
- Test navigation scenarios (back, forward, cancel, retry)

### Risk 6: Idempotent Adoption Handling
**Risk**: Adoption wizard may not properly handle already-adopted libraries, causing errors or duplicate operations.

**Mitigation**:
- Use Core API `LibraryAdopter.adoptLibrary` which handles idempotent behavior
- Display clear message when library is already adopted
- Test idempotent adoption scenarios
- Ensure wizard shows appropriate feedback for already-adopted libraries

### Risk 7: LibraryCreationConfirmationHandler Integration
**Risk**: `LibraryCreator.createLibrary` uses a confirmation handler pattern that may conflict with wizard confirmation dialogs, causing duplicate confirmations or blocking wizard flow.

**Mitigation**:
- Provide a custom `LibraryCreationConfirmationHandler` implementation that automatically confirms all Core-level confirmation requests
- The custom handler must bypass confirmations for non-empty directories and existing libraries since the wizard handles these in the UI
- Test that wizard confirmation dialogs are the only confirmation dialogs shown to users
- Ensure Core API proceeds without blocking on confirmation when wizard provides the custom handler

## Assumptions

- macOS 13.0 (Ventura) or later for SwiftUI features
- Core APIs (`LibraryCreator`, `LibraryAdopter`) are available and stable
- Users have write access to directories where they want to create libraries
- Users have read access to directories they want to adopt
- Library metadata files (`.mediahub/library.json`) follow the schema defined in Slice 1
- App may run in sandboxed environment (requires appropriate entitlements and security-scoped bookmarks)
- Wizard state is session-only (not persisted across app launches)
- Users understand the difference between "create" (new empty library) and "adopt" (existing directory with media files)

## Key Entities *(include if feature involves data)*

- **CreateWizardState**: Wizard state tracking current step, selected path, preview results, and confirmation status for library creation
- **AdoptWizardState**: Wizard state tracking current step, selected path, preview results (including baseline scan summary), and confirmation status for library adoption
- **WizardPreview**: Preview information showing what will be created (metadata location, operation type, baseline scan summary for adoption)
- **WizardConfirmation**: Confirmation dialog state with summary information and user action (confirm/cancel)
