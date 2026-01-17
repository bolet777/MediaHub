# Implementation Tasks: UI Persistence v1 — Sidebar Libraries & Auto-Reopen

**Feature**: UI Persistence v1 — Sidebar Libraries & Auto-Reopen  
**Specification**: `specs/014a-ui-persistence-v1/spec.md`  
**Plan**: `specs/014a-ui-persistence-v1/plan.md`  
**Slice**: 14a - Persist UI state so users keep their library list and context across app relaunches  
**Created**: 2026-01-27

## Task Organization

Tasks are organized by phase, following the implementation sequence defined in the plan. Each task is:
- Small and focused on a single deliverable (1–2 commands max per pass)
- Sequential with explicit dependencies
- Traceable to plan phases and spec requirements
- Read-only persistence first; restoration and auto-open after persistence

---

## Phase 1 — UIPersistenceService Implementation (Read-Only First)

**Plan Reference**: Phase 1 (lines 117-135)  
**Goal**: Create persistence service with UserDefaults integration, test read/write operations  
**Dependencies**: None (Foundation, UserDefaults)

### T-001: Create UIPersistenceService.swift File Skeleton
**Priority**: P1  
**Summary**: Create `UIPersistenceService.swift` file with class skeleton and UserDefaults key constants.

**Expected Files Touched**:
- `Sources/MediaHubUI/UIPersistenceService.swift` (new)

**Steps**:
1. Create `Sources/MediaHubUI/UIPersistenceService.swift` file
2. Define `final class UIPersistenceService` with `private init()` (static-only class)
3. Add private static constants for UserDefaults keys:
   - `private static let libraryListKey = "mediahub.ui.libraryList"`
   - `private static let discoveryRootKey = "mediahub.ui.discoveryRoot"`
   - `private static let lastOpenedLibraryKey = "mediahub.ui.lastOpenedLibrary"`
4. Mark class as `@MainActor` (optional, for consistency with AppState)

**Done When**:
- `UIPersistenceService` class compiles
- UserDefaults key constants are defined
- Class is structured as static-only utility

**Dependencies**: None

---

### T-002: Make DiscoveredLibrary Codable
**Priority**: P1  
**Summary**: Make `DiscoveredLibrary` conform to `Codable` for UserDefaults serialization.

**Expected Files Touched**:
- `Sources/MediaHubUI/DiscoveredLibrary.swift` (update)

**Steps**:
1. Modify `DiscoveredLibrary` struct to conform to `Codable`
2. Ensure all properties (`path`, `displayName`, `isValid`, `validationError`) are `Codable`-compatible
3. Verify `Codable` conformance compiles (automatic synthesis if all properties are `Codable`)

**Done When**:
- `DiscoveredLibrary` conforms to `Codable`
- Struct compiles without errors
- All properties are serializable

**Dependencies**: None

---

### T-003: Implement persistLibraryList Method
**Priority**: P1  
**Summary**: Implement method to persist library list and discovery root to UserDefaults.

**Expected Files Touched**:
- `Sources/MediaHubUI/UIPersistenceService.swift` (update)

**Steps**:
1. Add `static func persistLibraryList(_ libraries: [DiscoveredLibrary], discoveryRoot: String?)` method
2. Encode `libraries` array to JSON `Data` using `JSONEncoder`
3. Store encoded data in UserDefaults with key `libraryListKey`
4. Store `discoveryRoot` string in UserDefaults with key `discoveryRootKey` (or remove key if `nil`)
5. Handle encoding errors gracefully (log error, don't crash)

**Done When**:
- `persistLibraryList` method compiles
- Method writes library list and discovery root to UserDefaults
- Encoding errors are handled gracefully

**Dependencies**: T-001, T-002

---

### T-004: Implement restoreLibraryList Method
**Priority**: P1  
**Summary**: Implement method to restore library list and discovery root from UserDefaults.

**Expected Files Touched**:
- `Sources/MediaHubUI/UIPersistenceService.swift` (update)

**Steps**:
1. Add `static func restoreLibraryList() -> ([DiscoveredLibrary], String?)` method
2. Read encoded data from UserDefaults with key `libraryListKey`
3. Decode data to `[DiscoveredLibrary]` array using `JSONDecoder`
4. Read `discoveryRoot` string from UserDefaults with key `discoveryRootKey`
5. Return empty array and `nil` if data is missing or decoding fails (graceful fallback)

**Done When**:
- `restoreLibraryList` method compiles
- Method reads library list and discovery root from UserDefaults
- Missing or corrupted data returns empty state gracefully

**Dependencies**: T-001, T-002

---

### T-005: Implement persistLastOpenedLibrary Method
**Priority**: P1  
**Summary**: Implement method to persist last opened library path to UserDefaults.

**Expected Files Touched**:
- `Sources/MediaHubUI/UIPersistenceService.swift` (update)

**Steps**:
1. Add `static func persistLastOpenedLibrary(_ path: String?)` method
2. If `path` is not `nil`, store string in UserDefaults with key `lastOpenedLibraryKey`
3. If `path` is `nil`, remove key from UserDefaults (clear persisted value)

**Done When**:
- `persistLastOpenedLibrary` method compiles
- Method writes last opened library path to UserDefaults
- Method clears persisted value when `path` is `nil`

**Dependencies**: T-001

---

### T-006: Implement restoreLastOpenedLibrary Method
**Priority**: P1  
**Summary**: Implement method to restore last opened library path from UserDefaults.

**Expected Files Touched**:
- `Sources/MediaHubUI/UIPersistenceService.swift` (update)

**Steps**:
1. Add `static func restoreLastOpenedLibrary() -> String?` method
2. Read string from UserDefaults with key `lastOpenedLibraryKey`
3. Return `nil` if key is missing or value is invalid (graceful fallback)

**Done When**:
- `restoreLastOpenedLibrary` method compiles
- Method reads last opened library path from UserDefaults
- Missing data returns `nil` gracefully

**Dependencies**: T-001

---

### T-007: Implement clearPersistence Method
**Priority**: P1  
**Summary**: Implement method to clear all persisted UI state (for testing/debugging).

**Expected Files Touched**:
- `Sources/MediaHubUI/UIPersistenceService.swift` (update)

**Steps**:
1. Add `static func clearPersistence()` method
2. Remove all three UserDefaults keys: `libraryListKey`, `discoveryRootKey`, `lastOpenedLibraryKey`
3. Use `UserDefaults.standard.removeObject(forKey:)` for each key

**Done When**:
- `clearPersistence` method compiles
- Method removes all persisted UI state from UserDefaults
- All keys are cleared

**Dependencies**: T-001

---

## Phase 2 — AppState Persistence Integration

**Plan Reference**: Phase 2 (lines 137-152)  
**Goal**: Integrate persistence service with AppState, add persist/restore methods  
**Dependencies**: Phase 1 (UIPersistenceService)

### T-008: Add persistState Method to AppState
**Priority**: P1  
**Summary**: Add method to AppState that persists current state to UserDefaults.

**Expected Files Touched**:
- `Sources/MediaHubUI/AppState.swift` (update)

**Steps**:
1. Add `func persistState()` method to `AppState` class
2. Call `UIPersistenceService.persistLibraryList(_:discoveryRoot:)` with `discoveredLibraries` and `discoveryRootPath`
3. Call `UIPersistenceService.persistLastOpenedLibrary(_:)` with `openedLibraryPath`
4. Ensure method is `@MainActor` (AppState is already `@MainActor`)

**Done When**:
- `persistState` method compiles
- Method persists all UI state to UserDefaults via `UIPersistenceService`
- Method is callable from MainActor context

**Dependencies**: T-003, T-005

---

### T-009: Add restoreState Method to AppState
**Priority**: P1  
**Summary**: Add method to AppState that restores state from UserDefaults.

**Expected Files Touched**:
- `Sources/MediaHubUI/AppState.swift` (update)

**Steps**:
1. Add `func restoreState()` method to `AppState` class
2. Call `UIPersistenceService.restoreLibraryList()` and set `discoveredLibraries` and `discoveryRootPath`
3. Call `UIPersistenceService.restoreLastOpenedLibrary()` and set `openedLibraryPath`
4. Handle restoration errors gracefully (fallback to empty state if restoration fails)
5. Ensure method is `@MainActor` (AppState is already `@MainActor`)

**Done When**:
- `restoreState` method compiles
- Method restores all UI state from UserDefaults via `UIPersistenceService`
- Method handles errors gracefully (empty state fallback)

**Dependencies**: T-004, T-006

---

### T-010: Add Re-Validation Logic to restoreState
**Priority**: P1  
**Summary**: Add library re-validation logic to restoreState method to update isValid status.

**Expected Files Touched**:
- `Sources/MediaHubUI/AppState.swift` (update)

**Steps**:
1. In `restoreState()` method, after restoring `discoveredLibraries`, iterate through each library
2. For each library, call `LibraryPathValidator.validateSelectedLibraryPath(library.path)`
3. If validation returns error, create new `DiscoveredLibrary` with `isValid = false` and `validationError` set
4. If validation succeeds, create new `DiscoveredLibrary` with `isValid = true` and `validationError = nil`
5. Update `discoveredLibraries` array with re-validated libraries

**Done When**:
- Re-validation logic compiles
- Libraries are re-validated on restore
- Invalid libraries are marked with `isValid = false`

**Dependencies**: T-009

---

## Phase 3 — Persistence Trigger Integration

**Plan Reference**: Phase 3 (lines 154-170)  
**Goal**: Trigger persistence when state changes (library discovery, library open/close)  
**Dependencies**: Phase 2 (AppState Persistence Integration)

### T-011: Add persistState Call After Discovery Completes
**Priority**: P1  
**Summary**: Call `appState.persistState()` after library discovery completes in `chooseFolder()`.

**Expected Files Touched**:
- `Sources/MediaHubUI/ContentView.swift` (update)

**Steps**:
1. In `chooseFolder()` method, locate the completion handler where `appState.discoveredLibraries` is set
2. After `appState.discoveredLibraries = libraries` and `appState.isDiscovering = false`, add call to `appState.persistState()`
3. Ensure call occurs on MainActor (already in MainActor context)

**Done When**:
- `persistState()` is called after discovery completes
- Library list is persisted to UserDefaults
- Code compiles without errors

**Dependencies**: T-008

---

### T-012: Add persistState Call After Library Opens
**Priority**: P1  
**Summary**: Call `appState.persistState()` after library opens successfully in `handleLibrarySelection(_:)`.

**Expected Files Touched**:
- `Sources/MediaHubUI/ContentView.swift` (update)

**Steps**:
1. In `handleLibrarySelection(_:)` method, locate where `appState.setOpenedLibrary(path:context:)` is called
2. After successful library open (after `appState.setOpenedLibrary` call), add call to `appState.persistState()`
3. Ensure call occurs on MainActor (already in MainActor context)

**Done When**:
- `persistState()` is called after library opens successfully
- Last opened library path is persisted to UserDefaults
- Code compiles without errors

**Dependencies**: T-008

---

### T-013: Add persistState Call After Wizard Completion
**Priority**: P1  
**Summary**: Call `appState.persistState()` after library opens successfully in `handleWizardCompletion(libraryPath:)`.

**Expected Files Touched**:
- `Sources/MediaHubUI/ContentView.swift` (update)

**Steps**:
1. In `handleWizardCompletion(libraryPath:)` method, locate where `appState.setOpenedLibrary(path:context:)` is called
2. After successful library open (after `appState.setOpenedLibrary` call), add call to `appState.persistState()`
3. Ensure call occurs on MainActor (already in MainActor context)

**Done When**:
- `persistState()` is called after wizard completion and library opens successfully
- Last opened library path is persisted to UserDefaults
- Code compiles without errors

**Dependencies**: T-008

---

## Phase 4 — State Restoration on Launch

**Plan Reference**: Phase 4 (lines 172-186)  
**Goal**: Restore persisted state on app launch, populate sidebar  
**Dependencies**: Phase 2 (AppState Persistence Integration)

### T-014: Add restoreState Call on App Launch
**Priority**: P1  
**Summary**: Call `appState.restoreState()` on app launch to restore persisted state.

**Expected Files Touched**:
- `Sources/MediaHubUI/ContentView.swift` (update)

**Steps**:
1. In `ContentView`, add `.onAppear` modifier to body
2. In `.onAppear` closure, call `appState.restoreState()`
3. Ensure call occurs on MainActor (ContentView is MainActor)
4. Verify restored state: `discoveredLibraries`, `discoveryRootPath`, `openedLibraryPath` are set from UserDefaults

**Done When**:
- `restoreState()` is called on app launch
- Persisted state is restored to `AppState`
- Sidebar shows restored library list
- Code compiles without errors

**Dependencies**: T-009, T-010

---

## Phase 5 — Auto-Open Logic

**Plan Reference**: Phase 5 (lines 188-199)  
**Goal**: Automatically open last opened library on app launch (if accessible)  
**Dependencies**: Phase 4 (State Restoration on Launch)

### T-015: Add Auto-Open Logic to ContentView
**Priority**: P1  
**Summary**: Add logic to automatically open last opened library on app launch if path is restored.

**Expected Files Touched**:
- `Sources/MediaHubUI/ContentView.swift` (update)

**Steps**:
1. In `ContentView`, add `.task` modifier (runs once on view appearance) after `.onAppear`
2. In `.task` closure, check if `appState.openedLibraryPath` is set (from restoration)
3. If set, validate library path using `LibraryPathValidator.validateSelectedLibraryPath(appState.openedLibraryPath!)`
4. If validation succeeds, attempt to open library using `LibraryStatusService.openLibrary(at: appState.openedLibraryPath!)`
5. If open succeeds, call `appState.setOpenedLibrary(path:context:)` (library opens normally)
6. If validation or open fails, call `appState.clearOpenedLibrary(error: "Library no longer accessible")` and clear persisted path via `UIPersistenceService.persistLastOpenedLibrary(nil)`
7. Handle all errors gracefully (non-blocking, show error message)

**Done When**:
- Auto-open logic compiles
- Last opened library is automatically opened on app launch (if accessible)
- Missing/inaccessible libraries show error message and don't block app launch
- Code compiles without errors

**Dependencies**: T-014

---

## Phase 6 — Error Handling Refinement

**Plan Reference**: Phase 6 (lines 201-211)  
**Goal**: Ensure all error cases are handled gracefully, no blocking errors  
**Dependencies**: Phase 5 (Auto-Open Logic)

### T-016: Test and Refine Error Handling
**Priority**: P1  
**Summary**: Test all error scenarios and ensure graceful error handling.

**Expected Files Touched**:
- No code changes (manual verification only)

**Steps**:
1. Test missing library scenario: Persist library path, move/delete library, verify graceful error handling on relaunch
2. Test invalid library scenario: Persist library path, corrupt library metadata, verify graceful error handling on relaunch
3. Test corrupted persistence data: Corrupt UserDefaults data, verify restoration falls back to empty state
4. Test invalid path string: Persist malformed path, verify graceful error handling on relaunch
5. Verify all errors are non-blocking: App launches successfully even if auto-open fails
6. Verify error messages are clear and user-facing

**Done When**:
- All error scenarios tested
- App launches successfully in all error cases
- Error messages are clear and user-facing
- Verification documented (no code commit required)

**Dependencies**: T-015

---

## Phase 9 — Optional Polish (Post-Freeze)

**Plan Reference**: N/A (optional enhancements)  
**Goal**: Optional UX improvements and polish  
**Dependencies**: All P1 tasks (T-001 through T-016)

### T-017: Optional — Auto-Re-Discovery on Launch
**Priority**: P2  
**Summary**: Optionally trigger library re-discovery from persisted discovery root on app launch.

**Expected Files Touched**:
- `Sources/MediaHubUI/ContentView.swift` (update, optional)

**Steps**:
1. In `ContentView.onAppear` or `.task`, after `restoreState()`, check if `appState.discoveryRootPath` is set
2. If set, optionally trigger re-discovery using `LibraryDiscoveryService.scanFolder(at: appState.discoveryRootPath!)`
3. Update `appState.discoveredLibraries` with re-discovered libraries
4. Call `appState.persistState()` after re-discovery completes

**Done When**:
- Auto-re-discovery logic compiles (if implemented)
- Re-discovery is optional and doesn't block app launch
- Code compiles without errors

**Note**: This task is optional/post-freeze. Slice is complete without this task.

**Dependencies**: T-014

---

## Task Summary

**Total Tasks**: 17 (16 P1, 1 P2 optional)

**P1 Tasks** (Required for slice completion):
- T-001 through T-016: All persistence, restoration, and auto-open functionality

**P2 Tasks** (Optional/post-freeze):
- T-017: Auto-re-discovery on launch (optional enhancement)

**Phase Breakdown**:
- Phase 1: UIPersistenceService Implementation (T-001 through T-007)
- Phase 2: AppState Persistence Integration (T-008 through T-010)
- Phase 3: Persistence Trigger Integration (T-011 through T-013)
- Phase 4: State Restoration on Launch (T-014)
- Phase 5: Auto-Open Logic (T-015)
- Phase 6: Error Handling Refinement (T-016)
- Phase 9: Optional Polish (T-017)
