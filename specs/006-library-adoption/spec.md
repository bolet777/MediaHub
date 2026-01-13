# Feature Specification: Library Adoption

**Feature Branch**: `006-library-adoption`  
**Created**: 2026-01-27  
**Status**: Ready for Plan  
**Input**: User description: "Support adopting an existing media library directory that already contains all final photos/videos organized in YYYY/MM (e.g. /Volumes/Photos/Photos/Librairie_Amateur) as a MediaHub library without modifying existing media files."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Adopt an Existing Library Directory (Priority: P1)

A user has an existing media library directory that already contains all their photos and videos organized in YYYY/MM folders (e.g., `/Volumes/Photos/Photos/Librairie_Amateur`). This directory is their "source of truth" library (like Photos.app) and must never have its existing media files modified. The user wants to adopt this directory as a MediaHub library so that future imports from Sources (Photos.app exports, folders, eventually iPhone) can add only new items to the adopted library in a deterministic and idempotent way.

**Why this priority**: This is the foundational action that enables users with existing organized libraries to use MediaHub without re-importing or reorganizing their existing media. Without adoption, users would need to start with an empty library and re-import everything, which is impractical for large existing collections.

**Independent Test**: Can be fully tested by running `mediahub library adopt <path>` on an existing directory containing media files organized in YYYY/MM and verifying that MediaHub creates only `.mediahub/` metadata without modifying any existing media files. This delivers the core capability of bootstrapping MediaHub metadata in an existing library.

**Acceptance Scenarios**:

1. **Given** a user has an existing directory with media files organized in YYYY/MM folders, **When** they run `mediahub library adopt <path>`, **Then** MediaHub creates `.mediahub/library.json` and minimal metadata without modifying, moving, renaming, or deleting any existing media files
2. **Given** a user runs `mediahub library adopt <path>`, **When** the target directory already contains `.mediahub/library.json`, **Then** MediaHub detects the existing library and returns a clear message indicating the library is already adopted (idempotent behavior)
3. **Given** a user runs `mediahub library adopt <path>`, **When** the target path doesn't exist or is not a directory, **Then** MediaHub reports a clear error and does not create any metadata
4. **Given** a user runs `mediahub library adopt <path>`, **When** the target directory lacks write permissions, **Then** MediaHub reports a permission error and does not create any metadata
5. **Given** a user has adopted a library, **When** they run `mediahub library open <path>`, **Then** MediaHub successfully opens the adopted library and recognizes all existing media files

---

### User Story 2 - Preview Adoption with Dry-Run (Priority: P1)

A user wants to preview what would happen during adoption without actually creating any metadata files. The CLI should support a `--dry-run` flag that shows exactly what metadata would be created and what baseline scan would be performed, without performing any file system modifications.

**Why this priority**: Dry-run is the foundational safety feature that enables users to explore and understand adoption operations before committing to them. Without dry-run, users must trust that adoption won't modify their existing media files without verification.

**Independent Test**: Can be fully tested by running `mediahub library adopt <path> --dry-run` and verifying that:
- No files are created or modified
- Output shows what metadata would be created
- Baseline scan preview is displayed
- Exit code is 0 (successful preview)

**Acceptance Scenarios**:

1. **Given** a user runs `mediahub library adopt <path> --dry-run`, **When** the command executes, **Then** MediaHub displays a detailed preview of what metadata would be created (`.mediahub/` directory, `library.json` contents) and what baseline scan would be performed without creating any files
2. **Given** a user runs adoption with `--dry-run` flag, **When** the preview completes, **Then** MediaHub shows a summary indicating this was a dry-run (e.g., "DRY-RUN: Would create .mediahub/library.json") and no files are created or modified
3. **Given** a user runs adoption with `--dry-run` flag and JSON output, **When** the preview completes, **Then** MediaHub outputs JSON results with a `dryRun: true` field and all preview information in machine-readable format
4. **Given** a user runs adoption with `--dry-run` flag, **When** the preview completes, **Then** MediaHub exit code is 0 (successful preview) and no file system modifications occur
5. **Given** a user runs adoption with `--dry-run` flag, **When** the target directory already contains `.mediahub/library.json`, **Then** MediaHub preview shows that the library is already adopted and no new metadata would be created

---

### User Story 3 - Explicit Confirmation for Adoption (Priority: P1)

A user wants explicit confirmation before MediaHub creates metadata files in their existing library directory. The CLI should prompt for explicit user confirmation before proceeding with adoption operations that create metadata files, with a `--yes` flag available to bypass confirmation for non-interactive scripts.

**Why this priority**: Explicit confirmation prevents accidental adoption and gives users a final checkpoint before metadata creation. This aligns with Constitution principle 3.3 "Safe Operations" which requires explicit user confirmation for actions that modify the file system (even if only metadata).

**Independent Test**: Can be fully tested by running `mediahub library adopt <path>` (without `--yes`) and verifying that:
- CLI prompts for confirmation
- Adoption does not proceed without confirmation
- `--yes` flag bypasses confirmation for scripting
- Confirmation prompt shows summary of what will be created

**Acceptance Scenarios**:

1. **Given** a user runs `mediahub library adopt <path>` without `--yes` flag, **When** the command executes, **Then** MediaHub displays a confirmation prompt showing what will be created (metadata location, baseline scan summary) and waits for user input
2. **Given** a user is prompted for confirmation, **When** they type "yes" or "y", **Then** MediaHub proceeds with the adoption operation
3. **Given** a user is prompted for confirmation, **When** they type "no" or "n" or press Ctrl+C, **Then** MediaHub cancels the adoption operation, displays a cancellation message, and exits with code 0 (user cancellation is not an error)
4. **Given** a user runs adoption with `--yes` flag, **When** the command executes, **Then** MediaHub proceeds with adoption without prompting (suitable for scripting)
5. **Given** a user runs adoption with `--dry-run` flag, **When** the command executes, **Then** MediaHub does not prompt for confirmation (dry-run is always safe and requires no confirmation)
6. **Given** a user runs adoption in a non-interactive environment (no TTY), **When** the command executes without `--yes`, **Then** MediaHub detects non-interactive mode and fails with a clear error message instructing the user to use `--yes` flag

---

### User Story 4 - Baseline Scan of Existing Media (Priority: P1)

A user wants MediaHub to scan all existing media files in the adopted directory and establish them as a baseline so that future imports from Sources will only add new items (idempotent imports). The baseline scan should be deterministic and should not require content hashing (performance/indexing is Slice 7; hashing/dedup is Slice 8).

**Why this priority**: Baseline scanning ensures that existing media files are recognized as "known" for future detection runs, enabling idempotent imports. Without baseline scanning, future imports might attempt to re-import existing media files, causing duplicates or collisions.

**Independent Test**: Can be fully tested by adopting a library with existing media files and then running detection on a Source that contains some of the same files, verifying that existing files are excluded from candidate lists. This delivers the idempotent import capability.

**Acceptance Scenarios**:

1. **Given** a user adopts a library containing existing media files in YYYY/MM folders, **When** adoption completes, **Then** MediaHub performs a baseline scan of all existing media files (excluding `.mediahub/`) and records them for future detection comparison
2. **Given** a user has adopted a library with baseline scan, **When** they run detection on a Source containing files that already exist in the library, **Then** MediaHub excludes those existing files from the candidate list (idempotent detection)
3. **Given** a user runs adoption, **When** the baseline scan completes, **Then** MediaHub scan results are deterministic (same library state produces same baseline scan results)
4. **Given** a user runs adoption multiple times on the same library (idempotent), **When** adoption completes, **Then** MediaHub baseline scan produces consistent results (no duplicates, no changes to existing baseline)
5. **Given** a user runs adoption with `--dry-run` flag, **When** the preview completes, **Then** MediaHub shows what baseline scan would be performed (file count, scan scope) without actually performing the scan

---

### User Story 5 - Idempotent Adoption (Priority: P1)

A user wants to be able to re-run adoption on an already adopted library safely. Re-running adoption must be safe, deterministic, and return a clear outcome without modifying existing metadata or media files.

**Why this priority**: Idempotent adoption enables safe re-runs, verification, and recovery scenarios. Users should be able to re-run adoption without fear of corruption or duplicate metadata.

**Independent Test**: Can be fully tested by running `mediahub library adopt <path>` multiple times on the same library and verifying that:
- Results are consistent
- No duplicate metadata is created
- Clear messaging indicates library is already adopted
- Exit code is 0 (successful, no-op)

**Acceptance Scenarios**:

1. **Given** a user has already adopted a library, **When** they run `mediahub library adopt <path>` again, **Then** MediaHub detects the existing library and returns a clear message indicating the library is already adopted (idempotent behavior)
2. **Given** a user runs adoption on an already adopted library, **When** the command completes, **Then** MediaHub does not modify existing metadata files and does not create duplicate metadata
3. **Given** a user runs adoption on an already adopted library, **When** the command completes, **Then** MediaHub exit code is 0 (successful idempotent operation, not an error)
4. **Given** a user runs adoption on an already adopted library with `--dry-run` flag, **When** the preview completes, **Then** MediaHub shows that the library is already adopted and no new metadata would be created
5. **Given** a user runs adoption on an already adopted library, **When** the command completes, **Then** MediaHub baseline scan (if re-run) produces consistent results matching the existing baseline

---

### Edge Cases

- What happens when a user runs `--dry-run` and `--yes` together? (dry-run should not require confirmation, but --yes should be accepted)
- What happens when a user runs adoption on a directory that becomes inaccessible during the operation?
- What happens when a user runs adoption with confirmation prompt in a script that doesn't have TTY?
- What happens when a user cancels confirmation (Ctrl+C) - is this an error or successful cancellation?
- What happens when a user runs adoption on a directory that contains both media files and non-media files?
- What happens when a user runs adoption on a directory with very large numbers of media files (performance considerations)?
- What happens when a user runs adoption on a directory with nested YYYY/MM structures (e.g., `2024/01/subfolder/image.jpg`)?
- What happens when a user runs adoption on a directory that contains symbolic links to media files?
- What happens when a user runs adoption on a read-only directory (should fail gracefully)?
- What happens when a user runs adoption and the baseline scan encounters unreadable or corrupted media files?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: MediaHub CLI MUST support a `library adopt <path>` command that bootstraps MediaHub metadata in an existing library directory
- **FR-002**: MediaHub CLI MUST create ONLY MediaHub metadata files (`.mediahub/` directory, `library.json`) during adoption and MUST NOT modify, move, rename, or delete any existing media files
- **FR-003**: MediaHub CLI MUST support a `--dry-run` flag on the `library adopt` command that previews adoption operations without creating any files
- **FR-004**: MediaHub CLI MUST display detailed preview information when `--dry-run` is used, including what metadata would be created and what baseline scan would be performed
- **FR-005**: MediaHub CLI MUST ensure that `--dry-run` operations perform zero file system writes (no metadata creation, no baseline scan writes, no file modifications). Dry-run MAY perform read-only operations (scanning, counting, previewing files) to produce preview information, but MUST NOT write, create, modify, or delete any files
- **FR-006**: MediaHub CLI MUST support a `--yes` flag on the `library adopt` command that bypasses confirmation prompts for non-interactive usage
- **FR-007**: MediaHub CLI MUST prompt for explicit confirmation before performing adoption operations (when `--yes` is not provided and not in dry-run mode)
- **FR-008**: MediaHub CLI MUST display a clear confirmation prompt showing what will be created (metadata location, baseline scan summary) before proceeding
- **FR-009**: MediaHub CLI MUST handle user cancellation of confirmation (typing "no", "n", or Ctrl+C) gracefully and exit with code 0 (cancellation is not an error)
- **FR-010**: MediaHub CLI MUST detect non-interactive environments (no TTY) and require `--yes` flag for adoption operations (fail with clear error if `--yes` is not provided)
- **FR-011**: MediaHub CLI MUST perform a baseline scan of all existing media files in the adopted directory (excluding `.mediahub/`) during adoption
- **FR-012**: MediaHub CLI MUST ensure that baseline scan results are deterministic (same library state produces same baseline scan results)
- **FR-013**: MediaHub CLI MUST ensure that adoption is idempotent (re-running adopt on an already adopted library is safe and returns a clear outcome)
- **FR-014**: MediaHub CLI MUST detect when a library is already adopted and return a clear message without creating duplicate metadata
- **FR-015**: MediaHub CLI MUST validate that the target path exists and is a directory before attempting adoption
- **FR-016**: MediaHub CLI MUST validate that the target directory has write permissions before attempting adoption
- **FR-017**: MediaHub CLI MUST provide clear, actionable error messages when adoption operations fail
- **FR-018**: MediaHub CLI MUST ensure that baseline scan does not require content hashing (path-based scanning only for P1)
- **FR-019**: MediaHub CLI MUST support `--dry-run` flag with JSON output format, including a `dryRun: true` field in JSON results
- **FR-020**: MediaHub CLI MUST ensure that `--dry-run` preview accurately reflects what would happen during actual adoption (same metadata structure, same baseline scan scope)
- **FR-021**: MediaHub CLI MUST display clear messaging that "No media files will be modified; only .mediahub metadata will be created" during adoption operations

### Key Entities *(include if feature involves data)*

- **Library Adoption**: The process of bootstrapping MediaHub metadata (`.mediahub/` directory and `library.json`) in an existing media library directory that already contains organized media files. Adoption never modifies, moves, renames, or deletes existing media files.

- **Baseline Scan**: A deterministic scan of all existing media files in an adopted library directory (excluding `.mediahub/`) that establishes these files as "known" for future detection runs. Baseline scan is path-based only (no content hashing) for P1 and enables idempotent imports.

- **Adoption Metadata**: The minimal MediaHub metadata created during adoption, consisting of `.mediahub/` directory and `library.json` file. This metadata makes the directory identifiable as a MediaHub library and enables future operations (detection, import, etc.).

- **Idempotent Adoption**: The property that re-running adoption on an already adopted library is safe and produces a clear outcome without creating duplicate metadata or modifying existing files. Idempotent adoption enables safe re-runs and verification.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can adopt an existing library directory with `library adopt <path>` and MediaHub creates only `.mediahub/` metadata without modifying any existing media files (zero media file modifications verified by tests)
- **SC-002**: Users can preview adoption operations with `--dry-run` flag and see accurate preview of what would be created (100% accuracy: dry-run preview matches actual adoption results)
- **SC-003**: Users can run `--dry-run` operations without any file system modifications (zero file operations verified by tests)
- **SC-004**: Users are prompted for explicit confirmation before adoption operations (when `--yes` is not provided and not in dry-run mode)
- **SC-005**: Users can bypass confirmation with `--yes` flag for scripting (non-interactive usage works correctly)
- **SC-006**: Users receive clear error messages when running adoption in non-interactive mode without `--yes` flag (error message instructs user to use `--yes`)
- **SC-007**: Baseline scan results are 100% deterministic (same library state produces identical baseline scan results)
- **SC-008**: Adoption is idempotent (re-running adopt on an already adopted library produces consistent results without duplicate metadata)
- **SC-009**: Future detection runs on Sources exclude existing media files from adopted library (100% accuracy: existing files are not included in candidate lists)
- **SC-010**: Adoption operations handle errors gracefully without leaving library in inconsistent state (no partial metadata, valid library state after errors)
- **SC-011**: Dry-run preview accurately reflects actual adoption behavior (same metadata structure, same baseline scan scope - verified by tests)
- **SC-012**: JSON output format includes `dryRun: true` field when `--dry-run` flag is used
- **SC-013**: All existing core tests still pass after adoption feature implementation (no regression in core functionality)
- **SC-014**: Adoption feature works correctly with all existing CLI commands and options (compatibility with `--json`, `--library`, etc.)

**Note on Performance**: Adoption should complete in reasonable time for typical library sizes. Performance optimizations for very large libraries (10,000+ files) are addressed in Slice 7 (Baseline Index) and are not a P1 requirement for this slice.

## Assumptions

- Users will primarily use adoption to bootstrap MediaHub metadata in existing organized libraries (YYYY/MM structure)
- Users will use `--dry-run` to preview adoption before executing it
- Users will use `--yes` flag in scripts and automation workflows
- Interactive confirmation is suitable for terminal environments (Terminal.app, iTerm)
- Non-interactive adoption (no TTY) should fail gracefully with clear error message requiring `--yes` flag
- Dry-run operations should be fast (no actual file I/O, so should complete quickly)
- Confirmation prompts should be clear and show actionable information (metadata location, baseline scan summary)
- Baseline scan is path-based only (no content hashing) for P1; hashing/dedup is deferred to Slice 8
- Adoption metadata structure is minimal (`.mediahub/library.json` only); performance baseline index is deferred to Slice 7
- Existing media files in adopted libraries are organized in YYYY/MM folders (common pattern, but not strictly required)
- Adoption should work with libraries containing nested folder structures
- Adoption should handle libraries with mixed media and non-media files gracefully

## Safety Constraints

### Explicit Target Directories

- **CLI Code**: The majority of changes MUST be in `Sources/MediaHubCLI/` (new `adopt` subcommand, confirmation handling, dry-run preview)
- **Core Code**: Core adoption features MAY require minimal changes in `Sources/MediaHub/` but MUST be focused strictly on adoption metadata creation and validation only (reuse existing `LibraryStructureCreator`, `LibraryMetadata`, etc., without refactoring existing core logic)
- **Tests**: Adoption feature tests MUST be in `Tests/MediaHubTests/` or new `Tests/MediaHubCLITests/` if created
- **Documentation**: Adoption feature documentation updates MAY be in `docs/` but MUST NOT modify existing ADRs without explicit justification

### Explicit "No Touch" Rules

- **DO NOT** modify, move, rename, or delete any existing media files during adoption
- **DO NOT** create or reorganize YYYY/MM folders (assume existing structure is correct)
- **DO NOT** perform content hashing during baseline scan (path-based only for P1)
- **DO NOT** create performance baseline index beyond minimal required metadata (deferred to Slice 7)
- **DO NOT** modify existing core library creation logic beyond reusing components for adoption
- **DO NOT** change existing detection behavior (it already works with existing files via `LibraryContentQuery`)
- **DO NOT** modify Package.swift beyond adding dependencies if absolutely necessary
- **DO NOT** modify existing specs/ or docs/ except for this Slice 6 spec
- **DO NOT** change existing CLI command structure or argument parsing beyond adding new `adopt` subcommand
- **DO NOT** modify existing error types or error handling beyond adding adoption-specific error messages

### Explicit Validation Commands

- **Validation**: Run `swift test` to ensure all existing tests pass
- **Validation**: Run `scripts/smoke_cli.sh` to ensure CLI smoke tests pass with new adoption feature
- **Validation**: Manual testing of `--dry-run` flag to verify zero file operations
- **Validation**: Manual testing of confirmation prompts in interactive and non-interactive modes
- **Validation**: Verify that dry-run preview matches actual adoption results (same inputs produce same preview/execution)
- **Validation**: Verify that adoption is idempotent (re-running produces consistent results)
- **Validation**: Verify that future detection runs exclude existing media files from adopted library

## Non-Goals

- **P2 Features**: Performance baseline index (`.mediahub/registry/index.json`) beyond minimal required metadata (Slice 7)
- **P2 Features**: Content hashing/deduplication during baseline scan (Slice 8)
- **P2 Features**: Creating or reorganizing YYYY/MM folders (assume existing structure is correct)
- **P2 Features**: Photos.app direct integration, iPhone device ingestion (future slices)
- **P2 Features**: UI / browsing / tagging / metadata enrichment (out of scope)
- **P2 Features**: Advanced adoption features (e.g., adoption with different metadata schemas, adoption rollback)
- **P2 Features**: Adoption audit logs or adoption event tracking (out of scope for Slice 6)
- **P2 Features**: Adoption of libraries with non-standard structures (P1 focuses on YYYY/MM organized libraries)

## Constitutional Compliance

This specification adheres to the MediaHub Constitution:

- **3.3 Safe Operations**: Explicit confirmation for metadata creation, dry-run preview, no-touch guarantee for existing media files
- **4.1 Data Safety**: No modification of existing media files, library integrity preservation, safe error handling
- **3.4 Deterministic Behavior**: Baseline scan must be deterministic (same inputs produce same outputs), adoption must be idempotent
- **3.2 Transparent Storage**: Adoption metadata is transparent and readable without MediaHub; existing media files remain directly accessible
- **3.1 Simplicity of User Experience**: Adoption command is simple and explicit, with clear messaging about what will be created
