# Validation Runbook - Source Media Types + Library Statistics (Slice 10)

**Feature**: Source Media Types + Library Statistics  
**Slice**: 10  
**Specification**: `specs/010-source-media-types-library-statistics/spec.md`  
**Date**: 2026-01-27  
**Status**: Ready for Validation

## Overview

This validation runbook provides step-by-step instructions for validating the Source Media Types + Library Statistics feature (Slice 10). All validation tasks should be executed to ensure the feature meets the specification requirements.

**Success Criteria Mapping**:
- VAL-1 through VAL-8: Acceptance Scenarios 1-8 (functional completeness)
- VAL-9 through VAL-12: Validation Checks (year extraction, JSON conventions, classification source of truth, invalid values)
- VAL-13: Edge Cases and Invariants
- VAL-14: Automated Test Suite Coverage

**Important Notes**:
- **Media File Creation**: This validation uses `sips` (macOS) and `ffmpeg` to create valid media files. If these tools are unavailable, create valid JPEG/PNG/MOV/MP4 files manually or use sample files. Invalid file content may cause validation failures if the pipeline validates content (not just extensions).
- **File Paths**: The following paths are used in this validation (verify they match actual implementation):
  - Source associations: `.mediahub/sources/associations.json`
  - Baseline index: `.mediahub/registry/index.json`
  - If paths differ in your implementation, adjust commands accordingly.

---

## Preconditions / Test Fixtures

### Test Library Setup

**Objective**: Create test libraries with different states for comprehensive validation.

**Prerequisites**:
- Clean test directory
- MediaHub CLI built (`swift build`)
- `sips` command available (macOS, for creating valid JPEG files)
- `ffmpeg` command available (optional, for creating valid video files; or use sample video files)

**Steps**:

1. **Create test library with BaselineIndex (for statistics validation)**:
   ```bash
   cd /tmp
   rm -rf test_lib_with_index
   mkdir -p test_lib_with_index/2024/01 test_lib_with_index/2024/02 test_lib_with_index/2023/12
   # Create valid test image files using sips (macOS) - creates valid JPEG files
   # If sips unavailable, create valid JPEG files manually or use sample files
   sips -s format jpeg --out test_lib_with_index/2024/01/IMG_001.jpg /System/Library/CoreServices/DefaultDesktop.heic 2>/dev/null
   sips -s format jpeg --out test_lib_with_index/2024/01/IMG_002.jpg /System/Library/CoreServices/DefaultDesktop.heic 2>/dev/null
   sips -s format jpeg --out test_lib_with_index/2024/02/IMG_003.jpg /System/Library/CoreServices/DefaultDesktop.heic 2>/dev/null
   # Create valid test video files using ffmpeg - creates minimal valid MOV files
   # If ffmpeg unavailable, create valid MOV/MP4 files manually or use sample files
   ffmpeg -f lavfi -i testsrc=duration=1:size=320x240:rate=1 -t 1 -y test_lib_with_index/2024/01/VID_001.mov 2>/dev/null
   ffmpeg -f lavfi -i testsrc=duration=1:size=320x240:rate=1 -t 1 -y test_lib_with_index/2023/12/VID_002.mov 2>/dev/null
   
   cd /Volumes/Photos/_DevTools/MediaHub
   swift run mediahub library create /tmp/test_lib_with_index
   swift run mediahub library adopt /tmp/test_lib_with_index --yes
   ```
   - Verify: Library created with BaselineIndex containing entries (images and videos across multiple years)
   - **Note**: If `sips` or `ffmpeg` are unavailable, create valid media files manually or use sample files. Invalid file content may cause validation failures if the pipeline validates content (not just extensions).

2. **Create test library without BaselineIndex (for statistics unavailable validation)**:
   ```bash
   cd /tmp
   rm -rf test_lib_no_index
   mkdir -p test_lib_no_index
   
   cd /Volumes/Photos/_DevTools/MediaHub
   swift run mediahub library create /tmp/test_lib_no_index
   # Do NOT run library adopt (no BaselineIndex created)
   ```
   - Verify: Library created without BaselineIndex (`.mediahub/registry/index.json` does not exist)
   - **Note**: Verify path `.mediahub/registry/index.json` matches actual implementation

3. **Create test library with existing Source (for backward compatibility validation)**:
   ```bash
   cd /tmp
   rm -rf test_lib_existing_source
   mkdir -p test_lib_existing_source
   mkdir -p test_source_mixed
   # Create valid test files (if sips/ffmpeg unavailable, create valid files manually)
   sips -s format jpeg --out test_source_mixed/IMG_001.jpg /System/Library/CoreServices/DefaultDesktop.heic 2>/dev/null
   ffmpeg -f lavfi -i testsrc=duration=1:size=320x240:rate=1 -t 1 -y test_source_mixed/VID_001.mov 2>/dev/null
   
   cd /Volumes/Photos/_DevTools/MediaHub
   swift run mediahub library create /tmp/test_lib_existing_source
   swift run mediahub source attach /tmp/test_source_mixed --library /tmp/test_lib_existing_source
   # Verify association file exists and does NOT contain mediaTypes field (pre-Slice 10)
   # Path: .mediahub/sources/associations.json
   ```
   - Verify: Library has Source attached before Slice 10 (association file without `mediaTypes` field)

4. **Create test source directories with specific media types**:
   ```bash
   cd /tmp
   rm -rf test_source_images test_source_videos test_source_mixed
   
   # Images-only source (create valid JPEG/PNG files using sips)
   mkdir -p test_source_images
   sips -s format jpeg --out test_source_images/IMG_001.jpg /System/Library/CoreServices/DefaultDesktop.heic 2>/dev/null
   sips -s format jpeg --out test_source_images/IMG_002.jpg /System/Library/CoreServices/DefaultDesktop.heic 2>/dev/null
   sips -s format png --out test_source_images/IMG_003.png /System/Library/CoreServices/DefaultDesktop.heic 2>/dev/null
   
   # Videos-only source (create valid video files using ffmpeg)
   mkdir -p test_source_videos
   ffmpeg -f lavfi -i testsrc=duration=1:size=320x240:rate=1 -t 1 -y test_source_videos/VID_001.mov 2>/dev/null
   ffmpeg -f lavfi -i testsrc=duration=1:size=320x240:rate=1 -t 1 -y test_source_videos/VID_002.mp4 2>/dev/null
   
   # Mixed source
   mkdir -p test_source_mixed
   sips -s format jpeg --out test_source_mixed/IMG_001.jpg /System/Library/CoreServices/DefaultDesktop.heic 2>/dev/null
   ffmpeg -f lavfi -i testsrc=duration=1:size=320x240:rate=1 -t 1 -y test_source_mixed/VID_001.mov 2>/dev/null
   ```
   - Verify: Test source directories created with valid media files
   - **Note**: If `sips` or `ffmpeg` are unavailable, create valid media files manually or use sample files. Invalid file content may cause validation failures if the pipeline validates content (not just extensions).

**Expected Result**:
- All test libraries and sources created successfully
- Test fixtures ready for validation scenarios

---

## VAL-1: Acceptance Scenario 1 - Attach Source with Images-Only Filter

**Objective**: Verify Source attachment with `--media-types images` filter works correctly.

**Spec Reference**: Acceptance Scenario 1 (lines 380-388)

**Preconditions**:
- Test library exists at `/tmp/test_lib_scenario1`
- Test source directory `/tmp/test_source_images` exists (images only)

**Steps**:

1. **Attach source with images-only filter**:
   ```bash
   cd /Volumes/Photos/_DevTools/MediaHub
   swift run mediahub library create /tmp/test_lib_scenario1
   swift run mediahub source attach /tmp/test_source_images --media-types images --library /tmp/test_lib_scenario1
   ```
   - **Expected**: Command succeeds (exit code 0)
   - **Expected**: Output shows "Source attached successfully"

2. **Verify mediaTypes in association storage**:
   ```bash
   # Path: .mediahub/sources/associations.json (verify path matches actual implementation)
   cat /tmp/test_lib_scenario1/.mediahub/sources/associations.json | python3 -m json.tool
   ```
   - **Expected**: JSON contains `"mediaTypes": "images"` for the attached source
   - **Note**: Verify path `.mediahub/sources/associations.json` matches actual implementation

3. **Run detection and verify only images detected**:
   ```bash
   swift run mediahub detect --library /tmp/test_lib_scenario1
   ```
   - **Expected**: Detection results show only image files (no video files)
   - **Expected**: Detection count matches number of image files in source

4. **Run import and verify only images imported**:
   ```bash
   swift run mediahub import --all --yes --library /tmp/test_lib_scenario1
   ```
   - **Expected**: Import succeeds
   - **Expected**: Only image files imported to library (verify library contains only image files)

**Validation**:
- ✅ Source attached successfully
- ✅ `mediaTypes: "images"` stored in association file
- ✅ Detection returns only image files
- ✅ Import processes only image files

---

## VAL-2: Acceptance Scenario 2 - Attach Source with Videos-Only Filter

**Objective**: Verify Source attachment with `--media-types videos` filter works correctly.

**Spec Reference**: Acceptance Scenario 2 (lines 390-398)

**Preconditions**:
- Test library exists at `/tmp/test_lib_scenario2`
- Test source directory `/tmp/test_source_videos` exists (videos only)

**Steps**:

1. **Attach source with videos-only filter**:
   ```bash
   cd /Volumes/Photos/_DevTools/MediaHub
   swift run mediahub library create /tmp/test_lib_scenario2
   swift run mediahub source attach /tmp/test_source_videos --media-types videos --library /tmp/test_lib_scenario2
   ```
   - **Expected**: Command succeeds (exit code 0)

2. **Verify mediaTypes in association storage**:
   ```bash
   # Path: .mediahub/sources/associations.json
   cat /tmp/test_lib_scenario2/.mediahub/sources/associations.json | python3 -m json.tool
   ```
   - **Expected**: JSON contains `"mediaTypes": "videos"` for the attached source

3. **Run detection and verify only videos detected**:
   ```bash
   swift run mediahub detect --library /tmp/test_lib_scenario2
   ```
   - **Expected**: Detection results show only video files (no image files)

4. **Run import and verify only videos imported**:
   ```bash
   swift run mediahub import --all --yes --library /tmp/test_lib_scenario2
   ```
   - **Expected**: Only video files imported to library

**Validation**:
- ✅ Source attached successfully
- ✅ `mediaTypes: "videos"` stored in association file
- ✅ Detection returns only video files
- ✅ Import processes only video files

---

## VAL-3: Acceptance Scenario 3 - Attach Source with Default (Both) Filter

**Objective**: Verify Source attachment without `--media-types` flag defaults to "both".

**Spec Reference**: Acceptance Scenario 3 (lines 400-408)

**Preconditions**:
- Test library exists at `/tmp/test_lib_scenario3`
- Test source directory `/tmp/test_source_mixed` exists (images and videos)

**Steps**:

1. **Attach source without --media-types flag**:
   ```bash
   cd /Volumes/Photos/_DevTools/MediaHub
   swift run mediahub library create /tmp/test_lib_scenario3
   swift run mediahub source attach /tmp/test_source_mixed --library /tmp/test_lib_scenario3
   ```
   - **Expected**: Command succeeds (exit code 0)

2. **Verify mediaTypes defaults to "both"**:
   ```bash
   # Path: .mediahub/sources/associations.json
   cat /tmp/test_lib_scenario3/.mediahub/sources/associations.json | python3 -m json.tool
   ```
   - **Expected**: JSON contains `"mediaTypes": "both"` OR field is absent (both cases default to "both" behavior)

3. **Run detection and verify both types detected**:
   ```bash
   swift run mediahub detect --library /tmp/test_lib_scenario3
   ```
   - **Expected**: Detection results show both image and video files

4. **Run import and verify both types imported**:
   ```bash
   swift run mediahub import --all --yes --library /tmp/test_lib_scenario3
   ```
   - **Expected**: Both image and video files imported to library

**Validation**:
- ✅ Source attached successfully (flag omitted)
- ✅ Default behavior is "both" (field present as "both" or absent, both work)
- ✅ Detection returns both image and video files
- ✅ Import processes both image and video files

---

## VAL-4: Acceptance Scenario 4 - Backward Compatibility (Existing Source)

**Objective**: Verify existing Sources without `mediaTypes` field default to "both" behavior.

**Spec Reference**: Acceptance Scenario 4 (lines 410-417)

**Preconditions**:
- Test library `/tmp/test_lib_existing_source` exists with Source attached before Slice 10 (no `mediaTypes` field in association file)

**Steps**:

1. **Verify existing association file lacks mediaTypes field**:
   ```bash
   # Path: .mediahub/sources/associations.json
   cat /tmp/test_lib_existing_source/.mediahub/sources/associations.json | python3 -m json.tool
   ```
   - **Expected**: JSON does NOT contain `mediaTypes` field for existing source

2. **Run detection with existing source**:
   ```bash
   cd /Volumes/Photos/_DevTools/MediaHub
   swift run mediahub detect --library /tmp/test_lib_existing_source
   ```
   - **Expected**: Command succeeds (exit code 0, no error)
   - **Expected**: Source loads successfully
   - **Expected**: Detection processes both images and videos (defaults to "both")

3. **Verify default behavior**:
   - **Expected**: Source is treated as `mediaTypes: "both"` (default behavior)
   - **Expected**: No errors or warnings about missing field

**Validation**:
- ✅ Existing Source without `mediaTypes` field loads successfully
- ✅ Source defaults to "both" behavior (no error)
- ✅ Detection processes both images and videos

---

## VAL-5: Acceptance Scenario 5 - Status Command with Statistics (Index Available)

**Objective**: Verify `status` command displays library statistics when BaselineIndex is available.

**Spec Reference**: Acceptance Scenario 5 (lines 419-428)

**Preconditions**:
- Test library `/tmp/test_lib_with_index` exists with BaselineIndex containing entries

**Steps**:

1. **Run status command (human-readable)**:
   ```bash
   cd /Volumes/Photos/_DevTools/MediaHub
   swift run mediahub status --library /tmp/test_lib_with_index
   ```
   - **Expected**: Output includes "Statistics:" section
   - **Expected**: Statistics show:
     - Total items: matches BaselineIndex entry count
     - By year: distribution by year (e.g., "2024: X", "2023: Y")
     - By media type: "Images: X", "Videos: Y"
   - **Expected**: Statistics appear after library metadata, before hash coverage

2. **Run status command (JSON)**:
   ```bash
   swift run mediahub status --json --library /tmp/test_lib_with_index | python3 -m json.tool
   ```
   - **Expected**: JSON contains `"statistics"` field (non-null object)
   - **Expected**: `statistics` structure:
     ```json
     {
       "statistics": {
         "totalItems": <number>,
         "byYear": {
           "2024": <number>,
           "2023": <number>
         },
         "byMediaType": {
           "images": <number>,
           "videos": <number>
         }
       }
     }
     ```
   - **Expected**: `byYear` keys are strings (not integers)
   - **Expected**: Statistics match BaselineIndex entry count and distribution

**Validation**:
- ✅ Statistics displayed in human-readable output when BaselineIndex available
- ✅ Statistics displayed in JSON output when BaselineIndex available
- ✅ Statistics structure matches spec (byYear keys as strings, byMediaType structure)
- ✅ Statistics values match BaselineIndex data

---

## VAL-6: Acceptance Scenario 6 - Status Command without Statistics (Index Missing)

**Objective**: Verify `status` command handles missing BaselineIndex gracefully.

**Spec Reference**: Acceptance Scenario 6 (lines 430-438)

**Preconditions**:
- Test library `/tmp/test_lib_no_index` exists without BaselineIndex

**Steps**:

1. **Run status command (human-readable)**:
   ```bash
   cd /Volumes/Photos/_DevTools/MediaHub
   swift run mediahub status --library /tmp/test_lib_no_index
   ```
   - **Expected**: Output shows "Statistics: N/A (baseline index not available)"
   - **Expected**: No error reported (exit code 0)
   - **Expected**: Other status information (library metadata, sources) displayed normally

2. **Run status command (JSON)**:
   ```bash
   swift run mediahub status --json --library /tmp/test_lib_no_index | python3 -m json.tool
   ```
   - **Expected**: JSON does NOT contain `statistics` field (field is omitted, not set to null)
   - **Expected**: Other fields (library, sources) present and valid
   - **Expected**: JSON is valid and parseable

3. **Verify JSON encoding behavior**:
   - **Expected**: `statistics` field follows same pattern as `hashCoverage` (omitted when unavailable, not null)
   - **Expected**: JSON structure is backward compatible (existing fields unchanged)

**Validation**:
- ✅ Human-readable output shows "N/A" when BaselineIndex missing
- ✅ JSON output omits `statistics` field (not null) when BaselineIndex missing
- ✅ No error reported (missing index is not an error for statistics)
- ✅ JSON output follows existing conventions (omit when unavailable, not null)

---

## VAL-7: Acceptance Scenario 7 - Invalid Media Types Value

**Objective**: Verify invalid `--media-types` values produce clear error messages.

**Spec Reference**: Acceptance Scenario 7 (lines 440-448)

**Preconditions**:
- Test library exists at `/tmp/test_lib_scenario7`

**Steps**:

1. **Test invalid media types value**:
   ```bash
   cd /Volumes/Photos/_DevTools/MediaHub
   swift run mediahub library create /tmp/test_lib_scenario7
   swift run mediahub source attach /tmp/test_source_images --media-types invalid --library /tmp/test_lib_scenario7
   ```
   - **Expected**: Command exits with error code 1
   - **Expected**: Error message clearly indicates invalid media types value
   - **Expected**: Error message suggests valid values: "images", "videos", "both"
   - **Expected**: Source is NOT attached

2. **Test case-insensitive validation** (if applicable):
   ```bash
   swift run mediahub source attach /tmp/test_source_images --media-types IMAGES --library /tmp/test_lib_scenario7
   ```
   - **Expected**: Command succeeds (case-insensitive parsing works) OR fails with clear error (if case-sensitive)

3. **Test other invalid values**:
   ```bash
   swift run mediahub source attach /tmp/test_source_images --media-types image --library /tmp/test_lib_scenario7
   swift run mediahub source attach /tmp/test_source_images --media-types video --library /tmp/test_lib_scenario7
   ```
   - **Expected**: Both commands fail with clear error messages

**Validation**:
- ✅ Invalid values result in exit code 1
- ✅ Error message clearly indicates invalid value
- ✅ Error message suggests valid values
- ✅ Source is not attached when validation fails

---

## VAL-8: Acceptance Scenario 8 - Source List Shows Media Types

**Objective**: Verify `source list` command displays media types for each Source.

**Spec Reference**: Acceptance Scenario 8 (lines 450-457)

**Preconditions**:
- Test library exists with multiple Sources (images-only, videos-only, both)

**Steps**:

1. **Create library with multiple sources**:
   ```bash
   cd /tmp
   rm -rf test_lib_scenario8
   mkdir -p test_lib_scenario8
   
   cd /Volumes/Photos/_DevTools/MediaHub
   swift run mediahub library create /tmp/test_lib_scenario8
   swift run mediahub source attach /tmp/test_source_images --media-types images --library /tmp/test_lib_scenario8
   swift run mediahub source attach /tmp/test_source_videos --media-types videos --library /tmp/test_lib_scenario8
   swift run mediahub source attach /tmp/test_source_mixed --library /tmp/test_lib_scenario8
   ```

2. **Run source list (human-readable)**:
   ```bash
   swift run mediahub source list --library /tmp/test_lib_scenario8
   ```
   - **Expected**: Output shows "Media types: images" for first source
   - **Expected**: Output shows "Media types: videos" for second source
   - **Expected**: Output shows "Media types: both" for third source (or field absent, defaulting to "both")

3. **Run source list (JSON)**:
   ```bash
   swift run mediahub source list --json --library /tmp/test_lib_scenario8 | python3 -m json.tool
   ```
   - **Expected**: JSON contains `mediaTypes` field for each source
   - **Expected**: Values are "images", "videos", or "both"
   - **Expected**: Default "both" included when field absent

**Validation**:
- ✅ Human-readable output shows media types for each Source
- ✅ JSON output includes `mediaTypes` field for each Source
- ✅ Default "both" displayed/included when field absent

---

## VAL-9: Validation Check - Year Extraction Reliability

**Objective**: Validate that year extraction from BaselineIndex paths is reliable.

**Spec Reference**: Planning Note - Year Extraction Validation (lines 148-150), Task 7.1

**Preconditions**:
- Test libraries with various BaselineIndex path patterns

**Steps**:

1. **Test year extraction with standard YYYY/MM paths**:
   ```bash
   # Use test_lib_with_index (standard paths)
   cd /Volumes/Photos/_DevTools/MediaHub
   swift run mediahub status --json --library /tmp/test_lib_with_index | python3 -m json.tool | grep -A 10 statistics
   ```
   - **Expected**: Year extraction works for paths like "2024/01/filename.jpg"
   - **Expected**: `byYear` contains entries like `"2024": <count>`, `"2023": <count>`

2. **Test year extraction with edge cases** (if applicable):
   - **Expected**: Paths not following YYYY/MM pattern use "unknown" bucket (if implemented)
   - **Expected**: Items with unextractable year are grouped under "unknown" key, still counted in total

3. **Verify year extraction logic**:
   - **Expected**: Year is extracted from first path component (4 digits)
   - **Expected**: Invalid year patterns handled gracefully (fallback to "unknown" or excluded from byYear)

**Validation**:
- ✅ Year extraction works for standard YYYY/MM paths
- ✅ Edge cases handled (unknown bucket if implemented)
- ✅ Year extraction is reliable for adopted libraries

---

## VAL-10: Validation Check - JSON Output Convention

**Objective**: Verify JSON output convention (omit vs null) matches existing `hashCoverage` pattern.

**Spec Reference**: Validation Check #2 (Task 8.1), JSON Output (lines 208-293)

**Preconditions**:
- Test libraries with and without BaselineIndex

**Steps**:

1. **Review hashCoverage JSON behavior**:
   ```bash
   cd /Volumes/Photos/_DevTools/MediaHub
   swift run mediahub status --json --library /tmp/test_lib_no_index | python3 -m json.tool
   ```
   - **Expected**: `hashCoverage` field is omitted (not present) when BaselineIndex unavailable
   - **Expected**: `hashCoverage` field is present (non-null object) when BaselineIndex available

2. **Verify statistics follows same pattern**:
   ```bash
   # Without BaselineIndex
   swift run mediahub status --json --library /tmp/test_lib_no_index | python3 -m json.tool | grep -E "(statistics|hashCoverage)"
   ```
   - **Expected**: Both `statistics` and `hashCoverage` are omitted (not present) when index unavailable

   ```bash
   # With BaselineIndex
   swift run mediahub status --json --library /tmp/test_lib_with_index | python3 -m json.tool | grep -E "(statistics|hashCoverage)"
   ```
   - **Expected**: Both `statistics` and `hashCoverage` are present (non-null objects) when index available

3. **Verify JSON encoding behavior**:
   - **Expected**: Optional Codable fields with nil values are omitted (Swift JSONEncoder default behavior)
   - **Expected**: `statistics` field structure matches spec (byYear keys as strings, byMediaType structure)

**Validation**:
- ✅ `statistics` field behavior matches `hashCoverage` pattern exactly (omit when unavailable, not null)
- ✅ JSON encoding uses optional Codable (omitted when nil, not set to null)
- ✅ JSON structure matches spec (byYear keys as strings)

---

## VAL-11: Validation Check - Media Type Classification Source of Truth

**Objective**: Verify single source of truth for media type classification (no duplication, no divergence).

**Spec Reference**: Validation Check #3 (Task 4.1), Data Integrity (lines 322-327)

**Preconditions**:
- Understanding of existing media type classification component

**Steps**:

1. **Identify classification component**:
   - **Expected**: Single component exists for media type classification (extension sets for images/videos)
   - **Expected**: Component is documented as single source of truth

2. **Verify scan filtering uses same classification**:
   ```bash
   cd /Volumes/Photos/_DevTools/MediaHub
   swift run mediahub source attach /tmp/test_source_mixed --media-types images --library /tmp/test_lib_scenario1
   swift run mediahub detect --library /tmp/test_lib_scenario1
   ```
   - **Expected**: Only image files detected (uses same extension sets as existing classification)

3. **Verify statistics computation uses same classification**:
   ```bash
   swift run mediahub status --json --library /tmp/test_lib_with_index | python3 -m json.tool | grep -A 5 byMediaType
   ```
   - **Expected**: Statistics `byMediaType` counts match scan filtering behavior
   - **Expected**: Same files classified as images/videos in both scan and statistics

4. **Verify no duplication**:
   - **Expected**: No duplicate extension sets exist in codebase
   - **Expected**: Both scan filtering and statistics computation reference same classification component

**Validation**:
- ✅ Single source of truth identified and documented
- ✅ Scan filtering uses existing classification (no duplication)
- ✅ Statistics computation uses same classification (no divergence)
- ✅ No duplicate extension sets exist

---

## VAL-12: Validation Check - Invalid Stored Values Handling

**Objective**: Verify handling of invalid `mediaTypes` values in stored associations.

**Spec Reference**: Validation Check #5 (Task 9.1), Compatibility & Defaulting Rules (lines 304-309)

**Preconditions**:
- Test library with association file containing invalid `mediaTypes` value (if enum used, invalid raw strings)

**Steps**:

1. **Test invalid stored value** (if applicable):
   ```bash
   # Manually create association file with invalid mediaTypes value
   cd /tmp
   mkdir -p test_lib_invalid_value/.mediahub/sources
   # Path: .mediahub/sources/associations.json (verify path matches actual implementation)
   cat > test_lib_invalid_value/.mediahub/sources/associations.json << 'EOF'
   {
     "version": "1.0",
     "libraryId": "test-id",
     "sources": [
       {
         "sourceId": "test-source-id",
         "type": "folder",
         "path": "/tmp/test_source_mixed",
         "attachedAt": "2026-01-27T00:00:00Z",
         "mediaTypes": "invalid_value"
       }
     ]
   }
   EOF
   ```
   - **Expected**: Source loading handles invalid value gracefully (fallback to "both" with warning, OR error - per chosen approach)
   - **Expected**: No silent failures or undefined behavior

2. **Verify chosen approach**:
   - **Expected**: If enum used: invalid raw strings are automatically rejected during decoding (enum safety)
   - **Expected**: If fallback chosen: invalid values fallback to "both" with warning logged
   - **Expected**: If error chosen: invalid values cause error during Source loading

**Validation**:
- ✅ Invalid stored values handled gracefully (per chosen approach)
- ✅ No silent failures or undefined behavior
- ✅ Approach is consistent throughout codebase

---

## VAL-13: Edge Cases and Invariants

**Objective**: Verify edge cases and invariants are handled correctly.

**Spec Reference**: Statistics Computed (lines 140-152), Error Handling (lines 329-333)

### Edge Case 13.1: Unknown Year Handling

**Steps**:
```bash
# Test with BaselineIndex containing paths that don't follow YYYY/MM pattern
# (if such paths exist in test data)
cd /Volumes/Photos/_DevTools/MediaHub
swift run mediahub status --json --library /tmp/test_lib_with_index | python3 -m json.tool | grep -A 10 statistics
```
- **Expected**: Items with unextractable year use "unknown" bucket (if implemented) OR excluded from byYear but counted in total
- **Expected**: Year extraction handles edge cases gracefully

### Edge Case 13.2: Unknown Extensions Behavior

**Steps**:
```bash
   # Test with source containing files with unknown extensions
   cd /tmp
   mkdir -p test_source_unknown
   echo "test" > test_source_unknown/file.unknown
   # Create valid JPEG file (if sips unavailable, create valid JPEG manually)
   sips -s format jpeg --out test_source_unknown/IMG_001.jpg /System/Library/CoreServices/DefaultDesktop.heic 2>/dev/null

cd /Volumes/Photos/_DevTools/MediaHub
swift run mediahub library create /tmp/test_lib_unknown
swift run mediahub source attach /tmp/test_source_unknown --library /tmp/test_lib_unknown
swift run mediahub detect --library /tmp/test_lib_unknown
```
- **Expected**: Unknown extensions excluded from processing (consistent with existing behavior)
- **Expected**: Unknown extensions excluded from statistics `byMediaType` but counted in total (per spec)

### Edge Case 13.3: Invalid --media-types Error Message

**Steps**:
```bash
cd /Volumes/Photos/_DevTools/MediaHub
swift run mediahub source attach /tmp/test_source_images --media-types invalid --library /tmp/test_lib_scenario7 2>&1
```
- **Expected**: Error message clearly indicates invalid media types value
- **Expected**: Error message suggests valid values: "images", "videos", "both"
- **Expected**: Exit code 1

### Edge Case 13.4: Case-Insensitive Flag Parsing

**Steps**:
```bash
cd /Volumes/Photos/_DevTools/MediaHub
swift run mediahub source attach /tmp/test_source_images --media-types IMAGES --library /tmp/test_lib_scenario1
swift run mediahub source attach /tmp/test_source_videos --media-types Videos --library /tmp/test_lib_scenario1
swift run mediahub source attach /tmp/test_source_mixed --media-types BOTH --library /tmp/test_lib_scenario1
```
- **Expected**: All commands succeed (case-insensitive parsing works)
- **Expected**: MediaTypes stored correctly (normalized to lowercase enum values)

**Validation**:
- ✅ Unknown year handled (unknown bucket or excluded from byYear)
- ✅ Unknown extensions excluded (consistent with existing behavior)
- ✅ Invalid flag values produce clear error messages
- ✅ Case-insensitive parsing works correctly

---

## VAL-14: Automated Test Suite Coverage

**Objective**: Verify comprehensive test coverage for all acceptance scenarios and edge cases.

**Spec Reference**: Task 10.1 (Coverage Matrix), Testing Strategy (Step 9)

### Test Coverage Matrix

**Mapping Acceptance Scenarios 1-8 to Test Tasks**:

| Scenario | Description | Test Tasks | Test Files |
|----------|-------------|------------|------------|
| 1 | Attach Source with images-only filter | Task 3.3, Task 5.3 | `SourceCommandTests`, `DetectionOrchestrationTests`, `ImportExecutionTests` |
| 2 | Attach Source with videos-only filter | Task 3.3, Task 5.3 | `SourceCommandTests`, `DetectionOrchestrationTests`, `ImportExecutionTests` |
| 3 | Attach Source with default (both) filter | Task 3.3, Task 5.3 | `SourceCommandTests`, `DetectionOrchestrationTests`, `ImportExecutionTests` |
| 4 | Backward compatibility (existing Source without field) | Task 1.3, Task 2.2, Task 9.2 | `SourceTests`, `SourceAssociationTests` |
| 5 | Status command with statistics (index available) | Task 8.5 | `StatusCommandTests` |
| 6 | Status command without statistics (index missing) | Task 8.5 | `StatusCommandTests` |
| 7 | Invalid media types value | Task 3.2, Task 3.3 | `SourceCommandTests` |
| 8 | Source list shows media types | Task 6.3 | `SourceCommandTests` |

### Automated Test Execution

**Run all test suites**:

```bash
cd /Volumes/Photos/_DevTools/MediaHub

# Unit tests for Source mediaTypes field
swift test --filter SourceTests

# Unit tests for Source association persistence
swift test --filter SourceAssociationTests

# Integration tests for CLI flag parsing
swift test --filter SourceCommandTests

# Unit tests for source scanning filtering
swift test --filter SourceScanningTests

# Integration tests for detection with filtering
swift test --filter DetectionOrchestrationTests

# Integration tests for import with filtering
swift test --filter ImportExecutionTests

# Unit tests for statistics computation
swift test --filter LibraryStatisticsTests

# Integration tests for status command
swift test --filter StatusCommandTests

# Full test suite
swift test
```

**Expected Results**:
- ✅ All test suites pass
- ✅ All acceptance scenarios covered by tests
- ✅ Edge cases covered by tests
- ✅ Backward compatibility verified

**Validation**:
- ✅ Test coverage matrix complete (all 8 scenarios mapped)
- ✅ All test suites pass
- ✅ No test failures or regressions

---

## Validation Summary

### Acceptance Scenarios Validation

| Scenario | Status | Notes |
|----------|--------|-------|
| VAL-1: Attach Source with images-only filter | ⬜ TODO | |
| VAL-2: Attach Source with videos-only filter | ⬜ TODO | |
| VAL-3: Attach Source with default (both) filter | ⬜ TODO | |
| VAL-4: Backward compatibility (existing Source) | ⬜ TODO | |
| VAL-5: Status with statistics (index available) | ⬜ TODO | |
| VAL-6: Status without statistics (index missing) | ⬜ TODO | |
| VAL-7: Invalid media types value | ⬜ TODO | |
| VAL-8: Source list shows media types | ⬜ TODO | |

### Validation Checks

| Check | Status | Notes |
|-------|--------|-------|
| VAL-9: Year extraction reliability | ⬜ TODO | |
| VAL-10: JSON output convention | ⬜ TODO | |
| VAL-11: Media type classification source of truth | ⬜ TODO | |
| VAL-12: Invalid stored values handling | ⬜ TODO | |

### Edge Cases and Invariants

| Edge Case | Status | Notes |
|-----------|--------|-------|
| VAL-13.1: Unknown year handling | ⬜ TODO | |
| VAL-13.2: Unknown extensions behavior | ⬜ TODO | |
| VAL-13.3: Invalid flag error message | ⬜ TODO | |
| VAL-13.4: Case-insensitive parsing | ⬜ TODO | |

### Test Suite Coverage

| Test Suite | Status | Notes |
|------------|--------|-------|
| VAL-14: Automated test suite | ⬜ TODO | All test suites pass |

---

## Success Criteria

The implementation is validated when:

1. ✅ All 8 acceptance scenarios pass (VAL-1 through VAL-8)
2. ✅ All validation checks pass (VAL-9 through VAL-12)
3. ✅ All edge cases handled correctly (VAL-13)
4. ✅ All automated test suites pass (VAL-14)
5. ✅ Backward compatibility verified (existing Sources work without changes)
6. ✅ JSON output conventions match existing patterns (omit when unavailable, not null)
7. ✅ Media type classification uses single source of truth (no duplication, no divergence)
8. ✅ Statistics computation is efficient (single pass, O(n), no additional I/O)
9. ✅ Filtering occurs at scan stage (no post-filtering in detect/import)
10. ✅ Default behavior is "both" when mediaTypes field absent

---

## Notes

- **Manual Testing**: Some validation steps require manual inspection (JSON structure, file contents)
- **CI Compatibility**: All automated tests should run in CI without external dependencies
- **Exit Codes**: Commands should exit with code 0 for success, 1 for errors (consistent with existing CLI)
- **JSON Encoding**: Follow Swift JSONEncoder default behavior (optional Codable fields omitted when nil)
- **Error Messages**: Should be clear, actionable, and suggest valid values when applicable
