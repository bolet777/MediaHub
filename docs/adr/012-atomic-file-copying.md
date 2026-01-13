# ADR 012: Atomic File Copying Strategy

**Status**: Accepted  
**Date**: 2026-01-12  
**Component**: Atomic File Copying & Safety (Component 4)  
**Task**: 4.1

## Context

MediaHub needs to copy files from Source to Library destination with atomic/safe writes that prevent corruption on interruption. Source files must never be modified (read-only guarantee).

## Decision

### Atomic Write Strategy

**Strategy**: Temporary file + rename

**Process**:
1. Copy source file to temporary file in destination directory
2. Verify copy integrity (size comparison)
3. Atomically rename temporary file to final destination

**Rationale**:
- Atomic rename is filesystem-level operation (prevents partial files)
- Temporary file in same directory ensures rename is atomic
- Verification ensures data integrity
- Standard approach for atomic writes

### Temporary File Naming

**Pattern**: `.{originalFilename}.mediahub-tmp-{UUID}`

**Example**: `.IMG_1234.jpg.mediahub-tmp-550e8400-e29b-41d4-a716-446655440000`

**Rationale**:
- Hidden file (starts with `.`) reduces visibility
- UUID ensures uniqueness
- `.mediahub-tmp-` prefix enables cleanup of orphaned temp files
- Original filename helps identify temp file purpose

### Source File Validation

**Validation**: Check file accessibility before copying:
- File exists
- File is readable
- File is a regular file (not directory)

**Rationale**:
- Prevents copy failures mid-operation
- Clear error messages for inaccessible files
- Handles edge cases (deleted files, moved files)

### Read-Only Source Guarantee

**Guarantee**: Source files are never modified during import.

**Implementation**:
- Read-only file operations (no write access to source)
- Copy operation (not move)
- No metadata modification on source

**Rationale**:
- Preserves source files (Constitution requirement)
- Enables safe re-imports
- Maintains source integrity

### Interruption Cleanup

**Cleanup**: Temporary files are cleaned up on interruption.

**Strategy**:
- Track temporary files created during import
- Cleanup on error or interruption
- Orphaned temp files can be cleaned up later (by prefix)

**Rationale**:
- Prevents accumulation of temp files
- Maintains Library consistency
- Handles interruption gracefully

### File Data Preservation

**Preservation**: Copied files are byte-for-byte identical to source.

**Verification**: Size comparison after copy (full checksum is P2).

**Rationale**:
- Ensures data integrity
- Prevents corruption
- Simple verification for P1

### Injectable File Operations

**Design**: File operations are injectable/mockable for testing.

**Rationale**:
- Enables testing of interruption scenarios
- Supports unit testing without actual file I/O
- Allows testing edge cases

## Consequences

### Positive
- ✅ Atomic writes prevent partial files
- ✅ Source files remain unmodified
- ✅ Handles interruptions gracefully
- ✅ Verifies data integrity
- ✅ Testable via injectable operations

### Negative
- ⚠️ Temporary files require cleanup (handled)
- ⚠️ Size-only verification (checksum is P2)
- ⚠️ Orphaned temp files possible (cleanup by prefix)

### Risks
- **Disk Space**: Insufficient space during copy (handled by error)
- **Permissions**: Write permission denied (handled by error)
- **Network Volumes**: Disconnection during copy (handled by error)
- **Large Files**: Memory constraints (streaming copy handles this)

## Validation

This ADR addresses:
- ✅ FR-006: Ensure atomic/safe writes (no partial or corrupt files on interruption)
- ✅ FR-010: Never modify Source files during import (read-only guarantee)
- ✅ FR-013: Handle import interruptions gracefully without corrupting Library state
- ✅ FR-014: Validate Source files are still accessible before importing
- ✅ FR-015: Preserve original file data during import
- ✅ User Story 1: Import selected candidate items (acceptance scenarios 1, 4)
- ✅ SC-004: Import operations safe against interruption
- ✅ SC-006: Source files remain unmodified after import

## References
- Plan Component 4 (lines 175-221)
- Specification FR-006, FR-010, FR-013, FR-014, FR-015
- Specification User Story 1
