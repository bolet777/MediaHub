# MediaHub Project Status

**Document Type**: Project Status & Roadmap Tracking  
**Purpose**: Memory of project state, decisions, and planned slices  
**Last Updated**: 2026-01-27  
**Next Review**: After Slice 7 or after real-world usage  
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

### ✅ Slice 6 — Library Adoption
**Status**: Complete and validated  
**Spec**: `specs/006-library-adoption/spec.md`  
**Validation**: `specs/006-library-adoption/VALIDATION_RUNBOOK.md`

**Deliverables**:
- `library adopt <path> [--dry-run] [--yes]` command
- Adoption of existing library directories organized in YYYY/MM without modifying media files
- Baseline scan of existing media files to establish "known items" for future detection
- Dry-run preview mode for adoption operations
- Explicit confirmation prompts (with `--yes` bypass for scripting)
- Idempotent adoption (safe re-runs on already adopted libraries)
- Integration with existing `detect` and `import` commands for incremental imports

---

## Planned Slices

### 🔲 Slice 7 — Baseline Index
**Status**: Planned (future)

**Objective**: Performance optimization for very large libraries by creating a persistent baseline index of existing media files.

**Proposed Features**:
- Create `.mediahub/registry/index.json` with baseline file list
- Index structure prepared for future hash storage (Slice 8)
- Incremental index updates (on import, not full re-scan)
- Faster detection runs for large libraries (10,000+ files)

**Note**: This is a performance optimization, not a functional prerequisite. Current `LibraryContentQuery.scanLibraryContents()` is sufficient for typical library sizes. Slice 7 improves `detect` and `import` performance for very large libraries. Slice 7 does NOT perform content hashing (hashing is reserved for Slice 8).

**Dependency**: Builds on Slice 6 (adoption baseline scan). Slice 7 adds persistent indexing to avoid full re-scans.

### 🔲 Slice 8 — Advanced Hashing & Deduplication
**Status**: Planned (future)

**Objective**: Cross-source deduplication using content hashing (SHA-256 or similar) to identify duplicate media files across different sources.

**Proposed Features**:
- Content-based file identification (hash/checksum)
- Cross-source duplicate detection
- Global deduplication (beyond path-based known-items tracking)
- Optional hash storage in baseline index (complements Slice 7)

**Note**: Currently, known-items tracking is path-based and source-scoped. Hashing enables content-based deduplication across sources, detecting duplicates even when files have different paths or names.

**Dependency**: Can leverage Slice 7 baseline index for hash storage, but is independent in functionality. Slice 8 improves deduplication capabilities beyond current path-based detection.

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

**Current State**: Implemented (Slice 6)

**What Works Today**:
- `library adopt <path> [--dry-run] [--yes]` command for adopting existing library directories
- Adoption creates only `.mediahub/` metadata without modifying existing media files
- Baseline scan of existing media files establishes "known items" for future detection
- Dry-run preview mode for adoption operations
- Explicit confirmation prompts (with `--yes` bypass for scripting)
- Idempotent adoption (safe re-runs on already adopted libraries)
- Opening existing MediaHub libraries (with `.mediahub/library.json`)
- Legacy library adoption (MediaVault pattern detection)
- Importing into libraries that already contain media files (collision handling)
- Incremental imports: after adoption, `detect` and `import` commands work normally and only add new items

**What's Next**:
- Slice 7: Performance optimization with baseline index for very large libraries
- Slice 8: Advanced hashing and cross-source deduplication

---

## Analysis Reports

### Library Adoption Analysis (2026-01-27)
**Document**: `specs/archive/RAPPORT_ADOPTION_LIBRAIRIE.md`

**Key Findings** (historical reference):
- ✅ Core architecture is compatible with library adoption
- ✅ `LibraryContentQuery` scans all existing media files (baseline works)
- ✅ Import system is idempotent and safe (handles existing files correctly)
- ✅ Gap resolved: `library adopt` command implemented in Slice 6
- ✅ Implementation: Minimal addition approach without core changes

**Status**: Analysis completed and implementation delivered in Slice 6.

---

## Out of Scope (Current)

- Photos.app or device-specific integrations
- User interface / media browsing
- Advanced duplicate detection (hashing, fuzzy matching) — planned for Slice 8
- Metadata enrichment (tags, faces, albums)
- Pipelines, automation, or scheduling
- Cloud sync or backup features

---

## Notes

- All completed slices are frozen and covered by automated validation
- Constitution (`CONSTITUTION.md`) remains the supreme normative document
- Individual slice specifications in `specs/` are authoritative for their scope
- This status document is for tracking only, not normative

---

**Last Updated**: 2026-01-27  
**Next Review**: After Slice 7 or after real-world usage
