# Path-to-Identifier Mapping Strategy

**Component**: Library Identity Persistence  
**Task**: 6.1  
**Status**: Accepted

## Strategy Overview

MediaHub maintains library identity across moves and renames by:
1. Storing unique identifiers in library metadata (persistent)
2. Maintaining a runtime registry mapping identifiers to paths
3. Detecting path changes and updating the registry
4. Locating libraries by identifier when paths change

## Mapping Storage

### Runtime Registry (In-Memory)

**Location**: `LibraryRegistry` class in `LibraryOpening.swift`

**Purpose**: 
- Fast lookup during application runtime
- Tracks currently known library locations
- Updated when libraries are opened or moved

**Lifetime**: 
- Created at application startup
- Cleared when application terminates
- Not persisted to disk (for Slice 1)

### Persistent Storage (Future Enhancement)

For Slice 1, we rely on:
- Library metadata files (`.mediahub/library.json`) containing identifiers
- Discovery at known locations (Component 3)

Future slices may add:
- Application preferences file storing identifier-to-path mappings
- Persistent registry for faster library location

## Path Change Detection

### Detection Methods

1. **Registry Lookup Failure**
   - When opening by identifier, check if path in registry still contains library
   - If not, path has changed or library was moved

2. **Metadata Path Comparison**
   - Compare `rootPath` in metadata with actual library location
   - If different, library has been moved

3. **Explicit Move Detection**
   - User or system moves library directory
   - Next access attempt detects stale path

### Update Strategy

When a path change is detected:
1. Remove stale registry entry
2. Update metadata `rootPath` (optional - may remain stale)
3. Re-register library at new path
4. Continue operation with new path

## Identifier-Based Location

### Location Process

1. **Registry Lookup**: Check runtime registry first (fast)
2. **Metadata Search**: If not in registry, search known locations for matching identifier
3. **Discovery**: Use discovery mechanism (Component 3) to find libraries
4. **User Prompt**: If still not found, prompt user to locate library

### Known Locations

For Slice 1, known locations include:
- Previously opened library paths (tracked in registry)
- User-specified paths
- Explicitly opened locations

Full filesystem scanning is out of scope for Slice 1.

## Duplicate Identifier Handling

### Prevention

- UUID v4 generation ensures negligible collision probability
- No two libraries should have the same identifier

### Detection

If duplicate identifiers are detected:
1. Log warning/error
2. Generate new identifier for one library (prefer newer library)
3. Update metadata with new identifier
4. Update registry

### Recovery

- Compare library contents or creation dates
- User may need to manually resolve conflicts
- System can auto-resolve by assigning new identifier to duplicate

## Validation

This strategy addresses:
- ✅ FR-003: Unique identifier persists across application restarts
- ✅ FR-006: Maintain library identity across renames/moves
- ✅ SC-004: Library identifiers remain consistent across 100% of moves/renames
- ✅ SC-005: Users can open library after moving 100% of the time

## Implementation Notes

- Registry is in-memory only for Slice 1 (no persistence)
- Path changes are detected lazily (on access)
- Metadata `rootPath` may become stale but identifier remains valid
- Discovery mechanism (Component 3) handles finding libraries by identifier
