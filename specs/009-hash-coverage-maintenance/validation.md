# Validation Runbook - Hash Coverage & Maintenance (Slice 9)

**Feature**: Hash Coverage & Maintenance  
**Slice**: 9  
**Specification**: `specs/009-hash-coverage-maintenance/spec.md`  
**Date**: 2026-01-27  
**Status**: Ready for Validation

## Overview

This validation runbook provides step-by-step instructions for validating the Hash Coverage & Maintenance feature (Slice 9). All validation tasks should be executed to ensure the feature meets the specification requirements.

**Success Criteria Mapping**:
- VAL-1 through VAL-3: Functional completeness (SC-1)
- VAL-4 through VAL-6: Safety compliance (SC-2)
- VAL-7 through VAL-8: Determinism (SC-3)
- VAL-9 through VAL-11: Idempotence (SC-4)
- VAL-12: Integration (SC-5)
- VAL-13: Error handling (SC-6)
- VAL-14: Backward compatibility (SC-7)

---

## Preconditions / Test Fixtures

### Test Library Setup

**Objective**: Create test libraries with different baseline index states for comprehensive validation.

**Prerequisites**:
- Clean test directory
- MediaHub CLI built (`swift build`)

**Steps**:

1. **Create test library with v1.0 index (no hashes)**:
   ```bash
   cd /tmp
   mkdir -p test_lib_v10
   cd test_lib_v10
   mkdir -p 2024/01 2024/02
   echo "photo1" > 2024/01/IMG_001.jpg
   echo "photo2" > 2024/01/IMG_002.jpg
   echo "photo3" > 2024/02/IMG_003.jpg
   
   cd /Volumes/Photos/_DevTools/MediaHub
   swift run mediahub library create /tmp/test_lib_v10
   swift run mediahub library adopt /tmp/test_lib_v10
   ```
   - Verify: Library created, baseline index v1.0 (no hash fields)

2. **Create test library with v1.1 index (partial hashes)**:
   ```bash
   cd /tmp
   rm -rf test_lib_v11_partial
   mkdir -p test_lib_v11_partial/2024/01 test_lib_v11_partial/2024/02
   echo "photo1" > test_lib_v11_partial/2024/01/IMG_001.jpg
   echo "photo2" > test_lib_v11_partial/2024/01/IMG_002.jpg
   echo "photo3" > test_lib_v11_partial/2024/02/IMG_003.jpg
   echo "photo4" > test_lib_v11_partial/2024/02/IMG_004.jpg

   cd /Volumes/Photos/_DevTools/MediaHub
   swift run mediahub library create /tmp/test_lib_v11_partial
   swift run mediahub library adopt /tmp/test_lib_v11_partial

   # Ensure the library has a v1.1 baseline index with hashes via an existing workflow.
   # If your project already hashes on import (Slice 8), use your normal import flow here.
   # Otherwise, run Slice 9 after implementation once to populate hashes.

   # Locate the baseline index file path (adjust if your project uses a different location)
   INDEX_PATH="/tmp/test_lib_v11_partial/.mediahub/registry/index.json"

   # Simulate partial coverage by deleting the `hash` field for two entries.
   python3 - <<'PY'
import json
p = "/tmp/test_lib_v11_partial/.mediahub/registry/index.json"
with open(p, "r", encoding="utf-8") as f:
    data = json.load(f)
entries = data.get("entries", [])
# Remove hashes for the last two entries (if present)
for e in entries[-2:]:
    if "hash" in e:
        e["hash"] = None
with open(p, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, sort_keys=True)
PY
   ```
   - Verify: Library has a v1.1 index with partial hash coverage (some entries have hashes, some do not)

3. **Create test library with complete hash coverage**:
   ```bash
   cd /tmp
   mkdir -p test_lib_complete
   cd test_lib_complete
   mkdir -p 2024/01
   echo "photo1" > 2024/01/IMG_001.jpg
   echo "photo2" > 2024/01/IMG_002.jpg
   
   cd /Volumes/Photos/_DevTools/MediaHub
   swift run mediahub library create /tmp/test_lib_complete
   swift run mediahub source attach /tmp/test_lib_complete/2024/01 /tmp/test_lib_complete
   swift run mediahub detect <source-id> --library /tmp/test_lib_complete
   swift run mediahub import <source-id> --all --yes --library /tmp/test_lib_complete
   ```
   - Verify: Library has v1.1 index with 100% hash coverage (all entries have hashes)

4. **Create test library with missing file entry**:
   ```bash
   cd /tmp
   mkdir -p test_lib_missing_file
   cd test_lib_missing_file
   mkdir -p 2024/01
   echo "photo1" > 2024/01/IMG_001.jpg
   echo "photo2" > 2024/01/IMG_002.jpg
   
   cd /Volumes/Photos/_DevTools/MediaHub
   swift run mediahub library create /tmp/test_lib_missing_file
   swift run mediahub library adopt /tmp/test_lib_missing_file
   # Manually add index entry for non-existent file (simulate orphaned entry)
   rm 2024/01/IMG_002.jpg
   ```
   - Verify: Library has index entry referencing missing file

**Expected Result**:
- All test libraries created successfully
- Index states verified (v1.0, v1.1 partial, v1.1 complete, missing file entry)

---

## VAL-1: CLI Contract Validation

**Objective**: Verify command syntax, flags, and help text match specification.

**Spec Reference**: User-Facing CLI Contract (lines 35-77)

**Steps**:

1. **Verify command help text**:
   ```bash
   cd /Volumes/Photos/_DevTools/MediaHub
   swift run mediahub index hash --help
   ```

**Expected Result**:
- Command help displays:
  - `mediahub index hash [--dry-run] [--limit N] [--yes]`
  - Description: "Computes missing content hashes (SHA-256) for media files in the library"
  - `--dry-run`: "Enumerate candidates and statistics only; do not compute hashes. Performs zero writes."
  - `--limit N`: "Process at most N files (useful for incremental operation or testing)"
  - `--yes`: "Bypass confirmation prompt for non-interactive execution"
  - No `--library` flag defined as an index-hash-local flag (uses existing global library resolution)
  - Respects pre-existing global `--json` flag (if present in CLI architecture)
  - Slice-specific flags are present (--dry-run, --limit, --yes). Any global options (e.g., --library, --json) may appear if inherited, but must not be defined as index-hash-local flags.

**Acceptance Criteria**:
- ✅ Help text matches spec exactly
- ✅ Slice-specific flags are present (--dry-run, --limit, --yes); no index-hash-local --library flag is defined.
- ✅ No --library flag defined as index-hash-local
- ✅ Global --json mode is respected (if present)

---

## VAL-2: Exit Codes and Error Conditions

**Objective**: Verify exit codes and error handling match specification.

**Spec Reference**: Exit Codes (lines 67-68), Error Conditions (lines 71-77)

**Steps**:

1. **Test invalid library path**:
   ```bash
   swift run mediahub --library /nonexistent/path index hash
   ```
   - Expected: Error message, exit code 1

2. **Test missing index**:
   ```bash
   cd /tmp
   mkdir -p test_lib_no_index
   cd test_lib_no_index
   mkdir -p .mediahub
   echo '{"libraryId":"test","libraryVersion":"1.0"}' > .mediahub/library.json

   cd /Volumes/Photos/_DevTools/MediaHub
   swift run mediahub --library /tmp/test_lib_no_index index hash
   ```
   - Expected: Error message about missing index, exit code 1

3. **Test invalid index (corrupted)**:
   ```bash
   cd /tmp/test_lib_v10
   echo "invalid json" > .mediahub/registry/index.json

   cd /Volumes/Photos/_DevTools/MediaHub
   swift run mediahub --library /tmp/test_lib_v10 index hash
   ```
   - Expected: Error message about invalid index, exit code 1

4. **Test non-interactive without --yes**:
   ```bash
   echo "" | swift run mediahub --library /tmp/test_lib_v10 index hash
   ```
   - Expected: Error message instructing use of --yes, exit code 1

5. **Test dry-run success**:
   ```bash
   swift run mediahub --library /tmp/test_lib_v10 index hash --dry-run
   ```
   - Expected: Preview output, exit code 0

6. **Test idempotent no-op success**:
   ```bash
   swift run mediahub --library /tmp/test_lib_complete index hash --yes
   ```
   - Expected: "All files already have hash values", exit code 0

**Acceptance Criteria**:
- ✅ Invalid library → exit code 1
- ✅ Missing index → exit code 1
- ✅ Invalid index → exit code 1
- ✅ Non-interactive without --yes → exit code 1
- ✅ Dry-run success → exit code 0
- ✅ Idempotent no-op → exit code 0

---

## VAL-3: Safety - Dry-Run Zero Writes and Zero Hash Computation

**Objective**: Verify dry-run mode performs zero writes and zero hash computation.

**Spec Reference**: Safety - Dry-run mode (line 83)

**Steps**:

1. **Test dry-run on library with missing hashes**:
   ```bash
   cd /tmp/test_lib_v10
   # Capture index file modification time
   INDEX_TIME_BEFORE=$(stat -f %m .mediahub/registry/index.json 2>/dev/null || echo "0")

   cd /Volumes/Photos/_DevTools/MediaHub
   swift run mediahub --library /tmp/test_lib_v10 index hash --dry-run

   # Verify index file not modified
   INDEX_TIME_AFTER=$(stat -f %m /tmp/test_lib_v10/.mediahub/registry/index.json 2>/dev/null || echo "0")
   ```
   - Expected: `INDEX_TIME_BEFORE == INDEX_TIME_AFTER` (index file unchanged)

2. **Verify dry-run output indicates zero hash computation**:
   ```bash
   swift run mediahub --library /tmp/test_lib_v10 index hash --dry-run | grep -i "No hashes will be computed"
   ```
   - Expected: Output contains "No hashes will be computed. No changes will be made to the index."

3. **Verify dry-run enumerates candidates only**:
   ```bash
   swift run mediahub --library /tmp/test_lib_v10 index hash --dry-run
   ```
   - Expected: Output shows "Files to process: N" but no hash computation progress

4. **Verify file existence checks are allowed (metadata-only)**:
   - Dry-run should still validate file existence (metadata check)
   - No file content reads should occur (verified by automated tests with mocks/spies)

**Acceptance Criteria**:
- ✅ Dry-run performs zero writes (index file unchanged)
- ✅ Dry-run performs zero hash computation (no file content reads)
- ✅ Dry-run enumerates candidates and statistics only
- ✅ File existence checks allowed (metadata-only, no content reads)

---

## VAL-4: Safety - Non-Interactive Requires --yes

**Objective**: Verify non-interactive execution requires --yes flag for non-dry-run operations.

**Spec Reference**: Error Conditions - Non-interactive (line 77), Safety - Explicit confirmation (line 86)

**Steps**:

1. **Test non-interactive mode without --yes**:
   ```bash
   echo "" | swift run mediahub --library /tmp/test_lib_v10 index hash 2>&1
   ```
   - Expected: Error message "Non-interactive mode requires --yes flag", exit code 1

2. **Test non-interactive mode with --yes**:
   ```bash
   echo "" | swift run mediahub --library /tmp/test_lib_v10 index hash --yes
   ```
   - Expected: Proceeds without prompt, exit code 0

3. **Test dry-run bypasses non-interactive check**:
   ```bash
   echo "" | swift run mediahub --library /tmp/test_lib_v10 index hash --dry-run
   ```
   - Expected: Proceeds without --yes, exit code 0

**Acceptance Criteria**:
- ✅ Non-interactive without --yes → error, exit code 1
- ✅ Non-interactive with --yes → proceeds, exit code 0
- ✅ Dry-run bypasses non-interactive check

---

## VAL-5: Safety - Atomic Write Behavior

**Objective**: Verify atomic index writes prevent partial state.

**Spec Reference**: Safety - Atomic index updates (line 84), Interruption Safety (lines 90-92)

**Steps**:

1. **Test atomic write on successful completion**:
   ```bash
   cd /tmp/test_lib_v11_partial
   # Backup original index
   cp .mediahub/registry/index.json .mediahub/registry/index.json.backup

   cd /Volumes/Photos/_DevTools/MediaHub
   swift run mediahub --library /tmp/test_lib_v11_partial index hash --yes

   # Verify index is valid JSON and contains updated hashes
   cat /tmp/test_lib_v11_partial/.mediahub/registry/index.json | python3 -m json.tool > /dev/null
   ```
   - Expected: Index is valid JSON, contains all expected hashes

2. **Test write failure handling (simulated)**:
   - Create test with insufficient permissions or disk full scenario
   - Verify: Error message, exit code 1, no partial index file created

3. **Test interruption safety (simulated partial completion)**:
   - Simulate processing N of M files, then stop
   - Re-run command
   - Expected: Re-run processes all files (idempotent, no partial state)

**Acceptance Criteria**:
- ✅ Successful write produces valid index (atomic)
- ✅ Write failure produces error, no partial index
- ✅ Interruption does not leave partial state (re-run works)

---

## VAL-6: Determinism - Stable Candidate Ordering

**Objective**: Verify candidates are processed in deterministic order.

**Spec Reference**: Determinism - Stable file ordering (line 104)

**Steps**:

1. **Test candidate ordering consistency**:
   ```bash
   cd /tmp/test_lib_v10
   # Run command twice, capture output
   cd /Volumes/Photos/_DevTools/MediaHub
   swift run mediahub --library /tmp/test_lib_v10 index hash --dry-run > /tmp/output1.txt
   swift run mediahub --library /tmp/test_lib_v10 index hash --dry-run > /tmp/output2.txt

   # Compare outputs
   diff /tmp/output1.txt /tmp/output2.txt
   ```
   - Expected: Outputs are identical (same candidate order)

2. **Verify ordering is by normalized path**:
   ```bash
   swift run mediahub --library /tmp/test_lib_v10 --json index hash --dry-run | python3 -c "import sys, json; data=json.load(sys.stdin); print('\n'.join(sorted([e.get('path', '') for e in data.get('candidates', [])])))"
   ```
   - Expected: Candidates listed in sorted path order

**Acceptance Criteria**:
- ✅ Same library state produces same candidate order
- ✅ Candidates sorted by normalized path (deterministic)

---

## VAL-7: Determinism - Reproducible Outputs

**Objective**: Verify same inputs produce same outputs (human-readable and JSON).

**Spec Reference**: Determinism - Reproducible output (line 107)

**Steps**:

1. **Test human-readable output determinism**:
   ```bash
   cd /Volumes/Photos/_DevTools/MediaHub
   swift run mediahub --library /tmp/test_lib_v10 index hash --dry-run > /tmp/output1.txt
   swift run mediahub --library /tmp/test_lib_v10 index hash --dry-run > /tmp/output2.txt
   diff /tmp/output1.txt /tmp/output2.txt
   ```
   - Expected: Outputs are identical

2. **Test JSON output determinism**:
   ```bash
   swift run mediahub --library /tmp/test_lib_v10 --json index hash --dry-run > /tmp/json1.json
   swift run mediahub --library /tmp/test_lib_v10 --json index hash --dry-run > /tmp/json2.json
   diff <(python3 -m json.tool /tmp/json1.json) <(python3 -m json.tool /tmp/json2.json)
   ```
   - Expected: JSON outputs are identical (after normalization)

3. **Test output after hash computation**:
   ```bash
   cd /tmp/test_lib_v11_partial
   cp .mediahub/registry/index.json .mediahub/registry/index.json.backup

   cd /Volumes/Photos/_DevTools/MediaHub
   swift run mediahub --library /tmp/test_lib_v11_partial index hash --yes > /tmp/output1.txt

   # Restore and re-run
   cd /tmp/test_lib_v11_partial
   cp .mediahub/registry/index.json.backup .mediahub/registry/index.json

   cd /Volumes/Photos/_DevTools/MediaHub
   swift run mediahub --library /tmp/test_lib_v11_partial index hash --yes > /tmp/output2.txt

   diff /tmp/output1.txt /tmp/output2.txt
   ```
   - Expected: Outputs are identical (same results)

**Acceptance Criteria**:
- ✅ Same inputs produce same human-readable output
- ✅ Same inputs produce same JSON output
- ✅ Deterministic behavior verified across runs

---

## VAL-8: Idempotence - Existing Hashes Never Overwritten

**Objective**: Verify existing hash values are preserved (never overwritten).

**Spec Reference**: Idempotence - No duplicate work (line 111), Safety - Data Integrity (line 97)

**Steps**:

1. **Test hash preservation**:
   ```bash
   cd /tmp/test_lib_v11_partial
   # Capture existing hashes
   python3 -c "import json; data=json.load(open('.mediahub/registry/index.json')); hashes={e['path']:e.get('hash') for e in data['entries'] if e.get('hash')}; print(json.dumps(hashes, indent=2))" > /tmp/hashes_before.json

   cd /Volumes/Photos/_DevTools/MediaHub
   swift run mediahub --library /tmp/test_lib_v11_partial index hash --yes

   # Verify existing hashes unchanged
   cd /tmp/test_lib_v11_partial
   python3 -c "import json; data=json.load(open('.mediahub/registry/index.json')); hashes={e['path']:e.get('hash') for e in data['entries'] if e.get('hash')}; print(json.dumps(hashes, indent=2))" > /tmp/hashes_after.json

   diff /tmp/hashes_before.json /tmp/hashes_after.json
   ```
   - Expected: Existing hashes unchanged (diff shows no changes to existing hash values)

2. **Test complete coverage no-op**:
   ```bash
   cd /tmp/test_lib_complete
   INDEX_TIME_BEFORE=$(stat -f %m .mediahub/registry/index.json)

   cd /Volumes/Photos/_DevTools/MediaHub
   swift run mediahub --library /tmp/test_lib_complete index hash --yes

   INDEX_TIME_AFTER=$(stat -f %m /tmp/test_lib_complete/.mediahub/registry/index.json)
   ```
   - Expected: `INDEX_TIME_BEFORE == INDEX_TIME_AFTER` (no index write), output shows "All files already have hash values"

**Acceptance Criteria**:
- ✅ Existing hash values preserved (never overwritten)
- ✅ Complete coverage produces no-op (no writes, no hash computation)

---

## VAL-9: Idempotence - Re-Run After Completion

**Objective**: Verify re-running after successful completion produces no changes.

**Spec Reference**: Idempotence - Consistent state (line 114)

**Steps**:

1. **Test re-run after successful completion**:
   ```bash
   cd /tmp/test_lib_v10
   # First run
   cd /Volumes/Photos/_DevTools/MediaHub
   swift run mediahub --library /tmp/test_lib_v10 index hash --yes

   # Capture index state
   cp /tmp/test_lib_v10/.mediahub/registry/index.json /tmp/index_after_first.json

   # Second run
   swift run mediahub --library /tmp/test_lib_v10 index hash --yes > /tmp/output_second.txt

   # Compare index states
   diff /tmp/index_after_first.json /tmp/test_lib_v10/.mediahub/registry/index.json
   ```
   - Expected: Index unchanged (diff shows no differences), output shows idempotent no-op

2. **Verify output indicates no changes**:
   ```bash
   grep -i "All files already have hash values" /tmp/output_second.txt
   grep -i "Files processed: 0" /tmp/output_second.txt
   ```
   - Expected: Output indicates no-op (0 files processed, 0 hashes computed)

**Acceptance Criteria**:
- ✅ Re-run after completion produces no index changes
- ✅ Re-run output indicates idempotent no-op

---

## VAL-10: --limit Validation

**Objective**: Verify --limit processes first N candidates in deterministic order.

**Spec Reference**: Flags - --limit (line 50), Behavior - Hash computation (line 60)

**Steps**:

1. **Test --limit with deterministic ordering**:
   ```bash
   cd /Volumes/Photos/_DevTools/MediaHub
   swift run mediahub --library /tmp/test_lib_v10 index hash --dry-run --limit 2
   ```
   - Expected: Output shows "Files to process: 2" (first 2 by sorted path)

2. **Test --limit processing**:
   ```bash
   cd /tmp/test_lib_v10
   cp .mediahub/registry/index.json .mediahub/registry/index.json.backup

   cd /Volumes/Photos/_DevTools/MediaHub
   swift run mediahub --library /tmp/test_lib_v10 index hash --yes --limit 2

   # Verify only 2 hashes computed
   cd /tmp/test_lib_v10
   python3 -c "import json; data=json.load(open('.mediahub/registry/index.json')); print(sum(1 for e in data['entries'] if e.get('hash')))"
   ```
   - Expected: Exactly 2 entries have hashes (first 2 by sorted path)

3. **Test incremental progress with --limit**:
   ```bash
   # First run: process 2 files
   cd /Volumes/Photos/_DevTools/MediaHub
   swift run mediahub --library /tmp/test_lib_v10 index hash --yes --limit 2

   # Second run: process remaining files
   swift run mediahub --library /tmp/test_lib_v10 index hash --yes
   ```
   - Expected: Second run processes remaining files (not already-processed files)

**Acceptance Criteria**:
- ✅ --limit processes first N candidates (by sorted path)
- ✅ Coverage reflects limited processing
- ✅ Incremental progress works (subsequent runs process remaining files)

---

## VAL-11: Output Format Validation - Human-Readable

**Objective**: Verify human-readable output matches specification examples.

**Spec Reference**: Expected Outputs - Human-Readable Output (lines 118-186)

**Steps**:

1. **Test dry-run output format**:
   ```bash
   swift run mediahub --library /tmp/test_lib_v10 index hash --dry-run
   ```
   - Expected: Output contains:
     - "Hash Coverage Preview"
     - "Library: /path/to/library"
     - "Index version: 1.0" or "1.1"
     - "Current coverage: X% (Y / Z entries)"
     - "DRY-RUN: Would compute hashes for N files"
     - "Files to process: N"
     - "No hashes will be computed. No changes will be made to the index."

2. **Test normal mode output format**:
   ```bash
   cd /tmp/test_lib_v11_partial
   cp .mediahub/registry/index.json .mediahub/registry/index.json.backup

   cd /Volumes/Photos/_DevTools/MediaHub
   echo "yes" | swift run mediahub --library /tmp/test_lib_v11_partial index hash
   ```
   - Expected: Output contains:
     - "Hash Coverage Update"
     - "Library: /path/to/library"
     - "Index version: 1.1"
     - "Current coverage: X% (Y / Z entries)"
     - "Will compute hashes for N files."
     - "This will update the baseline index."
     - "Proceed? (yes/no): " (if interactive)
     - Progress indicator (if implemented)
     - "Completed:" section with summary

3. **Test idempotent no-op output format**:
   ```bash
   swift run mediahub --library /tmp/test_lib_complete index hash --yes
   ```
   - Expected: Output contains:
     - "Hash Coverage Update"
     - "Current coverage: 100%"
     - "All files already have hash values."
     - "No computation needed."
     - "Files processed: 0"
     - "Hashes computed: 0"
     - "Coverage unchanged: 100%"

**Acceptance Criteria**:
- ✅ Dry-run output matches spec format
- ✅ Normal mode output matches spec format
- ✅ Idempotent no-op output matches spec format
- ✅ Key fields and sections present

---

## VAL-12: Output Format Validation - JSON

**Objective**: Verify JSON output matches specification examples using pre-existing global JSON mode.

**Spec Reference**: Expected Outputs - JSON Output (lines 188-277)

**Steps**:

1. **Test dry-run JSON output**:
   ```bash
   swift run mediahub --library /tmp/test_lib_v10 --json index hash --dry-run | python3 -m json.tool
   ```
   - Expected: Valid JSON containing:
     - `"dryRun": true`
     - `"library": { "path": "...", "indexVersion": "1.0" or "1.1" }`
     - `"coverage": { "current": { "percentage": ..., "entriesWithHash": ..., "totalEntries": ... } }`
     - `"coverage": { "wouldUpdate": { "filesToProcess": ..., "estimatedNewCoverage": {...} } }`
     - `"summary": { "filesProcessed": 0, "hashesComputed": 0, "indexUpdated": false }`

2. **Test normal mode JSON output**:
   ```bash
   cd /tmp/test_lib_v11_partial
   cp .mediahub/registry/index.json .mediahub/registry/index.json.backup

   cd /Volumes/Photos/_DevTools/MediaHub
   swift run mediahub --library /tmp/test_lib_v11_partial --json index hash --yes | python3 -m json.tool
   ```
   - Expected: Valid JSON containing:
     - `"dryRun": false`
     - `"coverage": { "before": {...}, "after": {...} }`
     - `"summary": { "filesProcessed": ..., "hashesComputed": ..., "indexUpdated": true, "indexPath": "..." }`

3. **Test idempotent no-op JSON output**:
   ```bash
   swift run mediahub --library /tmp/test_lib_complete --json index hash --yes | python3 -m json.tool
   ```
   - Expected: Valid JSON containing:
     - `"dryRun": false`
     - `"coverage": { "before": { "percentage": 1.0, ... }, "after": { "percentage": 1.0, ... } }`
     - `"summary": { "filesProcessed": 0, "hashesComputed": 0, "indexUpdated": false, "reason": "all_files_already_have_hashes" }`

**Acceptance Criteria**:
- ✅ JSON output is valid and parseable
- ✅ JSON structure matches spec examples
- ✅ All required fields present
- ✅ Uses pre-existing global --json flag mode

---

## VAL-13: Status Integration - Hash Coverage Reporting

**Objective**: Verify status command reports hash coverage statistics.

**Spec Reference**: Integration with Status Command (lines 279-315)

**Steps**:

1. **Test status with v1.1 index (hash coverage available)**:
   ```bash
   swift run mediahub status --library /tmp/test_lib_v11_partial
   ```
   - Expected: Output contains:
     - "Hash Coverage: X% (Y / Z entries)"
     - Hash coverage displayed after "Sources:" line

2. **Test status JSON with hash coverage**:
   ```bash
   swift run mediahub status --json --library /tmp/test_lib_v11_partial | python3 -m json.tool
   ```
   - Expected: Valid JSON containing:
     - `"hashCoverage": { "percentage": ..., "entriesWithHash": ..., "totalEntries": ... }`

3. **Test status with v1.0 index (backward compatible)**:
   ```bash
   swift run mediahub status --library /tmp/test_lib_v10
   ```
   - Expected: Existing status output works, no hash coverage displayed (backward compatible)

4. **Test status with missing index (backward compatible)**:
   ```bash
   swift run mediahub status --library /tmp/test_lib_no_index
   ```
   - Expected: Existing status output works, no hash coverage displayed (backward compatible)

**Acceptance Criteria**:
- ✅ Status shows hash coverage when v1.1 index available
- ✅ Status JSON includes hash coverage when available
- ✅ Backward compatible (v1.0 index, missing index → no hash coverage, status still works)

---

## VAL-14: Error Handling - Edge Cases and Failure Modes

**Objective**: Verify all edge cases and failure modes are handled gracefully.

**Spec Reference**: Edge Cases (lines 319-330), Failure Modes (lines 332-339)

**Steps**:

1. **Test empty library**:
   ```bash
   cd /tmp
   mkdir -p test_lib_empty
   cd test_lib_empty
   mkdir -p .mediahub
   echo '{"libraryId":"test","libraryVersion":"1.0"}' > .mediahub/library.json
   echo '{"version":"1.0","created":"2024-01-01T00:00:00Z","lastUpdated":"2024-01-01T00:00:00Z","entryCount":0,"entries":[]}' > .mediahub/registry/index.json

   cd /Volumes/Photos/_DevTools/MediaHub
   swift run mediahub --library /tmp/test_lib_empty index hash --yes
   ```
   - Expected: Reports 0% coverage (0/0), no-op, exit code 0

2. **Test file missing during computation**:
   ```bash
   swift run mediahub --library /tmp/test_lib_missing_file index hash --yes
   ```
   - Expected: Error reported for missing file, continues with remaining files, exit code 0

3. **Test permission denied**:
   ```bash
   cd /tmp/test_lib_v10
   chmod 000 2024/01/IMG_001.jpg

   cd /Volumes/Photos/_DevTools/MediaHub
   swift run mediahub --library /tmp/test_lib_v10 index hash --yes

   # Restore permissions
   chmod 644 /tmp/test_lib_v10/2024/01/IMG_001.jpg
   ```
   - Expected: Error reported for permission-denied file, continues with remaining files

4. **Test index write failure (simulated)**:
   - Create scenario with insufficient disk space or write permissions
   - Expected: Error message, exit code 1, no partial index update

**Acceptance Criteria**:
- ✅ Empty library handled gracefully (0% coverage, no-op)
- ✅ Missing files handled gracefully (error reported, continues)
- ✅ Permission errors handled gracefully (error reported, continues)
- ✅ Write failures handled gracefully (error, exit code 1, no partial state)

---

## VAL-15: Automated Tests

**Objective**: Verify all automated tests pass and cover key scenarios.

**Spec Reference**: Success Criteria (lines 341-349)

**Steps**:

1. **Run all tests**:
   ```bash
   cd /Volumes/Photos/_DevTools/MediaHub
   swift test
   ```

**Expected Result**:
- All tests pass (existing + new Slice 9 tests)
- Exit code: 0

**Key Test Cases to Verify**:

1. **Unit Tests - Candidate Selection**:
   - Test filters entries with `hash == nil`
   - Test deterministic ordering (sorted by normalized path)
   - Test file existence validation
   - Test `--limit` support
   - **Proves**: Determinism (SC-3)

2. **Unit Tests - Hash Computation**:
   - Test hash computation for valid files
   - Test error handling (file missing, permission denied, I/O errors)
   - Test index update preserves existing hashes
   - **Proves**: Safety compliance (SC-2), Idempotence (SC-4)

3. **Unit Tests - Dry-Run Mode**:
   - Test dry-run enumerates candidates without computing hashes
   - Test dry-run performs zero writes
   - Test dry-run output format
   - **Proves**: Safety compliance (SC-2)

4. **Integration Tests - Full Workflow**:
   - Test complete workflow: load index → select candidates → compute hashes → update index
   - Test with `--limit` flag
   - Test with `--yes` flag
   - Test idempotent no-op
   - Test interruption safety (simulated partial completion, re-run idempotence)
   - **Proves**: Functional completeness (SC-1), Idempotence (SC-4)

5. **Integration Tests - Status Command**:
   - Test status command with v1.0 index (backward compatible)
   - Test status command with v1.1 index (hash coverage displayed)
   - Test status command with missing index (backward compatible)
   - **Proves**: Integration (SC-5), Backward compatibility (SC-7)

6. **Edge Case Tests**:
   - Test empty library
   - Test complete coverage
   - Test partial coverage with limit
   - Test file missing during computation
   - Test permission denied
   - Test index write failure
   - **Proves**: Error handling (SC-6)

**Acceptance Criteria**:
- ✅ All unit tests pass
- ✅ All integration tests pass
- ✅ Test coverage includes all key scenarios
- ✅ Tests prove success criteria (SC-1 through SC-7)

---

## Release Readiness Checklist

Before releasing Slice 9, verify all must-pass items:

### Functional Completeness
- [ ] `mediahub index hash` command works end-to-end
- [ ] Command computes missing hashes for existing library media files
- [ ] Command updates baseline index with computed hashes
- [ ] All automated tests pass (`swift test`)

### Safety Compliance
- [ ] Dry-run performs zero writes (index file unchanged)
- [ ] Dry-run performs zero hash computation (no file content reads)
- [ ] Non-interactive non-dry-run requires --yes flag
- [ ] Atomic index writes prevent partial state
- [ ] Existing hash values never overwritten

### Determinism
- [ ] Same library state produces same candidate order
- [ ] Same inputs produce same outputs (human-readable and JSON)
- [ ] Candidates processed in deterministic order (sorted by normalized path)

### Idempotence
- [ ] Re-running on complete coverage produces no changes (no-op)
- [ ] Re-running after successful completion produces no changes
- [ ] Existing hash values preserved (never overwritten)

### Integration
- [ ] Status command shows hash coverage when v1.1 index available
- [ ] Status command JSON includes hash coverage when available
- [ ] Backward compatible (v1.0 index, missing index → status still works)

### Error Handling
- [ ] All error conditions handled gracefully with clear error messages
- [ ] Exit codes correct (0 for success, 1 for errors)
- [ ] Edge cases handled (empty library, missing files, permission errors)

### Output Format
- [ ] Human-readable output matches spec examples
- [ ] JSON output matches spec examples (using pre-existing global --json mode)
- [ ] Output is deterministic (same inputs → same outputs)

### CLI Contract
- [ ] Command help text matches spec
- [ ] Only specified flags present (--dry-run, --limit, --yes)
- [ ] No --library flag defined (uses existing global resolution)
- [ ] Respects pre-existing global --json mode

---

**Validation Status**: ⬜ Not Started | ⬜ In Progress | ⬜ Complete

**Validated By**: _________________  
**Date**: _________________
