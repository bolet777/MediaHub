# ADR 014: Import Results Storage

**Status**: Accepted  
**Date**: 2026-01-12  
**Component**: Import Result Model & Storage (Component 6)  
**Task**: 6.4

## Context

MediaHub needs to store import results in a transparent, auditable format that shows what was imported, skipped, failed, and why.

## Decision

### Storage Location

**Location**: `.mediahub/sources/{sourceId}/imports/{timestamp}.json`

**Rationale**:
- Per-Source organization (consistent with detections)
- Per-import-run files (enables comparison)
- Timestamp-based naming (sortable, unique)
- Transparent location (within Library structure)

### Storage Format

**Format**: JSON (transparent, human-readable)

**Rationale**:
- Transparent and human-readable (FR-009)
- Easy to parse and validate
- Extensible for future requirements
- Consistent with other metadata formats

### Result Schema

**Schema**:
```json
{
  "version": "1.0",
  "sourceId": "uuid-v4-string",
  "libraryId": "uuid-v4-string",
  "importedAt": "ISO-8601-timestamp",
  "options": {
    "collisionPolicy": "rename|skip|error"
  },
  "items": [
    {
      "sourcePath": "absolute-source-path",
      "destinationPath": "relative-library-path",
      "status": "imported|skipped|failed",
      "reason": "optional-reason-string",
      "timestampUsed": "ISO-8601-timestamp",
      "timestampSource": "exif|filesystem"
    }
  ],
  "summary": {
    "total": 100,
    "imported": 90,
    "skipped": 5,
    "failed": 5
  }
}
```

**Rationale**:
- Includes all required fields for explainability
- Supports audit trail (metadata, timestamps, options)
- Clear status and reason for each item
- Summary statistics for quick overview

### Import Item Status

**Status Enumeration**: `imported`, `skipped`, `failed`

**Rationale**:
- Clear, mutually exclusive statuses
- Covers all possible outcomes
- Human-readable

### Import Item Reasons

**Reason Representation**: Descriptive strings (e.g., "File already exists at destination", "Source file not found")

**Rationale**:
- Explainable (SC-005)
- Human-readable
- Flexible (can include context)

## Consequences

### Positive
- ✅ Transparent, human-readable format
- ✅ Supports explainable results
- ✅ Enables comparison across runs
- ✅ Maintains audit trail
- ✅ Per-import-run organization

### Negative
- ⚠️ Multiple files per Source (acceptable for P1)
- ⚠️ No automatic cleanup of old results (can be added in future)

### Risks
- **File Accumulation**: Many imports create many files (acceptable for P1, cleanup can be added later)
- **Schema Evolution**: Future changes must maintain backward compatibility

## Validation

This ADR addresses:
- ✅ FR-007: Report import results showing what was imported, skipped, failed, and why
- ✅ FR-009: Maintain audit trail in transparent, human-readable format
- ✅ FR-016: Store import results persistently for auditability
- ✅ User Story 5: View import results and audit trail (all acceptance scenarios)
- ✅ SC-005: Import results are explainable
- ✅ SC-009: Import results stored persistently and survive restarts
- ✅ SC-010: Import audit trail is transparent and human-readable

## References
- Plan Component 6 (lines 270-314)
- Specification FR-007, FR-009, FR-016
- Specification User Story 5
