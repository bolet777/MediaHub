# Slice 13 — UI Sources + Detect + Import (P1)

**Document Type**: Slice Validation Runbook  
**Slice Number**: 13  
**Title**: UI Sources + Detect + Import (P1)  
**Author**: Spec-Kit Orchestrator  
**Date**: 2026-01-27  
**Status**: Frozen

**Note**: Slice validated without optional post-freeze UI integration tasks (T-029, T-030, T-031). These tasks have been moved to Slice 13b (optional UX polish).

---

## Validation Overview

This runbook provides comprehensive validation for Slice 13 implementation. All checks are runnable and verify the success criteria from spec.md: source management (attach/detach with media types), detection preview/run, and import preview/confirm/run workflows.

**Slice Status**: P1 complete (28 tasks). Optional UI integration tasks (T-029, T-030, T-031) moved to Slice 13b.

**Key Validation Principles**:
- Preview operations perform zero filesystem writes (detection preview, import preview)
- Detection preview does not update source metadata (lastDetectedAt timestamp)
- Import preview does not copy files or modify library contents
- Explicit confirmation before import execution
- Deterministic behavior (same input → identical results)
- User-facing error messages (clear and actionable)
- Backward compatibility with existing Core APIs from slices 1-12
- Source/detection/import results match CLI output semantically (same values, not exact JSON schema)

**Validation Approach**:
- Manual UI testing (macOS SwiftUI app requires visual verification)
- File system verification (check for zero writes during import preview; detection preview updates metadata but shows transparency)
- CLI cross-checks for accuracy (verify UI results match CLI output)
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
- Inline error text: displayed in UI (error messages)
- System Console.app: For system-level errors (if needed)

### Cleanup Before Validation
```bash
# Clean up previous test libraries and sources (if any)
rm -rf /tmp/mh-slice13-test-*
```

---

## 2. Test Fixtures

### Fixture Setup Commands

**Create test library for source management testing**:
```bash
# Create a test library
mediahub library create /tmp/mh-slice13-test-lib
# Verify library was created
ls -la /tmp/mh-slice13-test-lib/.mediahub/library.json
```

**Expected**: Valid MediaHub library at `/tmp/mh-slice13-test-lib`.

**Create test source directory with media files**:
```bash
# Create source directory with media files
mkdir -p /tmp/mh-slice13-test-source
echo "fake image content" > /tmp/mh-slice13-test-source/image1.jpg
echo "fake image content" > /tmp/mh-slice13-test-source/image2.jpg
echo "fake video content" > /tmp/mh-slice13-test-source/video1.mov
# Verify files exist
ls -la /tmp/mh-slice13-test-source/
```

**Expected**: Directory with media files at `/tmp/mh-slice13-test-source`.

**Create test source directory with images only**:
```bash
# Create source directory with images only
mkdir -p /tmp/mh-slice13-test-source-images
echo "fake image content" > /tmp/mh-slice13-test-source-images/img1.jpg
echo "fake image content" > /tmp/mh-slice13-test-source-images/img2.png
# Verify files exist
ls -la /tmp/mh-slice13-test-source-images/
```

**Expected**: Directory with image files only at `/tmp/mh-slice13-test-source-images`.

**Create test source directory with videos only**:
```bash
# Create source directory with videos only
mkdir -p /tmp/mh-slice13-test-source-videos
echo "fake video content" > /tmp/mh-slice13-test-source-videos/vid1.mov
echo "fake video content" > /tmp/mh-slice13-test-source-videos/vid2.mp4
# Verify files exist
ls -la /tmp/mh-slice13-test-source-videos/
```

**Expected**: Directory with video files only at `/tmp/mh-slice13-test-source-videos`.

**Create large test source for performance testing (1000+ items)**:
```bash
# Create source directory with many files (simulated)
mkdir -p /tmp/mh-slice13-test-source-large
for i in {1..1000}; do
  echo "fake content $i" > /tmp/mh-slice13-test-source-large/file$i.jpg
done
# Verify file count
ls -1 /tmp/mh-slice13-test-source-large/ | wc -l
```

**Expected**: Directory with 1000 files at `/tmp/mh-slice13-test-source-large`.

**Create invalid path (non-existent directory) for error testing**:
```bash
# Ensure path doesn't exist
rm -rf /tmp/mh-slice13-test-invalid-path
# Path will be used in UI but doesn't exist
```

**Expected**: Path `/tmp/mh-slice13-test-invalid-path` does not exist.

**Create read-only directory (for permission error testing)**:
```bash
# Create directory and remove write permissions
mkdir -p /tmp/mh-slice13-test-readonly
chmod -w /tmp/mh-slice13-test-readonly
# Verify permissions
ls -ld /tmp/mh-slice13-test-readonly
```

**Expected**: Directory at `/tmp/mh-slice13-test-readonly` without write permissions.

**Note**: After testing, restore permissions: `chmod +w /tmp/mh-slice13-test-readonly`

**Attach source via CLI for testing**:
```bash
# Attach source to test library
mediahub source attach /tmp/mh-slice13-test-source --library /tmp/mh-slice13-test-lib --media-types both
# Verify source was attached
mediahub source list --library /tmp/mh-slice13-test-lib --json
```

**Expected**: Source attached to library, visible in `source list` output.

---

## 3. Validation Checklist

### User Story 1: Attach Source with Media Types

#### Check 1.1: Attach Source Action Opens Interface
**Setup**: Test library created (`/tmp/mh-slice13-test-lib`).

**Steps**:
1. Build app: `swift build`
2. Run app: `swift run MediaHubUI`
3. Open library: `/tmp/mh-slice13-test-lib`
4. Locate "Attach Source" button or action
5. Click "Attach Source" action

**Expected Results**:
- ✅ Attach source interface opens (sheet or modal)
- ✅ Interface shows folder picker
- ✅ Interface shows media type selection (images, videos, both)
- ✅ Interface has "Cancel" button visible

**Pass/Fail**: All items must pass. Interface must open within 1 second.

**Determinism**: Repeat click "Attach Source" 3 times. Interface should open consistently each time.

---

#### Check 1.2: Folder Picker Opens and Selects Folder
**Setup**: Test source directory created (`/tmp/mh-slice13-test-source`).

**Steps**:
1. Launch app (if not already running)
2. Open library: `/tmp/mh-slice13-test-lib`
3. Click "Attach Source" action
4. In interface, click folder picker button
5. In folder picker dialog, navigate to `/tmp`
6. Select `/tmp/mh-slice13-test-source` folder
7. Click "Open" to confirm selection

**Expected Results**:
- ✅ Folder picker dialog opens
- ✅ Dialog allows directory selection only (not files)
- ✅ `/tmp/mh-slice13-test-source` folder can be selected
- ✅ Dialog closes after selection
- ✅ Selected path is displayed in interface
- ✅ Media type selection is enabled

**Pass/Fail**: Folder picker must work correctly and path must be displayed.

---

#### Check 1.3: Media Type Selection Works
**Setup**: Test source directory created (`/tmp/mh-slice13-test-source`).

**Steps**:
1. Launch app and open library: `/tmp/mh-slice13-test-lib`
2. Click "Attach Source" action
3. Select folder: `/tmp/mh-slice13-test-source`
4. Select media type: "Images"
5. Verify selection is stored
6. Change selection to "Videos"
7. Verify selection is stored
8. Change selection to "Both"
9. Verify selection is stored

**Expected Results**:
- ✅ Media type selection UI is visible (segmented control or picker)
- ✅ All three options are available: "Images", "Videos", "Both"
- ✅ Selection can be changed
- ✅ Selection is stored in state
- ✅ Default selection is "Both"

**Pass/Fail**: Media type selection must work correctly for all three options.

---

#### Check 1.4: Source Attachment Executes Successfully
**Setup**: Test library and source directory created.

**Steps**:
1. Launch app and open library: `/tmp/mh-slice13-test-lib`
2. Click "Attach Source" action
3. Select folder: `/tmp/mh-slice13-test-source`
4. Select media type: "Both"
5. Click "Attach" button
6. Wait for attachment to complete
7. Verify source appears in source list

**Expected Results**:
- ✅ "Attach" button is enabled when path and media type are selected
- ✅ Progress indicator shows during attachment
- ✅ Attachment completes within 2 seconds (SC-001)
- ✅ Source appears in source list with correct path
- ✅ Source shows media types as "both" (or "images, videos")
- ✅ Success feedback is displayed (if applicable)

**Pass/Fail**: Source attachment must complete successfully and source must appear in list.

**CLI Cross-Check**:
```bash
# Verify source was attached via CLI
mediahub source list --library /tmp/mh-slice13-test-lib --json
```
**Expected**: Source appears in CLI output with correct path and media types.

---

#### Check 1.5: Source Attachment Error Handling
**Setup**: Test library created, invalid path prepared.

**Steps**:
1. Launch app and open library: `/tmp/mh-slice13-test-lib`
2. Click "Attach Source" action
3. Try to select invalid path: `/tmp/mh-slice13-test-invalid-path`
4. Verify error message is displayed
5. Try to attach already-attached source: `/tmp/mh-slice13-test-source` (if already attached)
6. Verify error message is displayed

**Expected Results**:
- ✅ Invalid path shows clear error message: "The selected path does not exist. Please select a valid folder."
- ✅ Already-attached source shows clear error message: "This source is already attached to the library."
- ✅ Error messages are user-facing and actionable
- ✅ User can correct path and retry

**Pass/Fail**: All error conditions must show clear, user-facing error messages (SC-010).

---

### User Story 2: Detach Source

#### Check 2.1: Detach Source Action Opens Confirmation Dialog
**Setup**: Test library with attached source.

**Steps**:
1. Launch app and open library: `/tmp/mh-slice13-test-lib`
2. Verify source is visible in source list
3. Click "Detach Source" action for a source
4. Verify confirmation dialog opens

**Expected Results**:
- ✅ Confirmation dialog opens (sheet or alert)
- ✅ Dialog shows source information (path, media types)
- ✅ Dialog shows clear message: "Are you sure you want to detach this source?"
- ✅ Dialog has "Detach" button (primary action)
- ✅ Dialog has "Cancel" button (secondary action)

**Pass/Fail**: Confirmation dialog must open and display source information correctly.

---

#### Check 2.2: Source Detachment Executes Successfully
**Setup**: Test library with attached source.

**Steps**:
1. Launch app and open library: `/tmp/mh-slice13-test-lib`
2. Click "Detach Source" for a source
3. In confirmation dialog, click "Detach" button
4. Wait for detachment to complete
5. Verify source is removed from source list

**Expected Results**:
- ✅ Progress indicator shows during detachment
- ✅ Detachment completes within 1 second (SC-002)
- ✅ Source is removed from source list
- ✅ Success feedback is displayed (if applicable)

**Pass/Fail**: Source detachment must complete successfully and source must be removed from list.

**CLI Cross-Check**:
```bash
# Verify source was detached via CLI
mediahub source list --library /tmp/mh-slice13-test-lib --json
```
**Expected**: Source no longer appears in CLI output.

---

#### Check 2.3: Source Detachment Cancellation Works
**Setup**: Test library with attached source.

**Steps**:
1. Launch app and open library: `/tmp/mh-slice13-test-lib`
2. Click "Detach Source" for a source
3. In confirmation dialog, click "Cancel" button
4. Verify source remains in source list

**Expected Results**:
- ✅ Dialog closes when "Cancel" is clicked
- ✅ Source remains attached (still visible in source list)
- ✅ No changes are made to library

**Pass/Fail**: Cancellation must work correctly and source must remain attached.

---

### User Story 3: Detect Preview

#### Check 3.1: Detection Preview Action Executes
**Setup**: Test library with attached source containing media files.

**Steps**:
1. Launch app and open library: `/tmp/mh-slice13-test-lib`
2. Verify source is visible in source list
3. Click "Preview Detection" action for a source
4. Wait for preview to complete
5. Verify preview results are displayed

**Expected Results**:
- ✅ Progress indicator shows during preview
- ✅ Preview completes within 10 seconds for sources with up to 1000 items (SC-003)
- ✅ Preview results are displayed (new items, duplicates, statistics)
- ✅ "Preview" badge/indicator is visible
- ✅ "Run Detection" button is enabled

**Pass/Fail**: Detection preview must complete and display results correctly.

---

#### Check 3.2: Detection Preview Updates Metadata (Transparency)
**Setup**: Test library with attached source, note current lastDetectedAt timestamp.

**Steps**:
1. Launch app and open library: `/tmp/mh-slice13-test-lib`
2. Note current lastDetectedAt timestamp for source (or "Never" if never detected)
3. Click "Preview Detection" for source
4. Wait for preview to complete
5. Verify lastDetectedAt timestamp IS updated (Core API constraint)
6. Verify UI shows transparency note that preview updated metadata

**Expected Results**:
- ✅ Preview completes successfully
- ✅ Source metadata (lastDetectedAt) IS updated (Core API constraint, acceptable for preview)
- ✅ Source list shows updated lastDetectedAt timestamp (transparency)
- ✅ Preview view shows note: "Preview has updated detection timestamp"
- ✅ Preview results are displayed correctly

**Pass/Fail**: Detection preview updates metadata (Core API constraint), but UI shows transparency note.

**CLI Cross-Check**:
```bash
# Check source metadata before and after preview
mediahub source list --library /tmp/mh-slice13-test-lib --json
# Compare lastDetectedAt timestamp (will be updated, which is acceptable)
```
**Expected**: lastDetectedAt timestamp is updated after preview (Core API behavior, acceptable).

---

#### Check 3.3: Detection Preview Results Match CLI Output
**Setup**: Test library with attached source.

**Steps**:
1. Launch app and open library: `/tmp/mh-slice13-test-lib`
2. Click "Preview Detection" for a source
3. Wait for preview to complete
4. Note preview results (new items count, known items count, etc.)
5. Run CLI detection for same source:
```bash
mediahub detect <source-id> --library /tmp/mh-slice13-test-lib --json
```
6. Compare UI preview results with CLI output

**Expected Results**:
- ✅ Preview results match CLI `detect --json` output semantically (same values, not exact JSON schema) (SC-008)
- ✅ New items count matches
- ✅ Known items count matches
- ✅ Duplicates count matches (if available)
- ✅ Detection statistics match

**Pass/Fail**: Preview results must match CLI output exactly (SC-008).

---

### User Story 4: Run Detection

#### Check 4.1: Detection Run Action Executes
**Setup**: Test library with attached source.

**Steps**:
1. Launch app and open library: `/tmp/mh-slice13-test-lib`
2. Click "Run Detection" for a source (after preview or directly)
3. Wait for detection to complete
4. Verify detection results are displayed

**Expected Results**:
- ✅ Progress indicator shows during detection
- ✅ Detection completes within 10 seconds for sources with up to 1000 items (SC-004)
- ✅ Detection results are displayed (new items, duplicates, statistics)
- ✅ Source metadata (lastDetectedAt) is updated
- ✅ "Preview Import" button is enabled (if new items detected)

**Pass/Fail**: Detection run must complete and display results correctly.

---

#### Check 4.2: Detection Run Updates Source Metadata
**Setup**: Test library with attached source.

**Steps**:
1. Launch app and open library: `/tmp/mh-slice13-test-lib`
2. Note current lastDetectedAt timestamp for source (or "Never" if never detected)
3. Click "Run Detection" for source
4. Wait for detection to complete
5. Verify lastDetectedAt timestamp is updated

**Expected Results**:
- ✅ Detection completes successfully
- ✅ Source metadata (lastDetectedAt) is updated with current timestamp
- ✅ Source list shows updated lastDetectedAt timestamp
- ✅ Detection results are displayed correctly

**Pass/Fail**: Detection run must update source metadata correctly.

**CLI Cross-Check**:
```bash
# Check source metadata after detection run
mediahub source list --library /tmp/mh-slice13-test-lib --json
# Verify lastDetectedAt timestamp is updated
```
**Expected**: lastDetectedAt timestamp is updated after detection run.

---

#### Check 4.3: Detection Run Results Match CLI Output
**Setup**: Test library with attached source.

**Steps**:
1. Launch app and open library: `/tmp/mh-slice13-test-lib`
2. Click "Run Detection" for a source
3. Wait for detection to complete
4. Note detection results
5. Run CLI detection for same source:
```bash
mediahub detect <source-id> --library /tmp/mh-slice13-test-lib --json
```
6. Compare UI detection results with CLI output

**Expected Results**:
- ✅ Detection results match CLI `detect --json` output semantically (same values, not exact JSON schema) (SC-008)
- ✅ New items count matches
- ✅ Known items count matches
- ✅ Duplicates count matches (if available)
- ✅ Detection statistics match

**Pass/Fail**: Detection run results must match CLI output exactly (SC-008).

---

### User Story 5: Import Preview

#### Check 5.1: Import Preview Action Executes
**Setup**: Test library with detection results (new items detected).

**Steps**:
1. Launch app and open library: `/tmp/mh-slice13-test-lib`
2. Run detection for a source (or use existing detection results)
3. Click "Preview Import" action for detection results
4. Wait for preview to complete
5. Verify preview results are displayed

**Expected Results**:
- ✅ Progress indicator shows during preview
- ✅ Preview completes within 5 seconds for detection results with up to 100 items (SC-005)
- ✅ Preview results are displayed (items to copy, destination paths)
- ✅ "Preview" badge/indicator is visible
- ✅ "Confirm Import" button is enabled

**Pass/Fail**: Import preview must complete and display results correctly.

---

#### Check 5.2: Import Preview Does Not Copy Files
**Setup**: Test library with detection results.

**Steps**:
1. Launch app and open library: `/tmp/mh-slice13-test-lib`
2. Note current library contents (file count, directory structure)
3. Run detection and click "Preview Import"
4. Wait for preview to complete
5. Verify library contents have NOT changed

**Expected Results**:
- ✅ Preview completes successfully
- ✅ No files are copied to library (SR-003)
- ✅ Library directory structure is unchanged
- ✅ File count in library is unchanged
- ✅ Preview results are displayed correctly

**Pass/Fail**: Import preview must NOT copy files or modify library contents (SC-011, determinism).

**File System Verification**:
```bash
# Check library contents before and after preview
find /tmp/mh-slice13-test-lib -type f | wc -l
# Should be unchanged after preview
```
**Expected**: File count is unchanged after preview.

---

#### Check 5.3: Import Preview Results Match CLI Output
**Setup**: Test library with detection results.

**Steps**:
1. Launch app and open library: `/tmp/mh-slice13-test-lib`
2. Run detection and click "Preview Import"
3. Wait for preview to complete
4. Note preview results (items to import, total size, etc.)
5. Run CLI import preview for same detection result:
```bash
mediahub import <source-id> --all --library /tmp/mh-slice13-test-lib --dry-run --json
```
6. Compare UI preview results with CLI output

**Expected Results**:
- ✅ Preview results match CLI `import --dry-run --json` output semantically (same values, not exact JSON schema) (SC-009)
- ✅ Items to import count matches
- ✅ Total size matches (if available)
- ✅ Destination paths match

**Pass/Fail**: Import preview results must match CLI output exactly (SC-009).

---

### User Story 6: Confirm and Run Import

#### Check 6.1: Import Confirmation Dialog Opens
**Setup**: Test library with import preview results.

**Steps**:
1. Launch app and open library: `/tmp/mh-slice13-test-lib`
2. Run detection and click "Preview Import"
3. Wait for preview to complete
4. Click "Confirm Import" button
5. Verify confirmation dialog opens

**Expected Results**:
- ✅ Confirmation dialog opens (sheet or alert)
- ✅ Dialog shows summary (item count, total size, destination summary)
- ✅ Dialog shows clear message: "Are you sure you want to import these items?"
- ✅ Dialog has "Import" button (primary action)
- ✅ Dialog has "Cancel" button (secondary action)

**Pass/Fail**: Confirmation dialog must open and display summary correctly.

---

#### Check 6.2: Import Execution Executes Successfully
**Setup**: Test library with import preview results.

**Steps**:
1. Launch app and open library: `/tmp/mh-slice13-test-lib`
2. Run detection and click "Preview Import"
3. Wait for preview to complete
4. Click "Confirm Import" and confirm in dialog
5. Wait for import to complete
6. Verify import results are displayed

**Expected Results**:
- ✅ Progress indicator shows during import
- ✅ Import completes within 30 seconds for imports with up to 100 items (SC-006, actual file copy time depends on file sizes)
- ✅ Import results are displayed (successful imports, failures, collisions)
- ✅ Files are copied to library
- ✅ Library status is updated

**Pass/Fail**: Import execution must complete successfully and files must be copied.

**File System Verification**:
```bash
# Check library contents after import
find /tmp/mh-slice13-test-lib -type f | wc -l
# Should have increased by number of imported items
```
**Expected**: File count increases after import.

---

#### Check 6.3: Import Execution Results Match CLI Output
**Setup**: Test library with detection results.

**Steps**:
1. Launch app and open library: `/tmp/mh-slice13-test-lib`
2. Run detection and execute import
3. Note import results
4. Run CLI import for same detection result:
```bash
mediahub import <source-id> --all --library /tmp/mh-slice13-test-lib --json
```
5. Compare UI import results with CLI output

**Expected Results**:
- ✅ Import results match CLI `import --json` output semantically (same values, not exact JSON schema)
- ✅ Successful imports count matches
- ✅ Failed imports count matches (if any)
- ✅ Collisions count matches (if any)

**Pass/Fail**: Import execution results must match CLI output semantically (SC-007 pattern).

---

#### Check 6.4: Import Execution Cancellation Works
**Setup**: Test library with import preview results.

**Steps**:
1. Launch app and open library: `/tmp/mh-slice13-test-lib`
2. Run detection and click "Preview Import"
3. Wait for preview to complete
4. Click "Confirm Import" and cancel in dialog
5. Verify no files are copied

**Expected Results**:
- ✅ Dialog closes when "Cancel" is clicked
- ✅ No files are copied to library
- ✅ Library contents are unchanged
- ✅ Import is cancelled cleanly

**Pass/Fail**: Cancellation must work correctly and no files must be copied.

---

### User Story 7: Source List Display

#### Check 7.1: Source List Displays Attached Sources
**Setup**: Test library with attached sources.

**Steps**:
1. Launch app and open library: `/tmp/mh-slice13-test-lib`
2. Verify source list is visible in library view
3. Verify all attached sources are displayed

**Expected Results**:
- ✅ Source list is visible in library view
- ✅ All attached sources are displayed
- ✅ Each source shows:
  - Source path
  - Media types (images, videos, both)
  - Last detection timestamp (or "Never" if nil)
- ✅ Empty state is shown when no sources attached

**Pass/Fail**: Source list must display all attached sources correctly.

---

#### Check 7.2: Source List Matches CLI Output
**Setup**: Test library with attached sources.

**Steps**:
1. Launch app and open library: `/tmp/mh-slice13-test-lib`
2. Note source list information (paths, media types, last detection timestamps)
3. Run CLI source list:
```bash
mediahub source list --library /tmp/mh-slice13-test-lib --json
```
4. Compare UI source list with CLI output

**Expected Results**:
- ✅ Source list matches CLI `source list --json` output semantically (same values, not exact JSON schema) (SC-007)
- ✅ Source paths match
- ✅ Media types match
- ✅ Last detection timestamps match (or "Never" matches nil)

**Pass/Fail**: Source list must match CLI output semantically (same values, not exact JSON schema) (SC-007).

---

#### Check 7.3: Source List Handles Never-Detected Sources
**Setup**: Test library with attached source that has never been detected.

**Steps**:
1. Launch app and open library: `/tmp/mh-slice13-test-lib`
2. Attach a new source (if needed)
3. Verify source appears in list
4. Verify last detection timestamp shows "Never" or appropriate indicator

**Expected Results**:
- ✅ Source appears in list
- ✅ Last detection timestamp shows "Never" or appropriate indicator (BC-004)
- ✅ Source information is displayed correctly

**Pass/Fail**: Never-detected sources must be displayed correctly with "Never" indicator.

---

## 4. Success Criteria Validation

### SC-001: Source Attachment Performance
**Check**: Source attachment completes within 2 seconds.

**Steps**:
1. Launch app and open library
2. Click "Attach Source"
3. Select valid source path and media types
4. Start timer when "Attach" button is clicked
5. Stop timer when attachment completes
6. Verify time is ≤ 2 seconds

**Expected Results**:
- ✅ Attachment completes within 2 seconds for valid source paths

**Pass/Fail**: Must complete within 2 seconds.

---

### SC-002: Source Detachment Performance
**Check**: Source detachment completes within 1 second.

**Steps**:
1. Launch app and open library with attached source
2. Click "Detach Source"
3. Start timer when "Detach" button is clicked in confirmation dialog
4. Stop timer when detachment completes
5. Verify time is ≤ 1 second

**Expected Results**:
- ✅ Detachment completes within 1 second

**Pass/Fail**: Must complete within 1 second.

---

### SC-003: Detection Preview Performance
**Check**: Detection preview completes within 10 seconds for sources with up to 1000 items.

**Steps**:
1. Launch app and open library
2. Attach large source (1000+ items): `/tmp/mh-slice13-test-source-large`
3. Click "Preview Detection"
4. Start timer when preview starts
5. Stop timer when preview completes
6. Verify time is ≤ 10 seconds

**Expected Results**:
- ✅ Preview completes within 10 seconds for sources with up to 1000 items

**Pass/Fail**: Must complete within 10 seconds.

---

### SC-004: Detection Run Performance
**Check**: Detection run completes within 10 seconds for sources with up to 1000 items.

**Steps**:
1. Launch app and open library
2. Attach large source (1000+ items)
3. Click "Run Detection"
4. Start timer when detection starts
5. Stop timer when detection completes
6. Verify time is ≤ 10 seconds

**Expected Results**:
- ✅ Detection run completes within 10 seconds for sources with up to 1000 items

**Pass/Fail**: Must complete within 10 seconds.

---

### SC-005: Import Preview Performance
**Check**: Import preview completes within 5 seconds for detection results with up to 100 items.

**Steps**:
1. Launch app and open library
2. Run detection (ensure 100 or fewer new items)
3. Click "Preview Import"
4. Start timer when preview starts
5. Stop timer when preview completes
6. Verify time is ≤ 5 seconds

**Expected Results**:
- ✅ Preview completes within 5 seconds for detection results with up to 100 items

**Pass/Fail**: Must complete within 5 seconds.

---

### SC-006: Import Execution Performance
**Check**: Import execution completes within 30 seconds for imports with up to 100 items.

**Steps**:
1. Launch app and open library
2. Run detection (ensure 100 or fewer new items)
3. Execute import
4. Start timer when import starts
5. Stop timer when import completes
6. Verify time is ≤ 30 seconds (actual file copy time depends on file sizes)

**Expected Results**:
- ✅ Import execution completes within 30 seconds for imports with up to 100 items (actual file copy time depends on file sizes)

**Pass/Fail**: Must complete within 30 seconds (file copy time may vary).

---

### SC-007: Source List Accuracy
**Check**: Source list matches CLI output semantically.

**Steps**:
1. Launch app and open library
2. Note source list information
3. Run CLI: `mediahub source list --library <path> --json`
4. Compare UI source list with CLI JSON output
5. Verify semantic match (same values, not exact JSON schema)

**Expected Results**:
- ✅ Source list matches CLI output semantically (same values, not exact JSON schema) for same library state

**Pass/Fail**: Must match CLI output semantically (same values, not exact JSON schema).

---

### SC-008: Detection Results Accuracy
**Check**: Detection results match CLI output semantically.

**Steps**:
1. Launch app and open library
2. Run detection for a source
3. Note detection results
4. Run CLI: `mediahub detect <source-id> --library <path> --json`
5. Compare UI detection results with CLI JSON output
6. Verify semantic match (same values, not exact JSON schema)

**Expected Results**:
- ✅ Detection results match CLI output semantically (same values, not exact JSON schema) for same source state

**Pass/Fail**: Must match CLI output semantically (same values, not exact JSON schema).

---

### SC-009: Import Preview Accuracy
**Check**: Import preview results match CLI output semantically.

**Steps**:
1. Launch app and open library
2. Run detection and preview import
3. Note import preview results
4. Run CLI: `mediahub import <source-id> --all --library <path> --dry-run --json`
5. Compare UI import preview with CLI JSON output
6. Verify semantic match (same values, not exact JSON schema)

**Expected Results**:
- ✅ Import preview results match CLI output semantically (same values, not exact JSON schema) for same detection result

**Pass/Fail**: Must match CLI output semantically (same values, not exact JSON schema).

---

### SC-010: Error Handling Coverage
**Check**: All error conditions show clear error messages.

**Steps**:
1. Test all error scenarios:
   - Invalid source path (doesn't exist)
   - Source already attached
   - Permission denied
   - Source inaccessible
   - Library invalid
   - Invalid detection result
2. Verify each error shows clear, user-facing error message
3. Verify error messages are actionable

**Expected Results**:
- ✅ All error conditions show clear, user-facing error messages
- ✅ Error messages are actionable (tell user what went wrong and what to do)

**Pass/Fail**: All error conditions must show clear error messages (100% coverage).

---

### SC-011: Determinism Verification
**Check**: Same source state produces same detection/import results.

**Steps**:
1. Launch app and open library
2. Run detection for a source
3. Note detection results (new items count, known items count, etc.)
4. Run detection again for same source (without changing source contents)
5. Compare results
6. Repeat for import preview and execution

**Expected Results**:
- ✅ Same source state produces identical detection results
- ✅ Same detection result produces identical import preview results
- ✅ Same detection result produces identical import execution results (deterministic file organization)

**Pass/Fail**: Results must be deterministic (same input → same output).

---

## 5. Safety Guarantees Validation

### Check 5.1: Detection Preview Transparency
**Setup**: Test library with attached source.

**Steps**:
1. Note current library state (file count, metadata files)
2. Run detection preview
3. Verify detection result file is created (Core API behavior)
4. Verify source metadata (lastDetectedAt) IS updated (Core API constraint)
5. Verify UI shows transparency note about metadata update

**Expected Results**:
- ✅ Detection result file is created (Core API behavior, acceptable)
- ✅ Source metadata (lastDetectedAt) IS updated (Core API constraint, acceptable for preview)
- ✅ UI shows transparency note: "Preview has updated detection timestamp"
- ✅ Preview results are accurate and can be used to decide on detection run

**Pass/Fail**: Detection preview updates metadata (Core API constraint), but UI shows transparency and results are accurate.

---

### Check 5.2: Import Preview Zero Writes
**Setup**: Test library with detection results.

**Steps**:
1. Note current library state (file count, directory structure)
2. Run import preview
3. Verify no files are copied
4. Verify library contents are unchanged

**Expected Results**:
- ✅ No files are copied to library during preview (SR-003)
- ✅ Library directory structure is unchanged
- ✅ Library metadata files are unchanged

**Pass/Fail**: Import preview must perform zero filesystem writes.

---

### Check 5.3: Import Execution Requires Confirmation
**Setup**: Test library with import preview results.

**Steps**:
1. Run detection and preview import
2. Verify "Confirm Import" button is visible
3. Verify confirmation dialog appears before execution
4. Verify import does not execute without confirmation

**Expected Results**:
- ✅ Import execution requires explicit user confirmation (SR-004)
- ✅ Confirmation dialog shows summary of what will be imported
- ✅ Import does not execute if user cancels

**Pass/Fail**: Import execution must require explicit confirmation.

---

## 6. Backward Compatibility Validation

### Check 6.1: Libraries from Previous Slices Work
**Setup**: Libraries created/adopted by slices 1-12.

**Steps**:
1. Open library created by slice 1-12
2. Verify library opens correctly
3. Verify source management works
4. Verify detection works
5. Verify import works

**Expected Results**:
- ✅ Libraries from slices 1-12 open correctly (BC-001)
- ✅ All workflows work with existing libraries

**Pass/Fail**: Must work with libraries from previous slices.

---

### Check 6.2: Sources Without Media Types Work
**Setup**: Library with source attached before Slice 10 (no media types).

**Steps**:
1. Open library with source that has no media types field
2. Verify source appears in source list
3. Verify source shows default media types (both)
4. Verify detection works correctly
5. Verify import works correctly

**Expected Results**:
- ✅ Sources without media types default to "both" behavior (BC-002)
- ✅ All workflows work with sources without media types

**Pass/Fail**: Must handle sources without media types correctly.

---

### Check 6.3: Libraries Without Baseline Index Work
**Setup**: Library without baseline index (created before Slice 7).

**Steps**:
1. Open library without baseline index
2. Verify detection works (falls back to full scan)
3. Verify import works correctly

**Expected Results**:
- ✅ Detection falls back to full scan when baseline index is missing (BC-003)
- ✅ All workflows work with libraries without baseline index

**Pass/Fail**: Must handle libraries without baseline index correctly.

---

## 7. Summary

### Validation Completion Checklist

- [ ] All User Story checks pass (7 user stories, multiple checks each)
- [ ] All Success Criteria validated (SC-001 through SC-011)
- [ ] All Safety Guarantees validated (SR-001 through SR-004)
- [ ] All Backward Compatibility checks pass (BC-001 through BC-004)
- [ ] Performance targets met (SC-001 through SC-006)
- [ ] Accuracy targets met (SC-007 through SC-009)
- [ ] Error handling complete (SC-010)
- [ ] Determinism verified (SC-011)

### Known Limitations

- Performance measurements may vary based on system load and file sizes
- Large result sets (1000+ items) may require lazy loading or pagination for optimal UI performance
- Import execution time depends on actual file sizes and disk I/O speed

### Next Steps After Validation

- If all checks pass: Slice 13 is ready for freeze
- If any checks fail: Address failures and re-validate
- Performance issues: Consider optimizations in future slices
- Accuracy issues: Fix Core API integration or error mapping

---

**Validation Status**: Draft  
**Last Updated**: 2026-01-27  
**Next Review**: After implementation completion
