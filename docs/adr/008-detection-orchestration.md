# ADR 008: Detection Execution Flow

**Status**: Accepted  
**Date**: 2026-01-12  
**Component**: Detection Execution & Orchestration (Component 7)  
**Task**: 7.1

## Context

MediaHub needs to orchestrate the complete detection workflow, coordinating all components to execute detection runs end-to-end. The orchestration must:

- Coordinate Source scanning, Library comparison, and result generation (FR-009, FR-010)
- Ensure detection is deterministic and repeatable (FR-009, SC-004, SC-005)
- Support safe re-runs without side effects (FR-010)
- Never modify Source files (FR-011)
- Handle interruptions gracefully (FR-014, SC-010)
- Report progress and errors (FR-012)

## Decision

### Detection Execution Flow

The detection workflow follows this sequence:

1. **Validate Source Accessibility**: Check Source is accessible (Component 3)
2. **Scan Source**: Scan Source for candidate media files (Component 4)
3. **Query Library Contents**: Scan Library for known media files (Component 5)
4. **Compare Items**: Compare candidates against Library contents (Component 5)
5. **Generate Results**: Create detection result with status and explanations (Component 6)
6. **Store Results**: Persist detection result to disk (Component 6)
7. **Update Source Metadata**: Update Source lastDetectedAt timestamp (Component 2)

**Rationale**:
- Clear, sequential flow
- Each step depends on previous step
- Error handling at each stage
- Deterministic execution

### Determinism Enforcement

Detection is deterministic by:

- **Consistent File Ordering**: Files are sorted alphabetically by path at each stage
- **No Time-Dependent Logic**: Timestamps are only used for metadata, not for comparison
- **No Random Operations**: All operations are deterministic
- **Consistent Comparison**: Same inputs produce same comparison results

**Rationale**:
- Meets SC-004: 100% deterministic results
- Meets SC-005: Re-running produces identical results

### Interruption Handling

For P1, detection interruptions are handled by:

- **No Partial State**: Detection either completes or fails; no partial results stored
- **Atomic Writes**: Result files are written atomically (all-or-nothing)
- **Safe Restart**: Interrupted detection can be safely restarted (no cleanup needed)

**Rationale**:
- Simple for P1
- Meets SC-010: Safe interruption
- No complex state management required

**Future Enhancement**: Resume capability may be added in later slices

### Error Handling

Errors are handled at each stage:

- **Source Inaccessible**: Detection fails with clear error message
- **Scanning Errors**: Individual file errors are logged but scanning continues
- **Comparison Errors**: Errors are logged but comparison continues
- **Storage Errors**: Detection fails if results cannot be stored

**Rationale**:
- Graceful degradation where possible
- Clear error reporting
- No silent failures

### Read-Only Enforcement

All detection operations are read-only:

- **Source Scanning**: Only reads file metadata, never modifies files
- **Library Scanning**: Only reads Library structure, never modifies
- **Result Storage**: Only writes to Library metadata directory, never to Source

**Rationale**:
- Meets FR-011: Never modify Source files
- Safe and reversible operations

## Consequences

### Positive
- ✅ Clear, sequential workflow
- ✅ Deterministic execution
- ✅ Safe re-runs without side effects
- ✅ Read-only operations
- ✅ Graceful error handling

### Negative
- ⚠️ No resume capability for interrupted detections (acceptable for P1)
- ⚠️ Full scan on each run (acceptable for P1, can be optimized later)

### Risks
- **Performance**: Large Sources may take time (meets SC-003: < 30 seconds for 1000 files)
- **Interruptions**: No resume capability (acceptable for P1)

## Validation

This ADR addresses:
- ✅ FR-009: Produce deterministic detection results
- ✅ FR-010: Support re-running detection safely without side effects
- ✅ FR-011: Never modify Source files during detection
- ✅ FR-014: Handle detection interruptions gracefully
- ✅ SC-003: Detect candidate items within performance targets
- ✅ SC-004: Detection results are 100% deterministic
- ✅ SC-005: Re-running detection produces identical results
- ✅ SC-010: Detection can be safely interrupted

## References

- Plan Component 7: Detection Execution & Orchestration
- Specification FR-009, FR-010, FR-011, FR-014, SC-003, SC-004, SC-005, SC-010
- Task 7.1: Design Detection Execution Flow (ADR)
