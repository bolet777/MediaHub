# ADR 016: Import-Detection Integration Strategy

**Status**: Accepted  
**Date**: 2026-01-12  
**Component**: Import-Detection Integration (Component 8)  
**Task**: 8.1

## Context

MediaHub needs to integrate known-items tracking with the detection comparison mechanism from Slice 2, ensuring imported items are excluded from future detection runs.

## Decision

### Integration Point

**Extension of Library Comparison**: Known-items tracking is integrated into the Library comparison mechanism.

**Strategy**: 
- Query known items for Source during detection
- Include known items in Library paths set for comparison
- Detection comparison excludes items that match known items

**Rationale**:
- Minimal changes to existing detection mechanism
- Clear integration point
- Maintains determinism

### Query Timing

**During Detection**: Known items are queried during detection orchestration, before comparison.

**Rationale**:
- Efficient (single query per Source)
- Clear integration point
- Maintains detection flow

### Comparison Logic

**Path-Based Comparison**: Known items are compared by normalized path (same as Library comparison).

**Rationale**:
- Consistent with existing comparison
- Simple and efficient
- Deterministic

### Source Scoping

**Per-Source**: Known items are queried per-Source and only affect detection for that Source.

**Rationale**:
- Maintains source-scoped tracking
- No cross-source interference
- Clear behavior

### Edge Case Handling

**Missing Tracking**: If known-items tracking file doesn't exist, treat as empty set (no known items).

**Stale Entries**: Items deleted from Library are not automatically removed from tracking (P2 feature).

**Rationale**:
- Graceful handling of missing tracking
- No automatic reconciliation for P1
- Clear, predictable behavior

## Consequences

### Positive
- ✅ Minimal changes to existing detection
- ✅ Maintains determinism
- ✅ Source-scoped integration
- ✅ Efficient querying

### Negative
- ⚠️ No automatic cleanup of stale entries (P2)
- ⚠️ No validation against actual Library contents (P2)

### Risks
- **Performance**: Querying known items adds overhead (acceptable for P1)
- **Stale Entries**: Items deleted from Library remain in tracking (handled gracefully)

## Validation

This ADR addresses:
- ✅ FR-008: Update "known items" tracking so re-running detection excludes imported items
- ✅ User Story 1: Import selected candidate items (acceptance scenario 3)
- ✅ User Story 4: Track imported items for future detection (acceptance scenarios 1, 4, 5)
- ✅ SC-003: Re-running detection after import excludes imported items with 100% accuracy

## References
- Plan Component 8 (lines 359-395)
- Specification FR-008
- Specification User Story 1, User Story 4
