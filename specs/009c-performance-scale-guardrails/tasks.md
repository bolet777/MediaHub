# Slice 9c — Performance & Scale Observability

**Document Type**: Slice Implementation Tasks
**Slice Number**: 9c
**Title**: Performance & Scale Observability
**Author**: Spec-Kit Orchestrator
**Date**: 2026-01-27
**Status**: Draft

---

## Task Overview

This document breaks down the implementation of Slice 9c into 5 main tasks, designed as SAFE implementation passes. All tasks maintain strict read-only behavior, deterministic measurement guarantees, and zero state mutations.

**Key Constraints Applied**:
- Read-only measurement (zero writes, zero mutations)
- Non-invasive design (wrappers only, no core logic changes)
- Deterministic scale metrics (same input → identical scale metrics)
- Minimal overhead (non-normative target: <1% of operation time)
- Fail-safe behavior (measurement errors don't affect operations)
- Strictly observational (no operation blocking or refusals)

---

## Task 1: ScaleMetrics Foundation

**Purpose**: Implement the `ScaleMetrics` value type and collection logic for library and source scale characteristics.

**Expected Files/Touchpoints**:
- `Sources/MediaHub/ScaleMetrics.swift` (new)
- `Tests/MediaHubTests/ScaleMetricsTests.swift` (new)

**Subtasks**:
- Define `ScaleMetrics` struct with file count, total size, hash coverage
- Implement library scale metrics collection from BaselineIndex
- Add hash coverage percentage calculation
- Implement unit tests for all metric calculations

**Done When**:
- `ScaleMetrics` can be constructed from BaselineIndex with accurate file count, size, hash coverage
- Hash coverage percentage calculation is accurate (handles nil hashes correctly)
- Unit tests pass with >90% coverage
- All metric calculations are deterministic (same input → same output)

**References**: spec.md sections "Scale Dimensions & Characteristics", plan.md section "Scale Metrics Collection Strategy"

---

## Task 2: PerformanceMeasurement Core

**Purpose**: Implement execution time tracking and performance measurement infrastructure.

**Expected Files/Touchpoints**:
- `Sources/MediaHub/PerformanceMeasurement.swift` (new)
- `Tests/MediaHubTests/PerformanceMeasurementTests.swift` (new)

**Subtasks**:
- Implement execution time tracking using system clock (Date/TimeInterval)
- Create measurement context that tracks start/stop times
- Implement duration calculation (wall-clock time)
- Add measurement result type with duration and scale metrics
- Implement unit tests for duration presence and recording

**Done When**:
- Execution time tracking records operation duration (informational, may vary)
- Measurement context correctly tracks start and stop times
- Duration calculation produces results (may be null for fast operations)
- Unit tests verify duration is recorded when present
- Duration measurement is informational only (may vary across runs, may be null)

**References**: spec.md sections "Performance Measurement", plan.md section "PerformanceMeasurement"

---

## Task 3: PerformanceReporter Implementation

**Purpose**: Implement performance reporting in human-readable and JSON formats.

**Expected Files/Touchpoints**:
- `Sources/MediaHub/PerformanceReporter.swift` (new)
- `Sources/MediaHubCLI/OutputFormatting.swift` (extend)
- `Tests/MediaHubTests/PerformanceReporterTests.swift` (new)

**Subtasks**:
- Implement human-readable performance reporting (duration, scale context)
- Implement JSON performance reporting (duration, scale metrics object)
- Format duration in appropriate units (seconds, minutes)
- Format scale metrics for display (file count, size, hash coverage)
- Integrate with existing OutputFormatting utilities
- Add unit tests for formatting accuracy (human-readable and JSON)

**Done When**:
- Human-readable output includes duration and scale context
- JSON output includes performance object with duration and scale metrics (additive only)
- Duration formatting is human-readable (seconds or minutes/seconds)
- Scale metrics formatting is concise and clear
- JSON output is backward compatible (additive only)
- Unit tests verify formatting accuracy for all scenarios

**References**: spec.md sections "Performance Reporting", plan.md section "Performance Reporting Strategy"

---

## Task 4: CLI Command Integration - Index Hash, Duplicates & Status

**Purpose**: Add performance measurement and scale metrics reporting to index hash, duplicates, and status commands.

**Expected Files/Touchpoints**:
- `Sources/MediaHubCLI/IndexCommand.swift` (modify)
- `Sources/MediaHubCLI/DuplicatesCommand.swift` (modify)
- `Sources/MediaHubCLI/StatusCommand.swift` (modify)
- Integration tests

**Subtasks**:
- Wrap index hash operation with performance measurement
- Wrap duplicates operation with performance measurement
- Add scale metrics reporting to status command
- Add performance reporting to command output (human-readable and JSON)
- No new flags or command modifications beyond reporting

**Done When**:
- `mediahub index hash` reports performance metrics and scale context
- `mediahub duplicates` reports performance metrics and scale context
- `mediahub status` displays scale metrics prominently
- JSON output includes performance object (additive only, backward compatible)
- Human-readable output includes performance summary
- Existing output structure is preserved (no reformatting; performance data appended additively only)
- Integration tests verify measurement and reporting work correctly

**References**: spec.md sections "In-Scope CLI Operations", plan.md section "CLI Integration Points"

---

## Task 5: Comprehensive Testing and Validation

**Purpose**: Implement comprehensive test coverage and validate all performance measurement and reporting functionality.

**Expected Files/Touchpoints**:
- `Tests/MediaHubTests/PerformanceMeasurementTests.swift` (extend)
- `Tests/MediaHubTests/ScaleMetricsTests.swift` (extend)
- `Tests/MediaHubTests/PerformanceReporterTests.swift` (extend)
- Integration tests for all CLI commands

**Subtasks**:
- Unit tests for all components (ScaleMetrics, PerformanceMeasurement, PerformanceReporter)
- Integration tests for CLI command measurement (status, index hash, duplicates)
- Deterministic scale metrics tests (same input → identical scale metrics)
- Edge case testing (empty libraries, missing indexes, large libraries)
- JSON output schema validation
- Performance reporting accuracy validation (presence and format, not precision)

**Done When**:
- All unit tests pass with >90% coverage
- Integration tests verify CLI behavior matches spec requirements
- Deterministic scale metrics tests pass consistently (scale metrics identical across runs)
- Edge cases are covered with appropriate test scenarios
- JSON output is valid and backward compatible (additive only)
- Performance reporting is present and human-readable (duration informational, scale metrics accurate)

**References**: spec.md sections "Success Metrics", "Safety Guarantees", "Determinism Guarantees", plan.md section "Testing Strategy"

---

## Validation Mapping (Light Preview)

**Mapping to validation.md requirements** (detailed implementation in Phase 4):
- **Functional**: Tasks 1-4 verify scale metrics, performance measurement, and reporting for in-scope operations
- **Safety**: All tasks enforce read-only behavior, zero writes verified in tests
- **Determinism**: Tasks 2, 5 ensure identical metrics for identical library states
- **Edge Cases**: Task 5 covers all failure modes and edge cases from spec.md
- **Integration**: Task 4 verifies seamless CLI command integration (status, index hash, duplicates)

---

## Implementation Order and Dependencies

**Sequential Implementation Order**:
1. ScaleMetrics Foundation (Task 1) - Foundation for all other components
2. PerformanceMeasurement Core (Task 2) - Core measurement infrastructure
3. PerformanceReporter Implementation (Task 3) - Output formatting
4. CLI Command Integration (Task 4) - Command wrappers (status, index hash, duplicates)
5. Comprehensive Testing (Task 5) - Continuous throughout, final validation

**Parallel Opportunities**:
- Tasks 2 and 3 can be developed in parallel (PerformanceMeasurement and PerformanceReporter)
- Unit tests can be developed alongside implementation tasks
- Integration tests can be developed after CLI integration tasks

**No Circular Dependencies**: Each task builds incrementally on previous tasks with clear interfaces.

---

## Task Dependencies Graph

```
Task 1 (ScaleMetrics)
  ↓
Task 2 (PerformanceMeasurement) ──┐
  ↓                                 │
Task 3 (PerformanceReporter) ───────┼──→ Task 4 (CLI: Status/Index/Duplicates)
  ↓                                 │
Task 5 (Testing) ───────────────────┘
```

**Critical Path**: Task 1 → Task 2 → Task 3 → Task 4 → Task 5

---

## Self-Review

**Scope Check**: ✅
- Tasks break down plan into safe, reviewable implementation passes (5 tasks max)
- Each task has clear purpose and "done when" criteria
- Tasks maintain strictly observational scope (no blocking, no refusals)
- No algorithmic optimizations or UI work included
- Focused on status, index hash, duplicates only (detect/import deferred)

**Safety Check**: ✅
- All tasks enforce read-only behavior (zero writes)
- Measurement is non-invasive (wrappers only)
- Fail-safe behavior maintained (measurement errors don't affect operations)
- No state mutation or persistence

**Determinism / Idempotence Check**: ✅
- Tasks ensure scale metrics are deterministic (same library state → identical scale metrics)
- Duration is informational and may vary across runs
- Measurement is idempotent (no accumulated state)
- Testing tasks verify scale metrics determinism

**Proceeding to next phase**: validation.md
