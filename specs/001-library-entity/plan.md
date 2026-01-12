# Implementation Plan: MediaHub Library Entity (Slice 1)

**Feature**: MediaHub Library Entity  
**Specification**: `specs/001-library-entity/spec.md`  
**Slice**: 1 - Establishing a MediaHub Library as a persistent, identifiable entity on disk  
**Created**: 2025-01-27

## Plan Scope

This plan implements **Slice 1 only**, which establishes the MediaHub Library as a persistent, identifiable entity on disk. This includes:

- Creating a new MediaHub library at a user-chosen location
- Attaching/opening an existing library structure on disk
- Uniquely identifying libraries and preserving identity across moves/renames
- Validating library integrity when opening
- Supporting multiple independent libraries

**Explicitly out of scope**:
- Importing photos or videos
- Defining or executing pipelines
- Media organization (YYYY/MM or otherwise)
- Source configuration (Photos.app, folders, devices)
- Metadata extraction or media indexing
- UI polish beyond what is strictly necessary to enable the workflows

## Constitutional Compliance

This plan adheres to the MediaHub Constitution:

- **Transparent Storage**: Library metadata stored as normal files in standard folder structures
- **Safe Operations**: User confirmation required before creating libraries in non-empty directories
- **Deterministic Behavior**: Library creation and identification produce consistent results
- **Interoperability First**: Library structure remains usable when files are modified externally
- **Scalability by Design**: Multiple libraries supported as first-class concern

## Work Breakdown

### Component 1: Library Identity & Metadata Structure

**Purpose**: Define how a MediaHub library is uniquely identified and what metadata must be stored to establish and maintain library identity.

**Responsibilities**:
- Define the unique identifier format and generation mechanism
- Define the library metadata schema (identifier, creation date, version, root path, etc.)
- Define the storage location and format for library metadata within the library root directory
- Ensure metadata format is transparent and human-readable (per FR-007)

**Requirements Addressed**:
- FR-002: Store library metadata that makes library identifiable
- FR-003: Assign unique identifier that persists across restarts
- FR-006: Maintain library identity across renames/moves
- FR-007: Store metadata in transparent, human-readable format
- FR-012: Preserve library identity when files modified externally

**Key Decisions**:
- Unique identifier type (UUID, ULID, or similar) and where it's stored
- Metadata file name and location within library root (e.g., `.mediahub/library.json` or `LibraryInfo.plist`)
- Metadata schema fields (minimum required: unique identifier, library version, creation timestamp)
- Whether to support versioning of the metadata format itself

**Validation Points**:
- Metadata file can be read by standard system tools without MediaHub
- Unique identifier persists across application restarts
- Metadata format is extensible for future requirements

**Risks & Open Questions**:
- How to handle metadata format versioning if schema evolves?
- Should metadata include checksums or integrity markers?
- How to handle libraries created by prior versions (legacy libraries) with different metadata formats?

---

### Component 2: Library Root Structure

**Purpose**: Define the standard folder structure within a library root directory that makes it identifiable as a MediaHub library.

**Responsibilities**:
- Define the minimum structure required to identify a directory as a MediaHub library
- Define where library metadata files are stored within the structure
- Ensure structure is minimal, standard, and future-compatible (per FR-011), and usable without MediaHub
- Support future extensibility without breaking existing libraries

**Requirements Addressed**:
- FR-002: Store library metadata that makes library identifiable
- FR-011: Define a minimal, standard, and future-compatible library folder structure usable without MediaHub
- FR-005a: Support attaching to existing libraries (including libraries created by prior versions) without re-import

**Key Decisions**:
- Minimum files/directories required for library identification
- Naming conventions for library metadata directory (e.g., `.mediahub/`, `Library/`, `.library/`)
- Whether to create placeholder directories for future use (e.g., `Media/`, `Metadata/`)
- How to detect libraries created by prior versions (file patterns, metadata locations)

**Validation Points**:
- Empty directory structure is sufficient to identify a MediaHub library
- Structure remains accessible via Finder and other file managers
- Structure supports future additions without breaking identification

**Risks & Open Questions**:
- Should hidden directories (`.mediahub/`) or visible directories (`Library/`) be used?
- How to handle case-sensitivity on different file systems?
- What is the minimum structure needed to distinguish MediaHub from legacy libraries?

---

### Component 3: Library Discovery

For Slice 1, discovery is limited to explicitly opened or previously known library locations; full filesystem-wide scanning is considered a future enhancement.

**Purpose**: Enable MediaHub to find and list all MediaHub libraries on accessible volumes.

**Responsibilities**:
- Implement logic to discover libraries at explicitly specified or previously known locations
- Identify libraries by detecting library metadata files
- Distinguish between MediaHub libraries and other directories
- Support discovery of libraries on external drives and network volumes
- Handle cases where volumes are temporarily unavailable

**Requirements Addressed**:
- FR-004: Discover and list all MediaHub libraries on accessible volumes
- FR-010: Support multiple independent libraries on the same system
- User Story 2: Open an existing library (discovery aspect)

**Key Decisions**:
- Which locations to check (explicitly opened, previously known, or user-specified locations)
- How to efficiently check for valid libraries at these locations
- How to handle permission errors during checking
- Whether to cache discovery results or check on-demand
- How to present discovered libraries to users

**Validation Points**:
- All valid MediaHub libraries at known or specified locations are discovered
- Discovery completes within performance targets (SC-003: within 5 seconds)
- Discovery handles edge cases (permission errors, inaccessible volumes, corrupted metadata)

**Risks & Open Questions**:
- Performance implications of scanning large directory trees (full-volume scanning is out of scope for Slice 1)
- How to handle libraries on network volumes that may be slow or unavailable?
- Should discovery be incremental or full scan each time? (full-volume scanning is considered a future enhancement)
- How to handle libraries on external drives that are disconnected?

---

### Component 4: Library Creation

**Purpose**: Enable users to create a new MediaHub library at a specified directory path.

**Responsibilities**:
- Validate the target directory path (existence, permissions, availability)
- Check if target location already contains a MediaHub library (per FR-009)
- Create the library root directory structure if it doesn't exist, following a minimal, standard, and future-compatible structure (per FR-011)
- Generate and store library metadata with unique identifier
- Initialize any required subdirectories
- Handle user confirmation for non-empty directories

**Requirements Addressed**:
- FR-001: Create a new library at user-specified directory path
- FR-002: Store library metadata that makes library identifiable
- FR-003: Assign unique identifier that persists across restarts
- FR-009: Prevent creating library inside existing library; offer to open instead
- FR-011: Define a minimal, standard, and future-compatible library folder structure
- User Story 1: Create a new library

**Key Decisions**:
- What validation to perform before creating library (directory exists, permissions, disk space)
- How to handle non-empty directories (warn and require confirmation)
- Whether to create placeholder subdirectories during initialization
- How to handle creation failures (partial creation, rollback strategy)

**Validation Points**:
- Library creation completes successfully and library is immediately identifiable
- Creation time meets performance targets (SC-001: under 30 seconds)
- Library can be opened immediately after creation
- Non-empty directory handling works correctly with user confirmation

**Risks & Open Questions**:
- What constitutes a "non-empty" directory? (any files, or only certain patterns?)
- Should creation be atomic (all-or-nothing) or allow partial recovery?
- How to handle insufficient disk space or permission errors during creation?

---

### Component 5: Library Opening & Attachment

**Purpose**: Enable MediaHub to open an existing library, including libraries created by prior versions.

**Responsibilities**:
- Validate that a directory is a valid MediaHub library
- Read and parse library metadata
- Handle libraries created by prior versions (legacy libraries) with different metadata formats
- Support opening by unique identifier or by path
- Make the opened library the active library
- Handle cases where library metadata is missing or corrupted

**Requirements Addressed**:
- FR-005: Open an existing library by unique identifier or path
- FR-005a: Attach to existing library folder (including legacy libraries) without re-import
- FR-008: Validate library integrity when opening
- User Story 2: Open an existing library
- User Story 1: Attach to existing library folder

**Key Decisions**:
- What validation constitutes "library integrity" (metadata present, structure valid, permissions)
- How to detect and handle libraries created by prior versions (file patterns, metadata migration)
- How to handle corrupted or missing metadata (repair, reject, or prompt user)
- Whether to support opening libraries by identifier when path has changed

**Validation Points**:
- Valid libraries open successfully and become active
- Opening time meets performance targets (SC-002: within 2 seconds)
- Libraries created by prior versions are recognized and can be attached
- Corrupted libraries are detected and handled appropriately

**Risks & Open Questions**:
- What level of corruption is acceptable vs. requiring user intervention?
- Should legacy library attachment trigger metadata migration or just adoption?
- How to handle libraries where metadata exists but structure is incomplete?

---

### Component 6: Library Identity Persistence

**Purpose**: Ensure library unique identifiers persist across directory renames and moves.

**Responsibilities**:
- Store unique identifier in a way that survives directory renames
- Detect when a library has been moved to a new location
- Update internal references to library paths when moves are detected
- Support locating libraries by unique identifier even when path changes
- Handle cases where multiple libraries have conflicting identifiers (should not occur, but must be handled)

**Requirements Addressed**:
- FR-006: Maintain library identity across renames/moves
- FR-003: Unique identifier persists across application restarts
- User Story 3: Identify library uniquely (persistence aspect)
- SC-004: Library identifiers remain consistent across 100% of moves/renames
- SC-005: Users can open library after moving 100% of the time

**Key Decisions**:
- How to detect library moves (path change detection, identifier lookup)
- Where to store path-to-identifier mappings (application preferences, library registry)
- How to handle libraries moved to inaccessible locations
- Whether to support automatic path updates or require user confirmation

**Validation Points**:
- Library identifier remains consistent after moves
- Libraries can be located by identifier even after path changes
- Move detection works reliably across different scenarios

**Risks & Open Questions**:
- Should MediaHub track library locations in a central registry, or rely solely on discovery?
- How to handle libraries moved to external drives that are later disconnected?
- What happens if a library is copied (not moved) - should it get a new identifier?

---

### Component 7: Library Validation & Integrity

**Purpose**: Validate library integrity when opening and detect corruption or invalid states.

**Responsibilities**:
- Define what constitutes a valid MediaHub library
- Check library metadata file presence and validity
- Validate library root directory structure
- Detect common corruption scenarios (missing metadata, invalid structure, permission issues)
- Provide clear error messages for invalid libraries
- Support repair or recovery where possible

**Requirements Addressed**:
- FR-008: Validate library integrity when opening
- FR-002: Ensure library is identifiable as MediaHub library
- Edge cases: corrupted metadata, missing files, invalid permissions

**Key Decisions**:
- What validation checks are required vs. optional
- How strict to be with validation (reject vs. warn vs. auto-repair)
- What constitutes "corruption" vs. "incomplete" library
- How to handle validation failures (error messages, recovery options)

**Validation Points**:
- Valid libraries pass all integrity checks
- Invalid libraries are detected and reported clearly
- Edge cases (corrupted metadata, missing structure) are handled appropriately

**Risks & Open Questions**:
- Should validation be strict (reject any deviation) or lenient (warn but allow)?
- How to distinguish between a library being created and a corrupted library?
- Should validation support automatic repair, or only detection?

---

### Component 8: Multiple Library Management

**Purpose**: Support multiple independent libraries on the same system without conflicts.

Slice 1 assumes a single active library at a time; simultaneous active libraries are out of scope.

**Responsibilities**:
- Track multiple libraries (one active at a time)
- Ensure unique identifiers prevent conflicts between libraries
- Support switching between libraries
- Maintain separate state for each library
- Handle cases where multiple libraries are discovered

**Requirements Addressed**:
- FR-010: Support multiple independent libraries on the same system
- FR-003: Unique identifiers prevent conflicts
- User Story 2: Switch between multiple libraries
- SC-006: Distinguish between multiple libraries with 100% accuracy

**Key Decisions**:
- How to track which library is currently active
- Where to store application-level library registry (if needed)
- How to present multiple libraries to users
- Simultaneous active libraries are out of scope for Slice 1

**Validation Points**:
- Multiple libraries can coexist without conflicts
- Each library maintains independent identity and state
- Switching between libraries works correctly

**Risks & Open Questions**:
- Should MediaHub support one active library at a time, or multiple? (Slice 1: only one active at a time)
- How to handle libraries with duplicate identifiers (should not occur, but must be handled)?
- Should there be a "default" or "recent" library selection?

---

## Implementation Sequence

The components should be implemented in the following order to manage dependencies:

1. **Component 1: Library Identity & Metadata Structure** (Foundation)
   - Must be defined first as all other components depend on it
   - Defines the core data structures and formats

2. **Component 2: Library Root Structure** (Foundation)
   - Can be defined in parallel with Component 1
   - Defines the physical structure on disk

3. **Component 4: Library Creation** (Core Functionality)
   - Depends on Components 1 and 2
   - Enables the primary user workflow

4. **Component 5: Library Opening & Attachment** (Core Functionality)
   - Depends on Components 1, 2, and 4
   - Enables the secondary user workflow

5. **Component 6: Library Identity Persistence** (Robustness)
   - Depends on Components 1, 4, and 5
   - Enhances existing functionality

6. **Component 7: Library Validation & Integrity** (Robustness)
   - Depends on Components 1, 2, and 5
   - Enhances existing functionality

7. **Component 3: Library Discovery** (Enhancement)
   - Depends on Components 1, 2, and 7
   - Enables finding libraries across volumes

8. **Component 8: Multiple Library Management** (Enhancement)
   - Depends on all previous components
   - Completes the feature set

## Traceability Matrix

| Component | Functional Requirements | User Stories | Success Criteria |
|-----------|------------------------|--------------|------------------|
| Component 1: Identity & Metadata | FR-002, FR-003, FR-006, FR-007, FR-012 | Story 3 | SC-004, SC-007 |
| Component 2: Root Structure | FR-002, FR-011, FR-005a | Story 1, Story 2 | SC-007, SC-008 |
| Component 3: Discovery | FR-004, FR-010 | Story 2 | SC-003, SC-006 |
| Component 4: Creation | FR-001, FR-002, FR-003, FR-009, FR-011 | Story 1 | SC-001, SC-007, SC-008 |
| Component 5: Opening | FR-005, FR-005a, FR-008 | Story 1, Story 2 | SC-002, SC-005 |
| Component 6: Identity Persistence | FR-003, FR-006 | Story 3 | SC-004, SC-005 |
| Component 7: Validation | FR-002, FR-008 | Story 2 | SC-002, SC-005 |
| Component 8: Multiple Libraries | FR-003, FR-010 | Story 2, Story 3 | SC-006 |

## Risks & Mitigations

### High Risk Items

1. **Library Identity Across Moves**
   - **Risk**: Libraries moved externally may not be discoverable by identifier
   - **Mitigation**: Implement robust discovery and path tracking mechanisms
   - **Validation**: Test moving libraries to various locations and reopening

2. **Legacy Library Compatibility**
   - **Risk**: Existing libraries created by prior versions may not be fully compatible
   - **Mitigation**: Define clear detection and adoption rules for legacy libraries
   - **Validation**: Test with actual legacy library structures

3. **Performance at Scale**
   - **Risk**: Discovery and validation may be slow with many libraries or large directory trees
   - **Mitigation**: Implement efficient scanning and caching strategies
   - **Validation**: Test with multiple libraries and large directory structures

### Medium Risk Items

1. **Metadata Format Evolution**
   - **Risk**: Future changes to metadata format may break existing libraries
   - **Mitigation**: Design metadata format with versioning and extensibility
   - **Validation**: Test backward compatibility scenarios

2. **File System Differences**
   - **Risk**: Different file systems (APFS, HFS+, network volumes) may behave differently
   - **Mitigation**: Test on multiple file system types and handle differences explicitly
   - **Validation**: Test on various file system configurations

3. **Concurrent Access**
   - **Risk**: Multiple instances or external tools may conflict
   - **Mitigation**: Design for read-only external access; handle concurrent MediaHub instances
   - **Validation**: Test with external file modifications and multiple instances

## Open Questions Requiring Resolution

1. **Metadata Storage Format**
   - Should metadata be JSON, plist, or another format (e.g., YAML, TOML)?
   - What is the trade-off between human-readability and parsing performance?

2. **Library Metadata Location**
   - Should metadata be in a hidden directory (`.mediahub/`) or visible (`Library/`)?
   - How does this affect transparency and user accessibility?

3. **Legacy Library Adoption Strategy**
   - Should libraries created by prior versions (e.g., MediaVault) be migrated to new format or adopted as-is?
   - What is the minimum structure needed to identify a legacy library (e.g., MediaVault)?

4. **Path Tracking Strategy**
   - Should MediaHub maintain a central registry of library locations?
   - Or rely solely on discovery scanning?

5. **Validation Strictness**
   - How strict should library validation be?
   - Should MediaHub auto-repair minor issues or require user intervention?

6. **Multiple Library UI**
   - How should users select between multiple libraries?
   - Should there be a "recent libraries" or "default library" concept?

## Validation & Testing Strategy

### Unit Testing Focus Areas

- Library metadata serialization/deserialization
- Unique identifier generation and persistence
- Library structure validation
- Path normalization and comparison

### Integration Testing Focus Areas

- End-to-end library creation workflow
- End-to-end library opening workflow
- Library discovery across multiple volumes
- Library identity persistence across moves/renames

### Acceptance Testing Scenarios

All acceptance scenarios from the specification should be testable:
- User Story 1: All 5 acceptance scenarios
- User Story 2: All 4 acceptance scenarios  
- User Story 3: All 4 acceptance scenarios

### Edge Case Testing

- Libraries on external drives (connected/disconnected)
- Libraries on network volumes (available/unavailable)
- Corrupted metadata files
- Missing library structure files
- Permission errors
- Insufficient disk space
- Non-empty directories during creation
- Libraries moved to different volumes

## Success Criteria Validation

Each success criterion must be validated:

- **SC-001** (Creation < 30 seconds): Measure library creation time
- **SC-002** (Opening < 2 seconds): Measure library opening time
- **SC-003** (Discovery < 5 seconds): Measure library discovery time
- **SC-004** (100% identity persistence): Test moves/renames exhaustively
- **SC-005** (100% open after move): Test opening after various move scenarios
- **SC-006** (100% library distinction): Test with multiple libraries
- **SC-007** (Metadata readable): Verify with standard tools
- **SC-008** (Files accessible): Verify via Finder/file managers

## Dependencies & Prerequisites

### External Dependencies
- File system access APIs (platform-specific)
- Parsing support for a transparent, human-readable metadata format
- UUID generation utilities (if using UUIDs)

### Internal Dependencies
- None (Slice 1 is foundational)

### Future Dependencies Created
- Slice 2+ will depend on library identity and structure defined here
- Pipeline system will depend on library root structure
- Media import will depend on library creation and opening

## Notes

- This plan intentionally avoids specifying implementation technologies (languages, frameworks, storage formats) except where unavoidable for clarity
- All components should be designed with future extensibility in mind
- The plan focuses on correctness and robustness over performance optimization (performance targets are defined in success criteria)
- Each component should be independently testable where possible
- The plan assumes a single-user, single-machine context (multi-user scenarios are out of scope for Slice 1)
