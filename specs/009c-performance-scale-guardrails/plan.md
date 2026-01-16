# Slice 9c — Performance & Scale Observability

**Document Type**: Slice Implementation Plan
**Slice Number**: 9c
**Title**: Performance & Scale Observability
**Author**: Spec-Kit Orchestrator
**Date**: 2026-01-27
**Status**: Draft

---

## High-Level Architecture

Slice 9c adds performance measurement and scale metrics reporting to MediaHub CLI operations through a lightweight, non-invasive measurement layer. The architecture maintains separation of concerns by introducing measurement and reporting components that wrap existing operations without modifying core business logic:

- **Measurement Layer**: Execution time tracking and scale metric collection
- **Reporting Layer**: Human-readable and JSON performance reporting
- **Integration Points**: Minimal wrappers around existing CLI commands (status, index hash, duplicates)

The design follows MediaHub's established patterns: read-only operations, deterministic behavior, and zero state mutation. Measurement is transparent, automatic, and non-invasive. All operations proceed normally regardless of scale metrics.

---

## Core Components and Responsibilities

### PerformanceMeasurement (New Component)
**Purpose**: Central orchestrator for performance measurement during CLI operations.

**Responsibilities**:
- Track execution time using system clock
- Collect scale metrics from existing data structures (BaselineIndex, LibraryStatistics)
- Provide measurement results for reporting

**Dependencies**: `BaselineIndex`, `LibraryStatistics`, `LibraryContext`

**Measurement Strategy**:
- Start timer at operation beginning
- Stop timer at operation completion
- Calculate duration (wall-clock time)
- Extract scale metrics from operation inputs/outputs

### ScaleMetrics (New Value Type)
**Purpose**: Immutable representation of library/source scale characteristics.

**Structure**:
- `fileCount: Int` - Total files in library
- `totalSizeBytes: Int64` - Total size in bytes
- `hashCoveragePercent: Double?` - Hash coverage percentage (if applicable)

**Computation**:
- Derived from BaselineIndex for library metrics
- Computed on-demand, not persisted
- Cached during operation execution to avoid recomputation

### AdvisoryWarning (Optional Component)
**Purpose**: Optionally provides informational context about library scale (never blocking).

**Responsibilities** (if implemented):
- Evaluate scale metrics for informational context
- Generate optional advisory messages
- Never block or refuse operations

**Integration**:
- Optional, informational only
- Non-blocking (operation always continues)
- May be omitted entirely if not needed

### PerformanceReporter (New Component)
**Purpose**: Formats and outputs performance metrics in human-readable and JSON formats.

**Responsibilities**:
- Format execution time in human-readable units (seconds, minutes)
- Format scale metrics for display
- Generate JSON output with performance data
- Integrate with existing CLI output formatting

**Output Formats**:
- **Human-Readable**: "Processed 10,000 files in 45 seconds"
- **JSON**: `{"durationSeconds": 45, "fileCount": 10000, "scale": {...}}`

**Integration**:
- Reuses existing `OutputFormatting` utilities where applicable
- Follows existing JSON output patterns
- Integrates with command output streams

---

## Data Flow

```
Operation Input → ScaleMetrics Collection → Operation Execution → PerformanceMeasurement → PerformanceReporter → Output

Detailed Flow:
1. Operation begins (e.g., index hash, duplicates, status)
2. Collect scale metrics from BaselineIndex/LibraryStatistics
3. Start performance timer
4. Execute operation (existing business logic, unchanged)
5. Stop performance timer
6. PerformanceReporter formats results:
   - Human-readable: "Operation completed in X seconds"
   - JSON: {"durationSeconds": X, "scale": {...}} (additive only)
7. Output to stdout or JSON stream
8. Optional: Advisory warning may be emitted (informational, non-blocking)
```

**Measurement Overhead** (non-normative targets):
- Scale metrics collection: target <100ms (from existing data structures)
- Performance timing: target <1ms (system clock access)
- Reporting: target <50ms (string formatting)
- Total overhead: target <150ms per operation (target <1% of typical operation time)

**Deterministic Scale Metrics**:
- Same library state produces identical scale metrics (fileCount, totalSizeBytes, hashCoveragePercent)
- Scale metrics are calculated deterministically from BaselineIndex
- Measurement does not affect operation determinism

**Duration Measurement**:
- Duration is informational and best-effort
- Duration may vary across runs due to system timing
- Duration may be null for very fast operations

---

## CLI Integration Points

**Command Wrappers**:
Extend existing CLI commands with performance measurement wrappers. Commands remain unchanged; measurement is added as a transparent layer.

**Integration Points**:
- `IndexHashCommand`: Measure hash computation time, report library scale and coverage
- `DuplicatesCommand`: Measure duplicate analysis time, report library scale
- `StatusCommand`: Report scale metrics prominently (already fast, minimal measurement)

**Command Modifications**:
- Add performance metrics to existing JSON output (additive only, backward compatible)
- Add human-readable performance context to existing output
- No changes to command argument parsing or core logic
- No new flags or options
- **Explicit**: Slice 9c introduces zero new CLI flags; performance reporting is always opportunistic and additive

**Library Selection**: Reuses existing `LibraryContext` for library selection and validation.

**Error Handling**: Reuses existing `CLIError` patterns. No new error types for refusals.

---

## Scale Metrics Collection Strategy

### Library Scale Metrics
**Source**: BaselineIndex, LibraryStatistics

**Metrics Collected**:
- File count: `BaselineIndex.entries.count`
- Total size: Sum of `BaselineIndex.entries.map(\.sizeBytes)`
- Hash coverage: Percentage of entries with non-nil hash
- Index size: `BaselineIndex.entries.count`
- Path depth: Maximum depth from `BaselineIndex.entries.map(\.path).maxDepth`

**Collection Timing**:
- Before operation begins (for reporting)
- Cached during operation to avoid recomputation
- Reused for performance reporting

**Performance** (non-normative targets):
- Single pass over BaselineIndex entries
- O(n) where n = index entry count
- Target: <100ms for libraries up to 100K files (informational goal)

### Operation-Specific Metrics
**Index Hash Operation**:
- Library scale (from BaselineIndex)
- Hash computation duration
- Files processed count
- Hash coverage before/after

**Duplicates Operation**:
- Library scale (from BaselineIndex)
- Duplicate analysis duration
- Duplicate groups count
- Total duplicate files count

**Status Operation**:
- Library scale (from BaselineIndex)
- Statistics computation duration (minimal)
- All statistics from LibraryStatistics

---

## Advisory Warnings Strategy (Optional)

**Note**: Advisory warnings are optional and may be omitted entirely. If implemented, they are strictly informational and never blocking.

### Optional Advisory Context

**Evaluation Timing**: After operation completes, or during operation (non-blocking)

**Advisory Conditions** (if implemented):
1. **Large library scale**: File count >100K → Optional informational note
2. **Low hash coverage**: Hash coverage <50% → Optional informational note

**Advisory Process** (if implemented):
1. After operation completes, optionally evaluate scale metrics
2. If advisory conditions met, emit informational message to stderr
3. Operation always continues normally (never blocked)

**Advisory Format** (if implemented):
- Clear, informational message (not a warning)
- Include relevant scale metrics for context
- Suggest optional remediation steps
- Non-intrusive (does not interrupt operation flow)

**No Refusals**: Slice 9c does not implement operation refusals or blocking mechanisms.

---

## Performance Reporting Strategy

### Human-Readable Reporting

**Integration Points**:
- Append performance summary to existing operation output
- Include scale context in operation messages
- Format duration in appropriate units (seconds, minutes)

**Output Examples**:
```
Hashed 1,000 files in 45.8 seconds
(Library: 25,000 files, 45.2 GB, 99% hash coverage after operation)

Duplicate analysis completed in 2.1 seconds
(Library: 25,000 files, 45.2 GB, 99% hash coverage)
Found 3 duplicate groups containing 12 files

Status: Library contains 25,000 files, 45.2 GB, 99% hash coverage
```

**Formatting**:
- Duration: "X seconds" or "X minutes Y seconds" (human-readable)
- Scale: "X files, Y GB, Z% hash coverage" (concise)
- Context: Parenthetical, non-intrusive

### JSON Reporting

**Integration Points**:
- Extend existing JSON output with performance fields
- Add `performance` object to command JSON output
- Maintain backward compatibility (performance fields optional)

**JSON Structure** (additive only, backward compatible):
```json
{
  "operation": "index hash",
  "filesProcessed": 1000,
  "performance": {
    "durationSeconds": 45.8,
    "scale": {
      "fileCount": 25000,
      "totalSizeBytes": 48516300800,
      "hashCoveragePercent": 99.0
    }
  }
}
```

**Backward Compatibility**:
- Performance fields are additive (existing JSON consumers unaffected)
- Performance object omitted if measurement unavailable
- Scale metrics follow existing JSON patterns

---

## Testing Strategy

### Unit Testing
- `PerformanceMeasurementTests`: Execution time tracking accuracy
- `ScaleMetricsTests`: Scale metric calculation correctness
- `PerformanceReporterTests`: Output formatting accuracy (human-readable and JSON)

### Integration Testing
- End-to-end CLI command testing with performance measurement (status, index hash, duplicates)
- Performance reporting validation across all commands
- JSON output schema validation

### Validation Testing
- Deterministic scale metrics verification (same input → identical scale metrics)
- Scale metrics calculation accuracy
- Edge case handling (empty libraries, missing indexes, etc.)

**Test Infrastructure Reuse**: Leverages existing test patterns for CLI commands, index handling, and output validation.

---

## Implementation Touchpoints

**Minimal File Changes Expected**:

**New Files**:
- `Sources/MediaHub/PerformanceMeasurement.swift`
- `Sources/MediaHub/ScaleMetrics.swift`
- `Sources/MediaHub/PerformanceReporter.swift`
- `Tests/MediaHubTests/PerformanceMeasurementTests.swift`
- `Tests/MediaHubTests/ScaleMetricsTests.swift`
- `Tests/MediaHubTests/PerformanceReporterTests.swift`

**Modified Files**:
- `Sources/MediaHubCLI/IndexCommand.swift` (add measurement wrapper)
- `Sources/MediaHubCLI/DuplicatesCommand.swift` (add measurement wrapper)
- `Sources/MediaHubCLI/StatusCommand.swift` (add scale metrics reporting)
- `Sources/MediaHubCLI/OutputFormatting.swift` (extend for performance reporting)

**No Changes To**:
- Core import/detection/hashing logic
- BaselineIndex structure
- LibraryStatistics structure
- Source scanning logic
- Duplicate detection logic

---

## Risk Mitigation

**Architecture Risks**:
- **Measurement Overhead**: Mitigated by lightweight measurement (system clock only, minimal computation)
- **Non-Determinism**: Mitigated by deterministic scale metrics (no random factors in scale calculation)
- **Integration Complexity**: Mitigated by minimal touchpoints (wrappers only, no core changes)

**Performance Risks**:
- **Measurement Slowing Operations**: Mitigated by minimal overhead target and lightweight measurement
- **Scale Metrics Collection Cost**: Mitigated by single-pass collection and caching

**User Experience Risks**:
- **Over-Warning**: Mitigated by making warnings optional and informational only
- **Measurement Intrusion**: Mitigated by transparent, non-blocking measurement

**Compatibility Risks**:
- **JSON Schema Changes**: Mitigated by additive-only changes (backward compatible)
- **Command Behavior Changes**: Mitigated by transparent measurement (no logic changes)
- **BaselineIndex Dependency**: Mitigated by graceful degradation (metrics optional if unavailable)

---

## Sequencing and Dependency Order

**Implementation Order**:
1. **ScaleMetrics**: Foundation for all other components (no dependencies)
2. **PerformanceMeasurement**: Core measurement infrastructure (depends on ScaleMetrics)
3. **PerformanceReporter**: Output formatting (depends on PerformanceMeasurement, ScaleMetrics)
4. **CLI Integration**: Command wrappers (depends on all above components) - status, index hash, duplicates only
5. **Testing**: Comprehensive test coverage (depends on all components)

**Parallel Opportunities**:
- ScaleMetrics and PerformanceMeasurement can be developed in parallel
- Unit tests can be developed alongside implementation

**No Circular Dependencies**: Each component has clear dependencies and interfaces.

---

## Self-Review

**Scope Check**: ✅
- High-level architecture defined without implementation details
- No Swift APIs or concrete code specified
- Focus on measurement and reporting only (strictly observational)
- Clear separation of concerns
- All components are wrappers only (no core logic changes)

**Safety Check**: ✅
- Read-only measurement (zero writes)
- Non-invasive design (wrappers only)
- Fail-safe behavior (measurement errors don't affect operations)
- No state mutation or persistence

**Determinism / Idempotence Check**: ✅
- Scale metrics are deterministic (same library state → identical scale metrics)
- Duration is informational and may vary across runs
- Measurement is idempotent (no accumulated state)

**Proceeding to next phase**: tasks.md
