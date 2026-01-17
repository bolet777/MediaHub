# Slice 13b — UI Integration & UX Polish

**Document Type**: Slice Validation Runbook  
**Slice Number**: 13b  
**Title**: UI Integration & UX Polish  
**Author**: Spec-Kit Orchestrator  
**Date**: 2026-01-27  
**Status**: Frozen

---

## Validation Overview

This runbook provides comprehensive validation for Slice 13b implementation. All checks are runnable and verify the success criteria from spec.md: integration of source management, detection, and import workflows into the main library view and source list.

**Slice Status**: Optional/post-freeze UX polish. All functionality exists in Slice 13; this slice only integrates it.

**Key Validation Principles**:
- Source list displays in library detail view when library is open
- Source management actions (attach/detach) work from library view
- Detection actions (preview/run) work from source list
- Import actions (preview/confirmation/execution) work from detection results
- State synchronization works correctly (source list refresh, library status refresh)
- All safety guarantees from Slice 13 are preserved
- Deterministic behavior (same library state produces same UI state)

**Validation Approach**:
- Manual UI testing (macOS SwiftUI app requires visual verification)
- State synchronization verification (check that UI updates after operations)
- Workflow integration verification (check that workflows are accessible from integrated locations)
- Repeatable test scenarios with explicit pass/fail criteria

---

## 1. Preconditions

### System Requirements
- **macOS**: Version 13.0 (Ventura) or later
- **Swift**: Version 5.7 or later
- **Xcode**: Version 14.0 or later (for opening package in Xcode, optional)
- **Slice 13**: Must be complete (all source/detection/import workflows functional)

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
- Inline error text: displayed in UI (error messages)
- System Console.app: For system-level errors (if needed)

### Cleanup Before Validation
```bash
# Clean up previous test libraries and sources (if any)
rm -rf /tmp/mh-slice13b-test-*
```

---

## 2. Test Fixtures

### Fixture Setup Commands

**Create test library for integration testing**:
```bash
# Create a test library
mediahub library create /tmp/mh-slice13b-test-lib
# Verify library was created
ls -la /tmp/mh-slice13b-test-lib/.mediahub/library.json
```

**Expected**: Valid MediaHub library at `/tmp/mh-slice13b-test-lib`.

**Create test source directory with media files**:
```bash
# Create source directory with media files
mkdir -p /tmp/mh-slice13b-test-source
echo "fake image content" > /tmp/mh-slice13b-test-source/image1.jpg
echo "fake image content" > /tmp/mh-slice13b-test-source/image2.jpg
# Verify files exist
ls -la /tmp/mh-slice13b-test-source/
```

**Expected**: Directory with media files at `/tmp/mh-slice13b-test-source`.

**Attach source to library (for testing source list display)**:
```bash
# Attach source to library
mediahub source attach /tmp/mh-slice13b-test-source /tmp/mh-slice13b-test-lib --media-types both
# Verify source was attached
mediahub source list /tmp/mh-slice13b-test-lib
```

**Expected**: Source attached to library, visible in `mediahub source list` output.

---

## 3. Success Criteria Validation

### SC-001: Source List Display in Library View

**Objective**: Verify that source list displays in library detail view within 1 second of opening a library.

**Steps**:
1. Launch MediaHubUI app
2. Open library at `/tmp/mh-slice13b-test-lib` (use "Choose Folder" or library discovery)
3. Observe library detail view (right side of app)

**Expected Results**:
- ✅ Source list section appears below StatusView in library detail view
- ✅ Section header "Sources" or "Attached Sources" is visible
- ✅ SourceListView displays attached sources (if any)
- ✅ Source list appears within 1 second of library opening
- ✅ Source information matches CLI `mediahub source list` output (paths, media types, last detection timestamps)

**If source list does not appear**: Check console for errors, verify SourceState is initialized in ContentView.

---

### SC-002: Source List Refresh After Operations

**Objective**: Verify that source list refreshes within 1 second after source attachment/detachment operations.

**Steps**:
1. Open library at `/tmp/mh-slice13b-test-lib` in app
2. Verify source list is displayed (from SC-001)
3. Click "Attach Source" button in source list section
4. Select source directory `/tmp/mh-slice13b-test-source` (or create new test source)
5. Select media types (images, videos, or both)
6. Confirm attachment
7. Observe source list after attachment completes

**Expected Results**:
- ✅ Source list refreshes automatically after successful attachment
- ✅ Newly attached source appears in list
- ✅ Source list refresh completes within 1 second of attachment
- ✅ Source information is correct (path, media types)

**Steps for detachment**:
1. Click "Detach Source" action for a source in list
2. Confirm detachment in dialog
3. Observe source list after detachment completes

**Expected Results**:
- ✅ Source list refreshes automatically after successful detachment
- ✅ Detached source no longer appears in list
- ✅ Source list refresh completes within 1 second of detachment

**If source list does not refresh**: Check console for errors, verify SourceState.refreshSources() is called after operations.

---

### SC-003: Detection Workflows from Source List

**Objective**: Verify that detection workflows (preview/run) are accessible from source list and work correctly.

**Steps**:
1. Open library at `/tmp/mh-slice13b-test-lib` in app
2. Verify source list is displayed with at least one attached source
3. Right-click on a source (or use action button) to open context menu
4. Click "Preview Detection" action
5. Observe detection preview view

**Expected Results**:
- ✅ Detection actions ("Preview Detection", "Run Detection") are visible in source list context menu or as buttons
- ✅ "Preview Detection" action is accessible for each source
- ✅ DetectionPreviewView is presented as sheet within 1 second of clicking action
- ✅ Detection preview results are displayed correctly (matching Slice 13 behavior)
- ✅ Source list refreshes after preview to show updated lastDetectedAt timestamp

**Steps for detection run**:
1. Click "Run Detection" action for a source (or from preview view)
2. Observe detection run view

**Expected Results**:
- ✅ DetectionRunView is presented as sheet within 1 second of clicking action
- ✅ Detection run results are displayed correctly (matching Slice 13 behavior)
- ✅ Source list refreshes after run to show updated lastDetectedAt timestamp

**If detection actions are not visible**: Check SourceListView for context menu or button implementation.

---

### SC-004: Import Workflows from Detection Results

**Objective**: Verify that import workflows (preview/confirmation/execution) are accessible from detection results and work correctly.

**Steps**:
1. Open library at `/tmp/mh-slice13b-test-lib` in app
2. Run detection for a source (from SC-003)
3. Verify detection results show new items detected
4. Click "Preview Import" button in DetectionRunView
5. Observe import preview view

**Expected Results**:
- ✅ "Preview Import" button is visible in DetectionRunView when new items are detected
- ✅ ImportPreviewView is presented as sheet within 1 second of clicking action
- ✅ Import preview results are displayed correctly (matching Slice 13 behavior)

**Steps for import execution**:
1. Proceed through import preview to confirmation dialog
2. Confirm import in dialog
3. Observe import execution view

**Expected Results**:
- ✅ ImportConfirmationView is presented correctly
- ✅ ImportExecutionView is presented after confirmation
- ✅ Import execution completes successfully
- ✅ Library status refreshes after import execution (StatusView updates)

**If import actions are not visible**: Check DetectionRunView for "Preview Import" button implementation.

---

### SC-005: State Synchronization

**Objective**: Verify that state synchronization works correctly (source list refresh, library status refresh) after all operations.

**Steps**:
1. Open library at `/tmp/mh-slice13b-test-lib` in app
2. Perform source attachment operation (from SC-002)
3. Verify source list updates immediately after attachment
4. Perform detection operation (from SC-003)
5. Verify source list updates immediately after detection (lastDetectedAt timestamp)
6. Perform import operation (from SC-004)
7. Verify library status updates immediately after import (StatusView shows updated item count)

**Expected Results**:
- ✅ Source list refreshes after source operations (attachment/detachment)
- ✅ Source list refreshes after detection operations (lastDetectedAt timestamp)
- ✅ Library status refreshes after import operations (item count, statistics)
- ✅ All state updates occur automatically without manual refresh
- ✅ State synchronization is idempotent (safe to refresh multiple times)

**If state does not synchronize**: Check console for errors, verify state refresh handlers are called after operations.

---

### SC-006: Error Handling

**Objective**: Verify that error handling works correctly with clear error messages (matching Slice 13 behavior).

**Steps**:
1. Open library at `/tmp/mh-slice13b-test-lib` in app
2. Attempt to attach invalid source (non-existent path)
3. Observe error message

**Expected Results**:
- ✅ Error message is displayed clearly in UI
- ✅ Error message is user-facing and actionable (not technical error codes)
- ✅ Error handling matches Slice 13 behavior

**Steps for other error scenarios**:
1. Attempt detection on inaccessible source
2. Attempt import with invalid detection result
3. Observe error messages

**Expected Results**:
- ✅ All error conditions display clear error messages
- ✅ Error messages are consistent with Slice 13 behavior

---

### SC-007: Deterministic Behavior

**Objective**: Verify that deterministic behavior is maintained (same library state produces same UI state).

**Steps**:
1. Open library at `/tmp/mh-slice13b-test-lib` in app
2. Note source list contents and order
3. Close and reopen library
4. Observe source list contents and order

**Expected Results**:
- ✅ Source list displays same sources in same order
- ✅ Source information matches previous display (paths, media types, timestamps)
- ✅ UI state is deterministic (same library state produces same UI state)

**Steps for operation repeatability**:
1. Perform detection operation twice on same source
2. Verify detection results are identical (if source state hasn't changed)

**Expected Results**:
- ✅ Detection results are identical for same source state
- ✅ Import results are identical for same detection result
- ✅ Deterministic behavior is maintained across operations

---

## 4. Integration Workflow Validation

### Workflow 1: Source Management from Library View

**Objective**: Verify complete source management workflow from library view.

**Steps**:
1. Open library in app
2. View source list in library detail view
3. Attach new source from library view
4. Verify source appears in list
5. Detach source from library view
6. Verify source is removed from list

**Expected Results**:
- ✅ Complete workflow works from library view
- ✅ All steps are accessible without navigating to separate views
- ✅ State synchronization works correctly throughout workflow

---

### Workflow 2: Detection from Source List

**Objective**: Verify complete detection workflow from source list.

**Steps**:
1. Open library in app
2. View source list in library detail view
3. Run detection for a source from source list
4. View detection results
5. Verify source list shows updated lastDetectedAt timestamp

**Expected Results**:
- ✅ Complete workflow works from source list
- ✅ Detection views are presented correctly
- ✅ Source list updates after detection

---

### Workflow 3: Import from Detection Results

**Objective**: Verify complete import workflow from detection results.

**Steps**:
1. Open library in app
2. Run detection for a source
3. View detection results
4. Preview import from detection results
5. Confirm and execute import
6. Verify library status updates

**Expected Results**:
- ✅ Complete workflow works from detection results
- ✅ Import views are presented correctly
- ✅ Library status updates after import

---

## 5. Safety Guarantees Validation

### Safety Check 1: Preview Operations

**Objective**: Verify that preview operations maintain safety guarantees from Slice 13.

**Steps**:
1. Run detection preview from source list
2. Verify detection preview does not modify source files (read-only)
3. Run import preview from detection results
4. Verify import preview does not copy files (dry-run)

**Expected Results**:
- ✅ Detection preview is read-only (no source file modifications)
- ✅ Import preview performs zero filesystem writes (dry-run)
- ✅ All safety guarantees from Slice 13 are preserved

---

### Safety Check 2: Explicit Confirmations

**Objective**: Verify explicit confirmations are required before execution.

**Steps**:
1. Proceed through import preview to confirmation dialog
2. Verify confirmation dialog is displayed
3. Cancel confirmation dialog
4. Verify no files are copied

**Expected Results**:
- ✅ Confirmation dialog is displayed before import execution
- ✅ Cancelling confirmation prevents file operations
- ✅ Explicit confirmations are required (matching Slice 13 behavior)

---

## 6. Backward Compatibility Validation

### Compatibility Check 1: Existing Libraries

**Objective**: Verify that existing libraries work correctly with integrated workflows.

**Steps**:
1. Open existing library (created/adopted by slices 1-13)
2. Verify source list displays correctly
3. Perform source/detection/import operations
4. Verify operations work correctly

**Expected Results**:
- ✅ Existing libraries work correctly with integrated workflows
- ✅ Source list displays correctly for existing libraries
- ✅ All operations work correctly (backward compatibility maintained)

---

### Compatibility Check 2: Libraries Without Sources

**Objective**: Verify that libraries without sources display correctly.

**Steps**:
1. Open library with no attached sources
2. Verify source list displays empty state
3. Verify "Attach Source" action is available

**Expected Results**:
- ✅ Empty state is displayed correctly
- ✅ "Attach Source" action is available
- ✅ Empty state matches Slice 13 behavior

---

## 7. Performance Validation

### Performance Check 1: Source List Display Speed

**Objective**: Verify that source list displays within 1 second (SC-001).

**Steps**:
1. Open library in app
2. Measure time from library open to source list display
3. Verify time is ≤ 1 second

**Expected Results**:
- ✅ Source list displays within 1 second
- ✅ Performance is acceptable for user experience

---

### Performance Check 2: State Refresh Speed

**Objective**: Verify that state refreshes within 1 second after operations (SC-002).

**Steps**:
1. Perform source attachment operation
2. Measure time from operation completion to source list refresh
3. Verify time is ≤ 1 second

**Expected Results**:
- ✅ State refresh completes within 1 second
- ✅ Performance is acceptable for user experience

---

## 8. Summary Checklist

### Phase 1: Source List Integration
- [ ] SC-001: Source list displays in library view
- [ ] SC-002: Source list refreshes after operations
- [ ] Integration workflow 1: Source management from library view

### Phase 2: Source Management Actions
- [ ] SC-002: Attach/detach actions work from library view
- [ ] Integration workflow 1: Complete source management workflow

### Phase 3: Detection Actions
- [ ] SC-003: Detection workflows accessible from source list
- [ ] Integration workflow 2: Complete detection workflow from source list

### Phase 4: Import Actions
- [ ] SC-004: Import workflows accessible from detection results
- [ ] Integration workflow 3: Complete import workflow from detection results

### General Validation
- [ ] SC-005: State synchronization works correctly
- [ ] SC-006: Error handling works correctly
- [ ] SC-007: Deterministic behavior maintained
- [ ] Safety guarantees preserved
- [ ] Backward compatibility maintained
- [ ] Performance acceptable

---

## 9. Known Issues and Limitations

### Known Limitations
- This slice is optional/post-freeze UX polish
- All functionality exists in Slice 13; this slice only integrates it
- Performance optimizations are out of scope

### Known Issues
- None identified at validation time

---

## 10. Validation Completion

**Validation Status**: [ ] Complete / [ ] In Progress / [ ] Blocked

**Blocking Issues** (if any):
- [List any blocking issues here]

**Next Steps** (if validation incomplete):
- [List next validation steps here]

---

**Validation Date**: [Date]  
**Validated By**: [Name]  
**Slice Status**: Optional/post-freeze UX polish
