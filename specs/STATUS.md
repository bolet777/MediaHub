# MediaHub Project Status

**Document Type**: Project Status & Roadmap Tracking  
**Purpose**: Memory of project state, decisions, and planned slices  
**Last Updated**: 2026-01-27  
**Next Review**: After Slice 9 or after real-world usage  
**Note**: This is a tracking document, not a normative specification. For authoritative specs, see individual slice specifications in `specs/`.

---

## Macro Roadmap

**North Star**: MediaHub provides a reliable, transparent, and scalable media library system that replaces Photos.app for users who need filesystem-first control, deterministic workflows, and long-term maintainability.

See README.md for the authoritative North Star and product vision; STATUS.md focuses on execution and slice-level tracking.

**Pillars**:
1. **Reliability & Maintainability**: CLI-first architecture with deterministic behavior, comprehensive testing, and clear operational boundaries
2. **Transparency & Interoperability**: Filesystem-first storage that remains accessible to external tools without proprietary containers or lock-in
3. **Scalability & Performance**: Support for large libraries, multiple libraries, and long-term usage without degradation
4. **Content Integrity & Deduplication**: Hash-based duplicate detection and content verification to ensure data safety and prevent accidental duplication
5. **User Experience & Safety**: Simple workflows with explicit confirmations, dry-run previews, and auditable operations

**Current Focus**: CLI-first reliability & maintainability

The CLI is treated as the backend and source of truth for a future macOS desktop application.

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

### ✅ Slice 7 — Baseline Index
**Status**: Complete and validated (2026-01-14)  
**Spec**: `specs/007-baseline-index/`  
**Validation**: `specs/007-baseline-index/validation.md`

**Deliverables**:
- Baseline index persistant `.mediahub/registry/index.json` (v1.0)
- `detect` read-only: utilise l'index si valide, fallback sinon (raison reportée)
- `import` update incrémental atomique, dry-run = 0 write, update seulement si index valide au début

### ✅ Slice 8 — Advanced Hashing & Deduplication
**Status**: Complete and validated (2026-01-14)  
**Spec**: `specs/008-advanced-hashing-dedup/spec.md`

**Deliverables**:
- Baseline Index v1.1: Optional hash field in IndexEntry with backward compatibility (v1.0 indexes decode without changes)
- Content-based duplicate detection using SHA-256 hashing
- Import pipeline: Computes and stores content hashes for imported destination files only
- Detection pipeline: Computes source file hashes and compares against library hashSet to detect duplicates by content (read-only, no index writes)
- CLI output: Human-readable and JSON output include duplicate metadata (hash, library path, reason) and hash coverage statistics
- Cross-source duplicate detection: Detects duplicates even when files have different paths or names

### ✅ Slice 9 — Hash Coverage & Maintenance
**Status**: Complete and validated (2026-01-27)  
**Spec**: `specs/009-hash-coverage-maintenance/spec.md`  
**Validation**: `specs/009-hash-coverage-maintenance/validation.md`

**Deliverables**:
- `mediahub index hash [--dry-run] [--limit N] [--yes] [--json]` command
- Index-driven candidate selection: Loads baseline index and selects entries missing hash values
- SHA-256 hash computation for existing library media files (using existing `ContentHasher` from Slice 8)
- Atomic index updates: Updates baseline index with computed hashes using write-then-rename pattern
- Dry-run mode: Enumerates candidates and statistics only; zero hash computation, zero writes
- Explicit confirmation for non-dry-run operations (or `--yes` flag for non-interactive execution)
- Deterministic and idempotent behavior: Same library state produces same results; existing hashes never overwritten
- `--limit` support: Process first N candidates in deterministic order for incremental operation
- Status command integration: Hash coverage statistics reporting (human-readable and JSON)
- Backward compatible: Works with v1.0 indexes (no hashes) and v1.1 indexes (partial hashes)

---

## Planned Slices

| Slice | Title | Goal | Pillar | Depends on | Track | Status |
|-------|-------|------|--------|------------|-------|--------|
| 9b | Duplicate Reporting & Audit | Provide comprehensive duplicate reporting and audit capabilities to help users understand duplicate content across sources and libraries | Content Integrity & Deduplication | Slice 8, Slice 9 | Core / CLI | Proposed |
| 9c | Performance & Scale Guardrails | Establish performance benchmarks, scale testing, and guardrails to ensure MediaHub maintains acceptable performance as libraries grow | Scalability & Performance | Slice 8 | Core / CLI | Proposed |
| 10 | Source Media Types + Library Statistics | Add source media type filtering (images/videos/both) and library statistics (total, by year, by type) via BaselineIndex | User Experience & Safety | Slice 7, Slice 9 | Core / CLI | Proposed |
| 11 | UI Shell v1 + Library Discovery | Basic SwiftUI app with home screen, sidebar libraries, and library discovery/selection | User Experience & Safety | Slice 1 | UI | Proposed |
| 12 | UI Create / Adopt Wizard v1 | Unified wizard for library creation and adoption with preview dry-run and explicit confirmation | User Experience & Safety | Slice 1, Slice 6 | UI | Proposed |
| 13 | UI Sources + Detect + Import (P1) | Source management (attach/detach with media types), detect preview/run, and import preview/confirm/run workflows | User Experience & Safety | Slice 2, Slice 3, Slice 10 | UI | Proposed |
| 14 | Progress + Cancel API minimale | Add progress reporting and cancellation support to core operations (detect, import, hash) | Reliability & Maintainability | None | Core / CLI | Proposed |
| 15 | UI Operations UX (progress / cancel) | Progress bars, step indicators, and cancellation UI for detect/import/hash operations | User Experience & Safety | Slice 14 | UI | Proposed |
| 16 | UI Hash Maintenance + Coverage | Hash maintenance UI (batch/limit operations) and coverage insights with duplicate detection (read-only) | User Experience & Safety | Slice 9, Slice 14 | UI | Proposed |
| 17 | History / Audit UX + Export Center | Operation timeline (detect/import/maintenance), run details, and export capabilities (JSON/CSV/TXT) | User Experience & Safety, Transparency & Interoperability | Slice 14, Slice 9b | UI | Proposed |
| 18 | macOS Permissions + Distribution Hardening | Sandbox strategy, notarization, security-scoped bookmarks, and distribution hardening | Reliability & Maintainability | Slice 11+ | UI / Core | Proposed |

### Desktop App Track (Macro)

The desktop application is treated as a separate macro track.
It orchestrates existing CLI workflows (library, sources, detect, import, status)
but does not introduce new business logic.

Desktop UI slices will be tracked separately once the CLI backend is considered
functionally complete and stable.

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
- Future slices: Additional features and enhancements

---

## Analysis Reports

### Library Adoption Analysis (2026-01-13)
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
- UI-driven business logic (the desktop UI is planned; business logic remains in core/CLI)
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
**Next Review**: After real-world usage or next planned slice
