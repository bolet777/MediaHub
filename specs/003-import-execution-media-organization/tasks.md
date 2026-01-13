# Implementation Tasks: MediaHub Import Execution & Media Organization (Slice 3)

**Feature**: MediaHub Import Execution & Media Organization  
**Specification**: `specs/003-import-execution-media-organization/spec.md`  
**Plan**: `specs/003-import-execution-media-organization/plan.md`  
**Slice**: 3 - Import Execution & Media Organization (YYYY/MM)  
**Created**: 2026-01-12

## Task Organization

Tasks are organized by component and follow the implementation sequence defined in the plan. Each task is:
- Small and focused on a single deliverable
- Sequential (dependencies are clear)
- Traceable to plan components (referenced by component number)
- Includes only P1 scope: real import execution, Year/Month organization, timestamp rule (EXIF DateTimeOriginal → mtime fallback), collision policies, atomic writes, import results, known-items tracking (path-based, source-scoped), and import-detection integration

---

## Component 1: Timestamp Extraction & Resolution

**Plan Reference**: Component 1 (lines 46-87)  
**Dependencies**: None (Foundation)

### Task 1.1: Design Timestamp Extraction Strategy
**Priority**: P1
- **Objective**: Document in ADR: timestamp extraction strategy including EXIF DateTimeOriginal extraction, validation rules, and fallback to filesystem modification date
- **Deliverable**: Timestamp Extraction ADR (Component 1)
- **Traceability**: Plan Component 1, Key Decision: "Which EXIF library or API to use for timestamp extraction" and "How to validate EXIF timestamps"
- **Acceptance**: Strategy covers FR-004 (timestamp rule definition); supports EXIF DateTimeOriginal → mtime fallback; handles validation and edge cases

### Task 1.2: Implement EXIF DateTimeOriginal Extraction
**Priority**: P1
- **Objective**: Create function to extract EXIF DateTimeOriginal from image files when available
- **Deliverable**: EXIF extraction function/module
- **Traceability**: Plan Component 1, Responsibility: "Extract EXIF DateTimeOriginal from image files when available" and FR-004
- **Acceptance**: Function extracts EXIF DateTimeOriginal correctly when present; handles various image formats; supports SC-007 (100% organization accuracy)

### Task 1.3: Implement EXIF Timestamp Validation
**Priority**: P1
- **Objective**: Create function to validate extracted EXIF timestamps (reasonable date ranges, format validation)
- **Deliverable**: EXIF validation function/module
- **Traceability**: Plan Component 1, Responsibility: "Validate extracted EXIF timestamps (ensure they are reasonable/valid)" and Key Decision: "What constitutes 'invalid' EXIF data"
- **Acceptance**: Function correctly identifies valid vs. invalid EXIF timestamps; handles corrupted, out-of-range, and malformed dates

### Task 1.4: Implement Filesystem Modification Date Extraction
**Priority**: P1
- **Objective**: Create function to extract filesystem modification date as fallback timestamp
- **Deliverable**: Filesystem timestamp extraction function/module
- **Traceability**: Plan Component 1, Responsibility: "Fallback to filesystem modification date when EXIF is unavailable or invalid" and FR-004
- **Acceptance**: Function extracts modification date correctly; works for all file types (images and videos); supports SC-007

### Task 1.5: Implement Timestamp Resolution Logic
**Priority**: P1
- **Objective**: Create function that implements the P1 timestamp rule: EXIF DateTimeOriginal when available and valid, otherwise filesystem modification date
- **Deliverable**: Timestamp resolution function/module
- **Traceability**: Plan Component 1, Responsibility: "Ensure timestamp extraction is deterministic and consistent" and FR-004, FR-012, User Story 2 (acceptance scenarios 1, 4, 5)
- **Acceptance**: Function applies timestamp rule correctly; resolution is deterministic (same file produces same timestamp); supports SC-002 (100% deterministic results)

### Task 1.6: Implement Edge Case Handling for Timestamp Extraction
**Priority**: P1
- **Objective**: Create logic to handle edge cases (missing metadata, corrupted EXIF, unsupported formats, video files)
- **Deliverable**: Edge case handling function/module
- **Traceability**: Plan Component 1, Responsibility: "Handle edge cases (missing metadata, corrupted EXIF, unsupported formats)" and "Support both image and video files"
- **Acceptance**: Edge cases are handled gracefully; video files without EXIF use modification date; corrupted EXIF falls back to mtime

### Task 1.7: Validate Timestamp Extraction Determinism
**Priority**: P1
- **Objective**: Create tests to verify timestamp extraction is deterministic and consistent
- **Deliverable**: Timestamp extraction determinism test suite
- **Traceability**: Plan Component 1, Validation Point: "Timestamp extraction is deterministic (same file produces same timestamp)" and SC-002
- **Acceptance**: Same file produces identical timestamp across multiple extractions; determinism is verified

---

## Component 2: Destination Path Mapping

**Plan Reference**: Component 2 (lines 90-130)  
**Dependencies**: Component 1 (timestamp extraction must be implemented)

### Task 2.1: Design Destination Path Mapping Strategy
**Priority**: P1
- **Objective**: Document in ADR: destination path mapping strategy including Year/Month (YYYY/MM) structure, filename preservation, and path sanitization
- **Deliverable**: Destination Mapping ADR (Component 2)
- **Traceability**: Plan Component 2, Key Decision: "Destination path format" and "How to handle invalid characters in filenames"
- **Acceptance**: Strategy covers FR-003 (Year/Month organization); ensures deterministic mapping; handles path edge cases

### Task 2.2: Implement Year/Month Folder Structure Generation
**Priority**: P1
- **Objective**: Create function to generate Year/Month folder structure (YYYY/MM format) from timestamp
- **Deliverable**: Year/Month folder generation function/module
- **Traceability**: Plan Component 2, Responsibility: "Generate Year/Month folder structure (YYYY/MM format)" and FR-003, User Story 2 (all acceptance scenarios)
- **Acceptance**: Function generates correct YYYY/MM structure; format is consistent and human-readable; supports SC-007 (100% organization accuracy)

### Task 2.3: Implement Destination Path Computation
**Priority**: P1
- **Objective**: Create function to compute destination path for a candidate item based on its timestamp and original filename
- **Deliverable**: Destination path computation function/module
- **Traceability**: Plan Component 2, Responsibility: "Compute destination path for a candidate item based on its timestamp" and FR-003, FR-012
- **Acceptance**: Function computes correct destination paths; preserves original filename; mapping is deterministic (same timestamp → same path); supports SC-002 and SC-007

### Task 2.4: Implement Filename Preservation and Sanitization
**Priority**: P1
- **Objective**: Create function to preserve original filename while handling invalid characters and filesystem limitations
- **Deliverable**: Filename sanitization function/module
- **Traceability**: Plan Component 2, Responsibility: "Preserve original filename in destination path" and Key Decision: "How to handle invalid characters in filenames"
- **Acceptance**: Original filenames are preserved when possible; invalid characters are handled safely; filesystem limitations are respected

### Task 2.5: Implement Collision Detection Support
**Priority**: P1
- **Objective**: Create function to check if destination path already exists (for collision detection)
- **Deliverable**: Collision detection support function/module
- **Traceability**: Plan Component 2, Responsibility: "Support collision detection (check if destination path already exists)" and FR-005
- **Acceptance**: Function correctly detects existing files at destination paths; handles edge cases (directories vs. files)

### Task 2.6: Validate Destination Mapping Determinism
**Priority**: P1
- **Objective**: Create tests to verify destination mapping is deterministic
- **Deliverable**: Destination mapping determinism test suite
- **Traceability**: Plan Component 2, Validation Point: "Mapping is deterministic (same timestamp produces same path)" and SC-002, User Story 2 (acceptance scenario 4)
- **Acceptance**: Same file with same timestamp always maps to same destination path; determinism is verified

---

## Component 3: Collision Detection & Policy Handling

**Plan Reference**: Component 3 (lines 133-173)  
**Dependencies**: Component 2 (destination mapping must be implemented)

### Task 3.1: Design Collision Handling Strategy
**Priority**: P1
- **Objective**: Document in ADR: collision detection and policy handling strategy including rename, skip, and error policies
- **Deliverable**: Collision Handling ADR (Component 3)
- **Traceability**: Plan Component 3, Key Decision: "Collision detection strategy" and "Rename strategy (suffix pattern, numbering scheme, uniqueness guarantee)"
- **Acceptance**: Strategy covers FR-005 (collision policies); defines rename, skip, and error behaviors; ensures determinism

### Task 3.2: Implement Collision Detection
**Priority**: P1
- **Objective**: Create function to detect when an imported file would conflict with an existing file at the destination path
- **Deliverable**: Collision detection function/module
- **Traceability**: Plan Component 3, Responsibility: "Detect collisions (destination path already exists)" and FR-005, User Story 3 (acceptance scenarios 1, 2)
- **Acceptance**: Function correctly detects collisions; handles edge cases (directories vs. files, race conditions); supports SC-008 (100% collision policy compliance)

### Task 3.3: Implement Rename Policy
**Priority**: P1
- **Objective**: Create function to generate unique filenames when collision policy is "rename"
- **Deliverable**: Rename policy function/module
- **Traceability**: Plan Component 3, Responsibility: "Generate unique filenames when policy is 'rename'" and User Story 3 (acceptance scenario 3)
- **Acceptance**: Function generates unique, non-conflicting filenames; rename strategy is deterministic; prevents infinite loops; supports SC-008

### Task 3.4: Implement Skip Policy
**Priority**: P1
- **Objective**: Create function to skip files when collision policy is "skip"
- **Deliverable**: Skip policy function/module
- **Traceability**: Plan Component 3, Responsibility: "Apply collision policy (rename, skip, or error)" and User Story 3 (acceptance scenario 4)
- **Acceptance**: Function skips files without modifying existing files; skip action is reported in import results; supports SC-008

### Task 3.5: Implement Error Policy
**Priority**: P1
- **Objective**: Create function to fail import when collision policy is "error"
- **Deliverable**: Error policy function/module
- **Traceability**: Plan Component 3, Responsibility: "Apply collision policy (rename, skip, or error)" and User Story 3 (acceptance scenario 5)
- **Acceptance**: Function fails import with clear error messages; error is reported in import results; supports SC-008

### Task 3.6: Implement Collision Policy Orchestration
**Priority**: P1
- **Objective**: Create function that applies the configured collision policy (rename, skip, or error) based on import options
- **Deliverable**: Collision policy orchestration function/module
- **Traceability**: Plan Component 3, Responsibility: "Apply collision policy (rename, skip, or error)" and FR-005, User Story 3 (all acceptance scenarios)
- **Acceptance**: Function applies correct policy based on configuration; handles multiple collisions individually; supports SC-008

### Task 3.7: Validate Collision Handling Determinism
**Priority**: P1
- **Objective**: Create tests to verify collision handling is deterministic and follows configured policy
- **Deliverable**: Collision handling determinism test suite
- **Traceability**: Plan Component 3, Validation Point: "Collision actions are reported in import results" and SC-008
- **Acceptance**: Collision handling is deterministic; all policies work correctly; rename strategy doesn't create infinite loops

---

## Component 4: Atomic File Copying & Safety

**Plan Reference**: Component 4 (lines 175-221)  
**Dependencies**: Components 2 and 3 (destination mapping and collision handling must be implemented)

### Task 4.1: Design Atomic File Copying Strategy
**Priority**: P1
- **Objective**: Document in ADR: atomic file copying strategy including temporary file + rename approach, interruption handling, and source file read-only guarantee
- **Deliverable**: Atomic File Copying ADR (Component 4)
- **Traceability**: Plan Component 4, Key Decision: "Atomic write strategy (temporary file + rename, or copy + verify)" and "How to handle copy interruptions"
- **Acceptance**: Strategy covers FR-006 (atomic/safe writes), FR-010 (read-only guarantee), FR-013 (interruption handling); ensures no partial files on interruption.
- The design allows copy operations to be testable via injectable or mockable file operations in order to simulate interruptions during tests.

### Task 4.2: Implement Source File Validation
**Priority**: P1
- **Objective**: Create function to validate that Source files are still accessible before importing
- **Deliverable**: Source file validation function/module
- **Traceability**: Plan Component 4, Responsibility: "Validate Source file accessibility before copying" and FR-014
- **Acceptance**: Function validates file accessibility correctly; handles edge cases (deleted files, moved files, permission errors)

### Task 4.3: Implement Atomic File Copy Operation
**Priority**: P1
- **Objective**: Create function to copy files from Source to Library destination using atomic write strategy (temporary file + rename)
- **Deliverable**: Atomic file copy function/module
- **Traceability**: Plan Component 4, Responsibility: "Copy files from Source to Library destination" and "Ensure atomic writes (no partial files on interruption)" and FR-002, FR-006, User Story 1 (acceptance scenarios 1, 4)
- **Acceptance**: Files are copied correctly with data integrity preserved; atomic writes prevent partial files; supports SC-004 (safe against interruption) and SC-006 (source files unmodified)

### Task 4.4: Implement File Data Preservation
**Priority**: P1
- **Objective**: Ensure copied files preserve original file data (no modification, compression, or conversion)
- **Deliverable**: File data preservation implementation
- **Traceability**: Plan Component 4, Responsibility: "Preserve original file data (no modification, compression, or conversion)" and FR-015
- **Acceptance**: Copied files are byte-for-byte identical to source files; no data modification occurs; supports SC-006

### Task 4.5: Implement Read-Only Source Guarantee
**Priority**: P1
- **Objective**: Ensure Source files are never modified during import (read-only guarantee)
- **Deliverable**: Read-only source guarantee implementation
- **Traceability**: Plan Component 4, Responsibility: "Ensure Source files are never modified (read-only guarantee)" and FR-010, User Story 1 (acceptance scenario 1)
- **Acceptance**: Source files remain unmodified after copy; read-only guarantee is verified; supports SC-006

### Task 4.6: Implement Interruption Cleanup
**Priority**: P1
- **Objective**: Create function to handle import interruptions gracefully by cleaning up partial files
- **Deliverable**: Interruption cleanup function/module
- **Traceability**: Plan Component 4, Responsibility: "Support interruption handling (cleanup partial files)" and FR-013, User Story 1 (acceptance scenario 4)
- **Acceptance**: Interrupted imports leave Library in consistent state; partial files are cleaned up; supports SC-004

### Task 4.7: Implement Copy Error Handling
**Priority**: P1
- **Objective**: Create function to handle copy errors gracefully (permission errors, disk full, etc.)
- **Deliverable**: Copy error handling function/module
- **Traceability**: Plan Component 4, Responsibility: "Handle copy errors gracefully (permission errors, disk full, etc.)" and FR-013
- **Acceptance**: Copy errors are handled gracefully; clear error messages are generated; import continues with other items where possible

### Task 4.8: Validate Atomic Copy Safety
**Priority**: P1
- **Objective**: Create tests to verify atomic copying prevents corruption on interruption
- **Deliverable**: Atomic copy safety test suite
- **Traceability**: Plan Component 4, Validation Point: "Interrupted imports leave Library in consistent state" and SC-004
- **Acceptance**: Interrupted imports don't leave corrupt or partial files; Library state remains consistent; safety is verified

---

## Component 5: Import Job Orchestration

**Plan Reference**: Component 5 (lines 223-268)  
**Dependencies**: Components 1, 2, 3, 4, and 6 (timestamp extraction, destination mapping, collision handling, file copying, and import results must be implemented)

### Task 5.1: Design Import Job Orchestration Flow
**Priority**: P1
- **Objective**: Document in ADR: end-to-end import job orchestration flow coordinating timestamp extraction, destination mapping, collision handling, and file copying
- **Deliverable**: Import Orchestration ADR (Component 5)
- **Traceability**: Plan Component 5, Key Decision: "Import job execution flow (sequential vs. parallel item processing)" and "Whether import is transactional (all-or-nothing) or item-by-item"
- **Acceptance**: Flow coordinates all components correctly; supports FR-001, FR-012, FR-013, FR-017; ensures determinism

### Task 5.2: Implement Import Job State Management
**Priority**: P1
- **Objective**: Create function to manage import job state and progress
- **Deliverable**: Import job state management function/module
- **Traceability**: Plan Component 5, Responsibility: "Manage import job state and progress" and FR-001
- **Acceptance**: Job state is managed correctly; progress can be tracked; state is tracked during execution and final state is recorded in import results; no import resumption is implied in P1

### Task 5.3: Implement Import Item Processing Coordination
**Priority**: P1
- **Objective**: Create function to coordinate processing of individual import items (timestamp extraction → mapping → collision check → copy)
- **Deliverable**: Import item processing coordination function/module
- **Traceability**: Plan Component 5, Responsibility: "Coordinate import job execution (timestamp extraction → mapping → collision check → copy)" and FR-001, User Story 1 (all acceptance scenarios)
- **Acceptance**: Item processing coordinates all components correctly; workflow is deterministic; supports SC-001 (performance targets) and SC-002 (deterministic results)

### Task 5.4: Implement Import Job Execution
**Priority**: P1
- **Objective**: Create main function that executes import job for selected candidate items from detection results
- **Deliverable**: Import job execution function/module
- **Traceability**: Plan Component 5, Responsibility: "Support importing selected items from detection results" and FR-001, User Story 1 (acceptance scenarios 1, 2)
- **Acceptance**: Import executes end-to-end successfully; selected items are imported correctly; supports SC-001 (completes within 60 seconds per 100 items)

### Task 5.5: Implement Logical Atomicity Enforcement
**Priority**: P1
- **Objective**: Ensure import is logically atomic (Library remains consistent even on interruption)
- **Deliverable**: Logical atomicity enforcement implementation
- **Traceability**: Plan Component 5, Responsibility: "Ensure import is logically atomic (Library remains consistent)" and FR-013, User Story 1 (acceptance scenario 4)
- **Acceptance**: Import maintains Library consistency; interruptions don't corrupt Library state; supports SC-004 (safe against interruption)

### Task 5.6: Implement Determinism Enforcement
**Priority**: P1
- **Objective**: Ensure import execution is deterministic (consistent ordering, no side effects)
- **Deliverable**: Determinism enforcement implementation
- **Traceability**: Plan Component 5, Responsibility: "Ensure deterministic import execution" and FR-012, SC-002
- **Acceptance**: Import produces identical results for identical inputs; execution is deterministic; supports SC-002 (100% deterministic results)

### Task 5.7: Implement Import Interruption Handling
**Priority**: P1
- **Objective**: Create function to handle import interruptions gracefully
- **Deliverable**: Import interruption handling function/module
- **Traceability**: Plan Component 5, Responsibility: "Handle import interruptions gracefully" and FR-013, User Story 1 (acceptance scenario 4)
- **Acceptance**: Interruptions are handled gracefully; Library state remains consistent; supports SC-004

### Task 5.8: Implement Import Progress and Error Reporting
**Priority**: P1
- **Objective**: Create function to report progress and errors during import
- **Deliverable**: Import progress and error reporting function/module
- **Traceability**: Plan Component 5, Responsibility: "Report progress and errors during import" and FR-007
- **Acceptance**: Progress and errors are reported clearly; reporting supports explainable results (SC-005)

### Task 5.9: Validate Import Job Execution
**Priority**: P1
- **Objective**: Create tests to verify import job executes end-to-end successfully
- **Deliverable**: Import job execution test suite
- **Traceability**: Plan Component 5, Validation Point: "Import executes end-to-end successfully" and SC-001, SC-002, SC-004
- **Acceptance**: Import executes successfully; meets performance targets; produces deterministic results; handles interruptions safely

---

## Component 6: Import Result Model & Storage

**Plan Reference**: Component 6 (lines 270-314)  
**Dependencies**: Components 3 and 4 (collision handling and file copying must be implemented)

### Task 6.1: Design Import Result Data Structure
**Priority**: P1
- **Objective**: Define import result data structure including import items, status (imported, skipped, failed), reasons, summary statistics, and metadata
- **Deliverable**: Import result data structure definition
- **Traceability**: Plan Component 6, Responsibility: "Define import result data structure (import items, status, reasons, summary)" and FR-007, User Story 5 (all acceptance scenarios)
- **Acceptance**: Structure supports explainable results (SC-005); includes all required fields for auditability

### Task 6.2: Define Import Item Status Enumeration
**Priority**: P1
- **Objective**: Define how import item status is represented (imported, skipped, failed)
- **Deliverable**: Import item status enumeration/definition
- **Traceability**: Plan Component 6, Key Decision: "How to represent import item status (enumeration: imported, skipped, failed)" and FR-007
- **Acceptance**: Status enumeration is clear and complete; supports explainable results

### Task 6.3: Define Import Item Reason Representation
**Priority**: P1
- **Objective**: Define how skip/fail reasons are represented (enumeration, codes, or descriptive text)
- **Deliverable**: Import item reason representation definition
- **Traceability**: Plan Component 6, Key Decision: "How to represent skip/fail reasons (enumeration, codes, or descriptive text)" and FR-007, User Story 5 (acceptance scenarios 2, 3)
- **Acceptance**: Reasons are clear and explainable; supports SC-005 (explainable results)

### Task 6.4: Design Import Result Storage Format
**Priority**: P1
- **Objective**: Document in ADR: storage format and location for import results in transparent, human-readable format
- **Deliverable**: Import Results Storage ADR (Component 6)
- **Traceability**: Plan Component 6, Key Decision: "Storage location for import results (within Library structure)" and "Storage format (transparent, human-readable format)" and FR-009, FR-016
- **Acceptance**: Format is transparent and human-readable (FR-009); location is within Library structure; supports SC-010 (transparent audit trail)

### Task 6.5: Implement Import Result Serialization
**Priority**: P1
- **Objective**: Create function to serialize import results to storage format
- **Deliverable**: Import result serialization function/module
- **Traceability**: Plan Component 6, Responsibility: "Store import results persistently" and FR-016, SC-009
- **Acceptance**: Results are serialized correctly; format is transparent and human-readable; supports SC-009 (100% result persistence)

### Task 6.6: Implement Import Result Deserialization
**Priority**: P1
- **Objective**: Create function to deserialize import results from storage format
- **Deliverable**: Import result deserialization function/module
- **Traceability**: Plan Component 6, Responsibility: "Store import results persistently"
- **Acceptance**: Results are deserialized correctly; handles corrupted or invalid data gracefully

### Task 6.7: Implement Import Result Retrieval
**Priority**: P1
- **Objective**: Create function to retrieve stored import results
- **Deliverable**: Import result retrieval function/module
- **Traceability**: Plan Component 6, Responsibility: "Enable retrieval and comparison of import results" and User Story 5 (acceptance scenario 5)
- **Acceptance**: Function retrieves results correctly; supports viewing results from different import runs

### Task 6.8: Implement Import Result Comparison Support
**Priority**: P1
- **Objective**: Create functionality to enable comparison of results from different import runs
- **Deliverable**: Import result comparison function/module
- **Traceability**: Plan Component 6, Responsibility: "Enable result comparison across import runs" and User Story 5 (acceptance scenario 5)
- **Acceptance**: Results from different runs can be compared; differences are identifiable

### Task 6.9: Implement Import Result Metadata Storage
**Priority**: P1
- **Objective**: Ensure import results include necessary metadata (timestamp, source, library, options used)
- **Deliverable**: Import result metadata implementation
- **Traceability**: Plan Component 6, Responsibility: "Support auditable results (import metadata, timestamps, options used)" and FR-009
- **Acceptance**: Results include all required metadata for auditability; supports SC-010 (transparent audit trail)

### Task 6.10: Validate Import Result Storage
**Priority**: P1
- **Objective**: Create tests to verify import results are stored correctly and persist across application restarts
- **Deliverable**: Import result storage test suite
- **Traceability**: Plan Component 6, Validation Point: "Results are stored in transparent, human-readable format" and SC-009, SC-010
- **Acceptance**: Results are stored correctly; persist across restarts; format is transparent and human-readable

---

## Component 7: Known Items Tracking & Persistence

**Plan Reference**: Component 7 (lines 316-357)  
**Dependencies**: None (can be developed in parallel with Components 1-4)

### Task 7.1: Design Known Items Tracking Strategy
**Priority**: P1
- **Objective**: Document in ADR: known-items tracking strategy including path-based, source-scoped tracking schema and storage format
- **Deliverable**: Known Items Tracking ADR (Component 7)
- **Traceability**: Plan Component 7, Key Decision: "Known-items tracking schema (what identifiers to store: paths, hashes, etc.)" and "Storage format (transparent, human-readable format)"
- **Acceptance**: Strategy covers FR-008 (known-items tracking); uses path-based, source-scoped approach (P1); format is transparent and human-readable (FR-009)

### Task 7.2: Define Known Items Tracking Schema
**Priority**: P1
- **Objective**: Define schema for tracking imported items (path-based identifiers, source scope, metadata)
- **Deliverable**: Known items tracking schema definition
- **Traceability**: Plan Component 7, Key Decision: "How to represent imported items (normalized paths, relative paths, etc.)" and "How to scope tracking to Sources"
- **Acceptance**: Schema supports path-based tracking; includes source scope; supports FR-008

### Task 7.3: Design Known Items Storage Format
**Priority**: P1
- **Objective**: Document in ADR: storage format and location for known-items tracking in transparent, human-readable format
- **Deliverable**: Known Items Storage ADR (Component 7)
- **Traceability**: Plan Component 7, Key Decision: "Storage location for known-items tracking (within Library structure)" and "Storage format (transparent, human-readable format)" and FR-009
- **Acceptance**: Format is transparent and human-readable; location is within Library structure; supports SC-010 (transparent audit trail)

### Task 7.4: Implement Known Items Recording
**Priority**: P1
- **Objective**: Create function to record imported items in known-items tracking (path-based, source-scoped)
- **Deliverable**: Known items recording function/module
- **Traceability**: Plan Component 7, Responsibility: "Record imported items in known-items tracking (path-based, source-scoped)" and FR-008, User Story 4 (acceptance scenarios 1, 2, 3)
- **Acceptance**: Imported items are recorded correctly; tracking is source-scoped; supports SC-003 (100% detection exclusion accuracy)

### Task 7.5: Implement Known Items Persistence
**Priority**: P1
- **Objective**: Create function to persist known-items tracking in transparent, human-readable format
- **Deliverable**: Known items persistence function/module
- **Traceability**: Plan Component 7, Responsibility: "Persist known-items tracking in transparent, human-readable format" and FR-009, SC-010
- **Acceptance**: Tracking persists correctly; format is transparent and human-readable; survives application restarts

### Task 7.6: Implement Known Items Query
**Priority**: P1
- **Objective**: Create function to query known items for a Source
- **Deliverable**: Known items query function/module
- **Traceability**: Plan Component 7, Responsibility: "Support querying known items for a Source" and FR-008
- **Acceptance**: Function queries known items correctly; supports source-scoped queries; integrates with detection comparison

### Task 7.7: Implement Known Items Update After Import
**Priority**: P1
- **Objective**: Create function to update known-items tracking after successful imports
- **Deliverable**: Known items update function/module
- **Traceability**: Plan Component 7, Responsibility: "Update known-items tracking after successful imports" and FR-008, User Story 4 (acceptance scenario 1)
- **Acceptance**: Tracking is updated correctly after import; only successfully imported items are recorded; supports SC-003

### Task 7.8: Implement Source-Scoped Tracking Enforcement
**Priority**: P1
- **Objective**: Ensure tracking is source-scoped (items imported from Source A don't affect Source B)
- **Deliverable**: Source-scoped tracking enforcement implementation
- **Traceability**: Plan Component 7, Responsibility: "Ensure tracking is source-scoped (items imported from Source A don't affect Source B)" and User Story 4 (acceptance scenario 4)
- **Acceptance**: Tracking is correctly scoped to Sources; items from different Sources are tracked independently

### Task 7.9: Validate Known Items Tracking Persistence
**Priority**: P1
- **Objective**: Create tests to verify known-items tracking persists across application restarts
- **Deliverable**: Known items tracking persistence test suite
- **Traceability**: Plan Component 7, Validation Point: "Known-items tracking persists across application restarts" and SC-003
- **Acceptance**: Tracking persists correctly; survives application restarts; format is transparent and human-readable

---

## Component 8: Import-Detection Integration

**Plan Reference**: Component 8 (lines 359-395)  
**Dependencies**: Component 7 (known-items tracking must be implemented) and detection mechanism from Slice 2

### Task 8.1: Design Import-Detection Integration Strategy
**Priority**: P1
- **Objective**: Document in ADR: integration strategy for known-items tracking with detection comparison mechanism from Slice 2
- **Deliverable**: Import-Detection Integration ADR (Component 8)
- **Traceability**: Plan Component 8, Key Decision: "How to integrate known-items tracking with existing Library comparison mechanism" and "Whether to extend existing comparison API or create new integration point"
- **Acceptance**: Strategy integrates known-items tracking with detection; maintains determinism; supports FR-008

### Task 8.2: Implement Known Items Query Integration
**Priority**: P1
- **Objective**: Create function to query known items during detection for comparison
- **Deliverable**: Known items query integration function/module
- **Traceability**: Plan Component 8, Responsibility: "Support querying known items during detection" and FR-008
- **Acceptance**: Function queries known items correctly during detection; integrates with detection comparison mechanism

### Task 8.3: Implement Detection Exclusion Logic
**Priority**: P1
- **Objective**: Create function to exclude items recorded in known-items tracking from detection candidate lists
- **Deliverable**: Detection exclusion logic function/module
- **Traceability**: Plan Component 8, Responsibility: "Ensure detection excludes items recorded in known-items tracking" and FR-008, User Story 1 (acceptance scenario 3), User Story 4 (acceptance scenarios 1, 4, 5)
- **Acceptance**: Imported items are correctly excluded from detection; exclusion is source-scoped; supports SC-003 (100% detection exclusion accuracy)

### Task 8.4: Implement Integration with Detection Comparison
**Priority**: P1
- **Objective**: Integrate known-items tracking with existing Library comparison mechanism from Slice 2
- **Deliverable**: Detection comparison integration function/module
- **Traceability**: Plan Component 8, Responsibility: "Integrate known-items tracking with detection comparison mechanism" and FR-008
- **Acceptance**: Integration works correctly; detection comparison includes known-items exclusion; maintains determinism

### Task 8.5: Implement Edge Case Handling for Integration
**Priority**: P1
- **Objective**: Create logic to handle edge cases (items deleted from Library, Source detached, etc.)
- **Deliverable**: Integration edge case handling function/module
- **Traceability**: Plan Component 8, Responsibility: "Handle edge cases (items deleted from Library, Source detached, etc.)" and User Story 4 (acceptance scenario 5)
- **Acceptance**: Edge cases are handled gracefully; missing or stale known-item entries are logged or reported only, with no automatic reconciliation or correction in P1.

### Task 8.6: Ensure Integration Maintains Determinism
**Priority**: P1
- **Objective**: Ensure integration maintains detection determinism and accuracy
- **Deliverable**: Determinism enforcement implementation
- **Traceability**: Plan Component 8, Responsibility: "Ensure integration maintains determinism and accuracy" and FR-012, SC-002, SC-003
- **Acceptance**: Integration maintains determinism; detection accuracy meets success criteria (100%); supports SC-002 and SC-003

### Task 8.7: Validate Import-Detection Integration
**Priority**: P1
- **Objective**: Create tests to verify imported items are excluded from future detection runs
- **Deliverable**: Import-detection integration test suite
- **Traceability**: Plan Component 8, Validation Point: "Detection correctly excludes imported items" and SC-003, User Story 1 (acceptance scenario 3)
- **Acceptance**: Imported items are excluded with 100% accuracy; detection maintains determinism; integration works correctly

---

## Validation Deliverable

### Task V.1: Create Validation Document
**Priority**: P1
- **Objective**: Create validation checklist document for Slice 3
- **Deliverable**: `specs/003-import-execution-media-organization/validation.md`
- **Traceability**: Plan Validation & Testing Strategy (lines 530-588)
- **Acceptance**: Document includes validation commands, acceptance scenarios, success criteria validation, and edge case testing guidance

### Task V.2: Implement Unit Tests
**Priority**: P1
- **Objective**: Create unit tests covering key acceptance scenarios for all components
- **Deliverable**: Unit test suite under `Tests/MediaHubTests/`
- **Traceability**: Plan Unit Testing Focus Areas (lines 532-541) and all User Story acceptance scenarios
- **Acceptance**: Tests cover timestamp extraction, destination mapping, collision handling, atomic copying, import orchestration, import results, known-items tracking, and import-detection integration; all tests pass

### Task V.3: Implement Integration Tests
**Priority**: P1
- **Objective**: Create integration tests covering end-to-end import workflow and key scenarios
- **Deliverable**: Integration test suite under `Tests/MediaHubTests/`
- **Traceability**: Plan Integration Testing Focus Areas (lines 542-550)
- **Acceptance**: Tests cover end-to-end import workflow, collision scenarios, interruption handling, known-items integration, import result storage, and import determinism; all tests pass

### Task V.4: Implement Acceptance Test Scenarios
**Priority**: P1
- **Objective**: Create tests covering all acceptance scenarios from User Stories 1-5
- **Deliverable**: Acceptance test suite under `Tests/MediaHubTests/`
- **Traceability**: Plan Acceptance Testing Scenarios (lines 551-559) and all User Story acceptance scenarios
- **Acceptance**: All acceptance scenarios from User Stories 1-5 are testable and pass

### Task V.5: Implement Edge Case Tests
**Priority**: P1
- **Objective**: Create tests covering edge cases from specification
- **Deliverable**: Edge case test suite under `Tests/MediaHubTests/`
- **Traceability**: Plan Edge Case Testing (lines 560-573) and specification Edge Cases (lines 100-114)
- **Acceptance**: Edge cases are tested; tests handle scenarios gracefully; all edge case tests pass

---

## P2 Tasks (Out of Scope for Slice 3)

The following tasks are explicitly out of scope for Slice 3 but are documented for future reference:

### Advanced Duplicate Detection (P2)

**Note**: Content hash-based known-items tracking, cross-source/global deduplication, and advanced duplicate detection strategies are P2 and explicitly out of scope for Slice 3.

#### Task P2.1: Implement Content Hash-Based Tracking (P2)
- **Objective**: Create function to track imported items using content hashes instead of paths
- **Deliverable**: Content hash-based tracking function/module
- **Traceability**: Plan P2 Responsibilities (lines 624-633)
- **Acceptance**: Function tracks items using content hashes; supports cross-source deduplication

#### Task P2.2: Implement Cross-Source Deduplication (P2)
- **Objective**: Create function to detect duplicates across multiple Sources
- **Deliverable**: Cross-source deduplication function/module
- **Traceability**: Plan P2 Responsibilities (lines 624-633)
- **Acceptance**: Function detects duplicates across Sources; prevents duplicate imports

### Alternative Timestamp Strategies (P2)

**Note**: Alternative timestamp strategies beyond EXIF DateTimeOriginal → mtime fallback are P2 and explicitly out of scope for Slice 3.

#### Task P2.3: Implement Alternative Timestamp Strategies (P2)
- **Objective**: Create support for alternative timestamp strategies (EXIF DateTime, GPS timestamp, etc.)
- **Deliverable**: Alternative timestamp strategy function/module
- **Traceability**: Plan P2 Responsibilities (lines 624-633)
- **Acceptance**: Function supports multiple timestamp strategies; user can configure strategy

### Advanced Collision Strategies (P2)

**Note**: Advanced collision strategies (content comparison, merge, etc.) are P2 and explicitly out of scope for Slice 3.

#### Task P2.4: Implement Content-Based Collision Detection (P2)
- **Objective**: Create function to compare file content when collisions occur
- **Deliverable**: Content-based collision detection function/module
- **Traceability**: Plan P2 Responsibilities (lines 624-633)
- **Acceptance**: Function compares file content; detects identical files; supports merge strategies

### Import Resumption and Parallel Processing (P2)

**Note**: Import resumption after interruption and parallel import processing are P2 and explicitly out of scope for Slice 3.

#### Task P2.5: Implement Import Resumption (P2)
- **Objective**: Create function to resume interrupted imports
- **Deliverable**: Import resumption function/module
- **Traceability**: Plan P2 Responsibilities (lines 624-633)
- **Acceptance**: Function resumes interrupted imports; tracks progress; completes remaining items

#### Task P2.6: Implement Parallel Import Processing (P2)
- **Objective**: Create function to process import items in parallel
- **Deliverable**: Parallel import processing function/module
- **Traceability**: Plan P2 Responsibilities (lines 624-633)
- **Acceptance**: Function processes items in parallel; maintains determinism; improves performance

---

## Task Summary

**Total Tasks**: 75 tasks across 8 components (P1) + 5 validation tasks + 6 P2 tasks (documented but out of scope)

**Implementation Sequence** (as per plan):
1. Component 1: Timestamp Extraction & Resolution (7 tasks)
2. Component 2: Destination Path Mapping (6 tasks)
3. Component 3: Collision Detection & Policy Handling (7 tasks)
4. Component 4: Atomic File Copying & Safety (8 tasks)
5. Component 7: Known Items Tracking & Persistence (9 tasks) - can be developed in parallel with Components 1-4
6. Component 6: Import Result Model & Storage (10 tasks)
7. Component 5: Import Job Orchestration (9 tasks)
8. Component 8: Import-Detection Integration (7 tasks)
9. Validation Deliverable (5 tasks)

**P1 Task Count**: 70 implementation tasks + 5 validation tasks = 75 total P1 tasks

**Exclusions** (as requested):
- No advanced duplicate detection (hashing/fuzzy matching)
- No cross-source/global deduplication
- No organization beyond Year/Month (YYYY/MM)
- No Photos.app/device APIs
- No pipelines/automation/scheduling
- No UI beyond minimal enablement
- No alternative timestamp strategies beyond EXIF DateTimeOriginal → mtime fallback
- No content hash-based known-items tracking (path-based only for P1)
- P2 tasks are documented but out of scope

**Traceability**: Each task references specific plan components, requirements (FR-XXX), success criteria (SC-XXX), user stories, and acceptance scenarios where applicable.
