# Feature Specification: Progress + Cancel API minimale

**Feature Branch**: `014-progress-cancel-api-minimale`  
**Created**: 2026-01-27  
**Status**: Draft  
**Input**: User description: "Add progress reporting and cancellation support to core operations (detect, import, hash)"

## Overview

This slice adds minimal progress reporting and cancellation support to core operations (detection, import, hash maintenance). The API is designed to be optional, thread-safe, and zero-overhead when not used, enabling both CLI and UI consumers to receive progress updates and cancel long-running operations gracefully.

**Problem Statement**: Long-running operations (detect, import, hash computation) currently provide no programmatic progress reporting or cancellation support. The CLI uses `ProgressIndicator` to write to stderr, but Core operations have no callback mechanism. SIGINT handling exists in CLI but is not exposed as a cancellation API. UI consumers need real-time progress updates and cancellation capabilities for better user experience.

**Architecture Principle**: Progress and cancellation are optional, additive features. Core operations remain backward compatible: existing callers without progress/cancel parameters continue to work unchanged. Progress callbacks are throttled (max 1 update per second) to avoid performance overhead. Cancellation is thread-safe and checked at safe points in operation loops.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Progress Reporting for Detection (Priority: P1)

A CLI or UI consumer wants to receive progress updates during detection operations to show users how many items have been scanned and compared.

**Why this priority**: Detection can take a long time for large sources. Users need feedback that the operation is progressing, not frozen.

**Independent Test**: Can be fully tested by calling `DetectionOrchestrator.executeDetection` with a progress callback and verifying callbacks are invoked with accurate progress information. This delivers the core capability of progress reporting.

**Acceptance Scenarios**:

1. **Given** a detection operation is started with a progress callback, **When** detection progresses through scanning, **Then** the callback is invoked with stage="scanning" and item count updates
2. **Given** a detection operation is started with a progress callback, **When** detection progresses through comparison, **Then** the callback is invoked with stage="comparing" and item count updates
3. **Given** a detection operation is started with a progress callback, **When** detection completes, **Then** the callback is invoked with stage="complete" and final counts
4. **Given** a detection operation is started without a progress callback, **When** detection runs, **Then** detection completes normally with no performance overhead from progress tracking
5. **Given** a detection operation with a progress callback, **When** progress updates occur rapidly, **Then** callbacks are throttled to maximum 1 update per second to avoid performance overhead

---

### User Story 2 - Cancellation for Detection (Priority: P1)

A CLI or UI consumer wants to cancel a detection operation in progress without corrupting library state.

**Why this priority**: Users may need to cancel long-running detection operations. Cancellation must be safe and not leave the library in an inconsistent state.

**Independent Test**: Can be fully tested by starting a detection operation with a cancellation token, canceling it mid-operation, and verifying the operation stops gracefully without corrupting library state. This delivers the core capability of cancellation.

**Acceptance Scenarios**:

1. **Given** a detection operation is started with a cancellation token, **When** cancellation is requested during scanning, **Then** the operation stops and throws `CancellationError` without modifying library state
2. **Given** a detection operation is started with a cancellation token, **When** cancellation is requested during comparison, **Then** the operation stops and throws `CancellationError` without modifying library state
3. **Given** a detection operation is started with a cancellation token, **When** cancellation is requested after completion, **Then** the operation completes normally (cancellation has no effect after completion)
4. **Given** a detection operation is started without a cancellation token, **When** detection runs, **Then** detection completes normally with no performance overhead from cancellation checks
5. **Given** a detection operation is canceled, **When** the operation stops, **Then** no source metadata is updated and the library remains in a consistent state

---

### User Story 3 - Progress Reporting for Import (Priority: P1)

A CLI or UI consumer wants to receive progress updates during import operations to show users how many items have been imported (current/total).

**Why this priority**: Import operations can take a long time for large batches. Users need feedback showing import progress (e.g., "5 of 100 items imported").

**Independent Test**: Can be fully tested by calling `ImportExecutor.executeImport` with a progress callback and verifying callbacks are invoked with accurate current/total progress. This delivers the core capability of progress reporting.

**Acceptance Scenarios**:

1. **Given** an import operation is started with a progress callback, **When** import progresses through items, **Then** the callback is invoked with current and total counts (e.g., current=5, total=100)
2. **Given** an import operation is started with a progress callback, **When** import completes, **Then** the callback is invoked with current=total indicating completion
3. **Given** an import operation is started without a progress callback, **When** import runs, **Then** import completes normally with no performance overhead from progress tracking
4. **Given** an import operation with a progress callback, **When** progress updates occur rapidly, **Then** callbacks are throttled to maximum 1 update per second to avoid performance overhead
5. **Given** an import operation with a progress callback, **When** import fails on an item, **Then** the callback continues to be invoked for remaining items (progress reporting continues even if individual items fail)

---

### User Story 4 - Cancellation for Import (Priority: P1)

A CLI or UI consumer wants to cancel an import operation in progress without corrupting library state or leaving partial imports.

**Why this priority**: Users may need to cancel long-running import operations. Cancellation must be safe: already-imported items remain, but no partial state is left.

**Independent Test**: Can be fully tested by starting an import operation with a cancellation token, canceling it mid-operation, and verifying the operation stops gracefully with already-imported items preserved and no partial state. This delivers the core capability of cancellation.

**Acceptance Scenarios**:

1. **Given** an import operation is started with a cancellation token, **When** cancellation is requested during import, **Then** the operation stops and throws `CancellationError` after completing the current item (atomic item import)
2. **Given** an import operation is started with a cancellation token, **When** cancellation is requested, **Then** already-imported items remain in the library (no rollback of completed items)
3. **Given** an import operation is started with a cancellation token, **When** cancellation is requested, **Then** no partial file state is left (current item import completes atomically before cancellation)
4. **Given** an import operation is started without a cancellation token, **When** import runs, **Then** import completes normally with no performance overhead from cancellation checks
5. **Given** an import operation is canceled, **When** the operation stops, **Then** the library remains in a consistent state with all completed imports preserved

---

### User Story 5 - Progress Reporting for Hash Maintenance (Priority: P1)

A CLI or UI consumer wants to receive progress updates during hash computation operations to show users how many hashes have been computed (current/total candidates).

**Why this priority**: Hash computation can take a long time for large libraries. Users need feedback showing progress (e.g., "50 of 200 hashes computed").

**Independent Test**: Can be fully tested by calling `HashCoverageMaintenance.computeMissingHashes` with a progress callback and verifying callbacks are invoked with accurate current/total progress. This delivers the core capability of progress reporting.

**Acceptance Scenarios**:

1. **Given** a hash computation operation is started with a progress callback, **When** hash computation progresses through candidates, **Then** the callback is invoked with current and total counts (e.g., current=50, total=200)
2. **Given** a hash computation operation is started with a progress callback, **When** hash computation completes, **Then** the callback is invoked with current=total indicating completion
3. **Given** a hash computation operation is started without a progress callback, **When** hash computation runs, **Then** hash computation completes normally with no performance overhead from progress tracking
4. **Given** a hash computation operation with a progress callback, **When** progress updates occur rapidly, **Then** callbacks are throttled to maximum 1 update per second to avoid performance overhead
5. **Given** a hash computation operation with a progress callback, **When** hash computation fails on a file, **Then** the callback continues to be invoked for remaining files (progress reporting continues even if individual files fail)

---

### User Story 6 - Cancellation for Hash Maintenance (Priority: P1)

A CLI or UI consumer wants to cancel a hash computation operation in progress without corrupting the baseline index.

**Why this priority**: Users may need to cancel long-running hash computation operations. Cancellation must be safe: already-computed hashes are preserved in the index, but no partial state is left.

**Independent Test**: Can be fully tested by starting a hash computation operation with a cancellation token, canceling it mid-operation, and verifying the operation stops gracefully with already-computed hashes preserved and no partial index state. This delivers the core capability of cancellation.

**Acceptance Scenarios**:

1. **Given** a hash computation operation is started with a cancellation token, **When** cancellation is requested during hash computation, **Then** the operation stops and throws `CancellationError` after completing the current file hash (atomic hash computation)
2. **Given** a hash computation operation is started with a cancellation token, **When** cancellation is requested, **Then** already-computed hashes remain in the baseline index (no rollback of completed hashes)
3. **Given** a hash computation operation is started with a cancellation token, **When** cancellation is requested, **Then** the baseline index update is atomic (write-then-rename pattern ensures no partial index state)
4. **Given** a hash computation operation is started without a cancellation token, **When** hash computation runs, **Then** hash computation completes normally with no performance overhead from cancellation checks
5. **Given** a hash computation operation is canceled, **When** the operation stops, **Then** the baseline index remains in a consistent state with all completed hashes preserved

---

## Success Criteria

### SC-001: Progress API Types
- **Requirement**: Core defines `ProgressUpdate` struct with `stage: String`, `current: Int?`, `total: Int?`, `message: String?` fields
- **Validation**: `ProgressUpdate` struct exists in `Sources/MediaHub/Progress.swift` with all required fields
- **Priority**: P1

### SC-002: Cancellation API Types
- **Requirement**: Core defines `CancellationToken` class (thread-safe) and `CancellationError` enum (conforms to `Error`)
- **Validation**: `CancellationToken` and `CancellationError` exist in `Sources/MediaHub/Progress.swift`
- **Priority**: P1

### SC-003: Detection Progress Support
- **Requirement**: `DetectionOrchestrator.executeDetection` accepts optional `progress: ((ProgressUpdate) -> Void)?` parameter
- **Validation**: Method signature includes progress parameter, callbacks are invoked during scanning and comparison stages
- **Priority**: P1

### SC-004: Detection Cancellation Support
- **Requirement**: `DetectionOrchestrator.executeDetection` accepts optional `cancellationToken: CancellationToken?` parameter and checks cancellation at safe points
- **Validation**: Method signature includes cancellationToken parameter, cancellation is checked and throws `CancellationError` when requested
- **Priority**: P1

### SC-005: Import Progress Support
- **Requirement**: `ImportExecutor.executeImport` accepts optional `progress: ((ProgressUpdate) -> Void)?` parameter
- **Validation**: Method signature includes progress parameter, callbacks are invoked with current/total counts during import
- **Priority**: P1

### SC-006: Import Cancellation Support
- **Requirement**: `ImportExecutor.executeImport` accepts optional `cancellationToken: CancellationToken?` parameter and checks cancellation at safe points (between items)
- **Validation**: Method signature includes cancellationToken parameter, cancellation is checked and throws `CancellationError` when requested (after current item completes)
- **Priority**: P1

### SC-007: Hash Maintenance Progress Support
- **Requirement**: `HashCoverageMaintenance.computeMissingHashes` accepts optional `progress: ((ProgressUpdate) -> Void)?` parameter
- **Validation**: Method signature includes progress parameter, callbacks are invoked with current/total counts during hash computation
- **Priority**: P1

### SC-008: Hash Maintenance Cancellation Support
- **Requirement**: `HashCoverageMaintenance.computeMissingHashes` accepts optional `cancellationToken: CancellationToken?` parameter and checks cancellation at safe points (between files)
- **Validation**: Method signature includes cancellationToken parameter, cancellation is checked and throws `CancellationError` when requested (after current file hash completes)
- **Priority**: P1

### SC-009: Progress Throttling
- **Requirement**: Progress callbacks are throttled to maximum 1 update per second to avoid performance overhead
- **Validation**: Progress callbacks are not invoked more than once per second during rapid progress
- **Priority**: P1

### SC-010: Backward Compatibility
- **Requirement**: All Core API methods remain backward compatible: existing callers without progress/cancel parameters continue to work unchanged
- **Validation**: All existing Core API callers (CLI, tests) continue to work without modification
- **Priority**: P1

### SC-011: Thread Safety
- **Requirement**: `CancellationToken` is thread-safe and can be checked/canceled from any thread
- **Validation**: `CancellationToken` uses thread-safe mechanisms (e.g., `OSAllocatedUnfairLock` or `NSLock`) for cancellation state
- **Priority**: P1

### SC-012: Zero Overhead When Unused
- **Requirement**: When progress/cancel parameters are `nil`, operations have no additional allocations or work from progress tracking or cancellation checks
- **Validation**: Code review verifies no allocations or computations occur when parameters are `nil` (conditional checks only)
- **Priority**: P1

---

## Non-Goals

- **UI integration**: This slice does NOT add UI components for progress bars or cancel buttons. UI integration is deferred to Slice 15.
- **CLI progress output changes**: This slice does NOT change CLI progress output format. CLI continues to use `ProgressIndicator` for stderr output. CLI may optionally use Core progress API internally, but user-facing output remains unchanged.
- **Progress persistence**: This slice does NOT persist progress state across app restarts. Progress is ephemeral and only active during operation execution.
- **Batch progress**: This slice does NOT add progress reporting for batch operations (e.g., "library 1 of 3"). Only per-operation progress is supported.
- **Progress estimation**: This slice does NOT add time-based progress estimation (e.g., "5 minutes remaining"). Only item-based progress (current/total) is supported.
- **Cancellation callbacks**: This slice does NOT add callbacks that are invoked when cancellation occurs. Cancellation is signaled via `CancellationError` exception only.

---

## API Requirements

### API-001: ProgressUpdate Type
- **Location**: `Sources/MediaHub/Progress.swift`
- **Type**: `public struct ProgressUpdate`
- **Fields**:
  - `stage: String` - Operation stage name (e.g., "scanning", "comparing", "importing", "computing")
  - `current: Int?` - Current item count (optional, nil if not applicable)
  - `total: Int?` - Total item count (optional, nil if not applicable)
  - `message: String?` - Optional human-readable message (optional, nil if not provided)
- **Thread Safety**: Value type, thread-safe by design

### API-002: CancellationToken Type
- **Location**: `Sources/MediaHub/Progress.swift`
- **Type**: `public final class CancellationToken`
- **Methods**:
  - `init()` - Creates a new cancellation token
  - `func cancel()` - Marks the token as canceled (thread-safe)
  - `var isCanceled: Bool` - Returns whether cancellation has been requested (thread-safe, read-only)
- **Thread Safety**: All methods and properties are thread-safe

### API-003: CancellationError Type
- **Location**: `Sources/MediaHub/Progress.swift`
- **Type**: `public enum CancellationError: Error, LocalizedError`
- **Cases**: `cancelled` (single case)
- **Conformance**: Conforms to `Error` and `LocalizedError`

### API-004: DetectionOrchestrator Progress/Cancel
- **Location**: `Sources/MediaHub/DetectionOrchestration.swift`
- **Method**: `DetectionOrchestrator.executeDetection`
- **New Parameters**:
  - `progress: ((ProgressUpdate) -> Void)? = nil` - Optional progress callback
  - `cancellationToken: CancellationToken? = nil` - Optional cancellation token
- **Behavior**:
  - Progress callback is invoked during scanning stage (with item counts) and comparison stage (with item counts)
  - Cancellation is checked at safe points (between items during scanning, between items during comparison)
  - If cancellation is requested, throws `CancellationError.cancelled`
  - Progress callbacks are throttled to maximum 1 update per second

### API-005: ImportExecutor Progress/Cancel
- **Location**: `Sources/MediaHub/ImportExecution.swift`
- **Method**: `ImportExecutor.executeImport`
- **New Parameters**:
  - `progress: ((ProgressUpdate) -> Void)? = nil` - Optional progress callback
  - `cancellationToken: CancellationToken? = nil` - Optional cancellation token
- **Behavior**:
  - Progress callback is invoked during import with current/total counts (e.g., current=5, total=100)
  - Cancellation is checked between items (after current item import completes atomically)
  - If cancellation is requested, throws `CancellationError.cancelled` after completing current item
  - Progress callbacks are throttled to maximum 1 update per second

### API-006: HashCoverageMaintenance Progress/Cancel
- **Location**: `Sources/MediaHub/HashCoverageMaintenance.swift`
- **Method**: `HashCoverageMaintenance.computeMissingHashes`
- **New Parameters**:
  - `progress: ((ProgressUpdate) -> Void)? = nil` - Optional progress callback
  - `cancellationToken: CancellationToken? = nil` - Optional cancellation token
- **Behavior**:
  - Progress callback is invoked during hash computation with current/total counts (e.g., current=50, total=200)
  - Cancellation is checked between files (after current file hash completes)
  - If cancellation is requested, throws `CancellationError.cancelled` after completing current file hash
  - Progress callbacks are throttled to maximum 1 update per second

---

## Safety Rules

### SR-001: Read-Only Progress
- **Rule**: Progress callbacks are read-only. Progress callbacks must not modify library state, source state, or any Core data structures.
- **Enforcement**: Progress callbacks are invoked with `ProgressUpdate` value types only. No mutable state is passed to callbacks.

### SR-002: Atomic Cancellation
- **Rule**: Cancellation occurs only at safe points. For import and hash operations, cancellation occurs after the current item/file completes atomically. No partial state is left.
- **Enforcement**: Cancellation checks occur between items (import) or between files (hash), never during item/file processing.

### SR-003: Backward Compatibility
- **Rule**: All Core API methods remain backward compatible. Existing callers without progress/cancel parameters continue to work unchanged.
- **Enforcement**: All progress/cancel parameters are optional with `nil` defaults. No existing callers require modification.

### SR-004: Zero Overhead When Unused
- **Rule**: When progress/cancel parameters are `nil`, operations have no additional allocations or work from progress tracking or cancellation checks.
- **Enforcement**: Progress tracking and cancellation checks are conditional (only when parameters are non-nil). No allocations or computations occur when parameters are `nil` (conditional checks only).

### SR-005: Thread Safety
- **Rule**: `CancellationToken` is thread-safe. Cancellation can be requested from any thread, and cancellation checks are thread-safe.
- **Enforcement**: `CancellationToken` uses thread-safe synchronization primitives (e.g., `OSAllocatedUnfairLock` or `NSLock`) for cancellation state.

### SR-006: Progress Throttling
- **Rule**: Progress callbacks are throttled to maximum 1 update per second to avoid performance overhead.
- **Enforcement**: Progress callbacks track last invocation time and skip invocations that occur less than 1 second after the previous invocation.

---

## Determinism & Idempotence

### DI-001: Progress Reporting Determinism
- **Rule**: Progress updates are deterministic for the same operation. Same input produces same progress update sequence (stage names, counts).
- **Enforcement**: Progress callbacks are invoked at fixed points in operation loops (e.g., after each item, after each file). Progress updates reflect actual operation state, not estimated state.

### DI-002: Cancellation Idempotence
- **Rule**: Cancellation is idempotent. Calling `cancel()` multiple times has the same effect as calling it once.
- **Enforcement**: `CancellationToken.cancel()` sets a boolean flag. Multiple calls to `cancel()` are safe and have no additional effect.

### DI-003: Operation Idempotence Preserved
- **Rule**: Adding progress/cancel support does not change operation idempotence. Operations remain idempotent as before.
- **Enforcement**: Progress/cancel are additive features. Operation logic (detection, import, hash computation) remains unchanged. Only progress reporting and cancellation checks are added.

---

## Backward Compatibility

### BC-001: Core API Backward Compatibility
- **Guarantee**: All Core API methods (`DetectionOrchestrator.executeDetection`, `ImportExecutor.executeImport`, `HashCoverageMaintenance.computeMissingHashes`) remain backward compatible. Existing callers without progress/cancel parameters continue to work unchanged.
- **Enforcement**: All progress/cancel parameters are optional with `nil` defaults. No existing callers require modification.

### BC-002: CLI Backward Compatibility
- **Guarantee**: CLI commands (`detect`, `import`, `index hash`) continue to work unchanged. CLI may optionally use Core progress API internally, but user-facing output (stderr via `ProgressIndicator`) remains unchanged.
- **Enforcement**: CLI commands continue to use `ProgressIndicator` for stderr output. CLI may optionally wire Core progress callbacks to `ProgressIndicator`, but this is an internal implementation detail that does not affect CLI behavior.

### BC-003: Test Backward Compatibility
- **Guarantee**: All existing tests continue to pass without modification. Tests that call Core APIs without progress/cancel parameters continue to work.
- **Enforcement**: All tests are run and verified to pass after implementation. No test modifications are required.

---

## Implementation Notes

### Progress Throttling Implementation
- Progress callbacks track last invocation time using `Date` or `CFAbsoluteTimeGetCurrent()`.
- If less than 1 second has elapsed since last invocation, the callback is skipped.
- Throttling is per-operation (each operation has its own throttle state).

### Cancellation Check Points
- **Detection**: Cancellation checked between items during scanning, between items during comparison.
- **Import**: Cancellation checked between items (after current item import completes atomically).
- **Hash**: Cancellation checked between files (after current file hash completes).

### Thread Safety Implementation
- `CancellationToken` uses `OSAllocatedUnfairLock` (Swift 5.9+) or `NSLock` (fallback) for thread-safe cancellation state.
- `isCanceled` property uses the same lock for thread-safe reads.
- `cancel()` method uses the same lock for thread-safe writes.

### Performance Considerations
- Progress tracking uses minimal allocations (throttle state is a single `Date` or `Double`) only when progress callback is provided.
- Cancellation checks use a single boolean read (with lock) only when cancellation token is provided.
- When progress/cancel parameters are `nil`, no allocations or computations occur (conditional checks only).

### Minimal API Implementation Notes
- **ProgressThrottle duplication is acceptable**: Each operation (detect, import, hash) may implement its own `ProgressThrottle` helper. No shared helper or refactoring required for this slice.
- **Code duplication allowed**: Throttling logic may be duplicated across operations. Centralization is out of scope.

---

## Dependencies

- **None**: This slice has no dependencies on other slices. It is a Core-only addition that does not require UI or CLI changes.

---

## Out of Scope

- UI progress bars or cancel buttons (deferred to Slice 15)
- CLI progress output format changes (CLI continues to use `ProgressIndicator`)
- Progress persistence across app restarts
- Batch progress reporting (e.g., "library 1 of 3")
- Time-based progress estimation (e.g., "5 minutes remaining")
- Cancellation callbacks (cancellation signaled via `CancellationError` only)
