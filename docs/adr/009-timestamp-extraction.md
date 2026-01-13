# ADR 009: Timestamp Extraction Strategy

**Status**: Accepted  
**Date**: 2026-01-12  
**Component**: Timestamp Extraction & Resolution (Component 1)  
**Task**: 1.1

## Context

MediaHub needs to extract timestamps from media files to organize them into Year/Month (YYYY/MM) folders. The timestamp rule for P1 is: EXIF DateTimeOriginal when present and valid, otherwise filesystem modification date.

## Decision

### Timestamp Rule (P1)

**Primary**: EXIF DateTimeOriginal  
**Fallback**: Filesystem modification date

**Rationale**:
- EXIF DateTimeOriginal represents when the photo was actually taken (most accurate)
- Filesystem modification date is always available as a reliable fallback
- This rule is deterministic and simple for P1
- Alternative timestamp strategies are explicitly out of scope for P1

### EXIF Extraction Library

**ImageIO framework** (macOS built-in) is used for EXIF extraction.

**Rationale**:
- Built into macOS (no external dependencies)
- Supports common image formats (JPEG, HEIC, TIFF, etc.)
- Provides access to EXIF metadata including DateTimeOriginal
- Well-tested and reliable

### EXIF Timestamp Validation

EXIF timestamps are considered **valid** if:
1. The timestamp can be parsed as a valid date
2. The date is within a reasonable range (1900-01-01 to 2100-12-31)

**Invalid** EXIF timestamps include:
- Corrupted or unparseable date strings
- Dates outside reasonable range (before 1900 or after 2100)
- Missing DateTimeOriginal field

**Rationale**:
- Prevents using obviously incorrect dates
- Handles corrupted EXIF data gracefully
- Ensures dates are usable for Year/Month organization

### Fallback Strategy

When EXIF DateTimeOriginal is:
- Not present
- Invalid (corrupted, out of range)
- Unparseable

MediaHub falls back to the **filesystem modification date** (`mtime`).

**Rationale**:
- Always available for all file types
- Represents when file was last modified (reasonable proxy for capture date)
- Works for both images and videos (videos may not have EXIF)

### Video File Handling

Video files may not have EXIF metadata. For videos:
- Attempt EXIF extraction (some formats may have metadata)
- If EXIF is unavailable or invalid, use filesystem modification date

**Rationale**:
- Some video formats (e.g., MOV) may contain EXIF-like metadata
- Most videos don't have EXIF, so modification date is the primary fallback
- Consistent behavior across file types

### Timestamp Format

Timestamps are represented as **Date** objects internally and converted to ISO-8601 strings when needed for storage.

**Rationale**:
- Date objects provide proper date arithmetic and formatting
- ISO-8601 strings are human-readable and standardized
- Consistent with existing codebase (modificationDate in CandidateMediaItem)

## Consequences

### Positive
- ✅ Simple, deterministic timestamp rule
- ✅ Uses built-in macOS APIs (no external dependencies)
- ✅ Handles edge cases gracefully (corrupted EXIF, missing metadata)
- ✅ Works for both images and videos
- ✅ Always produces a valid timestamp (fallback guaranteed)

### Negative
- ⚠️ EXIF extraction may be slow for large batches (acceptable for P1)
- ⚠️ Some image formats may not support EXIF (fallback handles this)
- ⚠️ Video EXIF support is limited (expected behavior)

### Risks
- **EXIF Parsing Errors**: Some files may have non-standard EXIF formats (handled by fallback)
- **Timezone Handling**: EXIF timestamps may include timezone info; for P1, timestamps are treated as local/naive time
- **Performance**: EXIF extraction requires file I/O (acceptable for P1, can be optimized later)

## Validation

This ADR addresses:
- ✅ FR-004: Define and document timestamp rule (EXIF DateTimeOriginal → mtime fallback)
- ✅ FR-003: Organize files in Year/Month based on timestamp rule
- ✅ FR-012: Produce deterministic import results
- ✅ User Story 2: Organize imported files by Year/Month (acceptance scenarios 1, 4, 5)
- ✅ SC-002: Import results are 100% deterministic
- ✅ SC-007: Imported files organized according to timestamp rule 100% of the time

## References
- Plan Component 1 (lines 46-87)
- Specification FR-004
- Specification User Story 2
