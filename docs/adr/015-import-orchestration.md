# ADR 015: Import Job Orchestration Flow

**Status**: Accepted  
**Date**: 2026-01-12  
**Component**: Import Job Orchestration (Component 5)  
**Task**: 5.1

## Context

MediaHub needs to orchestrate the end-to-end import process, coordinating timestamp extraction, destination mapping, collision handling, and file copying.

## Decision

### Import Execution Flow

**Sequential Processing**: Items are processed sequentially (one at a time).

**Flow**:
1. Validate inputs (detection result, selected items, library)
2. For each selected item:
   a. Extract timestamp (EXIF → mtime fallback)
   b. Map destination path (Year/Month)
   c. Detect collision
   d. Apply collision policy
   e. Copy file atomically (if proceeding)
   f. Record result
3. Update known-items tracking
4. Store import result

**Rationale**:
- Sequential ensures determinism
- Simple error handling (per-item)
- Clear progress tracking
- No parallel complexity for P1

### Import Transactionality

**Item-by-Item**: Each item is processed independently (not all-or-nothing).

**Rationale**:
- Allows partial success
- Clear per-item results
- Handles errors gracefully
- No rollback complexity

### Determinism Enforcement

**Consistent Ordering**: Items are processed in deterministic order (from detection result).

**Rationale**:
- Same inputs → same outputs
- Supports idempotent imports
- Predictable behavior

### Interruption Handling

**Cleanup on Interruption**: Temporary files are cleaned up, Library remains consistent.

**Rationale**:
- Prevents corrupt Library state
- Handles interruptions gracefully
- Maintains consistency

### Progress Reporting

**Per-Item Results**: Results are collected per-item and aggregated into summary.

**Rationale**:
- Clear reporting
- Explainable results
- Supports audit trail

## Consequences

### Positive
- ✅ Deterministic execution
- ✅ Clear error handling
- ✅ Partial success support
- ✅ Explainable results
- ✅ Handles interruptions

### Negative
- ⚠️ Sequential processing (slower than parallel, acceptable for P1)
- ⚠️ No import resumption (P2 feature)

### Risks
- **Performance**: Sequential processing may be slow for large imports (acceptable for P1)
- **Interruption**: Mid-import interruption (handled by cleanup)

## Validation

This ADR addresses:
- ✅ FR-001: Support importing selected candidate items from detection results
- ✅ FR-012: Produce deterministic import results
- ✅ FR-013: Handle import interruptions gracefully
- ✅ FR-017: Support re-running import on same detection result safely
- ✅ User Story 1: Import selected candidate items (all acceptance scenarios)
- ✅ SC-001: Import completes within performance targets
- ✅ SC-002: Import results are 100% deterministic
- ✅ SC-004: Import operations safe against interruption

## References
- Plan Component 5 (lines 223-268)
- Specification FR-001, FR-012, FR-013, FR-017
- Specification User Story 1
