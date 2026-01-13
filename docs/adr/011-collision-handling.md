# ADR 011: Collision Handling Strategy

**Status**: Accepted  
**Date**: 2026-01-12  
**Component**: Collision Detection & Policy Handling (Component 3)  
**Task**: 3.1

## Context

MediaHub needs to handle cases where an imported file would conflict with an existing file at the destination path. The collision policy must be configurable (rename, skip, or error) and deterministic.

## Decision

### Collision Policies

Three collision policies are supported:

1. **rename**: Generate a unique filename that doesn't conflict
2. **skip**: Skip the file and report in import results
3. **error**: Fail the import for that file with clear error

**Rationale**:
- Covers common use cases (avoid overwrite, skip duplicates, fail on conflict)
- Simple and clear policies
- Deterministic behavior

### Rename Strategy

**Pattern**: `{originalName} ({number}).{extension}`

**Example**: `IMG_1234.jpg` → `IMG_1234 (1).jpg` → `IMG_1234 (2).jpg`

**Numbering**: Starts at 1, increments until unique filename is found.

**Max Attempts**: 1000 (prevents infinite loops)

**Rationale**:
- Preserves original filename (readable)
- Deterministic numbering (same collision → same rename)
- Clear pattern (users can understand)
- Max attempts prevents infinite loops

### Collision Detection

**Detection**: Check if destination path exists (file or directory) before copying.

**Timing**: Before copy operation (pre-check).

**Rationale**:
- Prevents unnecessary copy attempts
- Enables policy application before file operations
- Handles both file and directory collisions

### Policy Application

**Per-Item**: Each collision is handled individually according to the configured policy.

**Rationale**:
- Allows partial success (some items import, others skip/fail)
- Clear reporting per item
- Flexible handling

### Determinism

**Rename Policy**: Same collision scenario produces same renamed filename.

**Rationale**:
- Ensures deterministic import results
- Same inputs → same outputs
- Supports idempotent import operations

## Consequences

### Positive
- ✅ Clear, configurable policies
- ✅ Deterministic rename strategy
- ✅ Prevents infinite loops
- ✅ Handles edge cases (directories, multiple collisions)

### Negative
- ⚠️ Rename pattern may conflict if many collisions occur (max attempts prevents infinite loops)
- ⚠️ No content comparison (path-only collision detection for P1)

### Risks
- **Race Conditions**: File created between check and copy (handled by atomic copy operation)
- **Many Collisions**: Rename attempts may be slow (max attempts limits this)
- **Directory Collisions**: Directory at destination path (handled by error policy)

## Validation

This ADR addresses:
- ✅ FR-005: Handle name/path collisions according to configurable policy
- ✅ FR-007: Report import results showing what was skipped and why
- ✅ User Story 3: Handle import collisions safely (all acceptance scenarios)
- ✅ SC-008: Collision handling follows configured policy 100% of the time

## References
- Plan Component 3 (lines 133-173)
- Specification FR-005
- Specification User Story 3
