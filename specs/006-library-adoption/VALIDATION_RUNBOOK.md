# Validation Runbook - Library Adoption (Slice 6)

**Feature**: Library Adoption  
**Slice**: 6  
**Date**: 2026-01-13  
**Status**: Ready for Validation

## Overview

This runbook provides step-by-step instructions for validating the Library Adoption feature (Slice 6). All validation tasks (VAL-1 through VAL-6) should be executed to ensure the feature works correctly.

---

## VAL-1: Run All Existing Tests

**Objective**: Ensure no regression in existing functionality

**Steps**:
1. Run all tests:
   ```bash
   cd /Volumes/Photos/_DevTools/MediaHub
   swift test
   ```

**Expected Result**:
- All tests pass (143+ tests)
- No test failures or regressions
- Exit code: 0

**Acceptance Criteria**:
- ✅ All existing MediaHub tests pass
- ✅ All new LibraryAdoption tests pass (33 tests)
- ✅ No test failures or regressions

---

## VAL-2: Manual Testing - Confirmation Prompts

**Objective**: Verify confirmation prompts work correctly in interactive mode

**Prerequisites**:
- Terminal with TTY (interactive mode)
- Test directory with media files

**Steps**:

1. **Test Prompt Appearance**:
   ```bash
   cd /tmp
   mkdir -p test_prompt_lib
   cd test_prompt_lib
   mkdir -p 2024/01
   echo "test photo" > 2024/01/photo.jpg
   
   cd /Volumes/Photos/_DevTools/MediaHub
   swift run mediahub library adopt /tmp/test_prompt_lib
   ```

2. **Verify Prompt Shows**:
   - Prompt appears with:
     - Library path
     - Metadata location
     - Baseline scan summary (file count)
     - "No media files will be modified" message
     - "[yes/no]: " prompt

3. **Test "yes" Response**:
   - Type `yes` and press Enter
   - Verify: Library is adopted, metadata created, exit code 0

4. **Test "y" Response**:
   ```bash
   rm -rf /tmp/test_prompt_lib/.mediahub
   swift run mediahub library adopt /tmp/test_prompt_lib
   ```
   - Type `y` and press Enter
   - Verify: Library is adopted, exit code 0

5. **Test "no" Response**:
   ```bash
   rm -rf /tmp/test_prompt_lib/.mediahub
   swift run mediahub library adopt /tmp/test_prompt_lib
   ```
   - Type `no` and press Enter
   - Verify: "Adoption cancelled." message, exit code 0, no metadata created

6. **Test "n" Response**:
   ```bash
   rm -rf /tmp/test_prompt_lib/.mediahub
   swift run mediahub library adopt /tmp/test_prompt_lib
   ```
   - Type `n` and press Enter
   - Verify: "Adoption cancelled." message, exit code 0, no metadata created

7. **Test Ctrl+C**:
   ```bash
   rm -rf /tmp/test_prompt_lib/.mediahub
   swift run mediahub library adopt /tmp/test_prompt_lib
   ```
   - Press Ctrl+C during prompt
   - Verify: "Adoption cancelled." or "Interrupted: adoption cancelled." message, exit code 0

**Cleanup**:
```bash
rm -rf /tmp/test_prompt_lib
```

**Acceptance Criteria**:
- ✅ Prompt appears correctly with all required information
- ✅ "yes" or "y" proceeds with adoption
- ✅ "no" or "n" cancels with exit code 0
- ✅ Ctrl+C cancels gracefully with exit code 0
- ✅ No metadata created on cancellation

---

## VAL-3: Manual Testing - Non-Interactive Mode

**Objective**: Verify non-interactive mode detection and `--yes` flag requirement

**Prerequisites**:
- Terminal or script environment (non-interactive)

**Steps**:

1. **Test Non-Interactive Mode Detection**:
   ```bash
   cd /tmp
   mkdir -p test_noninteractive_lib
   cd test_noninteractive_lib
   mkdir -p 2024/01
   echo "test photo" > 2024/01/photo.jpg
   
   cd /Volumes/Photos/_DevTools/MediaHub
   echo "y" | swift run mediahub library adopt /tmp/test_noninteractive_lib
   ```

2. **Verify Error Message**:
   - Should show: "Error: Non-interactive mode requires --yes flag. Use --yes to skip confirmation in scripts."
   - Exit code: 1 (failure)
   - No metadata created

3. **Test with --yes Flag**:
   ```bash
   swift run mediahub library adopt /tmp/test_noninteractive_lib --yes
   ```

4. **Verify Success**:
   - Library is adopted without prompt
   - Metadata created
   - Exit code: 0

**Cleanup**:
```bash
rm -rf /tmp/test_noninteractive_lib
```

**Acceptance Criteria**:
- ✅ Non-interactive mode detected correctly
- ✅ Clear error message when `--yes` not provided
- ✅ `--yes` flag bypasses confirmation
- ✅ Adoption succeeds with `--yes` in non-interactive mode

---

## VAL-4: Manual Testing - Dry-Run Preview

**Objective**: Verify dry-run preview matches actual adoption

**Prerequisites**:
- Test directory with media files

**Steps**:

1. **Run Dry-Run**:
   ```bash
   cd /tmp
   mkdir -p test_dryrun_val
   cd test_dryrun_val
   mkdir -p 2024/01
   echo "test photo" > 2024/01/photo.jpg
   echo "test video" > 2024/01/video.mov
   
   cd /Volumes/Photos/_DevTools/MediaHub
   swift run mediahub library adopt /tmp/test_dryrun_val --dry-run
   ```

2. **Verify Dry-Run Output**:
   - Shows "DRY-RUN: Library adoption preview"
   - Shows "Would create:" with metadata preview
   - Shows baseline scan summary (2 files)
   - Shows "No files will be created; this is a preview only."
   - No `.mediahub/` directory created

3. **Run Actual Adoption**:
   ```bash
   swift run mediahub library adopt /tmp/test_dryrun_val --yes
   ```

4. **Compare Results**:
   - Compare dry-run output with actual adoption output
   - Verify: Same baseline scan file count (2 files)
   - Verify: Same metadata structure (rootPath, version)
   - Verify: `.mediahub/` directory now exists

5. **Test JSON Output**:
   ```bash
   rm -rf /tmp/test_dryrun_val/.mediahub
   swift run mediahub library adopt /tmp/test_dryrun_val --dry-run --json
   ```

6. **Verify JSON**:
   - JSON includes `"dryRun": true`
   - JSON includes `metadata` object
   - JSON includes `baselineScan` object with `fileCount` and `filePaths`

**Cleanup**:
```bash
rm -rf /tmp/test_dryrun_val
```

**Acceptance Criteria**:
- ✅ Dry-run shows preview without creating files
- ✅ Dry-run baseline scan matches actual adoption
- ✅ Dry-run metadata structure matches actual adoption
- ✅ JSON output includes `dryRun: true` field
- ✅ No files created in dry-run mode

---

## VAL-5: Smoke Test - End-to-End Adoption

**Objective**: Verify complete adoption workflow

**Prerequisites**:
- Test directory with media files organized in YYYY/MM structure

**Steps**:

1. **Prepare Test Library**:
   ```bash
   cd /tmp
   mkdir -p test_e2e_lib
   cd test_e2e_lib
   mkdir -p 2024/01 2024/02 2023/12
   echo "photo1" > 2024/01/photo1.jpg
   echo "photo2" > 2024/01/photo2.png
   echo "photo3" > 2024/02/photo3.jpg
   echo "photo4" > 2023/12/photo4.heic
   ```

2. **Adopt Library**:
   ```bash
   cd /Volumes/Photos/_DevTools/MediaHub
   swift run mediahub library adopt /tmp/test_e2e_lib --yes
   ```

3. **Verify Metadata Created**:
   ```bash
   test -f /tmp/test_e2e_lib/.mediahub/library.json && echo "OK: Metadata created" || echo "ERROR: Metadata not created"
   ```

4. **Verify Library Can Be Opened**:
   ```bash
   swift run mediahub library open /tmp/test_e2e_lib
   ```
   - Should show library information
   - Should show correct library ID

5. **Verify Baseline Scan**:
   - Check that baseline scan found 4 files
   - Verify all media files still exist at original locations

6. **Test Detection Excludes Existing Files**:
   ```bash
   # Create a source with some duplicate files
   mkdir -p /tmp/test_e2e_source
   cp /tmp/test_e2e_lib/2024/01/photo1.jpg /tmp/test_e2e_source/
   cp /tmp/test_e2e_lib/2024/01/photo2.png /tmp/test_e2e_source/
   echo "new_photo.jpg" > /tmp/test_e2e_source/new_photo.jpg
   
   # Attach source and run detection
   swift run mediahub source attach /tmp/test_e2e_source --library /tmp/test_e2e_lib
   swift run mediahub detect <source-id> --library /tmp/test_e2e_lib
   ```
   - Verify: Existing files (photo1.jpg, photo2.png) are excluded
   - Verify: New file (new_photo.jpg) is detected as new

7. **Test Import**:
   ```bash
   swift run mediahub import <source-id> --all --library /tmp/test_e2e_lib
   ```
   - Verify: Only new file is imported
   - Verify: Existing files are skipped

**Cleanup**:
```bash
rm -rf /tmp/test_e2e_lib /tmp/test_e2e_source
```

**Acceptance Criteria**:
- ✅ Adoption creates metadata successfully
- ✅ Library can be opened after adoption
- ✅ Baseline scan works correctly
- ✅ Detection excludes existing files
- ✅ Import works correctly with adopted library
- ✅ No media files were modified during adoption

---

## VAL-6: Smoke Test - CLI Help and Commands

**Objective**: Verify CLI help and command recognition

**Steps**:

1. **Test Help Command**:
   ```bash
   cd /Volumes/Photos/_DevTools/MediaHub
   swift run mediahub library adopt --help
   ```

2. **Verify Help Output**:
   - Shows command description
   - Shows usage: `mediahub library adopt <path> [--dry-run] [--yes] [--json]`
   - Shows all flags:
     - `--dry-run`: Preview adoption operations without creating metadata
     - `--yes`: Skip confirmation prompt
     - `-j, --json`: Output results in JSON format

3. **Test Command Recognition**:
   ```bash
   swift run mediahub library --help
   ```
   - Verify: `adopt` appears in subcommands list

4. **Test Flag Recognition**:
   ```bash
   cd /tmp
   mkdir -p test_flags_lib
   cd test_flags_lib
   mkdir -p 2024/01
   echo "test" > 2024/01/photo.jpg
   
   cd /Volumes/Photos/_DevTools/MediaHub
   swift run mediahub library adopt /tmp/test_flags_lib --dry-run --json
   ```
   - Verify: Both flags are recognized
   - Verify: Command executes with both flags

5. **Test Invalid Flags**:
   ```bash
   swift run mediahub library adopt /tmp/test_flags_lib --invalid-flag
   ```
   - Verify: Error message about unknown flag

**Cleanup**:
```bash
rm -rf /tmp/test_flags_lib
```

**Acceptance Criteria**:
- ✅ Help command shows correct information
- ✅ Command is recognized in subcommands
- ✅ All flags are recognized and work correctly
- ✅ Invalid flags produce clear error messages

---

## Summary Checklist

After completing all validation tasks, verify:

- [ ] VAL-1: All tests pass (143+ tests)
- [ ] VAL-2: Confirmation prompts work (yes/y, no/n, Ctrl+C)
- [ ] VAL-3: Non-interactive mode requires --yes
- [ ] VAL-4: Dry-run preview matches actual adoption
- [ ] VAL-5: End-to-end workflow works (adopt → open → detect → import)
- [ ] VAL-6: CLI help and commands work correctly

**Status**: ✅ All validation tasks completed

---

## Notes

- All validation tasks should be executed in order
- Clean up test directories after each validation task
- Report any failures or issues found during validation
- Manual testing (VAL-2, VAL-3, VAL-4) requires interactive terminal access
