# Feature Specification: UI Shell v1 + Library Discovery

**Feature Branch**: `011-ui-shell-v1-library-discovery`  
**Created**: 2026-01-27  
**Status**: Draft  
**Input**: User description: "Define a minimal SwiftUI macOS app shell that discovers existing MediaHub libraries on disk, lets the user select/open a library, and displays a basic library home/status view using existing CLI/status information"

## Overview

This slice establishes the foundational UI shell for the MediaHub macOS desktop application. The app acts as an orchestrator that invokes existing CLI commands and core APIs; it does not introduce new business logic. This slice focuses exclusively on read-only library discovery, selection, and status display.

**Problem Statement**: Users need a visual interface to discover and view their MediaHub libraries without using the command line. The desktop app must provide a safe, deterministic way to find libraries on disk, open them, and display their current status using the existing CLI backend as the source of truth.

**Architecture Principle**: The desktop application is a UI orchestrator. All business logic, data validation, and library operations remain in the Core/CLI layer. The UI invokes CLI commands (e.g., `mediahub status`) or uses Core APIs directly, but never implements its own library management logic.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Discover Libraries on Disk (Priority: P1)

A user launches the MediaHub desktop app for the first time or after closing it. They want to see their existing MediaHub libraries so they can open one. The app must discover libraries by scanning for `.mediahub/library.json` files in user-selected folders or known locations.

**Why this priority**: Library discovery is the entry point for all UI workflows. Without discovery, users cannot access their libraries through the app.

**Independent Test**: Can be fully tested by creating libraries on disk, launching the app, and verifying discovered libraries appear in the UI. This delivers the core capability of finding existing libraries.

**Acceptance Scenarios**:

1. **Given** the MediaHub app is launched for the first time, **When** the user selects a folder containing a MediaHub library (via folder picker), **Then** the app discovers the library and displays it in the library list
2. **Given** multiple MediaHub libraries exist in a user-selected folder, **When** the app scans that folder, **Then** all valid libraries are discovered and displayed in a deterministic order (e.g., by path lexicographically)
3. **Given** a folder is selected that contains no MediaHub libraries, **When** the app scans that folder, **Then** the app displays an empty list or a clear message indicating no libraries were found
4. **Given** a folder is selected that the user does not have permission to access, **When** the app attempts to scan that folder, **Then** the app displays a clear error message explaining the permission issue
5. **Given** a library exists at a previously opened location, **When** the app launches, **Then** the app can optionally remember and display that library (if last-opened persistence is implemented)

---

### User Story 2 - Open a Library (Priority: P1)

A user has discovered one or more libraries and wants to open one to view its status. The app must open the library, validate it, and display its information. If the library is invalid or inaccessible, the app must show a clear error.

**Why this priority**: Opening a library is the primary action after discovery. Users need to access library information to understand their library state.

**Independent Test**: Can be fully tested by discovering a library and opening it, verifying the status view displays correctly. This delivers the core capability of library access.

**Acceptance Scenarios**:

1. **Given** a valid MediaHub library is discovered, **When** the user selects and opens it, **Then** the app displays the library status view with library information
2. **Given** a library path is selected, **When** the library metadata is invalid or corrupted, **Then** the app displays a clear error message explaining the issue (e.g., "Invalid library metadata" or "Library file is corrupted")
3. **Given** a library path is selected, **When** the user does not have permission to access the library directory, **Then** the app displays a clear error message explaining the permission issue
4. **Given** a library is opened, **When** the app closes and reopens, **Then** the app can optionally remember the last opened library and restore it (if last-opened persistence is implemented)
5. **Given** a library is opened, **When** the library directory is moved or deleted while the app is running, **Then** the app detects the change and displays an appropriate error or warning

---

### User Story 3 - View Library Status (Priority: P1)

A user has opened a library and wants to see its current status, including statistics, hash coverage, and attached sources. The app must display this information by invoking the existing CLI `mediahub status` command or equivalent core APIs, and gracefully handle cases where the baseline index is missing or invalid.

**Why this priority**: Status display is the primary read-only view that demonstrates the app can successfully orchestrate CLI operations. This validates the UI-orchestrator architecture.

**Independent Test**: Can be fully tested by opening a library and verifying the status view matches the CLI `mediahub status` output. This delivers the core capability of displaying library information.

**Acceptance Scenarios**:

1. **Given** a library is opened with a valid baseline index, **When** the status view is displayed, **Then** the app shows library path, ID, version, source count, statistics (total items, by year, by media type), hash coverage, and attached sources
2. **Given** a library is opened without a baseline index (or with an invalid index), **When** the status view is displayed, **Then** the app shows library path, ID, version, source count, and attached sources, with "N/A" displayed for statistics and hash coverage (matching CLI behavior)
3. **Given** a library is opened, **When** the status view is displayed, **Then** the displayed information matches the output of `mediahub status --json` for the same library (when JSON output is used)
4. **Given** a library is opened, **When** the status view is displayed, **Then** the app shows performance metrics (file count, total size, hash coverage percent, duration) when available, or "N/A" when baseline index is missing (matching CLI behavior)
5. **Given** a library has no attached sources, **When** the status view is displayed, **Then** the app shows source count as 0 and displays an empty sources list or appropriate message

---

### User Story 4 - Navigate App Shell (Priority: P2)

A user wants to navigate the app using a familiar macOS desktop app structure. The app must provide a basic window with sidebar navigation and a main content area.

**Why this priority**: While not immediately critical, a proper app shell structure establishes the foundation for future UI slices and provides a professional user experience.

**Independent Test**: Can be fully tested by launching the app and verifying the window structure, sidebar, and navigation work correctly. This delivers the basic app shell capability.

**Acceptance Scenarios**:

1. **Given** the app is launched, **When** the main window opens, **Then** the app displays a window with a sidebar (for library list) and a main content area (for library status)
2. **Given** the app shell is displayed, **When** no library is selected, **Then** the main content area shows an empty state or welcome message
3. **Given** the app shell is displayed, **When** a library is selected in the sidebar, **Then** the main content area updates to show that library's status view
4. **Given** the app shell is displayed, **When** the user resizes the window, **Then** the layout adapts appropriately and remains usable

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST provide a SwiftUI macOS window with a sidebar layout (sidebar for library list, main area for content)
- **FR-002**: The app MUST support library discovery via user-selected folder (folder picker dialog)
- **FR-003**: The app MUST scan user-selected folders for `.mediahub/library.json` files to identify MediaHub libraries
- **FR-004**: The app MUST display discovered libraries in a deterministic order (e.g., by path lexicographically)
- **FR-005**: The app MUST validate discovered libraries by reading and parsing `.mediahub/library.json` before displaying them
- **FR-006**: The app MUST support opening a library by selecting it from the discovered library list
- **FR-007**: The app MUST display library status information by invoking `mediahub status --json` (or equivalent core API) and parsing the JSON output
- **FR-008**: The app MUST display all status fields shown by CLI `mediahub status`: path, ID, version, source count, sources list, statistics (when available), hash coverage (when available), and performance metrics (when available)
- **FR-009**: The app MUST display "N/A" for statistics and hash coverage when baseline index is missing or invalid (matching CLI behavior)
- **FR-010**: The app MUST handle library access errors gracefully and display clear, user-facing error messages
- **FR-011**: The app MUST support persisting the last opened library reference (e.g., using UserDefaults or security-scoped bookmarks) to restore it on app launch
- **FR-012**: The app MUST validate persisted library references on launch and handle cases where the library no longer exists or is inaccessible
- **FR-013**: The app MUST be read-only in this slice: no mutating operations, no library creation, no source attachment, no import operations
- **FR-014**: The app MUST work with libraries created/adopted by slices 1–10 (backward compatibility)

### Safety Rules

- **SR-001**: The app MUST NOT write to library directories during discovery or status display
- **SR-002**: The app MUST NOT modify library metadata files (`.mediahub/library.json` or `.mediahub/registry/index.json`)
- **SR-003**: The app MUST handle permission errors gracefully without crashing or corrupting state
- **SR-004**: The app MUST validate library metadata before attempting to open a library
- **SR-005**: The app MUST handle cases where CLI invocation fails (e.g., CLI not found, invalid JSON output) with clear error messages
- **SR-006**: The app MUST handle sandbox restrictions appropriately (if sandbox is enabled): use security-scoped bookmarks for persistent library access, request folder access via NSOpenPanel
- **SR-007**: The app MUST NOT store sensitive information (e.g., library paths) in insecure locations

### Determinism & Idempotence Rules

- **DR-001**: Library discovery MUST produce the same list of libraries in the same order when scanning the same folder multiple times (deterministic ordering)
- **DR-002**: Status display MUST show the same information as CLI `mediahub status` for the same library state (idempotent display)
- **DR-003**: Library list ordering MUST be stable across app launches (e.g., sort by path lexicographically)
- **DR-004**: Error messages MUST be deterministic and reproducible for the same error conditions

### Data/IO Boundaries

- **IO-001**: The app MUST read only the following files during discovery: `.mediahub/library.json` (to identify and validate libraries)
- **IO-002**: The app MUST read only the following files during status display: library metadata (via CLI or core API), baseline index (via CLI or core API, if available)
- **IO-003**: The app MAY write to app-specific storage (UserDefaults, app support directory) for last-opened library persistence
- **IO-004**: The app MUST NOT write to library directories, library metadata files, or baseline index files
- **IO-005**: The app MUST NOT create, modify, or delete any files in library directories

### CLI Integration Approach

- **CLI-001**: The app SHOULD invoke `mediahub status --json <library-path>` to retrieve library status information
- **CLI-002**: The app MUST parse JSON output from CLI commands and handle JSON parsing errors gracefully
- **CLI-003**: The app MUST handle cases where the CLI executable is not found or cannot be executed
- **CLI-004**: The app MAY use Core APIs directly (e.g., `LibraryContext.openLibrary`, `StatusFormatter`) as an alternative to CLI invocation, but must maintain the same data contract
- **CLI-005**: The app MUST NOT introduce new CLI commands, flags, or data models in this slice

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The app can discover and display all valid MediaHub libraries in a user-selected folder within 5 seconds for folders containing up to 10 libraries
- **SC-002**: The app can open a library and display its status view within 2 seconds of selection
- **SC-003**: The app displays status information that matches CLI `mediahub status --json` output with 100% accuracy for the same library state
- **SC-004**: The app handles library access errors (permission denied, invalid metadata, missing library) with clear error messages in 100% of error cases
- **SC-005**: The app maintains deterministic library list ordering across app launches (same libraries in same order)
- **SC-006**: The app successfully opens libraries created/adopted by slices 1–10 in 100% of cases (backward compatibility)
- **SC-007**: The app displays "N/A" for statistics and hash coverage when baseline index is missing, matching CLI behavior in 100% of cases
- **SC-008**: The app window opens and displays the app shell structure within 1 second of launch

## Out of Scope

This slice explicitly does NOT include:

- **OOS-001**: Library creation wizard (deferred to Slice 12)
- **OOS-002**: Library adoption wizard (deferred to Slice 12)
- **OOS-003**: Source attachment UI (deferred to Slice 13)
- **OOS-004**: Detection preview/run UI (deferred to Slice 13)
- **OOS-005**: Import preview/confirm/run UI (deferred to Slice 13)
- **OOS-006**: Progress bars and cancellation UI (deferred to Slices 14–15)
- **OOS-007**: Hash maintenance UI (deferred to Slice 16)
- **OOS-008**: History/audit timeline UI (deferred to Slice 17)
- **OOS-009**: Distribution/notarization work (deferred to Slice 18)
- **OOS-010**: Refactoring of core/CLI code (core/CLI remain frozen)
- **OOS-011**: New CLI commands or flags (CLI is source of truth, no changes)
- **OOS-012**: Mutating operations (create, adopt, attach, detect, import, hash maintenance)
- **OOS-013**: Advanced library discovery (e.g., scanning entire filesystem, network volumes, external drives beyond user selection)

## Risks & Mitigations

### Risk 1: macOS Sandbox Restrictions
**Risk**: macOS sandbox may restrict file access, preventing library discovery or opening libraries in user-selected locations.

**Mitigation**: 
- Use `NSOpenPanel` for folder selection (system handles sandbox access)
- Use security-scoped bookmarks for persistent library access (if sandbox is enabled)
- Request appropriate entitlements (e.g., `com.apple.security.files.user-selected.read-only`)
- Test with sandbox enabled and disabled

### Risk 2: CLI Invocation Failures
**Risk**: CLI executable may not be found, may fail to execute, or may return invalid JSON.

**Mitigation**:
- Bundle CLI executable with app or use system PATH
- Validate CLI executable exists before invocation
- Parse JSON with error handling; display clear error if JSON is invalid
- Fallback to Core API direct invocation if CLI is unavailable
- Test with missing CLI, invalid CLI, and malformed JSON responses

### Risk 3: Library Metadata Corruption
**Risk**: Library metadata files may be corrupted, invalid, or unreadable, causing app crashes or incorrect display.

**Mitigation**:
- Validate JSON structure before parsing
- Handle JSON decode errors gracefully with user-facing error messages
- Test with corrupted metadata files, missing files, and invalid JSON

### Risk 4: Performance with Large Libraries
**Risk**: Status display may be slow for very large libraries, causing UI to freeze.

**Mitigation**:
- Invoke CLI asynchronously (background thread/async task)
- Show loading indicator during status retrieval
- Consider caching status information (with invalidation on library changes)
- Test with large libraries (10,000+ items)

### Risk 5: Last-Opened Library Persistence
**Risk**: Persisted library references may become stale (library moved/deleted), causing errors on app launch.

**Mitigation**:
- Validate persisted library path on app launch
- Handle missing/inaccessible libraries gracefully (show error, allow user to select different library)
- Clear invalid persisted references
- Test with moved libraries, deleted libraries, and permission changes

### Risk 6: Deterministic Ordering
**Risk**: Library list ordering may vary across app launches or system configurations.

**Mitigation**:
- Use explicit sorting (e.g., by path lexicographically) before display
- Test ordering consistency across multiple app launches
- Document sorting algorithm in implementation

## Assumptions

- macOS 13.0 (Ventura) or later for SwiftUI features
- CLI executable is available (bundled with app or in system PATH)
- Users have read access to library directories they want to open
- Library metadata files (`.mediahub/library.json`) are valid JSON and follow the schema defined in Slice 1
- Baseline index (`.mediahub/registry/index.json`) may or may not exist (backward compatible with libraries without index)
- App may run in sandboxed environment (requires appropriate entitlements and security-scoped bookmarks)
- Libraries created by slices 1–10 are compatible with this UI slice (no breaking changes to library structure)

## Key Entities *(include if feature involves data)*

- **DiscoveredLibrary**: A library found during discovery, containing metadata (from `.mediahub/library.json`), path, and discovery source (user-selected vs. known location)
- **LibraryStatus**: Status information retrieved from CLI `mediahub status --json` or equivalent core API, including path, ID, version, source count, sources list, statistics (optional), hash coverage (optional), and performance metrics (optional)
- **AppState**: Application state tracking discovered libraries, currently opened library, and UI navigation state
- **LastOpenedLibrary**: Persisted reference to the last opened library (path or security-scoped bookmark) for restoration on app launch
