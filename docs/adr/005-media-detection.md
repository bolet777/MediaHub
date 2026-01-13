# ADR 005: Media File Format Support

**Status**: Accepted  
**Date**: 2026-01-12  
**Component**: Source Scanning & Media Detection (Component 4)  
**Task**: 4.1

## Context

MediaHub needs to identify media files during Source scanning. The system must:

- Support detection of common image and video file formats (FR-016)
- Identify media files efficiently during scanning
- Exclude non-media files from detection
- Handle edge cases (files with incorrect extensions, etc.)

## Decision

### Media File Identification Strategy

**Extension-based identification** is chosen for P1.

**Rationale**:
- Simple and fast (no file content reading required)
- Sufficient for P1 requirements
- Meets performance targets (SC-003: < 30 seconds for 1000 files)
- Can be enhanced with content-based detection in future slices

**Alternative Considered**: Content-based (MIME type) detection
- **Rejected for P1**: Requires reading file headers, slower, adds complexity
- **Future**: May be added in later slices for files with incorrect extensions

### Supported Image Formats (P1)

The following image formats are supported in P1:

- **JPEG**: `.jpg`, `.jpeg`
- **PNG**: `.png`
- **HEIC/HEIF**: `.heic`, `.heif`
- **TIFF**: `.tiff`, `.tif`
- **GIF**: `.gif`
- **WebP**: `.webp`
- **RAW formats**: `.cr2`, `.nef`, `.arw`, `.dng`, `.raf`, `.orf`, `.rw2`

**Rationale**:
- Covers common formats used by cameras and phones
- Includes RAW formats for professional photographers
- Extensible list can be expanded in future slices

### Supported Video Formats (P1)

The following video formats are supported in P1:

- **QuickTime**: `.mov`
- **MP4**: `.mp4`, `.m4v`
- **AVI**: `.avi`
- **MKV**: `.mkv`
- **MPEG**: `.mpg`, `.mpeg`

**Rationale**:
- Covers common formats from cameras and phones
- Includes standard container formats
- Extensible list can be expanded in future slices

### Case Sensitivity

File extension matching is **case-insensitive**.

**Rationale**:
- macOS file system is case-insensitive by default
- Handles variations like `.JPG`, `.Jpeg`, `.jpeg`
- More user-friendly

### Edge Cases

**Files with incorrect extensions**: For P1, files with non-media extensions are excluded even if they contain media content. Content-based detection may be added in future slices.

**Symbolic links and aliases**: Symbolic links are followed during scanning. If a link points to a media file, it is detected. If a link is broken, it is skipped.

**Locked files**: Files that cannot be read are skipped with a warning, but scanning continues.

**Corrupted files**: Files that cannot be accessed are skipped, but scanning continues.

## Consequences

### Positive
- ✅ Fast extension-based detection meets performance targets
- ✅ Covers common image and video formats
- ✅ Simple implementation for P1
- ✅ Extensible for future format additions

### Negative
- ⚠️ Files with incorrect extensions are excluded (acceptable for P1)
- ⚠️ No content validation (files may be corrupted, but this is acceptable for P1)

### Risks
- **False Positives**: Files with media extensions but non-media content (handled by skipping unreadable files)
- **Missing Formats**: Some formats may not be supported (extensible list addresses this)

## Validation

This ADR addresses:
- ✅ FR-016: Support detection of common image and video file formats
- ✅ Plan Component 4: Media file format support

## References

- Plan Component 4: Source Scanning & Media Detection
- Specification FR-016
- Task 4.1: Define Media File Format Support (ADR)
