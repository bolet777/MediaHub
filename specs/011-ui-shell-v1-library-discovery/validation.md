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
2. Click "Select Folder" button (in sidebar or empty state)
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
2. Click "Select Folder"
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
2. Click "Select Folder"
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

#### Check 1.7: Invalid Library Metadata is Skipped
**Setup**: Invalid library created (Fixture Setup).

**Steps**:
1. Launch app
2. Select `/tmp` folder (contains both valid and invalid libraries)
3. Observe sidebar list

**Expected Results**:
- ✅ Only valid libraries appear in list
- ✅ Invalid library (`mh-ui-test-invalid`) is NOT displayed
- ✅ No crash or error alert (invalid library is silently skipped)
- ✅ App continues to function normally

**Pass/Fail**: Invalid libraries must be skipped without crashing (FR-005, SR-003).

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
  - Library path
  - Library ID
  - Library version
  - Source count (0 for new libraries)
  - Sources list (empty for new libraries)
- ✅ All fields are readable and properly formatted

**Pass/Fail**: All basic library information must be displayed.

---

#### Check 2.3: Open Invalid Library Shows Error
**Setup**: Invalid library created (Fixture Setup). Note: Invalid library won't appear in discovery, so we need to test this differently.

**Steps**:
1. Create invalid library manually if not already created
2. If app allows manual path entry, enter `/tmp/mh-ui-test-invalid`
3. OR: If app only allows selection from discovered libraries, this check may be N/A
4. Observe error message

**Expected Results**:
- ✅ Clear error message: "Library metadata is corrupted or invalid" or "Invalid library metadata" or similar
- ✅ Error is actionable (user knows what went wrong)
- ✅ App remains usable (user can select different library)
- ✅ Error state clears when user selects different library

**Pass/Fail**: Invalid library must show clear error message (SC-004, FR-010, SR-004).

**Note**: If app only allows selection from discovered libraries (invalid ones are filtered out), document this check as "N/A - invalid libraries filtered during discovery" and explain.

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
  - Path, ID, Version, Source Count
  - Sources list (if any)
  - Statistics section: Total items, By year, By media type
  - Hash Coverage section: Total entries, Entries with hash, Coverage percentage
  - Performance section: File count, Total size, Hash coverage, Duration
- ✅ All sections are populated with actual values (not "N/A")

**Pass/Fail**: All status sections must display when baseline index is available.

**CLI Cross-Check**:
```bash
mediahub status --json /tmp/mh-ui-test-lib-with-index
```
Compare UI values with CLI JSON output semantically (same values when available, not exact schema).

**Note**: If no library with baseline index is available, mark this check as "N/A - no library with baseline index available" and explain.

---

#### Check 3.2: Status without Baseline Index (N/A Display)
**Setup**: Empty library without baseline index created (Fixture Setup).

**Steps**:
1. Open `/tmp/mh-ui-test-lib-no-index` (or any empty library)
2. Observe status view

**Expected Results**:
- ✅ Status view displays:
  - Path, ID, Version, Source Count
  - Sources list (empty)
- ✅ Statistics section shows "N/A" (or section indicates unavailable)
- ✅ Hash Coverage section shows "N/A" (or section indicates unavailable)
- ✅ Performance section may show "N/A" for hash coverage, but may show file count (0) and total size (0)

**Pass/Fail**: Missing baseline index must show "N/A" for statistics and hash coverage (SC-007, FR-009).

**CLI Cross-Check**:
```bash
mediahub status --json /tmp/mh-ui-test-lib-no-index
```
Verify CLI also shows "N/A" or omits statistics/hashCoverage fields. UI must match CLI behavior.

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
- ✅ UI values match CLI values semantically:
  - Path: Same
  - Identifier: Same
  - Version: Same
  - Source Count: Same
  - Sources: Same count and IDs
  - Statistics: Same values when available (or both show N/A)
  - Hash Coverage: Same values when available (or both show N/A)
  - Performance: Same values when available (or both show N/A)
- ✅ Field order and JSON schema may differ (semantic match, not exact schema)

**Pass/Fail**: UI status must match CLI status information semantically (SC-003, DR-002).

**Note**: This verifies semantic matching, not exact JSON schema/field order (per spec update).

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

## 4. Success Criteria Verification

### SC-001: Discovery Time < 5 Seconds
**What to Measure**: Time from folder selection to library list display.

**How to Measure**:
1. Launch app
2. Start stopwatch when clicking "Select Folder"
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
