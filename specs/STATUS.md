# MediaHub Project Status

**Document Type**: Project Status & Roadmap Tracking  
**Purpose**: Memory of project state, decisions, and planned slices  
**Last Updated**: 2026-01-27  
**Next Review**: After Slice 13 planning or after real-world usage  
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

### ✅ Slice 10 — Source Media Types + Library Statistics
**Status**: Complete and validated (2026-01-15)  
**Spec**: `specs/010-source-media-types-library-statistics/spec.md`  
**Validation**: `specs/010-source-media-types-library-statistics/validation.md`

**Deliverables**:
- Source media type filtering: `--media-types` flag for `source attach` (images, videos, both)
- Media type filtering at scan stage: Filtering occurs during source scanning, affecting both `detect` and `import` operations
- Backward compatibility: Existing Sources without `mediaTypes` field default to "both" behavior
- Library statistics computation: Total items, distribution by year, and distribution by media type from BaselineIndex
- Status command integration: Statistics displayed in `mediahub status` output (human-readable and JSON)
- Source list integration: Media types displayed in `mediahub source list` output (human-readable and JSON)
- JSON output conventions: Statistics field omitted when BaselineIndex unavailable (matches `hashCoverage` pattern)
- Single source of truth: Media type classification uses `MediaFileFormat` component (no duplication)

**Note**: Validation required minor command adaptations (`detect` and `import` require `<source-id>` argument); `validation.md` was updated accordingly.

### ✅ Slice 9b — Duplicate Reporting & Audit
**Status**: Complete and validated (2026-01-15)  
**Spec**: `specs/009b-duplicate-reporting-audit/spec.md`  
**Validation**: `specs/009b-duplicate-reporting-audit/validation.md`

**Deliverables**:
- `mediahub duplicates` command for duplicate file reporting by content hash
- Multiple output formats: text (human-readable), JSON (machine-readable), CSV (spreadsheet analysis)
- Deterministic ordering: groups sorted by hash lexicographically, files sorted by path lexicographically
- Read-only operations: zero writes to library or index, only writes to user-specified output file
- Fail-fast validation: output path validation before processing, clear error messages for invalid indexes
- Edge case handling: nil hashes skipped silently, empty reports supported, unwritable paths fail early
- CLI integration: `--format` option (text/json/csv), `--output` option for file output, minimal stdout feedback when writing to file

### ✅ Slice 9c — Performance & Scale Observability
**Status**: Complete and validated (2026-01-16)  
**Spec**: `specs/009c-performance-scale-guardrails/spec.md`  
**Validation**: `specs/009c-performance-scale-guardrails/validation.md`

**Deliverables**:
- Performance measurement for `mediahub status`, `mediahub index hash`, and `mediahub duplicates` commands
- Scale metrics reporting: file count, total size bytes, hash coverage percent (deterministic)
- Duration measurement (informational, may vary)
- Human-readable Performance section appended to command outputs
- JSON `performance` object (additive, optional) with `durationSeconds` and `scale` metrics
- Read-only operations: no index or filesystem mutations during measurement
- Deterministic scale metrics: identical values across multiple runs for same library state
- Graceful degradation: Performance section shows "N/A" when baseline index is missing/invalid

### ✅ Slice 11 — UI Shell v1 + Library Discovery
**Status**: Complete, validated, and FROZEN (2026-01-16)  
**Spec**: `specs/011-ui-shell-v1-library-discovery/`  
**Validation**: `specs/011-ui-shell-v1-library-discovery/validation.md`

**Deliverables**:
- SwiftPM MediaHubUI app shell (SwiftUI macOS application)
- Folder-based discovery (read-only, deterministic order)
- Open library via Core + StatusView (baseline/hash/items/last scan)
- Error handling + moved/deleted detection

#### Follow-ups / Watchlist (non-blocking)

- **[FOLLOW-UP] JSON explicitness for mediaTypes**: Decide if public JSON should always include `mediaTypes` explicitly vs omit when nil (persistence can omit). Currently: `source list`/`status` JSON always include `mediaTypes` via wrapper; confirm consistency across all JSON surfaces. *Suggested location: Future JSON schema review or Slice 11+ (UI integration)*

- **[DECISION] Invalid stored mediaTypes handling**: Current choice: enum decode error (Option 2). Consider whether a future UX improvement should wrap `DecodingError` with a user-facing message and remediation steps, or fallback-to-both policy. *Suggested location: Future error handling enhancement or Slice 11+ (UI error display)*

- **[VERIFY] Scan classification helpers duplication**: Ensure scan + stats reuse the same helper/classification path (`MediaFileFormat`). Avoid parallel logic. *Suggested location: Code review or future refactoring pass*

- **[FOLLOW-UP] Micro-perf: ISO8601DateFormatter allocation**: Consider static/shared formatter if performance ever matters (non-urgent). *Suggested location: Performance optimization pass (Slice 9c or future)*

- **[FOLLOW-UP] Source metadata updates copying fields manually**: `updateSourceLastDetected` copies fields; consider safer update strategy if `Source` grows (e.g., copy + override pattern), to avoid future omissions. *Suggested location: Future refactoring when `Source` structure evolves*

- **[VERIFY] Year extraction robustness**: Currently derived from first path component (YYYY). Confirm `BaselineIndexEntry.path` is normalized relative path; if absolute paths appear, consider deriving year from a date field (if present) or keep "unknown" bucket. *Suggested location: BaselineIndex validation or future path normalization review*

- **[VERIFY] StatusCommandTests file hygiene**: Confirm no accidental duplication/rename occurred when adding `StatusCommandTests` (tests pass, but keep an eye on structure). *Suggested location: Code review or test structure audit*

### ✅ Slice 12 — UI Create / Adopt Wizard v1
**Status**: Complete (2026-01-27)  
**Spec**: `specs/012-ui-create-adopt-wizard-v1/`  
**Plan**: `specs/012-ui-create-adopt-wizard-v1/plan.md`  
**Tasks**: `specs/012-ui-create-adopt-wizard-v1/tasks.md`

**Deliverables**:
- Unified wizard for library creation and adoption
- Path selection with folder picker and validation
- Preview operations (dry-run) for both create and adopt
- Explicit confirmation dialogs before execution
- Create library wizard with preview and execution
- Adopt library wizard with preview and execution
- Integration with ContentView (entry points and completion handling)
- Error mapping to user-facing messages

**Note**: 34 implementation tasks completed. 8 manual verification tasks pending (T-025 through T-031, T-036 through T-038).

### ✅ Slice 13 — UI Sources + Detect + Import (P1)
**Status**: Complete / Frozen (2026-01-27)  
**Spec**: `specs/013-ui-sources-detect-import-p1/`  
**Plan**: `specs/013-ui-sources-detect-import-p1/plan.md`  
**Tasks**: `specs/013-ui-sources-detect-import-p1/tasks.md`

**Deliverables**:
- Source management (attach/detach with media types)
- Detection preview and run workflows
- Import preview, confirmation, and execution workflows
- SourceListView with context menu actions
- DetectionPreviewView, DetectionRunView
- ImportPreviewView, ImportConfirmationView, ImportExecutionView
- State management (SourceState, DetectionState, ImportState)
- Orchestrators (SourceOrchestrator, DetectionOrchestrator, ImportOrchestrator)
- End-to-end UI flow from source list to import execution

**Note**: P1 complete (28 tasks). Optional UI integration tasks (T-029, T-030, T-031) moved to Slice 13b.

---

## Planned Slices

| Slice | Title | Goal | Pillar | Depends on | Track | Status |
|-------|-------|------|--------|------------|-------|--------|
| 12 | UI Create / Adopt Wizard v1 | Unified wizard for library creation and adoption with preview dry-run and explicit confirmation | User Experience & Safety | Slice 1, Slice 6 | UI | Complete |
| 13 | UI Sources + Detect + Import (P1) | Source management (attach/detach with media types), detect preview/run, and import preview/confirm/run workflows | User Experience & Safety | Slice 2, Slice 3, Slice 10 | UI | Complete / Frozen |
| 13b | UI Integration & UX Polish | Integrate source/detection/import workflows with library view and source list (optional UX polish) | User Experience & Safety | Slice 13 | UI | Planned (optional) |
| 14 | Progress + Cancel API minimale | Add progress reporting and cancellation support to core operations (detect, import, hash) | Reliability & Maintainability | None | Core / CLI | Proposed |
| 15 | UI Operations UX (progress / cancel) | Progress bars, step indicators, and cancellation UI for detect/import/hash operations | User Experience & Safety | Slice 14 | UI | Proposed |
| 16 | UI Hash Maintenance + Coverage | Hash maintenance UI (batch/limit operations) and coverage insights with duplicate detection (read-only) | User Experience & Safety | Slice 9, Slice 14 | UI | Proposed |
| 17 | History / Audit UX + Export Center | Operation timeline (detect/import/maintenance), run details, and export capabilities (JSON/CSV/TXT) | User Experience & Safety, Transparency & Interoperability | Slice 14, Slice 9b | UI | Proposed |
| 18 | macOS Permissions + Distribution Hardening | Sandbox strategy, notarization, security-scoped bookmarks, and distribution hardening | Reliability & Maintainability | Slice 11+ | UI / Core | Proposed |

### Desktop App Track (Macro)

The desktop application (UI slices 11–18) orchestrates existing CLI workflows (library, sources, detect, import, status)
but does not introduce new business logic. UI slices are tracked in the Planned Slices table above.

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
