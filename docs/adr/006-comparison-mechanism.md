# ADR 006: Library Comparison Mechanism

**Status**: Accepted  
**Date**: 2026-01-12  
**Component**: Library Comparison & New Item Detection (Component 5)  
**Task**: 5.1

## Context

MediaHub needs to compare candidate media items from Sources against Library contents to determine which items are new. The comparison mechanism must:

- Identify items already known to the Library (FR-007, FR-008)
- Exclude known items from candidate lists (FR-008)
- Produce deterministic results (FR-009, SC-004, SC-005)
- Achieve 100% accuracy (SC-006)
- Be simple and non-fuzzy for P1

## Decision

### Comparison Mechanism

**Path-based comparison** is chosen for P1.

**Rationale**:
- Simple and deterministic
- Fast (no content hashing required)
- Sufficient for P1 requirements
- Meets accuracy target (100% for exact path matches)
- No external dependencies

**Alternative Considered**: Content hash-based comparison
- **Rejected for P1**: Adds complexity, slower, not needed for simple "known vs new" detection
- **Future**: May be added in later slices for duplicate detection

### Library Content Discovery

For P1, Library contents are discovered by scanning the Library root directory (excluding `.mediahub/`) for media files using the same media file format detection as Source scanning.

**Rationale**:
- Simple and consistent with Source scanning
- No additional storage required
- Works with current Library structure (Slice 1)
- Deterministic (same scan produces same results)
- **P1 Minimal Representation**: Provides minimal representation of known items sufficient for comparison (as per plan requirement)

**Alternative Considered**: Stored index of Library contents
- **Rejected for P1**: Adds storage complexity; scanning is sufficient for P1
- **Future**: May be added in later slices (Slice 3/4) for performance optimization
- **API Evolution**: `LibraryContentQuery.scanLibraryContents()` can be refactored to use an index without breaking the comparison API (returns `Set<String>` regardless of implementation)

**Design Notes**:
- **Deterministic**: Scanning order is consistent (alphabetical sorting)
- **Organization-Independent**: Does not depend on future Library organization (YYYY/MM or otherwise)
- **Performance Debt**: Scanning large Libraries (100k+ files) may be slow; acceptable for P1, optimization deferred to later slices

### Comparison Strategy

1. **Scan Library root** (excluding `.mediahub/`) for media files
2. **Extract normalized paths** from Library media files
3. **Compare candidate item paths** against Library paths
4. **Mark items as known** if path matches (exact match)
5. **Mark items as new** if path does not match

**Path Normalization**:
- Absolute paths are used for comparison
- Paths are compared as strings (case-sensitive on macOS, but file system is case-insensitive)
- Symlinks are resolved to actual paths during Library scanning

### Determinism

Comparison is deterministic by:
- Consistent file system enumeration order (alphabetical sorting)
- No time-dependent logic
- No random or non-deterministic operations
- Same Library state produces same comparison results

## Consequences

### Positive
- ✅ Simple and fast implementation
- ✅ Deterministic results (meets SC-004, SC-005)
- ✅ 100% accuracy for exact path matches (meets SC-006)
- ✅ No additional storage required
- ✅ Consistent with Source scanning approach

### Negative
- ⚠️ Only detects exact path matches (items moved within Library are not detected as "known")
- ⚠️ No content-based duplicate detection (deferred to future slices)
- ⚠️ Library scanning adds overhead (acceptable for P1)

### Risks
- **Performance**: Scanning large Libraries may be slow (acceptable for P1, can be optimized later)
- **Path Changes**: Items moved within Library after import are not detected as "known" (acceptable for P1)
- **Case Sensitivity**: Path comparison is case-sensitive but file system is case-insensitive (handled by normalization)

## Validation

This ADR addresses:
- ✅ FR-007: Identify which candidate items are new relative to the Library
- ✅ FR-008: Exclude items already known to the Library from candidate lists
- ✅ FR-009: Produce deterministic detection results
- ✅ SC-004: Detection results are 100% deterministic
- ✅ SC-005: Re-running detection produces identical results
- ✅ SC-006: Correctly identify items already known to Library with 100% accuracy

## References

- Plan Component 5: Library Comparison & New Item Detection
- Specification FR-007, FR-008, FR-009, SC-004, SC-005, SC-006
- Task 5.1: Design Comparison Mechanism (ADR)
