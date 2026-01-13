# Feature Specification: MediaHub Sources & Import Detection

**Feature Branch**: `002-sources-import-detection`  
**Created**: 2025-01-27  
**Status**: Ready for Plan  
**Input**: User description: "Allow a MediaHub Library to be connected to one or more Sources and to safely detect new media items available for import, without modifying the source or importing files yet."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Attach a Source to a Library (Priority: P1)

A user wants to connect a source (such as a folder or device) to their MediaHub library so that MediaHub can detect new media items available for import. The user should be able to attach one or more sources to a library, and MediaHub must validate that the source is accessible and has appropriate permissions before allowing attachment.

**Why this priority**: This is the foundational action that enables source detection. Without the ability to attach sources, users cannot begin detecting new media items for import.

**Independent Test**: Can be fully tested by attaching a source to an existing library and verifying that MediaHub recognizes it as a valid source. This delivers the core capability of establishing a source-library association.

**Acceptance Scenarios**:

1. **Given** a user has an open MediaHub library, **When** they choose to attach a folder source at a specified path, **Then** MediaHub validates the source is accessible and attaches it to the library
2. **Given** a user wants to attach a source, **When** they specify a path that doesn't exist or is inaccessible, **Then** MediaHub reports a clear error and does not attach the source
3. **Given** a user wants to attach a source, **When** they specify a path without read permissions, **Then** MediaHub reports a permission error and does not attach the source
4. **Given** a user has attached a source to a library, **When** they close and reopen MediaHub, **Then** MediaHub recognizes the previously attached source and maintains the association
5. **Given** a user has a library with multiple sources attached, **When** they view the library's sources, **Then** MediaHub displays all attached sources with their current status (accessible/inaccessible)

---

### User Story 2 - Detect New Media Items from a Source (Priority: P1)

A user wants MediaHub to scan an attached source and identify which photos/videos are new relative to their library. MediaHub must produce a deterministic list of candidate media items that are available for import, without modifying the source or importing files.

**Why this priority**: This is the core functionality that enables users to see what's available for import. Without detection, users cannot know what new media is available.

**Independent Test**: Can be fully tested by running detection on a source and verifying that MediaHub produces a list of candidate items that are new relative to the library. This delivers the detection capability without side effects.

**Acceptance Scenarios**:

1. **Given** a user has attached a folder source containing photos and videos, **When** they run detection on that source, **Then** MediaHub scans the source and lists all candidate media items found
2. **Given** a user runs detection on a source, **When** some items in the source are already known to the library, **Then** MediaHub excludes those items from the candidate list and only shows new items
3. **Given** a user runs detection on a source, **When** they run detection again without changing the source, **Then** MediaHub produces the same deterministic results
4. **Given** a user runs detection on a source, **When** they add new files to the source and run detection again, **Then** MediaHub detects only the newly added items as candidates
5. **Given** a user runs detection on a source, **When** the source becomes inaccessible during detection, **Then** MediaHub reports a clear error and stops detection gracefully

---

### User Story 3 - View Detection Results (Priority: P1)

A user wants to see the results of a detection run in a clear, explainable format. The results should show which items are candidates for import and provide information about why items were included or excluded.

**Why this priority**: Users need to understand what will be imported before proceeding. Clear, explainable results build trust and enable informed decisions.

**Independent Test**: Can be fully tested by running detection and verifying that results are presented in a clear format with explainable inclusion/exclusion reasons. This delivers transparency and auditability.

**Acceptance Scenarios**:

1. **Given** a user has run detection on a source, **When** they view the detection results, **Then** MediaHub displays a list of candidate items with file names, paths, and basic metadata
2. **Given** a user views detection results, **When** they examine why an item was excluded, **Then** MediaHub provides a clear explanation (e.g., "already known", "unsupported format", "unreadable")
3. **Given** a user views detection results, **When** they examine why an item was included, **Then** MediaHub confirms the item is new and available for import
4. **Given** a user views detection results, **When** the results are empty (no new items), **Then** MediaHub clearly indicates that all items are already known to the library
5. **Given** a user views detection results, **When** they view results from multiple detection runs, **Then** MediaHub maintains separate result sets that can be compared

---

### User Story 4 - Re-run Detection Safely (Priority: P2)

A user wants to re-run detection on a source to check for changes, verify results, or update the candidate list. Re-running detection must be safe, deterministic, and not cause side effects.

**Why this priority**: Users need confidence that detection is reliable and repeatable. Safe re-runs enable verification and catch changes in sources.

**Independent Test**: Can be fully tested by running detection multiple times and verifying that results are consistent when the source hasn't changed, and updated when the source has changed. This delivers determinism and safety.

**Acceptance Scenarios**:

1. **Given** a user has run detection on a source, **When** they re-run detection immediately without changing the source, **Then** MediaHub produces identical results
2. **Given** a user has run detection on a source, **When** they modify files in the source and re-run detection, **Then** MediaHub detects the changes and updates the candidate list accordingly
3. **Given** a user has run detection on a source, **When** they re-run detection after the source was temporarily inaccessible, **Then** MediaHub handles the error gracefully and reports the issue
4. **Given** a user has run detection multiple times, **When** they compare results from different runs, **Then** MediaHub maintains an audit trail showing what changed between runs

---

### Edge Cases

- What happens when a source is attached but later becomes permanently inaccessible (e.g., external drive disconnected)?
- What happens when a source contains files that are locked or in use by another application?
- What happens when a source contains symbolic links or aliases to media files?
- What happens when a source contains nested folders with media files at various depths?
- What happens when a source contains files with invalid or corrupted metadata?
- What happens when a source contains files that appear to be media but are not (e.g., text files with image extensions)?
- What happens when detection is interrupted (e.g., application quit, system shutdown)?
- What happens when a source is moved or renamed after attachment?
- What happens when multiple sources contain the same media file (duplicate detection across sources)?
- What happens when a source contains files that were previously imported but have since been deleted from the library?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: MediaHub MUST support attaching at least one Source to an existing MediaHub Library
- **FR-002**: MediaHub MUST support multiple Sources attached to a single Library
- **FR-003**: MediaHub MUST validate Source accessibility and permissions before allowing attachment
- **FR-004**: MediaHub MUST maintain Source identity that persists across application restarts for an attached Source
- **FR-005**: MediaHub MUST support at least folder-based Sources (other types may be added in future slices)
- **FR-006**: MediaHub MUST be able to scan a Source to detect candidate media files
- **FR-007**: MediaHub MUST identify which candidate items are new relative to the Library
- **FR-008**: MediaHub MUST exclude items already known to the Library from candidate lists
- **FR-009**: MediaHub MUST produce deterministic detection results (same source state produces same results)
- **FR-010**: MediaHub MUST support re-running detection safely without side effects
- **FR-011**: MediaHub MUST never modify Source files during detection
- **FR-012**: MediaHub MUST report clear errors when Sources are inaccessible or have permission issues
- **FR-013**: MediaHub MUST maintain detection results in an explainable and auditable format
- **FR-014**: MediaHub MUST handle detection interruptions gracefully
- **FR-015 (P2)**: MediaHub SHOULD detect when a Source has been moved or renamed after attachment (best-effort; may be refined in later slices)
- **FR-016**: MediaHub MUST support detection of common image and video file formats
- **FR-017**: MediaHub MUST store Source associations in a transparent, human-readable format

### Key Entities *(include if feature involves data)*

- **Source**: An external location (folder, device, etc.) that contains media files available for import into a MediaHub Library. A Source has a unique identity that persists across application restarts and can be attached to one or more Libraries. Sources are read-only during detection; MediaHub never modifies Source files.

- **Source Identity**: A persistent identifier that uniquely identifies a Source and allows MediaHub to recognize it over time, even if the Source's path changes or the Source is temporarily inaccessible. Source identity enables tracking of Source-Library associations and detection history.

- **Source-Library Association**: A relationship between a Source and a Library that indicates the Source is attached to the Library and can be scanned for new media items. Associations are stored persistently and survive application restarts.

- **Candidate Media Item**: A media file found in a Source that is available for import. A candidate item represents a pre-import state: it has been detected but not yet imported. Candidate items include file path, basic metadata, and status (new vs. already known).

- **Detection Run**: A single execution of the detection process on a Source that produces a deterministic result set of candidate media items. Detection runs are read-only operations that scan Sources without modifying them. Each detection run produces a result that can be compared to previous runs.

- **Detection Result**: The output of a detection run, containing a list of candidate media items with their status (new, duplicate, excluded, etc.) and explanations for inclusion or exclusion. Detection results are deterministic, explainable, and auditable.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can attach a Source to a Library in under 10 seconds from initiation to completion
- **SC-002**: MediaHub can validate Source accessibility and permissions within 2 seconds
- **SC-003**: MediaHub can detect candidate items from a Source containing 1000 files within 30 seconds on a local filesystem under normal conditions
- **SC-004**: Detection results are 100% deterministic (same source state produces identical results)
- **SC-005**: Re-running detection on an unchanged Source produces identical results 100% of the time
- **SC-006**: MediaHub correctly identifies items already known to the Library with 100% accuracy
- **SC-007**: Detection results are explainable (users can understand why items were included/excluded)
- **SC-008**: Source associations persist across application restarts 100% of the time
- **SC-009**: MediaHub reports clear, actionable error messages for inaccessible Sources within 5 seconds
- **SC-010**: Detection can be safely interrupted and resumed without corrupting results

## Assumptions

- Sources will be stored on standard macOS file systems (APFS, HFS+, or network volumes)
- Users have appropriate file system permissions to read from Source locations
- Media files in Sources are in standard formats (JPEG, PNG, HEIC, MOV, MP4, etc.)
- Sources may contain nested folder structures with media files at various depths
- Sources may become temporarily or permanently inaccessible (external drives, network volumes)
- Detection will be performed on-demand by user action (not automatically scheduled)
- Folder-based Sources are sufficient for this slice (device and Photos.app integration are future enhancements)
- Detection results will be stored in a transparent format that can be audited
- Source identity may be determined from file system properties (path, volume identifier, etc.); handling moved/renamed sources is best-effort and may be refined in later slices
