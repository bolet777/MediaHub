# Implementation Plan: UI Persistence v1 — Sidebar Libraries & Auto-Reopen

**Feature**: UI Persistence v1 — Sidebar Libraries & Auto-Reopen  
**Specification**: `specs/014a-ui-persistence-v1/spec.md`  
**Slice**: 14a - Persist UI state so users keep their library list and context across app relaunches  
**Created**: 2026-01-27

## Plan Scope

This plan implements **Slice 14a only**, which adds UI state persistence using UserDefaults. This includes:

- UserDefaults persistence service for library list, discovery root, and last opened library
- AppState integration for persisting and restoring state
- ContentView auto-open logic for restoring last opened library on launch
- Graceful error handling for missing/inaccessible libraries

**Explicitly out of scope**:
- Security-scoped bookmarks (deferred to Slice 18)
- Core or CLI changes (persistence is UI-only)
- Library metadata persistence (status, sources, etc.)
- Multi-library persistence or library history
- Automatic discovery on launch (optional, may be deferred)
- Persistence format versioning

## Goals / Non-Goals

### Goals
- Persist sidebar library list (library paths and discovery root) to UserDefaults
- Persist last opened library path to UserDefaults
- Restore library list on app launch
- Auto-open last opened library on app launch (if accessible)
- Handle missing/inaccessible libraries gracefully (non-blocking errors)
- Maintain backward compatibility (first launch behaves as before)

### Non-Goals
- Security-scoped bookmarks (deferred to Slice 18)
- Core or CLI changes
- Library metadata persistence
- Multi-library persistence
- Automatic discovery on launch (optional)
- Persistence format versioning

## Proposed Architecture

### Module Structure

The implementation adds a new persistence service to the UI layer and integrates it with existing `AppState` and `ContentView`.

**Targets**:
- `MediaHubUI` (UI framework, existing)
  - New `UIPersistenceService.swift` file with UserDefaults persistence methods
  - Modified `AppState.swift` (add `persistState()` and `restoreState()` methods)
  - Modified `ContentView.swift` (add auto-open logic on launch)
  - Modified `MediaHubUIApp.swift` (optional: trigger state restoration on app launch)

**Boundaries**:
- **UI Layer**: Persistence service and state restoration logic
- **Core Layer**: No changes (uses existing `LibraryStatusService`, `LibraryPathValidator`)
- **CLI Layer**: No changes

### Component Overview

#### UIPersistenceService (`UIPersistenceService.swift`)

1. **Persistence Methods**
   - `static func persistLibraryList(_ libraries: [DiscoveredLibrary], discoveryRoot: String?)` - Persists library list and discovery root to UserDefaults
   - `static func persistLastOpenedLibrary(_ path: String?)` - Persists last opened library path to UserDefaults
   - `static func clearPersistence()` - Clears all persisted UI state (for testing/debugging)

2. **Restoration Methods**
   - `static func restoreLibraryList() -> ([DiscoveredLibrary], String?)` - Restores library list and discovery root from UserDefaults
   - `static func restoreLastOpenedLibrary() -> String?` - Restores last opened library path from UserDefaults

3. **UserDefaults Keys**
   - `"mediahub.ui.libraryList"` - Array of library dictionaries (path, displayName, isValid)
   - `"mediahub.ui.discoveryRoot"` - String path to discovery root folder
   - `"mediahub.ui.lastOpenedLibrary"` - String path to last opened library

4. **DiscoveredLibrary Persistence**
   - `DiscoveredLibrary` must be `Codable` or converted to/from dictionary format
   - On restore, re-validate libraries using `LibraryPathValidator` to update `isValid` status

#### AppState Integration (`AppState.swift`)

5. **Persistence Methods**
   - `func persistState()` - Saves `discoveredLibraries`, `discoveryRootPath`, and `openedLibraryPath` to UserDefaults via `UIPersistenceService`
   - Called when: library list changes (after discovery), library is opened, library is closed

6. **Restoration Methods**
   - `func restoreState()` - Loads persisted state from UserDefaults via `UIPersistenceService` and sets `discoveredLibraries`, `discoveryRootPath`, and `openedLibraryPath`
   - Called on app launch (in `MediaHubUIApp` or `ContentView.onAppear`)
   - Re-validates libraries using `LibraryPathValidator` to update `isValid` status

#### ContentView Auto-Open Integration (`ContentView.swift`)

7. **Auto-Open Logic**
   - Add `.onAppear` or `.task` modifier to attempt auto-open of last opened library on launch
   - Check if `appState.openedLibraryPath` is set (from restoration)
   - If set, attempt to open library using `LibraryStatusService.openLibrary(at:)`
   - If successful, library opens normally (same as manual selection)
   - If failed (missing/inaccessible), show error message and clear `openedLibraryPath`

8. **Error Handling**
   - Missing library: Clear persisted path, show error message in UI (`appState.libraryOpenError`)
   - Invalid library: Clear persisted path, show error message in UI
   - Corrupted persistence data: Clear persisted data, fallback to empty state
   - All errors are non-blocking (app launches successfully even if auto-open fails)

#### MediaHubUIApp Integration (`MediaHubUIApp.swift`)

9. **State Restoration Trigger**
   - Optional: Add `.onAppear` or initialization logic to call `appState.restoreState()` on app launch
   - Alternative: Trigger restoration in `ContentView.onAppear` (simpler, keeps logic in ContentView)

## Implementation Phases

### Phase 1: UIPersistenceService Implementation (Read-Only First)

**Goal**: Create persistence service with UserDefaults integration, test read/write operations.

**Steps**:
1. Create `Sources/MediaHubUI/UIPersistenceService.swift`
2. Implement `persistLibraryList(_:discoveryRoot:)` method (writes to UserDefaults)
3. Implement `restoreLibraryList()` method (reads from UserDefaults, returns empty state if missing)
4. Implement `persistLastOpenedLibrary(_:)` method (writes to UserDefaults)
5. Implement `restoreLastOpenedLibrary()` method (reads from UserDefaults, returns nil if missing)
6. Implement `clearPersistence()` method (clears all keys, for testing)
7. Handle `DiscoveredLibrary` serialization (make `DiscoveredLibrary` `Codable` or convert to/from dictionary)

**Validation**: 
- Unit tests or manual verification: Persist library list, restore it, verify data matches
- Persist last opened library, restore it, verify path matches
- Clear persistence, verify UserDefaults keys are removed

**Read-Only Guarantee**: This phase only writes to UserDefaults, never modifies library files or Core data.

### Phase 2: AppState Persistence Integration

**Goal**: Integrate persistence service with AppState, add persist/restore methods.

**Steps**:
1. Modify `Sources/MediaHubUI/AppState.swift`
2. Add `func persistState()` method that calls `UIPersistenceService` methods
3. Add `func restoreState()` method that calls `UIPersistenceService` methods and sets `discoveredLibraries`, `discoveryRootPath`, `openedLibraryPath`
4. Add re-validation logic in `restoreState()`: For each restored library, validate using `LibraryPathValidator.validateSelectedLibraryPath()` and update `isValid` status
5. Add error handling: If restoration fails (corrupted data), fallback to empty state

**Validation**:
- Manual verification: Call `appState.persistState()`, close app, call `appState.restoreState()`, verify state matches
- Test error handling: Corrupt UserDefaults data, verify restoration falls back to empty state

**Read-Only Guarantee**: This phase only reads/writes UserDefaults, never modifies library files or Core data.

### Phase 3: Persistence Trigger Integration

**Goal**: Trigger persistence when state changes (library discovery, library open/close).

**Steps**:
1. Modify `Sources/MediaHubUI/ContentView.swift`
2. In `chooseFolder()` completion handler (after discovery completes), call `appState.persistState()`
3. In `handleLibrarySelection(_:)` (after library opens successfully), call `appState.persistState()`
4. In `handleWizardCompletion(libraryPath:)` (after library opens successfully), call `appState.persistState()`
5. When library is closed (if close action exists), call `appState.persistState()` with `openedLibraryPath = nil`

**Validation**:
- Manual verification: Discover libraries, close app, verify library list persists
- Open library, close app, verify last opened library persists
- Close library (if close action exists), verify `openedLibraryPath` is cleared

**Read-Only Guarantee**: This phase only triggers persistence, never modifies library files or Core data.

### Phase 4: State Restoration on Launch

**Goal**: Restore persisted state on app launch, populate sidebar and attempt auto-open.

**Steps**:
1. Modify `Sources/MediaHubUI/ContentView.swift` or `Sources/MediaHubUI/MediaHubUIApp.swift`
2. Add `.onAppear` or `.task` modifier to call `appState.restoreState()` on app launch
3. Verify restored state: `discoveredLibraries`, `discoveryRootPath`, `openedLibraryPath` are set from UserDefaults
4. Verify libraries are re-validated: Invalid libraries are marked as `isValid = false`

**Validation**:
- Manual verification: Persist library list, close app, reopen app, verify library list is restored in sidebar
- Persist last opened library, close app, reopen app, verify `openedLibraryPath` is restored (but library not yet opened)

**Read-Only Guarantee**: This phase only restores UI state, never modifies library files or Core data.

### Phase 5: Auto-Open Logic

**Goal**: Automatically open last opened library on app launch (if accessible).

**Steps**:
1. Modify `Sources/MediaHubUI/ContentView.swift`
2. Add `.task` or `.onAppear` modifier to check if `appState.openedLibraryPath` is set (from restoration)
3. If set, validate library path using `LibraryPathValidator.validateSelectedLibraryPath()`
4. If valid, attempt to open library using `LibraryStatusService.openLibrary(at:)`
5. If successful, call `appState.setOpenedLibrary(path:context:)` (library opens normally)
6. If failed (missing/inaccessible), show error message via `appState.clearOpenedLibrary(error:)` and clear persisted path

**Validation**:
- Manual verification: Persist last opened library, close app, reopen app, verify library is automatically opened
- Move library to different location, close app, reopen app, verify error message is shown and library is not opened
- Delete library, close app, reopen app, verify error message is shown and library is not opened

**Read-Only Guarantee**: This phase only opens libraries (read-only operation), never modifies library files. Error handling clears persisted paths but does not modify library files.

### Phase 6: Error Handling Refinement

**Goal**: Ensure all error cases are handled gracefully, no blocking errors.

**Steps**:
1. Test missing library scenario: Persist library path, move/delete library, verify graceful error handling
2. Test invalid library scenario: Persist library path, corrupt library metadata, verify graceful error handling
3. Test corrupted persistence data: Corrupt UserDefaults data, verify restoration falls back to empty state
4. Test invalid path string: Persist malformed path, verify graceful error handling
5. Ensure all errors are non-blocking: App launches successfully even if auto-open fails

**Validation**:
- Manual verification: All error scenarios tested, app launches successfully in all cases
- Error messages are clear and user-facing
- Persisted invalid data is cleared automatically

**Read-Only Guarantee**: This phase only handles errors, never modifies library files or Core data.

## Sequencing & Safety

### Read-Only First
- **Phase 1**: Persistence service (read/write UserDefaults only, no library access)
- **Phase 2**: AppState integration (read/write UserDefaults only, no library access)
- **Phase 3**: Persistence triggers (read UI state, write UserDefaults only, no library access)

### Restoration & Auto-Open
- **Phase 4**: State restoration (read UserDefaults, set UI state, validate libraries using read-only `LibraryPathValidator`)
- **Phase 5**: Auto-open logic (read library metadata using `LibraryStatusService.openLibrary`, read-only operation)
- **Phase 6**: Error handling (clear persisted paths, show errors, no library mutations)

### Safety Guarantees
- All persistence operations are read-only with respect to library data (only UserDefaults is modified)
- All restoration operations are read-only (only UI state is modified, libraries are opened but not modified)
- All error handling is non-blocking (app launches successfully even if restoration/auto-open fails)
- All library validation uses existing read-only Core APIs (`LibraryPathValidator`, `LibraryStatusService`)

## Async Handling

### MainActor Requirements
- `AppState` is `@MainActor`, so all state updates occur on MainActor
- `UIPersistenceService` methods are thread-safe (UserDefaults is thread-safe), but UI state updates must occur on MainActor
- `restoreState()` is called on MainActor (via `@MainActor` on `AppState`)
- Auto-open logic in `ContentView` runs on MainActor (SwiftUI views are MainActor)

### Task Handling
- State restoration on launch: Use `.onAppear` or `.task` modifier in `ContentView` or `MediaHubUIApp`
- Auto-open logic: Use `.task` modifier in `ContentView` to check `openedLibraryPath` and attempt auto-open
- Library validation: Use existing synchronous `LibraryPathValidator.validateSelectedLibraryPath()` (runs on MainActor)
- Library opening: Use existing synchronous `LibraryStatusService.openLibrary(at:)` (runs on MainActor)

## Error Handling Strategy

### Persistence Errors
- **Corrupted UserDefaults data**: Fallback to empty state, clear corrupted data
- **Serialization errors**: Fallback to empty state, log error (optional)
- **All errors are non-blocking**: App launches successfully even if persistence fails

### Restoration Errors
- **Missing persisted data**: Return empty state (first launch behavior)
- **Invalid library paths**: Mark libraries as invalid (`isValid = false`), show in UI
- **Corrupted library metadata**: Show error message, clear persisted path
- **All errors are non-blocking**: App launches successfully even if restoration fails

### Auto-Open Errors
- **Missing library**: Clear persisted path, show error message (`appState.libraryOpenError`)
- **Inaccessible library**: Clear persisted path, show error message
- **Invalid library**: Clear persisted path, show error message
- **All errors are non-blocking**: App launches successfully even if auto-open fails

## Testing Strategy

### Unit Testing (Optional)
- Test `UIPersistenceService` methods: Persist/restore library list, persist/restore last opened library
- Test `AppState.persistState()` and `restoreState()`: Verify state is persisted and restored correctly
- Test error handling: Corrupted data, invalid paths, missing data

### Manual Verification (Required)
- **First launch**: App shows empty state (no libraries, no opened library)
- **After discovery**: Library list persists after app restart
- **After opening library**: Last opened library persists after app restart
- **Auto-open**: Last opened library is automatically reopened on app launch (if accessible)
- **Missing library**: App handles missing library gracefully (error message, no crash)
- **Invalid library**: App handles invalid library gracefully (error message, no crash)
- **Corrupted persistence**: App handles corrupted UserDefaults data gracefully (empty state, no crash)

## Dependencies

- **Slice 11** (UI Shell v1 + Library Discovery): `AppState`, `ContentView`, `LibraryDiscoveryService`, `LibraryStatusService`, `LibraryPathValidator`, `DiscoveredLibrary`
- **Slice 14** (Progress + Cancel API minimale): No direct dependency

## Backward Compatibility

### First Launch Behavior
- Apps launched without persisted state (first launch) behave identically to current behavior (empty state, no libraries, no opened library)
- Restoration methods return empty state when no persisted data exists

### Existing Libraries
- Persistence does not affect existing libraries
- Libraries created/adopted by previous slices remain valid and accessible
- Persistence only stores paths, library validation uses existing Core APIs

### UI Behavior
- All existing UI workflows (discovery, selection, opening) work identically
- Persistence is additive and does not modify existing workflows
- Only adds state restoration on launch, no changes to existing workflows

## Open Questions & Risks

### Open Questions
1. **Re-discovery on launch**: Should the app automatically re-discover libraries from persisted discovery root on launch? (Decision: Optional for this slice, may be deferred to future slice)
2. **Persistence timing**: When exactly should state be persisted? (Decision: After discovery completes, after library opens, after library closes)
3. **Error message placement**: Where should error messages for missing/inaccessible libraries be shown? (Decision: Use `appState.libraryOpenError`, displayed in `ContentView`)

### Risks
- **Risk 1**: Persisted library paths may become stale if libraries are moved/deleted
  - **Mitigation**: Re-validate libraries on restore, handle errors gracefully, clear invalid persisted paths
- **Risk 2**: Auto-open may fail silently if library is inaccessible
  - **Mitigation**: Explicit error handling, show error messages, clear persisted paths on failure
- **Risk 3**: UserDefaults data may become corrupted
  - **Mitigation**: Error handling with fallback to empty state, clear corrupted data automatically

## Notes

- This slice is **UI-only** and does not modify Core or CLI logic
- Persistence uses UserDefaults (standard macOS persistence mechanism)
- Security-scoped bookmarks are explicitly deferred to Slice 18
- All persistence operations are read-only with respect to library data
- All restoration operations are read-only (libraries are opened but not modified)
- Error handling is non-blocking (app launches successfully even if restoration/auto-open fails)
