# ADR 007: Detection Result Storage

**Status**: Accepted  
**Date**: 2026-01-12  
**Component**: Detection Result Model & Storage (Component 6)  
**Task**: 6.3

## Context

MediaHub needs to store detection results in an explainable, auditable format. Detection results must:

- Be stored persistently (FR-010)
- Be explainable (FR-013, SC-007)
- Be auditable (FR-013)
- Support comparison across detection runs (User Story 3, Acceptance Scenario 5)
- Be stored in transparent, human-readable format (FR-017)

## Decision

### Storage Location

Detection results are stored within the Library structure at: `.mediahub/sources/{sourceId}/detections/` directory.

**Rationale**:
- Keeps results within Library structure (consistent with associations)
- Per-Source organization enables tracking detection history per Source
- Hidden directory keeps metadata separate from user content
- Allows multiple detection runs per Source

### Storage Format

**JSON** is chosen as the result storage format.

**Rationale**:
- Transparent and human-readable (FR-017)
- Readable by standard system tools without MediaHub
- Widely supported across platforms
- Easy to parse and validate
- Extensible for future requirements
- Consistent with other metadata formats (ADR 001, ADR 003)

### Storage Strategy

**One file per detection run**: Each detection run produces a separate result file: `.mediahub/sources/{sourceId}/detections/{timestamp}.json`

**Rationale**:
- Enables comparison across detection runs
- Maintains detection history
- Clear timestamp-based naming
- Easy to identify latest detection

**File Naming**: ISO-8601 timestamp format (e.g., `2026-01-12T10:30:45Z.json`) ensures sortable, unique filenames.

### Result Schema

The detection result JSON schema:

```json
{
  "version": "1.0",
  "sourceId": "uuid-v4-string",
  "libraryId": "uuid-v4-string",
  "detectedAt": "ISO-8601-timestamp",
  "candidates": [
    {
      "item": {
        "path": "absolute-path",
        "size": 12345,
        "modificationDate": "ISO-8601-timestamp",
        "fileName": "filename.jpg"
      },
      "status": "new",
      "exclusionReason": null
    }
  ],
  "summary": {
    "totalScanned": 100,
    "newItems": 10,
    "knownItems": 90
  }
}
```

**Fields**:
- `version`: Result format version
- `sourceId`: Source identifier
- `libraryId`: Library identifier
- `detectedAt`: ISO-8601 timestamp of detection run
- `candidates`: Array of candidate items with status and exclusion reasons
- `summary`: Summary statistics

### Exclusion Reasons

Exclusion reasons are represented as **enumeration strings**:

- `"already_known"`: Item is already in Library
- `"unsupported_format"`: File format not supported (shouldn't occur if scanning works correctly)
- `"unreadable"`: File could not be read (shouldn't occur if scanning works correctly)

**Rationale**:
- Clear and explainable
- Easy to extend with new reasons
- Human-readable

## Consequences

### Positive
- ✅ Results are stored persistently
- ✅ Format is transparent and readable
- ✅ Supports comparison across runs
- ✅ Per-Source organization enables history tracking
- ✅ Timestamp-based naming ensures uniqueness

### Negative
- ⚠️ Multiple files per Source (acceptable for P1)
- ⚠️ No automatic cleanup of old results (can be added in future)

### Risks
- **File Accumulation**: Many detection runs create many files (acceptable for P1, cleanup can be added later)
- **Schema Evolution**: Future changes must maintain backward compatibility

## Validation

This ADR addresses:
- ✅ FR-010: Support re-running detection safely without side effects
- ✅ FR-013: Maintain detection results in explainable and auditable format
- ✅ FR-017: Store results in transparent, human-readable format
- ✅ SC-007: Detection results are explainable

## References

- Plan Component 6: Detection Result Model & Storage
- ADR 001: Library Metadata Specification (for consistency)
- Specification FR-010, FR-013, FR-017, SC-007
- Task 6.3: Design Result Storage Format (ADR)
