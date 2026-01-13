# ADR 004: Source Validation Requirements

**Status**: Accepted  
**Date**: 2026-01-12  
**Component**: Source Validation & Accessibility (Component 3)  
**Task**: 3.1

## Context

MediaHub needs to validate Sources before attachment and during detection to ensure:

- Sources are accessible and readable (FR-003)
- Sources have appropriate permissions (FR-003)
- Sources are of supported types (FR-005)
- Clear error messages are provided when validation fails (FR-012, SC-009)
- Validation completes within performance targets (SC-002: < 2 seconds)

## Decision

### Required Validation Checks

For P1, the following validation checks are **required** before Source attachment:

1. **Path Existence**: Source path must exist and be accessible
2. **Read Permissions**: Source must have read permissions
3. **Source Type**: Source type must be supported (folder-based for P1)
4. **Directory Type** (for folder Sources): Path must be a directory, not a file

### Optional Validation Checks (P2)

The following checks are **optional** for P1 but may be added in P2:

- Write permissions (not needed for read-only detection)
- Disk space availability (not needed for read-only detection)
- Network volume responsiveness (handled by timeout)
- Source contains media files (deferred to detection phase)

### Validation Timing

**Pre-Attachment Validation**: All required checks are performed before allowing Source attachment.

**Detection-Time Validation**: Basic accessibility check is performed at the start of detection to catch Sources that became inaccessible after attachment.

**Rationale**:
- Pre-attachment validation prevents attaching invalid Sources
- Detection-time validation handles Sources that become inaccessible (external drives, network volumes)
- Performance targets require fast validation (SC-002: < 2 seconds)

### Error Message Strategy

Validation failures produce clear, actionable error messages:

- **Path Not Found**: "Source path does not exist: {path}"
- **Permission Denied**: "Permission denied accessing source: {path}. Please check read permissions."
- **Invalid Type**: "Source type not supported: {type}. Supported types: folder"
- **Not a Directory**: "Source path is not a directory: {path}"

**Rationale**:
- Clear messages help users understand and fix issues
- Actionable guidance (e.g., "check read permissions")
- Meets SC-009: Clear, actionable error messages within 5 seconds

### Validation Performance

Validation must complete within 2 seconds (SC-002) for typical Sources.

**Strategies**:
- Use fast file system checks (existence, permissions)
- Avoid deep scanning during validation
- Defer expensive checks (media file detection) to detection phase

## Consequences

### Positive
- ✅ Invalid Sources are caught before attachment
- ✅ Clear error messages guide users
- ✅ Fast validation meets performance targets
- ✅ Read-only focus (no write permission checks needed)

### Negative
- ⚠️ Sources may become inaccessible after attachment (handled by detection-time validation)
- ⚠️ Network volumes may be slow to respond (timeout handling required)

### Risks
- **Performance**: Deep validation could exceed 2-second target (mitigated by lightweight checks)
- **Network Sources**: Network volumes may timeout (handled gracefully)
- **Permission Changes**: Permissions may change after attachment (detection-time validation catches this)

## Validation

This ADR addresses:
- ✅ FR-003: Validate Source accessibility and permissions before allowing attachment
- ✅ FR-012: Report clear errors when Sources are inaccessible or have permission issues
- ✅ SC-002: Validate Source accessibility within 2 seconds
- ✅ SC-009: Report clear, actionable error messages within 5 seconds

## References

- Plan Component 3: Source Validation & Accessibility
- Specification FR-003, FR-012, SC-002, SC-009
- Task 3.1: Define Validation Requirements (ADR)
