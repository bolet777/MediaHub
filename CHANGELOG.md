# Changelog

All notable changes to MediaHub are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
