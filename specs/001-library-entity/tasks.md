# Implementation Tasks: MediaHub Library Entity (Slice 1)

**Feature**: MediaHub Library Entity  
**Specification**: `specs/001-library-entity/spec.md`  
**Plan**: `specs/001-library-entity/plan.md`  
**Slice**: 1 - Establishing a MediaHub Library as a persistent, identifiable entity on disk  
**Created**: 2025-01-27

## Task Organization

Tasks are organized by component and follow the implementation sequence defined in the plan. Each task is:
- Small and focused on a single deliverable
- Sequential (dependencies are clear)
- Traceable to plan components (referenced by component number)
- Excludes import, pipeline, and media organization tasks (out of scope for Slice 1)

---

## Component 1: Library Identity & Metadata Structure

**Plan Reference**: Component 1 (lines 38-70)  
**Dependencies**: None (Foundation)

### Task 1.1: Define Library Metadata Specification (ADR)
**Priority**: P1
- **Objective**: Define library identity, metadata fields, format choice, file location, and versioning strategy in a single authoritative specification
- **Deliverable**: Library Metadata ADR document
- **Traceability**: Plan Component 1 (identity, metadata, versioning decisions)
- **Acceptance**: Metadata spec covers FR-002, FR-003, FR-006, FR-007 and supports backward compatibility

### Task 1.2: Implement Metadata Serialization
**Priority**: P1
- **Objective**: Create code to serialize library metadata to chosen format
- **Deliverable**: Serialization function/module
- **Traceability**: Plan Component 1, Validation Point: "Metadata file can be read by standard system tools"
- **Acceptance**: Metadata can be serialized to chosen format, readable without MediaHub

### Task 1.3: Implement Metadata Deserialization
**Priority**: P1
- **Objective**: Create code to deserialize library metadata from chosen format
- **Deliverable**: Deserialization function/module
- **Traceability**: Plan Component 1, Validation Point: "Metadata file can be read by standard system tools"
- **Acceptance**: Metadata can be deserialized from chosen format, handles invalid data gracefully

### Task 1.4: Implement Unique Identifier Generation
**Priority**: P1
- **Objective**: Create function to generate unique identifiers for new libraries
- **Deliverable**: Identifier generation function/module
- **Traceability**: Plan Component 1, FR-003: "Assign unique identifier"
- **Acceptance**: Generated identifiers are unique and follow chosen format

---

## Component 2: Library Root Structure

**Plan Reference**: Component 2 (lines 73-103)  
**Dependencies**: Component 1 (metadata structure must be defined)

### Task 2.1: Define Minimum Library Structure
**Priority**: P1
- **Objective**: Specify minimum files/directories required to identify a MediaHub library
- **Deliverable**: Structure specification document
- **Traceability**: Plan Component 2, Key Decision: "Minimum files/directories required for library identification"
- **Acceptance**: Structure is minimal and sufficient for identification (FR-011)

### Task 2.2: Choose Metadata Directory Naming Convention
**Priority**: P1
- **Objective**: Decide on metadata directory name (`.mediahub/`, `Library/`, `.library/`)
- **Deliverable**: Decision document with naming choice and rationale
- **Traceability**: Plan Component 2, Key Decision: "Naming conventions for library metadata directory"
- **Acceptance**: Naming convention is documented and meets transparency requirements (FR-011)

### Task 2.3: Define Future-Compatible Structure Rules
**Priority**: P1
- **Traceability**: Plan Component 2, FR-011: "minimal, standard, and future-compatible"
- **Objective**: Establish rules for extending structure without breaking identification
- **Deliverable**: Extension rules document
- **Acceptance**: Rules ensure future additions don't break library identification

### Task 2.4: Implement Structure Validation Logic
**Priority**: P1
- **Objective**: Create function to validate that a directory matches MediaHub library structure
- **Deliverable**: Structure validation function/module
- **Traceability**: Plan Component 2, Validation Point: "Empty directory structure is sufficient to identify a MediaHub library"
- **Acceptance**: Function correctly identifies valid MediaHub library structures

### Task 2.5: Implement Structure Creation Logic
**Priority**: P1
- **Objective**: Create function to generate the standard library root structure on disk
- **Deliverable**: Structure creation function/module
- **Traceability**: Plan Component 2, FR-011: "Define a minimal, standard, and future-compatible library folder structure"
- **Acceptance**: Function creates complete library structure matching specification

---

## Component 4: Library Creation

**Plan Reference**: Component 4 (lines 144-180)  
**Dependencies**: Components 1 and 2 (metadata and structure must be defined)

### Task 4.1: Implement Path Validation
**Priority**: P1
- **Objective**: Create function to validate target directory path (existence, permissions, availability)
- **Deliverable**: Path validation function/module
- **Traceability**: Plan Component 4, Key Decision: "What validation to perform before creating library"
- **Acceptance**: Function validates paths correctly and handles edge cases (permissions, non-existent paths)

### Task 4.2: Implement Existing Library Detection
**Priority**: P1
- **Objective**: Create function to detect if target location already contains a MediaHub library
- **Deliverable**: Library detection function/module
- **Traceability**: Plan Component 4, FR-009: "Prevent creating library inside existing library"
- **Acceptance**: Function correctly identifies existing libraries at target location

### Task 4.3: Implement Non-Empty Directory Check
**Priority**: P1
- **Objective**: Create function to check if target directory is non-empty and determine handling
- **Deliverable**: Non-empty directory check function/module
- **Traceability**: Plan Component 4, Key Decision: "How to handle non-empty directories"
- **Acceptance**: Function correctly identifies non-empty directories and triggers confirmation workflow

### Task 4.4: Implement User Confirmation Workflow for Non-Empty Directories
**Priority**: P1
- **Objective**: Create UI/UX flow for user confirmation when target is non-empty
- **Deliverable**: Confirmation workflow implementation
- **Traceability**: Plan Component 4, FR-009: "offer to open instead" and Validation Point: "Non-empty directory handling works correctly"
- **Acceptance**: Users can confirm or cancel library creation in non-empty directories  
UI must remain minimal and limited to enabling the workflow (no advanced library management UI).

### Task 4.5: Implement Directory Creation Logic
**Priority**: P1
- **Objective**: Create function to create library root directory if it doesn't exist
- **Deliverable**: Directory creation function/module
- **Traceability**: Plan Component 4, FR-001: "Create a new library at user-specified directory path"
- **Acceptance**: Function creates directories with appropriate permissions

### Task 4.6: Implement Library Creation Orchestration
**Priority**: P1
- **Objective**: Create main function that orchestrates library creation workflow
- **Deliverable**: Library creation orchestration function/module
- **Traceability**: Plan Component 4, User Story 1: "Create a new library"
- **Acceptance**: Function coordinates all creation steps and meets SC-001 (under 30 seconds)

### Task 4.7: Implement Rollback Strategy for Failed Creation
**Priority**: P1
- **Objective**: Create logic to handle partial creation failures and cleanup
- **Deliverable**: Rollback/cleanup function/module
- **Traceability**: Plan Component 4, Key Decision: "How to handle creation failures"
- **Acceptance**: Failed creations are cleaned up, no orphaned files/directories remain

---

## Component 5: Library Opening & Attachment

**Plan Reference**: Component 5 (lines 183-218)  
**Dependencies**: Components 1, 2, and 4 (must be able to read metadata and validate structure)

### Task 5.1: Implement Library Detection by Path
**Priority**: P1
- **Objective**: Create function to detect if a given path is a valid MediaHub library
- **Deliverable**: Library detection by path function/module
- **Traceability**: Plan Component 5, FR-005: "Open an existing library by... path"
- **Acceptance**: Function correctly identifies valid libraries at specified paths

### Task 5.2: Implement Metadata Reading
**Priority**: P1
- **Objective**: Create function to read and parse library metadata from disk
- **Deliverable**: Metadata reading function/module
- **Traceability**: Plan Component 5, Responsibility: "Read and parse library metadata"
- **Acceptance**: Function reads metadata correctly and handles missing/corrupted files

### Task 5.3: Implement Legacy Library Detection
**Priority**: P1
- **Objective**: Create function to detect libraries created by prior versions
- **Deliverable**: Legacy library detection function/module
- **Traceability**: Plan Component 5, FR-005a: "Attach to existing library folder (including libraries created by prior versions)"
- **Acceptance**: Function identifies legacy libraries using file patterns and metadata locations

### Task 5.4: Implement Legacy Library Adoption Logic
**Priority**: P1
- **Objective**: Create function to adopt/attach legacy libraries without re-import
- **Deliverable**: Legacy library adoption function/module
- **Traceability**: Plan Component 5, FR-005a: "without requiring re-import of existing media files"
- **Acceptance**: Legacy libraries can be attached and recognized as valid MediaHub libraries

### Task 5.5: Implement Library Opening by Identifier
**Priority**: P1
- **Objective**: Create function to locate and open library by unique identifier
- **Deliverable**: Library opening by identifier function/module
- **Traceability**: Plan Component 5, FR-005: "Open an existing library by its unique identifier"
- **Acceptance**: Function locates libraries by identifier and opens them successfully

### Task 5.6: Implement Active Library Management
**Priority**: P1
- **Objective**: Create mechanism to track and set the currently active library
- **Deliverable**: Active library management function/module
- **Traceability**: Plan Component 5, Responsibility: "Make the opened library the active library"
- **Acceptance**: Only one library is active at a time, state persists across operations

### Task 5.7: Implement Library Opening Orchestration
**Priority**: P1
- **Objective**: Create main function that orchestrates library opening workflow
- **Deliverable**: Library opening orchestration function/module
- **Traceability**: Plan Component 5, User Story 2: "Open an existing library"
- **Acceptance**: Function coordinates all opening steps and meets SC-002 (within 2 seconds)

### Task 5.8: Implement Corrupted Metadata Handling
**Priority**: P1
- **Objective**: Create logic to detect and handle corrupted or missing metadata
- **Deliverable**: Corrupted metadata handling function/module
- **Traceability**: Plan Component 5, Responsibility: "Handle cases where library metadata is missing or corrupted"
- **Acceptance**: Corrupted libraries are detected and user is informed with clear error messages

---

## Component 6: Library Identity Persistence

**Plan Reference**: Component 6 (lines 221-254)  
**Dependencies**: Components 1, 4, and 5 (must have identifiers and opening capability)

### Task 6.1: Design Path-to-Identifier Mapping Strategy
**Priority**: P1
- **Objective**: Define how library paths are tracked and mapped to identifiers
- **Deliverable**: Mapping strategy document
- **Traceability**: Plan Component 6, Key Decision: "Where to store path-to-identifier mappings"
- **Acceptance**: Strategy supports locating libraries by identifier when path changes

### Task 6.2: Implement Path Change Detection
**Priority**: P1
- **Objective**: Create function to detect when a library has been moved to a new location
- **Deliverable**: Path change detection function/module
- **Traceability**: Plan Component 6, Responsibility: "Detect when a library has been moved to a new location"
- **Acceptance**: Function correctly detects library moves and renames

### Task 6.3: Implement Path Reference Update Logic
**Priority**: P1
- **Objective**: Create function to update internal references when library paths change
- **Deliverable**: Path update function/module
- **Traceability**: Plan Component 6, Responsibility: "Update internal references to library paths when moves are detected"
- **Acceptance**: Path references are updated correctly when libraries move

### Task 6.4: Implement Identifier-Based Library Location
**Priority**: P1
- **Objective**: Create function to locate library by identifier even when path is unknown
- **Deliverable**: Identifier-based location function/module
- **Traceability**: Plan Component 6, Responsibility: "Support locating libraries by unique identifier even when path changes"
- **Acceptance**: Libraries can be found by identifier after moves (SC-005: 100% success rate)

### Task 6.5: Implement Duplicate Identifier Detection
**Priority**: P1
- **Objective**: Create function to detect and handle conflicting library identifiers
- **Deliverable**: Duplicate identifier detection function/module
- **Traceability**: Plan Component 6, Responsibility: "Handle cases where multiple libraries have conflicting identifiers"
- **Acceptance**: Duplicate identifiers are detected and handled appropriately

### Task 6.6: Validate Identity Persistence Across Moves
**Priority**: P1
- **Objective**: Create tests to verify library identity persists across renames and moves
- **Deliverable**: Identity persistence test suite
- **Traceability**: Plan Component 6, SC-004: "Library unique identifiers remain consistent across 100% of library moves and renames"
- **Acceptance**: All move/rename scenarios preserve library identity

---

## Component 7: Library Validation & Integrity

**Plan Reference**: Component 7 (lines 257-289)  
**Dependencies**: Components 1, 2, and 5 (must validate metadata and structure)

### Task 7.1: Define Validation Rules
**Priority**: P1
- **Objective**: Document what constitutes a valid MediaHub library
- **Deliverable**: Validation rules specification
- **Traceability**: Plan Component 7, Responsibility: "Define what constitutes a valid MediaHub library"
- **Acceptance**: Rules clearly define valid vs. invalid library states

### Task 7.2: Implement Metadata File Validation
**Priority**: P1
- **Objective**: Create function to validate library metadata file presence and validity
- **Deliverable**: Metadata validation function/module
- **Traceability**: Plan Component 7, Responsibility: "Check library metadata file presence and validity"
- **Acceptance**: Function detects missing, corrupted, or invalid metadata files

### Task 7.3: Implement Structure Validation
**Priority**: P1
- **Objective**: Create function to validate library root directory structure
- **Deliverable**: Structure validation function/module
- **Traceability**: Plan Component 7, Responsibility: "Validate library root directory structure"
- **Acceptance**: Function validates structure matches specification

### Task 7.4: Implement Corruption Detection
**Priority**: P1
- **Objective**: Create function to detect common corruption scenarios
- **Deliverable**: Corruption detection function/module
- **Traceability**: Plan Component 7, Responsibility: "Detect common corruption scenarios"
- **Acceptance**: Function detects missing metadata, invalid structure, permission issues

### Task 7.5: Implement Error Message Generation
**Priority**: P1
- **Objective**: Create function to generate clear error messages for invalid libraries
- **Deliverable**: Error message generation function/module
- **Traceability**: Plan Component 7, Responsibility: "Provide clear error messages for invalid libraries"
- **Acceptance**: Error messages are clear, actionable, and help users understand issues

### Task 7.6: Integrate Validation into Opening Workflow
**Priority**: P1
- **Objective**: Integrate validation checks into library opening process
- **Deliverable**: Updated library opening workflow with validation
- **Traceability**: Plan Component 7, FR-008: "Validate library integrity when opening"
- **Acceptance**: All libraries are validated before opening, invalid libraries are rejected with clear errors

---

## Component 3: Library Discovery

Note: Full discovery orchestration and UI presentation are considered P2 enhancements for Slice 1.

**Plan Reference**: Component 3 (lines 106-141)  
**Dependencies**: Components 1, 2, and 7 (must identify libraries and validate them)

### Task 3.1: Define Discovery Scope for Slice 1
**Priority**: P1
- **Objective**: Document which locations will be checked for libraries (explicitly opened, previously known, user-specified)
- **Deliverable**: Discovery scope specification
- **Traceability**: Plan Component 3, Key Decision: "Which locations to check"
- **Acceptance**: Scope is clearly defined and limited to Slice 1 requirements (no full-volume scanning)

### Task 3.2: Implement Library Detection at Path
**Priority**: P1
- **Objective**: Create function to check if a specific path contains a valid library
- **Deliverable**: Path-based library detection function/module
- **Traceability**: Plan Component 3, Responsibility: "Identify libraries by detecting library metadata files"
- **Acceptance**: Function correctly identifies libraries at specified paths

### Task 3.3: Implement Previously Known Location Tracking
**Priority**: P1
- **Objective**: Create mechanism to track and store previously opened library locations
- **Deliverable**: Location tracking function/module
- **Traceability**: Plan Component 3, Key Decision: "explicitly opened, previously known, or user-specified locations"
- **Acceptance**: Previously opened libraries are tracked and can be rediscovered

### Task 3.4: Implement Discovery at Known Locations
**Priority**: P1
- **Objective**: Create function to discover libraries at previously known locations
- **Deliverable**: Known location discovery function/module
- **Traceability**: Plan Component 3, FR-004: "Discover and list all MediaHub libraries on accessible volumes"
- **Acceptance**: Function discovers libraries at tracked locations

### Task 3.5: Implement Permission Error Handling
**Priority**: P1
- **Objective**: Create logic to handle permission errors during discovery
- **Deliverable**: Permission error handling function/module
- **Traceability**: Plan Component 3, Key Decision: "How to handle permission errors during checking"
- **Acceptance**: Permission errors are handled gracefully, don't crash discovery

### Task 3.6: Implement Volume Availability Checking
**Priority**: P2
- **Objective**: Create function to check if volumes (external drives, network volumes) are available
- **Deliverable**: Volume availability checking function/module
- **Traceability**: Plan Component 3, Responsibility: "Handle cases where volumes are temporarily unavailable"
- **Acceptance**: Function handles unavailable volumes gracefully

### Task 3.7: Implement Library Discovery Orchestration
**Priority**: P2
- **Objective**: Create main function that orchestrates library discovery workflow
- **Deliverable**: Discovery orchestration function/module
- **Traceability**: Plan Component 3, FR-004: "Discover and list all MediaHub libraries"
- **Acceptance**: Function discovers libraries and meets SC-003 (within 5 seconds)

### Task 3.8: Implement Library List Presentation
**Priority**: P2
- **Objective**: Create UI/function to present discovered libraries to users
- **Deliverable**: Library list presentation function/module
- **Traceability**: Plan Component 3, Key Decision: "How to present discovered libraries to users"
- **Acceptance**: Users can see and select from discovered libraries  
UI must remain minimal and limited to enabling the workflow (no advanced library management UI).

---

## Component 8: Multiple Library Management

Note: Component 8 represents extended multi-library management and is treated as P2 for Slice 1.

**Plan Reference**: Component 8 (lines 292-326)  
**Dependencies**: All previous components (must support multiple libraries)

### Task 8.1: Design Library Registry Structure
**Priority**: P2
- **Objective**: Define how multiple libraries are tracked and stored (if central registry is needed)
- **Deliverable**: Registry structure specification
- **Traceability**: Plan Component 8, Key Decision: "Where to store application-level library registry"
- **Acceptance**: Registry structure supports tracking multiple libraries

### Task 8.2: Implement Library Registry
**Priority**: P2
- **Objective**: Create mechanism to register and track multiple libraries
- **Deliverable**: Library registry function/module
- **Traceability**: Plan Component 8, Responsibility: "Track multiple libraries (one active at a time)"
- **Acceptance**: Multiple libraries can be registered and tracked independently

### Task 8.3: Implement Unique Identifier Conflict Prevention
**Priority**: P2
- **Objective**: Create logic to ensure unique identifiers prevent conflicts between libraries
- **Deliverable**: Conflict prevention function/module
- **Traceability**: Plan Component 8, FR-003: "Unique identifiers prevent conflicts"
- **Acceptance**: No two libraries can have the same identifier (SC-006: 100% accuracy)

### Task 8.4: Implement Library Switching Logic
**Priority**: P2
- **Objective**: Create function to switch between libraries (one active at a time)
- **Deliverable**: Library switching function/module
- **Traceability**: Plan Component 8, Responsibility: "Support switching between libraries"
- **Acceptance**: Users can switch between libraries, only one is active at a time

### Task 8.5: Implement Per-Library State Management
**Priority**: P2
- **Objective**: Create mechanism to maintain separate state for each library
- **Deliverable**: Per-library state management function/module
- **Traceability**: Plan Component 8, Responsibility: "Maintain separate state for each library"
- **Acceptance**: Each library maintains independent state, no cross-contamination

### Task 8.6: Implement Multiple Library Discovery Integration
**Priority**: P2
- **Objective**: Integrate discovery with registry to handle multiple discovered libraries
- **Deliverable**: Multi-library discovery integration
- **Traceability**: Plan Component 8, Responsibility: "Handle cases where multiple libraries are discovered"
- **Acceptance**: Multiple discovered libraries are properly registered and can be selected

### Task 8.7: Validate Multiple Library Independence
**Priority**: P2
- **Objective**: Create tests to verify libraries operate independently without conflicts
- **Deliverable**: Multi-library independence test suite
- **Traceability**: Plan Component 8, Validation Point: "Multiple libraries can coexist without conflicts"
- **Acceptance**: All libraries maintain independent identity and state (SC-006: 100% accuracy)

---

## Task Summary

**Total Tasks**: 68 tasks across 8 components

**Implementation Sequence** (as per plan):
1. Component 1: Library Identity & Metadata Structure (4 tasks)
2. Component 2: Library Root Structure (5 tasks)
3. Component 4: Library Creation (7 tasks)
4. Component 5: Library Opening & Attachment (8 tasks)
5. Component 6: Library Identity Persistence (6 tasks)
6. Component 7: Library Validation & Integrity (6 tasks)
7. Component 3: Library Discovery (8 tasks)
8. Component 8: Multiple Library Management (7 tasks)

**Exclusions** (as requested):
- No import tasks
- No pipeline tasks
- No media organization tasks

**Traceability**: Each task references specific plan components, requirements (FR-XXX), success criteria (SC-XXX), and user stories where applicable.
