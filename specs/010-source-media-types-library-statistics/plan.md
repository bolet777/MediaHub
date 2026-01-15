# Implementation Plan: Source Media Types + Library Statistics (Slice 10)

**Feature**: Source Media Types + Library Statistics  
**Specification**: `specs/010-source-media-types-library-statistics/spec.md`  
**Slice**: 10 - Source Media Types + Library Statistics  
**Created**: 2026-01-27

## Plan Scope

This plan implements **Slice 10 only**, which adds source media type filtering (images/videos/both) and library statistics (total items, by year, by media type) computed from BaselineIndex.

**Key Features**:
- Source media type configuration via `--media-types` flag on `source attach` command
- Media type filtering during Source scanning (affects both `detect` and `import`)
- Persistence of media types in Source association storage (backward compatible)
- Library statistics computation from BaselineIndex (total items, by year, by media type)
- Statistics display in `status` command (human-readable and JSON)
- Media types display in `source list` command output

**Explicitly out of scope**:
- UI or desktop app work
- New commands (extends existing `source attach`, `source list`, `status`)
- Modifying media types for existing Sources: This slice does not provide a command to modify media types for already-attached Sources. Users must manually edit the association file (`.mediahub/sources/associations.json`) or wait for a future slice that adds `source detach`/`source update` commands. This is explicitly out of scope to keep implementation simple.
- Performance refactors (unless strictly required)
- Changes to existing slices' behavior (additions and backward-compatible extensions allowed)

## Constitutional Compliance

This plan adheres to the MediaHub Constitution:

- **Safe Operations (3.3)**: Media type filtering is read-only (no file modifications); statistics computation is read-only
- **Data Safety (4.1)**: Media type filtering does not modify files or library structure; backward compatibility ensures existing Sources continue to work
- **Deterministic Behavior (3.4)**: Same Source configuration produces same filtering results; same BaselineIndex produces same statistics
- **Transparent Storage (3.2)**: Media types stored in transparent JSON format (Source association storage); statistics computed from transparent BaselineIndex
- **Simplicity of User Experience (3.1)**: Simple flag-based configuration; clear output formatting; backward compatible defaults

## Work Breakdown

### Step 1: Data Model Extension - Source Media Types

**Objective**: Extend `Source` struct to include optional `mediaTypes` field with backward-compatible defaulting.

**Responsibilities**:
- Add `mediaTypes` field to `Source` struct (optional String: "images", "videos", or "both")
- Implement default value handling (absent field → "both")
- Ensure Codable conformance handles optional field correctly
- Validate media types values ("images", "videos", "both" only)

**Files to Modify**:
- `Sources/MediaHub/Source.swift`: Add `mediaTypes` field with default value handling

**Key Decisions**:
- Field type: `String?` (optional) vs `String` with default in init
- Default value strategy: `nil` → "both" in getter vs default in init
- Validation: Where to validate (Source init vs CLI parsing)

**Validation Points**:
- Existing Sources without `mediaTypes` field decode successfully
- Default value "both" is applied when field is absent
- Invalid stored values are handled gracefully (per spec: fallback to "both" with warning, or error)

**Risks & Open Questions**:
- How to handle invalid stored values? (Spec allows either fallback or error; choose one consistently)
- Should validation occur at Source struct level or only at CLI level?

**Done Criteria**:
- `Source` struct includes optional `mediaTypes` field
- Codable decoding handles absent field (defaults to "both")
- Unit tests verify backward compatibility (Sources without field work correctly)

---

### Step 2: Source Association Storage Extension

**Objective**: Extend Source association storage to persist `mediaTypes` field.

**Responsibilities**:
- Ensure `SourceAssociation` serialization/deserialization handles optional `mediaTypes` field
- Verify atomic write pattern preserves new field
- Ensure backward compatibility (existing associations without field continue to work)

**Files to Review/Modify**:
- `Sources/MediaHub/SourceAssociation.swift`: Verify `Source` Codable conformance works with optional field
- No changes needed if `Source` Codable handles optional field correctly (delegates to Source struct)

**Key Decisions**:
- No changes needed if `Source` struct Codable handles optional field correctly
- Verify that `SourceAssociationSerializer` correctly serializes/deserializes Sources with optional fields

**Validation Points**:
- Existing association files (without `mediaTypes`) load successfully
- New association files include `mediaTypes` field when set
- Round-trip serialization preserves `mediaTypes` value

**Risks & Open Questions**:
- Verify JSON encoding/decoding behavior with optional Codable fields (should omit nil, decodeIfPresent for absent)

**Done Criteria**:
- Source associations persist `mediaTypes` field when present
- Existing associations (without field) load successfully
- Unit tests verify persistence and backward compatibility

---

### Step 3: CLI Parsing - Source Attach Command

**Objective**: Add `--media-types` flag to `source attach` command with validation.

**Responsibilities**:
- Add `@Option` flag for `--media-types` with case-insensitive parsing
- Validate flag value ("images", "videos", "both" only)
- Pass media types value to Source creation
- Handle default case (flag omitted → "both")

**Files to Modify**:
- `Sources/MediaHubCLI/SourceCommand.swift`: Add `@Option` flag and validation logic

**Key Decisions**:
- Flag parsing: Case-insensitive vs case-sensitive (spec says case-insensitive)
- Validation location: CLI parsing vs Source struct (CLI parsing preferred for early error)
- Error message format: Clear, suggests valid values

**Validation Points**:
- Valid values ("images", "videos", "both") accepted (case-insensitive)
- Invalid values result in clear error message and exit code 1
- Omitted flag defaults to "both"
- Error message suggests valid values

**Risks & Open Questions**:
- ArgumentParser case-insensitive option parsing (may need manual normalization)

**Done Criteria**:
- `--media-types` flag accepts "images", "videos", "both" (case-insensitive)
- Invalid values produce clear error message
- Omitted flag defaults to "both"
- Unit/integration tests verify flag parsing and validation

---

### Step 4: Source Scanning Integration - Media Type Filtering

**Objective**: Integrate media type filtering into Source scanning, before candidates are added to result set.

**Responsibilities**:
- Add media type filtering logic to the source scanning component
- Filter files by extension using existing media type classification (single source of truth)
- Apply filter based on Source's `mediaTypes` setting ("images", "videos", or "both")
- Ensure filtering occurs before candidates are added to result set

**Probable Touchpoints**:
- Source scanning component (likely `Sources/MediaHub/SourceScanning.swift`): Add filtering logic during scan enumeration

**Key Decisions**:
- Filtering point: During scan enumeration (preferred for performance) vs after scan completes
- Classification reuse: Use existing media type classification extension sets (single source of truth, no duplication)
- Performance: Filtering must be O(1) per file (extension check only, no additional I/O)

**Validation Points**:
- "images" filter: Only image files included in candidates
- "videos" filter: Only video files included in candidates
- "both" filter: Both images and videos included (no filtering)
- Unknown extensions excluded (consistent with existing behavior)
- Performance: Filtering is O(1) per file (extension check only, no additional I/O)

**Risks & Open Questions**:
- Verify `MediaFileFormat` extension sets are the single source of truth (no divergence)
- Ensure filtering logic matches existing classification exactly

**Done Criteria**:
- Source scanning filters by media type based on Source configuration
- Filtering uses existing media type classification (no duplication, single source of truth)
- Unit tests verify filtering for each media type setting
- Performance validation confirms O(1) per file, no additional I/O

---

### Step 5: Detection and Import Integration

**Objective**: Verify that media type filtering in scanning automatically affects `detect` and `import` operations.

**Responsibilities**:
- Verify that detection pipeline uses filtered scan results (no additional filtering needed)
- Verify that import pipeline processes only filtered candidates (inherits from detection)
- Ensure no duplicate filtering logic (single source of truth: scan stage)

**Probable Touchpoints**:
- Detection orchestration component: Verify uses filtered scan results
- Import execution component: Verify processes detection results (already filtered)

**Key Decisions**:
- No changes needed if detection/import already use scan results (verify flow)
- Ensure no additional filtering logic is added (filtering happens once at scan stage)

**Validation Points**:
- `detect` command results reflect only files matching Source's media type filter
- `import` command processes only files matching Source's media type filter
- No duplicate filtering occurs (single filter at scan stage)

**Risks & Open Questions**:
- Verify detection/import flow: scan → detection → import (filtering at scan affects both)

**Done Criteria**:
- Detection results reflect media type filtering (integration test)
- Import processes only filtered files (integration test)
- No duplicate filtering logic exists

---

### Step 6: Source List Output Extension

**Objective**: Extend `source list` command to display media types for each Source.

**Responsibilities**:
- Add media types display to human-readable output
- Add `mediaTypes` field to JSON output
- Handle default case (display "both" when field absent)

**Files to Modify**:
- `Sources/MediaHubCLI/OutputFormatting.swift`: Extend `SourceListFormatter` to include media types

**Key Decisions**:
- Human-readable format: "Media types: images" vs "Media types: images, videos" (spec shows single value)
- JSON field: Include `mediaTypes` field for all Sources (default "both" when absent)

**Validation Points**:
- Human-readable output shows "Media types: images", "Media types: videos", or "Media types: both"
- JSON output includes `mediaTypes` field for each Source
- Default "both" displayed when field absent

**Risks & Open Questions**:
- Verify SourceListFormatter structure and extension points

**Done Criteria**:
- `source list` displays media types in human-readable output
- `source list --json` includes `mediaTypes` field in JSON output
- Unit/integration tests verify output formatting

---

### Step 7: Library Statistics Computation

**Objective**: Implement library statistics computation from BaselineIndex (total items, by year, by media type).

**Responsibilities**:
- Create statistics computation logic (single pass over BaselineIndex entries)
- Extract year from normalized paths (first path component, YYYY pattern)
- Classify media type from file extension (reuse `MediaFileFormat` classification)
- Handle edge cases (paths not following YYYY/MM pattern, unknown extensions)

**Files to Create/Modify**:
- `Sources/MediaHub/LibraryStatistics.swift`: New file with statistics computation logic
  - `LibraryStatistics` struct (totalItems, byYear, byMediaType)
  - `LibraryStatisticsComputer` struct (compute from BaselineIndex)

**Key Decisions**:
- Year extraction: Extract from first path component, validate YYYY pattern (4 digits)
- **Default decision for unknown year**: If year cannot be extracted reliably, use "unknown" bucket in byYear statistics (items counted in total, grouped under "unknown" key)
- Media type classification: Reuse existing media type classification extension sets (single source of truth, same as scan filtering)
- Unknown extension handling: Exclude from "by media type" but count in total (per spec)
- Performance: Single pass over entries, O(n) where n is entry count, no additional I/O

**Validation Points** (from spec Planning Note):
- **CRITICAL**: Validate that year extraction from BaselineIndex paths is reliable
- If validation reveals paths may not consistently follow `YYYY/MM/...` pattern, implement "unknown" bucket as default fallback
- Verify year extraction works for adopted libraries and edge cases

**Risks & Open Questions**:
- **Year extraction reliability**: Validate against real BaselineIndex data; if unreliable, use "unknown" bucket (default decision)
- **Media type classification**: Ensure uses same logic as scan filtering (no divergence, single source of truth)
- **Performance**: Single pass, O(n) complexity, no additional I/O operations

**Done Criteria**:
- Statistics computation extracts year from paths (with "unknown" bucket fallback if needed)
- Statistics computation classifies media types using existing classification logic (single source of truth)
- Unit tests verify statistics computation for various path patterns (including "unknown" year cases)
- Performance validation confirms single pass, O(n) complexity, no additional I/O

---

### Step 8: Status Command Integration - Statistics Display

**Objective**: Extend `status` command to display library statistics when BaselineIndex is available.

**Responsibilities**:
- Integrate statistics computation into `StatusCommand`
- Add statistics section to human-readable output (after library metadata, before hash coverage)
- Add `statistics` field to JSON output (omitted when BaselineIndex unavailable)
- Handle missing/invalid index gracefully ("N/A" in human-readable, omitted in JSON)

**Files to Modify**:
- `Sources/MediaHubCLI/StatusCommand.swift`: Load BaselineIndex and compute statistics
- `Sources/MediaHubCLI/OutputFormatting.swift`: Extend `StatusFormatter` to include statistics

**Key Decisions**:
- JSON field handling: Omit `statistics` field when unavailable (not null, following `hashCoverage` pattern exactly)
- Output order: Statistics after library metadata, before hash coverage
- Missing index: Report as "N/A" (human-readable) or omit (JSON), not error

**Validation Points** (from spec):
- **CRITICAL**: Verify JSON output convention matches `hashCoverage` pattern exactly: optional Codable field, omitted when nil (not set to null)
- Statistics displayed when BaselineIndex available
- Statistics omitted/not displayed when BaselineIndex missing or invalid
- JSON schema backward compatible (existing fields unchanged, new field optional)

**Risks & Open Questions**:
- Verify JSON encoding behavior: Optional Codable fields are omitted (not null) when nil
- Ensure statistics JSON structure matches spec (byYear keys as strings, byMediaType structure)

**Done Criteria**:
- `status` command displays statistics when BaselineIndex available
- `status` command handles missing index gracefully (no error, "N/A" or omitted)
- JSON output follows existing conventions (omit when unavailable, not null)
- Unit/integration tests verify output formatting and edge cases

---

### Step 9: Testing Strategy

**Objective**: Add comprehensive tests for media type filtering and library statistics.

**Test Files to Create/Modify**:

**New Test File**: `Tests/MediaHubTests/SourceMediaTypesTests.swift`
- Unit tests for Source media types field (defaulting, persistence)
- Unit tests for Source scanning filtering (images, videos, both)
- Integration tests for detect/import with media type filtering

**Modify Existing**:
- `Tests/MediaHubTests/SourceTests.swift`: Add tests for `mediaTypes` field Codable
- `Tests/MediaHubTests/SourceAssociationTests.swift`: Add tests for persistence of `mediaTypes`
- `Tests/MediaHubTests/SourceScanningTests.swift`: Add tests for media type filtering
- `Tests/MediaHubTests/DetectionOrchestrationTests.swift`: Add tests for filtered detection results
- `Tests/MediaHubTests/ImportExecutionTests.swift`: Add tests for filtered import (if needed)
- `Tests/MediaHubTests/BaselineIndexTests.swift`: Add tests for statistics computation (or create new file)

**New Test File**: `Tests/MediaHubTests/LibraryStatisticsTests.swift`
- Unit tests for statistics computation (year extraction, media type classification)
- Unit tests for edge cases (unknown year, unknown extensions)
- Integration tests for status command with statistics

**Test Coverage**:
- Acceptance Scenario 1: Attach Source with images-only filter
- Acceptance Scenario 2: Attach Source with videos-only filter
- Acceptance Scenario 3: Attach Source with default (both) filter
- Acceptance Scenario 4: Backward compatibility (existing Source without field)
- Acceptance Scenario 5: Status command with statistics (index available)
- Acceptance Scenario 6: Status command without statistics (index missing)
- Acceptance Scenario 7: Invalid media types value
- Acceptance Scenario 8: Source list shows media types

**Done Criteria**:
- All acceptance scenarios covered by tests
- Unit tests for core logic (filtering, statistics computation)
- Integration tests for CLI commands
- Backward compatibility tests pass

---

## Validation Checks (During Implementation)

These checks MUST be performed during implementation to ensure alignment with existing codebase patterns:

### 1. Year Extraction Validation

**Check**: Validate that year extraction from BaselineIndex paths is reliable.

**Action Items**:
- Load sample BaselineIndex files (from real libraries, adopted libraries)
- Verify paths consistently follow `YYYY/MM/...` pattern
- Test edge cases: adopted libraries, manually organized folders, edge path patterns
- **Default decision if validation reveals issues**: Implement "unknown" bucket in byYear statistics (items with unextractable year are grouped under "unknown" key, still counted in total)

**Decision Point**: If year extraction is not reliable, use "unknown" bucket as default fallback (Option A). Only consider alternatives (Option B: report "N/A", Option C: extract from mtime) if "unknown" bucket proves insufficient.

### 2. JSON Output Convention Validation

**Check**: Verify JSON output convention (omit vs null) matches existing `hashCoverage` pattern exactly.

**Action Items**:
- Review `StatusFormatter.formatJSON()` implementation
- Verify `hashCoverage` field behavior: optional Codable field, omitted when nil (not set to null)
- Ensure `statistics` field follows identical pattern: optional Codable field, omitted when nil (not set to null)
- Test JSON encoding: Optional Codable fields with nil values are omitted (Swift JSONEncoder default behavior)
- Verify JSON structure: `statistics` field structure matches spec (byYear keys as strings, byMediaType structure)

**Decision Point**: `statistics` field MUST match `hashCoverage` pattern exactly: optional Codable, omitted when unavailable (not null). This is a hard requirement for consistency.

### 3. Media Type Classification Source of Truth

**Check**: Verify single source of truth for media type classification (no duplication, no divergence).

**Action Items**:
- Identify the existing media type classification component (extension sets for images/videos)
- Ensure statistics computation uses same extension sets (no duplication, reference existing component)
- Ensure scan filtering uses same extension sets (no divergence, reference existing component)
- Document that existing classification component is the single source of truth
- Verify both scan filtering and statistics computation reference the same classification logic

**Decision Point**: No divergence allowed. Both scan filtering and statistics computation MUST reference the same existing classification component (single source of truth).

### 4. Modifying Media Types for Existing Sources

**Check**: Clarify workflow for modifying media types of existing Sources (explicitly out of scope for this slice).

**Action Items**:
- Verify `source detach` command does not exist (out of scope P1 per Slice 4)
- Document explicit out-of-scope decision: This slice does not provide a command to modify media types for already-attached Sources
- Document workaround: Users can manually edit `.mediahub/sources/associations.json` to change `mediaTypes` field (with appropriate warnings about manual editing)
- Note future possibility: A future slice may add `source detach`/`source update` commands, but this is explicitly deferred
- Ensure no implementation assumes `source detach` exists

**Decision Point**: Explicitly out of scope. Document manual workaround (association file editing) and note that proper command support is deferred to a future slice. No implementation dependency on non-existent `source detach` command.

### 5. Invalid Stored Values Handling

**Check**: Choose approach for handling invalid `mediaTypes` values in stored associations.

**Action Items**:
- Review spec: Option 1 (fallback to "both" with warning) vs Option 2 (error)
- Choose one approach consistently
- Implement chosen approach in Source loading/decoding
- Add tests for invalid value handling

**Decision Point**: Implement either fallback with warning (preferred) or error (alternative), consistently.

---

## Implementation Sequence

Recommended implementation order (can be parallelized where dependencies allow):

1. **Step 1-2**: Data model extension (Source struct, association storage) - Foundation
2. **Step 3**: CLI parsing (source attach flag) - Can be done in parallel with Step 4
3. **Step 4**: Source scanning integration (filtering) - Core logic
4. **Step 5**: Detection/import integration (verification) - Depends on Step 4
5. **Step 6**: Source list output - Can be done in parallel with Step 7-8
6. **Step 7**: Statistics computation - Core logic (with validation checks)
7. **Step 8**: Status command integration - Depends on Step 7
8. **Step 9**: Testing - Throughout, but comprehensive coverage at end

---

## Non-Functional Requirements

- **NFR-001**: Media type filtering MUST not significantly impact scan performance (O(1) per file check, no additional I/O, extension-based classification only)
- **NFR-002**: Statistics computation MUST be efficient (single pass over BaselineIndex entries, O(n) where n is entry count, no additional I/O operations)
- **NFR-003**: Source association storage format extension MUST be backward compatible (existing Sources without `mediaTypes` field must work)
- **NFR-004**: Status command output MUST remain readable and well-formatted with statistics addition
- **NFR-005**: JSON output schema MUST be backward compatible (existing fields unchanged, new fields optional or omitted when unavailable, following `hashCoverage` pattern exactly)

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Year extraction unreliable | Medium | Validation check #1: Test with real BaselineIndex data, implement fallback if needed |
| JSON output convention mismatch | Low | Validation check #2: Review existing patterns, ensure consistency |
| Media type classification divergence | High | Validation check #3: Single source of truth (`MediaFileFormat`), no duplication |
| Detach/re-attach workflow unclear | Low | Validation check #4: Document chosen approach, defer to future slice if needed |
| Invalid stored values handling | Low | Validation check #5: Choose approach consistently, add tests |

---

## Success Criteria

The implementation is complete when:

1. ✅ `source attach --media-types` flag works with validation
2. ✅ Source scanning filters by media type (images, videos, both)
3. ✅ Detection and import respect media type filtering
4. ✅ Source associations persist `mediaTypes` field (backward compatible)
5. ✅ `source list` displays media types
6. ✅ `status` command displays library statistics (when BaselineIndex available)
7. ✅ Statistics computation is efficient (single pass, O(n), no additional I/O)
8. ✅ All acceptance scenarios pass
9. ✅ Backward compatibility verified (existing Sources work without changes)
10. ✅ Validation checks completed and documented (year extraction, JSON conventions, classification source of truth, modify workflow, invalid values)
