# Slice 11 — UI Shell v1 + Library Discovery

**Document Type**: Slice Validation Runbook  
**Slice Number**: 11  
**Title**: UI Shell v1 + Library Discovery  
**Author**: Spec-Kit Orchestrator  
**Date**: 2026-01-27  
**Status**: Draft

---

## Validation Overview

This runbook provides comprehensive validation for Slice 11 implementation. All checks are runnable and verify the success criteria from spec.md: app shell foundation, library discovery, library opening, status display, and deterministic behavior.

**Key Validation Principles**:
- Read-only operations (zero writes to library directories, zero mutations)
- Deterministic behavior (same input → identical results)
- User-facing error messages (clear and actionable)
- Semantic status matching (same values as CLI, not exact JSON schema)
- Backward compatibility with libraries from slices 1–10

**Validation Approach**:
- Manual UI testing (macOS SwiftUI app requires visual verification)
- CLI cross-checks for status information comparison
- Repeatable test scenarios with explicit pass/fail criteria
- Performance measurements using stopwatch/timing

---

## 1. Preconditions

### System Requirements
- **macOS**: Version 13.0 (Ventura) or later
- **Swift**: Version 5.7 or later
- **Xcode**: Version 14.0 or later (for opening package in Xcode, optional)

### Build and Run Commands

**Build the app**:
```bash
cd /path/to/MediaHub
swift build
```

**Run the app**:
```bash
swift run MediaHubUI
```

**Alternative (Xcode)**:
```bash
open Package.swift
# Then run MediaHubUI target in Xcode
```

**Where to observe logs/errors**:
- Console output: Terminal where `swift run MediaHubUI` is executed
- Xcode console: If running from Xcode
- UI alerts: Displayed in app window
- System Console.app: For system-level errors (if needed)

### Cleanup Before Validation
```bash
# Clean up previous test libraries (if any)
rm -rf /tmp/mh-ui-test-*
```

---

## 2. Test Fixtures

### Fixture Setup Commands

**Create test libraries for discovery**:
```bash
# Create three libraries with different names (test sorting)
mediahub library create /tmp/mh-ui-test-lib-1
mediahub library create /tmp/mh-ui-test-lib-2
mediahub library create /tmp/mh-ui-test-lib-zebra

# Verify libraries were created
ls -la /tmp/mh-ui-test-lib-*/.mediahub/library.json
```

**Expected**: Three valid MediaHub libraries at `/tmp/mh-ui-test-lib-1`, `/tmp/mh-ui-test-lib-2`, `/tmp/mh-ui-test-lib-zebra`.

**Create invalid library metadata**:
```bash
# Create directory structure
mkdir -p /tmp/mh-ui-test-invalid/.mediahub

# Write invalid JSON
echo "invalid json content" > /tmp/mh-ui-test-invalid/.mediahub/library.json

# Verify invalid file exists
cat /tmp/mh-ui-test-invalid/.mediahub/library.json
```

**Expected**: Directory with invalid `library.json` file.

**Create library with baseline index (for status testing)**:
```bash
# Create a library and adopt existing media (if available)
# OR create empty library (will have no index)
mediahub library create /tmp/mh-ui-test-lib-with-index

# If you have existing media to adopt:
# mediahub library adopt /path/to/existing/media --yes
# export MEDIAHUB_LIBRARY=/tmp/mh-ui-test-lib-with-index
# mediahub index hash --yes  # Create baseline index

# For testing "no index" case, use the empty library:
mediahub library create /tmp/mh-ui-test-lib-no-index
```

**Expected**: 
- `/tmp/mh-ui-test-lib-with-index`: Library with baseline index (if media adopted)
- `/tmp/mh-ui-test-lib-no-index`: Empty library without baseline index

**Note**: If baseline index creation is not available or requires media files, mark status checks that require index as "N/A" and document why.

**Create empty folder (for "no libraries found" test)**:
```bash
mkdir -p /tmp/mh-ui-test-empty-folder
# Leave it empty
```

**Expected**: Empty directory with no MediaHub libraries.

---

## 3. Validation Checklist

### User Story 1: Discover Libraries on Disk

#### Check 1.1: App Shell Opens and Displays Empty State
**Setup**: No setup required.

**Steps**:
1. Build app: `swift build`
2. Run app: `swift run MediaHubUI`
3. Observe window appearance

**Expected Results**:
- ✅ Window opens with title "MediaHub"
- ✅ Window displays sidebar (left pane) and main content area (right pane)
- ✅ Main content area shows empty state message: "Welcome to MediaHub" or similar
- ✅ Empty state includes instruction: "Select a folder to discover libraries" or similar
- ✅ Window can be resized and layout adapts appropriately

**Pass/Fail**: All items must pass. Window must open within 1 second (SC-008).

**Determinism**: Repeat launch 3 times. Window should open consistently each time.

---

#### Check 1.2: Folder Picker Opens and Selects Folder
**Setup**: Test libraries created (Fixture Setup).

**Steps**:
1. Launch app (if not already running)
2. Click "Choose Folder…" button (in sidebar)
3. In folder picker dialog, navigate to `/tmp`
4. Click "Open" to select `/tmp` folder

**Expected Results**:
- ✅ Folder picker dialog opens
- ✅ Dialog allows directory selection only (not files)
- ✅ `/tmp` folder can be selected
- ✅ Dialog closes after selection

**Pass/Fail**: Folder picker must work correctly.

---

#### Check 1.3: Discovery Lists All Valid Libraries
**Setup**: Test libraries created (Fixture Setup).

**Steps**:
1. Select `/tmp` folder via folder picker (from Check 1.2)
2. Observe sidebar list update
3. Note which libraries appear

**Expected Results**:
- ✅ Sidebar displays list of discovered libraries
- ✅ All three test libraries appear: `mh-ui-test-lib-1`, `mh-ui-test-lib-2`, `mh-ui-test-lib-zebra`
- ✅ Loading indicator appears during scan (if scan takes > 0.5 seconds)
- ✅ Loading indicator disappears when scan completes

**Pass/Fail**: All three libraries must appear in list.

**Timing**: Discovery must complete within 5 seconds (SC-001).

---

#### Check 1.4: Deterministic Ordering (Lexicographic by Path)
**Setup**: Test libraries created (Fixture Setup).

**Steps**:
1. Select `/tmp` folder via folder picker
2. Observe library order in sidebar
3. Quit app (Cmd+Q)
4. Relaunch app
5. Select `/tmp` folder again
6. Observe library order in sidebar

**Expected Results**:
- ✅ Libraries appear in lexicographic order by path:
  1. `mh-ui-test-lib-1`
  2. `mh-ui-test-lib-2`
  3. `mh-ui-test-lib-zebra`
- ✅ Order is identical on second launch (deterministic)

**Pass/Fail**: Order must be lexicographic and stable across launches (SC-005, DR-001, DR-003).

**Determinism**: Repeat discovery 3 times. Order must be identical each time.

---

#### Check 1.5: Empty Folder Shows Normal Empty State (Not Error)
**Setup**: Empty folder created (Fixture Setup).

**Steps**:
1. Launch app
2. Click "Choose Folder…"
3. Navigate to `/tmp/mh-ui-test-empty-folder`
4. Click "Open"
5. Observe UI response

**Expected Results**:
- ✅ No error alert appears
- ✅ Sidebar shows empty list or "No libraries found" message (normal empty state)
- ✅ Main content area shows empty state or welcome message
- ✅ App remains usable (user can select different folder)

**Pass/Fail**: Empty folder must show normal empty state, NOT an error/alert.

**Note**: This verifies that "no libraries found" is handled as normal state, not an error (per spec update).

---

#### Check 1.6: Permission Denied Shows Clear Error
**Setup**: Create a folder with no access permissions:
```bash
mkdir -p /tmp/mh-ui-test-no-access
chmod 000 /tmp/mh-ui-test-no-access
```

**Steps**:
1. Launch app
2. Click "Choose Folder…"
3. Navigate to `/tmp/mh-ui-test-no-access`
4. Attempt to select folder
5. Observe error message

**Expected Results**:
- ✅ Clear error message displayed: "You don't have permission to access this folder. Please select a different folder." or similar
- ✅ Error is actionable (user knows what to do)
- ✅ App remains usable (user can select different folder)
- ✅ Error state clears when user selects different folder

**Pass/Fail**: Permission error must show clear, actionable message (SC-004, SR-003).

**Cleanup**:
```bash
chmod 755 /tmp/mh-ui-test-no-access
rm -rf /tmp/mh-ui-test-no-access
```

---

#### Check 1.7: Invalid Library Metadata Appears with "Invalid" Label
**Setup**: Invalid library created (Fixture Setup).

**Steps**:
1. Launch app
2. Select `/tmp` folder (contains both valid and invalid libraries)
3. Observe sidebar list

**Expected Results**:
- ✅ Invalid library (`mh-ui-test-invalid`) appears in list with an "Invalid" label
- ✅ Valid libraries appear without "Invalid" label
- ✅ No crash or error alert
- ✅ App continues to function normally
- ✅ Selecting invalid library shows error and does not open it (see Check 2.3)

**Pass/Fail**: Invalid libraries must appear in list with "Invalid" label and not crash (FR-005, SR-003).

---

### User Story 2: Open a Library

#### Check 2.1: Open Valid Library
**Setup**: Libraries discovered (from User Story 1).

**Steps**:
1. Ensure libraries are discovered in sidebar (from Check 1.3)
2. Click on `mh-ui-test-lib-1` in sidebar
3. Observe main content area update

**Expected Results**:
- ✅ Library selection is visually indicated (highlighted/selected)
- ✅ Main content area updates to show library status view
- ✅ Status view appears within 2 seconds (SC-002)
- ✅ Loading indicator appears during status load (if load takes > 0.5 seconds)
- ✅ Loading indicator disappears when status loads

**Pass/Fail**: Library must open and status view must appear within 2 seconds.

**Timing**: Measure time from click to status view display (must be < 2 seconds for SC-002).

---

#### Check 2.2: Status View Displays Library Information
**Setup**: Library opened (from Check 2.1).

**Steps**:
1. Library is open (from Check 2.1)
2. Observe status view content

**Expected Results**:
- ✅ Status view displays:
  - "Library Status" heading
  - Baseline index: "Present" / "Missing" / "N/A"
  - Hash index: "Present" / "Missing" / "N/A"
  - Items: `<n>` / "N/A"
  - Last scan: `<date>` / "N/A"
- ✅ All fields are readable and properly formatted

**Pass/Fail**: All displayed status fields must be shown correctly.

**Note**: Library ID, version, source count, and sources list are not currently displayed in StatusView (deferred to future slices).

---

#### Check 2.3: Open Invalid Library Shows Error
**Setup**: Invalid library created (Fixture Setup). Invalid library appears in discovery list with "Invalid" label (see Check 1.7).

**Steps**:
1. Ensure invalid library is discovered in sidebar (from Check 1.7)
2. Click on invalid library row (marked with "Invalid" label)
3. Observe error message and main content area

**Expected Results**:
- ✅ Clear error message displayed in main content area (red text): "This library is invalid (unreadable or malformed .mediahub/library.json)." or similar
- ✅ Error is actionable (user knows what went wrong)
- ✅ Library does NOT open (no StatusView appears)
- ✅ App remains usable (user can select different library)
- ✅ Error state clears when user selects different library

**Pass/Fail**: Invalid library selection must show clear error and NOT open the library (SC-004, FR-010, SR-004).

---

#### Check 2.4: Moved/Deleted Library Detection
**Setup**: Library opened (from Check 2.1).

**Steps**:
1. Open `mh-ui-test-lib-1` (from Check 2.1)
2. While app is running, rename library directory:
   ```bash
   mv /tmp/mh-ui-test-lib-1 /tmp/mh-ui-test-lib-1-moved
   ```
3. In app, attempt to access library again (e.g., trigger status refresh or select library again)
4. Observe error message

**Expected Results**:
- ✅ App detects library is missing/moved
- ✅ Clear error message: "The library at this location no longer exists." or similar
- ✅ Error is actionable
- ✅ App remains usable (user can select different library)

**Pass/Fail**: Moved library must be detected and show clear error (User Story 2, Acceptance Scenario 5).

**Cleanup**:
```bash
# Restore library for subsequent tests
mv /tmp/mh-ui-test-lib-1-moved /tmp/mh-ui-test-lib-1
```

---

### User Story 3: View Library Status

#### Check 3.1: Status with Baseline Index (Full Information)
**Setup**: Library with baseline index created (Fixture Setup).

**Steps**:
1. If library with index exists, open it
2. OR: Use a library created by prior slices that has media and index
3. Observe status view

**Expected Results**:
- ✅ Status view displays:
  - "Library Status" heading
  - Baseline index: "Present"
  - Hash index: "Present" / "Missing" (based on index version and hash entries)
  - Items: `<n>` (actual count from index)
  - Last scan: `<date>` (if available from index lastUpdated)
- ✅ All displayed fields show actual values (not "N/A")

**Pass/Fail**: All displayed status fields must show correct values when baseline index is available.

**CLI Cross-Check**:
```bash
mediahub status --json /tmp/mh-ui-test-lib-with-index
```
Compare baseline index presence, hash index presence, items count, and last scan date semantically when available. Do NOT require full JSON semantic parity beyond what UI displays.

**Note**: Library ID, version, source count, sources list, statistics, hash coverage, and performance sections are not currently displayed in StatusView (deferred to future slices). If no library with baseline index is available, mark this check as "N/A - no library with baseline index available" and explain.

---

#### Check 3.2: Status without Baseline Index (N/A Display)
**Setup**: Empty library without baseline index created (Fixture Setup).

**Steps**:
1. Open `/tmp/mh-ui-test-lib-no-index` (or any empty library)
2. Observe status view

**Expected Results**:
- ✅ Status view displays:
  - "Library Status" heading
  - Baseline index: "Missing"
  - Hash index: "N/A" (not applicable when baseline index is missing)
  - Items: "N/A" (cannot know without scanning)
  - Last scan: "N/A" (not available without index)
- ✅ All displayed fields show "N/A" or "Missing" appropriately

**Pass/Fail**: Missing baseline index must show "Missing" for baseline index and "N/A" for hash index, items, and last scan (SC-007, FR-009).

**CLI Cross-Check**:
```bash
mediahub status --json /tmp/mh-ui-test-lib-no-index
```
Compare baseline index presence, hash index presence, items count, and last scan date semantically when available. Do NOT require full JSON semantic parity beyond what UI displays.

**Note**: Library ID, version, source count, sources list, statistics, hash coverage, and performance sections are not currently displayed in StatusView (deferred to future slices).

---

#### Check 3.3: Status Semantics Match CLI Output
**Setup**: Any valid library opened.

**Steps**:
1. Open any valid library (e.g., `mh-ui-test-lib-1`)
2. Observe status view values
3. Run CLI status command:
   ```bash
   mediahub status --json /tmp/mh-ui-test-lib-1
   ```
4. Compare UI values with CLI JSON output

**Expected Results**:
- ✅ UI values match CLI values semantically for displayed fields:
  - Baseline index presence: Same (Present/Missing)
  - Hash index presence: Same (Present/Missing/N/A)
  - Items count: Same when available (or both show N/A)
  - Last scan date: Same when available (or both show N/A)
- ✅ Field order and JSON schema may differ (semantic match, not exact schema)

**Pass/Fail**: UI status must match CLI status information semantically for displayed fields (SC-003, DR-002).

**Note**: This verifies semantic matching for displayed fields only. Library ID, version, source count, sources list, statistics, hash coverage, and performance sections are not currently displayed in StatusView (deferred to future slices).

---

#### Check 3.4: Status Loading Errors are Handled
**Setup**: Library opened.

**Steps**:
1. Open a library
2. While status is loading, if possible, simulate error (e.g., move library directory)
3. OR: Open a library that causes status load to fail
4. Observe error handling

**Expected Results**:
- ✅ Error message displayed: "Failed to load library status. Please try opening the library again." or similar
- ✅ Error is actionable (user knows what to do)
- ✅ App remains usable (user can retry or select different library)
- ✅ Error state clears when user takes action

**Pass/Fail**: Status loading errors must show clear message (SC-004, FR-010).

---

### User Story 4: Navigate App Shell

#### Check 4.1: Window Layout and Navigation
**Setup**: No setup required.

**Steps**:
1. Launch app
2. Observe window structure
3. Resize window
4. Select library (if available)
5. Observe layout changes

**Expected Results**:
- ✅ Window displays sidebar (left) and main content area (right)
- ✅ Sidebar and main area are resizable
- ✅ Layout adapts to window resizing
- ✅ Selecting library updates main content area
- ✅ Layout remains usable at different window sizes

**Pass/Fail**: Window layout must be functional and adaptable.

---

## 3.5. T-023 — Manual Verification (UI Shell)

This section provides focused manual verification steps for T-023, covering the core UI shell functionality and library discovery workflow.

### Prerequisites

**Build and run the app**:
```bash
cd /path/to/MediaHub
swift build
swift test  # Verify tests pass before manual testing
swift run MediaHubUI  # GUI app runs until closed (Cmd+Q to quit)
```

**Note**: The GUI app will run until explicitly closed. Use Cmd+Q to quit, or close the window.

### Verification Steps

#### Step 1: App Launches and Shows Sidebar + EmptyState
**Setup**: No setup required.

**Steps**:
1. Run: `swift run MediaHubUI`
2. Observe the app window

**Expected Results**:
- ✅ Window opens with title "MediaHub"
- ✅ Window displays sidebar (left pane) with "Libraries" header
- ✅ Sidebar shows "Choose Folder…" button
- ✅ Main content area (right pane) shows `EmptyStateView`:
  - Text: "Welcome to MediaHub"
  - Text: "Choose a folder to discover libraries"
- ✅ No errors displayed

**Pass/Fail**: All items must pass. Window must open within 1 second.

---

#### Step 2: Choose Folder… Opens NSOpenPanel and Triggers Discovery
**Setup**: Test libraries created (see Fixture Setup in section 2).

**Steps**:
1. In the app, click "Choose Folder…" button in the sidebar
2. In the `NSOpenPanel` dialog:
   - Verify it's configured for directory selection only (files cannot be selected)
   - Navigate to `/tmp` (or folder containing test libraries)
   - Click "Open"
3. Observe the sidebar during discovery

**Expected Results**:
- ✅ `NSOpenPanel` opens when button is clicked
- ✅ Dialog allows directory selection only (not files)
- ✅ After selecting a folder:
  - Sidebar shows "Discovering…" text (if scan takes time)
  - "Discovering…" disappears when scan completes
  - Sidebar shows list of discovered libraries (if any found)

**Pass/Fail**: Folder picker must work and trigger discovery correctly.

**CLI Cross-Check** (optional):
```bash
# Verify libraries exist at expected paths
ls -la /tmp/mh-ui-test-lib-*/.mediahub/library.json
```

---

#### Step 3: 0 Results Shows "(No libraries found)" and NOT an Error
**Setup**: Empty folder created (see Fixture Setup in section 2).

**Steps**:
1. In the app, click "Choose Folder…"
2. Navigate to `/tmp/mh-ui-test-empty-folder` (or any empty folder)
3. Click "Open"
4. Observe the sidebar

**Expected Results**:
- ✅ Sidebar shows "(No libraries found)" text
- ✅ NO error message is displayed
- ✅ Main content area remains in empty state (or shows welcome message)
- ✅ App remains usable (user can choose a different folder)

**Pass/Fail**: Empty folder must show normal empty state, NOT an error.

**Note**: This verifies that "no libraries found" is handled as normal state, not an error condition.

---

#### Step 4: Selecting an Invalid Library Shows Error and Does NOT Open It
**Setup**: Invalid library created (see Fixture Setup in section 2). Note: Invalid libraries may appear in the discovery list with an "Invalid" label.

**Steps**:
1. In the app, select a folder containing an invalid library (e.g., `/tmp` if `mh-ui-test-invalid` exists)
2. In the sidebar, click on a library row marked as "Invalid"
3. Observe the main content area and any error messages

**Expected Results**:
- ✅ Invalid library row is visually distinct (shows "Invalid" label)
- ✅ Clicking invalid library:
  - Does NOT open the library (no `StatusView` appears)
  - Shows error message in main content area (red text)
  - Error message is clear and user-facing (e.g., "This library is invalid (unreadable or malformed .mediahub/library.json).")
- ✅ `selectedLibraryPath` remains `nil` (library is not selected)
- ✅ `openedLibraryPath` remains `nil` (library is not opened)

**Pass/Fail**: Invalid library selection must show error and NOT open the library.

---

#### Step 5: Selecting a Valid Library Opens It and Loads Status
**Setup**: Valid libraries discovered (from Step 2).

**Steps**:
1. In the sidebar, click on a valid library (e.g., `mh-ui-test-lib-1`)
2. Observe the main content area
3. Wait for status to load (if applicable)

**Expected Results**:
- ✅ Library row is visually selected (highlighted)
- ✅ Main content area updates to show `StatusView` (replaces `EmptyStateView`)
- ✅ `StatusView` displays:
  - "Library Status" heading
  - Baseline index status: "Present" / "Missing" / "N/A"
  - Hash index status: "Present" / "Missing" / "N/A"
  - Items count: `<n>` / "N/A"
  - Last scan date: `<date>` / "N/A"
- ✅ If status is loading, shows "Loading status…" text
- ✅ Loading indicator disappears when status loads
- ✅ No errors displayed

**Pass/Fail**: Valid library must open and status must load correctly.

**Timing**: Status view must appear within 2 seconds of selection.

**CLI Cross-Check** (optional):
```bash
mediahub status --json /tmp/mh-ui-test-lib-1
```
Compare baseline index presence, hash index presence, items count, and last scan date semantically when available. Do NOT require full JSON semantic parity beyond what UI displays.

---

#### Step 6: Opening Failure Shows libraryOpenError and Resets Status View
**Setup**: Valid library discovered. Create a scenario where opening will fail.

**Steps**:
1. In the app, discover libraries (e.g., select `/tmp` folder)
2. Before selecting a library, make it temporarily inaccessible:
   ```bash
   # Make library folder unreadable
   chmod 000 /tmp/mh-ui-test-lib-1
   ```
3. In the sidebar, click on the library (`mh-ui-test-lib-1`)
4. Observe error handling
5. Restore access:
   ```bash
   chmod 755 /tmp/mh-ui-test-lib-1
   ```

**Expected Results**:
- ✅ If opening fails:
  - `libraryOpenError` is displayed in main content area (red text)
  - Error message is clear and user-facing (e.g., "Failed to open library: <reason>")
  - `StatusView` is NOT displayed (or is reset to empty state)
  - `statusViewModel.status` is `nil`
  - `statusViewModel.errorMessage` is `nil`
  - `statusViewModel.isLoading` is `false`
- ✅ App remains usable (user can select a different library)

**Pass/Fail**: Opening failure must show clear error and reset status view correctly.

**Note**: This verifies that stale status from a previous library is not shown when a new library fails to open.

---

#### Step 7: Moved/Deleted Library Detection (Within ~2 Seconds)
**Setup**: Valid library opened (from Step 5).

**Steps**:
1. Open a valid library in the app (e.g., `mh-ui-test-lib-1`)
2. Verify `StatusView` is displayed
3. While app is running, move or delete the library directory:
   ```bash
   mv /tmp/mh-ui-test-lib-1 /tmp/mh-ui-test-lib-1-moved
   # OR: rm -rf /tmp/mh-ui-test-lib-1
   ```
4. Wait approximately 2 seconds
5. Observe the app's response

**Expected Results**:
- ✅ Within ~2 seconds, app detects library is no longer accessible
- ✅ Error message appears: "Opened library is no longer accessible (moved or deleted)."
- ✅ `selectedLibraryPath` is cleared (`nil`)
- ✅ `openedLibraryPath` is cleared (`nil`)
- ✅ `libraryContext` is cleared (`nil`)
- ✅ `StatusView` is replaced with `EmptyStateView`
- ✅ App remains usable (user can select a different library)

**Pass/Fail**: Moved/deleted library must be detected within ~2 seconds and state must be cleared correctly.

**Timing**: Detection must occur within approximately 2 seconds (periodic validation runs every 2 seconds).

**Cleanup**:
```bash
# Restore library for subsequent tests (if moved, not deleted)
mv /tmp/mh-ui-test-lib-1-moved /tmp/mh-ui-test-lib-1
```

---

#### Step 8: Determinism — Re-running Discovery Yields Same Ordering
**Setup**: Test libraries created (see Fixture Setup in section 2).

**Steps**:
1. In the app, click "Choose Folder…"
2. Select `/tmp` folder (or folder containing test libraries)
3. Note the order of libraries in the sidebar (e.g., `mh-ui-test-lib-1`, `mh-ui-test-lib-2`, `mh-ui-test-lib-zebra`)
4. Click "Choose Folder…" again
5. Select the same folder again (`/tmp`)
6. Note the order of libraries in the sidebar
7. Repeat steps 4-6 two more times (total of 3 runs)

**Expected Results**:
- ✅ Libraries appear in lexicographic order by path:
  1. `mh-ui-test-lib-1` (if path is `/tmp/mh-ui-test-lib-1`)
  2. `mh-ui-test-lib-2` (if path is `/tmp/mh-ui-test-lib-2`)
  3. `mh-ui-test-lib-zebra` (if path is `/tmp/mh-ui-test-lib-zebra`)
- ✅ Order is identical across all 3 runs (deterministic)
- ✅ Order matches lexicographic sorting by full path string

**Pass/Fail**: Discovery must yield identical ordering across multiple runs (deterministic behavior).

**CLI Cross-Check** (optional):
```bash
# Verify CLI also discovers in same order (if CLI discovery exists)
# This is a UI-only feature, so CLI cross-check may not apply
```

---

### T-023 Verification Summary

**All Steps Pass**: ________ (Yes/No)

**Notes**: ________

---

## 4. Success Criteria Verification

### SC-001: Discovery Time < 5 Seconds
**What to Measure**: Time from folder selection to library list display.

**How to Measure**:
1. Launch app
2. Start stopwatch when clicking "Choose Folder…"
3. Select `/tmp` folder (contains 3 test libraries)
4. Stop stopwatch when libraries appear in sidebar

**Threshold**: < 5 seconds

**Pass/Fail**: 
- ✅ **Pass**: Discovery completes within 5 seconds
- ❌ **Fail**: Discovery takes 5 seconds or longer

**Result**: ________ (Pass/Fail)

---

### SC-002: Open Time < 2 Seconds
**What to Measure**: Time from library selection to status view display.

**How to Measure**:
1. Libraries are discovered in sidebar
2. Start stopwatch when clicking library in sidebar
3. Stop stopwatch when status view appears in main content area

**Threshold**: < 2 seconds

**Pass/Fail**:
- ✅ **Pass**: Status view appears within 2 seconds
- ❌ **Fail**: Status view takes 2 seconds or longer

**Result**: ________ (Pass/Fail)

---

### SC-003: Status Matches CLI Semantically
**What to Measure**: Semantic match between UI status and CLI `mediahub status --json` output.

**How to Measure**:
1. Open a library in UI
2. Note all displayed values (path, ID, version, source count, statistics, hash coverage, performance)
3. Run: `mediahub status --json <library-path>`
4. Compare values semantically (same values when available, not exact JSON schema)

**Threshold**: 100% semantic accuracy (same values when available)

**Pass/Fail**:
- ✅ **Pass**: All available values match CLI semantically
- ❌ **Fail**: Values differ from CLI or missing values are not handled correctly

**Result**: ________ (Pass/Fail)

**Note**: Semantic match means same values, not exact JSON schema/field order (per spec update).

---

### SC-004: Error Handling (100% Clear Messages)
**What to Measure**: All error cases display clear, actionable messages.

**How to Measure**:
Test all error scenarios:
1. Permission denied folder
2. Invalid library metadata
3. Moved/deleted library
4. Status loading failure

**Threshold**: 100% of error cases show clear messages

**Pass/Fail**:
- ✅ **Pass**: All error cases tested show clear, actionable messages
- ❌ **Fail**: Any error case shows unclear message or crashes

**Result**: ________ (Pass/Fail)

---

### SC-005: Deterministic Ordering
**What to Measure**: Library list order is stable across app launches.

**How to Measure**:
1. Launch app, select `/tmp` folder, note library order
2. Quit app
3. Relaunch app, select `/tmp` folder again, note library order
4. Compare orders

**Threshold**: Identical order across launches

**Pass/Fail**:
- ✅ **Pass**: Order is identical (lexicographic by path)
- ❌ **Fail**: Order differs between launches

**Result**: ________ (Pass/Fail)

---

### SC-006: Backward Compatibility
**What to Measure**: App opens libraries created by slices 1–10.

**How to Measure**:
1. Use a library created by prior slices (user-provided path)
2. Discover and open library in UI
3. Verify status displays correctly

**Threshold**: 100% success rate

**Pass/Fail**:
- ✅ **Pass**: Library opens and status displays without errors
- ❌ **Fail**: Library fails to open or status fails to display

**Result**: ________ (Pass/Fail)

**Note**: If no library from prior slices is available, mark as "N/A - no prior slice library available" and explain.

---

### SC-007: N/A Display for Missing Index
**What to Measure**: "N/A" displayed for statistics and hash coverage when baseline index is missing.

**How to Measure**:
1. Open library without baseline index (empty library)
2. Observe status view
3. Verify "N/A" is shown for statistics and hash coverage
4. Compare with CLI: `mediahub status <library-path>` (should also show "N/A")

**Threshold**: 100% match with CLI behavior

**Pass/Fail**:
- ✅ **Pass**: "N/A" displayed and matches CLI behavior
- ❌ **Fail**: Missing index not handled correctly or doesn't match CLI

**Result**: ________ (Pass/Fail)

---

### SC-008: Window Opens < 1 Second
**What to Measure**: Time from app launch to window display.

**How to Measure**:
1. Start stopwatch when executing `swift run MediaHubUI`
2. Stop stopwatch when window appears on screen

**Threshold**: < 1 second

**Pass/Fail**:
- ✅ **Pass**: Window appears within 1 second
- ❌ **Fail**: Window takes 1 second or longer

**Result**: ________ (Pass/Fail)

---

## 5. Safety & Non-Goals Verification

### Safety Check 1: Read-Only Operations
**What to Verify**: App does not write to library directories.

**How to Verify**:
1. Create file snapshot before operations:
   ```bash
   find /tmp/mh-ui-test-lib-1 -type f -exec stat -f "%m %N" {} \; | sort > /tmp/mh-before.txt
   ```
2. Note modification time of library metadata file:
   ```bash
   stat -f %m /tmp/mh-ui-test-lib-1/.mediahub/library.json
   ```
3. Launch app, discover library, open library, view status
4. Create file snapshot after operations:
   ```bash
   find /tmp/mh-ui-test-lib-1 -type f -exec stat -f "%m %N" {} \; | sort > /tmp/mh-after.txt
   ```
5. Compare snapshots:
   ```bash
   diff /tmp/mh-before.txt /tmp/mh-after.txt
   ```
6. Check modification time again:
   ```bash
   stat -f %m /tmp/mh-ui-test-lib-1/.mediahub/library.json
   ```
7. Verify no files were created/modified in library directory:
   ```bash
   find /tmp/mh-ui-test-lib-1 -newer /tmp/mh-ui-test-lib-1/.mediahub/library.json
   ```

**Expected Results**:
- ✅ File snapshot diff shows no differences (no files created/modified)
- ✅ Modification time unchanged
- ✅ No new files created in library directory
- ✅ No files modified in library directory

**Pass/Fail**:
- ✅ **Pass**: No writes detected
- ❌ **Fail**: Writes detected

**Result**: ________ (Pass/Fail)

**Traceability**: SR-001, SR-002, IO-004, IO-005

---

### Safety Check 2: No New CLI Commands/Flags
**What to Verify**: App does not require new CLI commands or flags.

**How to Verify**:
1. Check CLI help for new commands:
   ```bash
   mediahub --help
   ```
2. Verify all used commands exist in prior slices:
   - `mediahub library create` (Slice 1)
   - `mediahub status` (Slice 4)
   - `mediahub library adopt` (Slice 6, if used)

**Expected Results**:
- ✅ No new commands in CLI help
- ✅ All used commands are from prior slices

**Pass/Fail**:
- ✅ **Pass**: No new commands/flags required
- ❌ **Fail**: New commands/flags required

**Result**: ________ (Pass/Fail)

**Traceability**: CLI-005, OOS-011

---

### Safety Check 3: Backward Compatibility Smoke Test
**What to Verify**: App works with libraries from slices 1–10.

**How to Verify**:
1. Use a library created by prior slices (user-provided path)
2. Discover library in UI
3. Open library
4. View status
5. Verify no errors or mutations

**Expected Results**:
- ✅ Library discovered successfully
- ✅ Library opens without errors
- ✅ Status displays correctly
- ✅ No mutations to library

**Pass/Fail**:
- ✅ **Pass**: Library works correctly
- ❌ **Fail**: Library fails or is mutated

**Result**: ________ (Pass/Fail)

**Traceability**: FR-014, SC-006

**Note**: If no library from prior slices is available, mark as "N/A - no prior slice library available" and explain.

---

### Non-Goals Verification
**What to Verify**: App does NOT implement out-of-scope features.

**How to Verify**: Visual inspection and functional testing.

**Expected Results**:
- ✅ No library creation wizard (deferred to Slice 12)
- ✅ No library adoption wizard (deferred to Slice 12)
- ✅ No source attachment UI (deferred to Slice 13)
- ✅ No detection/import UI (deferred to Slice 13)
- ✅ No progress bars/cancellation UI (deferred to Slices 14–15)
- ✅ No hash maintenance UI (deferred to Slice 16)
- ✅ No history/audit timeline UI (deferred to Slice 17)
- ✅ No mutating operations (create, adopt, attach, detect, import, hash maintenance)

**Pass/Fail**:
- ✅ **Pass**: No out-of-scope features present
- ❌ **Fail**: Out-of-scope features present

**Result**: ________ (Pass/Fail)

**Traceability**: OOS-001 through OOS-012

---

## 6. Optional Features (If Implemented)

### Optional Check: Last-Opened Library Persistence
**What to Verify**: App remembers last-opened library across launches.

**How to Verify**:
1. Open a library in app
2. Quit app (Cmd+Q)
3. Relaunch app
4. Observe if library is restored

**Expected Results**:
- ✅ Last-opened library is restored (if valid)
- ✅ Invalid library paths are cleared (no error shown)
- ✅ App falls back to empty state gracefully if library is invalid

**Pass/Fail**:
- ✅ **Pass**: Persistence works correctly
- ❌ **Fail**: Persistence fails or causes errors
- ⚪ **N/A**: Persistence not implemented (per plan, this is optional)

**Result**: ________ (Pass/Fail/N/A)

**Traceability**: FR-011, FR-012

**Note**: If persistence is not implemented, mark ONLY persistence-related optional checks as N/A. This does not affect SC-004 (error handling).

---

### Optional Check: Security-Scoped Bookmarks (Sandbox)
**What to Verify**: Security-scoped bookmarks work in sandboxed environment.

**How to Verify**:
1. Enable app sandbox (if applicable)
2. Open library
3. Quit and relaunch app
4. Verify library access persists

**Expected Results**:
- ✅ Security-scoped bookmarks work correctly
- ✅ Library access persists across launches in sandboxed environment

**Pass/Fail**:
- ✅ **Pass**: Bookmarks work correctly
- ❌ **Fail**: Bookmarks fail or cause errors
- ⚪ **N/A**: Sandbox not enabled or bookmarks not implemented (per plan, this is optional)

**Result**: ________ (Pass/Fail/N/A)

**Traceability**: SR-006, FR-011

**Note**: If sandbox/bookmarks are not implemented, mark as "N/A" and document that this was deferred per plan.

---

## 7. Validation Summary

### Overall Results

**Success Criteria**:
- SC-001 (Discovery < 5s): ________
- SC-002 (Open < 2s): ________
- SC-003 (Status matches CLI): ________
- SC-004 (Error handling): ________
- SC-005 (Deterministic ordering): ________
- SC-006 (Backward compatibility): ________
- SC-007 (N/A display): ________
- SC-008 (Window opens < 1s): ________

**Safety Checks**:
- Read-only operations: ________
- No new CLI commands: ________
- Backward compatibility: ________
- Non-goals verification: ________

**Optional Features**:
- Last-opened persistence: ________ (Pass/Fail/N/A)
- Security-scoped bookmarks: ________ (Pass/Fail/N/A)

### Final Status

- ✅ **PASS**: All success criteria pass, all safety checks pass
- ⚠️ **PASS WITH NOTES**: All success criteria pass, but some optional features are N/A or have notes
- ❌ **FAIL**: One or more success criteria fail or safety checks fail

**Validation Date**: ________  
**Validated By**: ________  
**Notes**: ________

---

## 8. Cleanup

After validation, clean up test fixtures:

```bash
# Remove test libraries
rm -rf /tmp/mh-ui-test-*

# Verify cleanup
ls -la /tmp/mh-ui-test-* 2>/dev/null || echo "Cleanup complete"
```

---

**End of Validation Runbook**
