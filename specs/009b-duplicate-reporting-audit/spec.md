# Slice 9b — Duplicate Reporting & Audit

**Document Type**: Slice Specification
**Slice Number**: 9b
**Title**: Duplicate Reporting & Audit
**Author**: Spec-Kit Orchestrator
**Date**: 2026-01-15
**Status**: Draft

---

## Overview

**Goal**: Provide comprehensive duplicate reporting and audit capabilities to help users understand duplicate content across sources and libraries.

**Problem Statement**: After implementing content-based duplicate detection in Slice 8, users need visibility into what duplicates exist in their libraries and sources to make informed decisions about content management.

**Success Criteria**:
- Users can generate detailed duplicate reports for their libraries
- Reports are exportable in multiple formats for external analysis
- Reports include actionable metadata for duplicate resolution
- Operations are deterministic, idempotent, and safe (read-only)

**Scope**: Read-only duplicate analysis and reporting. No duplicate resolution or deletion capabilities.

---

## Requirements

### Core Functionality

**Duplicate Detection & Grouping**
- Identify all duplicate groups by content hash within a library
- Group duplicates by SHA-256 hash (established in Slice 8)
- Include library path, size, and timestamp information for each duplicate
- Detect duplicates across different paths but same content

**Duplicate Metadata**
- For each duplicate group: hash, file count, total size
- For each file in group: relative path, file size, creation timestamp

**Report Generation**
- Generate duplicate reports in multiple formats:
  - Human-readable text format (console output)
  - JSON format for programmatic consumption
  - CSV format for spreadsheet analysis

**CLI Integration**
- New command: `mediahub duplicates [--format json|csv|text] [--output <file>]`
- Uses the existing library selection mechanism (env/config or per-command option consistent with other commands)
- Support for multiple output formats
- Optional file output (defaults to stdout)

### Safety & Operational Requirements

**Read-Only Operations**
- All duplicate reporting is read-only (zero writes to library or index)
- No modification of library state or metadata
- Compatible with dry-run philosophy

**Deterministic Behavior**
- Same library state produces identical reports
- Reports are generated in deterministic order: duplicate groups sorted by content hash (ascending), files within each group sorted by relative path lexicographic ascending
- Timestamps are displayed metadata only and must NOT affect ordering

**Performance Considerations**
- Efficient duplicate detection using existing BaselineIndex hash data
- Memory-efficient processing for large libraries
- Reasonable performance for libraries with thousands of duplicates

**Edge Cases & Failure Modes**
- Baseline index missing/invalid: Graceful error message directing user to run library operations first
- Hash coverage incomplete (entries with nil hash): Skip entries without warning and continue processing
- No duplicates found: Generate empty report with clear "no duplicates" summary
- Output file path not writable: Fail with clear error message before processing
- Deterministic ordering guaranteed: Files within duplicate groups always sorted by relative path lexicographic ascending (primary ordering rule)
- Very large duplicate sets: Single pass over BaselineIndex entries to build an in-memory hash → files grouping, with memory usage proportional to duplicate set size

### Output Formats

**Text Format (Default)**
```
Duplicate Report for Library: My Photos
Generated: 2026-01-15 14:30:00

Found 3 duplicate groups containing 12 total files

Group 1: Hash a1b2c3d4... (3 files, 15.2 MB total)
  - 2023/12/photo1.jpg (5.1 MB) [2023-12-01 10:15:00]
  - 2024/01/backup/photo1.jpg (5.1 MB) [2023-12-01 10:15:00]
  - 2024/02/edited/photo1.jpg (5.0 MB) [2023-12-01 10:16:00]

Group 2: Hash e5f6g7h8... (5 files, 25.8 MB total)
  - 2022/08/vacation/img001.jpg (5.2 MB) [2022-08-15 16:20:00]
  - 2022/08/vacation/img001_copy.jpg (5.2 MB) [2022-08-15 16:20:00]
  - 2023/01/backup/vacation/img001.jpg (5.2 MB) [2022-08-15 16:20:00]
  - 2024/06/archive/img001.jpg (5.1 MB) [2022-08-15 16:21:00]
  - 2024/11/cleanup/img001.jpg (5.1 MB) [2022-08-15 16:21:00]

Summary:
- Total duplicate groups: 3
- Total duplicate files: 12
- Total space used by duplicates: 41.0 MB
- Potential space savings: ~27.3 MB (keep 1 copy per group)
```

**JSON Format**
```json
{
  "library": "My Photos",
  "generated": "2026-01-15T14:30:00Z",
  "summary": {
    "duplicateGroups": 3,
    "totalDuplicateFiles": 12,
    "totalDuplicateSizeBytes": 42949672,
    "potentialSavingsBytes": 28632646
  },
  "groups": [
    {
      "hash": "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6",
      "fileCount": 3,
      "totalSizeBytes": 15938355,
      "files": [
        {
          "path": "2023/12/photo1.jpg",
          "sizeBytes": 5346123,
          "timestamp": "2023-12-01T10:15:00Z"
        }
      ]
    }
  ]
}
```

**CSV Format**
```csv
group_hash,file_count,total_size_bytes,path,size_bytes,timestamp
a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6,3,15938355,2023/12/photo1.jpg,5346123,2023-12-01T10:15:00Z
a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6,3,15938355,2024/01/backup/photo1.jpg,5346123,2023-12-01T10:15:00Z
a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6,3,15938355,2024/02/edited/photo1.jpg,5297609,2023-12-01T10:16:00Z
```

---

## Dependencies

**Slice Dependencies**:
- Slice 8 (Advanced Hashing & Deduplication) - for content hash infrastructure
- Slice 9 (Hash Coverage & Maintenance) - for complete hash coverage in baseline index

**No External Dependencies**: This slice builds entirely on existing MediaHub infrastructure.

---

## Non-Goals / Out of Scope

**Duplicate Resolution**: This slice provides only reporting and audit capabilities. Actual duplicate resolution (deletion, consolidation) is out of scope.

**Cross-Library Duplicate Detection**: Reporting is limited to within a single library. Cross-library duplicate analysis is out of scope.

**Advanced Duplicate Classification**: No AI-powered "similar but not identical" detection. Only exact content matches by hash.

**Automated Actions**: No automatic duplicate handling or cleanup suggestions. Pure reporting only.

**Real-time Updates**: No continuous monitoring or background duplicate detection. Reports are generated on-demand.

---

## Success Metrics

**Functional Completeness**:
- ✅ Can identify all duplicate groups in a library
- ✅ Generates reports in text, JSON, and CSV formats
- ✅ Reports include all required metadata (paths, sizes, timestamps)
- ✅ CLI command integrates with existing MediaHub commands

**Safety & Reliability**:
- ✅ Read-only operations (zero writes)
- ✅ Deterministic output for same library state
- ✅ Handles edge cases (empty libraries, no duplicates, large libraries)

**Performance**:
- ✅ Reasonable execution time for typical libraries (< 30 seconds)
- ✅ Memory efficient for libraries with thousands of files
- ✅ Scales linearly with library size

**User Experience**:
- ✅ Clear, actionable reports
- ✅ Multiple output formats for different use cases
- ✅ Integrates naturally with existing CLI workflows

---

## Implementation Notes

**Architecture Alignment**: This slice extends the duplicate detection logic from Slice 8 into a dedicated reporting system while maintaining separation of concerns.

**Data Sources**: Leverages existing BaselineIndex (v1.1+) for hash data and file metadata.

**Error Handling**: Follows MediaHub patterns for user-friendly error messages and safe failure modes.

**Testing**: Comprehensive unit and integration tests covering all output formats and edge cases.

---

## Risk Assessment

**Low Risk**: This is a read-only reporting feature that builds on established infrastructure. No changes to core import/detection logic.

**Compatibility**: Requires BaselineIndex v1.1+ (with hash support). Graceful degradation for older indexes.

**Performance**: Duplicate grouping is computationally inexpensive compared to hash computation.

---

## Related Documents

- `specs/008-advanced-hashing-dedup/spec.md` - Foundation for content-based duplicate detection
- `specs/009-hash-coverage-maintenance/spec.md` - Hash coverage maintenance
- `CONSTITUTION.md` - Project principles and constraints
