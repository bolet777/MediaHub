# Feature Specification: Hash Coverage & Maintenance

**Feature Branch**: `009-hash-coverage-maintenance`  
**Created**: 2026-01-27  
**Status**: Ready for Plan  
**Input**: User description: "Enable users to compute, track, and maintain hash coverage for existing MediaHub libraries in a SAFE, deterministic, and idempotent way."

## Problem Statement

MediaHub libraries created before Slice 8 (Advanced Hashing & Deduplication) or adopted without `--with-hashes` contain media files without content hashes in the baseline index. Additionally, libraries may have partial hash coverage due to:
- Files imported before hash computation was implemented
- Hash computation failures during import (non-fatal errors)
- Manual file additions outside MediaHub workflows

Without complete hash coverage, hash-based duplicate detection (Slice 8) cannot function optimally. Users need a safe, deterministic way to compute missing hashes for existing library media without rescanning or rewriting everything.

## Goals

1. **Enable hash computation for existing libraries**: Provide a CLI command to compute missing content hashes for media files already in the library
2. **Improve hash coverage incrementally**: Allow users to improve hash coverage over time without rescanning or rewriting everything
3. **Maintain safety guarantees**: Zero risk of data loss or file modification; explicit confirmation for write operations
4. **Ensure determinism**: Same library state produces same hash computation results
5. **Guarantee idempotence**: Re-running produces no changes once coverage is complete
6. **Support batch and incremental operation**: Safe to interrupt and re-run; no duplicate work
7. **Integrate with status reporting**: Display hash coverage statistics in `status` command output

## Non-Goals

- **No duplicate deletion or merging**: This slice does not remove or merge duplicate files
- **No automatic cleanup**: This slice does not automatically modify or reorganize media files
- **No UI work**: This slice is Core / CLI only
- **No performance refactors**: No changes to existing performance characteristics unless strictly required by the spec
- **No breaking changes to existing slices**: Slices 1-8 behavior remains unchanged (output additions are allowed)

## User-Facing CLI Contract

### Command Syntax

```
mediahub index hash [--dry-run] [--limit N] [--yes]
```

### Command Description

Computes missing content hashes (SHA-256) for media files in the library and updates the baseline index. Only processes files that do not already have hash values in the index.

### Flags

- `--dry-run`: Enumerate candidates and statistics only; do not compute hashes. Performs zero writes.
- `--limit N`: Process at most N files (useful for incremental operation or testing). If not specified, processes all files missing hashes.
- `--yes`: Bypass confirmation prompt for non-interactive execution. Required when not in dry-run mode and not in an interactive terminal.

Note: The `--json` flag is a pre-existing global output mode supported by MediaHubCLI commands. Slice 9 supports JSON output for the `index hash` command using the same pattern as other commands.

### Behavior

1. **Library validation**: Validates that the specified path is a valid MediaHub library (contains `.mediahub/library.json`)
2. **Index loading**: Loads the baseline index (v1.0 or v1.1). If index is missing or invalid, reports error and exits
3. **Candidate selection**: Loads baseline index and selects entries missing hash values; for each entry, validates the referenced file path exists before hashing
4. **Hash computation**: Computes SHA-256 hashes for files missing hashes (respects `--limit` if specified)
5. **Index update**: Updates baseline index with computed hashes (atomic write, only if not `--dry-run`)
6. **Progress reporting**: Displays progress during hash computation (file count, current file, estimated time)
7. **Result reporting**: Displays summary of files processed, hashes computed, and updated coverage statistics

### Exit Codes

- `0`: Success (including dry-run preview, idempotent no-op, and user cancellation)
- `1`: Error (library not found, index invalid, I/O error, etc.)

### Error Conditions

- Library path does not exist or is not a valid MediaHub library (library path is determined via existing MediaHubCLI library resolution mechanism)
- Baseline index is missing or invalid (corrupted, unsupported version)
- Insufficient permissions to read library files or write index
- I/O errors during file reading or hash computation
- Index write failure (atomic write failed)
- Non-interactive execution without `--yes` flag (when not in dry-run mode)

## Safety Guarantees and Constraints

### Write Safety

- **Dry-run mode**: `--dry-run` performs zero writes to the baseline index and does not compute hashes. Only enumerates candidates and statistics.
- **Atomic index updates**: Index updates use the same atomic write-then-rename pattern as existing index operations (Slice 7, Slice 8)
- **Read-only file access**: Hash computation reads library media files only; never modifies, moves, renames, or deletes media files
- **Explicit confirmation**: Non-dry-run operations require explicit confirmation (or `--yes` flag) before writing to the index

### Interruption Safety

- **Safe to interrupt**: Operation can be safely interrupted (Ctrl+C) at any time. Partial progress is not persisted; re-running resumes from the beginning.
- **No partial state**: Index updates are atomic; interrupted operations do not leave the index in a partially updated state
- **Idempotent re-runs**: Re-running the command after interruption produces the same results as if it had completed successfully

### Data Integrity

- **No file modification**: Media files are never modified, moved, renamed, or deleted
- **Index validation**: Index is validated before and after updates to ensure integrity
- **Hash verification**: Hash computation uses the same SHA-256 algorithm as Slice 8; deterministic and verified

## Determinism and Idempotence Rules

### Deterministic Behavior

1. **Stable file ordering**: Files are processed in a deterministic order (e.g., sorted by normalized path)
2. **Consistent hash computation**: Same file content always produces the same hash (SHA-256)
3. **Predictable results**: Same library state (same files, same index state) produces the same hash computation results
4. **Reproducible output**: Same inputs produce the same output format and statistics

### Idempotence Rules

1. **No duplicate work**: Files that already have hash values in the index are skipped
2. **Re-run safety**: Re-running the command on a library with complete hash coverage produces no changes (no-op)
3. **Incremental progress**: Partial runs (with `--limit`) can be safely re-run; subsequent runs process remaining files
4. **Consistent state**: After successful completion, re-running produces identical results (same files processed, same hashes computed)

## Expected Outputs

### Human-Readable Output

**Dry-run mode**:
```
Hash Coverage Preview
====================

Library: /path/to/library
Index version: 1.1
Current coverage: 45% (4,500 / 10,000 entries)

DRY-RUN: Would compute hashes for 5,500 files
  Files to process: 5,500

No hashes will be computed. No changes will be made to the index.
```

**Normal mode (with confirmation)**:
```
Hash Coverage Update
====================

Library: /path/to/library
Index version: 1.1
Current coverage: 45% (4,500 / 10,000 entries)

Will compute hashes for 5,500 files.
This will update the baseline index.

Proceed? (yes/no): 
```

**Normal mode (execution)**:
```
Hash Coverage Update
====================

Library: /path/to/library
Index version: 1.1
Current coverage: 45% (4,500 / 10,000 entries)

Computing hashes...
  [████████████████████] 100% (5,500 / 5,500 files)
  Current: 2024/01/IMG_1234.jpg

Completed:
  Files processed: 5,500
  Hashes computed: 5,500
  Updated coverage: 100% (10,000 / 10,000 entries)
  Index updated: .mediahub/registry/index.json
```

**Idempotent no-op**:
```
Hash Coverage Update
====================

Library: /path/to/library
Index version: 1.1
Current coverage: 100% (10,000 / 10,000 entries)

All files already have hash values.
No computation needed.

Completed:
  Files processed: 0
  Hashes computed: 0
  Coverage unchanged: 100% (10,000 / 10,000 entries)
```

### JSON Output

**Dry-run mode** (using pre-existing `--json` flag with `--dry-run`):
```json
{
  "dryRun": true,
  "library": {
    "path": "/path/to/library",
    "indexVersion": "1.1"
  },
  "coverage": {
    "current": {
      "percentage": 0.45,
      "entriesWithHash": 4500,
      "totalEntries": 10000
    },
    "wouldUpdate": {
      "filesToProcess": 5500,
      "estimatedNewCoverage": {
        "percentage": 1.0,
        "entriesWithHash": 10000,
        "totalEntries": 10000
      }
    }
  },
  "summary": {
    "filesProcessed": 0,
    "hashesComputed": 0,
    "indexUpdated": false
  }
}
```

**Normal mode** (using pre-existing `--json` flag):
```json
{
  "dryRun": false,
  "library": {
    "path": "/path/to/library",
    "indexVersion": "1.1"
  },
  "coverage": {
    "before": {
      "percentage": 0.45,
      "entriesWithHash": 4500,
      "totalEntries": 10000
    },
    "after": {
      "percentage": 1.0,
      "entriesWithHash": 10000,
      "totalEntries": 10000
    }
  },
  "summary": {
    "filesProcessed": 5500,
    "hashesComputed": 5500,
    "indexUpdated": true,
    "indexPath": ".mediahub/registry/index.json"
  }
}
```

**Idempotent no-op** (using pre-existing `--json` flag):
```json
{
  "dryRun": false,
  "library": {
    "path": "/path/to/library",
    "indexVersion": "1.1"
  },
  "coverage": {
    "before": {
      "percentage": 1.0,
      "entriesWithHash": 10000,
      "totalEntries": 10000
    },
    "after": {
      "percentage": 1.0,
      "entriesWithHash": 10000,
      "totalEntries": 10000
    }
  },
  "summary": {
    "filesProcessed": 0,
    "hashesComputed": 0,
    "indexUpdated": false,
    "reason": "all_files_already_have_hashes"
  }
}
```

## Integration with Status Command

The `status` command (Slice 4) MUST be extended to report hash coverage statistics:

### Human-Readable Output Addition

```
Library Status
==============

Path: /path/to/library
ID: abc123...
Version: 1.0
Sources: 2

Hash Coverage: 45% (4,500 / 10,000 entries)

Attached sources:
  ...
```

### JSON Output Addition

```json
{
  "path": "/path/to/library",
  "identifier": "abc123...",
  "version": "1.0",
  "sourceCount": 2,
  "hashCoverage": {
    "percentage": 0.45,
    "entriesWithHash": 4500,
    "totalEntries": 10000
  },
  "sources": [...]
}
```

## Edge Cases and Failure Modes

### Edge Cases

1. **Empty library**: Library with no index entries → reports 0% coverage (0/0), no-op
2. **Complete coverage**: All files already have hashes → idempotent no-op, reports 100% coverage
3. **Partial coverage with limit**: `--limit 100` on library with 1000 missing hashes → processes 100 files, reports updated coverage
4. **Interrupted operation**: User interrupts (Ctrl+C) during hash computation → no index update, safe to re-run
5. **File missing during computation**: File listed in index but missing from filesystem → reports error for that file, continues with remaining files
6. **Index becomes invalid during operation**: Index file corrupted or deleted during operation → reports error, exits without partial update
7. **Permission denied**: Cannot read a media file → reports error for that file, continues with remaining files
8. **Very large files**: Files >10GB → hash computation uses streaming (constant memory), may take longer but completes successfully
9. **Symlinks**: Symlinks to media files → resolved to actual file, hash computed for target file
10. **Non-media files**: Index entries referencing files not recognized as media → skipped (only processes entries referencing files matching media detection criteria from Slice 2)

### Failure Modes

1. **Library not found**: Invalid path or not a MediaHub library → error message, exit code 1
2. **Index missing or invalid**: Index file missing, corrupted, or unsupported version → error message, exit code 1
3. **Insufficient permissions**: Cannot read library files or write index → error message, exit code 1
4. **I/O errors**: Disk errors, network filesystem issues → error message for affected files, continues with remaining files (non-fatal), or exits if index write fails (fatal)
5. **Index write failure**: Atomic write fails (disk full, permission denied) → error message, exit code 1, no partial update
6. **Non-interactive without --yes**: TTY not available and `--yes` not provided → error message instructing use of `--yes`, exit code 1

## Success Criteria

1. **Functional completeness**: Command successfully computes missing hashes for existing library media files
2. **Safety compliance**: Zero risk of data loss; all safety guarantees met (dry-run with zero hash computation, atomic writes, explicit confirmation)
3. **Determinism**: Same library state produces same results; stable ordering and consistent hash computation
4. **Idempotence**: Re-running produces no changes once coverage is complete; no duplicate work; existing hash values are never overwritten
5. **Integration**: Status command reports hash coverage statistics (human-readable and JSON)
6. **Error handling**: All edge cases and failure modes handled gracefully with clear error messages
7. **Backward compatibility**: Works with v1.0 indexes (no hashes) and v1.1 indexes (partial hashes); no breaking changes to existing functionality

## Boundaries with Other Slices

### Slice 8 (Advanced Hashing & Deduplication)

- **Uses**: Baseline Index v1.1 structure (optional hash field), SHA-256 hash computation algorithm, atomic index write pattern
- **Does not modify**: Slice 8's import-time hash computation, detection-time hash computation, or duplicate detection logic
- **Complements**: Provides hash computation for files imported before Slice 8 or without hashes

### Slice 9b (Duplicate Reporting & Audit) - Future

- **Prepares**: Complete hash coverage enables comprehensive duplicate reporting in Slice 9b
- **Does not implement**: Duplicate reporting, duplicate grouping, or export functionality (deferred to Slice 9b)

### Slice 9c (Performance & Scale Guardrails) - Future

- **May inform**: Hash computation performance characteristics may inform scale guardrails in Slice 9c
- **Does not implement**: Performance benchmarks, regression guardrails, or operational limits (deferred to Slice 9c)

### Slices 1-7 (Core Functionality)

- **Does not modify**: Existing library, source, detection, import, or index functionality
- **Uses**: Library validation (Slice 1), baseline index structure (Slice 7), media file detection (Slice 2)

## Non-normative Notes (Informative)

The following notes provide implementation guidance but do not introduce new requirements. All hard constraints are specified in the normative sections above.

### Hash Computation

Hash computation uses SHA-256 algorithm (same as Slice 8). For large files, streaming hash computation maintains constant memory usage. Files are processed in deterministic order (e.g., sorted by normalized path) as specified in the Determinism section.

### Index Updates

Index updates use atomic write-then-rename pattern (same as Slice 7, Slice 8). Only entries missing hash values are updated, and existing hash values are preserved (never overwritten) as specified in the Safety Guarantees section. Index version is maintained (v1.0 → v1.1 if hashes added, v1.1 → v1.1 if already v1.1).

### Progress Reporting

Progress reporting displays file count progress (X / Y files) and shows current file being processed. Time estimation is optional and may be omitted for very fast operations.

### Candidate Selection

Candidate selection loads the baseline index and identifies entries missing hash values. For each candidate entry, the referenced file path is validated to exist before hashing. Files not in the index (orphaned files) are not processed.
