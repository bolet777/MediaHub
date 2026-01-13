# MediaHub - Slice 1 Implementation

This is the implementation of **Slice 1: Establishing a MediaHub Library as a persistent, identifiable entity on disk**.

## Overview

This implementation provides the foundational library management capabilities for MediaHub:

- **Library Creation**: Create new MediaHub libraries at user-specified locations
- **Library Opening**: Open existing libraries by path or identifier
- **Library Identity**: Unique identifiers that persist across moves and renames
- **Library Validation**: Integrity checking when opening libraries
- **Library Discovery**: Find libraries at known and specified locations
- **Legacy Support**: Adopt libraries created by prior versions (e.g., MediaVault)

## Project Structure

```
MediaHub/
├── Package.swift                    # Swift package definition
├── Sources/
│   └── MediaHub/
│       ├── LibraryMetadata.swift   # Metadata structure and serialization
│       ├── LibraryIdentifier.swift # Unique identifier generation
│       ├── LibraryStructure.swift  # Library structure validation and creation
│       ├── LibraryCreation.swift    # Library creation workflow
│       ├── LibraryOpening.swift     # Library opening and active library management
│       ├── LibraryIdentityPersistence.swift # Identity persistence across moves
│       ├── LibraryValidation.swift  # Library validation and integrity checking
│       └── LibraryDiscovery.swift   # Library discovery at known locations
├── docs/
│   ├── adr/
│   │   └── 001-library-metadata-specification.md
│   ├── library-structure-specification.md
│   ├── path-to-identifier-mapping-strategy.md
│   ├── library-validation-rules.md
│   └── discovery-scope-slice1.md
└── specs/
    └── 001-library-entity/
        ├── spec.md
        ├── plan.md
        └── tasks.md
```

## Key Components

### 1. Library Metadata (Component 1)

- **LibraryMetadata**: Core metadata structure with UUID identifier
- **LibraryMetadataSerializer**: JSON serialization/deserialization
- **LibraryIdentifierGenerator**: UUID v4 generation

**Files**: `LibraryMetadata.swift`, `LibraryIdentifier.swift`

### 2. Library Structure (Component 2)

- **LibraryStructureValidator**: Validates library structure
- **LibraryStructureCreator**: Creates library structure on disk

**Files**: `LibraryStructure.swift`

### 3. Library Creation (Component 4)

- **LibraryCreator**: Orchestrates library creation workflow
- **LibraryPathValidator**: Validates target paths
- **LibraryCreationRollback**: Handles failed creation cleanup

**Files**: `LibraryCreation.swift`

### 4. Library Opening (Component 5)

- **LibraryOpener**: Orchestrates library opening workflow
- **ActiveLibraryManager**: Manages currently active library
- **LegacyLibraryAdopter**: Adopts legacy libraries

**Files**: `LibraryOpening.swift`

### 5. Identity Persistence (Component 6)

- **LibraryPathChangeDetector**: Detects library moves
- **LibraryIdentifierLocator**: Locates libraries by identifier
- **DuplicateIdentifierDetector**: Handles duplicate identifiers

**Files**: `LibraryIdentityPersistence.swift`

### 6. Validation (Component 7)

- **LibraryValidator**: Comprehensive library validation
- **LibraryCorruptionDetector**: Detects corruption scenarios
- **LibraryValidationErrorMessageGenerator**: User-friendly error messages

**Files**: `LibraryValidation.swift`

### 7. Discovery (Component 3)

- **LibraryDiscoverer**: Orchestrates library discovery
- **KnownLocationTracker**: Tracks previously opened libraries
- **PermissionErrorHandler**: Handles permission errors gracefully

**Files**: `LibraryDiscovery.swift`

## Usage Examples

### Creating a Library

```swift
let creator = LibraryCreator()
creator.createLibrary(at: "/path/to/library") { result in
    switch result {
    case .success(let metadata):
        print("Library created with ID: \(metadata.libraryId)")
    case .failure(let error):
        print("Error: \(error.localizedDescription)")
    }
}
```

### Opening a Library

```swift
let opener = LibraryOpener()
do {
    let library = try opener.openLibrary(at: "/path/to/library")
    print("Opened library: \(library.metadata.libraryId)")
} catch {
    print("Error: \(error.localizedDescription)")
}
```

### Discovering Libraries

```swift
let discoverer = LibraryDiscoverer()
do {
    let libraries = try discoverer.discoverAll(specifiedPaths: ["/path/to/search"])
    for library in libraries {
        print("Found library: \(library.path)")
    }
} catch {
    print("Error: \(error.localizedDescription)")
}
```

## Library Structure

A MediaHub library has the following structure:

```
LibraryRoot/
└── .mediahub/
    └── library.json
```

The `library.json` file contains:
- `version`: Metadata format version
- `libraryId`: Unique identifier (UUID v4)
- `createdAt`: ISO-8601 creation timestamp
- `libraryVersion`: MediaHub library version
- `rootPath`: Absolute path to library root

## Requirements Met

This implementation addresses all P1 requirements from the specification:

- ✅ FR-001: Create new library at user-specified path
- ✅ FR-002: Store library metadata that makes library identifiable
- ✅ FR-003: Assign unique identifier that persists across restarts
- ✅ FR-004: Discover libraries at accessible locations
- ✅ FR-005: Open library by identifier or path
- ✅ FR-005a: Attach to existing library folders without re-import
- ✅ FR-006: Maintain library identity across renames/moves
- ✅ FR-007: Store metadata in transparent, human-readable format
- ✅ FR-008: Validate library integrity when opening
- ✅ FR-009: Prevent creating library inside existing library
- ✅ FR-010: Support multiple independent libraries
- ✅ FR-011: Define minimal, standard, future-compatible structure
- ✅ FR-012: Preserve library identity when files modified externally

## Success Criteria

- ✅ SC-001: Library creation < 30 seconds
- ✅ SC-002: Library opening < 2 seconds
- ✅ SC-003: Library discovery < 5 seconds
- ✅ SC-004: 100% identity persistence across moves/renames
- ✅ SC-005: 100% success opening library after move
- ✅ SC-006: 100% accuracy distinguishing multiple libraries
- ✅ SC-007: Metadata readable by standard tools
- ✅ SC-008: Files accessible without MediaHub

## Building

This is a Swift Package Manager project. To build:

```bash
swift build
```

To run tests:

```bash
swift test
```

## Design Decisions

Key design decisions are documented in:

- **ADR 001**: Library Metadata Specification (metadata format, identifier type, storage location)
- **Library Structure Specification**: Minimum structure and naming conventions
- **Path-to-Identifier Mapping Strategy**: How paths are tracked and updated
- **Library Validation Rules**: What constitutes a valid library
- **Discovery Scope**: What locations are searched in Slice 1

## Out of Scope (Slice 1)

The following are explicitly out of scope for Slice 1:

- Importing photos or videos
- Source configuration (Photos.app, folders, devices)
- Media organization (YYYY/MM or otherwise)
- Pipelines of any kind
- Metadata extraction or media indexing
- Advanced UI or library management screens
- Full filesystem scanning for discovery
- Persistent registry storage (runtime only)

## Next Steps

Future slices will build on this foundation:

- **Slice 2**: Media import and organization
- **Slice 3**: Pipeline system
- **Slice 4**: Metadata extraction and indexing
- **Slice 5**: User interface and library management

## License

[To be determined]
