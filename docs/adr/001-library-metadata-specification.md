# ADR 001: Library Metadata Specification

**Status**: Accepted  
**Date**: 2025-01-27  
**Component**: Library Identity & Metadata Structure  
**Task**: 1.1

## Context

MediaHub needs to uniquely identify each library and store essential metadata that:
- Makes a directory identifiable as a MediaHub library (FR-002)
- Assigns a unique identifier that persists across application restarts (FR-003)
- Maintains library identity across renames and moves (FR-006)
- Stores metadata in a transparent, human-readable format (FR-007)
- Preserves library identity when files are modified externally (FR-012)

## Decision

### Unique Identifier Format

**UUID v4** is chosen as the unique identifier format for libraries.

**Rationale**:
- Globally unique with negligible collision probability
- Standard format supported by all platforms
- No dependencies on external services
- Human-readable when needed
- Persists across moves and renames when stored in metadata

### Metadata Storage Format

**JSON** is chosen as the metadata storage format.

**Rationale**:
- Transparent and human-readable (FR-007)
- Readable by standard system tools without MediaHub
- Widely supported across platforms
- Easy to parse and validate
- Extensible for future requirements
- No binary dependencies

**Alternative Considered**: Property List (plist)
- **Rejected**: While native to macOS, less portable and harder to read/edit manually

### Metadata File Location

Metadata is stored at: `.mediahub/library.json` within the library root directory.

**Rationale**:
- Hidden directory (`.mediahub/`) keeps metadata separate from user content
- Standard JSON file name makes purpose clear
- Follows common pattern of hidden configuration directories
- Allows future metadata files in same directory without cluttering root

**Alternative Considered**: Visible `Library/` directory
- **Rejected**: Could be confused with user content; hidden directory is cleaner

### Metadata Schema

The library metadata JSON schema:

```json
{
  "version": "1.0",
  "libraryId": "uuid-v4-string",
  "createdAt": "ISO-8601-timestamp",
  "libraryVersion": "1.0",
  "rootPath": "absolute-path-to-library-root"
}
```

**Fields**:
- `version`: Metadata format version (for future schema evolution)
- `libraryId`: Unique identifier (UUID v4) that persists across moves
- `createdAt`: ISO-8601 timestamp of library creation
- `libraryVersion`: MediaHub library version (for compatibility tracking)
- `rootPath`: Absolute path to library root (may become stale after moves)

**Design Notes**:
- `rootPath` may become stale after moves but is useful for initial location tracking
- `version` allows future schema evolution without breaking existing libraries
- `libraryVersion` tracks MediaHub version that created the library
- All fields are required for a valid library

### Versioning Strategy

**Metadata Format Versioning**:
- Current format version: `1.0`
- Future versions must maintain backward compatibility or provide migration
- Version field allows detection of format changes

**Library Versioning**:
- Tracks MediaHub application version that created the library
- Used for compatibility checks and feature availability
- Format: Semantic versioning (e.g., "1.0.0")

## Consequences

### Positive
- ✅ Libraries are uniquely identifiable with UUIDs
- ✅ Metadata is transparent and readable without MediaHub
- ✅ Format is extensible for future requirements
- ✅ Standard formats (UUID, JSON) ensure portability
- ✅ Hidden directory keeps metadata separate from content

### Negative
- ⚠️ JSON parsing requires error handling for corrupted files
- ⚠️ Hidden directory may be less discoverable (but this is intentional)
- ⚠️ `rootPath` may become stale (handled by path tracking in Component 6)

### Risks
- **Schema Evolution**: Future changes must maintain backward compatibility
- **Corruption**: JSON files can be corrupted; validation required (Component 7)
- **Path Staleness**: `rootPath` may become outdated; identifier-based lookup required (Component 6)

## Validation

This ADR addresses:
- ✅ FR-002: Store library metadata that makes library identifiable
- ✅ FR-003: Assign unique identifier that persists across restarts
- ✅ FR-006: Maintain library identity across renames/moves
- ✅ FR-007: Store metadata in transparent, human-readable format
- ✅ FR-012: Preserve library identity when files modified externally

## References

- Plan Component 1: Library Identity & Metadata Structure
- Specification FR-002, FR-003, FR-006, FR-007, FR-012
- Task 1.1: Define Library Metadata Specification (ADR)
