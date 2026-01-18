# Slice 16 — UI Hash Maintenance + Coverage

**Document Type**: Slice Validation Runbook  
**Slice Number**: 16  
**Title**: UI Hash Maintenance + Coverage  
**Author**: Spec-Kit Orchestrator  
**Date**: 2026-01-17  
**Status**: Draft

---

## Validation Overview

This runbook provides comprehensive validation for Slice 16 implementation. All checks are runnable and verify the success criteria from spec.md: hash maintenance UI (batch/limit operations), hash coverage insights, and read-only duplicate detection display.

**Slice Status**: P1 complete (20 tasks). Optional polish tasks (T-021, T-022) are P2 and post-freeze.

**Key Validation Principles**:
- Preview operations perform zero hash computation and zero writes (hash maintenance preview)
- Hash maintenance execution only updates index (no media file modifications)
- Duplicate detection is read-only (no file deletions or mutations)
- Explicit confirmation before hash maintenance execution
- Progress/cancellation support works correctly (from Slice 15)
- Deterministic behavior (same input → identical results)
- User-facing error messages (clear and actionable)
- Backward compatibility with existing Core APIs from slices 1-15
- Hash coverage statistics match CLI output semantically (same values, not exact JSON schema)

**Validation Approach**:
- Manual UI testing (macOS SwiftUI app requires visual verification)
- File system verification (check for zero writes during preview; index updates only during execution)
- CLI cross-checks for accuracy (verify UI results match CLI output semantically - same counts and values, not exact formatting)
- Repeatable test scenarios with explicit pass/fail criteria
- Performance observations (informational only, not pass/fail blockers)

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
# Clean up previous test libraries (if any)
rm -rf /tmp/mh-slice16-test-*
```

---

## 2. Test Fixtures

### Fixture Setup Commands

**Create test library with partial hash coverage**:
```bash
# Create a test library
mediahub library create /tmp/mh-slice16-test-lib
# Add some media files (without hashes initially)
mkdir -p /tmp/mh-slice16-test-lib/2024/01
echo "fake image content" > /tmp/mh-slice16-test-lib/2024/01/image1.jpg
echo "fake image content" > /tmp/mh-slice16-test-lib/2024/01/image2.jpg
# Adopt library to create baseline index
mediahub library adopt /tmp/mh-slice16-test-lib --yes
# Verify library has baseline index
ls -la /tmp/mh-slice16-test-lib/.mediahub/registry/index.json
```

**Expected**: Valid MediaHub library at `/tmp/mh-slice16-test-lib` with baseline index but no hashes.

**Create test library with complete hash coverage**:
```bash
# Create a test library
mediahub library create /tmp/mh-slice16-test-lib-complete
# Add some media files
mkdir -p /tmp/mh-slice16-test-lib-complete/2024/01
echo "fake image content" > /tmp/mh-slice16-test-lib-complete/2024/01/image1.jpg
# Adopt library
mediahub library adopt /tmp/mh-slice16-test-lib-complete --yes
# Compute hashes for all files
mediahub index hash /tmp/mh-slice16-test-lib-complete --yes
# Verify hash coverage is 100%
mediahub status /tmp/mh-slice16-test-lib-complete --json | grep -i "hashCoverage"
```

**Expected**: Valid MediaHub library at `/tmp/mh-slice16-test-lib-complete` with 100% hash coverage.

**Create test library with duplicates**:
```bash
# Create a test library
mediahub library create /tmp/mh-slice16-test-lib-duplicates
# Add duplicate files (same content, different paths)
mkdir -p /tmp/mh-slice16-test-lib-duplicates/2024/01
echo "duplicate content" > /tmp/mh-slice16-test-lib-duplicates/2024/01/file1.jpg
echo "duplicate content" > /tmp/mh-slice16-test-lib-duplicates/2024/01/file2.jpg
# Adopt library
mediahub library adopt /tmp/mh-slice16-test-lib-duplicates --yes
# Compute hashes
mediahub index hash /tmp/mh-slice16-test-lib-duplicates --yes
# Verify duplicates exist
mediahub duplicates /tmp/mh-slice16-test-lib-duplicates --format json | grep -i "duplicateGroups"
```

**Expected**: Valid MediaHub library at `/tmp/mh-slice16-test-lib-duplicates` with duplicate files.

**Create test library with missing index**:
```bash
# Create a test library
mediahub library create /tmp/mh-slice16-test-lib-no-index
# Remove index to test graceful degradation
rm -f /tmp/mh-slice16-test-lib-no-index/.mediahub/registry/index.json
# Verify index is missing
ls -la /tmp/mh-slice16-test-lib-no-index/.mediahub/registry/index.json 2>&1 | grep -i "no such file"
```

**Expected**: Valid MediaHub library at `/tmp/mh-slice16-test-lib-no-index` without baseline index.

---

## 3. Success Criteria Validation

### SC-001: Hash Coverage Display

**Requirement**: Library status view displays hash coverage statistics (total entries, entries with hash, entries missing hash, coverage percentage).

**Validation Steps**:
1. Open MediaHubUI app
2. Open test library `/tmp/mh-slice16-test-lib` (partial hash coverage)
3. Navigate to library status view
4. Verify hash coverage statistics are displayed:
   - Hash coverage percentage (e.g., "0% coverage" or "50% coverage")
   - Total entries count
   - Entries with hash count
   - Entries missing hash count
5. Open test library `/tmp/mh-slice16-test-lib-complete` (complete hash coverage)
6. Verify hash coverage shows "100% coverage" or similar positive indicator
7. Open test library `/tmp/mh-slice16-test-lib-no-index` (missing index)
8. Verify hash coverage shows "N/A" or "Not available" (graceful degradation)

**Expected Results**:
- ✅ Hash coverage statistics display correctly when library is opened
- ✅ Statistics match CLI output semantically (same counts and values, not exact formatting)
- ✅ Graceful degradation works when index is missing/invalid (shows "N/A")
- ✅ Statistics update after hash maintenance operations complete

**CLI Cross-Check**:
```bash
# Verify hash coverage from CLI
mediahub status /tmp/mh-slice16-test-lib --json | jq '.hashCoverage'
```

**Pass Criteria**: All expected results pass.

---

### SC-002: Hash Maintenance Preview

**Requirement**: Hash maintenance preview displays candidate files and statistics without computing hashes.

**Validation Steps**:
1. Open MediaHubUI app
2. Open test library `/tmp/mh-slice16-test-lib` (partial hash coverage)
3. Click "Hash Maintenance" or similar action
4. Click "Preview" button in hash maintenance preview view
5. Verify preview displays:
   - Candidate files (files missing hashes) or summary
   - Candidate statistics (total candidates, limit if specified)
   - "Preview" badge/indicator clearly visible
6. Verify "Run Hash Maintenance" button is enabled when preview completes successfully
7. Verify no hash computation occurred (check index modification time before/after preview)
8. Verify preview results match CLI `mediahub index hash --dry-run` output semantically (same counts and values, not exact formatting)

**Expected Results**:
- ✅ Preview shows accurate candidate information
- ✅ Preview is clearly marked as preview (badge/indicator visible)
- ✅ Execution button enables when preview completes
- ✅ Zero hash computation during preview (index modification time unchanged)
- ✅ Preview errors are handled gracefully (clear error messages)

**CLI Cross-Check**:
```bash
# Verify preview results from CLI (semantic comparison: same counts and values, not exact formatting)
mediahub index hash /tmp/mh-slice16-test-lib --dry-run --json | jq '.candidates'
```

**Pass Criteria**: All expected results pass.

---

### SC-003: Hash Maintenance Execution

**Requirement**: Hash maintenance execution computes hashes with progress feedback and cancellation support.

**Validation Steps**:
1. Open MediaHubUI app
2. Open test library `/tmp/mh-slice16-test-lib` (partial hash coverage)
3. Click "Hash Maintenance" or similar action
4. Click "Run Hash Maintenance" button
5. Verify progress bar displays during hash computation:
   - Progress bar shows current/total counts (e.g., "50 of 200 files")
   - Progress updates smoothly (throttled to 1 update/second)
6. Verify cancel button is enabled during operation
7. Click cancel button during hash computation
8. Verify operation stops gracefully:
   - Progress stops updating
   - "Canceling..." feedback is displayed
   - Operation completes with "Operation canceled" message
9. Verify already-computed hashes are preserved in index (no partial state)
10. Run hash maintenance again without canceling
11. Verify hash computation completes successfully:
   - Results display (hashes computed, coverage improved)
   - Hash coverage statistics update in status view

**Expected Results**:
- ✅ Hash computation runs with progress bars
- ✅ Cancel button stops operation gracefully
- ✅ Results update coverage statistics
- ✅ Progress updates smoothly (no flickering)
- ✅ Cancellation preserves already-computed hashes

**CLI Cross-Check**:
```bash
# Verify hash computation results from CLI (semantic comparison: same counts and values, not exact formatting)
mediahub index hash /tmp/mh-slice16-test-lib --yes --json | jq '.hashesComputed'
mediahub status /tmp/mh-slice16-test-lib --json | jq '.hashCoverage'
```

**Pass Criteria**: All expected results pass.

---

### SC-004: Hash Maintenance Batch/Limit Controls

**Requirement**: Hash maintenance UI supports optional limit configuration (process first N files).

**Validation Steps**:
1. Open MediaHubUI app
2. Open test library `/tmp/mh-slice16-test-lib` (partial hash coverage, 200+ candidates)
3. Click "Hash Maintenance" or similar action
4. Configure limit input (e.g., "Process first 100 files")
5. Run hash maintenance with limit
6. Verify only specified number of files are processed:
   - Progress bar shows "Processing first 100 of 200 candidates"
   - Only 100 hashes are computed
7. Verify remaining candidates are still available for processing
8. Run hash maintenance again without limit
9. Verify all remaining candidates are processed

**Expected Results**:
- ✅ Limit configuration works correctly
- ✅ Only specified number of files are processed
- ✅ Remaining candidates are available for incremental processing

**CLI Cross-Check**:
```bash
# Verify limit works from CLI (semantic comparison: same counts and values, not exact formatting)
mediahub index hash /tmp/mh-slice16-test-lib --limit 100 --yes --json | jq '.hashesComputed'
```

**Pass Criteria**: All expected results pass.

---

### SC-005: Duplicate Detection Display

**Requirement**: Duplicate detection displays duplicate groups and file details in read-only view.

**Validation Steps**:
1. Open MediaHubUI app
2. Open test library `/tmp/mh-slice16-test-lib-duplicates` (with duplicates)
3. Click "View Duplicates" or similar action
4. Verify duplicate detection view displays:
   - Duplicate groups (sorted by hash, deterministically)
   - File details within each group (path, size, timestamp, sorted by path)
   - Summary statistics (total groups, total files, potential savings)
5. Verify duplicate groups and files are sorted deterministically:
   - Groups sorted by hash (lexicographically)
   - Files within groups sorted by path (lexicographically)
6. Verify statistics match CLI output semantically (same counts and values, not exact formatting)
7. Open test library `/tmp/mh-slice16-test-lib` (no duplicates)
8. Verify "No duplicates found" message is displayed
9. Verify duplicate detection is read-only (no deletion or merging capabilities visible)

**Expected Results**:
- ✅ Duplicate groups and files are displayed accurately
- ✅ Sorting is deterministic (by hash for groups, by path for files)
- ✅ Statistics match CLI output format
- ✅ Empty state is handled correctly ("No duplicates found")
- ✅ View is read-only (no mutation capabilities)

**CLI Cross-Check**:
```bash
# Verify duplicate detection results from CLI (semantic comparison: same counts and values, not exact formatting)
mediahub duplicates /tmp/mh-slice16-test-lib-duplicates --format json | jq '.summary'
```

**Pass Criteria**: All expected results pass.

---

### SC-006: Progress and Cancellation Integration

**Requirement**: Hash maintenance operations display progress bars and support cancellation (from Slice 15).

**Validation Steps**:
1. Open MediaHubUI app
2. Open test library `/tmp/mh-slice16-test-lib` (partial hash coverage, 200+ candidates)
3. Click "Hash Maintenance" and run hash computation
4. Verify progress bar updates during hash computation:
   - Progress bar shows current/total counts
   - Progress updates smoothly (throttled to 1 update/second)
   - Progress stage/message updates correctly
5. Verify cancel button is enabled during operation
6. Click cancel button
7. Verify cancellation works correctly:
   - Cancel button shows "Canceling..." state
   - Operation stops gracefully
   - "Operation canceled" message is displayed
   - No partial state is left (already-computed hashes preserved)

**Expected Results**:
- ✅ Progress bars update during hash computation
- ✅ Cancel button stops operation gracefully
- ✅ Cancellation feedback is clear ("Canceling..." state)
- ✅ No partial state after cancellation

**Pass Criteria**: All expected results pass.

---

### SC-007: Error Handling

**Requirement**: All operations handle errors gracefully and display user-facing, stable, and actionable error messages.

**Validation Steps**:
1. Open MediaHubUI app
2. Open test library `/tmp/mh-slice16-test-lib-no-index` (missing index)
3. Try to view hash coverage statistics
4. Verify graceful degradation (shows "N/A" or "Not available")
5. Try to run hash maintenance preview
6. Verify error message is displayed (clear, actionable)
7. Try to run hash maintenance execution
8. Verify error message is displayed (clear, actionable)
9. Try to view duplicates
10. Verify error message is displayed (clear, actionable)
11. Open test library with invalid path (non-existent)
12. Verify error messages are user-facing, stable, and actionable

**Expected Results**:
- ✅ Error messages are clear and actionable
- ✅ Graceful degradation works (shows "N/A" when index missing)
- ✅ Error messages are user-facing (not technical stack traces)
- ✅ Error messages are stable (same error → same message)

**Pass Criteria**: All expected results pass.

---

### SC-008: Backward Compatibility

**Requirement**: Existing UI workflows continue to work unchanged. Hash maintenance and duplicate detection are additive features.

**Validation Steps**:
1. Open MediaHubUI app
2. Verify all existing UI workflows continue to work:
   - Library discovery and opening (Slice 11)
   - Library creation/adoption wizards (Slice 12)
   - Source management (Slice 13)
   - Detection workflows (Slice 13)
   - Import workflows (Slice 13)
   - Progress/cancellation UI (Slice 15)
3. Verify hash maintenance and duplicate detection are additive (not required for existing workflows)
4. Verify existing workflows work without hash maintenance/duplicate detection features

**Expected Results**:
- ✅ All existing UI workflows continue to work unchanged
- ✅ Hash maintenance and duplicate detection are additive features
- ✅ No breaking changes to existing workflows

**Pass Criteria**: All expected results pass.

---

## 4. Safety Guarantees Validation

### Safety Check 1: Hash Maintenance Preview Safety

**Requirement**: Preview operations perform zero hash computation and zero writes.

**Validation Steps**:
1. Open MediaHubUI app
2. Open test library `/tmp/mh-slice16-test-lib` (partial hash coverage)
3. Record index modification time before preview:
   ```bash
   stat -f "%Sm" /tmp/mh-slice16-test-lib/.mediahub/registry/index.json
   ```
4. Run hash maintenance preview
5. Record index modification time after preview:
   ```bash
   stat -f "%Sm" /tmp/mh-slice16-test-lib/.mediahub/registry/index.json
   ```
6. Verify index modification time is unchanged (zero writes)

**Expected Results**:
- ✅ Index modification time is unchanged after preview
- ✅ Zero hash computation during preview
- ✅ Zero writes to index during preview

**Pass Criteria**: All expected results pass.

---

### Safety Check 2: Hash Maintenance Execution Safety

**Requirement**: Hash maintenance execution only updates index (no media file modifications).

**Validation Steps**:
1. Open MediaHubUI app
2. Open test library `/tmp/mh-slice16-test-lib` (partial hash coverage)
3. Record media file modification times before execution:
   ```bash
   stat -f "%Sm" /tmp/mh-slice16-test-lib/2024/01/image1.jpg
   stat -f "%Sm" /tmp/mh-slice16-test-lib/2024/01/image2.jpg
   ```
4. Run hash maintenance execution
5. Record media file modification times after execution:
   ```bash
   stat -f "%Sm" /tmp/mh-slice16-test-lib/2024/01/image1.jpg
   stat -f "%Sm" /tmp/mh-slice16-test-lib/2024/01/image2.jpg
   ```
6. Verify media file modification times are unchanged (no media file modifications)
7. Verify index is updated (hashes added to index)

**Expected Results**:
- ✅ Media file modification times are unchanged
- ✅ Index is updated with computed hashes
- ✅ No media files are modified

**Pass Criteria**: All expected results pass.

---

### Safety Check 3: Duplicate Detection Read-Only

**Requirement**: Duplicate detection is read-only (no file deletions or mutations).

**Validation Steps**:
1. Open MediaHubUI app
2. Open test library `/tmp/mh-slice16-test-lib-duplicates` (with duplicates)
3. Record duplicate file paths before duplicate detection:
   ```bash
   ls -la /tmp/mh-slice16-test-lib-duplicates/2024/01/
   ```
4. View duplicates in UI
5. Record duplicate file paths after duplicate detection:
   ```bash
   ls -la /tmp/mh-slice16-test-lib-duplicates/2024/01/
   ```
6. Verify duplicate files are unchanged (no deletions or mutations)
7. Verify no deletion or merging capabilities are visible in UI

**Expected Results**:
- ✅ Duplicate files are unchanged after duplicate detection
- ✅ No deletion or merging capabilities visible in UI
- ✅ Duplicate detection is read-only

**Pass Criteria**: All expected results pass.

---

### Safety Check 4: Explicit Confirmation

**Requirement**: Explicit confirmation required before hash maintenance execution.

**Validation Steps**:
1. Open MediaHubUI app
2. Open test library `/tmp/mh-slice16-test-lib` (partial hash coverage)
3. Click "Hash Maintenance" and proceed to execution
4. Verify confirmation dialog appears before execution:
   - Shows summary of what will be computed
   - Shows explicit "Confirm" and "Cancel" buttons
   - Shows safety messaging ("No media files will be modified")
5. Click "Cancel" in confirmation dialog
6. Verify execution does not proceed (no hash computation)
7. Click "Hash Maintenance" again and confirm
8. Verify execution proceeds only after confirmation

**Expected Results**:
- ✅ Confirmation dialog appears before execution
- ✅ Execution only proceeds if user confirms
- ✅ Safety messaging is clear

**Pass Criteria**: All expected results pass.

---

## 5. Determinism Verification

### Determinism Check 1: Hash Maintenance Determinism

**Requirement**: Hash maintenance operations are deterministic (same library state → same results).

**Validation Steps**:
1. Open MediaHubUI app
2. Open test library `/tmp/mh-slice16-test-lib` (partial hash coverage)
3. Run hash maintenance preview
4. Record preview results (candidate count, statistics)
5. Run hash maintenance preview again
6. Verify preview results are identical (same candidate count, same statistics)
7. Run hash maintenance execution
8. Record execution results (hashes computed, coverage improved)
9. Reset library state (remove computed hashes from index)
10. Run hash maintenance execution again
11. Verify execution results are identical (same hashes computed, same coverage improvement)

**Expected Results**:
- ✅ Preview results are identical across multiple runs
- ✅ Execution results are identical for same library state
- ✅ Hash maintenance is deterministic

**Pass Criteria**: All expected results pass.

---

### Determinism Check 2: Duplicate Detection Determinism

**Requirement**: Duplicate detection results are deterministic (same library state → same results).

**Validation Steps**:
1. Open MediaHubUI app
2. Open test library `/tmp/mh-slice16-test-lib-duplicates` (with duplicates)
3. View duplicates in UI
4. Record duplicate groups (hash, file count, file paths)
5. View duplicates again
6. Verify duplicate groups are identical (same hash, same file count, same file paths)
7. Verify duplicate groups are sorted deterministically (by hash)
8. Verify files within groups are sorted deterministically (by path)

**Expected Results**:
- ✅ Duplicate groups are identical across multiple runs
- ✅ Sorting is deterministic (by hash for groups, by path for files)
- ✅ Duplicate detection is deterministic

**Pass Criteria**: All expected results pass.

---

## 6. Performance Validation

### Performance Check 1: Hash Maintenance Performance

**Requirement**: Hash maintenance operations complete successfully without UI freeze or crash.

**Validation Steps**:
1. Open MediaHubUI app
2. Open test library `/tmp/mh-slice16-test-lib` (partial hash coverage, 200+ candidates)
3. Run hash maintenance execution
4. Observe operation completion (informational: note approximate duration if desired)
5. Verify progress updates are smooth (no UI freezing)
6. Verify UI remains responsive during hash computation

**Expected Results**:
- ✅ Hash maintenance completes successfully without UI freeze or crash
- ✅ Progress updates are smooth (no UI freezing)
- ✅ UI remains responsive during hash computation

**Pass Criteria**: All expected results pass.

---

### Performance Check 2: Duplicate Detection Performance

**Requirement**: Duplicate detection completes successfully without UI freeze or crash.

**Validation Steps**:
1. Open MediaHubUI app
2. Open test library `/tmp/mh-slice16-test-lib-duplicates` (with duplicates)
3. View duplicates in UI
4. Observe operation completion (informational: note approximate duration if desired)
5. Verify UI remains responsive during duplicate detection

**Expected Results**:
- ✅ Duplicate detection completes successfully without UI freeze or crash
- ✅ UI remains responsive during duplicate detection
- ✅ No UI freezing or blocking

**Pass Criteria**: All expected results pass.

---

## 7. Integration Validation

### Integration Check 1: Hash Coverage Statistics Update

**Requirement**: Hash coverage statistics update after hash maintenance operations complete.

**Validation Steps**:
1. Open MediaHubUI app
2. Open test library `/tmp/mh-slice16-test-lib` (partial hash coverage)
3. Record hash coverage statistics before hash maintenance
4. Run hash maintenance execution
5. Verify hash coverage statistics update in status view:
   - Coverage percentage increases
   - Entries with hash count increases
   - Entries missing hash count decreases
6. Verify statistics match CLI output semantically (same counts and values, not exact formatting):
   ```bash
   mediahub status /tmp/mh-slice16-test-lib --json | jq '.hashCoverage'
   ```

**Expected Results**:
- ✅ Hash coverage statistics update after hash maintenance operations
- ✅ Statistics match CLI output semantically (same counts and values, not exact formatting)

**Pass Criteria**: All expected results pass.

---

### Integration Check 2: UI Workflow Integration

**Requirement**: Hash maintenance and duplicate detection workflows are accessible from main library interface.

**Validation Steps**:
1. Open MediaHubUI app
2. Open test library `/tmp/mh-slice16-test-lib` (partial hash coverage)
3. Verify hash maintenance entry points are accessible from library view:
   - "Hash Maintenance" button or menu item visible
   - Preview and execution workflows accessible
4. Verify duplicate detection entry point is accessible from library view:
   - "View Duplicates" button or menu item visible
   - Duplicate detection workflow accessible
5. Verify all workflows work end-to-end from library view

**Expected Results**:
- ✅ Hash maintenance workflows are accessible from library view
- ✅ Duplicate detection workflow is accessible from library view
- ✅ All workflows work end-to-end

**Pass Criteria**: All expected results pass.

---

## 8. Error Path Validation

### Error Check 1: Missing Index Handling

**Requirement**: Graceful degradation when baseline index is missing or invalid.

**Validation Steps**:
1. Open MediaHubUI app
2. Open test library `/tmp/mh-slice16-test-lib-no-index` (missing index)
3. Verify hash coverage statistics show "N/A" or "Not available"
4. Try to run hash maintenance preview
5. Verify error message is displayed (clear, actionable)
6. Try to run hash maintenance execution
7. Verify error message is displayed (clear, actionable)
8. Try to view duplicates
9. Verify error message is displayed (clear, actionable)

**Expected Results**:
- ✅ Graceful degradation works when index is missing/invalid
- ✅ Error messages are clear and actionable
- ✅ No crashes or unhandled errors

**Pass Criteria**: All expected results pass.

---

### Error Check 2: Permission Errors

**Requirement**: Permission errors are handled gracefully.

**Validation Steps**:
1. Create test library with restricted permissions (if possible):
   ```bash
   chmod 000 /tmp/mh-slice16-test-lib/.mediahub/registry/index.json
   ```
2. Open MediaHubUI app
3. Try to run hash maintenance operations
4. Verify error message is displayed (clear, actionable)
5. Restore permissions:
   ```bash
   chmod 644 /tmp/mh-slice16-test-lib/.mediahub/registry/index.json
   ```

**Expected Results**:
- ✅ Permission errors are handled gracefully
- ✅ Error messages are clear and actionable
- ✅ No crashes or unhandled errors

**Pass Criteria**: All expected results pass.

---

## 9. Summary

### Validation Checklist

- [ ] SC-001: Hash Coverage Display
- [ ] SC-002: Hash Maintenance Preview
- [ ] SC-003: Hash Maintenance Execution
- [ ] SC-004: Hash Maintenance Batch/Limit Controls
- [ ] SC-005: Duplicate Detection Display
- [ ] SC-006: Progress and Cancellation Integration
- [ ] SC-007: Error Handling
- [ ] SC-008: Backward Compatibility
- [ ] Safety Check 1: Hash Maintenance Preview Safety
- [ ] Safety Check 2: Hash Maintenance Execution Safety
- [ ] Safety Check 3: Duplicate Detection Read-Only
- [ ] Safety Check 4: Explicit Confirmation
- [ ] Determinism Check 1: Hash Maintenance Determinism
- [ ] Determinism Check 2: Duplicate Detection Determinism
- [ ] Performance Check 1: Hash Maintenance Performance (informational only, not pass/fail blocker)
- [ ] Performance Check 2: Duplicate Detection Performance (informational only, not pass/fail blocker)
- [ ] Integration Check 1: Hash Coverage Statistics Update
- [ ] Integration Check 2: UI Workflow Integration
- [ ] Error Check 1: Missing Index Handling
- [ ] Error Check 2: Permission Errors

### Pass Criteria

All checks must pass for slice validation to be considered complete. If any check fails, document the failure and fix before proceeding.

### Notes

- Manual UI testing is required (macOS SwiftUI app)
- CLI cross-checks verify accuracy (UI results match CLI output semantically - same counts and values, not exact formatting)
- Performance observations are informational only (not pass/fail blockers)
- Error scenarios may require manual setup (permission restrictions, etc.)

---

**Validation Status**: Pending (awaiting implementation)
