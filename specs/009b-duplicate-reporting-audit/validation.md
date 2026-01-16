# Slice 9b — Duplicate Reporting & Audit

**Document Type**: Slice Validation Runbook
**Slice Number**: 9b
**Title**: Duplicate Reporting & Audit
**Author**: Spec-Kit Orchestrator
**Date**: 2026-01-15
**Status**: Draft

---

## Validation Overview

This runbook provides comprehensive validation for Slice 9b implementation. All checks are runnable and verify the success criteria from spec.md: duplicate reporting by content hash, read-only safety, deterministic ordering, and multiple output formats.

**Key Validation Principles**:
- Read-only operations (zero writes, zero mutations)
- Deterministic output (same input → identical output)
- Exact duplicates by content hash only
- Memory usage proportional to duplicate set size

**Library Selection Setup**:
- Commands use the `MEDIAHUB_LIBRARY` environment variable for library selection
- Set `export MEDIAHUB_LIBRARY="<fixture_path>"` before running commands on a specific fixture

---

## 1. Preconditions / Test Fixtures

### Fixture A: Library with Duplicates (fixture-duplicates)
**Setup**: Create a test library with at least 2 files having identical content (same SHA-256 hash).

```bash
# Create test library in /tmp
mkdir -p /tmp/mediahub-fixture-duplicates
cd /tmp/mediahub-fixture-duplicates

# Create library structure and directories
mkdir -p .mediahub/registry 2023/01 2024/02/backup 2023/06

# Create test files with identical content (same hash)
echo "identical content" > 2023/01/photo1.jpg
echo "identical content" > 2024/02/backup/photo1.jpg
echo "different content" > 2023/06/vacation.jpg

# Use existing MediaHub commands to create/adopt the library and generate baseline index
# (This will create a proper BaselineIndex with correct schema)
cd /path/to/mediahub
swift run mediahub library adopt /tmp/mediahub-fixture-duplicates

# Set up library selection for subsequent commands
export MEDIAHUB_LIBRARY=/tmp/mediahub-fixture-duplicates
swift run mediahub index hash --yes
```

**Expected**: Library with 1 duplicate group (2 files with same hash), 1 unique file.

### Fixture B: Library with No Duplicates (fixture-no-duplicates)
**Setup**: Create a test library where all files have unique content.

```bash
# Create test library in /tmp
mkdir -p /tmp/mediahub-fixture-no-duplicates
cd /tmp/mediahub-fixture-no-duplicates

# Create library structure and directories
mkdir -p .mediahub/registry 2023/01 2023/02 2023/03

# Create files with unique content
echo "content 1" > 2023/01/file1.jpg
echo "content 2" > 2023/02/file2.jpg
echo "content 3" > 2023/03/file3.jpg

# Use existing MediaHub commands to create/adopt the library and generate baseline index
cd /path/to/mediahub
swift run mediahub library adopt /tmp/mediahub-fixture-no-duplicates

# Set up library selection for subsequent commands
export MEDIAHUB_LIBRARY=/tmp/mediahub-fixture-no-duplicates
swift run mediahub index hash --yes
```

**Expected**: Library with no duplicate groups (all files unique).

### Fixture C: Library with Incomplete Hash Coverage (fixture-nil-hashes)
**Setup**: Create a test library with some entries having nil hashes and one duplicate group.

```bash
# Create test library in /tmp
mkdir -p /tmp/mediahub-fixture-nil-hashes
cd /tmp/mediahub-fixture-nil-hashes

# Create library structure and directories
mkdir -p .mediahub/registry 2023/01 2024/01 2023/12

# Create test files
echo "duplicate content" > 2023/01/file1.jpg
echo "duplicate content" > 2024/01/file1.jpg
echo "unique content" > 2023/12/file2.jpg

# Use existing MediaHub commands to create/adopt the library and generate baseline index
cd /path/to/mediahub
swift run mediahub library adopt /tmp/mediahub-fixture-nil-hashes

# Set up library selection for subsequent commands
export MEDIAHUB_LIBRARY=/tmp/mediahub-fixture-nil-hashes
swift run mediahub index hash --yes

# Manually set one hash to null for testing incomplete coverage
# (Edit .mediahub/registry/index.json to set one entry's hash field to null)
```

**Expected**: Library with 1 duplicate group (2 files with same hash), 1 file with nil hash (should be skipped).

---

## 2. CLI Contract Validations

### Command Help Display
```bash
cd /path/to/mediahub
swift run mediahub duplicates --help
```

**Expected Output Pattern**:
```
USAGE: mediahub duplicates [--format <format>] [--output <output>]

OPTIONS:
  --format <format>         Output format: text, json, csv (default: text)
  --output <output>         Output file path (default: stdout)
  -h, --help                Show help information
```

**Note**: Library selection uses the existing MediaHub mechanism (env/config/per-command convention).

### Default Behavior (No Flags)
```bash
cd /tmp/mediahub-fixture-duplicates
swift run mediahub duplicates
```

**Expected**: Success with text output to stdout, showing duplicate groups.

### Format Flag Validation
```bash
cd /tmp/mediahub-fixture-duplicates

# Text format (explicit)
swift run mediahub duplicates --format text
# Expected: Text output identical to default

# JSON format
swift run mediahub duplicates --format json
# Expected: Valid JSON output (test with: | python3 -m json.tool)

# CSV format
swift run mediahub duplicates --format csv
# Expected: CSV with header row and data rows

# Invalid format
swift run mediahub duplicates --format invalid
# Expected: Error message about invalid format
```

### Output File Flag
```bash
cd /tmp/mediahub-fixture-duplicates

# Output to file
swift run mediahub duplicates --output /tmp/duplicates-report.txt
# Expected: File /tmp/duplicates-report.txt created with content

# Verify file exists and has content
ls -la /tmp/duplicates-report.txt
head /tmp/duplicates-report.txt
```

---

## 3. Safety Validations (Read-Only)

### No Index Modifications
```bash
cd /tmp/mediahub-fixture-duplicates

# Record index mtime before
ls -la .mediahub/registry/index.json

# Run duplicates command
swift run mediahub duplicates > /dev/null

# Verify index mtime unchanged
ls -la .mediahub/registry/index.json
```

**Expected**: Index file modification time unchanged (no writes occurred).

### No New Files Created (Without --output)
```bash
cd /tmp/mediahub-fixture-duplicates

# Count files before
find . -type f | wc -l

# Run duplicates command (no --output)
swift run mediahub duplicates > /dev/null

# Count files after
find . -type f | wc -l
```

**Expected**: File count unchanged (no new files created).

### Output File Creation (With --output)
```bash
cd /tmp/mediahub-fixture-duplicates

# Run with --output
swift run mediahub duplicates --output /tmp/test-output.json

# Verify only the specified file was created
ls -la /tmp/test-output.json
# Expected: File exists with recent timestamp

# Verify no other files created in library
find . -newer /tmp/test-output.json -type f
# Expected: Only the output file is newer
```

---

## 4. Determinism & Ordering Validations

### Identical Output on Multiple Runs
```bash
cd /tmp/mediahub-fixture-duplicates

# Run 1
swift run mediahub duplicates --format json > run1.json

# Run 2
swift run mediahub duplicates --format json > run2.json

# Compare outputs
diff run1.json run2.json
```

**Expected**: No differences (files identical).

### Ordering Rules Verification
```bash
cd /tmp/mediahub-fixture-duplicates
swift run mediahub duplicates --format json | jq '.groups[0].files | map(.path)'
```

**Expected**: Files sorted lexicographically by relative path, e.g.:
```json
[
  "2023/01/photo1.jpg",
  "2024/02/backup/photo1.jpg"
]
```

### Hash-Based Group Ordering
```bash
cd /tmp/mediahub-fixture-duplicates
swift run mediahub duplicates --format json | jq '.groups | map(.hash)'
```

**Expected**: Hashes in lexicographic ascending order.

---

## 5. Format Validations

### Text Format Structure
```bash
cd /tmp/mediahub-fixture-duplicates
swift run mediahub duplicates --format text
```

**Expected Output Pattern**:
```
Duplicate Report for Library: mediahub-fixture-duplicates
Generated: [timestamp]

Found 1 duplicate groups containing 2 total files

Group 1: Hash [hash] (2 files, 36 bytes total)
  - 2023/01/photo1.jpg (18 bytes) [timestamp]
  - 2024/02/backup/photo1.jpg (18 bytes) [timestamp]

Summary:
- Total duplicate groups: 1
- Total duplicate files: 2
- Total space used by duplicates: 36 bytes
- Potential space savings: ~18 bytes (keep 1 copy per group)
```

### JSON Format Validation
```bash
cd /tmp/mediahub-fixture-duplicates

# Generate JSON
swift run mediahub duplicates --format json > duplicates.json

# Validate JSON syntax
python3 -m json.tool duplicates.json > /dev/null && echo "JSON valid"

# Check required fields (requires jq - install with: brew install jq)
jq '.library, .generated, .summary, .groups' duplicates.json
```

**Expected**: Valid JSON with all required fields present.

### CSV Format Validation
```bash
cd /tmp/mediahub-fixture-duplicates

# Generate CSV
swift run mediahub duplicates --format csv > duplicates.csv

# Check header
head -1 duplicates.csv
# Expected: group_hash,file_count,total_size_bytes,path,size_bytes,timestamp

# Check row count (header + data rows)
wc -l duplicates.csv
# Expected: 3 lines (header + 2 data rows for the duplicate group)

# Verify deterministic ordering (same path order as JSON)
cut -d',' -f4 duplicates.csv | tail -2
# Expected: 2023/01/photo1.jpg, then 2024/02/backup/photo1.jpg
```

---

## 6. Failure Modes & Edge Cases

### Missing Baseline Index
```bash
# Create library without .mediahub structure
mkdir -p /tmp/mediahub-no-index
cd /tmp/mediahub-no-index

swift run mediahub duplicates
```

**Expected Error**: Clear message directing user to run library operations first.

### Invalid Baseline Index
```bash
cd /tmp/mediahub-fixture-duplicates

# Backup the original index
cp .mediahub/registry/index.json .mediahub/registry/index.json.bak

# Corrupt the index file
echo "invalid json" > .mediahub/registry/index.json

# Run command (expect error)
swift run mediahub duplicates

# Restore the original index
mv .mediahub/registry/index.json.bak .mediahub/registry/index.json
```

**Expected Error**: Clear error about invalid index format.

### Unwritable Output Path
```bash
cd /tmp/mediahub-fixture-duplicates

# Try to write to read-only location
swift run mediahub duplicates --output /etc/duplicates.json
```

**Expected Error**: Clear error about unwritable output path (fails before processing).

### No Duplicates Found
```bash
cd /tmp/mediahub-fixture-no-duplicates
swift run mediahub duplicates
```

**Expected Output**: Empty report with "no duplicates found" summary.

### Incomplete Hash Coverage
```bash
cd /tmp/mediahub-fixture-nil-hashes
swift run mediahub duplicates --format json | jq '.summary.duplicateGroups'
```

**Expected**: Returns 1 (duplicate group found, nil hash entry skipped).

---

## Prerequisites

**Required Tools**:
- `jq` for JSON validation: Install with `brew install jq`
- `python3` for JSON syntax validation
- Swift toolchain for running MediaHub

**Test Environment**:
- macOS with Swift development environment
- `/tmp` directory writable for test fixtures

---

## 7. Automated Tests

### Unit Test Execution
```bash
cd /path/to/mediahub

# Run full test suite (recommended)
swift test

# Or run specific test filters if available in the project
# swift test --filter DuplicateReporting
# swift test --filter DuplicateFormatter
```

**Test Coverage Requirements**:
- ✅ Duplicate grouping logic
- ✅ Deterministic ordering (multiple runs)
- ✅ All output formats (text, JSON, CSV)
- ✅ Edge cases (missing index, no duplicates, nil hashes)
- ✅ Error handling and user-friendly messages

### Integration Test Coverage
```bash
# Full test suite
swift test
```

**Expected**: All tests pass with >90% coverage of new functionality.

---

## 8. Release Readiness Checklist

**Must-Pass Items for Slice 9b Acceptance**:

### Functional Completeness
- [ ] `mediahub duplicates` command works with all fixtures
- [ ] All output formats (text, JSON, CSV) produce correct structure
- [ ] Duplicate detection finds all groups by content hash
- [ ] Summary statistics are accurate

### Safety & Reliability
- [ ] No writes to library or index files (verified with mtime checks)
- [ ] Read-only operations confirmed across all code paths
- [ ] No new files created unless `--output` specified
- [ ] Memory usage proportional to duplicate set size

### Determinism & Ordering
- [ ] Identical outputs on multiple runs (diff returns empty)
- [ ] Groups ordered by hash lexicographically ascending
- [ ] Files within groups ordered by relative path lexicographically ascending
- [ ] Timestamps displayed but do not affect ordering

### Error Handling
- [ ] Missing index: clear error message
- [ ] Invalid index: appropriate error handling
- [ ] Unwritable output: fail fast with clear message
- [ ] No duplicates: empty report with clear summary
- [ ] Nil hashes: skipped silently, processing continues

### Performance
- [ ] Execution time < 30 seconds for test fixtures
- [ ] Memory usage scales with duplicate count, not library size
- [ ] No performance degradation with large duplicate sets

### Integration
- [ ] Command appears in general help output
- [ ] Library selection works with existing mechanisms
- [ ] Error messages follow MediaHub patterns
- [ ] No conflicts with existing commands

### Testing
- [ ] All unit tests pass
- [ ] Integration tests verify CLI behavior
- [ ] Edge case coverage complete
- [ ] Deterministic ordering tests pass consistently

---

## Validation Completion Criteria

**Slice 9b is ready for implementation freeze when**:
- All checklist items marked as passed
- No outstanding issues in error handling or edge cases
- Performance targets met for all test scenarios
- Determinism verified across multiple test runs
- All automated tests pass with comprehensive coverage

**Post-Freeze Activities**:
- Update `specs/STATUS.md` to mark Slice 9b as complete
- Update README.md if new CLI commands need documentation
- Consider follow-up slices (9c, 11+) based on roadmap priorities
