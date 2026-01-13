# Implementation Tasks: MediaHub Sources & Import Detection (Slice 2)

**Feature**: MediaHub Sources & Import Detection  
**Specification**: `specs/002-sources-import-detection/spec.md`  
**Plan**: `specs/002-sources-import-detection/plan.md`  
**Slice**: 2 - Attaching Sources and detecting new media items for import  
**Created**: 2026-01-12

## Task Organization

Tasks are organized by component and follow the implementation sequence defined in the plan. Each task is:
- Small and focused on a single deliverable
- Sequential (dependencies are clear)
- Traceable to plan components (referenced by component number)
- Excludes import, copying, media organization, pipelines, and UI beyond minimal enablement (out of scope for Slice 2)

---

## Component 1: Source Model & Identity

**Plan Reference**: Component 1 (lines 42-80)  
**Dependencies**: None (Foundation)

### Task 1.1: Define Source Data Structure
**Priority**: P1
- **Objective**: Define the Source data structure including type, path, identity, and metadata fields
- **Deliverable**: Source data structure definition (struct/class)
- **Traceability**: Plan Component 1, Responsibility: "Define the Source data structure (type, path, identity, metadata)"
- **Acceptance**: Structure supports FR-001, FR-002, FR-004, FR-005, FR-017; includes all required fields for folder-based Sources

### Task 1.2: Design Source Identity Mechanism
**Priority**: P1
- **Objective**: Document in ADR: how Sources are uniquely identified and persist across application restarts
- **Deliverable**: Source Identity ADR (Component 1)
- **Traceability**: Plan Component 1, Key Decision: "Source identity mechanism (path-based, volume-based, or hybrid approach)"
- **Acceptance**: Identity mechanism supports FR-004 (persists across restarts) and FR-017 (transparent format); works for folder-based Sources

### Task 1.3: Implement Source Identity Generation
**Priority**: P1
- **Objective**: Create function to generate unique Source identifiers
- **Deliverable**: Source identity generation function/module
- **Traceability**: Plan Component 1, Responsibility: "Define Source identity mechanism"
- **Acceptance**: Generated identifiers are unique and follow chosen mechanism; identifiers persist across restarts

### Task 1.4: Define Source Types Enumeration
**Priority**: P1
- **Objective**: Define Source type enumeration (folder-based for P1; extensible for future types)
- **Deliverable**: Source type enumeration/definition
- **Traceability**: Plan Component 1, Responsibility: "Define Source types (folder-based for P1; extensible for future types)"
- **Acceptance**: Enumeration includes folder-based type; design allows future extension

### Task 1.5: Implement Source Metadata Schema
**Priority**: P1
- **Objective**: Define and implement Source metadata schema (identifier, type, path, attachment timestamp, etc.)
- **Deliverable**: Source metadata schema definition and implementation
- **Traceability**: Plan Component 1, Key Decision: "Source metadata schema (identifier, type, path, attachment timestamp, etc.)"
- **Acceptance**: Schema includes all required fields; supports FR-017 (transparent, human-readable format)

---

## Component 2: Source-Library Association Persistence

**Plan Reference**: Component 2 (lines 82-122)  
**Dependencies**: Component 1 (Source model must be defined)

### Task 2.1: Design Association Storage Format
**Priority**: P1
- **Objective**: Document in ADR: storage format and location for Source–Library associations
- **Deliverable**: Source Associations ADR (Component 2)
- **Traceability**: Plan Component 2, Key Decision: "Where to store associations (within Library structure, e.g., `.mediahub/sources/`)" and "Association storage format (transparent, human-readable format)"
- **Acceptance**: Format is transparent and human-readable (FR-017); location is within Library structure

### Task 2.2: Define Association Schema
**Priority**: P1
- **Objective**: Define association data schema (Library ID, Source ID, attachment metadata, etc.)
- **Deliverable**: Association schema definition
- **Traceability**: Plan Component 2, Key Decision: "Association schema (Library ID, Source ID, attachment metadata, etc.)"
- **Acceptance**: Schema supports FR-001, FR-002, FR-004; includes all required fields

### Task 2.3: Implement Association Creation
**Priority**: P1
- **Objective**: Create function to create and store Source-Library associations
- **Deliverable**: Association creation function/module
- **Traceability**: Plan Component 2, Responsibility: "Implement association creation (attaching a Source to a Library)" and User Story 1
- **Acceptance**: Associations are created and stored correctly; supports FR-001, FR-002

### Task 2.4: Implement Association Retrieval
**Priority**: P1
- **Objective**: Create function to retrieve Source-Library associations for a Library
- **Deliverable**: Association retrieval function/module
- **Traceability**: Plan Component 2, Responsibility: "Implement association retrieval (listing Sources for a Library)"
- **Acceptance**: Function retrieves all Sources for a given Library; supports FR-002 (multiple Sources per Library)

### Task 2.5: Implement Association Validation
**Priority**: P1
- **Objective**: Create function to validate that associations are valid and refer to existing Sources
- **Deliverable**: Association validation function/module
- **Traceability**: Plan Component 2, Responsibility: "Implement association validation (ensuring associations are valid)"
- **Acceptance**: Function detects invalid, corrupted, or orphaned associations

### Task 2.6: Implement Association Removal
**Priority**: P1
- **Objective**: Create function to remove Source-Library associations (detaching a Source)
- **Deliverable**: Association removal function/module
- **Traceability**: Plan Component 2, Responsibility: "Support association removal (detaching a Source from a Library)"
- **Acceptance**: Associations can be removed cleanly; removal is persistent

### Task 2.7: Validate Association Persistence
**Priority**: P1
- **Objective**: Create tests to verify associations persist across application restarts
- **Deliverable**: Association persistence test suite
- **Traceability**: Plan Component 2, SC-008: "Source associations persist across application restarts 100% of the time"
- **Acceptance**: All association persistence scenarios pass

---

## Component 3: Source Validation & Accessibility

**Plan Reference**: Component 3 (lines 124-164)  
**Dependencies**: Components 1 and 2 (Source model and associations must be defined)

### Task 3.1: Define Validation Requirements
**Priority**: P1
- **Objective**: Document in ADR: required validation checks for Source attachment
- **Deliverable**: Source Validation ADR (Component 3)
- **Traceability**: Plan Component 3, Key Decision: "What validation checks are required vs. optional"
- **Acceptance**: Requirements cover FR-003 (validate accessibility and permissions); include folder-based Source checks

### Task 3.2: Implement Path Existence Check
**Priority**: P1
- **Objective**: Create function to validate Source path exists and is accessible
- **Deliverable**: Path existence validation function/module
- **Traceability**: Plan Component 3, Responsibility: "Validate Source path exists and is accessible"
- **Acceptance**: Function correctly identifies existing vs. non-existent paths; handles edge cases

### Task 3.3: Implement Read Permission Check
**Priority**: P1
- **Objective**: Create function to validate Source has read permissions
- **Deliverable**: Read permission validation function/module
- **Traceability**: Plan Component 3, Responsibility: "Validate Source has read permissions" and User Story 1, Acceptance Scenario 3
- **Acceptance**: Function correctly identifies readable vs. permission-denied paths

### Task 3.4: Implement Source Type Validation
**Priority**: P1
- **Objective**: Create function to validate Source type (folder-based for P1)
- **Deliverable**: Source type validation function/module
- **Traceability**: Plan Component 3, Responsibility: "Validate Source type (folder-based for P1)"
- **Acceptance**: Function validates folder-based Sources correctly; rejects invalid types

### Task 3.5: Implement Pre-Attachment Validation
**Priority**: P1
- **Objective**: Create function that performs all validation checks before Source attachment
- **Deliverable**: Pre-attachment validation orchestration function/module
- **Traceability**: Plan Component 3, Responsibility: "Check Source accessibility before attachment" and User Story 1, Acceptance Scenario 2
- **Acceptance**: Function performs all required checks; meets SC-002 (validation within 2 seconds)

### Task 3.6: Implement Detection-Time Validation
**Priority**: P1
- **Objective**: Create function to check Source accessibility during detection runs
- **Deliverable**: Detection-time validation function/module
- **Traceability**: Plan Component 3, Responsibility: "Check Source accessibility during detection" and User Story 2, Acceptance Scenario 5
- **Acceptance**: Function detects inaccessible Sources during detection; handles gracefully

### Task 3.7: Implement Error Message Generation
**Priority**: P1
- **Objective**: Create function to generate clear, actionable error messages for validation failures
- **Deliverable**: Error message generation function/module
- **Traceability**: Plan Component 3, Responsibility: "Report clear, actionable error messages for validation failures" and FR-012, SC-009
- **Acceptance**: Error messages are clear and actionable; meet SC-009 (reported within 5 seconds)

---

## Component 4: Source Scanning & Media Detection

**Plan Reference**: Component 4 (lines 166-208)  
**Dependencies**: Component 1 (Source model must be defined)

### Task 4.1: Define Media File Format Support
**Priority**: P1
- **Objective**: Document in ADR: which categories of common image and video formats are supported in P1
- **Deliverable**: Media Detection ADR (Component 4)
- **Traceability**: Plan Component 4, FR-016: "Support detection of common image and video file formats" and Key Decision: "Which categories of common image and video formats to include in P1"
- **Acceptance**: Specification covers common formats; supports FR-016

### Task 4.2: Implement Media File Identification
**Priority**: P1
- **Objective**: Create function to identify media files by extension and/or content type
- **Deliverable**: Media file identification function/module
- **Traceability**: Plan Component 4, Responsibility: "Identify media files by extension and/or content type"
- **Acceptance**: Function correctly identifies supported media formats; excludes non-media files

### Task 4.3: Implement Recursive Folder Scanning
**Priority**: P1
- **Objective**: Create function to recursively scan folder-based Sources for files
- **Deliverable**: Recursive folder scanning function/module
- **Traceability**: Plan Component 4, Responsibility: "Recursively scan folder-based Sources for media files" and "Handle nested folder structures at various depths"
- **Acceptance**: Function scans all nested folders; handles various depths; handles edge cases

### Task 4.4: Implement File Metadata Extraction
**Priority**: P1
- **Objective**: Create function to extract basic file metadata (path, size, modification date, etc.)
- **Deliverable**: File metadata extraction function/module
- **Traceability**: Plan Component 4, Responsibility: "Extract basic file metadata (path, size, modification date, etc.)"
- **Acceptance**: Function extracts required metadata; handles files with missing metadata gracefully

### Task 4.5: Implement Edge Case Handling
**Priority**: P1
- **Objective**: Create logic to handle edge cases (symbolic links, locked files, corrupted files, etc.)
- **Deliverable**: Edge case handling function/module
- **Traceability**: Plan Component 4, Responsibility: "Handle edge cases (symbolic links, locked files, corrupted files, etc.)"
- **Acceptance**: Edge cases are handled gracefully; scanning continues despite individual file errors

### Task 4.6: Implement Read-Only Scanning Enforcement
**Priority**: P1
- **Objective**: Ensure scanning operations are read-only and never modify Source files
- **Deliverable**: Read-only scanning implementation
- **Traceability**: Plan Component 4, Responsibility: "Ensure scanning is read-only (never modifies Source files)" and FR-011
- **Acceptance**: Scanning operations are verified to be read-only; no Source files are modified

### Task 4.7: Validate Scanning Performance
**Priority**: P1
- **Objective**: Create tests to verify scanning meets performance targets
- **Deliverable**: Scanning performance test suite
- **Traceability**: Plan Component 4, SC-003: "Detect candidate items from Source with 1000 files within 30 seconds"
- **Acceptance**: Scanning completes within 30 seconds for Sources with 1000 files

---

## Component 5: Library Comparison & New Item Detection

**Plan Reference**: Component 5 (lines 210-254)  
**Dependencies**: Component 4 (scanning must be implemented) and Library structure from Slice 1

### Task 5.1: Design Comparison Mechanism
**Priority**: P1
- **Objective**: Document in ADR: the simple, deterministic comparison mechanism used to decide "known vs new"
- **Deliverable**: Comparison ADR (Component 5)
- **Traceability**: Plan Component 5, Key Decision: "Comparison mechanism (how to determine if an item is 'known' to the Library)" and "Which simple, deterministic comparison mechanism to use in P1"
- **Acceptance**: Mechanism is simple, deterministic, and non-fuzzy; supports FR-007, FR-008, FR-009

### Task 5.2: Implement Library Content Query
**Priority**: P1
- **Objective**: Create function to query Library contents for comparison (using Slice 1 Library structure)
- **Deliverable**: Library content query function/module
- **Traceability**: Plan Component 5, Responsibility: "Compare candidate items against Library contents"
- **Acceptance**: Function retrieves Library contents needed for comparison; integrates with Slice 1 Library structure

### Task 5.3: Implement Item Comparison Logic
**Priority**: P1
- **Objective**: Create function to compare a candidate item against Library contents using chosen mechanism
- **Deliverable**: Item comparison function/module
- **Traceability**: Plan Component 5, Responsibility: "Identify items already known to the Library"
- **Acceptance**: Function correctly identifies known vs. new items; comparison is deterministic

### Task 5.4: Implement Known Item Exclusion
**Priority**: P1
- **Objective**: Create function to exclude known items from candidate lists
- **Deliverable**: Known item exclusion function/module
- **Traceability**: Plan Component 5, Responsibility: "Exclude known items from candidate lists" and FR-008
- **Acceptance**: Known items are correctly excluded; only new items remain in candidate list

### Task 5.5: Ensure Deterministic Comparison
**Priority**: P1
- **Objective**: Ensure comparison produces deterministic, repeatable results
- **Deliverable**: Deterministic comparison implementation
- **Traceability**: Plan Component 5, Responsibility: "Ensure comparison is deterministic and repeatable" and FR-009, SC-004, SC-005
- **Acceptance**: Same inputs produce same comparison results; comparison is deterministic

### Task 5.6: Validate Comparison Accuracy
**Priority**: P1
- **Objective**: Create tests to verify comparison accuracy
- **Deliverable**: Comparison accuracy test suite
- **Traceability**: Plan Component 5, SC-006: "Correctly identify items already known to Library with 100% accuracy"
- **Acceptance**: Comparison achieves 100% accuracy in identifying known vs. new items

---

## Component 6: Detection Result Model & Storage

**Plan Reference**: Component 6 (lines 256-297)  
**Dependencies**: Components 4 and 5 (scanning and comparison must be implemented)

### Task 6.1: Design Detection Result Data Structure
**Priority**: P1
- **Objective**: Define detection result data structure (candidate items, status, explanations)
- **Deliverable**: Detection result data structure definition
- **Traceability**: Plan Component 6, Responsibility: "Define detection result data structure (candidate items, status, explanations)"
- **Acceptance**: Structure supports FR-010, FR-013; includes all required fields for explainable results

### Task 6.2: Define Exclusion Reason Enumeration
**Priority**: P1
- **Objective**: Define how exclusion reasons are represented (enumeration, codes, or descriptive text)
- **Deliverable**: Exclusion reason enumeration/definition
- **Traceability**: Plan Component 6, Key Decision: "How to represent exclusion reasons (enumeration, codes, or descriptive text)"
- **Acceptance**: Exclusion reasons are clear and explainable; supports SC-007 (explainable results)

### Task 6.3: Design Result Storage Format
**Priority**: P1
- **Objective**: Document in ADR: storage format and location for detection results
- **Deliverable**: Detection Results ADR (Component 6)
- **Traceability**: Plan Component 6, Key Decision: "Storage location for detection results (within Library structure)" and "Storage format (transparent, human-readable format)"
- **Acceptance**: Format is transparent and human-readable (FR-017); location is within Library structure

### Task 6.4: Implement Result Serialization
**Priority**: P1
- **Objective**: Create function to serialize detection results to storage format
- **Deliverable**: Result serialization function/module
- **Traceability**: Plan Component 6, Responsibility: "Store detection results persistently"
- **Acceptance**: Results are serialized correctly; format is transparent and human-readable

### Task 6.5: Implement Result Deserialization
**Priority**: P1
- **Objective**: Create function to deserialize detection results from storage format
- **Deliverable**: Result deserialization function/module
- **Traceability**: Plan Component 6, Responsibility: "Store detection results persistently"
- **Acceptance**: Results are deserialized correctly; handles corrupted or invalid data gracefully

### Task 6.6: Implement Result Retrieval
**Priority**: P1
- **Objective**: Create function to retrieve stored detection results
- **Deliverable**: Result retrieval function/module
- **Traceability**: Plan Component 6, User Story 3: "View detection results"
- **Acceptance**: Function retrieves results correctly; supports viewing results from different runs

### Task 6.7: Implement Result Comparison Support
**Priority**: P1
- **Objective**: Create functionality to enable comparison of results from different detection runs
- **Deliverable**: Result comparison function/module
- **Traceability**: Plan Component 6, Responsibility: "Enable comparison of results from different detection runs" and User Story 3, Acceptance Scenario 5
- **Acceptance**: Results from different runs can be compared; differences are identifiable

### Task 6.8: Implement Result Metadata Storage
**Priority**: P1
- **Objective**: Ensure detection results include necessary metadata (timestamp, Source, etc.)
- **Deliverable**: Result metadata implementation
- **Traceability**: Plan Component 6, Responsibility: "Support auditable results (detection run metadata, timestamps, etc.)"
- **Acceptance**: Results include all required metadata for auditability

---

## Component 7: Detection Execution & Orchestration

**Plan Reference**: Component 7 (lines 299-346)  
**Dependencies**: Components 3, 4, 5, and 6 (validation, scanning, comparison, and results must be implemented)

### Task 7.1: Design Detection Execution Flow
**Priority**: P1
- **Objective**: Document in ADR: the end-to-end detection execution flow (scan → compare → generate results)
- **Deliverable**: Detection Orchestration ADR (Component 7)
- **Traceability**: Plan Component 7, Key Decision: "Detection execution flow (scan → compare → generate results)"
- **Acceptance**: Flow coordinates all components correctly; supports FR-009, FR-010, FR-011

### Task 7.2: Implement Source Scanning Coordination
**Priority**: P1
- **Objective**: Create function to coordinate Source scanning within detection workflow
- **Deliverable**: Scanning coordination function/module
- **Traceability**: Plan Component 7, Responsibility: "Coordinate Source scanning and Library comparison"
- **Acceptance**: Scanning is coordinated correctly; integrates with Component 4

### Task 7.3: Implement Comparison Coordination
**Priority**: P1
- **Objective**: Create function to coordinate Library comparison within detection workflow
- **Deliverable**: Comparison coordination function/module
- **Traceability**: Plan Component 7, Responsibility: "Coordinate Source scanning and Library comparison"
- **Acceptance**: Comparison is coordinated correctly; integrates with Component 5

### Task 7.4: Implement Result Generation Coordination
**Priority**: P1
- **Objective**: Create function to coordinate result generation within detection workflow
- **Deliverable**: Result generation coordination function/module
- **Traceability**: Plan Component 7, Responsibility: "Execute detection runs end-to-end"
- **Acceptance**: Result generation is coordinated correctly; integrates with Component 6

### Task 7.5: Implement Detection Orchestration
**Priority**: P1
- **Objective**: Create main function that orchestrates the complete detection workflow
- **Deliverable**: Detection orchestration function/module
- **Traceability**: Plan Component 7, Responsibility: "Execute detection runs end-to-end" and User Story 2
- **Acceptance**: Orchestration coordinates all components; executes end-to-end successfully

### Task 7.6: Implement Determinism Enforcement
**Priority**: P1
- **Objective**: Ensure detection execution is deterministic (consistent ordering, no side effects)
- **Deliverable**: Determinism enforcement implementation
- **Traceability**: Plan Component 7, Responsibility: "Ensure detection is deterministic and repeatable" and FR-009, SC-004, SC-005
- **Acceptance**: Detection produces identical results for identical Source states; meets SC-004 and SC-005

### Task 7.7: Implement Interruption Handling
**Priority**: P1
- **Objective**: Create logic to handle detection interruptions gracefully
- **Deliverable**: Interruption handling function/module
- **Traceability**: Plan Component 7, Responsibility: "Handle detection interruptions gracefully" and FR-014, SC-010
- **Acceptance**: Interruptions are handled gracefully; detection can be safely interrupted; meets SC-010

### Task 7.8: Implement Error Reporting
**Priority**: P1
- **Objective**: Create function to report progress and errors during detection
- **Deliverable**: Error reporting function/module
- **Traceability**: Plan Component 7, Responsibility: "Report progress and errors during detection" and FR-012
- **Acceptance**: Errors are reported clearly; progress reporting is informative

### Task 7.9: Validate Safe Re-runs
**Priority**: P1
- **Objective**: Create tests to verify detection can be safely re-run without side effects
- **Deliverable**: Safe re-run test suite
- **Traceability**: Plan Component 7, Responsibility: "Support safe re-runs of detection" and FR-010, User Story 4, SC-005
- **Acceptance**: Re-running detection on unchanged Source produces identical results; no side effects occur

### Task 7.10: Validate Read-Only Operations
**Priority**: P1
- **Objective**: Create tests to verify detection never modifies Source files
- **Deliverable**: Read-only operation test suite
- **Traceability**: Plan Component 7, Responsibility: "Ensure no side effects (read-only operations)" and FR-011
- **Acceptance**: All detection operations are verified to be read-only; no Source files are modified

---

## Validation Deliverable

### Task V.1: Create Validation Document
**Priority**: P1
- **Objective**: Create validation checklist document for Slice 2
- **Deliverable**: `specs/002-sources-import-detection/validation.md`
- **Traceability**: Plan Validation & Testing Strategy (lines 503-560)
- **Acceptance**: Document includes validation commands, acceptance scenarios, success criteria validation, and edge case testing guidance

### Task V.2: Implement Unit Tests
**Priority**: P1
- **Objective**: Create unit tests covering key acceptance scenarios for all components
- **Deliverable**: Unit test suite under `Tests/MediaHubTests/`
- **Traceability**: Plan Unit Testing Focus Areas (lines 505-514) and all User Story acceptance scenarios
- **Acceptance**: Tests cover Source identity, association persistence, validation, scanning, comparison, results, and orchestration; all tests pass

### Task V.3: Implement Integration Tests
**Priority**: P1
- **Objective**: Create integration tests covering end-to-end workflows
- **Deliverable**: Integration test suite under `Tests/MediaHubTests/`
- **Traceability**: Plan Integration Testing Focus Areas (lines 515-523)
- **Acceptance**: Tests cover end-to-end Source attachment, detection workflow, persistence, determinism, and error handling; all tests pass

---

## P2 Tasks (Out of Scope for Slice 2)

The following tasks are explicitly out of scope for Slice 2 but are documented for future reference:

### Component 8: Source Status & Health Monitoring (P2)

**Plan Reference**: Component 8 (lines 349-384)  
**Note**: This component is P2 and explicitly out of scope for Slice 2.

#### Task 8.1: Implement Source Status Checking (P2)
- **Objective**: Create function to check Source accessibility status
- **Deliverable**: Source status checking function/module
- **Traceability**: Plan Component 8, Responsibility: "Check Source accessibility status"
- **Acceptance**: Function reports Source status accurately

#### Task 8.2: Implement Move/Rename Detection (P2)
- **Objective**: Create function to detect when Source paths have changed (moved/renamed)
- **Deliverable**: Move/rename detection function/module
- **Traceability**: Plan Component 8, Responsibility: "Detect when Source paths have changed (moved/renamed)" and FR-015 (P2)
- **Acceptance**: Function detects Source moves when possible (best-effort)

#### Task 8.3: Implement Source Relocation (P2)
- **Objective**: Create function to attempt to locate moved Sources (best-effort)
- **Deliverable**: Source relocation function/module
- **Traceability**: Plan Component 8, Responsibility: "Attempt to locate moved Sources (best-effort)"
- **Acceptance**: Function attempts to locate moved Sources; handles failures gracefully

#### Task 8.4: Implement Status Reporting (P2)
- **Objective**: Create function to report Source status (accessible, inaccessible, moved, etc.)
- **Deliverable**: Status reporting function/module
- **Traceability**: Plan Component 8, Responsibility: "Report Source status (accessible, inaccessible, moved, etc.)"
- **Acceptance**: Status is reported clearly to users

---

## Task Summary

**Total Tasks**: 68 tasks across 7 components (P1) + 3 validation tasks + 4 P2 tasks (documented but out of scope)

**Implementation Sequence** (as per plan):
1. Component 1: Source Model & Identity (5 tasks)
2. Component 2: Source-Library Association Persistence (7 tasks)
3. Component 3: Source Validation & Accessibility (7 tasks)
4. Component 4: Source Scanning & Media Detection (7 tasks)
5. Component 5: Library Comparison & New Item Detection (6 tasks)
6. Component 6: Detection Result Model & Storage (8 tasks)
7. Component 7: Detection Execution & Orchestration (10 tasks)
8. Validation Deliverable (3 tasks)

**P1 Task Count**: 55 implementation tasks + 3 validation tasks = 58 total P1 tasks

**Exclusions** (as requested):
- No import/copying tasks
- No media organization tasks
- No pipeline/automation/scheduling tasks
- No Photos.app or device-specific integration tasks
- No advanced duplicate detection strategies
- No UI beyond minimal enablement
- Component 8 (Source Status & Health Monitoring) is P2 and out of scope
- FR-015 (move/rename handling) is P2 and out of scope

**Traceability**: Each task references specific plan components, requirements (FR-XXX), success criteria (SC-XXX), user stories, and acceptance scenarios where applicable.
