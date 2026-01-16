# Slice 9b — Duplicate Reporting & Audit

**Document Type**: Slice Implementation Plan
**Slice Number**: 9b
**Title**: Duplicate Reporting & Audit
**Author**: Spec-Kit Orchestrator
**Date**: 2026-01-15
**Status**: Draft

---

## High-Level Architecture

Slice 9b extends MediaHub's duplicate detection capabilities from Slice 8 into a dedicated read-only reporting system. The architecture maintains separation of concerns by introducing a new `DuplicateReporting` component while reusing existing infrastructure:

- **Core Component**: `DuplicateReporting` - orchestrates the entire duplicate analysis pipeline
- **Data Source**: `BaselineIndex` (v1.1+) - provides hash-indexed library content
- **Output Layer**: Format-specific reporters (Text/JSON/CSV) - handle presentation logic
- **CLI Integration**: New `duplicates` command extending existing CLI patterns

The design follows MediaHub's established patterns: read-only operations, deterministic behavior, and zero state mutation.

---

## Core Components and Responsibilities

### DuplicateReporting (New Component)
**Purpose**: Central orchestrator for duplicate analysis and reporting workflow.

**Responsibilities**:
- Load and validate BaselineIndex data
- Extract hash-to-files mapping from index entries
- Group files by content hash (SHA-256)
- Apply deterministic sorting (hash primary, path secondary)
- Route results to appropriate output formatter
- Handle edge cases (missing hashes, empty results)

**Dependencies**: `BaselineIndex`, `LibraryContext`

### DuplicateGroup (New Value Type)
**Purpose**: Immutable representation of a duplicate group for reporting.

**Structure**:
- `hash: String` (SHA-256 hex)
- `files: [DuplicateFile]` (sorted deterministically)
- Computed properties: `fileCount`, `totalSizeBytes`

### DuplicateFile (New Value Type)
**Purpose**: Immutable representation of a file within a duplicate group.

**Structure**:
- `path: String` (relative library path)
- `sizeBytes: Int`
- `timestamp: Date` (file creation timestamp)

### Output Formatters (New Components)
**Purpose**: Handle format-specific presentation of duplicate analysis results.

**TextFormatter**: Human-readable console output with grouped display
**JsonFormatter**: Structured JSON output for programmatic consumption
**CsvFormatter**: Tabular CSV output for spreadsheet analysis

**Shared Interface**: All formatters implement `DuplicateFormatter` protocol for consistent result routing.

---

## Data Flow

```
BaselineIndex (v1.1+) → DuplicateReporting → OutputFormatter → stdout/file

Detailed Flow:
1. Load BaselineIndex from .mediahub/registry/index.json
2. Validate index version and hash coverage
3. Extract entries with non-nil hash values
4. Build hash → [file entries] mapping
5. Filter groups with fileCount > 1 (true duplicates)
6. Apply deterministic sorting:
   - Groups: lexicographic by hash
   - Files within groups: relative path lexicographic ascending (primary, stable)
7. Generate summary statistics (total groups, files, sizes)
8. Route to selected formatter (text/json/csv)
9. Output to stdout or specified file path
```

**Deterministic Ordering Guarantees**:
- Groups always sorted by hash (SHA-256 hex string, lexicographic ascending)
- Files within groups sorted by: relative path lexicographic ascending (primary, stable ordering)
- Timestamp displayed for user reference but does not affect ordering (ordering based solely on stable path data)
- Ensures identical output for identical library state
- Path-based sorting provides stable, reproducible results independent of filesystem metadata

---

## CLI Integration Points

**Command Structure**:
Extends existing `MediaHubCLI` module with new `DuplicatesCommand`.

**Integration Points**:
- `LibraryContext`: Reuse existing library selection and validation
- `OutputFormatting`: Reuse existing JSON/text formatting patterns where applicable
- `ProgressIndicator`: No progress needed (fast operation)
- Error handling: Reuse existing `CLIError` patterns

**Command Line Interface**:
```
mediahub duplicates [--format json|csv|text] [--output <file>]
```

**Library Selection**: Uses existing MediaHub library selection mechanism (environment/config), consistent with other commands like `status`, `detect`, `import`.

---

## Output Formatting Strategy

### Text Format (Default)
**Purpose**: Human-readable console output for interactive use.

**Structure**:
- Header with library name and generation timestamp
- Summary statistics (groups, files, total size, potential savings)
- Grouped duplicate listings with hash, file count, and total size
- Individual file details (indented, with size and timestamp)
- Footer with summary recap

**Reuses**: Existing text formatting utilities for size display, timestamp formatting.

### JSON Format
**Purpose**: Structured output for programmatic consumption and external tools.

**Structure**:
```json
{
  "library": "Library Name",
  "generated": "2026-01-15T14:30:00Z",
  "summary": {
    "duplicateGroups": 3,
    "totalDuplicateFiles": 12,
    "totalDuplicateSizeBytes": 42949672,
    "potentialSavingsBytes": 28632646
  },
  "groups": [
    {
      "hash": "a1b2c3...",
      "fileCount": 3,
      "totalSizeBytes": 15938355,
      "files": [
        {
          "path": "2023/12/photo.jpg",
          "sizeBytes": 5346123,
          "timestamp": "2023-12-01T10:15:00Z"
        }
      ]
    }
  ]
}
```

**Reuses**: Existing JSON output patterns from commands like `status`, `detect`.

### CSV Format
**Purpose**: Tabular output for spreadsheet analysis and data processing.

**Structure**:
- Header row: `group_hash,file_count,total_size_bytes,path,size_bytes,timestamp`
- One row per file (groups denormalized)
- Deterministic ordering ensures consistent CSV structure

**Reuses**: Existing CSV formatting utilities if available, or minimal custom implementation.

---

## Performance Considerations

### Memory Efficiency
- Single pass over BaselineIndex entries to build hash→files mapping
- Build hash mappings incrementally to avoid large intermediate data structures
- No arbitrary limits on duplicate set sizes (memory-efficient grouping)

### Execution Time
- Target: < 30 seconds for typical libraries (10k-100k files)
- Fast-path for libraries with no/complete hash coverage
- Linear scaling with library size (no quadratic operations)

### BaselineIndex Access
- Read-only access to existing index file
- No index modifications or rebuilds required
- Graceful handling of missing/invalid indexes

---

## Testing Strategy

### Unit Testing
- `DuplicateReportingTests`: Core grouping and sorting logic
- `DuplicateFormatterTests`: Output formatting accuracy (all three formats)
- Edge case coverage: empty libraries, no duplicates, incomplete hashes

### Integration Testing
- End-to-end CLI command testing with sample libraries
- Output format validation against schema expectations
- Deterministic ordering verification across multiple runs

### Validation Testing
- Performance benchmarking with various library sizes
- Memory usage monitoring for large duplicate sets
- Compatibility testing with different BaselineIndex versions

**Test Infrastructure Reuse**: Leverages existing test patterns for CLI commands, index handling, and output validation.

---

## Implementation Touchpoints

**Minimal File Changes Expected**:

**New Files**:
- `Sources/MediaHub/DuplicateReporting.swift`
- `Sources/MediaHub/DuplicateFormatter.swift` (protocol + implementations)
- `Sources/MediaHubCLI/DuplicatesCommand.swift`
- `Tests/MediaHubTests/DuplicateReportingTests.swift`
- `Tests/MediaHubTests/DuplicateFormatterTests.swift`

**Modified Files**:
- `Sources/MediaHubCLI/main.swift` (add command registration)
- Potentially `Sources/MediaHubCLI/OutputFormatting.swift` (reuse utilities)

**No Changes To**:
- Core import/detection logic
- BaselineIndex structure
- Existing CLI commands
- Library management components

---

## Risk Mitigation

**Architecture Risks**:
- Minimal coupling: New components isolated from existing import/detection logic
- Read-only design: Zero risk of data corruption or state mutation
- Backward compatibility: Works with existing BaselineIndex v1.1+ infrastructure

**Performance Risks**:
- Memory-efficient design prevents scaling issues
- Fast failure for invalid indexes avoids long-running operations
- No changes to existing performance-critical paths

**Integration Risks**:
- Follows established CLI patterns for seamless integration
- Reuses existing error handling and output formatting
- Independent of future changes to import/detection logic
