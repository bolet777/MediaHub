# Feature Specification: MediaHub Import Execution & Media Organization

**Feature Branch**: `003-import-execution-media-organization`  
**Created**: 2026-01-12  
**Status**: Ready for Plan  
**Input**: User description: "Implement real import: copy selected candidate items into the MediaHub Library using a simple, deterministic organization strategy (Year/Month folders), and update the Library's notion of 'known items' so that re-running detection does not re-suggest already imported items."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Import Selected Candidate Items (Priority: P1)

A user wants to import selected candidate items from a detection result into their MediaHub Library. The import should copy files from the Source to the Library, organize them in a predictable Year/Month structure, and ensure that re-running detection does not re-suggest these imported items.

**Why this priority**: This is the core functionality that enables users to actually import media into their library. Without import execution, detection results are merely informational.

**Independent Test**: Can be fully tested by selecting candidate items from a detection result, executing import, and verifying that files are copied to the Library in the expected Year/Month structure and that future detection excludes these items.

**Acceptance Scenarios**:

1. **Given** a user has a detection result with candidate items, **When** they select items and execute import, **Then** MediaHub copies the selected files from Source to Library in Year/Month folders
2. **Given** a user executes an import, **When** the import completes successfully, **Then** MediaHub reports what was imported, skipped, or failed with clear reasons
3. **Given** a user executes an import, **When** they re-run detection on the same Source, **Then** MediaHub excludes the imported items from the candidate list
4. **Given** a user executes an import, **When** the import is interrupted (e.g., application quit), **Then** MediaHub does not leave corrupt or partial files in the Library
5. **Given** a user executes an import, **When** a file with the same name already exists at the destination, **Then** MediaHub handles the collision according to the configured policy (rename, skip, or error)

---

### User Story 2 - Organize Imported Files by Year/Month (Priority: P1)

A user wants imported media files to be organized in a predictable, human-readable folder structure based on the file's timestamp. The organization should be deterministic and transparent.

**Why this priority**: Predictable organization enables users to find files easily, supports transparent storage (Constitution requirement), and enables external tools to work with the library structure.

**Independent Test**: Can be fully tested by importing files with known timestamps and verifying they are placed in the correct Year/Month folders according to the defined timestamp rule.

**Acceptance Scenarios**:

1. **Given** a user imports a photo with a known timestamp, **When** the import completes, **Then** the file is placed in the correct `YYYY/MM` folder based on the chosen timestamp rule
2. **Given** a user imports multiple files with different timestamps, **When** the import completes, **Then** files are organized into the appropriate Year/Month folders
3. **Given** a user views the Library in Finder, **When** they navigate the folder structure, **Then** they can see files organized by Year/Month in a transparent, human-readable structure
4. **Given** a user imports files, **When** they examine the destination paths, **Then** the organization is deterministic (same file with same timestamp always goes to the same location)
5. **Given** a user imports files with missing or invalid timestamps, **When** the import executes, **Then** MediaHub uses a fallback timestamp rule and documents the choice

---

### User Story 3 - Handle Import Collisions Safely (Priority: P1)

A user wants MediaHub to handle cases where an imported file would conflict with an existing file at the destination path. The collision policy should be clear, deterministic, and safe.

**Why this priority**: Collisions are inevitable in real-world usage. Safe, predictable collision handling prevents data loss and ensures deterministic behavior.

**Independent Test**: Can be fully tested by attempting to import a file that would create a collision and verifying that MediaHub handles it according to the configured policy.

**Acceptance Scenarios**:

1. **Given** a user imports a file, **When** a file with the same name already exists at the destination path, **Then** MediaHub applies the collision policy (rename, skip, or error) and reports the action
2. **Given** a user imports multiple files, **When** some files would create collisions, **Then** MediaHub handles each collision individually according to the policy
3. **Given** a user imports a file with a collision, **When** the policy is "rename", **Then** MediaHub generates a unique filename that doesn't conflict and preserves the original file
4. **Given** a user imports a file with a collision, **When** the policy is "skip", **Then** MediaHub skips the file and reports it in the import results without modifying the existing file
5. **Given** a user imports a file with a collision, **When** the policy is "error", **Then** MediaHub fails the import for that file and reports a clear error

---

### User Story 4 - Track Imported Items for Future Detection (Priority: P1)

A user wants MediaHub to remember which items have been imported so that future detection runs do not re-suggest already imported items. This tracking must be transparent and auditable.

**Why this priority**: Without tracking imported items, users would see the same items suggested for import repeatedly, creating confusion and potential duplicate imports.

**Independent Test**: Can be fully tested by importing items, then running detection again and verifying that imported items are excluded from the candidate list.

**Acceptance Scenarios**:

1. **Given** a user imports items from a Source, **When** they run detection on the same Source again, **Then** MediaHub excludes the imported items from the candidate list
2. **Given** a user imports items, **When** they examine the Library metadata, **Then** they can see a transparent record of what has been imported (audit trail)
3. **Given** a user imports items, **When** they view the import tracking data, **Then** the format is human-readable and explainable
4. **Given** a user imports items from multiple Sources, **When** they run detection, **Then** MediaHub correctly excludes items imported from each Source
5. **Given** a user imports items, **When** they manually delete imported files from the Library, **Then** MediaHub's tracking reflects this change (or handles it gracefully)

---

### User Story 5 - View Import Results and Audit Trail (Priority: P1)

A user wants to see the results of an import operation in a clear, explainable format. The results should show what was imported, what was skipped, what failed, and why.

**Why this priority**: Transparent, auditable results build trust and enable users to understand what happened during import. This aligns with Constitution requirements for explainable operations.

**Independent Test**: Can be fully tested by executing an import and verifying that results are presented in a clear format with explanations for each item's outcome.

**Acceptance Scenarios**:

1. **Given** a user executes an import, **When** the import completes, **Then** MediaHub presents a summary showing imported, skipped, and failed items with counts
2. **Given** a user views import results, **When** they examine a skipped item, **Then** MediaHub explains why it was skipped (collision, error, etc.)
3. **Given** a user views import results, **When** they examine a failed item, **Then** MediaHub explains the failure reason (permission error, disk full, etc.)
4. **Given** a user views import results, **When** they examine an imported item, **Then** MediaHub shows the source path, destination path, and timestamp used for organization
5. **Given** a user views import results, **When** they view results from multiple import runs, **Then** MediaHub maintains separate result sets that can be compared

---

### Edge Cases

- What happens when a Source file is deleted or moved after detection but before import?
- What happens when disk space is insufficient during import?
- What happens when a Source file becomes locked or inaccessible during import?
- What happens when multiple import jobs run concurrently on the same Library?
- What happens when a file's timestamp changes between detection and import?
- What happens when a collision policy would create an infinite rename loop?
- What happens when the Library directory becomes read-only during import?
- What happens when a Source file has invalid or corrupted metadata?
- What happens when an imported file is manually deleted from the Library after import?
- What happens when a Source is detached after items have been imported from it?
- What happens when import is interrupted mid-way through copying a large file?
- What happens when the Year/Month folder structure would create an invalid path (e.g., invalid characters)?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: MediaHub MUST support importing selected candidate items from a detection result into the Library
- **FR-002**: MediaHub MUST copy files from Source to Library (never move or modify Source files)
- **FR-003**: MediaHub MUST organize imported files in Year/Month folders (`YYYY/MM`) based on a deterministic timestamp rule
- **FR-004**: MediaHub MUST define and document the timestamp rule used for Year/Month organization. For P1, MediaHub MUST use EXIF DateTimeOriginal when present and valid, otherwise fallback to filesystem modification date.
- **FR-005**: MediaHub MUST handle name/path collisions according to a configurable policy (rename, skip, or error)
- **FR-006**: MediaHub MUST ensure atomic/safe writes (no partial or corrupt files on interruption)
- **FR-007**: MediaHub MUST report import results showing what was imported, skipped, failed, and why
- **FR-008**: MediaHub MUST update "known items" tracking so that re-running detection excludes imported items
- **FR-009**: MediaHub MUST maintain an audit trail of import operations in a transparent, human-readable format
- **FR-010**: MediaHub MUST never modify Source files during import (read-only guarantee)
- **FR-011**: MediaHub MUST support importing items from multiple Sources independently
- **FR-012**: MediaHub MUST produce deterministic import results (same inputs produce same outputs)
- **FR-013**: MediaHub MUST handle import interruptions gracefully without corrupting Library state
- **FR-014**: MediaHub MUST validate that Source files are still accessible before importing
- **FR-015**: MediaHub MUST preserve original file data during import (no modification, compression, or conversion)
- **FR-016**: MediaHub MUST store import results persistently for auditability
- **FR-017**: MediaHub MUST support re-running import on the same detection result safely (idempotent where possible)

### Key Entities *(include if feature involves data)*

- **Import Job**: A single execution of the import process that takes a detection result, a selection of candidate items, and import options (collision policy, timestamp rule) as inputs, and produces an import result. An import job is logically atomic: partial results are either cleaned up or clearly reported, and the Library remains in a consistent, non-corrupt state.

- **Import Item**: A single candidate item being imported. Each import item has a status (imported, skipped, failed) and a reason for that status. Import items track the source path, destination path, and any transformations applied (e.g., rename due to collision).

- **Destination Mapping**: The deterministic function that maps a candidate item to its destination path in the Library. For P1, this uses a Year/Month rule (`YYYY/MM`) based on a chosen timestamp from the file (e.g., modification date, EXIF date). The mapping must be deterministic: the same file with the same timestamp always maps to the same destination.

- **Collision Policy**: The strategy for handling cases where an imported file would conflict with an existing file at the destination path. Policies include: "rename" (generate unique filename), "skip" (skip the import), or "error" (fail the import). The policy must be configurable per import job and documented. For P1, the collision policy is provided as an option to the import execution API; no user interface or persistent preferences are implied.

- **Known Items Tracking**: The mechanism by which MediaHub records which items have been imported so that future detection runs exclude them. This tracking must be transparent, human-readable, and auditable. For P1, known items tracking is path-based and scoped to the Source from which items were imported. Content hashes, cross-source matching, or global deduplication strategies are explicitly out of scope for this slice.

- **Import Result**: The output of an import job, containing a list of import items with their status (imported, skipped, failed) and reasons, summary statistics, and metadata about the import operation (timestamp, source, library, options used). Import results are stored persistently for auditability.

- **Timestamp Rule**: The rule that determines which timestamp from a file is used for Year/Month organization. For P1, MediaHub uses EXIF DateTimeOriginal when available and valid; otherwise it falls back to the filesystem modification date. This rule is deterministic and documented. Alternative timestamp strategies are out of scope for this slice.

- **Audit Trail**: The persistent record of import operations stored in the Library. The audit trail includes import results, timestamps, and metadata that enable users to understand what was imported, when, and why. The format must be transparent and human-readable.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can import selected candidate items from a detection result in under 60 seconds per 100 items on a local filesystem under normal conditions
- **SC-002**: Import results are 100% deterministic (same inputs produce identical outputs)
- **SC-003**: Re-running detection after import excludes imported items with 100% accuracy
- **SC-004**: Import operations are safe against interruption (no corrupt or partial files left in Library)
- **SC-005**: Import results are explainable (users can understand why items were imported, skipped, or failed)
- **SC-006**: Source files remain unmodified after import (read-only guarantee verified)
- **SC-007**: Imported files are organized in Year/Month folders according to the timestamp rule 100% of the time
- **SC-008**: Collision handling follows the configured policy 100% of the time
- **SC-009**: Import results are stored persistently and survive application restarts 100% of the time
- **SC-010**: Import audit trail is transparent and human-readable (can be viewed without MediaHub)

## Assumptions

- Import will be performed on-demand by user action (not automatically scheduled)
- Source files will remain accessible during import (handling of inaccessible sources is best-effort)
- Library has sufficient disk space for imported files (handling of insufficient space is best-effort)
- Filesystem supports standard file operations (copy, create directories, etc.)
- Timestamp information is available from files (modification date at minimum; EXIF dates are optional enhancement)
- Year/Month folder structure is sufficient for P1 organization (more complex organization is out of scope)
- Collision policy can be configured per import job (default policy is acceptable for P1)
- Import tracking can use path-based or content-based identifiers (path-based is simpler for P1)
- Import results are stored in a transparent, human-readable format
- Multiple import jobs on the same Library are serialized (concurrent imports are out of scope for P1)
- Video files are handled the same way as image files for P1 (no special video strategies)
