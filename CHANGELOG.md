# Changelog

All notable changes to MediaHub are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Slice 13b] - 2026-01-27

### What: UI Integration & UX Polish

**Feature**: Integration of source management, detection, and import workflows into the main library view for improved UX cohesion.

**Changes**:
- Source list integrated into library detail view (below StatusView)
- Source management actions (attach/detach) accessible directly from library view
- Detection actions (preview/run) accessible from source list context menu
- Import actions accessible from detection results
- Library status automatically refreshes after import operations
- All workflows accessible from integrated locations in main library interface

**Why**: Improves user experience by making all source/detection/import workflows accessible from the main library view, eliminating the need to navigate through separate interfaces. This provides a more cohesive and intuitive workflow.

**Safety**:
- **No new functionality**: All functionality already exists in Slice 13; this slice only integrates it
- **No Core API changes**: Uses existing Core APIs from Slice 13
- **State synchronization**: Source list and library status refresh automatically after operations
- **Backward compatible**: Works with all libraries created/adopted by slices 1-13

**Technical Details**:
- SourceState shared between ContentView and SourceListView for state synchronization
- DetectionState and ImportState managed within SourceListView and DetectionRunView respectively
- Completion callbacks wired through view hierarchy for library status refresh
- All existing views from Slice 13 reused without modification

**Files Modified**:
- `Sources/MediaHubUI/ContentView.swift` (added SourceState, source list section, import completion handler)
- `Sources/MediaHubUI/SourceListView.swift` (accepts external SourceState, added attach/detach sheets, detection actions)
- `Sources/MediaHubUI/AttachSourceView.swift` (changed from @Binding to @ObservedObject for SourceState)
- `Sources/MediaHubUI/DetectionRunView.swift` (added internal ImportState, import completion callback)
- `Sources/MediaHubUI/ImportPreviewView.swift` (added import completion callback parameter)

**Files Added**:
- `specs/013b-ui-integration-ux-polish/` (specification, plan, tasks, validation)

**Post-Freeze Fixes (SAFE PASS)**:
- **13b-A**: Fixed ImportExecutionView sheet dismissal bug - removed premature `previewResult = nil` before presenting execution sheet, added deterministic cleanup in `onDone` closure
- **13b-B**: Fixed DetectionRun → ImportPreview transition - added `@MainActor` to `previewImport()` to ensure proper sheet state sequencing, dismiss DetectionRun sheet before presenting ImportPreview
- **13b-C**: Verified AttachSourceView sourceState wiring - confirmed `@ObservedObject` usage and correct call site parameter passing

---

## [Slice 8] - 2026-01-14

### What: Advanced Hashing & Deduplication

**Feature**: Content-based duplicate detection using SHA-256 hashing, extending the baseline index to support hash storage and enabling cross-source duplicate detection.

**Changes**:
- Baseline Index v1.1: Optional hash field in IndexEntry with backward compatibility (v1.0 indexes decode without changes)
- Import pipeline: Computes and stores content hashes for imported destination files only (read-only on sources)
- Detection pipeline: Computes source file hashes and compares against library hashSet to detect duplicates by content (read-only, no index writes)
- CLI output: Human-readable and JSON output include duplicate metadata (hash, library path, reason) and hash coverage statistics
- Cross-source duplicate detection: Detects duplicates even when files have different paths or names

**Why**: Enables content-based duplicate detection across sources, detecting duplicates even when files have different paths or names. This complements path-based known-items tracking with content-based deduplication.

**Safety**:
- **Backward compatible**: v1.0 indexes decode without changes (hash field optional)
- **Read-only detection**: `detect` never writes to index, only reads (hash computation is read-only)
- **Non-fatal hashing**: Hash computation failures don't block import/detect operations (hash omitted, operation continues)
- **Deterministic**: Same file content always produces same hash
- **Idempotent**: Same imported file -> same hash field in index
- **Dry-run safe**: `import --dry-run` performs zero hash computation and zero index writes

**Technical Details**:
- Hash format: SHA-256 in format "sha256:<64-char-hexdigest>"
- Streaming computation: Files read in 64KB chunks for constant memory usage
- Index version: Automatically set to "1.1" if any entry has hash, "1.0" otherwise
- Hash lookup: `hashSet` and `hashToAnyPath` computed properties for O(1) duplicate detection
- Duplicate metadata: `duplicateOfHash`, `duplicateOfLibraryPath`, `duplicateReason` in detection results
- JSON backward compatible: New fields are optional and omitted if nil

**Files Added**:
- `Sources/MediaHub/ContentHashing.swift` (SHA-256 streaming hash computation)
- `Tests/MediaHubTests/ContentHashingTests.swift` (hash computation tests)
- `specs/008-advanced-hashing-dedup/` (specification, plan, tasks)

**Files Modified**:
- `Sources/MediaHub/BaselineIndex.swift` (v1.1 support, hash lookup properties)
- `Sources/MediaHub/DetectionOrchestration.swift` (source hash computation and duplicate detection)
- `Sources/MediaHub/DetectionResult.swift` (duplicate metadata fields)
- `Sources/MediaHub/ImportExecution.swift` (hash computation after successful file copy)
- `Sources/MediaHubCLI/OutputFormatting.swift` (CLI output for duplicate metadata)
- `Tests/MediaHubTests/BaselineIndexTests.swift` (v1.1 tests)
- `Tests/MediaHubTests/ImportExecutionTests.swift` (hash storage tests)

---

## [Slice 7] - 2026-01-14

### What: Baseline Index

**Feature**: Persistent baseline index for fast library content queries on very large libraries (10,000+ files).

**Changes**:
- Added `.mediahub/registry/index.json` persistent index file (format v1.0)
- Index created automatically during `library adopt` (reuses baseline scan, no double scan)
- Index updated incrementally during `import` operations (atomic, batched updates)
- `detect` command uses index when valid, falls back to full scan if missing/invalid (read-only guarantee)
- Index metadata included in JSON output (`detect`, `import`, `adopt` results)

**Why**: Performance optimization for very large libraries. Without baseline index, every `detect` operation must scan all library files, which becomes prohibitively slow for libraries with 10,000+ files. The baseline index enables fast detection by providing a pre-computed list of library contents.

**Safety**:
- **Read-only guarantee**: `detect` never creates or modifies `index.json` (read-only operations)
- **Atomic writes**: Index updates use write-then-rename pattern (interruption-safe, no partial files)
- **Graceful degradation**: Operations succeed even if index is missing, corrupted, or invalid (fallback to full scan)
- **Dry-run compliance**: Dry-run operations perform zero writes to `index.json` (preview only)
- **Path validation**: Index file paths strictly validated (never write outside library root)
- **Idempotent**: Re-running `library adopt` preserves valid existing index (no overwrite)
- **No-touch rules**: All writes limited to `.mediahub/**` directory (no media file modifications)

**Technical Details**:
- Index format: JSON with normalized paths, file sizes, modification times (no content hashing in Slice 7)
- Deterministic encoding: Entries sorted by normalized path, stable JSON structure
- Incremental updates: Only updates index if valid at start of import (no creation during import)
- Fallback reporting: JSON output includes `indexUsed`/`indexFallbackReason` (detect), `indexUpdated`/`indexUpdateSkippedReason` (import)

**Files Added**:
- `Sources/MediaHub/BaselineIndex.swift` (core index implementation)
- `Tests/MediaHubTests/BaselineIndexTests.swift` (unit tests)
- `specs/007-baseline-index/` (specification, plan, tasks, validation)

**Files Modified**:
- `Sources/MediaHub/DetectionOrchestration.swift` (index integration, read-only)
- `Sources/MediaHub/DetectionResult.swift` (index metadata in results)
- `Sources/MediaHub/ImportExecution.swift` (incremental index updates)
- `Sources/MediaHub/ImportResult.swift` (index metadata in results)
- `Sources/MediaHub/LibraryAdoption.swift` (index creation during adoption)
- `Tests/MediaHubTests/DetectionOrchestrationTests.swift` (index integration tests)
- `Tests/MediaHubTests/ImportExecutionTests.swift` (index integration tests)
- `Tests/MediaHubTests/LibraryAdoptionTests.swift` (index integration tests)

---

## [Slice 6] - Previous Release

### Library Adoption

**Feature**: Adopt existing library directories organized in YYYY/MM without modifying media files.

**Changes**:
- `library adopt <path> [--dry-run] [--yes]` command
- Baseline scan of existing media files to establish "known items"
- Idempotent adoption (safe re-runs on already adopted libraries)

---

## [Slice 5] - Previous Release

### Safety Features & Dry-Run Operations

**Feature**: Safety-first operations with dry-run preview mode.

**Changes**:
- Dry-run mode for import operations (preview without copying)
- Explicit confirmation prompts for import operations
- Read-only guarantees for detection operations

---

## [Slice 4] - Previous Release

### CLI Tool & Packaging

**Feature**: Command-line interface executable.

**Changes**:
- Library management commands (`create`, `open`, `list`)
- Source management commands (`attach`, `list`)
- Detection command (`detect`)
- Import command (`import --all`)
- Status command (`status`)
- JSON output support (`--json`)

---

## [Slice 3] - Previous Release

### Import Execution & Media Organization

**Feature**: Real media import with deterministic organization.

**Changes**:
- Real media import (copy from Source to Library)
- Deterministic Year/Month (YYYY/MM) organization
- Collision handling (rename / skip / error)
- Atomic and interruption-safe import
- Known-items tracking to prevent re-imports

---

## [Slice 2] - Previous Release

### Sources & Import Detection

**Feature**: Folder-based Sources with read-only detection.

**Changes**:
- Folder-based Sources
- Read-only, deterministic detection of new media
- Explainable detection results
- Persistent Source–Library associations

---

## [Slice 1] - Previous Release

### Library Entity & Identity

**Feature**: Persistent, identifiable libraries on disk.

**Changes**:
- Persistent, identifiable libraries on disk
- Multiple independent libraries
- Validation, discovery, and identity persistence across moves/renames
- Legacy library adoption (MediaVault pattern detection)

---
