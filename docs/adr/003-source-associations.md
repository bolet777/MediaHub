# ADR 003: Source-Library Association Storage

**Status**: Accepted  
**Date**: 2026-01-12  
**Component**: Source-Library Association Persistence (Component 2)  
**Task**: 2.1

## Context

MediaHub needs to persistently store associations between Sources and Libraries. These associations must:

- Persist across application restarts (FR-004, SC-008)
- Support multiple Sources per Library (FR-002)
- Be stored in transparent, human-readable format (FR-017)
- Enable retrieval of all Sources for a Library
- Support association removal (detaching Sources)

## Decision

### Storage Location

Associations are stored within the Library structure at: `.mediahub/sources/` directory.

**Rationale**:
- Keeps metadata within Library structure (consistent with library.json location)
- Hidden directory keeps metadata separate from user content
- Allows multiple association files (one per Source or combined)
- Follows established pattern from `.mediahub/library.json`

### Storage Format

**JSON** is chosen as the association storage format.

**Rationale**:
- Transparent and human-readable (FR-017)
- Readable by standard system tools without MediaHub
- Widely supported across platforms
- Easy to parse and validate
- Extensible for future requirements
- Consistent with library.json format (ADR 001)

**Alternative Considered**: Property List (plist)
- **Rejected**: While native to macOS, less portable and harder to read/edit manually

### Association Storage Strategy

**Single file per Library**: All Source associations for a Library are stored in one file: `.mediahub/sources/associations.json`

**Rationale**:
- Simple to manage (one file per Library)
- Easy to read/write atomically
- Efficient for Libraries with multiple Sources
- Clear ownership (associations belong to the Library)

**Alternative Considered**: One file per Source
- **Rejected**: More files to manage; harder to get all associations for a Library

### Association Schema

The associations JSON schema:

```json
{
  "version": "1.0",
  "libraryId": "uuid-v4-string",
  "sources": [
    {
      "sourceId": "uuid-v4-string",
      "type": "folder",
      "path": "absolute-path-to-source",
      "attachedAt": "ISO-8601-timestamp",
      "lastDetectedAt": "ISO-8601-timestamp-or-null"
    }
  ]
}
```

**Fields**:
- `version`: Association format version (for future schema evolution)
- `libraryId`: Library identifier (for validation)
- `sources`: Array of Source objects (full Source metadata)

**Design Notes**:
- `libraryId` allows validation that associations belong to correct Library
- `version` allows future schema evolution without breaking existing associations
- Full Source objects stored for convenience (no separate Source registry needed)
- Array format supports multiple Sources per Library (FR-002)

### Versioning Strategy

**Association Format Versioning**:
- Current format version: `1.0`
- Future versions must maintain backward compatibility or provide migration
- Version field allows detection of format changes
- **P1 Choice**: JSON chosen for simplicity and readability; format is versioned and migration-capable
- **Future Evolution**: Format can evolve (e.g., to binary format, different schema) with version detection and migration logic

## Consequences

### Positive
- ✅ Associations persist across application restarts
- ✅ Format is transparent and readable without MediaHub
- ✅ Supports multiple Sources per Library
- ✅ Consistent with Library metadata storage approach
- ✅ Simple file structure (one file per Library)

### Negative
- ⚠️ JSON parsing requires error handling for corrupted files
- ⚠️ Single file means all associations loaded together (acceptable for P1)

### Risks
- **Schema Evolution**: Future changes must maintain backward compatibility
- **Corruption**: JSON files can be corrupted; validation required
- **Concurrency**: Multiple processes modifying same file (handled by atomic writes)

## Validation

This ADR addresses:
- ✅ FR-001: Support attaching at least one Source to a Library
- ✅ FR-002: Support multiple Sources attached to a single Library
- ✅ FR-004: Maintain Source identity across restarts
- ✅ FR-017: Store Source associations in transparent, human-readable format
- ✅ SC-008: Source associations persist across application restarts 100% of the time

## References

- Plan Component 2: Source-Library Association Persistence
- ADR 001: Library Metadata Specification (for consistency)
- Specification FR-001, FR-002, FR-004, FR-017, SC-008
- Task 2.1: Design Association Storage Format (ADR)
