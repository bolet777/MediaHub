# Slice 12 — UI Create / Adopt Wizard v1

**Document Type**: Slice Validation Runbook  
**Slice Number**: 12  
**Title**: UI Create / Adopt Wizard v1  
**Author**: Spec-Kit Orchestrator  
**Date**: 2026-01-27  
**Status**: Draft

---

## Validation Overview

This runbook provides comprehensive validation for Slice 12 implementation. All checks are runnable and verify the success criteria from spec.md: unified wizard interface for library creation and adoption, dry-run preview operations, explicit confirmation dialogs, wizard navigation, and deterministic behavior.

**Key Validation Principles**:
- Read-only operations during preview (zero writes to library directories, zero mutations)
- Deterministic behavior (same input → identical results)
- User-facing error messages (clear and actionable)
- Explicit confirmation before any file system modifications
- Backward compatibility with existing Core APIs from slices 1, 4, and 6
- Preview accuracy (preview matches actual execution results)

**Validation Approach**:
- Manual UI testing (macOS SwiftUI app requires visual verification)
- File system verification (check for zero writes during preview)
- CLI cross-checks for library compatibility (verify created/adopted libraries work with CLI)
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
- Inline error text: displayed in wizard UI (error messages)
- System Console.app: For system-level errors (if needed)

### Cleanup Before Validation
```bash
# Clean up previous test libraries and directories (if any)
rm -rf /tmp/mh-wizard-test-*
```

---

## 2. Test Fixtures

### Fixture Setup Commands

**Create empty directory for create wizard testing**:
```bash
# Create empty directory for new library creation
mkdir -p /tmp/mh-wizard-test-empty
# Verify it's empty
ls -la /tmp/mh-wizard-test-empty
```

**Expected**: Empty directory at `/tmp/mh-wizard-test-empty`.

**Create directory with files (non-empty, not a library) for create wizard testing**:
```bash
# Create directory with some files
mkdir -p /tmp/mh-wizard-test-with-files
echo "test file 1" > /tmp/mh-wizard-test-with-files/file1.txt
echo "test file 2" > /tmp/mh-wizard-test-with-files/file2.txt
# Verify files exist
ls -la /tmp/mh-wizard-test-with-files/
```

**Expected**: Directory with files at `/tmp/mh-wizard-test-with-files` (not a MediaHub library).

**Create existing MediaHub library (for error testing)**:
```bash
# Create a library that already exists
mediahub library create /tmp/mh-wizard-test-existing-lib
# Verify library was created
ls -la /tmp/mh-wizard-test-existing-lib/.mediahub/library.json
```

**Expected**: Valid MediaHub library at `/tmp/mh-wizard-test-existing-lib`.

**Create directory with media files for adopt wizard testing**:
```bash
# Create directory structure with media files (simulated)
mkdir -p /tmp/mh-wizard-test-adopt/{2024/01,2024/02}
echo "fake media content" > /tmp/mh-wizard-test-adopt/2024/01/media1.jpg
echo "fake media content" > /tmp/mh-wizard-test-adopt/2024/02/media2.jpg
# Verify structure exists
ls -la /tmp/mh-wizard-test-adopt/2024/01/
ls -la /tmp/mh-wizard-test-adopt/2024/02/
```

**Expected**: Directory with media files at `/tmp/mh-wizard-test-adopt` (not a MediaHub library).

**Create already-adopted library (for idempotent adoption testing)**:
```bash
# Create a library that's already adopted
mediahub library create /tmp/mh-wizard-test-already-adopted
# Verify library was created
ls -la /tmp/mh-wizard-test-already-adopted/.mediahub/library.json
```

**Expected**: Valid MediaHub library at `/tmp/mh-wizard-test-already-adopted`.

**Create invalid path (non-existent directory) for error testing**:
```bash
# Ensure path doesn't exist
rm -rf /tmp/mh-wizard-test-invalid-path
# Path will be used in wizard but doesn't exist
```

**Expected**: Path `/tmp/mh-wizard-test-invalid-path` does not exist.

**Create read-only directory (for permission error testing)**:
```bash
# Create directory and remove write permissions
mkdir -p /tmp/mh-wizard-test-readonly
chmod -w /tmp/mh-wizard-test-readonly
# Verify permissions
ls -ld /tmp/mh-wizard-test-readonly
```

**Expected**: Directory at `/tmp/mh-wizard-test-readonly` without write permissions.

**Note**: After testing, restore permissions: `chmod +w /tmp/mh-wizard-test-readonly`

---

## 3. Validation Checklist

### User Story 1: Create a New Library via Wizard

#### Check 1.1: Create Library Action Opens Wizard
**Setup**: No setup required.

**Steps**:
1. Build app: `swift build`
2. Run app: `swift run MediaHubUI`
3. Locate "Create Library" button or menu item
4. Click "Create Library" action

**Expected Results**:
- ✅ Wizard opens as a sheet or modal window
- ✅ Wizard displays step 1: Path Selection
- ✅ Wizard shows folder selection interface
- ✅ Wizard has "Cancel" button visible

**Pass/Fail**: All items must pass. Wizard must open within 1 second.

**Determinism**: Repeat launch and click "Create Library" 3 times. Wizard should open consistently each time.

---

#### Check 1.2: Folder Picker Opens and Selects Folder
**Setup**: Empty directory created (`/tmp/mh-wizard-test-empty`).

**Steps**:
1. Launch app (if not already running)
2. Click "Create Library" action
3. In wizard, click folder picker button
4. In folder picker dialog, navigate to `/tmp`
5. Select `/tmp/mh-wizard-test-empty` folder
6. Click "Open" to confirm selection

**Expected Results**:
- ✅ Folder picker dialog opens
- ✅ Dialog allows directory selection only (not files)
- ✅ `/tmp/mh-wizard-test-empty` folder can be selected
- ✅ Dialog closes after selection
- ✅ Selected path is displayed in wizard
- ✅ "Next" button becomes enabled (if path is valid)

**Pass/Fail**: Folder picker must work correctly and path must be displayed.

---

#### Check 1.3: Preview Shows What Will Be Created
**Setup**: Empty directory selected (`/tmp/mh-wizard-test-empty`).

**Steps**:
1. Select `/tmp/mh-wizard-test-empty` folder via folder picker (from Check 1.2)
2. Click "Next" button to proceed to preview step
3. Observe preview information displayed

**Expected Results**:
- ✅ Wizard navigates to preview step
- ✅ Preview step displays "Preview" badge or indicator
- ✅ Preview shows metadata location: `.mediahub/library.json` path
- ✅ Preview shows library ID (simulated, for create operations)
- ✅ Preview shows library version: "1.0"
- ✅ Preview indicates this is a preview (not actual execution)
- ✅ "Next" button is enabled to proceed to confirmation

**Pass/Fail**: All preview information must be displayed correctly.

**Timing**: Preview must complete within 1 second (SC-001: under 30 seconds total for typical operations).

**Zero Writes Verification**: 
- Before preview: `ls -la /tmp/mh-wizard-test-empty/.mediahub/` should show "No such file or directory"
- After preview: `ls -la /tmp/mh-wizard-test-empty/.mediahub/` should still show "No such file or directory"
- ✅ No `.mediahub` directory created during preview

---

#### Check 1.4: Path Validation - Already Existing Library
**Setup**: Existing library created (`/tmp/mh-wizard-test-existing-lib`).

**Steps**:
1. Launch wizard and click folder picker
2. Select `/tmp/mh-wizard-test-existing-lib` folder
3. Observe validation result

**Expected Results**:
- ✅ Wizard displays error message: "This location already contains a MediaHub library" or similar
- ✅ Error message is clear and user-facing
- ✅ "Next" button is disabled
- ✅ User can select a different path

**Pass/Fail**: Error must be displayed correctly for existing library.

---

#### Check 1.5: Path Validation - Non-Empty Directory Warning
**Setup**: Directory with files created (`/tmp/mh-wizard-test-with-files`).

**Steps**:
1. Launch wizard and click folder picker
2. Select `/tmp/mh-wizard-test-with-files` folder
3. Observe validation result

**Expected Results**:
- ✅ Wizard shows warning message about non-empty directory
- ✅ Warning requires explicit confirmation
- ✅ User can proceed after confirming (matching CLI behavior)
- ✅ Preview step shows what will be created

**Pass/Fail**: Warning must be displayed and confirmation must be required.

---

#### Check 1.6: Confirmation Dialog Displays Accurate Information
**Setup**: Preview completed for empty directory.

**Steps**:
1. Complete preview step (from Check 1.3)
2. Click "Next" to proceed to confirmation step
3. Observe confirmation dialog

**Expected Results**:
- ✅ Confirmation dialog displays summary:
  - Metadata location (accurate path to `.mediahub/library.json`)
  - Operation type: "Create Library"
  - Preview information (library ID, version)
- ✅ Confirmation dialog has "Create" button
- ✅ Confirmation dialog has "Cancel" button
- ✅ Information matches preview step

**Pass/Fail**: Confirmation dialog must show accurate information.

---

#### Check 1.7: Library Creation Execution
**Setup**: Empty directory selected, confirmation dialog displayed.

**Steps**:
1. In confirmation dialog, click "Create" button
2. Observe execution progress
3. Wait for completion

**Expected Results**:
- ✅ Progress indicator is shown during execution
- ✅ "Create" button is disabled during execution
- ✅ Library is created successfully
- ✅ Success feedback is displayed
- ✅ Wizard closes automatically
- ✅ Newly created library is automatically opened in app

**Pass/Fail**: Library must be created successfully and opened automatically.

**Timing**: Total operation must complete within 30 seconds (SC-001).

**Verification**:
- After execution: `ls -la /tmp/mh-wizard-test-empty/.mediahub/library.json` should show file exists
- Library metadata is valid: `mediahub library status /tmp/mh-wizard-test-empty` should work
- ✅ Library is compatible with CLI commands (backward compatibility, SC-007)

---

#### Check 1.8: Error Handling - Permission Denied
**Setup**: Read-only directory created (`/tmp/mh-wizard-test-readonly`).

**Steps**:
1. Launch wizard and select `/tmp/mh-wizard-test-readonly` folder
2. Proceed through preview and confirmation
3. Click "Create" button
4. Observe error handling

**Expected Results**:
- ✅ Error message is displayed: "Permission denied" or similar
- ✅ Error message is clear and actionable
- ✅ Wizard allows retry (user can correct issue)
- ✅ No partial library creation occurred
- ✅ Wizard does not crash

**Pass/Fail**: Error must be handled gracefully with clear message.

**Cleanup**: Restore permissions: `chmod +w /tmp/mh-wizard-test-readonly`

---

#### Check 1.9: Cancellation at Any Step
**Setup**: Wizard open at various steps.

**Steps**:
1. Launch wizard
2. Test cancellation at path selection step: Click "Cancel"
3. Launch wizard again
4. Select path, proceed to preview step
5. Test cancellation at preview step: Click "Cancel"
6. Launch wizard again
7. Select path, proceed to confirmation step
8. Test cancellation at confirmation step: Click "Cancel"

**Expected Results**:
- ✅ Cancellation works at path selection step
- ✅ Cancellation works at preview step
- ✅ Cancellation works at confirmation step
- ✅ Wizard closes on cancellation
- ✅ No files are created or modified on cancellation
- ✅ App returns to previous screen (library list or empty state)

**Pass/Fail**: Cancellation must work at all steps with zero file modifications (SC-010).

**Zero Writes Verification**:
- After cancellation: `ls -la /tmp/mh-wizard-test-empty/.mediahub/` should show "No such file or directory"
- ✅ No `.mediahub` directory created on cancellation

---

### User Story 2: Adopt Existing Directory via Wizard

#### Check 2.1: Adopt Library Action Opens Wizard
**Setup**: No setup required.

**Steps**:
1. Build app: `swift build`
2. Run app: `swift run MediaHubUI`
3. Locate "Adopt Library" button or menu item
4. Click "Adopt Library" action

**Expected Results**:
- ✅ Wizard opens as a sheet or modal window
- ✅ Wizard displays step 1: Path Selection
- ✅ Wizard shows directory selection interface
- ✅ Wizard has "Cancel" button visible

**Pass/Fail**: All items must pass. Wizard must open within 1 second.

**Determinism**: Repeat launch and click "Adopt Library" 3 times. Wizard should open consistently each time.

---

#### Check 2.2: Directory Picker Opens and Selects Directory
**Setup**: Directory with media files created (`/tmp/mh-wizard-test-adopt`).

**Steps**:
1. Launch app (if not already running)
2. Click "Adopt Library" action
3. In wizard, click folder picker button
4. In folder picker dialog, navigate to `/tmp`
5. Select `/tmp/mh-wizard-test-adopt` folder
6. Click "Open" to confirm selection

**Expected Results**:
- ✅ Folder picker dialog opens
- ✅ Dialog allows directory selection only (not files)
- ✅ `/tmp/mh-wizard-test-adopt` folder can be selected
- ✅ Dialog closes after selection
- ✅ Selected path is displayed in wizard
- ✅ "Next" button becomes enabled (if path is valid)

**Pass/Fail**: Folder picker must work correctly and path must be displayed.

---

#### Check 2.3: Preview Shows Baseline Scan Summary
**Setup**: Directory with media files selected (`/tmp/mh-wizard-test-adopt`).

**Steps**:
1. Select `/tmp/mh-wizard-test-adopt` folder via folder picker (from Check 2.2)
2. Click "Next" button to proceed to preview step
3. Observe preview information displayed (including baseline scan)

**Expected Results**:
- ✅ Wizard navigates to preview step
- ✅ Preview step displays "Preview" badge or indicator
- ✅ Preview shows metadata location: `.mediahub/library.json` path
- ✅ Preview shows baseline scan summary:
  - File count (number of media files found)
  - Scan scope information
- ✅ Preview shows library ID
- ✅ Preview indicates this is a preview (not actual execution)
- ✅ "Next" button is enabled to proceed to confirmation

**Pass/Fail**: All preview information including baseline scan must be displayed correctly.

**Timing**: Preview must complete within 5 seconds (SC-002: under 60 seconds total for typical operations).

**Zero Writes Verification**: 
- Before preview: `ls -la /tmp/mh-wizard-test-adopt/.mediahub/` should show "No such file or directory"
- After preview: `ls -la /tmp/mh-wizard-test-adopt/.mediahub/` should still show "No such file or directory"
- ✅ No `.mediahub` directory created during preview (dry-run mode)

---

#### Check 2.4: Path Validation - Already Adopted Library (Idempotent)
**Setup**: Already-adopted library created (`/tmp/mh-wizard-test-already-adopted`).

**Steps**:
1. Launch adopt wizard and click folder picker
2. Select `/tmp/mh-wizard-test-already-adopted` folder
3. Observe validation result

**Expected Results**:
- ✅ Wizard displays message: "Library is already adopted" or similar (idempotent behavior, not an error)
- ✅ Message is clear and informative
- ✅ "Next" button is enabled (allows proceeding to open existing library)
- ✅ User can proceed to open the existing library

**Pass/Fail**: Idempotent message must be displayed correctly (not treated as error).

---

#### Check 2.5: Path Validation - Invalid Path
**Setup**: Invalid path (non-existent directory).

**Steps**:
1. Launch adopt wizard and click folder picker
2. Manually enter or attempt to select `/tmp/mh-wizard-test-invalid-path` (non-existent)
3. Observe validation result

**Expected Results**:
- ✅ Wizard displays error message: "Path does not exist" or similar
- ✅ Error message is clear and user-facing
- ✅ "Next" button is disabled
- ✅ User can select a different path

**Pass/Fail**: Error must be displayed correctly for invalid path.

---

#### Check 2.6: Confirmation Dialog Displays Safety Message
**Setup**: Preview completed for directory with media files.

**Steps**:
1. Complete preview step (from Check 2.3)
2. Click "Next" to proceed to confirmation step
3. Observe confirmation dialog

**Expected Results**:
- ✅ Confirmation dialog displays summary:
  - Metadata location (accurate path to `.mediahub/library.json`)
  - Operation type: "Adopt Library"
  - Preview information (baseline scan summary, library ID)
- ✅ Confirmation dialog prominently displays: "No media files will be modified; only .mediahub metadata will be created"
- ✅ Confirmation dialog has "Adopt" button
- ✅ Confirmation dialog has "Cancel" button
- ✅ Information matches preview step

**Pass/Fail**: Confirmation dialog must show accurate information and safety message.

---

#### Check 2.7: Library Adoption Execution
**Setup**: Directory with media files selected, confirmation dialog displayed.

**Steps**:
1. In confirmation dialog, click "Adopt" button
2. Observe execution progress
3. Wait for completion

**Expected Results**:
- ✅ Progress indicator is shown during execution
- ✅ "Adopt" button is disabled during execution
- ✅ Library is adopted successfully
- ✅ Success feedback is displayed
- ✅ Wizard closes automatically
- ✅ Newly adopted library is automatically opened in app

**Pass/Fail**: Library must be adopted successfully and opened automatically.

**Timing**: Total operation must complete within 60 seconds (SC-002).

**Verification**:
- After execution: `ls -la /tmp/mh-wizard-test-adopt/.mediahub/library.json` should show file exists
- Library metadata is valid: `mediahub library status /tmp/mh-wizard-test-adopt` should work
- ✅ Library is compatible with CLI commands (backward compatibility, SC-008)
- ✅ Media files are unchanged: `ls -la /tmp/mh-wizard-test-adopt/2024/01/media1.jpg` should still exist
- ✅ Only metadata was created (no media files modified, SR-008)

---

#### Check 2.8: Idempotent Adoption - Already Adopted Library
**Setup**: Already-adopted library (`/tmp/mh-wizard-test-already-adopted`).

**Steps**:
1. Launch adopt wizard
2. Select `/tmp/mh-wizard-test-already-adopted` folder
3. Proceed through preview and confirmation (if allowed)
4. Click "Adopt" button (or observe idempotent handling)

**Expected Results**:
- ✅ Wizard handles already-adopted library gracefully
- ✅ If execution occurs, it shows success (not error) with idempotent message
- ✅ Library is opened automatically
- ✅ No duplicate metadata is created

**Pass/Fail**: Idempotent behavior must work correctly.

---

### User Story 3: Preview Operations with Dry-Run

#### Check 3.1: Create Preview Shows Accurate Information
**Setup**: Empty directory selected for create wizard.

**Steps**:
1. Complete create wizard preview (from Check 1.3)
2. Note preview information (library ID, metadata location)
3. Cancel wizard (do not create library yet)
4. Launch create wizard again
5. Select same directory
6. Complete preview again
7. Compare preview information

**Expected Results**:
- ✅ Preview shows same library ID for same path (deterministic, DR-001)
- ✅ Preview shows same metadata location for same path
- ✅ Preview information is consistent across multiple previews

**Pass/Fail**: Preview must be deterministic (same inputs produce same preview).

---

#### Check 3.2: Adopt Preview Shows Accurate Baseline Scan
**Setup**: Directory with media files selected for adopt wizard.

**Steps**:
1. Complete adopt wizard preview (from Check 2.3)
2. Note baseline scan summary (file count)
3. Cancel wizard (do not adopt library yet)
4. Launch adopt wizard again
5. Select same directory
6. Complete preview again
7. Compare baseline scan summary

**Expected Results**:
- ✅ Preview shows same baseline scan summary for same directory (deterministic, DR-001)
- ✅ File count matches actual files in directory
- ✅ Preview information is consistent across multiple previews

**Pass/Fail**: Preview must be deterministic and accurate (SC-003).

---

#### Check 3.3: Preview Indicator is Visible
**Setup**: Wizard at preview step (either create or adopt).

**Steps**:
1. Navigate to preview step in wizard
2. Observe preview display

**Expected Results**:
- ✅ "Preview" badge or indicator is prominently displayed
- ✅ Text indicates "This is a preview" or similar
- ✅ User can clearly distinguish preview from actual execution

**Pass/Fail**: Preview indicator must be clearly visible.

---

#### Check 3.4: Preview Accuracy - Create Operation
**Setup**: Empty directory for create wizard.

**Steps**:
1. Complete create wizard preview (from Check 1.3)
2. Note preview information (library ID, metadata location, version)
3. Proceed through confirmation and create library
4. After creation, verify actual library metadata
5. Compare preview information with actual metadata

**Expected Results**:
- ✅ Preview library ID matches actual created library ID (SC-003: 100% accuracy)
- ✅ Preview metadata location matches actual metadata location
- ✅ Preview library version matches actual library version ("1.0")
- ✅ Preview structure matches actual structure

**Pass/Fail**: Preview must match actual execution results with 100% accuracy (SC-003).

---

#### Check 3.5: Preview Accuracy - Adopt Operation
**Setup**: Directory with media files for adopt wizard.

**Steps**:
1. Complete adopt wizard preview (from Check 2.3)
2. Note preview information (baseline scan summary, library ID, metadata location)
3. Proceed through confirmation and adopt library
4. After adoption, verify actual library metadata and baseline scan
5. Compare preview information with actual results

**Expected Results**:
- ✅ Preview baseline scan summary matches actual baseline scan (SC-003: 100% accuracy)
- ✅ Preview library ID matches actual library ID
- ✅ Preview metadata location matches actual metadata location
- ✅ Preview file count matches actual file count

**Pass/Fail**: Preview must match actual execution results with 100% accuracy (SC-003).

---

#### Check 3.6: Zero Writes During Preview - Create
**Setup**: Empty directory for create wizard.

**Steps**:
1. Before preview: Verify directory is empty: `ls -la /tmp/mh-wizard-test-empty/.mediahub/`
2. Complete create wizard preview (from Check 1.3)
3. After preview: Verify directory is still empty: `ls -la /tmp/mh-wizard-test-empty/.mediahub/`
4. Check file system for any `.mediahub` directory creation

**Expected Results**:
- ✅ Before preview: No `.mediahub` directory exists
- ✅ After preview: No `.mediahub` directory exists
- ✅ No files are created during preview (SC-004: zero writes verified)

**Pass/Fail**: Preview must perform zero file system writes (SC-004, SR-001).

---

#### Check 3.7: Zero Writes During Preview - Adopt
**Setup**: Directory with media files for adopt wizard.

**Steps**:
1. Before preview: Verify no library exists: `ls -la /tmp/mh-wizard-test-adopt/.mediahub/`
2. Complete adopt wizard preview (from Check 2.3)
3. After preview: Verify no library exists: `ls -la /tmp/mh-wizard-test-adopt/.mediahub/`
4. Check file system for any `.mediahub` directory creation

**Expected Results**:
- ✅ Before preview: No `.mediahub` directory exists
- ✅ After preview: No `.mediahub` directory exists
- ✅ No files are created during preview (SC-004: zero writes verified, dry-run mode)

**Pass/Fail**: Preview must perform zero file system writes (SC-004, SR-001).

---

### User Story 4: Explicit Confirmation Dialogs

#### Check 4.1: Confirmation Dialog Displays Accurate Summary
**Setup**: Wizard at confirmation step (either create or adopt).

**Steps**:
1. Navigate to confirmation step in wizard
2. Observe confirmation dialog content

**Expected Results**:
- ✅ Confirmation dialog displays metadata location (accurate path)
- ✅ Confirmation dialog displays operation type (Create/Adopt)
- ✅ Confirmation dialog displays preview information:
  - For create: Library ID, version
  - For adopt: Baseline scan summary, library ID
- ✅ Information matches preview step exactly (DR-002: idempotent display)

**Pass/Fail**: Confirmation dialog must show accurate information (SC-005: 100% accuracy).

---

#### Check 4.2: Confirmation Cancel Prevents Execution
**Setup**: Wizard at confirmation step.

**Steps**:
1. Navigate to confirmation step
2. Click "Cancel" button
3. Verify no files were created

**Expected Results**:
- ✅ Wizard closes on cancel
- ✅ No library is created or adopted
- ✅ No files are modified
- ✅ App returns to previous screen

**Pass/Fail**: Cancellation must prevent execution (SR-003).

**Zero Writes Verification**:
- After cancellation: `ls -la /tmp/mh-wizard-test-empty/.mediahub/` should show "No such file or directory"
- ✅ No files created on cancellation

---

#### Check 4.3: Confirmation Proceeds with Execution
**Setup**: Wizard at confirmation step.

**Steps**:
1. Navigate to confirmation step
2. Click "Create" or "Adopt" button
3. Observe execution

**Expected Results**:
- ✅ Wizard proceeds with actual operation
- ✅ Progress indicator is shown
- ✅ Confirmation button is disabled during execution
- ✅ Operation completes successfully

**Pass/Fail**: Confirmation must trigger execution correctly.

---

#### Check 4.4: Progress Indicator During Execution
**Setup**: Wizard at confirmation step, ready to execute.

**Steps**:
1. Navigate to confirmation step
2. Click "Create" or "Adopt" button
3. Observe progress indicator

**Expected Results**:
- ✅ Progress indicator appears immediately when execution starts
- ✅ Progress indicator is visible during entire operation
- ✅ Confirmation button is disabled during execution
- ✅ Progress indicator disappears when operation completes

**Pass/Fail**: Progress indicator must be shown during execution (FR-013).

---

#### Check 4.5: Safety Message for Adoption
**Setup**: Adopt wizard at confirmation step.

**Steps**:
1. Navigate to confirmation step in adopt wizard
2. Observe confirmation dialog

**Expected Results**:
- ✅ Confirmation dialog prominently displays: "No media files will be modified; only .mediahub metadata will be created"
- ✅ Message is clear and visible
- ✅ User can understand that adoption is safe (SR-008)

**Pass/Fail**: Safety message must be displayed prominently (FR-008).

---

### User Story 5: Wizard Navigation and Error Handling

#### Check 5.1: Back Button Navigation
**Setup**: Wizard at preview or confirmation step.

**Steps**:
1. Navigate to preview step (step 2)
2. Verify "Back" button is visible
3. Click "Back" button
4. Navigate to confirmation step (step 3)
5. Verify "Back" button is visible
6. Click "Back" button
7. Verify navigation works correctly

**Expected Results**:
- ✅ "Back" button appears on preview step (step 2)
- ✅ "Back" button appears on confirmation step (step 3)
- ✅ "Back" button does NOT appear on path selection step (step 1)
- ✅ "Back" button returns to previous step correctly
- ✅ Preview and confirmation information updates when navigating back and changing path

**Pass/Fail**: Back button navigation must work correctly.

---

#### Check 5.2: Error Handling - Clear Error Messages
**Setup**: Various error conditions (invalid path, permission denied, etc.).

**Steps**:
1. Test invalid path error (from Check 1.4, 2.5)
2. Test permission denied error (from Check 1.8)
3. Test existing library error (from Check 1.4)
4. Observe error messages

**Expected Results**:
- ✅ All error messages are clear and user-facing (DR-003: deterministic)
- ✅ Error messages are actionable (tell user what to do)
- ✅ Error messages are displayed inline (not blocking alerts)
- ✅ Same error conditions produce same messages (deterministic)

**Pass/Fail**: Error messages must be clear and actionable (SC-006: 100% of error cases).

---

#### Check 5.3: Error Recovery - Retry Without Restart
**Setup**: Error condition encountered in wizard.

**Steps**:
1. Trigger an error (e.g., select invalid path)
2. Observe error message
3. Correct the issue (e.g., select valid path)
4. Verify wizard allows retry

**Expected Results**:
- ✅ Error message is displayed
- ✅ User can correct the issue (e.g., select different path)
- ✅ Wizard allows retry without restarting
- ✅ Wizard proceeds normally after correction

**Pass/Fail**: Error recovery must work without restarting wizard.

---

#### Check 5.4: Cancellation Returns to Previous Screen
**Setup**: Wizard open at any step.

**Steps**:
1. Launch wizard
2. Cancel wizard at any step
3. Observe app state

**Expected Results**:
- ✅ Wizard closes on cancellation
- ✅ App returns to previous screen (library list or empty state)
- ✅ No files are created or modified
- ✅ App state is correct

**Pass/Fail**: Cancellation must return to previous screen correctly.

---

## 4. Error Path Validation

### Error Path 1: Invalid Path Selection
**Setup**: Invalid path (non-existent directory).

**Steps**:
1. Launch wizard (create or adopt)
2. Attempt to select invalid path (non-existent directory)
3. Observe error handling

**Expected Results**:
- ✅ Error message: "Path does not exist" or similar
- ✅ Error message is clear and actionable
- ✅ Wizard prevents proceeding to next step
- ✅ User can select a different path

**Pass/Fail**: Invalid path must be handled gracefully.

---

### Error Path 2: Permission Denied
**Setup**: Read-only directory.

**Steps**:
1. Launch create wizard
2. Select read-only directory (`/tmp/mh-wizard-test-readonly`)
3. Proceed through preview and confirmation
4. Attempt to create library
5. Observe error handling

**Expected Results**:
- ✅ Error message: "Permission denied" or similar
- ✅ Error message is clear and actionable
- ✅ Wizard allows retry (user can select different path)
- ✅ No partial library creation occurred
- ✅ Wizard does not crash

**Pass/Fail**: Permission errors must be handled gracefully (SR-004).

**Cleanup**: Restore permissions: `chmod +w /tmp/mh-wizard-test-readonly`

---

### Error Path 3: Existing Library (Create)
**Setup**: Existing library directory.

**Steps**:
1. Launch create wizard
2. Select existing library directory (`/tmp/mh-wizard-test-existing-lib`)
3. Observe error handling

**Expected Results**:
- ✅ Error message: "This location already contains a MediaHub library" or similar
- ✅ Error message is clear
- ✅ Wizard prevents proceeding
- ✅ User can select a different path

**Pass/Fail**: Existing library must be detected and error displayed.

---

### Error Path 4: Preview Failure
**Setup**: Invalid path or permission error during preview.

**Steps**:
1. Launch wizard
2. Select path that causes preview to fail (e.g., permission denied)
3. Observe preview error handling

**Expected Results**:
- ✅ Error message is displayed in preview step
- ✅ Error message is clear and actionable
- ✅ Confirmation step is disabled
- ✅ User can correct issue and retry

**Pass/Fail**: Preview failures must be handled gracefully.

---

## 5. Determinism Verification

### Determinism Check 1: Preview Determinism
**Setup**: Same directory selected multiple times.

**Steps**:
1. Launch create wizard
2. Select `/tmp/mh-wizard-test-empty`
3. Complete preview, note library ID
4. Cancel wizard
5. Launch create wizard again
6. Select same directory (`/tmp/mh-wizard-test-empty`)
7. Complete preview, note library ID
8. Compare library IDs

**Expected Results**:
- ✅ Same path produces same preview library ID (DR-001: deterministic preview)
- ✅ Same path produces same metadata location
- ✅ Preview is consistent across multiple runs

**Pass/Fail**: Preview must be deterministic (DR-001).

---

### Determinism Check 2: Path Validation
**Setup**: Same path validated multiple times.

**Steps**:
1. Launch wizard
2. Select `/tmp/mh-wizard-test-existing-lib` (existing library)
3. Note validation result (error message)
4. Cancel wizard
5. Launch wizard again
6. Select same path
7. Note validation result
8. Compare validation results

**Expected Results**:
- ✅ Same path produces same validation result (DR-004: deterministic validation)
- ✅ Same error conditions produce same error messages (DR-003: deterministic messages)

**Pass/Fail**: Path validation must be deterministic (DR-004).

---

### Determinism Check 3: Error Message Determinism
**Setup**: Same error condition triggered multiple times.

**Steps**:
1. Trigger same error condition (e.g., invalid path) 3 times
2. Note error message each time
3. Compare error messages

**Expected Results**:
- ✅ Same error condition produces same error message (DR-003: deterministic messages)
- ✅ Error messages are consistent across multiple runs

**Pass/Fail**: Error messages must be deterministic (DR-003).

---

## 6. Safety Guarantees Validation

### Safety Check 1: Zero Writes During Preview
**Setup**: Directory for preview testing.

**Steps**:
1. Before preview: Verify no `.mediahub` directory exists
2. Complete preview (create or adopt wizard)
3. After preview: Verify no `.mediahub` directory exists
4. Check file system for any writes

**Expected Results**:
- ✅ No `.mediahub` directory created during preview
- ✅ No files are created or modified during preview
- ✅ Preview performs zero writes (SR-001, SC-004)

**Pass/Fail**: Preview must perform zero writes (SR-001, SC-004).

**Verification Commands**:
```bash
# Before preview
ls -la /tmp/mh-wizard-test-empty/.mediahub/  # Should show "No such file or directory"

# After preview (before execution)
ls -la /tmp/mh-wizard-test-empty/.mediahub/  # Should still show "No such file or directory"
```

---

### Safety Check 2: No Modifications Until Confirmation
**Setup**: Wizard at preview step.

**Steps**:
1. Complete preview step
2. Verify no files created
3. Navigate back to path selection
4. Verify no files created
5. Cancel wizard
6. Verify no files created

**Expected Results**:
- ✅ No files created during preview
- ✅ No files created when navigating back
- ✅ No files created on cancellation
- ✅ Files are only created after explicit confirmation (SR-003)

**Pass/Fail**: No modifications until explicit confirmation (SR-003).

---

### Safety Check 3: Adoption Does Not Modify Media Files
**Setup**: Directory with media files adopted.

**Steps**:
1. Note media files before adoption: `ls -la /tmp/mh-wizard-test-adopt/2024/01/`
2. Complete adopt wizard and adopt library
3. After adoption: Verify media files unchanged: `ls -la /tmp/mh-wizard-test-adopt/2024/01/`
4. Verify only metadata was created: `ls -la /tmp/mh-wizard-test-adopt/.mediahub/`

**Expected Results**:
- ✅ Media files are unchanged after adoption
- ✅ Only `.mediahub` metadata directory was created
- ✅ No media files were modified, moved, renamed, or deleted (SR-008)

**Pass/Fail**: Adoption must not modify media files (SR-008).

**Verification Commands**:
```bash
# Before adoption
ls -la /tmp/mh-wizard-test-adopt/2024/01/media1.jpg  # Should exist

# After adoption
ls -la /tmp/mh-wizard-test-adopt/2024/01/media1.jpg  # Should still exist, unchanged
ls -la /tmp/mh-wizard-test-adopt/.mediahub/library.json  # Should exist (metadata created)
```

---

### Safety Check 4: Cancellation Performs Zero Writes
**Setup**: Wizard at any step.

**Steps**:
1. Launch wizard and proceed to any step
2. Cancel wizard
3. Verify no files were created

**Expected Results**:
- ✅ No `.mediahub` directory created on cancellation
- ✅ No files are created or modified on cancellation
- ✅ Cancellation performs zero writes (SC-010: 100% of cases)

**Pass/Fail**: Cancellation must perform zero writes (SC-010).

---

## 7. Backward Compatibility Validation

### Compatibility Check 1: Created Library Works with CLI
**Setup**: Library created via wizard.

**Steps**:
1. Create library via wizard (from Check 1.7)
2. Verify library works with CLI commands:
   - `mediahub library status /tmp/mh-wizard-test-empty`
   - `mediahub library list` (should show library)
3. Verify library metadata is valid

**Expected Results**:
- ✅ CLI `library status` command works with wizard-created library
- ✅ CLI `library list` command shows wizard-created library
- ✅ Library metadata follows schema from Slice 1
- ✅ Library is compatible with existing Core APIs (SC-007: 100% compatibility)

**Pass/Fail**: Created library must be compatible with CLI (SC-007).

---

### Compatibility Check 2: Adopted Library Works with CLI
**Setup**: Library adopted via wizard.

**Steps**:
1. Adopt library via wizard (from Check 2.7)
2. Verify library works with CLI commands:
   - `mediahub library status /tmp/mh-wizard-test-adopt`
   - `mediahub library list` (should show library)
3. Verify library metadata is valid

**Expected Results**:
- ✅ CLI `library status` command works with wizard-adopted library
- ✅ CLI `library list` command shows wizard-adopted library
- ✅ Library metadata follows schema from Slice 1
- ✅ Library is compatible with existing Core APIs (SC-008: 100% compatibility)

**Pass/Fail**: Adopted library must be compatible with CLI (SC-008).

---

## 8. Performance Validation

### Performance Check 1: Create Wizard Completion Time
**Setup**: Empty directory for create wizard.

**Steps**:
1. Start stopwatch
2. Launch create wizard
3. Select folder
4. Complete preview
5. Complete confirmation
6. Execute creation
7. Stop stopwatch when library opens

**Expected Results**:
- ✅ Total time is under 30 seconds (SC-001: under 30 seconds for typical operations)
- ✅ Preview completes within 1 second
- ✅ Execution completes within 5 seconds

**Pass/Fail**: Create wizard must complete within 30 seconds (SC-001).

---

### Performance Check 2: Adopt Wizard Completion Time
**Setup**: Directory with media files for adopt wizard.

**Steps**:
1. Start stopwatch
2. Launch adopt wizard
3. Select directory
4. Complete preview (including baseline scan)
5. Complete confirmation
6. Execute adoption
7. Stop stopwatch when library opens

**Expected Results**:
- ✅ Total time is under 60 seconds (SC-002: under 60 seconds for typical operations)
- ✅ Preview (including baseline scan) completes within 5 seconds
- ✅ Execution completes within 10 seconds

**Pass/Fail**: Adopt wizard must complete within 60 seconds (SC-002).

---

## 9. Cleanup After Validation

After completing all validation checks, clean up test fixtures:

```bash
# Remove test libraries and directories
rm -rf /tmp/mh-wizard-test-*

# Restore permissions if needed
chmod +w /tmp/mh-wizard-test-readonly 2>/dev/null || true
```

---

## Validation Summary

**Total Checks**: 40+ validation checks covering:
- User Story 1 (Create Library): 9 checks
- User Story 2 (Adopt Library): 8 checks
- User Story 3 (Preview Operations): 7 checks
- User Story 4 (Confirmation Dialogs): 5 checks
- User Story 5 (Navigation and Error Handling): 4 checks
- Error Path Validation: 4 checks
- Determinism Verification: 3 checks
- Safety Guarantees Validation: 4 checks
- Backward Compatibility Validation: 2 checks
- Performance Validation: 2 checks

**Success Criteria Coverage**:
- ✅ SC-001: Create wizard completion time (Performance Check 1)
- ✅ SC-002: Adopt wizard completion time (Performance Check 2)
- ✅ SC-003: Preview accuracy (Checks 3.4, 3.5)
- ✅ SC-004: Zero writes during preview (Checks 3.6, 3.7, Safety Check 1)
- ✅ SC-005: Confirmation dialog accuracy (Check 4.1)
- ✅ SC-006: Error handling (Check 5.2, Error Path Validation)
- ✅ SC-007: Created library compatibility (Compatibility Check 1)
- ✅ SC-008: Adopted library compatibility (Compatibility Check 2)
- ✅ SC-009: Automatic library opening (Checks 1.7, 2.7)
- ✅ SC-010: Cancellation zero writes (Check 1.9, Safety Check 4)

**All success criteria from spec.md are validated in this runbook.**
