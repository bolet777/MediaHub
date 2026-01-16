# Implementation Tasks: UI Shell v1 + Library Discovery

**Feature**: UI Shell v1 + Library Discovery  
**Specification**: `specs/011-ui-shell-v1-library-discovery/spec.md`  
**Plan**: `specs/011-ui-shell-v1-library-discovery/plan.md`  
**Slice**: 11 - Basic SwiftUI macOS app shell with library discovery and status display  
**Created**: 2026-01-27

## Task Organization

Tasks are organized by phase and follow the implementation sequence defined in the plan. Each task is:
- Small and focused on a single deliverable (1–2 commands max per pass)
- Sequential with explicit dependencies
- Traceable to plan phases and spec requirements
- Read-only and in-memory state first; writes only for app-local persistence (optional)

---

## Phase 1 — App Shell Foundation

**Plan Reference**: Phase 1 (lines 300-308)  
**Goal**: Basic window structure and navigation  
**Dependencies**: None (Foundation)

### T-001: Create SwiftPM Executable Target and SwiftUI App Entry Point
**Priority**: P1  
**Summary**: Create new SwiftPM executable target "MediaHubUI" and main app entry point with basic window configuration.

**Expected Files Touched**:
- `Package.swift` (update: add MediaHubUI executable target)
- `Sources/MediaHubUI/MediaHubUIApp.swift` (new)
- `Sources/MediaHubUI/main.swift` (new, if needed)

**Steps**:
1. Update `Package.swift` to add new executable target "MediaHubUI":
   - Add target with `.executableTarget` type
   - Set platform to `.macOS(.v13)`
   - Add dependency on `MediaHub` product
   - Set path to `Sources/MediaHubUI`
2. Create `Sources/MediaHubUI/` directory structure
3. Create `MediaHubUIApp.swift` with `@main` struct conforming to `App`
4. Configure app window with title "MediaHub"
5. Create basic `ContentView` placeholder
6. Build and run via SwiftPM: `swift build` and `swift run MediaHubUI`, or open package in Xcode

**Done When**:
- Package builds successfully with new target
- App runs via SwiftPM or Xcode on package
- Window opens with title "MediaHub"
- Basic `ContentView` is displayed

**Dependencies**: None

---

### T-002: Implement AppState ObservableObject
**Priority**: P1  
**Summary**: Create the main app state management class with published properties.

**Expected Files Touched**:
- `Sources/MediaHubUI/AppState.swift` (new)

**Steps**:
1. Create `AppState` class conforming to `ObservableObject`
2. Add `@Published` properties:
   - `discoveredLibraries: [DiscoveredLibrary] = []`
   - `currentLibrary: OpenedLibrary? = nil`
   - `currentStatus: LibraryStatus? = nil`
   - `isLoading: Bool = false`
   - `errorMessage: String? = nil`
3. Mark class with `@MainActor`
4. Note: `DiscoveredLibrary` will be defined in T-006

**Done When**:
- `AppState` compiles
- All properties are `@Published` and accessible
- Type references are correct (will be resolved when T-006 completes)

**Dependencies**: T-001

---

### T-003: Implement ContentView with Sidebar Layout
**Priority**: P1  
**Summary**: Create the main content view with NavigationSplitView (sidebar + detail).

**Expected Files Touched**:
- `Sources/MediaHubUI/ContentView.swift` (new or update)

**Steps**:
1. Create `ContentView` struct conforming to `View`
2. Use `NavigationSplitView` with sidebar and detail pane
3. Sidebar: Placeholder list (empty for now)
4. Detail: Placeholder empty state view
5. Inject `AppState` as `@StateObject` or `@ObservedObject`

**Done When**:
- Window displays with sidebar and main content area
- Sidebar and detail panes are visible and resizable
- Layout adapts to window resizing

**Dependencies**: T-001, T-002

---

### T-004: Implement Empty State View
**Priority**: P1  
**Summary**: Create empty state view shown when no library is selected.

**Expected Files Touched**:
- `Sources/MediaHubUI/EmptyStateView.swift` (new)

**Steps**:
1. Create `EmptyStateView` struct conforming to `View`
2. Display welcome message: "Welcome to MediaHub"
3. Display instruction: "Select a folder to discover libraries"
4. Center content vertically and horizontally
5. Use appropriate SwiftUI styling (spacing, fonts)

**Done When**:
- Empty state view displays when no library is selected
- Message is clear and centered
- View is visually appealing

**Dependencies**: T-003

---

### T-005: Prepare Verification Content for validation.md — App Shell Foundation
**Priority**: P1  
**Summary**: Prepare manual verification steps for Phase 1 (content for validation.md, no file creation).

**Expected Files Touched**:
- None (content prepared for validation.md)

**Steps**:
1. Document verification steps for Phase 1:
   - Launch app
   - Verify window opens with title "MediaHub"
   - Verify sidebar and main content area are visible
   - Verify empty state message is displayed
   - Verify window can be resized and layout adapts
2. Document expected outcomes for each step
3. Note any issues or observations
4. Prepare content in format suitable for validation.md

**Done When**:
- Verification steps are prepared for validation.md
- All Phase 1 acceptance scenarios from User Story 4 are covered
- Content is ready to be included in validation.md

**Dependencies**: T-001 through T-004

---

## Phase 2 — Library Discovery

**Plan Reference**: Phase 2 (lines 310-319)  
**Goal**: Discover libraries from user-selected folder  
**Dependencies**: Phase 1

### T-006: Create DiscoveredLibrary Model
**Priority**: P1  
**Summary**: Define the data model for discovered libraries.

**Expected Files Touched**:
- `Sources/MediaHubUI/DiscoveredLibrary.swift` (new)

**Steps**:
1. Create `DiscoveredLibrary` struct
2. Properties:
   - `path: String`
   - `libraryId: String` (from metadata)
   - `libraryVersion: String` (from metadata)
3. Make it `Identifiable` (use `libraryId` as id)
4. Make it `Equatable` and `Hashable` for list operations

**Done When**:
- `DiscoveredLibrary` compiles
- Can be used in SwiftUI `List` and `ForEach`
- Properties match metadata from `.mediahub/library.json`

**Dependencies**: T-002

---

### T-007: Implement LibraryDiscoveryService
**Priority**: P1  
**Summary**: Create service class for library discovery operations.

**Expected Files Touched**:
- `Sources/MediaHubUI/LibraryDiscoveryService.swift` (new)

**Steps**:
1. Create `LibraryDiscoveryService` class
2. Add method `scanFolder(at path: String) async throws -> [DiscoveredLibrary]`
3. Implement recursive directory walk looking for `.mediahub/library.json`
4. For each found library:
   - Read and parse JSON file
   - Extract `libraryId` and `libraryVersion`
   - Create `DiscoveredLibrary` instance
   - Skip if JSON is invalid (log error, continue)
5. Sort results by path lexicographically
6. Return sorted array

**Done When**:
- Service can scan a folder and return discovered libraries
- Libraries are sorted deterministically (lexicographic by path)
- Invalid libraries are skipped (no crash)
- Method is `async` and can be called from SwiftUI

**Dependencies**: T-006

---

### T-008: Integrate NSOpenPanel for Folder Selection
**Priority**: P1  
**Summary**: Add folder picker button and NSOpenPanel integration in UI layer.

**Expected Files Touched**:
- `Sources/MediaHubUI/ContentView.swift` (update)
- `Sources/MediaHubUI/FolderPickerHelper.swift` (new, optional UI helper)

**Steps**:
1. Create `NSOpenPanel` helper in UI layer (e.g., in `ContentView` or small `FolderPickerHelper`):
   - Configure for directory selection only
   - Set appropriate title and message
   - Return selected folder path or `nil`
2. Add "Select Folder" button to sidebar or empty state
3. On button click: Show folder picker using UI helper
4. On folder selection: Call `LibraryDiscoveryService.scanFolder(at:)` and update `AppState.discoveredLibraries`

**Done When**:
- User can click button to open folder picker
- Folder picker allows directory selection
- Selected folder triggers discovery scan
- Discovered libraries appear in sidebar (after T-009)

**Dependencies**: T-007

---

### T-009: Display Discovered Libraries in Sidebar
**Priority**: P1  
**Summary**: Show discovered libraries in sidebar list.

**Expected Files Touched**:
- `Sources/MediaHubUI/ContentView.swift` (update)
- `Sources/MediaHubUI/LibraryListItemView.swift` (new, optional)

**Steps**:
1. Update sidebar in `ContentView` to show `AppState.discoveredLibraries`
2. Use `List` with `ForEach` to display libraries
3. Display library path or library ID in list item
4. Handle empty state: Show "No libraries found" when list is empty
5. Add loading indicator during discovery scan

**Done When**:
- Discovered libraries appear in sidebar list
- Libraries are displayed in sorted order (lexicographic by path)
- Empty state shows appropriate message
- Loading indicator appears during scan

**Dependencies**: T-008

---

### T-010: Handle Discovery Error States
**Priority**: P1  
**Summary**: Display clear error messages for discovery failures.

**Expected Files Touched**:
- `Sources/MediaHubUI/LibraryDiscoveryService.swift` (update)
- `Sources/MediaHubUI/ContentView.swift` (update)

**Steps**:
1. Define discovery error types:
   - Permission denied
   - Invalid library (skip, log)
2. Catch errors in discovery flow
3. Map errors to user-facing messages:
   - Permission denied: "You don't have permission to access this folder. Please select a different folder."
4. Display errors using SwiftUI `Alert` or inline message
5. Clear error state when user takes action (selects different folder)
6. Handle empty results (0 libraries found) as normal empty state in UI, not as error

**Done When**:
- Permission errors show clear message
- Empty folder (0 libraries) shows normal empty state message (not error/alert)
- Invalid libraries are skipped (no crash)
- Errors are user-facing and actionable

**Dependencies**: T-008

---

### T-011: Prepare Verification Content for validation.md — Library Discovery
**Priority**: P1  
**Summary**: Prepare manual verification steps for Phase 2 (content for validation.md, no file creation).

**Expected Files Touched**:
- None (content prepared for validation.md)

**Steps**:
1. Document verification steps for Phase 2:
   - Create test libraries: `mediahub library create /tmp/test-lib-1`, `mediahub library create /tmp/test-lib-2`, `mediahub library create /tmp/test-lib-zebra`
   - Launch app
   - Click "Select Folder" and choose `/tmp`
   - Verify all three libraries appear in sidebar
   - Verify libraries are sorted lexicographically (test-lib-1, test-lib-2, test-lib-zebra)
   - Select empty folder, verify "no libraries found" message
2. Document expected outcomes for each step
3. Prepare content in format suitable for validation.md

**Done When**:
- Verification steps are prepared for validation.md
- All Phase 2 acceptance scenarios from User Story 1 are covered
- Content is ready to be included in validation.md

**Dependencies**: T-006 through T-010

---

## Phase 3 — Open Library

**Plan Reference**: Phase 3 (lines 321-330)  
**Goal**: Open and validate discovered libraries  
**Dependencies**: Phase 2

### T-012: Implement Library Selection Handling
**Priority**: P1  
**Summary**: Handle library selection from sidebar and trigger opening.

**Expected Files Touched**:
- `Sources/MediaHubUI/ContentView.swift` (update)

**Steps**:
1. Add selection state to sidebar `List` (use `@State` for selected library)
2. On library selection: Call library opening method (T-013)
3. Update `AppState.currentLibrary` on successful open
4. Clear `AppState.currentStatus` when new library is selected

**Done When**:
- Clicking library in sidebar triggers opening flow
- Selection is visually indicated
- `AppState.currentLibrary` is updated on selection

**Dependencies**: T-009

---

### T-013: Implement LibraryStatusService.openLibrary
**Priority**: P1  
**Summary**: Create service method to open and validate libraries using Core APIs.

**Expected Files Touched**:
- `Sources/MediaHubUI/LibraryStatusService.swift` (new)

**Steps**:
1. Create `LibraryStatusService` class
2. Add method `openLibrary(at path: String) async throws -> OpenedLibrary`
3. Validate path exists and is accessible
4. Invoke Core API: `LibraryContext.openLibrary(at: path)`
5. Return `OpenedLibrary` on success
6. Map Core API errors to user-facing messages:
   - `LibraryOpeningError.metadataNotFound` → "Library metadata not found"
   - `LibraryOpeningError.metadataCorrupted` → "Library metadata is corrupted or invalid"
   - `LibraryOpeningError.permissionDenied` → "You don't have permission to access this library"
   - `LibraryOpeningError.structureInvalid` → "This directory is not a valid MediaHub library"
7. Throw errors with user-facing messages

**Done When**:
- Service can open libraries using Core APIs
- Errors are mapped to user-facing messages
- Method is `async` and can be called from SwiftUI

**Dependencies**: T-012

---

### T-014: Integrate Library Opening with AppState
**Priority**: P1  
**Summary**: Connect library opening to app state and handle errors.

**Expected Files Touched**:
- `Sources/MediaHubUI/ContentView.swift` (update)

**Steps**:
1. On library selection: Call `LibraryStatusService.openLibrary(at:)`
2. Wrap in `Task` block for async execution
3. On success: Update `AppState.currentLibrary`
4. On error: Set `AppState.errorMessage` and show `Alert`
5. Set `AppState.isLoading = true` during opening, `false` when done
6. Clear error state when user selects different library

**Done When**:
- Library opening updates `AppState.currentLibrary`
- Errors are displayed in `Alert`
- Loading state is managed correctly
- Error state clears on new selection

**Dependencies**: T-013

---

### T-015: Handle Moved/Deleted Library Detection
**Priority**: P1  
**Summary**: Detect when opened library is moved or deleted while app is running.

**Expected Files Touched**:
- `Sources/MediaHubUI/ContentView.swift` (update)
- `Sources/MediaHubUI/LibraryStatusService.swift` (update)

**Steps**:
1. Before accessing library (status load, etc.): Verify path still exists
2. If path doesn't exist: Clear `AppState.currentLibrary`, show error message
3. Error message: "The library at this location no longer exists."
4. Allow user to select different library

**Done When**:
- Moved/deleted library is detected on next access
- Error message is displayed
- User can select different library

**Dependencies**: T-014

---

### T-016: Prepare Verification Content for validation.md — Library Opening
**Priority**: P1  
**Summary**: Prepare manual verification steps for Phase 3 (content for validation.md, no file creation).

**Expected Files Touched**:
- None (content prepared for validation.md)

**Steps**:
1. Document verification steps for Phase 3:
   - Discover libraries (from Phase 2)
   - Select a valid library from sidebar
   - Verify library opens and status view appears (after Phase 4)
   - Create invalid library: `mkdir -p /tmp/test-lib-invalid/.mediahub && echo "invalid json" > /tmp/test-lib-invalid/.mediahub/library.json`
   - Discover and select invalid library, verify error message
   - Move library directory while app is running, verify error on next access
2. Document expected outcomes for each step
3. Prepare content in format suitable for validation.md

**Done When**:
- Verification steps are prepared for validation.md
- All Phase 3 acceptance scenarios from User Story 2 are covered
- Content is ready to be included in validation.md

**Dependencies**: T-012 through T-015

---

## Phase 4 — Status View

**Plan Reference**: Phase 4 (lines 332-341)  
**Goal**: Display library status using Core APIs  
**Dependencies**: Phase 3

### T-017: Create LibraryStatus Data Model
**Priority**: P1  
**Summary**: Define data model matching CLI status information semantically (same values when available), without requiring exact JSON schema/field order.

**Expected Files Touched**:
- `Sources/MediaHubUI/LibraryStatus.swift` (new)

**Steps**:
1. Create `LibraryStatus` struct
2. Properties matching CLI JSON contract:
   - `path: String`
   - `identifier: String`
   - `version: String`
   - `sourceCount: Int`
   - `sources: [SourceInfo]`
   - `statistics: StatisticsInfo?` (optional)
   - `hashCoverage: HashCoverageInfo?` (optional)
   - `performance: PerformanceInfo?` (optional)
3. Create nested structs: `SourceInfo`, `StatisticsInfo`, `HashCoverageInfo`, `PerformanceInfo`
4. Make all optional fields properly optional (nil when baseline index missing)

**Done When**:
- `LibraryStatus` compiles
- Structure matches CLI status information semantically (same values when available), without requiring exact JSON schema/field order
- Optional fields are correctly typed

**Dependencies**: None (can be done in parallel with other tasks)

---

### T-018: Implement LibraryStatusService.loadStatus
**Priority**: P1  
**Summary**: Create service method to load library status using Core APIs (equivalent to StatusCommand).

**Expected Files Touched**:
- `Sources/MediaHubUI/LibraryStatusService.swift` (update)

**Steps**:
1. Add method `loadStatus(for libraryPath: String) async throws -> LibraryStatus`
2. Use existing Core APIs (equivalent to `StatusCommand.run()`) to obtain the same information:
   - Open library and retrieve sources
   - Load baseline index if available
   - Compute statistics and scale metrics when index is available
3. Build `LibraryStatus` from Core API results
4. Handle nil cases for statistics and hash coverage (when index missing) - display "N/A" to match CLI behavior
5. Return `LibraryStatus` instance that matches CLI status information semantically (same values when available), without requiring exact JSON schema/field order

**Done When**:
- Service can load status using Core APIs
- Status data matches CLI status information semantically (same values when available), without requiring exact JSON schema/field order
- Nil cases are handled correctly (N/A when index missing, matching CLI behavior)

**Dependencies**: T-017

---

### T-019: Create StatusViewModel
**Priority**: P1  
**Summary**: Create view model for status display with formatted strings.

**Expected Files Touched**:
- `Sources/MediaHubUI/StatusViewModel.swift` (new)

**Steps**:
1. Create `StatusViewModel` struct
2. Initialize from `LibraryStatus`
3. Add computed properties for formatted display:
   - Formatted numbers (comma separators)
   - Formatted file sizes (human-readable)
   - "N/A" strings for nil statistics/hash coverage
   - Formatted dates
4. Handle all display cases (with/without index, with/without sources)

**Done When**:
- `StatusViewModel` compiles
- All display properties are formatted correctly
- "N/A" is shown for missing data (matching CLI behavior)

**Dependencies**: T-017

---

### T-020: Implement StatusView SwiftUI
**Priority**: P1  
**Summary**: Create SwiftUI view to display library status.

**Expected Files Touched**:
- `Sources/MediaHubUI/StatusView.swift` (new)

**Steps**:
1. Create `StatusView` struct conforming to `View`
2. Accept `StatusViewModel` as parameter
3. Display all status fields:
   - Path, ID, Version, Source Count
   - Sources list (if any)
   - Statistics section (or "N/A" if nil)
   - Hash Coverage section (or "N/A" if nil)
   - Performance section (or "N/A" if nil)
4. Use appropriate SwiftUI layout (VStack, sections, etc.)
5. Match CLI human-readable output format (as reference)

**Done When**:
- Status view displays all status information
- "N/A" is shown for missing statistics/hash coverage
- Layout is clear and readable
- Matches CLI output format (visually similar)

**Dependencies**: T-019

---

### T-021: Integrate Status Loading with AppState
**Priority**: P1  
**Summary**: Connect status loading to app state and display in detail pane.

**Expected Files Touched**:
- `Sources/MediaHubUI/ContentView.swift` (update)

**Steps**:
1. When `AppState.currentLibrary` is set: Trigger status loading
2. Call `LibraryStatusService.loadStatus(for:)` in `Task` block
3. Set `AppState.isLoading = true` during load
4. On success: Update `AppState.currentStatus`
5. On error: Set `AppState.errorMessage`
6. Set `AppState.isLoading = false` when done
7. Update detail pane to show `StatusView` when `currentStatus` is available
8. Show loading indicator during status load

**Done When**:
- Status loading is triggered when library is opened
- Status view appears in detail pane
- Loading indicator shows during load
- Errors are handled gracefully

**Dependencies**: T-018, T-020

---

### T-022: Handle Status Loading Errors
**Priority**: P1  
**Summary**: Display clear error messages for status loading failures.

**Expected Files Touched**:
- `Sources/MediaHubUI/ContentView.swift` (update)

**Steps**:
1. Catch errors from `loadStatus(for:)`
2. Map to user-facing message: "Failed to load library status. Please try opening the library again."
3. Display error in detail pane (inline message or Alert)
4. Allow user to retry by selecting library again

**Done When**:
- Status loading errors show clear message
- User can retry by selecting library again
- Error doesn't crash app

**Dependencies**: T-021

---

### T-023: Prepare Verification Content for validation.md — Status Display
**Priority**: P1  
**Summary**: Prepare manual verification steps for Phase 4 (content for validation.md, no file creation).

**Expected Files Touched**:
- None (content prepared for validation.md)

**Steps**:
1. Document verification steps for Phase 4:
   - Open library with baseline index (adopt existing media: `mediahub library adopt /path/to/media --yes`)
   - Verify status view shows: path, ID, version, source count, statistics, hash coverage, performance metrics
   - Open library without baseline index (new empty library: `mediahub library create /tmp/test-empty`)
   - Verify status view shows: path, ID, version, source count, with "N/A" for statistics and hash coverage
   - Compare UI status with CLI: `mediahub status --json <library-path>`
   - Verify status information matches CLI status information semantically (same values when available), without requiring exact JSON schema/field order
2. Document expected outcomes for each step
3. Prepare content in format suitable for validation.md

**Done When**:
- Verification steps are prepared for validation.md
- All Phase 4 acceptance scenarios from User Story 3 are covered
- Status matching CLI output is verified
- Content is ready to be included in validation.md

**Dependencies**: T-017 through T-022

---

## Phase 5 — Persistence (Optional)

**Plan Reference**: Phase 5 (lines 343-351)  
**Goal**: Remember last-opened library across app launches  
**Dependencies**: Phase 3 (library opening must work)

**Note**: This phase is optional and can be deferred if sandbox complexity is high.

### T-024: Create LibraryPersistenceService
**Priority**: P2 (Optional)  
**Summary**: Create service for persisting last-opened library path.

**Expected Files Touched**:
- `Sources/MediaHubUI/LibraryPersistenceService.swift` (new)

**Steps**:
1. Create `LibraryPersistenceService` class
2. Add method `saveLastOpenedLibrary(path: String)`
3. Store path in UserDefaults with key `lastOpenedLibraryPath`
4. Add method `loadLastOpenedLibrary() -> String?`
5. Read path from UserDefaults, return `nil` if not found

**Done When**:
- Service can save and load library path from UserDefaults
- Methods are synchronous and simple

**Dependencies**: T-013

---

### T-025: Integrate Persistence with Library Opening
**Priority**: P2 (Optional)  
**Summary**: Save library path when library is opened.

**Expected Files Touched**:
- `Sources/MediaHubUI/ContentView.swift` (update)

**Steps**:
1. When library is successfully opened: Call `LibraryPersistenceService.saveLastOpenedLibrary(path:)`
2. Save library path from `AppState.currentLibrary`
3. Handle save errors gracefully (log, don't crash)

**Done When**:
- Library path is saved when library is opened
- Save errors don't crash app

**Dependencies**: T-024

---

### T-026: Restore Last-Opened Library on Launch
**Priority**: P2 (Optional)  
**Summary**: Attempt to restore last-opened library on app launch.

**Expected Files Touched**:
- `Sources/MediaHubUI/MediaHubUIApp.swift` (update)
- `Sources/MediaHubUI/ContentView.swift` (update)

**Steps**:
1. On app launch: Call `LibraryPersistenceService.loadLastOpenedLibrary()`
2. If path exists: Validate path still exists and is accessible
3. If valid: Open library using `LibraryStatusService.openLibrary(at:)`
4. If invalid: Clear persisted value, show empty state (no error)
5. Handle all errors gracefully (fall back to empty state)

**Done When**:
- Last-opened library is restored on app launch (if valid)
- Invalid paths are cleared (no error shown)
- App falls back to empty state gracefully

**Dependencies**: T-025

---

### T-027: Security-Scoped Bookmark Support (Optional)
**Priority**: P2 (Optional, Deferred)  
**Summary**: Add security-scoped bookmark support for sandboxed environments.

**Expected Files Touched**:
- `Sources/MediaHubUI/LibraryPersistenceService.swift` (update)

**Steps**:
1. Detect if app is sandboxed
2. If sandboxed: Store security-scoped bookmark (NSData) instead of path
3. If not sandboxed: Use path storage (existing behavior)
4. On load: Resolve bookmark to path, start accessing security-scoped resource
5. Handle bookmark resolution errors gracefully

**Done When**:
- Security-scoped bookmarks work in sandboxed environment
- Non-sandboxed environment still uses path storage
- Errors are handled gracefully

**Dependencies**: T-024

**Note**: This task can be deferred if sandbox testing reveals it's not necessary.

---

### T-028: Prepare Verification Content for validation.md — Persistence
**Priority**: P2 (Optional)  
**Summary**: Prepare manual verification steps for Phase 5 (content for validation.md, no file creation).

**Expected Files Touched**:
- None (content prepared for validation.md)

**Steps**:
1. Document verification steps for Phase 5:
   - Open a library in app
   - Quit app
   - Relaunch app
   - Verify last-opened library is restored (if valid)
   - Move library directory
   - Relaunch app
   - Verify app falls back to empty state (no error)
2. Document expected outcomes for each step
3. Prepare content in format suitable for validation.md

**Done When**:
- Verification steps are prepared for validation.md
- Persistence scenarios are covered
- Content is ready to be included in validation.md

**Dependencies**: T-024 through T-026

---

## Testing & Validation

### T-029: Prepare Smoke Checklist Content for validation.md
**Priority**: P1  
**Summary**: Prepare comprehensive smoke test checklist content for validation.md (no file creation).

**Expected Files Touched**:
- None (content prepared for validation.md)

**Steps**:
1. Prepare test scenarios for each user story:
   - User Story 1: Discovery scenarios (valid, empty, permission denied)
   - User Story 2: Opening scenarios (valid, invalid, moved/deleted)
   - User Story 3: Status display scenarios (with/without index)
   - User Story 4: App shell navigation
2. Document CLI commands for test setup
3. Document expected outcomes for each scenario
4. Document success criteria verification steps
5. Format content for inclusion in validation.md

**Done When**:
- Smoke checklist content covers all user stories
- Test setup commands are documented
- Expected outcomes are clear
- Content is ready to be included in validation.md

**Dependencies**: T-011, T-016, T-023

---

### T-030: Prepare Success Criteria Verification Content for validation.md
**Priority**: P1  
**Summary**: Prepare success criteria verification content for validation.md (no file creation).

**Expected Files Touched**:
- None (content prepared for validation.md)

**Steps**:
1. Prepare verification steps for all success criteria:
   - SC-001: Discovery time < 5 seconds (for up to 10 libraries)
   - SC-002: Open time < 2 seconds
   - SC-003: Status matches CLI status information semantically (same values when available), without requiring exact JSON schema/field order
   - SC-004: Error handling (all error cases tested)
   - SC-005: Deterministic ordering (multiple launches)
   - SC-006: Backward compatibility (libraries from slices 1–10)
   - SC-007: N/A display (libraries without index)
   - SC-008: Window opens < 1 second
2. Document measurement procedures
3. Document expected thresholds
4. Format content for inclusion in validation.md

**Done When**:
- All success criteria verification steps are prepared
- Measurement procedures are documented
- Content is ready to be included in validation.md

**Dependencies**: T-029

---

## Task Dependencies Summary

**Phase 1** (App Shell):
- T-001 → T-002 → T-003 → T-004 → T-005

**Phase 2** (Discovery):
- T-006 → T-007 → T-008 → T-009 → T-010 → T-011
- Depends on: T-002

**Phase 3** (Open Library):
- T-012 → T-013 → T-014 → T-015 → T-016
- Depends on: T-009

**Phase 4** (Status View):
- T-017 (parallel) → T-018 → T-019 → T-020 → T-021 → T-022 → T-023
- Depends on: T-014

**Phase 5** (Persistence, Optional):
- T-024 → T-025 → T-026 → T-028
- T-027 (optional, can be deferred)
- Depends on: T-013

**Testing**:
- T-029 → T-030
- Depends on: T-011, T-016, T-023
