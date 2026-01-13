# ADR 010: Destination Path Mapping Strategy

**Status**: Accepted  
**Date**: 2026-01-12  
**Component**: Destination Path Mapping (Component 2)  
**Task**: 2.1

## Context

MediaHub needs to map candidate items to their destination paths in the Library using a deterministic Year/Month (YYYY/MM) organization rule. The mapping must be deterministic (same timestamp → same path) and preserve original filenames.

## Decision

### Destination Path Format

**Format**: `{LibraryRoot}/{YYYY}/{MM}/{filename.ext}`

**Example**: `/Users/john/Library/2026/01/IMG_1234.jpg`

**Rationale**:
- Simple, transparent folder structure
- Human-readable and navigable in Finder
- Deterministic (same timestamp always produces same path)
- Zero-padded months ensure consistent sorting (01, 02, ..., 12)

### Year/Month Folder Structure

**Format**: `YYYY/MM` where:
- `YYYY` is 4-digit year (e.g., 2026)
- `MM` is 2-digit zero-padded month (e.g., 01, 02, ..., 12)

**Rationale**:
- Zero-padding ensures consistent sorting (01 comes before 10)
- 4-digit years handle all reasonable dates
- Consistent format across all imports

### Filename Preservation

**Original filenames are preserved** in the destination path.

**Rationale**:
- Maintains user's original naming
- Transparent (users can see original filenames)
- No data loss or confusion from renaming

### Filename Sanitization

**Invalid characters** in filenames are handled by:
- Replacing invalid filesystem characters with underscore (`_`)
- Invalid characters: `/`, `\0` (null), and any characters that would create invalid paths

**Rationale**:
- Prevents filesystem errors
- Preserves filename readability
- Minimal transformation (only when necessary)

### Path Length Limitations

**No explicit truncation** for P1. If a path exceeds filesystem limits, the import will fail with a clear error.

**Rationale**:
- Edge case (rare in practice)
- Clear error reporting is sufficient for P1
- Can be enhanced in future if needed

### Collision Detection Support

Destination path mapping **supports collision detection** by:
- Computing the intended destination path
- Checking if path already exists (file or directory)
- Returning collision information for policy handling

**Rationale**:
- Enables collision handling before copy
- Prevents overwriting existing files
- Supports deterministic collision resolution

## Consequences

### Positive
- ✅ Deterministic mapping (same timestamp → same path)
- ✅ Transparent, human-readable structure
- ✅ Preserves original filenames
- ✅ Simple and maintainable
- ✅ Works with external tools (Finder, command line)

### Negative
- ⚠️ No handling of very long paths (edge case, handled by error)
- ⚠️ Minimal filename sanitization (may need enhancement for edge cases)

### Risks
- **Path Length**: Very long filenames may exceed filesystem limits (handled by error)
- **Invalid Characters**: Some edge cases may not be caught (minimal sanitization is acceptable for P1)
- **Collision Frequency**: Files with same timestamp and name will collide (handled by collision policy)

## Validation

This ADR addresses:
- ✅ FR-003: Organize imported files in Year/Month folders (YYYY/MM)
- ✅ FR-012: Produce deterministic import results
- ✅ User Story 2: Organize imported files by Year/Month (all acceptance scenarios)
- ✅ SC-002: Import results are 100% deterministic
- ✅ SC-007: Imported files organized according to timestamp rule 100% of the time

## References
- Plan Component 2 (lines 90-130)
- Specification FR-003
- Specification User Story 2
