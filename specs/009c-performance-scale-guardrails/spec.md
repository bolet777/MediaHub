# Slice 9c — Performance & Scale Observability

**Document Type**: Slice Specification
**Slice Number**: 9c
**Title**: Performance & Scale Observability
**Author**: Spec-Kit Orchestrator
**Date**: 2026-01-27
**Status**: Draft

---

## Overview

**Goal**: Establish performance measurement and scale metrics reporting for MediaHub CLI operations to provide visibility into library characteristics and operation duration.

**Problem Statement**: As MediaHub libraries grow in size (file count, total size, hash coverage), users need visibility into their library scale and operation performance to make informed decisions. Without explicit metrics, users cannot understand their library characteristics or predict operation duration. Additionally, future UI development requires observable performance characteristics.

**Success Criteria**:
- Users can see scale metrics (file count, size, hash coverage) for their libraries
- Operation duration is measured and reported
- Performance metrics are available in human-readable and JSON formats
- Advisory warnings provide context when library scale is large
- All measurement and reporting is read-only and non-invasive

**Scope**: Strictly observational performance measurement and scale metrics reporting. No algorithmic optimizations, no operation blocking, no policy enforcement. Advisory warnings only.

---

## Requirements

### Core Functionality

**Performance Measurement**
- Measure execution time for CLI operations (index hash, duplicates, status)
- Report operation duration in human-readable format
- Duration is informational and expected to vary across runs (best-effort)

**Scale Characteristics**
- Define scale dimensions: file count, total library size, hash coverage percentage
- Collect scale metrics from BaselineIndex and LibraryStatistics
- Report scale metrics in operation output (file count, size, coverage)

**Performance Reporting**
- Report operation duration in human-readable format
- Include scale metrics in operation output (file count, size, coverage)
- Support JSON output for programmatic analysis (additive only, backward compatible)

**Advisory Warnings**
- Optionally warn users when library scale is large (informational only)
- Provide context about library characteristics
- Never block or refuse operations

### Safety & Operational Requirements

**Read-Only Operations**
- All performance measurement is read-only (zero writes to library or index)
- Measurement does not modify library state or metadata
- Performance reporting does not affect operation determinism
- Compatible with dry-run philosophy

**Deterministic Behavior**
- Scale metrics are deterministic (same library state produces identical scale metrics)
- Duration measurements are informational and may vary across runs
- Measurement overhead is minimal and predictable
- No performance measurement affects operation correctness

**Non-Invasive Measurement**
- Performance measurement does not require special modes or flags
- Measurement is automatic and transparent to users
- No additional I/O operations beyond what operations already perform
- Measurement overhead is minimal (see Non-Normative Targets below)

**Scale Dimensions**
- **File Count**: Total number of media files in library (from BaselineIndex)
- **Total Library Size**: Sum of file sizes in library (from BaselineIndex)
- **Hash Coverage**: Percentage of files with computed hashes (from BaselineIndex)

### Advisory Warnings (Informational Only)

**Warning Examples** (for reference, not enforced):
- Large library scale: Library with >100,000 files may benefit from organization
- Low hash coverage: Hash coverage <50% may impact duplicate detection performance
- These are informational signals only, never blocking

**No Refusals**: Slice 9c does not prevent or refuse any operations. All operations proceed normally regardless of scale metrics.

---

## In-Scope CLI Operations

**Operations Requiring Performance Measurement**:
- `mediahub index hash [--limit N]` - Hash computation and index updates
- `mediahub duplicates` - Duplicate reporting
- `mediahub status` - Library status and statistics

**Operations Requiring Scale Reporting**:
- All operations above should report scale context (file count, size, coverage)
- `mediahub status` should include scale metrics prominently

**Operations NOT in Scope** (deferred to future slices):
- `mediahub detect <source-id>` - Deferred
- `mediahub import <source-id> --dry-run` - Deferred
- `mediahub library create/open/list` - Fast metadata operations
- `mediahub source attach/list` - Fast metadata operations
- `mediahub library adopt` - One-time operation

---

## Scale Dimensions & Characteristics

**Scale metrics are informational only, providing context about library characteristics:**

### File Count
- Total number of media files in library (from BaselineIndex)
- Reported as integer count

### Total Library Size
- Sum of file sizes in library (from BaselineIndex)
- Reported in bytes (Int64)

### Hash Coverage
- Percentage of files with computed hashes (from BaselineIndex)
- Reported as percentage (0.0-100.0)
- Optional (nil if not applicable)

---

## Performance Measurement Requirements

**Execution Time**:
- Measure wall-clock time for operation completion (best-effort, informational only)
- Report in human-readable format (seconds, minutes)
- Include in JSON output as `durationSeconds` field (optional, may be null, additive only)
- Duration measurement may be omitted or null without affecting operation correctness

**Scale Metrics**:
- Report file count, total size, hash coverage for context
- Include in operation output (human-readable and JSON)
- Enable users to understand their library scale

### JSON Contract

**Performance Object Structure**:
The `performance` object is an optional, additive field in JSON output. It does not modify existing JSON structure.

**Shape**:
```json
{
  "performance": {
    "durationSeconds": <number | null>,
    "scale": {
      "fileCount": <number>,
      "totalSizeBytes": <number>,
      "hashCoveragePercent": <number | null>
    }
  }
}
```

**Contract Guarantees**:
- The `performance` object is optional (may be omitted entirely)
- All fields are additive only (existing JSON consumers unaffected)
- `durationSeconds` is informational and may be `null` (especially for fast operations)
- `hashCoveragePercent` may be `null` if not applicable
- Scale metrics (`fileCount`, `totalSizeBytes`) are always present when `performance` object exists
- No thresholds or guarantees apply to duration values

---

## Safety Guarantees

**Read-Only Measurement**:
- Performance measurement never writes to library or index
- Measurement does not modify operation behavior
- Measurement is transparent and non-invasive

**Determinism Preservation**:
- Performance measurement does not affect operation determinism
- Same library state produces same results (with or without measurement)
- Scale metrics are deterministic (same library state → identical scale metrics)

**No State Mutation**:
- No new metadata files created for performance tracking
- No modification of existing metadata for measurement
- Performance data is ephemeral (reported, not persisted)

**Fail-Safe Behavior**:
- If performance measurement fails, operation continues normally
- Measurement errors do not affect operation success
- Performance reporting is best-effort, not required for operation success

---

## Determinism Guarantees

**Scale Metrics Determinism**:
- Same library state produces identical scale metrics (fileCount, totalSizeBytes, hashCoveragePercent)
- Scale metrics are calculated deterministically from BaselineIndex
- Measurement does not introduce non-determinism in scale metrics

**Duration Measurement**:
- Duration is informational and best-effort
- Duration may vary across runs due to system timing
- Duration may be null for very fast operations

**Consistent Reporting**:
- Scale metrics reported in consistent format
- Scale metrics use same calculation methods
- JSON output follows consistent schema

---

## Advisory Warnings (Optional, Informational Only)

**When to Provide Advisory Context**:
- Library scale is large (informational only)
- Hash coverage is low (informational only)
- These are optional signals, never blocking

**Warning Format** (if implemented):
- Clear, informational message
- Include scale metrics for context
- Suggest optional remediation steps (e.g., "consider running `mediahub index hash`")
- Non-blocking (operation always continues)

**Example Advisory Messages** (for reference):
```
Note: Library contains 150,000 files. Large libraries may take longer to process.
Consider running 'mediahub index hash' to improve duplicate detection performance.

Note: Hash coverage is 30%. Consider running 'mediahub index hash' to improve
duplicate detection accuracy.
```

**No Refusals**: Slice 9c does not implement operation refusals or blocking. All operations proceed normally regardless of scale metrics.

---

## Non-Goals / Out of Scope

**Algorithmic Optimizations**: This slice does not optimize algorithms or data structures. Performance improvements are out of scope unless strictly required to enable measurement.

**Background Processing**: No async operations, background threads, or scheduling. CLI remains synchronous and blocking.

**Performance Profiling**: No detailed profiling, flame graphs, or performance analysis tools. Only high-level metrics (duration, scale).

**Historical Performance Tracking**: No persistence of performance metrics over time. Metrics are ephemeral and reported per-operation.

**UI Performance Work**: No UI development or UI-specific performance considerations. This slice is CLI-only.

**Optimization Recommendations**: No automatic optimization suggestions beyond basic guardrail guidance. Users make optimization decisions.

**Real-Time Monitoring**: No continuous performance monitoring or background measurement. Measurement occurs only during CLI operations.

---

## Dependencies

**Slice Dependencies**:
- Slice 7 (Baseline Index) - Required for scale metrics (file count, size, hash coverage)
- Slice 8 (Advanced Hashing & Deduplication) - Required for hash coverage metrics
- Slice 9 (Hash Coverage & Maintenance) - Required for hash coverage reporting
- Slice 9b (Duplicate Reporting & Audit) - Required for duplicates operation measurement
- Slice 10 (Library Statistics) - Required for library scale metrics

**No External Dependencies**: This slice builds entirely on existing MediaHub infrastructure.

---

## Success Metrics

**Functional Completeness**:
- ✅ Performance measurement works for in-scope operations (index hash, duplicates, status)
- ✅ Scale metrics reported accurately for all operations
- ✅ Advisory warnings provide context when appropriate (optional, non-blocking)
- ✅ Performance reporting available in human-readable and JSON formats

**Safety & Reliability**:
- ✅ Read-only operations (zero writes, zero mutations)
- ✅ Measurement does not affect operation determinism
- ✅ Fail-safe behavior (measurement errors don't affect operations)

**User Experience**:
- ✅ Clear, informational scale metrics and duration reporting
- ✅ Performance context helps users understand operation duration
- ✅ Advisory warnings provide optional context (never blocking)
- ✅ JSON output enables programmatic performance analysis

**Non-Normative Performance Targets** (informational goals, not guarantees):
- Measurement overhead target: <1% of operation time
- Performance reporting target: <100ms
- Scale metrics calculation target: <1 second

---

## Implementation Notes

**Architecture Alignment**: This slice adds performance measurement and scale metrics reporting to existing CLI operations without modifying core business logic. Measurement is a cross-cutting concern that integrates with existing command infrastructure.

**Data Sources**: Leverages existing BaselineIndex, LibraryStatistics, and operation results for scale metrics. No new data structures required.

**Measurement Strategy**: Use system clock for execution time. Extract scale metrics from existing data structures (BaselineIndex). Avoid expensive measurement operations.

**Integration Points**: Minimal touchpoints in Core and CLI. Measurement wrappers around existing operations. No changes to core import/detection/hashing logic.

**Testing**: Comprehensive testing of measurement accuracy, scale metrics calculation, and edge cases. Verification that measurement overhead is minimal.

---

## Risk Assessment

**Low Risk**: This is a strictly observational slice. No changes to core business logic. Measurement is additive and non-invasive.

**Compatibility**: Requires BaselineIndex and LibraryStatistics infrastructure. Graceful degradation if metrics unavailable.

**Performance**: Measurement overhead must be minimal. Risk of measurement affecting operation performance is mitigated by keeping measurement lightweight.

**User Experience**: Risk of over-warning or under-warning. Mitigated by making warnings optional and informational only.

---

## Related Documents

- `specs/007-baseline-index/spec.md` - Baseline Index infrastructure
- `specs/008-advanced-hashing-dedup/spec.md` - Hash infrastructure
- `specs/009-hash-coverage-maintenance/spec.md` - Hash coverage maintenance
- `specs/009b-duplicate-reporting-audit/spec.md` - Duplicate reporting
- `specs/010-source-media-types-library-statistics/spec.md` - Library statistics
- `CONSTITUTION.md` - Project principles and constraints

---

## Self-Review

**Scope Check**: ✅
- Focused on measurement and reporting only (strictly observational)
- No algorithmic optimizations or UI work
- No operation blocking or refusals
- Clear boundaries with future slices
- Advisory warnings only (optional, informational)

**Safety Check**: ✅
- All operations are read-only (zero writes)
- Measurement is non-invasive and transparent
- Fail-safe behavior (measurement errors don't affect operations)
- No state mutation or persistence

**Determinism / Idempotence Check**: ✅
- Scale metrics are deterministic (same library state → identical scale metrics)
- Duration is informational and may vary across runs
- Measurement does not affect operation determinism
- Measurement is idempotent (no accumulated state)

**Proceeding to next phase**: plan.md
