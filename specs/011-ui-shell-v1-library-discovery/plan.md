# Implementation Plan: UI Shell v1 + Library Discovery

**Feature**: UI Shell v1 + Library Discovery  
**Specification**: `specs/011-ui-shell-v1-library-discovery/spec.md`  
**Slice**: 11 - Basic SwiftUI macOS app shell with library discovery and status display  
**Created**: 2026-01-27

## Plan Scope

This plan implements **Slice 11 only**, which establishes the foundational UI shell for the MediaHub macOS desktop application. This includes:

- SwiftUI macOS app window with sidebar layout
- Library discovery via user-selected folder (scanning for `.mediahub/library.json`)
- Opening and validating discovered libraries
- Displaying library status using existing Core APIs
- Minimal persistence of last-opened library (optional, can be deferred if sandbox complexity is high)

**Explicitly out of scope**:
- Library creation/adoption wizards (Slice 12)
- Source attachment/detection/import UI (Slice 13)
- Progress bars and cancellation UI (Slices 14–15)
- Hash maintenance UI (Slice 16)
- History/audit timeline UI (Slice 17)
- Distribution/notarization work (Slice 18)
- Any mutating operations (create, adopt, attach, detect, import, hash maintenance)
- Refactoring of core/CLI code

## Goals / Non-Goals

### Goals
- Provide a minimal, read-only SwiftUI macOS app shell that orchestrates existing CLI/Core operations
- Enable users to discover and view their MediaHub libraries without using the command line
- Display library status information that matches CLI `mediahub status` output exactly
- Establish the foundation for future UI slices (Slices 12–17)
- Maintain backward compatibility with libraries created/adopted by slices 1–10

### Non-Goals
- Implement any new business logic (all logic remains in Core/CLI)
- Support mutating operations (create, adopt, attach, detect, import)
- Provide advanced library discovery (e.g., scanning entire filesystem, network volumes)
- Implement full sandbox support in this slice (minimal approach, can be enhanced in Slice 18)
- Optimize for very large libraries beyond basic async loading (performance work deferred)

## Proposed Architecture

### Module Structure

The UI app will be structured as a single macOS app target that links against the existing `MediaHub` framework (Core APIs). The app does not need a separate UI framework; it uses SwiftUI directly.

**Targets**:
- `MediaHubUI` (macOS app target)
  - Links against `MediaHub` framework (Core APIs)
  - SwiftUI views and view models
  - App state management
  - Library discovery and status orchestration

**Boundaries**:
- **UI Layer**: SwiftUI views, view models, app state
- **Orchestration Layer**: Thin wrappers that invoke Core APIs (same code path as CLI)
- **Core Layer**: Existing MediaHub framework (frozen, no changes)
- **CLI Layer**: Not used by UI (UI uses Core APIs directly)

### Component Overview

1. **App Shell** (`AppShell.swift`, `ContentView.swift`)
   - Main window structure with sidebar and content area
   - Navigation state management
   - Empty state handling

2. **Library Discovery** (`LibraryDiscoveryService.swift`)
   - Folder picker integration (`NSOpenPanel`)
   - Recursive scanning for `.mediahub/library.json` files
   - Library validation and metadata parsing
   - Deterministic ordering (lexicographic path sorting)

3. **Library Status** (`LibraryStatusService.swift`, `StatusViewModel.swift`)
   - Core API orchestration (same code path as `StatusCommand`)
   - Status data model (matches CLI JSON output contract)
   - Async loading with loading states
   - Error handling and user-facing error messages

4. **Persistence** (`LibraryPersistenceService.swift`)
   - Last-opened library storage (UserDefaults)
   - Security-scoped bookmark handling (if sandboxed)
   - Validation on app launch

5. **State Management** (`AppState.swift`, `LibraryListViewModel.swift`)
   - Discovered libraries list
   - Currently opened library
   - Navigation state
   - Error state

### Data Flow

#### Library Discovery Flow
```
User selects folder via NSOpenPanel
  ↓
LibraryDiscoveryService.scanFolder(path:)
  ↓
Recursively scan for .mediahub/library.json files
  ↓
For each found library:
  - Read and parse .mediahub/library.json
  - Validate metadata structure
  - Create DiscoveredLibrary model
  ↓
Sort by path (lexicographically) for deterministic ordering
  ↓
Update AppState.discoveredLibraries
  ↓
UI updates library list in sidebar
```

#### Library Opening Flow
```
User selects library from sidebar
  ↓
LibraryStatusService.openLibrary(path:)
  ↓
Validate library still exists and is accessible
  ↓
Invoke Core API: LibraryContext.openLibrary(at:)
  ↓
If successful:
  - Update AppState.currentLibrary
  - Trigger status loading
Else:
  - Display user-facing error message
  - Clear current library selection
```

#### Status Display Flow
```
Library opened successfully
  ↓
LibraryStatusService.loadStatus(for: libraryPath)
  ↓
Invoke Core APIs (same as StatusCommand.run()):
  - LibraryContext.openLibrary(at:)
  - SourceAssociationManager.retrieveSources(...)
  - BaselineIndexLoader.tryLoadBaselineIndex(...)
  - LibraryStatisticsComputer.compute(...) [if index available]
  - ScaleMetricsComputer.compute(...) [if index available]
  ↓
Build StatusViewModel with all data
  ↓
UI displays status view (matches CLI output)
```

## CLI Integration Decision

**Primary Approach: Core API Direct Invocation**

The UI app will use Core APIs directly (same code path as `StatusCommand`) rather than invoking the CLI executable. This decision is justified by:

1. **Simplicity**: No process spawning, no JSON parsing, no CLI executable dependency
2. **Performance**: Direct function calls are faster than subprocess execution
3. **Error Handling**: Direct Swift error propagation vs. parsing CLI error output
4. **Code Reuse**: Same code path as CLI ensures identical behavior
5. **Availability**: Core APIs are always available (app links against MediaHub framework)

**Implementation**:
- UI app links against `MediaHub` framework
- `LibraryStatusService` invokes the same Core APIs used by `StatusCommand`:
  - `LibraryContext.openLibrary(at:)`
  - `SourceAssociationManager.retrieveSources(...)`
  - `BaselineIndexLoader.tryLoadBaselineIndex(...)`
  - `LibraryStatisticsComputer.compute(...)`
  - `ScaleMetricsComputer.compute(...)`
- Status data model matches the JSON contract from `StatusFormatter.formatJSON()` for consistency

**Fallback Strategy**: None required. Core APIs are always available since the app links against the MediaHub framework. If Core APIs fail, it's a programming error (not a runtime dependency issue).

**Note**: This approach means the UI app must be built with the MediaHub framework as a dependency. The CLI executable is not required at runtime.

## File System Access

### Discovery Mechanism

1. **User Selection**: Use `NSOpenPanel` with `.canChooseDirectories = true` to let user select a root folder
2. **Recursive Scan**: Walk the selected folder tree looking for `.mediahub/library.json` files
3. **Validation**: For each found library:
   - Verify `.mediahub/library.json` exists and is readable
   - Parse JSON and validate structure (libraryId, libraryVersion present)
   - Verify library root directory is accessible
   - Skip if validation fails (log error, continue scanning)
4. **Ordering**: Sort discovered libraries by path lexicographically before display (deterministic)
5. **Read-Only Guarantee**: Only read operations during discovery; no writes to library directories

### Library Opening Validation

1. **Path Validation**: Verify library path still exists and is accessible
2. **Metadata Validation**: Re-read and parse `.mediahub/library.json` to ensure it's still valid
3. **Core API Validation**: Invoke `LibraryContext.openLibrary(at:)` which performs full validation:
   - Structure validation (`.mediahub/` directory exists)
   - Metadata validation (valid JSON, required fields present)
   - Permission checks
4. **Error Handling**: If any validation step fails, display clear user-facing error:
   - "Library not found" (path doesn't exist)
   - "Invalid library metadata" (corrupted JSON)
   - "Permission denied" (can't access library directory)
   - "Library structure invalid" (missing `.mediahub/` directory)

### Sandbox Considerations

- Use `NSOpenPanel` for folder selection (system handles sandbox access automatically)
- If sandboxed and persistence is implemented: use security-scoped bookmarks for last-opened library
- Request appropriate entitlements: `com.apple.security.files.user-selected.read-only`
- Test with sandbox enabled and disabled

## Persistence Strategy

### Minimal Viable Approach

**Last-Opened Library Persistence** (FR-011, optional if complexity is high):

1. **Storage**: UserDefaults with key `lastOpenedLibraryPath`
2. **Sandbox Handling**:
   - If sandboxed: Store security-scoped bookmark data (NSData) in UserDefaults
   - If not sandboxed: Store library path (String) in UserDefaults
3. **Validation on Launch**:
   - Read persisted value from UserDefaults
   - If bookmark: Resolve bookmark and verify library still exists
   - If path: Verify path exists and is accessible
   - If invalid: Clear persisted value, show empty state
4. **Failure Behavior**: If persistence fails or library is invalid, gracefully fall back to empty state (no error shown, user can select folder manually)

**Implementation Notes**:
- This is optional and can be deferred if sandbox/bookmark complexity is high
- Minimal implementation: Just store path in UserDefaults, validate on launch, clear if invalid
- Enhanced implementation (if time permits): Add security-scoped bookmark support for sandboxed environments

**Decision Point**: Implement minimal version (path-only) first. Add bookmark support only if sandbox testing reveals it's necessary.

## State Management Approach

### App State Structure

```swift
@MainActor
class AppState: ObservableObject {
    @Published var discoveredLibraries: [DiscoveredLibrary] = []
    @Published var currentLibrary: OpenedLibrary?
    @Published var currentStatus: LibraryStatus?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
}
```

### State Transitions

1. **Initial State**: Empty libraries list, no current library, no error
2. **Discovery**: User selects folder → scan → update `discoveredLibraries` (sorted)
3. **Opening**: User selects library → validate → update `currentLibrary` → trigger status load
4. **Status Loading**: Set `isLoading = true` → invoke Core APIs → update `currentStatus` → set `isLoading = false`
5. **Error State**: Any error → set `errorMessage` → clear affected state → user can retry

### Determinism Guarantees

- Library list ordering: Always sort by path lexicographically before assigning to `discoveredLibraries`
- Status display: Use same Core APIs as CLI, ensuring identical data contract
- Error messages: Use deterministic error formatting (same error → same message)

## Error Handling Strategy

### Error Categories

1. **Discovery Errors**:
   - Permission denied: "You don't have permission to access this folder. Please select a different folder."
   - No libraries found: "No MediaHub libraries found in the selected folder."
   - Invalid library: "Found a library with invalid metadata. Skipping." (log, continue scanning)

2. **Opening Errors**:
   - Library not found: "The library at this location no longer exists."
   - Invalid metadata: "The library metadata is corrupted or invalid."
   - Permission denied: "You don't have permission to access this library."
   - Structure invalid: "This directory is not a valid MediaHub library."

3. **Status Loading Errors**:
   - Core API failure: "Failed to load library status. Please try opening the library again."
   - JSON parsing error: "Library status data is invalid." (should not occur with Core APIs, but handle gracefully)

### Error Display

- Use SwiftUI `Alert` for critical errors (opening failures)
- Use inline error messages in status view for non-critical errors
- Always provide actionable error messages (what went wrong, what user can do)
- Clear error state when user takes action (selects different library, retries)

### Error Recovery

- Discovery errors: User can select a different folder
- Opening errors: User can select a different library from the list
- Status loading errors: User can retry by selecting the library again
- Persistence errors: Gracefully fall back to empty state (no error shown)

## Sequencing

### Phase 1: App Shell Foundation (P1)
**Goal**: Basic window structure and navigation

1. Create SwiftUI app entry point (`@main App`)
2. Implement `ContentView` with sidebar layout (NavigationSplitView)
3. Implement empty state view (no libraries selected)
4. Basic app state management (`AppState`)

**Why First**: Establishes the foundation for all other components. Can be tested immediately.

### Phase 2: Library Discovery (P1)
**Goal**: Discover libraries from user-selected folder

1. Implement `LibraryDiscoveryService` with folder picker integration
2. Implement recursive scan for `.mediahub/library.json` files
3. Implement library validation (metadata parsing)
4. Implement deterministic sorting (lexicographic path)
5. Integrate with `AppState` and display in sidebar

**Why Second**: Discovery is the entry point. Users need to find libraries before opening them.

### Phase 3: Library Opening (P1)
**Goal**: Open and validate discovered libraries

1. Implement library selection handling in sidebar
2. Implement `LibraryStatusService.openLibrary(path:)` with validation
3. Integrate with Core API `LibraryContext.openLibrary(at:)`
4. Implement error handling and user-facing error messages
5. Update `AppState` with current library

**Why Third**: Opening is the primary action after discovery. Needed before status display.

### Phase 4: Status Display (P1)
**Goal**: Display library status using Core APIs

1. Implement `LibraryStatusService.loadStatus(for:)` using Core APIs
2. Build status data model matching CLI JSON contract
3. Implement `StatusViewModel` and SwiftUI status view
4. Implement async loading with loading indicators
5. Handle "N/A" cases for missing baseline index (matching CLI behavior)

**Why Fourth**: Status display is the primary read-only view. Validates the UI-orchestrator architecture.

### Phase 5: Persistence (Optional, P2)
**Goal**: Remember last-opened library across app launches

1. Implement `LibraryPersistenceService` with UserDefaults storage
2. Implement path validation on app launch
3. Implement security-scoped bookmark support (if sandboxed, optional)
4. Integrate with app launch flow

**Why Last**: Optional feature. Can be deferred if sandbox complexity is high. App works without it.

## Risks & Mitigations (Implementation Sequencing)

### Risk 1: Sandbox Complexity for Persistence
**Risk**: Security-scoped bookmarks add complexity that may delay the slice.

**Mitigation**: 
- Implement minimal version first (path-only in UserDefaults)
- Add bookmark support only if sandbox testing reveals it's necessary
- Can defer persistence entirely if complexity is too high (FR-011 is optional)

**Sequencing Impact**: Persistence is Phase 5 (optional). Can be skipped if needed.

### Risk 2: Core API Integration Complexity
**Risk**: Core APIs may have dependencies or initialization requirements that complicate UI integration.

**Mitigation**:
- Core APIs are already used by CLI, so they're proven to work
- UI app links against same framework, so dependencies are resolved at build time
- Test Core API integration early (Phase 3) to catch issues

**Sequencing Impact**: None. Core APIs are stable and well-tested.

### Risk 3: Async Loading Performance
**Risk**: Status loading may block UI if not properly async.

**Mitigation**:
- Use Swift concurrency (`async/await`) for all Core API calls
- Show loading indicators during status retrieval
- Test with large libraries (10,000+ items) to verify performance

**Sequencing Impact**: None. Async loading is standard SwiftUI practice.

### Risk 4: Deterministic Ordering
**Risk**: Library list ordering may vary if sorting is not explicit.

**Mitigation**:
- Always sort by path lexicographically before assigning to state
- Test ordering consistency across multiple app launches
- Document sorting algorithm in code comments

**Sequencing Impact**: None. Sorting is straightforward to implement.

## Testing / Verification Hooks

### User Story 1: Discover Libraries on Disk

**Verification Steps**:
1. Create test libraries on disk using CLI: `mediahub library create <path1>`, `mediahub library create <path2>`
2. Launch UI app
3. Select folder containing test libraries via folder picker
4. Verify libraries appear in sidebar list
5. Verify libraries are sorted by path (lexicographically)
6. Verify empty folder shows empty list or "no libraries found" message
7. Verify permission-denied folder shows clear error message

**CLI Commands for Test Setup**:
```bash
# Create test libraries
mediahub library create /tmp/test-lib-1
mediahub library create /tmp/test-lib-2
mediahub library create /tmp/test-lib-zebra  # Test sorting
```

### User Story 2: Open a Library

**Verification Steps**:
1. Discover libraries (from User Story 1)
2. Select a library from sidebar
3. Verify library opens and status view appears
4. Verify invalid library shows error message
5. Verify permission-denied library shows error message
6. Verify moved library (move directory while app running) shows error on next access

**CLI Commands for Test Setup**:
```bash
# Create valid library
mediahub library create /tmp/test-lib-valid

# Create invalid library (corrupt metadata)
mkdir -p /tmp/test-lib-invalid/.mediahub
echo "invalid json" > /tmp/test-lib-invalid/.mediahub/library.json
```

### User Story 3: View Library Status

**Verification Steps**:
1. Open a library with baseline index (from User Story 2)
2. Verify status view shows: path, ID, version, source count, statistics, hash coverage, performance metrics
3. Open a library without baseline index
4. Verify status view shows: path, ID, version, source count, with "N/A" for statistics and hash coverage
5. Compare UI status output with CLI: `mediahub status --json <library-path>`
6. Verify status information matches CLI output exactly

**CLI Commands for Test Setup**:
```bash
# Create library with baseline index (adopt existing media)
mediahub library adopt /path/to/existing/media --yes

# Create library without baseline index (new empty library)
mediahub library create /tmp/test-lib-empty
```

### User Story 4: Navigate App Shell

**Verification Steps**:
1. Launch app
2. Verify window opens with sidebar and main content area
3. Verify empty state shows when no library selected
4. Verify selecting library updates main content area
5. Verify window resizing maintains usable layout

**Manual Steps**: Visual inspection of window structure and layout.

## Success Criteria Verification

- **SC-001** (Discovery < 5 seconds): Measure time from folder selection to library list display
- **SC-002** (Open < 2 seconds): Measure time from library selection to status view display
- **SC-003** (Status matches CLI): Compare UI status JSON with `mediahub status --json` output (programmatic comparison)
- **SC-004** (Error handling): Test all error cases and verify clear messages displayed
- **SC-005** (Deterministic ordering): Launch app multiple times, verify same libraries in same order
- **SC-006** (Backward compatibility): Test with libraries created by slices 1–10
- **SC-007** (N/A display): Test with libraries without baseline index, verify "N/A" displayed
- **SC-008** (Window opens < 1 second): Measure time from app launch to window display

## Implementation Notes

### Core API Usage Pattern

The UI app will mirror the exact code path used by `StatusCommand`:

```swift
// Same pattern as StatusCommand.run()
let openedLibrary = try LibraryContext.openLibrary(at: libraryPath)
let sources = try SourceAssociationManager.retrieveSources(
    for: openedLibrary.rootURL,
    libraryId: openedLibrary.metadata.libraryId
)
let indexState = BaselineIndexLoader.tryLoadBaselineIndex(libraryRoot: libraryPath)
let baselineIndex = (indexState == .valid(index)) ? index : nil
let statistics = baselineIndex.map { LibraryStatisticsComputer.compute(from: $0) }
let scaleMetrics = ScaleMetricsComputer.compute(for: libraryPath)
```

This ensures identical behavior between CLI and UI.

### SwiftUI Concurrency

All Core API calls will be wrapped in `Task` blocks and use `@MainActor` for state updates:

```swift
Task {
    isLoading = true
    do {
        let status = try await libraryStatusService.loadStatus(for: libraryPath)
        await MainActor.run {
            currentStatus = status
            isLoading = false
        }
    } catch {
        await MainActor.run {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
```

### Error Message Mapping

Map Core API errors to user-facing messages:
- `LibraryOpeningError.metadataNotFound` → "Library metadata not found"
- `LibraryOpeningError.metadataCorrupted` → "Library metadata is corrupted or invalid"
- `LibraryOpeningError.permissionDenied` → "You don't have permission to access this library"
- `LibraryOpeningError.structureInvalid` → "This directory is not a valid MediaHub library"

## Dependencies

- **MediaHub Framework**: Core APIs (already exists, frozen)
- **SwiftUI**: macOS 13.0+ (Ventura)
- **Foundation**: File system access, UserDefaults, NSOpenPanel
- **No external dependencies**: Pure Swift/SwiftUI implementation

## Out of Scope (Reiterated)

- Library creation/adoption wizards
- Source attachment/detection/import UI
- Progress bars and cancellation
- Hash maintenance UI
- History/audit timeline
- Distribution/notarization
- Mutating operations
- Core/CLI refactoring
