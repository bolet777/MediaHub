# MediaHub Project Status

**Document Type**: Project Status & Roadmap Tracking  
**Purpose**: Memory of project state, decisions, and planned slices  
**Last Updated**: 2026-01-27  
**Note**: This is a tracking document, not a normative specification. For authoritative specs, see individual slice specifications in `specs/`.

---

## Completed Slices

### ✅ Slice 1 — Library Entity & Identity
**Status**: Complete and validated  
**Spec**: `specs/001-library-entity/`  
**Validation**: `specs/001-library-entity/validation.md`

**Deliverables**:
- Persistent, identifiable libraries on disk
- Multiple independent libraries
- Validation, discovery, and identity persistence across moves/renames
- Legacy library adoption (MediaVault pattern detection)

### ✅ Slice 2 — Sources & Import Detection
**Status**: Complete and validated  
**Spec**: `specs/002-sources-import-detection/`  
**Validation**: `specs/002-sources-import-detection/validation.md`

**Deliverables**:
- Folder-based Sources
- Read-only, deterministic detection of new media
- Explainable detection results
- Persistent Source–Library associations
- Library comparison to identify new items

### ✅ Slice 3 — Import Execution & Media Organization
**Status**: Complete and validated  
**Spec**: `specs/003-import-execution-media-organization/`  
**Validation**: `specs/003-import-execution-media-organization/validation.md`

**Deliverables**:
- Real media import (copy from Source to Library)
- Deterministic Year/Month (YYYY/MM) organization
- Collision handling (rename / skip / error)
- Atomic and interruption-safe import
- Known-items tracking to prevent re-imports
- Auditable import results

### ✅ Slice 4 — CLI Tool & Packaging
**Status**: Complete and validated  
**Spec**: `specs/004-cli-tool-packaging/`  
**Validation**: `specs/004-cli-tool-packaging/validation.md`

**Deliverables**:
- Command-line interface (CLI) executable
- Library management commands (`create`, `open`, `list`)
- Source management commands (`attach`, `list`)
- Detection command (`detect`)
- Import command (`import --all`)
- Status command (`status`)
- JSON output support (`--json`)
- Progress feedback for long-running operations

### ✅ Slice 5 — Safety Features & Dry-Run Operations
**Status**: Complete and validated  
**Spec**: `specs/005-safety-features-dry-run/`  
**Validation**: `specs/005-safety-features-dry-run/validation.md`

**Deliverables**:
- Dry-run mode for import operations (preview without copying)
- Explicit confirmation prompts for import operations
- Read-only guarantees for detection operations (explicit documentation)
- Safety-first error handling and interruption handling
- JSON output support for dry-run mode

---

## Planned Slices

### 🔲 Slice 6 — Library Adoption
**Status**: Planned (not yet implemented)  
**Analysis**: `specs/archive/RAPPORT_ADOPTION_LIBRAIRIE.md`

**Objective**: Enable adoption of an existing media library (e.g., `/Volumes/Photos/Photos/Librairie_Amateur` organized in YYYY/MM) as a MediaHub library without modifying existing media files.

**Key Requirements** (from analysis report):
- Create `.mediahub/library.json` in an existing library directory
- No modification of existing media files (no-touch guarantee)
- Support dry-run mode for preview
- Explicit confirmation before adoption
- Baseline scan of existing files (via existing `LibraryContentQuery`)

**Proposed Command**: `mediahub library adopt <path> [--dry-run]`

**Architectural Compatibility**: ✅ Confirmed compatible
- Core architecture supports adoption (structure minimum is permissive)
- `LibraryContentQuery` already scans all existing media files
- Import system is idempotent and handles collisions safely
- Safety features (dry-run, confirmation) are compatible

**Gap Identified**: No explicit command/API for adopting a "virgin" library (non-legacy, just organized in YYYY/MM). `LegacyLibraryAdopter` only detects specific legacy patterns (MediaVault).

**Decision** (from analysis report): Implement `library adopt` command as minimal addition, reusing existing architecture without core changes.

### 🔲 Slice 7 — Baseline Index
**Status**: Planned (future)

**Objective**: Performance optimization for large libraries by creating a baseline index of existing media files.

**Proposed Features**:
- Create `.mediahub/registry/index.json` with baseline file list
- Optional hash/checksum for future deduplication
- Incremental index updates (on import, not full re-scan)
- Faster detection runs for large libraries

**Note**: For P1, `LibraryContentQuery.scanLibraryContents()` is sufficient. Index is a performance optimization for P2.

### 🔲 Slice 8 — Advanced Hashing & Deduplication
**Status**: Planned (future)

**Objective**: Cross-source deduplication using content hashing (SHA-256 or similar).

**Proposed Features**:
- Content-based file identification (hash/checksum)
- Cross-source duplicate detection
- Global deduplication (beyond path-based known-items)
- Optional hash storage in baseline index

**Note**: Currently, known-items tracking is path-based and source-scoped. Hashing enables content-based deduplication across sources.

---

## Key Architectural Decisions

### Source vs Library Model

**Source**:
- Input location (iPhone, Photos.app, folder)
- Read-only during detection and import
- MediaHub never modifies Source files
- Can be attached to one or more Libraries

**Library**:
- Final destination controlled by MediaHub
- Contains `.mediahub/` metadata directory
- Organizes media in Year/Month (YYYY/MM) structure
- MediaHub manages Library structure and metadata
- Files remain accessible without MediaHub (transparent storage)

### Library Adoption Status

**Current State**: Not yet implemented

**What Works Today**:
- Opening existing MediaHub libraries (with `.mediahub/library.json`)
- Legacy library adoption (MediaVault pattern detection)
- Importing into libraries that already contain media files (collision handling)

**What's Missing**:
- Explicit command to adopt a "virgin" library (existing YYYY/MM structure without MediaHub metadata)
- Workflow to bootstrap `.mediahub/` in an existing library

**Planned Solution**: Slice 6 — `library adopt` command

---

## Analysis Reports

### Library Adoption Analysis (2026-01-27)
**Document**: `specs/archive/RAPPORT_ADOPTION_LIBRAIRIE.md`

**Key Findings**:
- ✅ Core architecture is compatible with library adoption
- ✅ `LibraryContentQuery` scans all existing media files (baseline works)
- ✅ Import system is idempotent and safe (handles existing files correctly)
- ⚠️ Gap: No explicit command for adopting non-legacy libraries
- ✅ Recommendation: Minimal addition (`library adopt` command) without core changes

**Decision**: Proceed with Slice 6 implementation using minimal addition approach.

---

## Out of Scope (As of Slice 5)

- Photos.app or device-specific integrations
- User interface / media browsing
- Advanced duplicate detection (hashing, fuzzy matching) — planned for Slice 8
- Metadata enrichment (tags, faces, albums)
- Pipelines, automation, or scheduling
- Cloud sync or backup features
- Library adoption (planned for Slice 6)

---

## Notes

- All completed slices are frozen and covered by automated validation
- Constitution (`CONSTITUTION.md`) remains the supreme normative document
- Individual slice specifications in `specs/` are authoritative for their scope
- This status document is for tracking only, not normative

---

**Last Updated**: 2026-01-27  
**Next Review**: After Slice 6 implementation
