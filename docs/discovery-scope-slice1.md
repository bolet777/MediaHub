# Discovery Scope for Slice 1

**Component**: Library Discovery  
**Task**: 3.1  
**Status**: Accepted

## Scope Definition

For Slice 1, library discovery is limited to explicitly specified or previously known library locations. Full filesystem-wide scanning is considered a future enhancement (P2).

## Discovery Locations

### 1. Explicitly Opened Locations

**Definition**: Libraries opened by the user through explicit path selection

**Implementation**:
- User provides a path (via file picker, command line, etc.)
- MediaHub checks if path contains a valid library
- If valid, library is registered and made active

**Use Cases**:
- User selects "Open Library..." and chooses a directory
- User provides library path via command line
- User drags library folder onto MediaHub

### 2. Previously Known Locations

**Definition**: Libraries that were previously opened and their locations are tracked

**Implementation**:
- MediaHub maintains a registry of previously opened libraries
- Registry maps library identifiers to paths
- On startup, MediaHub checks if libraries at registered paths still exist
- Valid libraries are available for opening

**Storage**:
- Runtime registry (in-memory) for Slice 1
- Future: Persistent registry in application preferences

**Use Cases**:
- User opens MediaHub and sees recently opened libraries
- User switches between multiple libraries
- User reopens a library after application restart

### 3. User-Specified Locations

**Definition**: Locations explicitly provided by the user for discovery

**Implementation**:
- User can specify directories to search for libraries
- MediaHub checks specified locations for valid libraries
- Found libraries are registered and available

**Use Cases**:
- User adds a directory to "Library Search Paths"
- User specifies external drive to search
- User provides network volume path

## Out of Scope for Slice 1

### Full Filesystem Scanning

**Not Included**:
- Automatic scanning of all volumes
- Deep directory tree traversal
- Background discovery of libraries
- Automatic library detection on mount

**Rationale**:
- Performance concerns with large filesystems
- Privacy considerations
- Complexity beyond Slice 1 scope
- Can be added in future slices if needed

### Network Volume Discovery

**Not Included**:
- Automatic discovery on network volumes
- Scanning of mounted network drives
- Cloud storage volume scanning

**Rationale**:
- Network volumes may be slow or unavailable
- Requires handling of disconnected volumes
- Complexity beyond Slice 1 scope

### External Drive Auto-Discovery

**Not Included**:
- Automatic discovery when external drives are connected
- Scanning of removable media
- USB drive auto-detection

**Rationale**:
- Requires filesystem event monitoring
- Handling of disconnected drives
- Complexity beyond Slice 1 scope

## Discovery Process

### Step 1: Check Registry

1. Load previously known library locations from registry
2. For each location:
   - Check if path still exists
   - Check if path contains valid library
   - If valid, add to available libraries list
   - If invalid, remove from registry

### Step 2: Check User-Specified Locations

1. For each user-specified location:
   - Check if path exists and is accessible
   - Check if path contains valid library
   - If valid, add to available libraries list
   - Register in registry for future use

### Step 3: Present Available Libraries

1. List all discovered libraries
2. Show library name/path to user
3. Allow user to select library to open

## Performance Targets

- Discovery at known locations: < 2 seconds (SC-002)
- Discovery at user-specified locations: < 5 seconds (SC-003)
- Total discovery time: < 5 seconds for typical use cases

## Validation

This scope addresses:
- ✅ FR-004: Discover libraries at accessible locations (limited to known/specified)
- ✅ FR-010: Support multiple libraries (via registry)
- ✅ User Story 2: Open existing library (discovery aspect)
- ✅ SC-003: Discovery within 5 seconds (achievable with limited scope)

## Future Enhancements (P2)

- Full filesystem scanning
- Automatic discovery on volume mount
- Network volume discovery
- External drive auto-detection
- Background discovery
- Persistent registry storage
