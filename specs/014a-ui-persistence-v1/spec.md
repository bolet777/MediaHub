# Feature Specification: UI Persistence v1 — Sidebar Libraries & Auto-Reopen

**Feature Branch**: `014a-ui-persistence-v1`  
**Created**: 2026-01-27  
**Status**: Draft  
**Input**: User description: "Persist UI state so users keep their library list and context across app relaunches"

## Overview

This slice adds UI state persistence so users retain their library list and active library context across app relaunches. Currently, MediaHubUI loses all state on app restart, requiring users to re-discover libraries and re-open their active library manually. This slice persists the sidebar library list and last opened library, restoring them on app launch.

**Problem Statement**: On app relaunch, MediaHubUI loses the list of discovered libraries and the active library context. Users must manually choose a discovery folder, wait for library discovery, and re-open their library. This is acceptable for early development but not for real usage. Users expect their library list and active context to persist across app relaunches.

**Architecture Principle**: UI persistence is UI-only and uses UserDefaults. No Core or CLI logic is modified. Persistence stores library paths (strings) and discovery root paths. On relaunch, the UI restores these paths and attempts to re-discover libraries and re-open the last active library. If libraries are missing or inaccessible, the UI handles errors gracefully without blocking app launch.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Persist Sidebar Library List (Priority: P1)

A user wants their library list to persist in the sidebar across app relaunches, so they don't need to re-discover libraries every time they open the app.

**Why this priority**: This is a core user experience requirement. Users expect their library list to persist, and re-discovering libraries on every launch is a significant friction point.

**Independent Test**: Can be fully tested by opening the app, discovering libraries, closing the app, and verifying the library list is restored on relaunch.

**Acceptance Scenarios**:

1. **Given** a user has discovered libraries in the sidebar, **When** the app is closed and reopened, **Then** the sidebar shows the same library list (same libraries, same order)
2. **Given** a user has discovered libraries from a specific folder, **When** the app is closed and reopened, **Then** the sidebar shows libraries from the same discovery root folder (discovery root is persisted, but automatic re-discovery on launch is optional/P2)
3. **Given** a user has discovered libraries, **When** the app is closed and reopened, **Then** libraries that are no longer accessible (moved/deleted) are shown as invalid or removed from the list gracefully
4. **Given** a user has never discovered libraries, **When** the app is opened, **Then** the sidebar shows an empty state (no libraries, no error)

---

### User Story 2 - Persist Last Opened Library (Priority: P1)

A user wants their last opened library to be automatically reopened on app launch, so they can continue working where they left off.

**Why this priority**: This is a core user experience requirement. Users expect their active context to persist, and manually re-opening libraries on every launch is a significant friction point.

**Independent Test**: Can be fully tested by opening a library, closing the app, and verifying the library is automatically reopened on relaunch.

**Acceptance Scenarios**:

1. **Given** a user has opened a library, **When** the app is closed and reopened, **Then** the app attempts to automatically reopen the last opened library
2. **Given** a user has opened a library, **When** the app is closed and reopened, **Then** if the library is still accessible, the library opens successfully and the detail view shows the library status and sources
3. **Given** a user has opened a library, **When** the app is closed and reopened, **Then** if the library is no longer accessible (moved/deleted), the app shows a clear error message and does not block app launch
4. **Given** a user has opened a library, **When** the app is closed and reopened, **Then** if the library path is invalid or the library metadata is corrupted, the app shows a clear error message and does not block app launch
5. **Given** a user has never opened a library, **When** the app is opened, **Then** the app shows the empty state (no library opened, no error)

---

### User Story 3 - Graceful Error Handling for Missing Libraries (Priority: P1)

A user wants the app to handle missing or inaccessible libraries gracefully, without blocking app launch or causing crashes.

**Why this priority**: Libraries may be moved, deleted, or become inaccessible (e.g., external drive disconnected). The app must handle these cases gracefully to maintain a good user experience.

**Independent Test**: Can be fully tested by persisting a library path, moving/deleting the library, and verifying the app handles the error gracefully on relaunch.

**Acceptance Scenarios**:

1. **Given** a persisted library path points to a moved library, **When** the app is opened, **Then** the app detects the library is missing and shows a clear error message (e.g., "Library no longer accessible")
2. **Given** a persisted library path points to a deleted library, **When** the app is opened, **Then** the app detects the library is missing and removes it from the persisted list (or marks it as invalid)
3. **Given** a persisted library path points to an inaccessible library (e.g., external drive disconnected), **When** the app is opened, **Then** the app detects the library is inaccessible and shows a clear error message without blocking app launch
4. **Given** a persisted library path points to a corrupted library (invalid .mediahub/library.json), **When** the app is opened, **Then** the app detects the library is invalid and shows a clear error message without blocking app launch
5. **Given** a persisted library path is invalid (malformed path string), **When** the app is opened, **Then** the app handles the invalid path gracefully and does not crash

---

## Success Criteria

### SC-001: Sidebar Library List Persistence
- **Requirement**: The app persists the sidebar library list (library paths and discovery root path) to UserDefaults
- **Validation**: After discovering libraries and closing the app, the library list is restored on relaunch
- **Priority**: P1

### SC-002: Last Opened Library Persistence
- **Requirement**: The app persists the last opened library path to UserDefaults
- **Validation**: After opening a library and closing the app, the last opened library path is restored on relaunch
- **Priority**: P1

### SC-003: Auto-Reopen on Launch
- **Requirement**: On app launch, the app attempts to automatically reopen the last opened library (if persisted)
- **Validation**: After opening a library and closing the app, the library is automatically reopened on relaunch (if still accessible)
- **Priority**: P1

### SC-004: Graceful Handling of Missing Libraries
- **Requirement**: If a persisted library path is missing or inaccessible, the app shows a clear error message and does not block app launch
- **Validation**: After persisting a library path, moving/deleting the library, and reopening the app, the app handles the error gracefully
- **Priority**: P1

### SC-005: Graceful Handling of Invalid Libraries
- **Requirement**: If a persisted library path points to an invalid or corrupted library, the app shows a clear error message and does not block app launch
- **Validation**: After persisting a library path, corrupting the library metadata, and reopening the app, the app handles the error gracefully
- **Priority**: P1

### SC-006: Discovery Root Persistence
- **Requirement**: The app persists the discovery root path to UserDefaults (if available)
- **Validation**: After discovering libraries from a folder and closing the app, the discovery root is restored on relaunch (for future use; automatic re-discovery on launch is optional/P2, not required for P1)
- **Priority**: P1

### SC-007: Empty State Handling
- **Requirement**: If no libraries are persisted, the app shows an empty state (no libraries, no error)
- **Validation**: After launching the app with no persisted libraries, the sidebar shows an empty state
- **Priority**: P1

### SC-008: State Synchronization
- **Requirement**: Persisted state is synchronized with UI state (sidebar list, opened library) on app launch
- **Validation**: After relaunch, the UI state matches the persisted state (libraries shown, library opened if persisted and accessible)
- **Priority**: P1

---

## Non-Goals

- **Security-scoped bookmarks**: This slice does NOT implement security-scoped bookmarks for sandboxed access. Security-scoped bookmarks are deferred to Slice 18 (macOS Permissions + Distribution Hardening).
- **Core or CLI changes**: This slice does NOT modify Core or CLI logic. Persistence is UI-only using UserDefaults.
- **Library metadata persistence**: This slice does NOT persist library metadata (status, sources, etc.). Only library paths and discovery root paths are persisted.
- **Multi-library persistence**: This slice does NOT persist multiple opened libraries or library history. Only the last opened library is persisted.
- **Discovery auto-run**: This slice does NOT automatically run discovery on launch. Discovery may be triggered manually or in a future slice.
- **Library validation on persistence**: This slice does NOT validate library paths before persisting them. Validation occurs on restore/launch.
- **Persistence format versioning**: This slice does NOT implement versioning for persisted data. UserDefaults keys are fixed for this slice.

---

## API Requirements

### API-001: UserDefaults Persistence Service
- **Location**: `Sources/MediaHubUI/` (new file: `UIPersistenceService.swift` or similar)
- **Type**: `final class UIPersistenceService`
- **Methods**:
  - `static func persistLibraryList(_ libraries: [DiscoveredLibrary], discoveryRoot: String?)` - Persists library list and discovery root
  - `static func restoreLibraryList() -> ([DiscoveredLibrary], String?)` - Restores library list and discovery root
  - `static func persistLastOpenedLibrary(_ path: String?)` - Persists last opened library path
  - `static func restoreLastOpenedLibrary() -> String?` - Restores last opened library path
  - `static func clearPersistence()` - Clears all persisted UI state (for testing/debugging)
- **Storage**: Uses `UserDefaults.standard` with keys: `"mediahub.ui.libraryList"`, `"mediahub.ui.discoveryRoot"`, `"mediahub.ui.lastOpenedLibrary"`
- **Thread Safety**: All methods are thread-safe (UserDefaults is thread-safe)

### API-002: AppState Persistence Integration
- **Location**: `Sources/MediaHubUI/AppState.swift`
- **Changes**: 
  - Add methods to persist/restore state: `func persistState()`, `func restoreState()`
  - Add initialization logic to restore state on app launch
- **Behavior**: 
  - `persistState()` saves `discoveredLibraries`, `discoveryRootPath`, and `openedLibraryPath` to UserDefaults
  - `restoreState()` loads persisted state from UserDefaults and sets `discoveredLibraries`, `discoveryRootPath`, and `openedLibraryPath`
  - Restoration occurs on app launch (in `MediaHubUIApp` or `ContentView`)

### API-003: ContentView Auto-Open Integration
- **Location**: `Sources/MediaHubUI/ContentView.swift`
- **Changes**: 
  - Add `.onAppear` or `.task` modifier to attempt auto-open of last opened library on launch
  - Add error handling for missing/inaccessible libraries during auto-open
- **Behavior**: 
  - On app launch, if `appState.openedLibraryPath` is set (from restoration), attempt to open the library
  - If library is missing/inaccessible, show error message and clear `openedLibraryPath`
  - If library is valid, open it normally (same as manual selection)

### API-004: Library Discovery Service Integration
- **Location**: `Sources/MediaHubUI/LibraryDiscoveryService.swift` (no changes, used by ContentView)
- **Usage**: 
  - On app launch, if `discoveryRootPath` is restored, optionally trigger re-discovery (or defer to user action)
  - Re-discovery is optional for this slice (may be deferred to future slice)

---

## Safety Rules

### SR-001: Read-Only Persistence
- **Rule**: Persistence operations are read-only with respect to library data. Persistence only reads/writes UserDefaults, never modifies library files or metadata.
- **Enforcement**: Persistence service methods only interact with UserDefaults, never with library files or Core APIs.

### SR-002: Graceful Error Handling
- **Rule**: All persistence and restoration operations must handle errors gracefully. Missing or invalid persisted data must not crash the app or block app launch.
- **Enforcement**: All persistence methods use try-catch or optional handling. Invalid persisted data is ignored or cleared, with fallback to empty state.

### SR-003: No Core Mutations
- **Rule**: Persistence does not modify Core or CLI behavior. Persistence is UI-only and does not affect library files, source associations, or any Core data structures.
- **Enforcement**: Persistence service methods do not call Core APIs for writing. Only UI state (paths, lists) is persisted.

### SR-004: Validation on Restore
- **Rule**: Persisted library paths are validated on restore, not on persistence. Invalid paths are detected and handled gracefully during restoration.
- **Enforcement**: Restoration methods validate library paths using `LibraryPathValidator` before attempting to open libraries. Invalid paths are cleared or marked as invalid.

### SR-005: Idempotent Persistence
- **Rule**: Persistence operations are idempotent. Calling `persistState()` multiple times with the same state produces the same persisted result.
- **Enforcement**: Persistence methods overwrite previous values. No incremental updates or merging logic.

### SR-006: Thread Safety
- **Rule**: All persistence operations are thread-safe. UserDefaults is thread-safe, but UI state updates must occur on MainActor.
- **Enforcement**: Persistence service methods are thread-safe (UserDefaults). UI state restoration occurs on MainActor (via `@MainActor` on `AppState`).

---

## Determinism & Idempotence

### DI-001: Persistence Determinism
- **Rule**: Persistence is deterministic. Same UI state produces same persisted data.
- **Enforcement**: Persistence methods serialize state to UserDefaults in a deterministic format (same library list order, same path strings).

### DI-002: Restoration Idempotence
- **Rule**: Restoration is idempotent. Calling `restoreState()` multiple times produces the same UI state (if persisted state is unchanged).
- **Enforcement**: Restoration methods read from UserDefaults and set UI state. Multiple calls with unchanged persisted data produce identical UI state.

### DI-003: Auto-Open Idempotence
- **Rule**: Auto-open is idempotent. If a library is already opened, auto-open has no effect.
- **Enforcement**: Auto-open checks if `openedLibraryPath` is already set before attempting to open. If already opened, skip auto-open.

---

## Backward Compatibility

### BC-001: App Launch Without Persistence
- **Guarantee**: Apps launched without persisted state (first launch, or after clearing persistence) behave identically to current behavior (empty state, no libraries, no opened library).
- **Enforcement**: Restoration methods return empty state (empty arrays, nil paths) when no persisted data exists. App behavior matches current behavior.

### BC-002: Existing Libraries Remain Valid
- **Guarantee**: Persistence does not affect existing libraries. Libraries created/adopted by previous slices remain valid and accessible.
- **Enforcement**: Persistence only stores paths. Library validation and opening use existing Core APIs (`LibraryStatusService.openLibrary`, `LibraryPathValidator.validateSelectedLibraryPath`).

### BC-003: UI Behavior Unchanged
- **Guarantee**: UI behavior (library discovery, library opening, library selection) remains unchanged. Persistence only adds state restoration on launch.
- **Enforcement**: All existing UI workflows (discovery, selection, opening) work identically. Persistence is additive and does not modify existing workflows.

---

## Implementation Notes

### UserDefaults Key Strategy
- Use prefixed keys to avoid conflicts: `"mediahub.ui.libraryList"`, `"mediahub.ui.discoveryRoot"`, `"mediahub.ui.lastOpenedLibrary"`
- Store library list as array of dictionaries (or Codable structs) with `path`, `displayName`, `isValid` fields
- Store discovery root and last opened library as strings (paths)

### Persistence Timing
- Persist state when:
  - Library list changes (after discovery completes)
  - Library is opened (after successful open)
  - Library is closed (clear last opened library)
- Restore state on app launch (in `MediaHubUIApp` or `ContentView.onAppear`)

### Auto-Open Sequence
1. App launches
2. `AppState.restoreState()` restores persisted state
3. `ContentView` detects `openedLibraryPath` is set
4. `ContentView` attempts to open library using `LibraryStatusService.openLibrary`
5. If successful, library opens normally
6. If failed (missing/inaccessible), show error and clear `openedLibraryPath`

### Error Handling Strategy
- Missing library: Clear persisted path, show error message in UI
- Invalid library: Clear persisted path, show error message in UI
- Corrupted persistence data: Clear persisted data, fallback to empty state
- All errors are non-blocking (app launches successfully even if auto-open fails)

### DiscoveredLibrary Persistence
- `DiscoveredLibrary` is a struct with `path`, `displayName`, `isValid` fields
- Persist as array of dictionaries or use `Codable` conformance
- On restore, re-validate libraries using `LibraryPathValidator` to update `isValid` status

---

## Dependencies

- **Slice 11** (UI Shell v1 + Library Discovery): App shell, library discovery, `AppState`, `ContentView`, `LibraryDiscoveryService`, `LibraryStatusService`, `LibraryPathValidator`
- **Slice 14** (Progress + Cancel API minimale): No direct dependency, but slice 14 provides progress/cancel support that may be used in future slices

---

## Out of Scope

- Security-scoped bookmarks (deferred to Slice 18)
- Core or CLI changes
- Library metadata persistence (status, sources, etc.)
- Multi-library persistence or library history
- Automatic discovery on launch
- Persistence format versioning
- Migration of persisted data between app versions
