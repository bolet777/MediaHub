# ADR 013: Known Items Tracking Strategy

**Status**: Accepted  
**Date**: 2026-01-12  
**Component**: Known Items Tracking & Persistence (Component 7)  
**Task**: 7.1

## Context

MediaHub needs to track which items have been imported so that future detection runs exclude them. For P1, tracking is path-based and scoped to the Source from which items were imported.

## Decision

### Tracking Schema

**Path-Based Identifiers**: Imported items are tracked by their source path (absolute, normalized).

**Source-Scoped**: Tracking is scoped to the Source from which items were imported.

**Rationale**:
- Simple and efficient for P1
- Path-based is sufficient for source-scoped tracking
- No content hashes needed (P2 feature)
- No cross-source deduplication (P2 feature)

### Storage Location

**Location**: `.mediahub/sources/{sourceId}/known-items.json`

**Rationale**:
- Per-Source organization (consistent with detections)
- Transparent location (within Library structure)
- Human-readable filename
- Single file per Source (simple for P1)

### Storage Format

**Format**: JSON (transparent, human-readable)

**Schema**:
```json
{
  "version": "1.0",
  "sourceId": "uuid-v4-string",
  "items": [
    {
      "path": "absolute-source-path",
      "importedAt": "ISO-8601-timestamp",
      "destinationPath": "relative-library-path"
    }
  ],
  "lastUpdated": "ISO-8601-timestamp"
}
```

**Rationale**:
- Transparent and human-readable (FR-009)
- Easy to parse and validate
- Extensible for future requirements
- Consistent with other metadata formats

### Path Normalization

**Normalization**: Paths are stored as absolute, resolved paths (symlinks resolved).

**Rationale**:
- Ensures consistent comparison
- Handles symlinks correctly
- Prevents duplicate entries

### Update Strategy

**Strategy**: Append-only updates (add new items, don't remove).

**Rationale**:
- Simple for P1
- Maintains audit trail
- No automatic reconciliation (P2 feature)

### Query Strategy

**Query**: Load known items for a Source and check if candidate path exists in set.

**Rationale**:
- Efficient lookup (Set-based)
- Simple implementation
- Fast comparison

## Consequences

### Positive
- ✅ Simple, path-based tracking
- ✅ Source-scoped (no cross-source interference)
- ✅ Transparent, human-readable format
- ✅ Efficient querying (Set-based)
- ✅ Maintains audit trail

### Negative
- ⚠️ No automatic cleanup of stale entries (P2)
- ⚠️ No content hash tracking (P2)
- ⚠️ No cross-source deduplication (P2)

### Risks
- **Path Changes**: Source files moved/renamed (tracking becomes stale, handled gracefully)
- **Large Sets**: Many imported items (Set-based lookup is efficient)
- **Stale Entries**: Items deleted from Library (no automatic cleanup for P1)

## Validation

This ADR addresses:
- ✅ FR-008: Update "known items" tracking so re-running detection excludes imported items
- ✅ FR-009: Maintain audit trail in transparent, human-readable format
- ✅ User Story 4: Track imported items for future detection (all acceptance scenarios)
- ✅ SC-003: Re-running detection after import excludes imported items with 100% accuracy

## References
- Plan Component 7 (lines 316-357)
- Specification FR-008, FR-009
- Specification User Story 4
