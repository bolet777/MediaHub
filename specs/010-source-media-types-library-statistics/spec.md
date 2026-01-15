# Feature Specification: Source Media Types + Library Statistics

**Feature Branch**: `010-source-media-types-library-statistics`  
**Created**: 2026-01-27  
**Status**: Draft  
**Input**: User description: "Add source media type filtering (images/videos/both) and library statistics (total, by year, by type) via BaselineIndex"

## Problem Statement

MediaHub currently processes all media types (images and videos) from Sources without distinction. Users need the ability to:

1. **Filter Sources by media type**: Some Sources may contain only images or only videos, and users should be able to configure Sources to process only specific media types
2. **View library statistics**: Users need visibility into library content including total items, distribution by year, and distribution by media type to understand library composition and health

Without media type filtering, users cannot selectively import images or videos from Sources that contain both. Without library statistics, users lack visibility into library composition and growth patterns.

## Goals

1. **Enable source media type filtering**: Each Source MUST define which media types it processes (images, videos, or both)
2. **Persist media type configuration**: Source media type settings MUST be persisted and survive application restarts
3. **Apply filtering at scan stage**: Media type filtering MUST occur during Source scanning, affecting both `detect` and `import` operations
4. **Maintain backward compatibility**: Existing Sources without media type configuration MUST default to processing both images and videos
5. **Provide library statistics**: Library statistics (total items, by year, by media type) MUST be computed from BaselineIndex when available
6. **Expose statistics via status command**: Library statistics MUST be displayed in `mediahub status` output (human-readable and JSON)
7. **Handle missing index gracefully**: When BaselineIndex is missing or invalid, statistics behavior MUST be clearly specified

## Non-Goals

- **No UI work**: This slice is Core / CLI only
- **No media type detection changes**: Media type detection (extension-based) remains unchanged; this slice only adds filtering
- **No new commands**: This slice extends existing commands (`source attach`, `status`) rather than introducing new commands. Modifying media types for existing Sources is out of scope (Sources must be detached and re-attached with new media types if needed).
- **No performance refactors**: No changes to existing performance characteristics unless strictly required by the spec
- **No breaking changes to existing slices**: Slices 1-9 behavior remains unchanged (additions and backward-compatible extensions are allowed)

## User-Facing CLI Contract

### Source Media Type Configuration

#### Command Syntax

```
mediahub source attach <path> [--media-types <types>] [--library <path>] [--json]
```

#### Media Types Flag

**Flag**: `--media-types <types>`

**Values**: `images`, `videos`, or `both` (case-insensitive)

**Default**: `both` (for backward compatibility)

**Description**: Specifies which media types the Source should process. When set to `images`, only image files are scanned and detected. When set to `videos`, only video files are scanned and detected. When set to `both` (or omitted), both images and videos are processed.

**Examples**:
- `mediahub source attach /path/to/photos --media-types images` - Attach Source that processes only images
- `mediahub source attach /path/to/videos --media-types videos` - Attach Source that processes only videos
- `mediahub source attach /path/to/mixed --media-types both` - Attach Source that processes both (explicit)
- `mediahub source attach /path/to/mixed` - Attach Source that processes both (default, backward compatible)

#### Behavior

1. **Validation**: Media types value MUST be validated. Invalid values (e.g., `invalid`, `image`, `video`) MUST result in an error
2. **Persistence**: Media types setting MUST be stored in Source association metadata and persist across application restarts
3. **Backward compatibility**: Existing Sources without media types setting MUST be treated as `both` (see Compatibility & Defaulting Rules section)
4. **Scan filtering**: During Source scanning, files are filtered by media type before being added to candidate list
5. **Detection impact**: `detect` command results reflect only files matching the Source's media type filter
6. **Import impact**: `import` command processes only files matching the Source's media type filter

#### Modifying Media Types for Existing Sources

**Out of scope**: This slice does not provide a command to modify media types for an already-attached Source. To change media types for an existing Source, users MUST detach the Source and re-attach it with the desired `--media-types` value. This keeps the implementation simple and avoids ambiguity about how existing detection/import state should be handled.

**Planning Note - Detach/Re-attach Workflow Validation**: During plan phase, the implementation MUST validate that requiring detach/re-attach to modify media types is consistent with existing CLI patterns and product expectations. Note: `source detach` command does not currently exist (out of scope for P1 per Slice 4). The plan MUST:
1. Confirm whether manual editing of association storage or a future `source detach` command is the intended workflow
2. Validate that re-attaching a Source (same path) is a supported workflow and does not cause issues
3. Assess if this approach aligns with user expectations (no hidden complexity or data loss)
4. If validation reveals that detach/re-attach is not viable, the plan MUST either: (a) explicitly declare a `source update` or `source configure` command as out of scope for this slice (with clear rationale), or (b) propose an alternative approach that fits within the slice scope (e.g., manual association file editing, or deferring media type modification to a future slice)

#### Source List Output

The `mediahub source list` command MUST display media types for each Source:

**Human-readable output**:
```
Attached Sources
================

1. /path/to/photos (abc123...)
   Media types: images
   Last detected: 2026-01-27T10:00:00Z

2. /path/to/videos (def456...)
   Media types: videos
   Last detected: 2026-01-27T11:00:00Z

3. /path/to/mixed (ghi789...)
   Media types: both
   Last detected: 2026-01-27T12:00:00Z
```

**JSON output**: Source objects MUST include `mediaTypes` field:
```json
{
  "sources": [
    {
      "sourceId": "abc123...",
      "type": "folder",
      "path": "/path/to/photos",
      "attachedAt": "2026-01-27T09:00:00Z",
      "lastDetectedAt": "2026-01-27T10:00:00Z",
      "mediaTypes": "images"
    },
    {
      "sourceId": "def456...",
      "type": "folder",
      "path": "/path/to/videos",
      "attachedAt": "2026-01-27T10:00:00Z",
      "lastDetectedAt": "2026-01-27T11:00:00Z",
      "mediaTypes": "videos"
    },
    {
      "sourceId": "ghi789...",
      "type": "folder",
      "path": "/path/to/mixed",
      "attachedAt": "2026-01-27T11:00:00Z",
      "lastDetectedAt": "2026-01-27T12:00:00Z",
      "mediaTypes": "both"
    }
  ]
}
```

### Library Statistics

#### Status Command Extension

The `mediahub status` command MUST be extended to display library statistics when BaselineIndex is available.

#### Statistics Computed

Library statistics MUST include:

1. **Total items**: Total number of media files in the library (from BaselineIndex entry count)
2. **Items by year**: Distribution of items by year (extracted from normalized library paths following the Year/Month organization pattern)
3. **Items by media type**: Distribution of items by media type (images vs videos, determined using the same classification logic as existing media detection)

**Year extraction**: Year is derived from the normalized relative path stored in BaselineIndex entries. MediaHub libraries organize media in `YYYY/MM/filename` structure (Slice 3), so the year is the first path component. If a path does not follow this pattern or year cannot be determined, the item is excluded from year distribution statistics (not counted in "by year" but still counted in total items).

**Planning Note - Year Extraction Validation**: During plan phase, the implementation MUST validate that year extraction from BaselineIndex paths is reliable. If analysis reveals that paths may not consistently follow the `YYYY/MM/...` pattern (e.g., adopted libraries, edge cases), the plan MUST either: (1) implement a fallback bucket for "unknown" year items, or (2) define an alternative extraction rule that aligns with the core library structure specification. The spec assumes reliable year extraction but allows for implementation adjustments if validation reveals edge cases.

**Media type classification**: Media type (image vs video) is determined using the same extension-based classification as existing media detection (Slice 2, ADR 005). Files with extensions not recognized as images or videos are excluded from media type distribution statistics (not counted in "by media type" but still counted in total items).

#### Human-Readable Output

**When BaselineIndex is available**:
```
Library Status
==============

Path: /path/to/library
ID: abc123...
Version: 1.0
Sources: 2

Statistics:
  Total items: 10,543
  By year:
    2024: 4,231
    2023: 3,456
    2022: 2,856
  By media type:
    Images: 8,432
    Videos: 2,111

Hash Coverage: 45% (4,500 / 10,543 entries)

Attached sources:
  1. /path/to/photos (abc123...)
     Media types: images
     Last detected: 2026-01-27T10:00:00Z
  2. /path/to/videos (def456...)
     Media types: videos
     Last detected: 2026-01-27T11:00:00Z
```

**When BaselineIndex is missing or invalid**:
```
Library Status
==============

Path: /path/to/library
ID: abc123...
Version: 1.0
Sources: 2

Statistics: N/A (baseline index not available)

Attached sources:
  1. /path/to/photos (abc123...)
     Media types: images
     Last detected: 2026-01-27T10:00:00Z
  2. /path/to/videos (def456...)
     Media types: videos
     Last detected: 2026-01-27T11:00:00Z
```

#### JSON Output

**When BaselineIndex is available**:
```json
{
  "library": {
    "path": "/path/to/library",
    "id": "abc123...",
    "version": "1.0"
  },
  "sources": {
    "count": 2,
    "items": [
      {
        "sourceId": "abc123...",
        "type": "folder",
        "path": "/path/to/photos",
        "attachedAt": "2026-01-27T09:00:00Z",
        "lastDetectedAt": "2026-01-27T10:00:00Z",
        "mediaTypes": "images"
      },
      {
        "sourceId": "def456...",
        "type": "folder",
        "path": "/path/to/videos",
        "attachedAt": "2026-01-27T10:00:00Z",
        "lastDetectedAt": "2026-01-27T11:00:00Z",
        "mediaTypes": "videos"
      }
    ]
  },
  "statistics": {
    "totalItems": 10543,
    "byYear": {
      "2024": 4231,
      "2023": 3456,
      "2022": 2856
    },
    "byMediaType": {
      "images": 8432,
      "videos": 2111
    }
  },
  "hashCoverage": {
    "percentage": 0.45,
    "entriesWithHash": 4500,
    "totalEntries": 10543
  }
}
```

**When BaselineIndex is missing or invalid**:
```json
{
  "library": {
    "path": "/path/to/library",
    "id": "abc123...",
    "version": "1.0"
  },
  "sources": {
    "count": 2,
    "items": [
      {
        "sourceId": "abc123...",
        "type": "folder",
        "path": "/path/to/photos",
        "attachedAt": "2026-01-27T09:00:00Z",
        "lastDetectedAt": "2026-01-27T10:00:00Z",
        "mediaTypes": "images"
      },
      {
        "sourceId": "def456...",
        "type": "folder",
        "path": "/path/to/videos",
        "attachedAt": "2026-01-27T10:00:00Z",
        "lastDetectedAt": "2026-01-27T11:00:00Z",
        "mediaTypes": "videos"
      }
    ]
  }
}
```

Note: `statistics` field is omitted (not present) when BaselineIndex is unavailable, following the same pattern as `hashCoverage`.

**Note on JSON output behavior**: When BaselineIndex is absent or invalid, the `statistics` field MUST be omitted from JSON output (not set to `null`). This follows the same pattern as `hashCoverage` in Slice 9, where optional fields are omitted rather than set to null. When BaselineIndex is available, `statistics` is a non-null object. The `hashCoverage` field behavior remains unchanged from Slice 9 (omitted when index is unavailable).

## Safety Guarantees and Constraints

### Compatibility & Defaulting Rules

**Source Media Types Defaulting**:
- When `mediaTypes` field is absent from Source association storage, the Source MUST be treated as `mediaTypes: "both"`
- This applies to all Sources created before Slice 10 (backward compatibility)
- This applies to Sources where the field was never set (default behavior)

**Invalid Stored Values**:
- If a Source association contains an invalid `mediaTypes` value (not "images", "videos", or "both"), the behavior MUST be:
  - Option 1 (preferred): Fallback to `"both"` with a warning logged (non-fatal, allows library to function)
  - Option 2 (alternative): Treat as error during Source loading (fatal, requires manual fix)
  - Implementation MUST choose one approach consistently
- Invalid values MUST NOT cause silent failures or undefined behavior

**JSON Schema Stability**:
- The `mediaTypes` field in Source association storage MUST be optional (not required)
- The field MUST be stable: once set, it persists and is not automatically changed
- Source association format versioning (ADR 003) applies: format version remains "1.0" but schema is extended with optional field

**Backward Compatibility Summary**:
1. **Existing Sources**: Sources created before Slice 10 MUST default to `mediaTypes: "both"` when media types field is absent
2. **Source association format**: Source association storage format MUST be extended to include optional `mediaTypes` field
3. **Migration**: No migration script is required; default behavior handles existing Sources
4. **API compatibility**: Source data structure MUST include optional `mediaTypes` field with default value handling

### Data Integrity

1. **Media type detection**: Media type filtering uses the same extension-based classification as existing media detection (Slice 2, ADR 005). The classification logic MUST be identical to what is used in `detect` and `import` operations today.
2. **No file modification**: Media type filtering does not modify files or library structure
3. **Deterministic filtering**: Same Source configuration produces same filtering results
4. **Unknown extensions**: Files with extensions not recognized as images or videos by the existing classification system are excluded from processing (consistent with existing behavior)

### Error Handling

1. **Invalid media types value**: Invalid `--media-types` values MUST result in clear error message and exit code 1
2. **Missing index**: When BaselineIndex is missing, statistics MUST be reported as "N/A" (human-readable) or omitted (JSON), not as an error
3. **Invalid index**: When BaselineIndex is invalid (corrupted, unsupported version), statistics MUST be reported as "N/A" (human-readable) or omitted (JSON), not as an error

## Determinism and Idempotence Rules

### Deterministic Behavior

1. **Stable filtering**: Media type filtering produces deterministic results based on file extensions (uses the same classification as existing media detection)
2. **Consistent statistics**: Same BaselineIndex produces same statistics (year extraction from normalized paths, media type from file extensions using existing classification)
3. **Predictable output**: Same library state produces same status output format

### Idempotence Rules

1. **Source attachment**: Re-attaching a Source with same media types produces same result (idempotent if Source already exists)
2. **Statistics computation**: Statistics computation is read-only and idempotent (no state changes)

## Implementation Constraints

### Source Media Types Storage

1. **Storage location**: Media types MUST be stored in Source association storage (as defined in ADR 003)
2. **Field name**: Media types field MUST be named `mediaTypes` (camelCase, string value: "images", "videos", or "both")
3. **Optional field**: Media types field MUST be optional in Source association schema for backward compatibility
4. **Default handling**: When `mediaTypes` field is absent, MUST default to `"both"` (see Compatibility & Defaulting Rules)

### Source Scanning Integration

1. **Filtering point**: Media type filtering MUST occur during Source scanning, before candidates are added to the result set
2. **Classification logic**: Media type determination MUST use the same extension-based classification as existing media detection (Slice 2, ADR 005)
3. **Performance**: Filtering MUST not significantly impact scan performance (target: < 5% overhead per file, O(1) per file check)

### Statistics Computation

1. **Data source**: Statistics MUST be computed from BaselineIndex entries (not from filesystem scan)
2. **Year extraction**: Year MUST be extracted from normalized relative paths stored in BaselineIndex entries, following the library's Year/Month organization pattern
3. **Media type determination**: Media type MUST be determined from file extension using the same classification logic as existing media detection
4. **Performance**: Statistics computation MUST be efficient (single pass over index entries, O(n) where n is entry count, target: < 1 second for 10,000 entries)
5. **Missing index handling**: When BaselineIndex is missing or invalid, statistics MUST NOT trigger error; MUST report as unavailable (see Error Handling)

### Status Command Integration

1. **Statistics display**: Statistics section MUST appear after library metadata and before hash coverage (if available)
2. **Conditional display**: Statistics section MUST only appear when BaselineIndex is available and valid
3. **Format consistency**: Statistics output format MUST be consistent between human-readable and JSON (same data, different presentation)
4. **JSON field handling**: The `statistics` field in JSON output MUST be omitted (not set to null) when BaselineIndex is unavailable, following the same pattern as `hashCoverage`

## Acceptance Scenarios

### Scenario 1: Attach Source with Images-Only Filter

**Given**: A library exists at `/path/to/library`  
**When**: User runs `mediahub source attach /path/to/photos --media-types images --library /path/to/library`  
**Then**:
- Source is attached successfully
- Source has `mediaTypes: "images"` in association storage
- Running `mediahub detect --library /path/to/library` only detects image files from that Source
- Running `mediahub import --library /path/to/library` only imports image files from that Source

### Scenario 2: Attach Source with Videos-Only Filter

**Given**: A library exists at `/path/to/library`  
**When**: User runs `mediahub source attach /path/to/videos --media-types videos --library /path/to/library`  
**Then**:
- Source is attached successfully
- Source has `mediaTypes: "videos"` in association storage
- Running `mediahub detect --library /path/to/library` only detects video files from that Source
- Running `mediahub import --library /path/to/library` only imports video files from that Source

### Scenario 3: Attach Source with Default (Both) Filter

**Given**: A library exists at `/path/to/library`  
**When**: User runs `mediahub source attach /path/to/mixed --library /path/to/library` (no `--media-types` flag)  
**Then**:
- Source is attached successfully
- Source has `mediaTypes: "both"` (or field absent, defaulting to "both") in association storage
- Running `mediahub detect --library /path/to/library` detects both image and video files from that Source
- Running `mediahub import --library /path/to/library` imports both image and video files from that Source

### Scenario 4: Backward Compatibility - Existing Source

**Given**: A library exists with a Source attached before Slice 10 (no `mediaTypes` field in association storage)  
**When**: User runs `mediahub detect --library /path/to/library`  
**Then**:
- Source is loaded successfully (no error)
- Source is treated as `mediaTypes: "both"` (default behavior)
- Detection processes both images and videos from that Source

### Scenario 5: Status Command with Statistics (Index Available)

**Given**: A library exists at `/path/to/library` with BaselineIndex containing 10,543 entries  
**When**: User runs `mediahub status --library /path/to/library`  
**Then**:
- Status output includes statistics section
- Statistics show total items: 10,543
- Statistics show distribution by year (extracted from paths)
- Statistics show distribution by media type (images vs videos)
- Output format matches specification (human-readable or JSON based on flags)

### Scenario 6: Status Command without Statistics (Index Missing)

**Given**: A library exists at `/path/to/library` without BaselineIndex (or invalid index)  
**When**: User runs `mediahub status --library /path/to/library`  
**Then**:
- Human-readable output shows "Statistics: N/A (baseline index not available)"
- JSON output omits the `statistics` field entirely (not set to null)
- No error is reported (missing index is not an error for statistics)
- Other status information (library metadata, sources) is displayed normally

### Scenario 7: Invalid Media Types Value

**Given**: A library exists at `/path/to/library`  
**When**: User runs `mediahub source attach /path/to/photos --media-types invalid --library /path/to/library`  
**Then**:
- Command exits with error code 1
- Error message clearly indicates invalid media types value
- Error message suggests valid values: "images", "videos", "both"
- Source is not attached

### Scenario 8: Source List Shows Media Types

**Given**: A library exists with multiple Sources (images-only, videos-only, both)  
**When**: User runs `mediahub source list --library /path/to/library`  
**Then**:
- Output shows media types for each Source
- Human-readable output displays "Media types: images", "Media types: videos", or "Media types: both"
- JSON output includes `mediaTypes` field for each Source

## Key Entities

- **Source Media Types**: Configuration setting per Source that determines which media types (images, videos, or both) are processed during scanning, detection, and import. Stored in Source association metadata.

- **Library Statistics**: Aggregate information about library content computed from BaselineIndex, including total items, distribution by year, and distribution by media type. Displayed in `status` command output.

- **Year Distribution**: Count of items per year, extracted from normalized relative paths stored in BaselineIndex entries. Year is derived from the library's Year/Month organization pattern (Slice 3). Items whose paths do not follow this pattern are excluded from year distribution but still counted in total items.

- **Media Type Distribution**: Count of items by media type (images vs videos), determined using the same extension-based classification as existing media detection (Slice 2, ADR 005). Items with unrecognized extensions are excluded from media type distribution but still counted in total items.

## Non-Functional Requirements

- **NFR-001**: Media type filtering MUST not significantly impact scan performance (target: < 5% overhead per file)
- **NFR-002**: Statistics computation MUST complete in reasonable time (target: O(n) where n is BaselineIndex entry count, < 1 second for 10,000 entries)
- **NFR-003**: Source association storage format extension MUST be backward compatible (existing Sources without `mediaTypes` field must work)
- **NFR-004**: Status command output MUST remain readable and well-formatted with statistics addition
- **NFR-005**: JSON output schema MUST be backward compatible (existing fields unchanged, new fields optional or omitted when unavailable, following existing JSON output conventions)
