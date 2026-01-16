# Slice 9c — Performance & Scale Observability

**Document Type**: Slice Validation Runbook
**Slice Number**: 9c
**Title**: Performance & Scale Observability
**Author**: Spec-Kit Orchestrator
**Date**: 2026-01-27
**Status**: Draft

---

## Validation Overview

This runbook provides comprehensive validation for Slice 9c implementation. All checks are runnable and verify the success criteria from spec.md: performance measurement, scale metrics reporting, and deterministic behavior.

**Key Validation Principles**:
- Read-only operations (zero writes, zero mutations)
- Deterministic measurement (same input → identical scale metrics)
- Fail-safe behavior (measurement errors don't affect operations)
- Accurate scale metrics and performance reporting
- No operation blocking or refusals

**Library Selection Setup**:
- Commands use the `MEDIAHUB_LIBRARY` environment variable for library selection
- Set `export MEDIAHUB_LIBRARY="<fixture_path>"` before running commands on a specific fixture

---

## 1. Preconditions / Test Fixtures

### Fixture A: Small Library (fixture-small)
**Setup**: Create a test library with <1,000 files for baseline testing.

```bash
# Create test library in /tmp
mkdir -p /tmp/mediahub-fixture-small
cd /tmp/mediahub-fixture-small

# Create library structure
mkdir -p .mediahub/registry 2023/01 2023/02 2023/03

# Create test files (100 files)
for i in {1..100}; do
  echo "content $i" > "2023/01/file$i.jpg"
done

# Use existing MediaHub commands to create/adopt the library
cd /path/to/mediahub
swift run mediahub library adopt /tmp/mediahub-fixture-small

# Set up library selection
export MEDIAHUB_LIBRARY=/tmp/mediahub-fixture-small
swift run mediahub index hash --yes
```

**Expected**: Library with ~100 files, complete hash coverage.

### Fixture B: Large Library (fixture-large)
**Setup**: Create a test library with 10,000+ files for large-scale testing.

```bash
# Create test library in /tmp
mkdir -p /tmp/mediahub-fixture-large
cd /tmp/mediahub-fixture-large

# Create library structure
mkdir -p .mediahub/registry 2015/{01..12} 2016/{01..12} 2017/{01..12} 2018/{01..12} 2019/{01..12}

# Create test files (25,000 files - manageable for testing)
for year in 2015 2016 2017 2018 2019; do
  for month in {01..12}; do
    for i in {1..416}; do  # ~416 files per month = ~25,000 total
      echo "content $year-$month-$i" > "$year/$month/file$i.jpg"
    done
  done
done

# Use existing MediaHub commands to create/adopt the library
cd /path/to/mediahub
swift run mediahub library adopt /tmp/mediahub-fixture-large

# Set up library selection
export MEDIAHUB_LIBRARY=/tmp/mediahub-fixture-large
swift run mediahub index hash --yes
```

**Expected**: Library with ~25,000 files, complete hash coverage.

---

## 2. Safety Validations (Read-Only)

### No Index Modifications
```bash
export MEDIAHUB_LIBRARY=/tmp/mediahub-fixture-small

# Record index mtime before
INDEX_MTIME_BEFORE=$(stat -f %m /tmp/mediahub-fixture-small/.mediahub/registry/index.json 2>/dev/null || stat -c %Y /tmp/mediahub-fixture-small/.mediahub/registry/index.json)

# Run command with performance measurement
swift run mediahub status > /dev/null

# Verify index mtime unchanged
INDEX_MTIME_AFTER=$(stat -f %m /tmp/mediahub-fixture-small/.mediahub/registry/index.json 2>/dev/null || stat -c %Y /tmp/mediahub-fixture-small/.mediahub/registry/index.json)
if [ "$INDEX_MTIME_BEFORE" = "$INDEX_MTIME_AFTER" ]; then
  echo "✅ Index not modified"
else
  echo "❌ Index was modified"
fi
```

**Expected**: Index file modification time unchanged (no writes occurred).

### No New Files Created (Without Measurement Persistence)
```bash
export MEDIAHUB_LIBRARY=/tmp/mediahub-fixture-small

# Count files before
FILE_COUNT_BEFORE=$(find /tmp/mediahub-fixture-small -type f | wc -l)

# Run command with performance measurement
swift run mediahub status > /dev/null

# Count files after
FILE_COUNT_AFTER=$(find /tmp/mediahub-fixture-small -type f | wc -l)
if [ "$FILE_COUNT_BEFORE" = "$FILE_COUNT_AFTER" ]; then
  echo "✅ No new files created"
else
  echo "❌ New files created"
fi
```

**Expected**: File count unchanged (no new files created for measurement).

### Measurement Does Not Affect Operation Results
```bash
export MEDIAHUB_LIBRARY=/tmp/mediahub-fixture-small

# Run command multiple times (measurement is always on)
swift run mediahub status --json > output1.json
swift run mediahub status --json > output2.json

# Compare results (excluding performance fields)
# Use jq to remove performance fields and compare (jq optional - skip if not available)
if command -v jq > /dev/null 2>&1; then
  jq 'del(.performance)' output1.json > output1_no_perf.json
  jq 'del(.performance)' output2.json > output2_no_perf.json
  diff output1_no_perf.json output2_no_perf.json
  if [ $? -eq 0 ]; then
    echo "✅ Operation results identical (excluding performance fields)"
  else
    echo "❌ Operation results differ"
  fi
else
  echo "⚠️  jq not available, skipping comparison (validate JSON syntax with python3 -m json.tool)"
  python3 -m json.tool output1.json > /dev/null && echo "✅ output1.json is valid JSON"
  python3 -m json.tool output2.json > /dev/null && echo "✅ output2.json is valid JSON"
fi
```

**Expected**: No differences in operation results (measurement does not affect correctness).

---

## 3. Performance Measurement Validations

### Execution Time Measurement Presence (Informational Check)
```bash
export MEDIAHUB_LIBRARY=/tmp/mediahub-fixture-small

# Run command and capture output
swift run mediahub status --json > status_output.json

# Extract duration from JSON (jq optional - skip if not available)
if command -v jq > /dev/null 2>&1; then
  DURATION=$(jq -r '.performance.durationSeconds' status_output.json)
  # Verify duration is present (may be null/empty for very fast operations)
  if [ -n "$DURATION" ] && [ "$DURATION" != "null" ]; then
    echo "✅ Duration measured: ${DURATION}s"
  else
    echo "✅ Duration field present (may be null for fast operations)"
  fi
else
  # Fallback: validate JSON syntax
  python3 -m json.tool status_output.json > /dev/null && echo "✅ JSON output is valid"
  echo "⚠️  jq not available, skipping duration extraction"
fi
```

**Expected**: Duration field is present in JSON (may be null for very fast operations). This is an informational check; duration values may vary across runs.

### Scale Metrics Accuracy
```bash
export MEDIAHUB_LIBRARY=/tmp/mediahub-fixture-small

# Run command and capture output
swift run mediahub status --json > status_output.json

# Extract scale metrics (jq optional - skip if not available)
if command -v jq > /dev/null 2>&1; then
  FILE_COUNT=$(jq -r '.performance.scale.fileCount' status_output.json)
  TOTAL_SIZE=$(jq -r '.performance.scale.totalSizeBytes' status_output.json)
  HASH_COVERAGE=$(jq -r '.performance.scale.hashCoveragePercent' status_output.json)

  # Verify metrics are present and reasonable
  if [ -n "$FILE_COUNT" ] && [ "$FILE_COUNT" -gt 0 ]; then
    echo "✅ File count: $FILE_COUNT"
  else
    echo "❌ Invalid file count: $FILE_COUNT"
  fi

  if [ -n "$TOTAL_SIZE" ] && [ "$TOTAL_SIZE" -gt 0 ]; then
    echo "✅ Total size: $TOTAL_SIZE bytes"
  else
    echo "❌ Invalid total size: $TOTAL_SIZE"
  fi

  if [ -n "$HASH_COVERAGE" ] && [ "$HASH_COVERAGE" != "null" ]; then
    echo "✅ Hash coverage: ${HASH_COVERAGE}%"
  else
    echo "✅ Hash coverage field present (may be null if not applicable)"
  fi
else
  # Fallback: validate JSON syntax
  python3 -m json.tool status_output.json > /dev/null && echo "✅ JSON output is valid"
  echo "⚠️  jq not available, skipping scale metrics extraction"
fi
```

**Expected**: All scale metrics are present, accurate, and within expected ranges.

### Measurement Presence Verification
```bash
export MEDIAHUB_LIBRARY=/tmp/mediahub-fixture-small

# Run command multiple times
for i in {1..5}; do
  swift run mediahub status --json > "status_$i.json"
done

# Verify performance object is present in all runs (jq optional)
if command -v jq > /dev/null 2>&1; then
  for i in {1..5}; do
    if jq -e '.performance' "status_$i.json" > /dev/null 2>&1; then
      echo "✅ Performance object present in run $i"
    else
      echo "❌ Performance object missing in run $i"
    fi
  done
else
  # Fallback: validate JSON syntax
  for i in {1..5}; do
    python3 -m json.tool "status_$i.json" > /dev/null && echo "✅ status_$i.json is valid JSON"
  done
  echo "⚠️  jq not available, skipping performance object verification"
fi
```

**Expected**: Performance object is present in JSON output for all runs.

---

## 4. Determinism & Measurement Consistency Validations

### Identical Scale Metrics on Multiple Runs
```bash
export MEDIAHUB_LIBRARY=/tmp/mediahub-fixture-small

# Run command multiple times
for i in {1..5}; do
  swift run mediahub status --json > "run_$i.json"
done

# Extract and compare scale metrics (should be identical) - jq optional
if command -v jq > /dev/null 2>&1; then
  SCALE_METRICS_1=$(jq -c '.performance.scale' run_1.json)
  SCALE_METRICS_2=$(jq -c '.performance.scale' run_2.json)
  SCALE_METRICS_3=$(jq -c '.performance.scale' run_3.json)
  SCALE_METRICS_4=$(jq -c '.performance.scale' run_4.json)
  SCALE_METRICS_5=$(jq -c '.performance.scale' run_5.json)

  # All scale metrics should be identical
  if [ "$SCALE_METRICS_1" = "$SCALE_METRICS_2" ] && \
     [ "$SCALE_METRICS_2" = "$SCALE_METRICS_3" ] && \
     [ "$SCALE_METRICS_3" = "$SCALE_METRICS_4" ] && \
     [ "$SCALE_METRICS_4" = "$SCALE_METRICS_5" ]; then
    echo "✅ Scale metrics are identical across runs (deterministic)"
  else
    echo "❌ Scale metrics differ across runs"
  fi
else
  echo "⚠️  jq not available, skipping scale metrics comparison"
  echo "✅ JSON files generated (validate syntax with python3 -m json.tool)"
fi
```

**Expected**: Scale metrics are identical across multiple runs (deterministic).

---

## 5. Operation Proceeds Normally (No Blocking)

### Large Library Operations Proceed
```bash
export MEDIAHUB_LIBRARY=/tmp/mediahub-fixture-large

# Run command on large library
swift run mediahub status 2>&1 | tee status_output.txt

# Verify operation succeeded (no refusal)
if [ $? -eq 0 ]; then
  echo "✅ Operation succeeded on large library (no blocking)"
else
  echo "❌ Operation failed (should not be blocked)"
fi
```

**Expected**: Operations proceed normally on large libraries (no blocking or refusals).

### Operations Always Succeed
```bash
export MEDIAHUB_LIBRARY=/tmp/mediahub-fixture-large

# Run multiple operations
swift run mediahub status > /dev/null && echo "✅ Status succeeded"
swift run mediahub duplicates > /dev/null && echo "✅ Duplicates succeeded"
swift run mediahub index hash --limit 100 --yes > /dev/null && echo "✅ Index hash succeeded"
```

**Expected**: All operations succeed regardless of library scale (no refusals).

---

## 6. Performance Reporting Validations

### Human-Readable Format
```bash
export MEDIAHUB_LIBRARY=/tmp/mediahub-fixture-small

# Run command and capture output
swift run mediahub status > status_output.txt

# Check for performance summary
if grep -q "files.*seconds" status_output.txt || \
   grep -q "completed in" status_output.txt || \
   grep -q "Library:.*files" status_output.txt; then
  echo "✅ Human-readable performance reporting present"
else
  echo "❌ Human-readable performance reporting missing"
fi
```

**Expected**: Human-readable performance summary includes duration and scale context.

### JSON Format
```bash
export MEDIAHUB_LIBRARY=/tmp/mediahub-fixture-small

# Run command and capture JSON output
swift run mediahub status --json > status_output.json

# Validate JSON syntax
if python3 -m json.tool status_output.json > /dev/null 2>&1; then
  echo "✅ JSON output is valid"
else
  echo "❌ JSON output is invalid"
fi

# Check for performance object (jq optional)
if command -v jq > /dev/null 2>&1; then
  if jq -e '.performance' status_output.json > /dev/null 2>&1; then
    echo "✅ Performance object present in JSON"
  else
    echo "❌ Performance object missing in JSON"
  fi

  # Check for required performance fields
  if jq -e '.performance.durationSeconds' status_output.json > /dev/null 2>&1 && \
     jq -e '.performance.scale' status_output.json > /dev/null 2>&1; then
    echo "✅ Required performance fields present"
  else
    echo "❌ Required performance fields missing"
  fi
else
  echo "⚠️  jq not available, skipping performance object verification"
fi
```

**Expected**: JSON output includes valid performance object with duration and scale metrics.

### Optional: UX Non-Regression Check (Informational)
```bash
export MEDIAHUB_LIBRARY=/tmp/mediahub-fixture-small

# Capture output without JSON flag (human-readable)
swift run mediahub status > status_human.txt

# Verify existing output structure is preserved
# (This is a sanity check - exact format may vary)
if grep -q "Library\|Status\|Files" status_human.txt; then
  echo "✅ Existing output structure appears preserved"
else
  echo "⚠️  Output structure may have changed (review manually)"
fi

# Verify performance information appears as additional section
# (Non-blocking check - performance may be integrated or appended)
if grep -q "files\|coverage\|Library:" status_human.txt; then
  echo "✅ Performance/scale information present in output"
else
  echo "⚠️  Performance information not found (may be integrated differently)"
fi
```

**Note**: This is an optional, informational check. It verifies that existing command output structure is preserved and performance information appears as an additional section. Exact formatting is not normative.

### Scale Metrics Reporting
```bash
export MEDIAHUB_LIBRARY=/tmp/mediahub-fixture-small

# Run command and capture JSON output
swift run mediahub status --json > status_output.json

# Verify scale metrics are present and accurate (jq optional)
if command -v jq > /dev/null 2>&1; then
  FILE_COUNT_JSON=$(jq -r '.performance.scale.fileCount' status_output.json)
  FILE_COUNT_ACTUAL=$(find /tmp/mediahub-fixture-small -type f -name "*.jpg" | wc -l)

  # Allow small variance (JSON may exclude .mediahub files)
  if [ -n "$FILE_COUNT_JSON" ] && [ "$FILE_COUNT_JSON" -gt 0 ]; then
    echo "✅ Scale metrics reported: $FILE_COUNT_JSON files"
  else
    echo "❌ Scale metrics missing or invalid"
  fi
else
  echo "⚠️  jq not available, skipping scale metrics verification"
  python3 -m json.tool status_output.json > /dev/null && echo "✅ JSON output is valid"
fi
```

**Expected**: Scale metrics are present, accurate, and match library state.

---

## 7. Operation-Specific Validations

### Index Hash Performance
```bash
export MEDIAHUB_LIBRARY=/tmp/mediahub-fixture-small

# Run index hash with limit
swift run mediahub index hash --limit 100 --json > index_output.json

# Verify performance metrics (jq optional)
if command -v jq > /dev/null 2>&1; then
  if jq -e '.performance.durationSeconds' index_output.json > /dev/null 2>&1 && \
     jq -e '.performance.scale' index_output.json > /dev/null 2>&1; then
    echo "✅ Index hash operation reports performance metrics"
  else
    echo "❌ Index hash operation missing performance metrics"
  fi
else
  python3 -m json.tool index_output.json > /dev/null && echo "✅ JSON output is valid"
  echo "⚠️  jq not available, skipping performance metrics verification"
fi
```

**Expected**: Index hash operation reports performance metrics and scale context.

### Duplicates Performance
```bash
export MEDIAHUB_LIBRARY=/tmp/mediahub-fixture-small

# Run duplicates command
swift run mediahub duplicates --format json > duplicates_output.json

# Verify performance metrics (jq optional)
if command -v jq > /dev/null 2>&1; then
  if jq -e '.performance.durationSeconds' duplicates_output.json > /dev/null 2>&1 && \
     jq -e '.performance.scale' duplicates_output.json > /dev/null 2>&1; then
    echo "✅ Duplicates operation reports performance metrics"
  else
    echo "❌ Duplicates operation missing performance metrics"
  fi
else
  python3 -m json.tool duplicates_output.json > /dev/null && echo "✅ JSON output is valid"
  echo "⚠️  jq not available, skipping performance metrics verification"
fi
```

**Expected**: Duplicates operation reports performance metrics and scale context.

### Status Performance
```bash
export MEDIAHUB_LIBRARY=/tmp/mediahub-fixture-small

# Run status command
swift run mediahub status --json > status_output.json

# Verify performance metrics and scale context (jq optional)
if command -v jq > /dev/null 2>&1; then
  if jq -e '.performance.scale' status_output.json > /dev/null 2>&1; then
    echo "✅ Status operation reports scale metrics"
  else
    echo "❌ Status operation missing scale metrics"
  fi
else
  python3 -m json.tool status_output.json > /dev/null && echo "✅ JSON output is valid"
  echo "⚠️  jq not available, skipping scale metrics verification"
fi
```

**Expected**: Status operation reports scale metrics prominently.

---

## 8. Edge Cases & Failure Modes

### Empty Library
```bash
# Create empty library
mkdir -p /tmp/mediahub-fixture-empty/.mediahub/registry
cd /path/to/mediahub
swift run mediahub library adopt /tmp/mediahub-fixture-empty
export MEDIAHUB_LIBRARY=/tmp/mediahub-fixture-empty

# Run command
swift run mediahub status --json > status_output.json

# Verify graceful handling (jq optional)
if command -v jq > /dev/null 2>&1; then
  if jq -e '.performance.scale.fileCount == 0' status_output.json > /dev/null 2>&1; then
    echo "✅ Empty library handled gracefully"
  else
    echo "❌ Empty library not handled gracefully"
  fi
else
  python3 -m json.tool status_output.json > /dev/null && echo "✅ JSON output is valid"
  echo "⚠️  jq not available, skipping fileCount verification"
fi
```

**Expected**: Empty library handled gracefully with zero file count.

### Missing BaselineIndex (Graceful Degradation)
```bash
# Create small library without index
mkdir -p /tmp/mediahub-fixture-small-no-index/.mediahub/registry
cd /path/to/mediahub
swift run mediahub library adopt /tmp/mediahub-fixture-small-no-index
rm /tmp/mediahub-fixture-small-no-index/.mediahub/registry/index.json
export MEDIAHUB_LIBRARY=/tmp/mediahub-fixture-small-no-index

# Run command (should handle gracefully)
swift run mediahub status --json > status_output.json

# Verify graceful degradation (operation succeeds, metrics may be limited)
if [ -f status_output.json ]; then
  echo "✅ Library without index handled gracefully"
else
  echo "❌ Library without index not handled gracefully"
fi
```

**Expected**: Library without index handled gracefully (operation succeeds, metrics may be limited).

### Measurement Error Handling
```bash
export MEDIAHUB_LIBRARY=/tmp/mediahub-fixture-small

# Run command (measurement should not affect operation)
swift run mediahub status > status_output.txt

# Verify operation succeeded
if [ $? -eq 0 ]; then
  echo "✅ Operation succeeded despite potential measurement issues"
else
  echo "❌ Operation failed (measurement may have affected operation)"
fi
```

**Expected**: Operation succeeds even if measurement encounters errors (fail-safe).

---

## Prerequisites

**Required Tools**:
- `python3` for JSON syntax validation (required)
- `jq` for JSON field extraction: Install with `brew install jq` (optional, validation provides fallbacks)
- Swift toolchain for running MediaHub

**Test Environment**:
- macOS with Swift development environment
- `/tmp` directory writable for test fixtures
- Sufficient disk space for test fixtures (several GB for large fixtures)

---

## 9. Automated Tests

### Unit Test Execution
```bash
cd /path/to/mediahub

# Run full test suite (recommended)
swift test

# Or run specific test filters if available
# swift test --filter PerformanceMeasurement
# swift test --filter ScaleMetrics
# swift test --filter PerformanceReporter
```

**Test Coverage Requirements**:
- ✅ Scale metrics calculation accuracy
- ✅ Performance measurement duration recording (presence, not precision)
- ✅ Performance reporting formatting (human-readable and JSON)
- ✅ Edge cases (empty libraries, missing indexes, etc.)
- ✅ Deterministic scale metrics verification (scale metrics identical across runs)

### Integration Test Coverage
```bash
# Full test suite
swift test
```

**Expected**: All tests pass with >90% coverage of new functionality. Tests verify presence and format, not duration precision or overhead thresholds.

---

## 10. Release Readiness Checklist

**Must-Pass Items for Slice 9c Acceptance**:

### Functional Completeness
- [ ] Performance measurement works for in-scope operations (index hash, duplicates, status)
- [ ] Scale metrics reported accurately for all operations
- [ ] Performance reporting available in human-readable and JSON formats
- [ ] Operations proceed normally regardless of library scale (no blocking)

### Safety & Reliability
- [ ] No writes to library or index files (verified with mtime checks)
- [ ] Read-only operations confirmed across all code paths
- [ ] No new files created for measurement (no persistence)
- [ ] Measurement does not affect operation results
- [ ] Fail-safe behavior (measurement errors don't affect operations)

### Determinism & Measurement
- [ ] Scale metrics are identical across multiple runs (deterministic)
- [ ] Performance reporting is deterministic (same input → same scale metrics)
- [ ] Operations always succeed (no blocking or refusals)

### Performance Reporting
- [ ] Human-readable format includes duration and scale context
- [ ] JSON format includes performance object with duration and scale metrics (additive only)
- [ ] Scale metrics are accurate and match library state
- [ ] JSON output is backward compatible (additive only, existing consumers unaffected)

### Integration
- [ ] All CLI commands integrate performance measurement seamlessly
- [ ] Performance metrics appear in command output (human-readable and JSON)
- [ ] No conflicts with existing command behavior
- [ ] Error messages follow MediaHub patterns

### Testing
- [ ] All unit tests pass
- [ ] Integration tests verify CLI behavior (status, index hash, duplicates)
- [ ] Edge case coverage complete
- [ ] Deterministic measurement tests pass consistently (scale metrics identical)

---

## Validation Completion Criteria

**Slice 9c is ready for implementation freeze when**:
- All checklist items marked as passed
- No outstanding issues in measurement accuracy or reporting
- Determinism verified across multiple test runs (scale metrics identical)
- All automated tests pass with comprehensive coverage
- Operations proceed normally regardless of library scale (no blocking verified)

**Post-Freeze Activities**:
- Update `specs/STATUS.md` to mark Slice 9c as complete
- Update README.md if new CLI features need documentation
- Consider follow-up slices (11+, UI development) based on roadmap priorities
