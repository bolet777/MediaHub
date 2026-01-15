# Implementation Tasks: Source Media Types + Library Statistics (Slice 10)

**Feature**: Source Media Types + Library Statistics  
**Specification**: `specs/010-source-media-types-library-statistics/spec.md`  
**Plan**: `specs/010-source-media-types-library-statistics/plan.md`  
**Slice**: 10 - Source Media Types + Library Statistics  
**Created**: 2026-01-27

## Task Organization

Tasks are organized by implementation sequence and follow the steps defined in the plan. Each task is:
- Small and focused on a single deliverable
- Sequential (dependencies are clear)
- Traceable to spec sections (referenced by section name)
- Traceable to plan steps (referenced by step number)
- Includes explicit backward compatibility and validation verification

## NON-NEGOTIABLE CONSTRAINTS FOR SLICE 10

**CRITICAL**: The following constraints MUST be followed during Slice 10 implementation:

1. **Backward Compatibility**:
   - Existing Sources without `mediaTypes` field MUST default to `.both` (enum value)
   - Source association storage format extension MUST be backward compatible
   - JSON output schema MUST be backward compatible (existing fields unchanged)

2. **Single Source of Truth**:
   - Media type classification MUST use existing classification component (no duplication)
   - Scan filtering and statistics computation MUST reference same classification logic

3. **Performance**:
   - Media type filtering MUST be O(1) per file (extension check only, no additional I/O)
   - Statistics computation MUST be single pass, O(n), no additional I/O

4. **Minimal Changes**:
   - No breaking changes to existing functionality
   - Reuse existing patterns (Source struct, SourceAssociation, StatusFormatter)
   - No UI/SwiftUI work

---

## Task 1: Data Model Extension - Source Media Types

**Plan Reference**: Step 1 (lines 39-69)  
**Spec Reference**: Source Media Type Configuration (lines 37-79), Compatibility & Defaulting Rules (lines 297-320)  
**Dependencies**: None

### Task 1.1: Create SourceMediaTypes Enum and Add Field to Source Struct

**Objective**: Create `SourceMediaTypes` enum (Codable) and extend `Source` struct to include optional `mediaTypes` field with backward-compatible defaulting.

**Probable Touchpoints**:
- `Sources/MediaHub/Source.swift` (modify)

**Implementation**:
- Create `SourceMediaTypes` enum conforming to `String, Codable` with cases: `.images`, `.videos`, `.both` (following pattern of `SourceType` enum)
- Add `mediaTypes: SourceMediaTypes?` field to `Source` struct
- Implement default value handling: when field is absent/nil, treat as `.both`
- Ensure Codable conformance handles optional field correctly (decodeIfPresent)
- Add computed property or init logic to provide `.both` default when nil
- Enum reduces errors and simplifies invalid value handling (invalid strings cannot be decoded)

**Done when**:
- `SourceMediaTypes` enum created (Codable, String-backed)
- `Source` struct includes optional `mediaTypes` field
- Codable decoding handles absent field (defaults to `.both` behavior)
- `swift build` succeeds

**Validation**:
- Run `swift build`
- Verify Source struct compiles with new enum and field

---

### Task 1.2: Implement Default Value Handling

**Objective**: Ensure Source provides `.both` as default when mediaTypes is nil/absent.

**Probable Touchpoints**:
- `Sources/MediaHub/Source.swift` (modify)

**Implementation**:
- Add computed property or init logic that returns `.both` when `mediaTypes` is nil
- Ensure this default is used consistently throughout codebase
- Document default behavior

**Done when**:
- Source with nil mediaTypes behaves as `.both`
- Default value is applied consistently

**Validation**:
- Create Source with nil mediaTypes, verify it behaves as `.both`

---

### Task 1.3: Add Tests for Source Media Types Field

**Objective**: Add unit tests for Source mediaTypes field (defaulting, Codable).

**Probable Touchpoints**:
- `Tests/MediaHubTests/SourceTests.swift` (modify)

**Implementation**:
- Test Source creation with mediaTypes field set (`.images`, `.videos`, `.both`)
- Test Source creation without mediaTypes field (defaults to `.both`)
- Test Codable encoding/decoding with mediaTypes field
- Test Codable encoding/decoding without mediaTypes field (backward compatibility)
- Test invalid enum values are rejected during decoding (enum safety)

**Done when**:
- All tests pass
- Backward compatibility verified (Sources without field decode successfully)

**Validation**:
- Run `swift test --filter SourceTests`

---

## Task 2: Source Association Storage Extension

**Plan Reference**: Step 2 (lines 73-101)  
**Spec Reference**: Source Media Type Configuration (lines 37-79), Compatibility & Defaulting Rules (lines 297-320)  
**Dependencies**: Task 1

### Task 2.1: Verify SourceAssociation Handles Optional Field

**Objective**: Verify that SourceAssociation serialization/deserialization handles optional mediaTypes field correctly.

**Probable Touchpoints**:
- `Sources/MediaHub/SourceAssociation.swift` (review, minimal changes if needed)

**Implementation**:
- Review SourceAssociationSerializer to ensure it correctly serializes/deserializes Sources with optional fields
- Verify JSON encoding/decoding behavior with optional Codable fields (should omit nil, decodeIfPresent for absent)
- No changes needed if Source Codable handles optional field correctly (delegates to Source struct)

**Done when**:
- SourceAssociation correctly serializes/deserializes Sources with optional mediaTypes field
- Existing association files (without mediaTypes) load successfully

**Validation**:
- Load existing association file without mediaTypes field, verify it works
- Create new association with mediaTypes field, verify it persists

---

### Task 2.2: Add Tests for Source Association Persistence

**Objective**: Add unit tests for persistence of mediaTypes field in Source associations.

**Probable Touchpoints**:
- `Tests/MediaHubTests/SourceAssociationTests.swift` (modify)

**Implementation**:
- Test association serialization with mediaTypes field
- Test association deserialization with mediaTypes field
- Test association deserialization without mediaTypes field (backward compatibility)
- Test round-trip serialization preserves mediaTypes value

**Done when**:
- All tests pass
- Backward compatibility verified (existing associations without field work)

**Validation**:
- Run `swift test --filter SourceAssociationTests`

---

## Task 3: CLI Parsing - Source Attach Command

**Plan Reference**: Step 3 (lines 105-136)  
**Spec Reference**: Source Media Type Configuration (lines 37-79), Acceptance Scenario 7 (lines 440-448)  
**Dependencies**: Task 1

### Task 3.1: Add --media-types Flag to Source Attach Command

**Objective**: Add `--media-types` flag to `source attach` command with case-insensitive parsing.

**Probable Touchpoints**:
- `Sources/MediaHubCLI/SourceCommand.swift` (modify)

**Implementation**:
- Add `@Option` property for `--media-types` flag (String input)
- Parse string input and convert to `SourceMediaTypes` enum (case-insensitive: "images" → `.images`, "videos" → `.videos`, "both" → `.both`)
- Handle default case (flag omitted → `.both`)
- Pass media types enum value to Source creation
- Enum conversion simplifies validation (invalid strings cannot be converted to enum)

**Done when**:
- `--media-types` flag is recognized by ArgumentParser
- Flag accepts "images", "videos", "both" (case-insensitive, converted to enum)
- Omitted flag defaults to `.both`
- `swift build` succeeds

**Validation**:
- Run `swift build`
- Run `mediahub source attach --help` and verify `--media-types` flag is listed

---

### Task 3.2: Implement Flag Validation

**Objective**: Validate `--media-types` flag value and provide clear error messages.

**Probable Touchpoints**:
- `Sources/MediaHubCLI/SourceCommand.swift` (modify)

**Implementation**:
- Validate flag value during enum conversion ("images", "videos", "both" only)
- Invalid values result in clear error message and exit code 1 (enum conversion fails for invalid strings)
- Error message suggests valid values: "images", "videos", "both"

**Done when**:
- Valid values accepted (case-insensitive)
- Invalid values produce clear error message with exit code 1
- Error message suggests valid values

**Validation**:
- Test with valid values: `mediahub source attach /path --media-types images`
- Test with invalid value: `mediahub source attach /path --media-types invalid` (should error)

---

### Task 3.3: Add Tests for CLI Flag Parsing

**Objective**: Add integration tests for `--media-types` flag parsing and validation.

**Probable Touchpoints**:
- `Tests/MediaHubTests/SourceCommandTests.swift` (create or modify)

**Implementation**:
- Test valid flag values ("images", "videos", "both", case-insensitive, converted to enum)
- Test invalid flag values (error with clear message, enum conversion fails)
- Test omitted flag (defaults to `.both`)
- Test flag is passed to Source creation correctly (as enum)

**Done when**:
- All tests pass
- Flag parsing and validation verified

**Validation**:
- Run `swift test --filter SourceCommandTests`

---

## Task 4: Source Scanning Integration - Media Type Filtering

**Plan Reference**: Step 4 (lines 140-173), Validation Check #3 (lines 388-399)  
**Spec Reference**: Source Media Type Configuration (lines 37-79), Data Integrity (lines 322-327)  
**Dependencies**: Task 1, Task 3

### Task 4.1: Validation Check - Media Type Classification Source of Truth

**Objective**: Verify single source of truth for media type classification before implementing filtering.

**Probable Touchpoints**:
- Review existing media type classification component

**Implementation**:
- Identify existing media type classification component (extension sets for images/videos)
- Document that this component is the single source of truth
- Verify extension sets are accessible for both scan filtering and statistics computation
- Ensure no duplication of classification logic

**Done when**:
- Single source of truth identified and documented
- Extension sets are accessible for filtering and statistics
- No duplication exists

**Validation**:
- Review codebase for media type classification logic
- Document location and usage of classification component

---

### Task 4.2: Add Media Type Filtering to Source Scanning

**Objective**: Integrate media type filtering into source scanning, before candidates are added to result set.

**Probable Touchpoints**:
- Source scanning component (likely `Sources/MediaHub/SourceScanning.swift`): Add filtering logic during scan enumeration

**Implementation**:
- Add filtering logic during scan enumeration
- Filter files by extension using existing media type classification (single source of truth)
- Apply filter based on Source's `mediaTypes` setting (`.images`, `.videos`, or `.both`)
- Ensure filtering occurs before candidates are added to result set
- `.images` filter: Only image files included
- `.videos` filter: Only video files included
- `.both` filter: Both images and videos included (no filtering)

**Done when**:
- Source scanning filters by media type based on Source configuration
- Filtering uses existing media type classification (no duplication, single source of truth)
- Filtering is O(1) per file (extension check only, no additional I/O)

**Validation**:
- Test scan with "images" filter (only images returned)
- Test scan with "videos" filter (only videos returned)
- Test scan with "both" filter (both images and videos returned)

---

### Task 4.3: Add Tests for Source Scanning Filtering

**Objective**: Add unit tests for media type filtering in source scanning.

**Probable Touchpoints**:
- `Tests/MediaHubTests/SourceScanningTests.swift` (modify)

**Implementation**:
- Test scan with Source mediaTypes=.images (only image files in results)
- Test scan with Source mediaTypes=.videos (only video files in results)
- Test scan with Source mediaTypes=.both (both images and videos in results)
- Test scan with Source mediaTypes=nil (defaults to .both, both types included)
- Test unknown extensions excluded (consistent with existing behavior)

**Done when**:
- All tests pass
- Filtering verified for each media type setting

**Validation**:
- Run `swift test --filter SourceScanningTests`

---

## Task 5: Detection and Import Integration

**Plan Reference**: Step 5 (lines 177-205)  
**Spec Reference**: Source Media Type Configuration (lines 37-79), Acceptance Scenarios 1-3 (lines 380-408)  
**Dependencies**: Task 4

### Task 5.1: Verify Detection Pipeline Uses Filtered Results

**Objective**: Verify that detection pipeline uses filtered scan results (no additional filtering needed).

**Probable Touchpoints**:
- Detection orchestration component (likely `Sources/MediaHub/DetectionOrchestration.swift`): Review to verify uses filtered scan results

**Implementation**:
- Review detection orchestration to verify it uses filtered scan results
- Ensure no additional filtering logic is added (filtering happens once at scan stage)
- Verify detection results reflect only files matching Source's media type filter

**Done when**:
- Detection uses filtered scan results
- No duplicate filtering logic exists
- Detection results reflect media type filtering

**Validation**:
- Run detection with Source mediaTypes="images", verify only images detected
- Run detection with Source mediaTypes="videos", verify only videos detected

---

### Task 5.2: Verify Import Pipeline Processes Filtered Candidates

**Objective**: Verify that import pipeline processes only filtered candidates (inherits from detection).

**Probable Touchpoints**:
- Import execution component (likely `Sources/MediaHub/ImportExecution.swift`): Review to verify processes detection results

**Implementation**:
- Review import execution to verify it processes detection results (already filtered)
- Ensure no additional filtering logic is added
- Verify import processes only files matching Source's media type filter

**Done when**:
- Import processes only filtered files
- No duplicate filtering logic exists

**Validation**:
- Run import after detection with Source mediaTypes="images", verify only images imported
- Run import after detection with Source mediaTypes="videos", verify only videos imported

---

### Task 5.3: Add Integration Tests for Detect/Import with Filtering

**Objective**: Add integration tests for detect and import operations with media type filtering.

**Probable Touchpoints**:
- `Tests/MediaHubTests/DetectionOrchestrationTests.swift` (modify)
- `Tests/MediaHubTests/ImportExecutionTests.swift` (modify if needed)

**Implementation**:
- Test detect with Source mediaTypes=.images (only images in detection results)
- Test detect with Source mediaTypes=.videos (only videos in detection results)
- Test import with Source mediaTypes=.images (only images imported)
- Test import with Source mediaTypes=.videos (only videos imported)
- Test end-to-end: attach source with filter → detect → import (only filtered types processed)

**Done when**:
- All tests pass
- Detect and import respect media type filtering verified

**Validation**:
- Run `swift test --filter DetectionOrchestrationTests`
- Run `swift test --filter ImportExecutionTests`

---

## Task 6: Source List Output Extension

**Plan Reference**: Step 6 (lines 209-236), Acceptance Scenario 8 (lines 450-457)  
**Spec Reference**: Source List Output (lines 70-132)  
**Dependencies**: Task 1

### Task 6.1: Add Media Types to Source List Human-Readable Output

**Objective**: Add media types display to human-readable `source list` output.

**Probable Touchpoints**:
- `Sources/MediaHubCLI/OutputFormatting.swift` (modify): Extend `SourceListFormatter` to include media types

**Implementation**:
- Extend `SourceListFormatter` to include media types in human-readable output
- Display "Media types: images", "Media types: videos", or "Media types: both" (convert enum to string for display)
- Handle default case (display "both" when field absent)

**Done when**:
- `source list` displays media types in human-readable output
- Default "both" displayed when field absent

**Validation**:
- Run `mediahub source list` and verify media types displayed

---

### Task 6.2: Add Media Types to Source List JSON Output

**Objective**: Add `mediaTypes` field to JSON `source list` output.

**Probable Touchpoints**:
- `Sources/MediaHubCLI/OutputFormatting.swift` (modify): Extend `SourceListFormatter` JSON output

**Implementation**:
- Extend `SourceListFormatter` to include `mediaTypes` field in JSON output (enum encodes as string: "images", "videos", "both")
- Include `mediaTypes` field for all Sources (default "both" when absent)

**Done when**:
- `source list --json` includes `mediaTypes` field in JSON output
- Default "both" included when field absent

**Validation**:
- Run `mediahub source list --json` and verify `mediaTypes` field present

---

### Task 6.3: Add Tests for Source List Output

**Objective**: Add tests for source list output with media types.

**Probable Touchpoints**:
- `Tests/MediaHubTests/SourceCommandTests.swift` (modify)

**Implementation**:
- Test human-readable output shows media types (enum converted to string for display)
- Test JSON output includes `mediaTypes` field (enum encodes as string: "images", "videos", "both")
- Test default "both" displayed when field absent

**Done when**:
- All tests pass
- Source list output verified

**Validation**:
- Run `swift test --filter SourceCommandTests`

---

## Task 7: Library Statistics Computation

**Plan Reference**: Step 7 (lines 240-276), Validation Check #1 (lines 363-373)  
**Spec Reference**: Library Statistics (lines 134-153), Statistics Computed (lines 140-152)  
**Dependencies**: None (can be done in parallel with Tasks 1-6)

### Task 7.1: Validation Check - Year Extraction Reliability

**Objective**: Validate that year extraction from BaselineIndex paths is reliable before implementing statistics.

**Probable Touchpoints**:
- Review BaselineIndex structure and sample data

**Implementation**:
- Load sample BaselineIndex files (from real libraries, adopted libraries)
- Verify paths consistently follow `YYYY/MM/...` pattern
- Test edge cases: adopted libraries, manually organized folders, edge path patterns
- **Default decision if validation reveals issues**: Implement "unknown" bucket in byYear statistics (items with unextractable year are grouped under "unknown" key, still counted in total)

**Done when**:
- Year extraction reliability validated
- Decision made: use "unknown" bucket if extraction unreliable (default fallback)

**Validation**:
- Review real BaselineIndex data
- Document year extraction approach (with "unknown" bucket fallback if needed)

---

### Task 7.2: Create LibraryStatistics Data Structure

**Objective**: Create data structures for library statistics (totalItems, byYear, byMediaType).

**Probable Touchpoints**:
- `Sources/MediaHub/LibraryStatistics.swift` (new file)

**Implementation**:
- Create `LibraryStatistics` struct with:
  - `totalItems: Int`
  - `byYear: [String: Int]` (year as string key, count as value)
  - `byMediaType: [String: Int]` (media type as key: "images", "videos", count as value)
- Make struct Codable for JSON output

**Done when**:
- `LibraryStatistics` struct created and compiles
- Struct matches spec structure (byYear keys as strings, byMediaType structure)

**Validation**:
- Run `swift build`
- Verify struct compiles

---

### Task 7.3: Implement Statistics Computation Logic

**Objective**: Implement statistics computation from BaselineIndex (single pass, O(n)).

**Probable Touchpoints**:
- `Sources/MediaHub/LibraryStatistics.swift` (modify)

**Implementation**:
- Create `LibraryStatisticsComputer` struct with `compute(from:)` method
- Single pass over BaselineIndex entries
- Extract year from normalized paths (first path component, YYYY pattern)
- Use "unknown" bucket if year cannot be extracted (default decision)
- Classify media type from file extension (reuse existing classification, single source of truth)
- Unknown extensions excluded from "by media type" but counted in total
- Performance: O(n) where n is entry count, no additional I/O

**Done when**:
- Statistics computation extracts year from paths (with "unknown" bucket fallback)
- Statistics computation classifies media types using existing classification logic (single source of truth)
- Single pass, O(n) complexity, no additional I/O

**Validation**:
- Test with sample BaselineIndex data
- Verify year extraction works (including "unknown" bucket for edge cases)
- Verify media type classification matches scan filtering logic

---

### Task 7.4: Add Tests for Statistics Computation

**Objective**: Add unit tests for statistics computation (year extraction, media type classification, edge cases).

**Probable Touchpoints**:
- `Tests/MediaHubTests/LibraryStatisticsTests.swift` (new file)

**Implementation**:
- Test statistics computation with valid YYYY/MM paths
- Test statistics computation with "unknown" year paths (fallback bucket)
- Test statistics computation classifies media types correctly
- Test statistics computation with unknown extensions (excluded from byMediaType, counted in total)
- Test performance: single pass, O(n) complexity

**Done when**:
- All tests pass
- Statistics computation verified for various path patterns (including "unknown" year cases)

**Validation**:
- Run `swift test --filter LibraryStatisticsTests`

---

## Task 8: Status Command Integration - Statistics Display

**Plan Reference**: Step 8 (lines 280-313), Validation Check #2 (lines 375-386)  
**Spec Reference**: Library Statistics (lines 134-293), Acceptance Scenarios 5-6 (lines 419-438)  
**Dependencies**: Task 7

### Task 8.1: Validation Check - JSON Output Convention

**Objective**: Verify JSON output convention (omit vs null) matches existing `hashCoverage` pattern exactly.

**Probable Touchpoints**:
- `Sources/MediaHubCLI/OutputFormatting.swift` (review)

**Implementation**:
- Review `StatusFormatter.formatJSON()` implementation
- Verify `hashCoverage` field behavior: optional Codable field, omitted when nil (not set to null)
- Ensure `statistics` field follows identical pattern: optional Codable field, omitted when nil (not set to null)
- Test JSON encoding: Optional Codable fields with nil values are omitted (Swift JSONEncoder default behavior)
- Verify JSON structure: `statistics` field structure matches spec (byYear keys as strings, byMediaType structure)

**Done when**:
- JSON output convention validated (omit when unavailable, not null)
- `statistics` field pattern matches `hashCoverage` pattern exactly

**Validation**:
- Review existing `hashCoverage` JSON output behavior
- Document that `statistics` must follow same pattern

---

### Task 8.2: Integrate Statistics Computation into StatusCommand

**Objective**: Integrate statistics computation into StatusCommand.

**Probable Touchpoints**:
- `Sources/MediaHubCLI/StatusCommand.swift` (modify)

**Implementation**:
- Load BaselineIndex (reuse existing logic)
- Compute statistics when BaselineIndex is available
- Pass statistics to StatusFormatter (optional, nil when index unavailable)

**Done when**:
- StatusCommand computes statistics when BaselineIndex available
- Statistics passed to StatusFormatter (nil when index unavailable)

**Validation**:
- Run `mediahub status` with BaselineIndex available, verify statistics computed
- Run `mediahub status` without BaselineIndex, verify no error

---

### Task 8.3: Add Statistics to Status Human-Readable Output

**Objective**: Add statistics section to human-readable status output.

**Probable Touchpoints**:
- `Sources/MediaHubCLI/OutputFormatting.swift` (modify)

**Implementation**:
- Extend `StatusFormatter.formatHumanReadable()` to include statistics section
- Statistics section appears after library metadata, before hash coverage
- Display "Statistics: N/A (baseline index not available)" when index missing/invalid
- Display statistics when BaselineIndex available (total items, by year, by media type)

**Done when**:
- `status` command displays statistics in human-readable output when BaselineIndex available
- `status` command handles missing index gracefully ("N/A" message, no error)

**Validation**:
- Run `mediahub status` with BaselineIndex, verify statistics displayed
- Run `mediahub status` without BaselineIndex, verify "N/A" message

---

### Task 8.4: Add Statistics to Status JSON Output

**Objective**: Add `statistics` field to JSON status output (omitted when unavailable).

**Probable Touchpoints**:
- `Sources/MediaHubCLI/OutputFormatting.swift` (modify)

**Implementation**:
- Extend `StatusFormatter.formatJSON()` to include `statistics` field
- `statistics` field is optional Codable, omitted when nil (not set to null)
- Follow `hashCoverage` pattern exactly
- JSON structure matches spec (byYear keys as strings, byMediaType structure)

**Done when**:
- `status --json` includes `statistics` field when BaselineIndex available
- `status --json` omits `statistics` field when BaselineIndex unavailable (not null)
- JSON output follows existing conventions (omit when unavailable, not null)

**Validation**:
- Run `mediahub status --json` with BaselineIndex, verify `statistics` field present
- Run `mediahub status --json` without BaselineIndex, verify `statistics` field omitted (not null)

---

### Task 8.5: Add Tests for Status Command with Statistics

**Objective**: Add integration tests for status command with statistics display.

**Probable Touchpoints**:
- `Tests/MediaHubTests/StatusCommandTests.swift` (create or modify)

**Implementation**:
- Test status with BaselineIndex available (statistics displayed)
- Test status without BaselineIndex (statistics "N/A" or omitted)
- Test status JSON with BaselineIndex (statistics field present)
- Test status JSON without BaselineIndex (statistics field omitted, not null)
- Test JSON schema backward compatibility (existing fields unchanged)

**Done when**:
- All tests pass
- Status command output verified (human-readable and JSON)

**Validation**:
- Run `swift test --filter StatusCommandTests`

---

## Task 9: Backward Compatibility and Migration

**Plan Reference**: Compatibility & Defaulting Rules (lines 297-320), Validation Check #5 (lines 414-424)  
**Spec Reference**: Compatibility & Defaulting Rules (lines 297-320), Acceptance Scenario 4 (lines 410-417)  
**Dependencies**: Tasks 1-8

### Task 9.1: Validation Check - Invalid Stored Values Handling

**Objective**: Choose approach for handling invalid `mediaTypes` values in stored associations.

**Probable Touchpoints**:
- `Sources/MediaHub/Source.swift` (modify if needed)

**Implementation**:
- Review spec: Option 1 (fallback to "both" with warning) vs Option 2 (error)
- **Note**: With enum Codable, invalid stored values are automatically rejected during decoding (enum safety)
- If invalid raw string values exist in stored associations, choose approach: fallback to `.both` with warning (preferred) or error
- Implement chosen approach in Source loading/decoding (enum decoding handles most cases automatically)
- Invalid values MUST NOT cause silent failures or undefined behavior

**Done when**:
- Approach chosen and implemented consistently
- Invalid values handled gracefully (fallback or error, not silent failure)

**Validation**:
- Test with invalid stored value, verify chosen behavior

---

### Task 9.2: Add Backward Compatibility Tests

**Objective**: Add comprehensive backward compatibility tests.

**Probable Touchpoints**:
- `Tests/MediaHubTests/SourceTests.swift` (modify)
- `Tests/MediaHubTests/SourceAssociationTests.swift` (modify)

**Implementation**:
- Test existing Sources without `mediaTypes` field (default to `.both`)
- Test existing association files without `mediaTypes` field (load successfully)
- Test Sources created before Slice 10 work correctly (backward compatibility)
- Test invalid stored values handling (enum decoding automatically rejects invalid raw strings, per chosen approach for edge cases)

**Done when**:
- All backward compatibility tests pass
- Existing Sources work without changes verified

**Validation**:
- Run `swift test --filter SourceTests`
- Run `swift test --filter SourceAssociationTests`

---

### Task 9.3: Document Out-of-Scope: Modifying Media Types

**Objective**: Document explicit out-of-scope decision for modifying media types of existing Sources.

**Probable Touchpoints**:
- Implementation notes or documentation

**Implementation**:
- Document that this slice does not provide a command to modify media types for already-attached Sources
- Document that manual editing of `.mediahub/sources/associations.json` is **not recommended** (safety risk: file corruption, invalid JSON, format changes may break compatibility)
- Note future possibility: A future slice may add `source detach`/`source update` commands, but this is explicitly deferred
- Ensure no implementation assumes `source detach` exists

**Done when**:
- Out-of-scope decision documented
- Manual editing marked as not recommended (safety risk)
- No implementation dependency on non-existent `source detach` command

**Validation**:
- Review implementation for any assumptions about `source detach` command

---

## Task 10: Test Coverage Audit

**Plan Reference**: Step 9 (lines 317-355)  
**Spec Reference**: Acceptance Scenarios (lines 379-457)  
**Dependencies**: Tasks 1-9

### Task 10.1: Audit Test Coverage Against Acceptance Scenarios

**Objective**: Verify all 8 acceptance scenarios from spec are covered by existing tests (no new test files needed).

**Probable Touchpoints**:
- Review all test files created/modified in Tasks 1-9

**Implementation**:
- Create coverage matrix mapping Acceptance Scenarios 1-8 to existing test tasks:
  1. Attach Source with images-only filter → Task 3.3, Task 5.3
  2. Attach Source with videos-only filter → Task 3.3, Task 5.3
  3. Attach Source with default (both) filter → Task 3.3, Task 5.3
  4. Backward compatibility (existing Source without field) → Task 1.3, Task 2.2, Task 9.2
  5. Status command with statistics (index available) → Task 8.5
  6. Status command without statistics (index missing) → Task 8.5
  7. Invalid media types value → Task 3.2, Task 3.3
  8. Source list shows media types → Task 6.3
- Verify each scenario has corresponding tests in existing test tasks
- Identify any gaps in coverage (if any)
- Document coverage matrix

**Done when**:
- Coverage matrix created
- All 8 acceptance scenarios mapped to existing test tasks
- Any coverage gaps identified and documented (if any)

**Validation**:
- Review test files from Tasks 1-9
- Verify coverage matrix is complete
- Run full test suite: `swift test`
- Verify all acceptance scenarios pass

---

## Task Summary

**Total Tasks**: 10 major tasks with 29 subtasks

**Implementation Sequence**:
1. Tasks 1-2: Data model and persistence (foundation)
2. Tasks 3-5: CLI parsing and scan filtering (core logic)
3. Task 6: Source list output (can be done in parallel)
4. Tasks 7-8: Statistics computation and status integration (can be done in parallel with 1-6)
5. Tasks 9-10: Backward compatibility and comprehensive testing

**Validation Checks** (explicit tasks):
- Task 4.1: Media type classification source of truth
- Task 7.1: Year extraction reliability
- Task 8.1: JSON output convention
- Task 9.1: Invalid stored values handling

**Critical Path**:
- Tasks 1 → 2 → 3 → 4 → 5 (source media types filtering)
- Tasks 7 → 8 (library statistics)
- Tasks 9-10 (compatibility and testing) depend on all previous tasks
