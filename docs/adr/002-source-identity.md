# ADR 002: Source Identity Mechanism

**Status**: Accepted  
**Date**: 2026-01-12  
**Component**: Source Model & Identity (Component 1)  
**Task**: 1.2

## Context

MediaHub needs to uniquely identify Sources and maintain their identity across application restarts. Sources may be attached to Libraries and need to be recognizable even if their paths change (P2: best-effort handling). Source identity enables:

- Persistent Source-Library associations (FR-004)
- Tracking Sources across application restarts
- Maintaining detection history per Source
- Future support for moved/renamed Sources (P2)

## Decision

### Unique Identifier Format

**UUID v4** is chosen as the unique identifier format for Sources.

**Rationale**:
- Globally unique with negligible collision probability
- Standard format supported by all platforms
- No dependencies on external services
- Human-readable when needed
- Persists across moves and renames when stored in metadata
- Consistent with Library identifier approach (ADR 001)

### Source Identity Generation

Source identifiers are generated when a Source is first attached to a Library using `SourceIdentifierGenerator.generate()`, which produces a UUID v4 string.

**Rationale**:
- Simple and reliable
- No external dependencies
- Consistent with Library identifier generation
- Generated once and stored persistently

### Source Identity Persistence

Source identity is stored in the Source metadata structure (`Source.sourceId`) and persisted in Source-Library association files (Component 2).

**Rationale**:
- Identity survives application restarts
- Enables Source tracking across sessions
- Supports future move/rename detection (P2)
- Transparent storage format (JSON)

### Path-Based Identity (P1)

For P1, Source identity is primarily UUID-based. The Source path is stored but may become stale if the Source is moved or renamed. Path changes are not automatically detected in P1 (P2: best-effort detection).

**Rationale**:
- Simple and deterministic for P1
- UUID ensures uniqueness regardless of path
- Path stored for immediate access
- Move/rename detection deferred to P2

**Alternative Considered**: Hybrid path + volume identifier approach
- **Rejected for P1**: Adds complexity; P2 will implement best-effort move detection

## Consequences

### Positive
- ✅ Sources are uniquely identifiable with UUIDs
- ✅ Identity persists across application restarts
- ✅ Simple and deterministic for P1
- ✅ Consistent with Library identity approach
- ✅ Enables future move/rename detection (P2)

### Negative
- ⚠️ Path may become stale if Source is moved (handled in P2)
- ⚠️ No automatic relocation of moved Sources in P1 (P2 feature)

### Risks
- **Path Staleness**: Source paths may become outdated; validation will detect inaccessible Sources
- **Move Detection**: P1 does not automatically detect moved Sources; P2 will add best-effort detection

## Validation

This ADR addresses:
- ✅ FR-004: Maintain Source identity that persists across application restarts
- ✅ FR-017: Store Source associations in transparent, human-readable format
- ✅ Plan Component 1: Source identity mechanism

## References

- Plan Component 1: Source Model & Identity
- ADR 001: Library Metadata Specification (for consistency)
- Specification FR-004, FR-017
- Task 1.2: Design Source Identity Mechanism (ADR)
