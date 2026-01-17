# Implementation Plan: Progress + Cancel API minimale

**Feature**: Progress + Cancel API minimale  
**Specification**: `specs/014-progress-cancel-api-minimale/spec.md`  
**Slice**: 14 - Add progress reporting and cancellation support to core operations (detect, import, hash)  
**Created**: 2026-01-27

## Plan Scope

This plan implements **Slice 14 only**, which adds minimal progress reporting and cancellation support to Core operations (detection, import, hash maintenance). This includes:

- Progress API types (`ProgressUpdate`, `CancellationToken`, `CancellationError`)
- Progress callback support for `DetectionOrchestrator.executeDetection`
- Cancellation support for `DetectionOrchestrator.executeDetection`
- Progress callback support for `ImportExecutor.executeImport`
- Cancellation support for `ImportExecutor.executeImport`
- Progress callback support for `HashCoverageMaintenance.computeMissingHashes`
- Cancellation support for `HashCoverageMaintenance.computeMissingHashes`
- Progress throttling (maximum 1 update per second)
- Thread-safe cancellation token implementation

**Explicitly out of scope**:
- UI progress bars or cancel buttons (deferred to Slice 15)
- CLI progress output format changes (CLI continues to use `ProgressIndicator`)
- Progress persistence across app restarts
- Batch progress reporting
- Time-based progress estimation
- Cancellation callbacks (cancellation signaled via `CancellationError` only)

## Goals / Non-Goals

### Goals
- Add minimal progress reporting API to Core operations (detect, import, hash)
- Add minimal cancellation API to Core operations (detect, import, hash)
- Maintain backward compatibility (all parameters optional with `nil` defaults)
- Ensure no additional allocations or work when progress/cancel are `nil` (conceptual guarantee)
- Ensure thread-safe cancellation token
- Implement progress throttling to avoid callback overhead

### Non-Goals
- UI integration (deferred to Slice 15)
- CLI progress output changes (CLI continues to use `ProgressIndicator`)
- Progress persistence
- Batch progress reporting
- Time-based progress estimation
- Cancellation callbacks

## Proposed Architecture

### Module Structure

The implementation adds new types to the existing `MediaHub` framework (Core layer) and modifies existing Core API methods to accept optional progress/cancel parameters.

**Targets**:
- `MediaHub` (Core framework, existing)
  - New `Progress.swift` file with `ProgressUpdate`, `CancellationToken`, `CancellationError`
  - Modified `DetectionOrchestration.swift` (add progress/cancel parameters)
  - Modified `ImportExecution.swift` (add progress/cancel parameters)
  - Modified `HashCoverageMaintenance.swift` (add progress/cancel parameters)

**Boundaries**:
- **Core Layer**: Progress/cancel API types and integration into existing operations
- **CLI Layer**: May optionally use Core progress API internally, but user-facing output unchanged
- **UI Layer**: Not modified in this slice (deferred to Slice 15)

### Component Overview

#### Progress API Types (`Progress.swift`)

1. **ProgressUpdate** (`public struct ProgressUpdate`)
   - Value type with `stage: String`, `current: Int?`, `total: Int?`, `message: String?`
   - Thread-safe by design (value type)

2. **CancellationToken** (`public final class CancellationToken`)
   - Thread-safe cancellation token using `OSAllocatedUnfairLock` (Swift 5.9+) or `NSLock` (fallback)
   - Methods: `init()`, `func cancel()`, `var isCanceled: Bool`
   - All methods and properties are thread-safe

3. **CancellationError** (`public enum CancellationError: Error, LocalizedError`)
   - Single case: `cancelled`
   - Conforms to `Error` and `LocalizedError`

#### Detection Integration (`DetectionOrchestration.swift`)

4. **Progress Reporting**
   - Add optional `progress: ((ProgressUpdate) -> Void)? = nil` parameter to `executeDetection`
   - Invoke progress callback during scanning stage (with item counts)
   - Invoke progress callback during comparison stage (with item counts)
   - Invoke progress callback at completion (with final counts)
   - Throttle progress callbacks to maximum 1 update per second

5. **Cancellation Support**
   - Add optional `cancellationToken: CancellationToken? = nil` parameter to `executeDetection`
   - Check cancellation between items during scanning (safe point)
   - Check cancellation between items during comparison (safe point)
   - Throw `CancellationError.cancelled` if cancellation requested
   - Ensure no library state modification if canceled

#### Import Integration (`ImportExecution.swift`)

6. **Progress Reporting**
   - Add optional `progress: ((ProgressUpdate) -> Void)? = nil` parameter to `executeImport`
   - Invoke progress callback during import loop with current/total counts (e.g., current=5, total=100)
   - Throttle progress callbacks to maximum 1 update per second

7. **Cancellation Support**
   - Add optional `cancellationToken: CancellationToken? = nil` parameter to `executeImport`
   - Check cancellation between items (after current item import completes atomically)
   - Throw `CancellationError.cancelled` if cancellation requested
   - Ensure already-imported items remain (no rollback)
   - Ensure no partial file state (current item completes before cancellation)

#### Hash Maintenance Integration (`HashCoverageMaintenance.swift`)

8. **Progress Reporting**
   - Add optional `progress: ((ProgressUpdate) -> Void)? = nil` parameter to `computeMissingHashes`
   - Invoke progress callback during hash computation loop with current/total counts (e.g., current=50, total=200)
   - Throttle progress callbacks to maximum 1 update per second

9. **Cancellation Support**
   - Add optional `cancellationToken: CancellationToken? = nil` parameter to `computeMissingHashes`
   - Check cancellation between files (after current file hash completes)
   - Throw `CancellationError.cancelled` if cancellation requested
   - Ensure already-computed hashes remain in index (no rollback)
   - Ensure atomic index update (write-then-rename pattern)

### Progress Throttling Implementation

10. **Throttle State**
    - Each operation maintains throttle state (last invocation time)
    - Use `Date` or `CFAbsoluteTimeGetCurrent()` for timestamp tracking
    - Skip callback if less than 1 second has elapsed since last invocation
    - Throttling is per-operation (each operation has its own throttle state)
    - **Note**: ProgressThrottle duplication is acceptable. Each operation may implement its own helper. No shared helper or refactoring required.

### Thread Safety Implementation

11. **CancellationToken Thread Safety**
    - Use `OSAllocatedUnfairLock` (Swift 5.9+) for thread-safe cancellation state
    - Fallback to `NSLock` if `OSAllocatedUnfairLock` unavailable
    - `isCanceled` property uses lock for thread-safe reads
    - `cancel()` method uses lock for thread-safe writes

## Implementation Phases

### Phase 1: Progress API Types (Read-Only)

**Goal**: Create `Progress.swift` with `ProgressUpdate`, `CancellationToken`, `CancellationError` types.

**Steps**:
1. Create `Sources/MediaHub/Progress.swift` file
2. Define `ProgressUpdate` struct with required fields (`stage`, `current`, `total`, `message`)
3. Define `CancellationToken` class with thread-safe implementation (`OSAllocatedUnfairLock` or `NSLock`)
4. Define `CancellationError` enum with `cancelled` case
5. Add unit tests for `CancellationToken` thread safety
6. Verify compilation and tests pass

**Validation**:
- `ProgressUpdate` struct exists with all required fields
- `CancellationToken` class exists with thread-safe `cancel()` and `isCanceled`
- `CancellationError` enum exists and conforms to `Error` and `LocalizedError`
- Thread safety tests pass (multiple threads calling `cancel()` and `isCanceled`)

### Phase 2: Detection Progress Integration (Read-Only First)

**Goal**: Add progress callback support to `DetectionOrchestrator.executeDetection` (read-only integration, no cancellation yet).

**Steps**:
1. Add optional `progress: ((ProgressUpdate) -> Void)? = nil` parameter to `executeDetection` method signature
2. Implement progress throttling helper (tracks last invocation time, skips if <1 second elapsed) - **Note**: Duplication is acceptable, no shared helper required
3. Invoke progress callback during scanning stage (after each item, throttled)
4. Invoke progress callback during comparison stage (after each item, throttled)
5. Invoke progress callback at completion (with final counts)
6. Verify backward compatibility (existing callers without progress parameter continue to work)
7. Add functional tests for progress callback invocation (verify callbacks are invoked with correct data)
8. Add functional tests for progress throttling (verify callbacks are throttled, no exact timing requirements)

**Validation**:
- Method signature includes progress parameter with `nil` default
- Progress callbacks are invoked during scanning and comparison stages
- Progress callbacks are throttled to maximum 1 update per second
- Existing callers without progress parameter continue to work
- Unit tests verify progress callback invocation and throttling

### Phase 3: Detection Cancellation Integration

**Goal**: Add cancellation support to `DetectionOrchestrator.executeDetection`.

**Steps**:
1. Add optional `cancellationToken: CancellationToken? = nil` parameter to `executeDetection` method signature
2. Check cancellation between items during scanning (safe point)
3. Check cancellation between items during comparison (safe point)
4. Throw `CancellationError.cancelled` if cancellation requested
5. Ensure no library state modification if canceled (no source metadata update)
6. Verify backward compatibility (existing callers without cancellationToken parameter continue to work)
7. Add unit tests for cancellation during scanning
8. Add unit tests for cancellation during comparison
9. Add unit tests for cancellation after completion (no effect)

**Validation**:
- Method signature includes cancellationToken parameter with `nil` default
- Cancellation is checked at safe points (between items)
- `CancellationError.cancelled` is thrown when cancellation requested
- No library state modification if canceled
- Existing callers without cancellationToken parameter continue to work
- Unit tests verify cancellation behavior

### Phase 4: Import Progress Integration (Read-Only First)

**Goal**: Add progress callback support to `ImportExecutor.executeImport` (read-only integration, no cancellation yet).

**Steps**:
1. Add optional `progress: ((ProgressUpdate) -> Void)? = nil` parameter to `executeImport` method signature
2. Implement progress throttling helper (duplication is acceptable, no shared helper required)
3. Invoke progress callback during import loop (after each item import completes, with current/total counts, throttled)
4. Verify backward compatibility (existing callers without progress parameter continue to work)
5. Add functional tests for progress callback invocation (verify callbacks are invoked with correct current/total counts)
6. Add functional tests for progress throttling (verify callbacks are throttled, no exact timing requirements)

**Validation**:
- Method signature includes progress parameter with `nil` default
- Progress callbacks are invoked during import with current/total counts
- Progress callbacks are throttled to maximum 1 update per second
- Existing callers without progress parameter continue to work
- Unit tests verify progress callback invocation and throttling

### Phase 5: Import Cancellation Integration

**Goal**: Add cancellation support to `ImportExecutor.executeImport`.

**Steps**:
1. Add optional `cancellationToken: CancellationToken? = nil` parameter to `executeImport` method signature
2. Check cancellation between items (after current item import completes atomically)
3. Throw `CancellationError.cancelled` if cancellation requested
4. Ensure already-imported items remain (no rollback of completed items)
5. Ensure no partial file state (current item completes before cancellation)
6. Verify backward compatibility (existing callers without cancellationToken parameter continue to work)
7. Add unit tests for cancellation during import (verify already-imported items remain)
8. Add unit tests for cancellation atomicity (verify no partial file state)

**Validation**:
- Method signature includes cancellationToken parameter with `nil` default
- Cancellation is checked between items (after current item completes)
- `CancellationError.cancelled` is thrown when cancellation requested
- Already-imported items remain (no rollback)
- No partial file state (current item completes before cancellation)
- Existing callers without cancellationToken parameter continue to work
- Unit tests verify cancellation behavior and atomicity

### Phase 6: Hash Maintenance Progress Integration (Read-Only First)

**Goal**: Add progress callback support to `HashCoverageMaintenance.computeMissingHashes` (read-only integration, no cancellation yet).

**Steps**:
1. Add optional `progress: ((ProgressUpdate) -> Void)? = nil` parameter to `computeMissingHashes` method signature
2. Implement progress throttling helper (duplication is acceptable, no shared helper required)
3. Invoke progress callback during hash computation loop (after each file hash completes, with current/total counts, throttled)
4. Verify backward compatibility (existing callers without progress parameter continue to work)
5. Add functional tests for progress callback invocation (verify callbacks are invoked with correct current/total counts)
6. Add functional tests for progress throttling (verify callbacks are throttled, no exact timing requirements)

**Validation**:
- Method signature includes progress parameter with `nil` default
- Progress callbacks are invoked during hash computation with current/total counts
- Progress callbacks are throttled to maximum 1 update per second
- Existing callers without progress parameter continue to work
- Unit tests verify progress callback invocation and throttling

### Phase 7: Hash Maintenance Cancellation Integration

**Goal**: Add cancellation support to `HashCoverageMaintenance.computeMissingHashes`.

**Steps**:
1. Add optional `cancellationToken: CancellationToken? = nil` parameter to `computeMissingHashes` method signature
2. Check cancellation between files (after current file hash completes)
3. Throw `CancellationError.cancelled` if cancellation requested
4. Ensure already-computed hashes remain in index (no rollback)
5. Ensure atomic index update (write-then-rename pattern ensures no partial index state)
6. Verify backward compatibility (existing callers without cancellationToken parameter continue to work)
7. Add unit tests for cancellation during hash computation (verify already-computed hashes remain)
8. Add unit tests for cancellation atomicity (verify no partial index state)

**Validation**:
- Method signature includes cancellationToken parameter with `nil` default
- Cancellation is checked between files (after current file hash completes)
- `CancellationError.cancelled` is thrown when cancellation requested
- Already-computed hashes remain in index (no rollback)
- Atomic index update (write-then-rename pattern)
- Existing callers without cancellationToken parameter continue to work
- Unit tests verify cancellation behavior and atomicity

### Phase 8: Backward Compatibility Validation

**Goal**: Verify backward compatibility and code correctness.

**Steps**:
1. Run all existing tests (verify no regressions)
2. Verify CLI commands continue to work without modification (backward compatibility)
3. Code review: Verify no additional allocations or work when progress/cancel are `nil` (conditional checks only)
4. Functional tests: Progress callbacks work correctly (unit tests from previous phases)
5. Functional tests: Cancellation works correctly (unit tests from previous phases)
6. Functional tests: Thread safety of cancellation token (unit test from Phase 1)

**Validation**:
- All existing tests pass (no regressions)
- CLI commands work without modification (backward compatibility)
- Code review confirms no allocations or computations when parameters are `nil`
- Functional tests verify progress/cancel work correctly
- Functional tests verify thread safety

## Execution Sequences

### Sequence 1: Detection with Progress/Cancel

1. **Detection Start**: Caller invokes `DetectionOrchestrator.executeDetection` with optional `progress` and `cancellationToken` parameters
2. **Progress Throttling**: If progress callback provided, initialize throttle state (last invocation time = nil)
3. **Scanning Stage**: For each candidate item:
   - Process item (scanning logic)
   - If progress callback provided and throttle allows (≥1 second since last invocation):
     - Invoke progress callback with `ProgressUpdate(stage: "scanning", current: itemIndex, total: totalItems)`
     - Update throttle state (last invocation time = now)
   - If cancellationToken provided and `cancellationToken.isCanceled`:
     - Throw `CancellationError.cancelled` (no library state modification)
4. **Comparison Stage**: For each candidate item:
   - Process item (comparison logic)
   - If progress callback provided and throttle allows:
     - Invoke progress callback with `ProgressUpdate(stage: "comparing", current: itemIndex, total: totalItems)`
     - Update throttle state
   - If cancellationToken provided and `cancellationToken.isCanceled`:
     - Throw `CancellationError.cancelled` (no library state modification)
5. **Completion**: If progress callback provided:
   - Invoke progress callback with `ProgressUpdate(stage: "complete", current: totalItems, total: totalItems)`
6. **Detection Complete**: Return `DetectionResult` (or throw `CancellationError` if canceled)

### Sequence 2: Import with Progress/Cancel

1. **Import Start**: Caller invokes `ImportExecutor.executeImport` with optional `progress` and `cancellationToken` parameters
2. **Progress Throttling**: If progress callback provided, initialize throttle state (last invocation time = nil)
3. **Import Loop**: For each item in sorted items:
   - Process item import (copy file, compute hash, create index entry) - **atomic operation**
   - If progress callback provided and throttle allows (≥1 second since last invocation):
     - Invoke progress callback with `ProgressUpdate(stage: "importing", current: itemIndex, total: totalItems)`
     - Update throttle state
   - If cancellationToken provided and `cancellationToken.isCanceled`:
     - Throw `CancellationError.cancelled` (already-imported items remain, no partial state)
4. **Import Complete**: If progress callback provided:
   - Invoke progress callback with `ProgressUpdate(stage: "complete", current: totalItems, total: totalItems)`
5. **Index Update**: Update baseline index atomically (write-then-rename pattern)
6. **Import Complete**: Return `ImportResult` (or throw `CancellationError` if canceled)

### Sequence 3: Hash Computation with Progress/Cancel

1. **Hash Start**: Caller invokes `HashCoverageMaintenance.computeMissingHashes` with optional `progress` and `cancellationToken` parameters
2. **Candidate Selection**: Select candidates (missing hash, file exists)
3. **Progress Throttling**: If progress callback provided, initialize throttle state (last invocation time = nil)
4. **Hash Loop**: For each candidate file:
   - Compute hash for file - **atomic operation**
   - Store computed hash in memory (path -> hash map)
   - If progress callback provided and throttle allows (≥1 second since last invocation):
     - Invoke progress callback with `ProgressUpdate(stage: "computing", current: fileIndex, total: totalFiles)`
     - Update throttle state
   - If cancellationToken provided and `cancellationToken.isCanceled`:
     - Throw `CancellationError.cancelled` (already-computed hashes remain in memory, no index update)
5. **Index Update**: If not canceled, apply computed hashes to index atomically (write-then-rename pattern)
6. **Hash Complete**: Return `HashComputationResult` (or throw `CancellationError` if canceled)

## Safety Guarantees

### SR-001: Read-Only Progress
- **Enforcement**: Progress callbacks receive `ProgressUpdate` value types only. No mutable state is passed to callbacks.
- **Validation**: Progress callbacks are invoked with `ProgressUpdate` structs (value types). No Core data structures are passed to callbacks.

### SR-002: Atomic Cancellation
- **Enforcement**: Cancellation checks occur at safe points (between items for import, between files for hash). No cancellation during item/file processing.
- **Validation**: Cancellation checks occur in loops between items/files, never during item/file processing. Import cancellation occurs after current item completes atomically.

### SR-003: Backward Compatibility
- **Enforcement**: All progress/cancel parameters are optional with `nil` defaults. No existing callers require modification.
- **Validation**: All existing Core API callers (CLI, tests) continue to work without modification. All parameters have `nil` defaults.

### SR-004: Zero Overhead When Unused
- **Enforcement**: Progress tracking and cancellation checks are conditional (only when parameters are non-nil). No allocations or computations occur when parameters are `nil` (conditional checks only).
- **Validation**: Code review confirms no allocations or computations when parameters are `nil`. Conditional checks use `if let` or `guard let` patterns.

### SR-005: Thread Safety
- **Enforcement**: `CancellationToken` uses thread-safe synchronization primitives (`OSAllocatedUnfairLock` or `NSLock`) for cancellation state.
- **Validation**: Thread safety tests verify multiple threads can call `cancel()` and `isCanceled` concurrently without data races.

### SR-006: Progress Throttling
- **Enforcement**: Progress callbacks track last invocation time and skip invocations that occur less than 1 second after the previous invocation.
- **Validation**: Unit tests verify progress callbacks are not invoked more than once per second during rapid progress.

## Determinism & Idempotence

### DI-001: Progress Reporting Determinism
- **Enforcement**: Progress callbacks are invoked at fixed points in operation loops (e.g., after each item, after each file). Progress updates reflect actual operation state.
- **Validation**: Progress updates are deterministic for the same operation. Same input produces same progress update sequence.

### DI-002: Cancellation Idempotence
- **Enforcement**: `CancellationToken.cancel()` sets a boolean flag. Multiple calls to `cancel()` are safe and have no additional effect.
- **Validation**: Unit tests verify calling `cancel()` multiple times has the same effect as calling it once.

### DI-003: Operation Idempotence Preserved
- **Enforcement**: Progress/cancel are additive features. Operation logic (detection, import, hash computation) remains unchanged.
- **Validation**: All existing operation idempotence tests continue to pass. Operations remain idempotent as before.

## Backward Compatibility

### BC-001: Core API Backward Compatibility
- **Guarantee**: All Core API methods remain backward compatible. Existing callers without progress/cancel parameters continue to work unchanged.
- **Enforcement**: All progress/cancel parameters are optional with `nil` defaults. No existing callers require modification.
- **Validation**: All existing Core API callers (CLI, tests) continue to work without modification.

### BC-002: CLI Backward Compatibility
- **Guarantee**: CLI commands continue to work unchanged. CLI may optionally use Core progress API internally, but user-facing output remains unchanged.
- **Enforcement**: CLI commands continue to use `ProgressIndicator` for stderr output. CLI may optionally wire Core progress callbacks to `ProgressIndicator`, but this is an internal implementation detail.
- **Validation**: CLI commands work without modification. User-facing output (stderr via `ProgressIndicator`) remains unchanged.

### BC-003: Test Backward Compatibility
- **Guarantee**: All existing tests continue to pass without modification. Tests that call Core APIs without progress/cancel parameters continue to work.
- **Enforcement**: All tests are run and verified to pass after implementation. No test modifications are required.
- **Validation**: All existing tests pass without modification.

## Testing Strategy

### Functional Tests (Required)

1. **Progress API Types**:
   - `ProgressUpdate` struct creation and field access
   - `CancellationToken` thread safety (multiple threads calling `cancel()` and `isCanceled`)
   - `CancellationError` enum cases and `LocalizedError` conformance

2. **Progress Callback Invocation**:
   - Detection progress callbacks invoked during scanning and comparison stages
   - Import progress callbacks invoked with current/total counts
   - Hash computation progress callbacks invoked with current/total counts

3. **Progress Throttling**:
   - Progress callbacks are throttled (verify throttling logic works, no exact timing requirements)

4. **Cancellation**:
   - Detection cancellation during scanning (throws `CancellationError`, no state modification)
   - Detection cancellation during comparison (throws `CancellationError`, no state modification)
   - Import cancellation during import (throws `CancellationError`, already-imported items remain)
   - Hash computation cancellation (throws `CancellationError`, already-computed hashes remain)

5. **Backward Compatibility**:
   - Existing callers without progress/cancel parameters continue to work
   - All existing tests pass without modification

### Optional Tests (Post-Freeze)

1. **End-to-End Integration** (optional):
   - Cross-operation integration tests (may be added post-freeze if needed)

2. **Performance Benchmarks** (optional):
   - Performance validation (may be added post-freeze if needed)

## Risk Assessment

### Low Risk
- **Progress API Types**: Simple value types and enum, low complexity
- **Progress Callback Integration**: Additive changes, optional parameters, low risk
- **Progress Throttling**: Simple time-based throttling, low complexity

### Medium Risk
- **Cancellation Integration**: Requires careful placement of cancellation checks at safe points. Medium complexity.
- **Thread Safety**: Requires proper synchronization primitives. Medium complexity.

### Mitigation Strategies
- **Cancellation Integration**: Test cancellation at all safe points. Verify no state corruption.
- **Thread Safety**: Use well-tested synchronization primitives (`OSAllocatedUnfairLock` or `NSLock`). Comprehensive thread safety tests.
- **Backward Compatibility**: All parameters optional with `nil` defaults. Comprehensive backward compatibility tests.

## Success Criteria

All success criteria from spec.md must be validated:

- SC-001: Progress API Types (ProgressUpdate struct exists)
- SC-002: Cancellation API Types (CancellationToken and CancellationError exist)
- SC-003: Detection Progress Support (method signature includes progress parameter)
- SC-004: Detection Cancellation Support (method signature includes cancellationToken parameter)
- SC-005: Import Progress Support (method signature includes progress parameter)
- SC-006: Import Cancellation Support (method signature includes cancellationToken parameter)
- SC-007: Hash Maintenance Progress Support (method signature includes progress parameter)
- SC-008: Hash Maintenance Cancellation Support (method signature includes cancellationToken parameter)
- SC-009: Progress Throttling (callbacks throttled to 1/second max)
- SC-010: Backward Compatibility (existing callers work unchanged)
- SC-011: Thread Safety (CancellationToken is thread-safe)
- SC-012: Zero Overhead When Unused (no additional allocations or work when parameters are `nil`)

## NON-NEGOTIABLE CONSTRAINTS

- **Backward Compatibility**: All existing Core API callers must continue to work without modification
- **Zero Overhead**: When progress/cancel parameters are `nil`, operations must have no additional allocations or work (conditional checks only)
- **Thread Safety**: `CancellationToken` must be thread-safe
- **Atomic Cancellation**: Cancellation must occur at safe points (no partial state)
- **Progress Throttling**: Progress callbacks must be throttled to maximum 1 update per second
- **No UI Changes**: This slice does NOT modify UI (deferred to Slice 15)
- **No CLI Changes**: CLI commands continue to work unchanged (user-facing output unchanged)
