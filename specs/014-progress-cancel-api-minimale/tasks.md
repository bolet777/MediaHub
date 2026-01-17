# Implementation Tasks: Progress + Cancel API minimale

**Feature**: Progress + Cancel API minimale  
**Specification**: `specs/014-progress-cancel-api-minimale/spec.md`  
**Plan**: `specs/014-progress-cancel-api-minimale/plan.md`  
**Slice**: 14 - Add progress reporting and cancellation support to core operations (detect, import, hash)  
**Created**: 2026-01-27

## Task Organization

Tasks are organized by phase, following the implementation sequence defined in the plan. Each task is:
- Small and focused on a single deliverable (1–2 commands max per pass)
- Sequential with explicit dependencies
- Traceable to plan phases and spec requirements
- Read-only progress integration first; cancellation integration after progress

---

## Phase 1 — Progress API Types

**Plan Reference**: Phase 1 (lines 200-220)  
**Goal**: Create `Progress.swift` with `ProgressUpdate`, `CancellationToken`, `CancellationError` types  
**Dependencies**: None (Foundation)

### T-001: Create Progress.swift File with ProgressUpdate Struct
**Priority**: P1  
**Summary**: Create `Progress.swift` file and define `ProgressUpdate` struct with required fields.

**Expected Files Touched**:
- `Sources/MediaHub/Progress.swift` (new)

**Steps**:
1. Create `Sources/MediaHub/Progress.swift` file
2. Define `public struct ProgressUpdate` with fields:
   - `stage: String` - Operation stage name
   - `current: Int?` - Current item count (optional)
   - `total: Int?` - Total item count (optional)
   - `message: String?` - Optional human-readable message (optional)
3. Add public initializer with all fields
4. Mark struct as `public` for Core API visibility

**Done When**:
- `ProgressUpdate` struct compiles
- All required fields are present and accessible
- Struct is marked `public`

**Dependencies**: None

---

### T-002: Add CancellationToken Class to Progress.swift
**Priority**: P1  
**Summary**: Add `CancellationToken` class with thread-safe implementation.

**Expected Files Touched**:
- `Sources/MediaHub/Progress.swift` (update)

**Steps**:
1. Add `public final class CancellationToken` to `Progress.swift`
2. Add private property `_isCanceled: Bool = false` with thread-safe synchronization
3. Use `OSAllocatedUnfairLock` (Swift 5.9+) or `NSLock` (fallback) for thread safety
4. Implement `public init()` initializer
5. Implement `public func cancel()` method (thread-safe, sets `_isCanceled = true`)
6. Implement `public var isCanceled: Bool` property (thread-safe read-only)
7. Ensure all methods and properties are thread-safe

**Done When**:
- `CancellationToken` class compiles
- `cancel()` and `isCanceled` are thread-safe
- Thread safety uses `OSAllocatedUnfairLock` or `NSLock`

**Dependencies**: T-001

---

### T-003: Add CancellationError Enum to Progress.swift
**Priority**: P1  
**Summary**: Add `CancellationError` enum conforming to `Error` and `LocalizedError`.

**Expected Files Touched**:
- `Sources/MediaHub/Progress.swift` (update)

**Steps**:
1. Add `public enum CancellationError: Error, LocalizedError` to `Progress.swift`
2. Add single case: `cancelled`
3. Implement `LocalizedError` conformance:
   - `var errorDescription: String?` returning "Operation was cancelled"
4. Mark enum as `public` for Core API visibility

**Done When**:
- `CancellationError` enum compiles
- Enum conforms to `Error` and `LocalizedError`
- `errorDescription` returns user-facing message

**Dependencies**: T-001

---

### T-004: Add Unit Tests for CancellationToken Thread Safety
**Priority**: P1  
**Summary**: Create unit tests verifying `CancellationToken` thread safety.

**Expected Files Touched**:
- `Tests/MediaHubTests/ProgressTests.swift` (new)

**Steps**:
1. Create `Tests/MediaHubTests/ProgressTests.swift` file
2. Add test `testCancellationTokenThreadSafety()`:
   - Create `CancellationToken` instance
   - Spawn multiple threads calling `cancel()` concurrently
   - Spawn multiple threads checking `isCanceled` concurrently
   - Verify no data races or crashes
   - Verify `isCanceled` eventually becomes `true` after `cancel()` calls
3. Add test `testCancellationTokenIdempotence()`:
   - Create `CancellationToken` instance
   - Call `cancel()` multiple times
   - Verify `isCanceled` is `true` after first call
   - Verify multiple calls have same effect as single call

**Done When**:
- Thread safety tests compile and pass
- Tests verify no data races
- Tests verify idempotence

**Dependencies**: T-002

---

## Phase 2 — Detection Progress Integration

**Plan Reference**: Phase 2 (lines 222-245)  
**Goal**: Add progress callback support to `DetectionOrchestrator.executeDetection` (read-only integration)  
**Dependencies**: Phase 1 (Progress API Types)

### T-005: Add Progress Parameter to DetectionOrchestrator.executeDetection
**Priority**: P1  
**Summary**: Add optional `progress` parameter to `executeDetection` method signature.

**Expected Files Touched**:
- `Sources/MediaHub/DetectionOrchestration.swift` (update)

**Steps**:
1. Add optional parameter `progress: ((ProgressUpdate) -> Void)? = nil` to `executeDetection` method signature
2. Verify method signature compiles
3. Verify backward compatibility (existing callers without progress parameter continue to work)

**Done When**:
- Method signature includes progress parameter with `nil` default
- Existing callers compile without modification
- Method signature is correct

**Dependencies**: T-001

---

### T-006: Implement Progress Throttling Helper for Detection
**Priority**: P1  
**Summary**: Create progress throttling helper to limit callbacks to 1 update per second.

**Expected Files Touched**:
- `Sources/MediaHub/DetectionOrchestration.swift` (update)

**Steps**:
1. Add private helper struct `ProgressThrottle` inside `DetectionOrchestrator`:
   - Property `lastInvocationTime: Date? = nil`
   - Method `func shouldInvoke() -> Bool` (returns true if ≥1 second since last invocation)
   - Method `func recordInvocation()` (updates `lastInvocationTime = Date()`)
2. Add helper method `invokeProgressIfNeeded(progress: ProgressUpdate, throttle: inout ProgressThrottle, callback: ((ProgressUpdate) -> Void)?)`:
   - If callback is `nil`, return early (no allocations or work)
   - If throttle allows (≥1 second), invoke callback and record invocation
   - If throttle disallows, skip callback
3. **Note**: Duplication is acceptable. This helper may be duplicated in Import and Hash operations. No shared helper required.

**Done When**:
- Progress throttling helper compiles
- Throttling logic limits callbacks (no exact timing requirements)
- No allocations or work when callback is `nil`

**Dependencies**: T-005

---

### T-007: Invoke Progress Callback During Detection Scanning Stage
**Priority**: P1  
**Summary**: Invoke progress callback during detection scanning stage with item counts.

**Expected Files Touched**:
- `Sources/MediaHub/DetectionOrchestration.swift` (update)

**Steps**:
1. After `SourceScanner.scan` completes, initialize progress throttle (if progress callback provided)
2. After sorting candidates, invoke progress callback with `ProgressUpdate(stage: "scanning", current: sortedCandidates.count, total: sortedCandidates.count, message: nil)` (throttled)
3. Verify progress callback is invoked with correct stage and counts

**Done When**:
- Progress callback is invoked during scanning stage
- Callback includes correct stage name and item counts
- Throttling is applied (callbacks limited to 1/second)

**Dependencies**: T-006

---

### T-008: Invoke Progress Callback During Detection Comparison Stage
**Priority**: P1  
**Summary**: Invoke progress callback during detection comparison stage with item counts.

**Expected Files Touched**:
- `Sources/MediaHub/DetectionOrchestration.swift` (update)

**Steps**:
1. In the hash-based duplicate detection loop (after line 129), add progress callback invocation:
   - After processing each candidate (or every N candidates for throttling), invoke progress callback with `ProgressUpdate(stage: "comparing", current: itemIndex, total: sortedCandidates.count, message: nil)` (throttled)
2. Verify progress callback is invoked during comparison stage
3. Verify throttling is applied

**Done When**:
- Progress callback is invoked during comparison stage
- Callback includes correct stage name and item counts
- Throttling is applied (callbacks limited to 1/second)

**Dependencies**: T-007

---

### T-009: Invoke Progress Callback at Detection Completion
**Priority**: P1  
**Summary**: Invoke progress callback at detection completion with final counts.

**Expected Files Touched**:
- `Sources/MediaHub/DetectionOrchestration.swift` (update)

**Steps**:
1. Before returning `DetectionResult` (after line 260), invoke progress callback with `ProgressUpdate(stage: "complete", current: candidateResults.count, total: candidateResults.count, message: nil)` (not throttled, final update)
2. Verify progress callback is invoked at completion
3. Verify callback includes final counts

**Done When**:
- Progress callback is invoked at detection completion
- Callback includes correct stage name and final counts
- Final update is not throttled

**Dependencies**: T-008

---

### T-010: Add Unit Tests for Detection Progress Callback Invocation
**Priority**: P1  
**Summary**: Create unit tests verifying detection progress callbacks are invoked correctly.

**Expected Files Touched**:
- `Tests/MediaHubTests/DetectionOrchestrationTests.swift` (update or new)

**Steps**:
1. Add test `testDetectionProgressCallbackInvocation()`:
   - Create mock progress callback that records all invocations
   - Call `executeDetection` with progress callback
   - Verify callback is invoked during scanning stage
   - Verify callback is invoked during comparison stage
   - Verify callback is invoked at completion
   - Verify callback receives correct `ProgressUpdate` data
2. Add test `testDetectionProgressThrottling()`:
   - Create mock progress callback that records invocations
   - Call `executeDetection` with progress callback on source with multiple items
   - Verify throttling logic works (callbacks are throttled, no exact timing requirements)

**Done When**:
- Progress callback tests compile and pass
- Tests verify callbacks are invoked with correct data
- Tests verify throttling works correctly

**Dependencies**: T-009

---

## Phase 3 — Detection Cancellation Integration

**Plan Reference**: Phase 3 (lines 247-270)  
**Goal**: Add cancellation support to `DetectionOrchestrator.executeDetection`  
**Dependencies**: Phase 2 (Detection Progress Integration)

### T-011: Add CancellationToken Parameter to DetectionOrchestrator.executeDetection
**Priority**: P1  
**Summary**: Add optional `cancellationToken` parameter to `executeDetection` method signature.

**Expected Files Touched**:
- `Sources/MediaHub/DetectionOrchestration.swift` (update)

**Steps**:
1. Add optional parameter `cancellationToken: CancellationToken? = nil` to `executeDetection` method signature
2. Verify method signature compiles
3. Verify backward compatibility (existing callers without cancellationToken parameter continue to work)

**Done When**:
- Method signature includes cancellationToken parameter with `nil` default
- Existing callers compile without modification
- Method signature is correct

**Dependencies**: T-002, T-009

---

### T-012: Check Cancellation During Detection Scanning Stage
**Priority**: P1  
**Summary**: Check cancellation at safe points during detection scanning stage.

**Expected Files Touched**:
- `Sources/MediaHub/DetectionOrchestration.swift` (update)

**Steps**:
1. After `SourceScanner.scan` completes and before sorting candidates, check cancellation:
   - If `cancellationToken?.isCanceled == true`, throw `CancellationError.cancelled`
2. Verify cancellation check occurs at safe point (no library state modification yet)
3. Verify `CancellationError.cancelled` is thrown when cancellation requested

**Done When**:
- Cancellation is checked during scanning stage
- `CancellationError.cancelled` is thrown when cancellation requested
- No library state modification if canceled

**Dependencies**: T-011

---

### T-013: Check Cancellation During Detection Comparison Stage
**Priority**: P1  
**Summary**: Check cancellation at safe points during detection comparison stage.

**Expected Files Touched**:
- `Sources/MediaHub/DetectionOrchestration.swift` (update)

**Steps**:
1. In the hash-based duplicate detection loop (after line 129), add cancellation check:
   - After processing each candidate (or every N candidates), check `cancellationToken?.isCanceled`
   - If `true`, throw `CancellationError.cancelled`
2. Verify cancellation check occurs at safe point (between items, no library state modification)
3. Verify `CancellationError.cancelled` is thrown when cancellation requested

**Done When**:
- Cancellation is checked during comparison stage
- `CancellationError.cancelled` is thrown when cancellation requested
- No library state modification if canceled

**Dependencies**: T-012

---

### T-014: Ensure No Library State Modification on Detection Cancellation
**Priority**: P1  
**Summary**: Verify detection cancellation does not modify library state (no source metadata update).

**Expected Files Touched**:
- `Sources/MediaHub/DetectionOrchestration.swift` (update)

**Steps**:
1. Verify cancellation checks occur before source metadata update (before line 248)
2. If `CancellationError.cancelled` is thrown, ensure `updateSourceLastDetected` is not called
3. Verify no detection result is stored if canceled (cancellation occurs before result storage)

**Done When**:
- Cancellation occurs before source metadata update
- No source metadata is updated if canceled
- No detection result is stored if canceled

**Dependencies**: T-013

---

### T-015: Add Unit Tests for Detection Cancellation
**Priority**: P1  
**Summary**: Create unit tests verifying detection cancellation works correctly.

**Expected Files Touched**:
- `Tests/MediaHubTests/DetectionOrchestrationTests.swift` (update or new)

**Steps**:
1. Add test `testDetectionCancellationDuringScanning()`:
   - Create `CancellationToken` instance
   - Start detection operation with cancellation token
   - Cancel token during scanning stage
   - Verify `CancellationError.cancelled` is thrown
   - Verify no source metadata is updated
2. Add test `testDetectionCancellationDuringComparison()`:
   - Create `CancellationToken` instance
   - Start detection operation with cancellation token
   - Cancel token during comparison stage
   - Verify `CancellationError.cancelled` is thrown
   - Verify no source metadata is updated
3. Add test `testDetectionCancellationAfterCompletion()`:
   - Create `CancellationToken` instance
   - Start detection operation with cancellation token
   - Complete detection operation
   - Cancel token after completion
   - Verify detection completes normally (cancellation has no effect after completion)

**Done When**:
- Cancellation tests compile and pass
- Tests verify cancellation works during scanning and comparison
- Tests verify cancellation has no effect after completion

**Dependencies**: T-014

---

## Phase 4 — Import Progress Integration

**Plan Reference**: Phase 4 (lines 272-295)  
**Goal**: Add progress callback support to `ImportExecutor.executeImport` (read-only integration)  
**Dependencies**: Phase 3 (Detection Cancellation Integration)

### T-016: Add Progress Parameter to ImportExecutor.executeImport
**Priority**: P1  
**Summary**: Add optional `progress` parameter to `executeImport` method signature.

**Expected Files Touched**:
- `Sources/MediaHub/ImportExecution.swift` (update)

**Steps**:
1. Add optional parameter `progress: ((ProgressUpdate) -> Void)? = nil` to `executeImport` method signature
2. Verify method signature compiles
3. Verify backward compatibility (existing callers without progress parameter continue to work)

**Done When**:
- Method signature includes progress parameter with `nil` default
- Existing callers compile without modification
- Method signature is correct

**Dependencies**: T-001

---

### T-017: Implement Progress Throttling Helper for Import
**Priority**: P1  
**Summary**: Create progress throttling helper for import operations.

**Expected Files Touched**:
- `Sources/MediaHub/ImportExecution.swift` (update)

**Steps**:
1. Add private helper struct `ProgressThrottle` inside `ImportExecutor` (duplication is acceptable, same structure as T-006):
   - Property `lastInvocationTime: Date? = nil`
   - Method `func shouldInvoke() -> Bool`
   - Method `func recordInvocation()`
2. Add helper method `invokeProgressIfNeeded(progress: ProgressUpdate, throttle: inout ProgressThrottle, callback: ((ProgressUpdate) -> Void)?)` (duplication is acceptable)

**Done When**:
- Progress throttling helper compiles
- Throttling logic limits callbacks (no exact timing requirements)
- No allocations or work when callback is `nil`

**Dependencies**: T-016

---

### T-018: Invoke Progress Callback During Import Loop
**Priority**: P1  
**Summary**: Invoke progress callback during import loop with current/total counts.

**Expected Files Touched**:
- `Sources/MediaHub/ImportExecution.swift` (update)

**Steps**:
1. In the import loop (after line 111), initialize progress throttle (if progress callback provided)
2. After each item import completes (after `processImportItem` call, after line 120), invoke progress callback with `ProgressUpdate(stage: "importing", current: itemIndex + 1, total: sortedItems.count, message: nil)` (throttled)
3. Verify progress callback is invoked with correct current/total counts

**Done When**:
- Progress callback is invoked during import loop
- Callback includes correct stage name and current/total counts
- Throttling is applied (callbacks limited to 1/second)

**Dependencies**: T-017

---

### T-019: Invoke Progress Callback at Import Completion
**Priority**: P1  
**Summary**: Invoke progress callback at import completion with final counts.

**Expected Files Touched**:
- `Sources/MediaHub/ImportExecution.swift` (update)

**Steps**:
1. Before returning `ImportResult` (after index update, after line 250), invoke progress callback with `ProgressUpdate(stage: "complete", current: importItemResults.count, total: importItemResults.count, message: nil)` (not throttled, final update)
2. Verify progress callback is invoked at completion
3. Verify callback includes final counts

**Done When**:
- Progress callback is invoked at import completion
- Callback includes correct stage name and final counts
- Final update is not throttled

**Dependencies**: T-018

---

### T-020: Add Unit Tests for Import Progress Callback Invocation
**Priority**: P1  
**Summary**: Create unit tests verifying import progress callbacks are invoked correctly.

**Expected Files Touched**:
- `Tests/MediaHubTests/ImportExecutionTests.swift` (update or new)

**Steps**:
1. Add test `testImportProgressCallbackInvocation()`:
   - Create mock progress callback that records all invocations
   - Call `executeImport` with progress callback
   - Verify callback is invoked during import loop with current/total counts
   - Verify callback is invoked at completion
   - Verify callback receives correct `ProgressUpdate` data
2. Add test `testImportProgressThrottling()`:
   - Create mock progress callback that records invocations
   - Call `executeImport` with progress callback on import batch with multiple items
   - Verify throttling logic works (callbacks are throttled, no exact timing requirements)

**Done When**:
- Progress callback tests compile and pass
- Tests verify callbacks are invoked with correct data
- Tests verify throttling works correctly

**Dependencies**: T-019

---

## Phase 5 — Import Cancellation Integration

**Plan Reference**: Phase 5 (lines 297-320)  
**Goal**: Add cancellation support to `ImportExecutor.executeImport`  
**Dependencies**: Phase 4 (Import Progress Integration)

### T-021: Add CancellationToken Parameter to ImportExecutor.executeImport
**Priority**: P1  
**Summary**: Add optional `cancellationToken` parameter to `executeImport` method signature.

**Expected Files Touched**:
- `Sources/MediaHub/ImportExecution.swift` (update)

**Steps**:
1. Add optional parameter `cancellationToken: CancellationToken? = nil` to `executeImport` method signature
2. Verify method signature compiles
3. Verify backward compatibility (existing callers without cancellationToken parameter continue to work)

**Done When**:
- Method signature includes cancellationToken parameter with `nil` default
- Existing callers compile without modification
- Method signature is correct

**Dependencies**: T-002, T-019

---

### T-022: Check Cancellation Between Items During Import
**Priority**: P1  
**Summary**: Check cancellation at safe points during import (between items, after current item completes).

**Expected Files Touched**:
- `Sources/MediaHub/ImportExecution.swift` (update)

**Steps**:
1. In the import loop (after line 120, after `processImportItem` completes), add cancellation check:
   - Check `cancellationToken?.isCanceled`
   - If `true`, throw `CancellationError.cancelled`
2. Verify cancellation check occurs after current item import completes atomically (safe point)
3. Verify `CancellationError.cancelled` is thrown when cancellation requested

**Done When**:
- Cancellation is checked between items (after current item completes)
- `CancellationError.cancelled` is thrown when cancellation requested
- Cancellation occurs at safe point (no partial file state)

**Dependencies**: T-021

---

### T-023: Ensure Already-Imported Items Remain on Import Cancellation
**Priority**: P1  
**Summary**: Verify import cancellation preserves already-imported items (no rollback).

**Expected Files Touched**:
- `Sources/MediaHub/ImportExecution.swift` (update)

**Steps**:
1. Verify cancellation check occurs after `processImportItem` completes (item is already imported)
2. Verify `successfullyImported` array contains all items imported before cancellation
3. Verify `knownItemsUpdateFailed` error handling does not rollback imported items
4. Verify index update (if any) preserves already-imported items

**Done When**:
- Already-imported items remain if canceled
- No rollback of completed items
- Index update (if any) preserves imported items

**Dependencies**: T-022

---

### T-024: Add Unit Tests for Import Cancellation
**Priority**: P1  
**Summary**: Create unit tests verifying import cancellation works correctly.

**Expected Files Touched**:
- `Tests/MediaHubTests/ImportExecutionTests.swift` (update or new)

**Steps**:
1. Add test `testImportCancellationDuringImport()`:
   - Create `CancellationToken` instance
   - Start import operation with cancellation token
   - Import first few items
   - Cancel token during import
   - Verify `CancellationError.cancelled` is thrown
   - Verify already-imported items remain in library
   - Verify no partial file state
2. Add test `testImportCancellationAtomicity()`:
   - Create `CancellationToken` instance
   - Start import operation with cancellation token
   - Cancel token during item import
   - Verify current item import completes atomically before cancellation
   - Verify no partial file state

**Done When**:
- Cancellation tests compile and pass
- Tests verify cancellation works during import
- Tests verify already-imported items remain
- Tests verify atomicity (no partial state)

**Dependencies**: T-023

---

## Phase 6 — Hash Maintenance Progress Integration

**Plan Reference**: Phase 6 (lines 322-345)  
**Goal**: Add progress callback support to `HashCoverageMaintenance.computeMissingHashes` (read-only integration)  
**Dependencies**: Phase 5 (Import Cancellation Integration)

### T-025: Add Progress Parameter to HashCoverageMaintenance.computeMissingHashes
**Priority**: P1  
**Summary**: Add optional `progress` parameter to `computeMissingHashes` method signature.

**Expected Files Touched**:
- `Sources/MediaHub/HashCoverageMaintenance.swift` (update)

**Steps**:
1. Add optional parameter `progress: ((ProgressUpdate) -> Void)? = nil` to `computeMissingHashes` method signature
2. Verify method signature compiles
3. Verify backward compatibility (existing callers without progress parameter continue to work)

**Done When**:
- Method signature includes progress parameter with `nil` default
- Existing callers compile without modification
- Method signature is correct

**Dependencies**: T-001

---

### T-026: Implement Progress Throttling Helper for Hash Maintenance
**Priority**: P1  
**Summary**: Create progress throttling helper for hash maintenance operations.

**Expected Files Touched**:
- `Sources/MediaHub/HashCoverageMaintenance.swift` (update)

**Steps**:
1. Add private helper struct `ProgressThrottle` inside `HashCoverageMaintenance` (duplication is acceptable, same structure as T-006):
   - Property `lastInvocationTime: Date? = nil`
   - Method `func shouldInvoke() -> Bool`
   - Method `func recordInvocation()`
2. Add helper method `invokeProgressIfNeeded(progress: ProgressUpdate, throttle: inout ProgressThrottle, callback: ((ProgressUpdate) -> Void)?)` (duplication is acceptable)

**Done When**:
- Progress throttling helper compiles
- Throttling logic limits callbacks (no exact timing requirements)
- No allocations or work when callback is `nil`

**Dependencies**: T-025

---

### T-027: Invoke Progress Callback During Hash Computation Loop
**Priority**: P1  
**Summary**: Invoke progress callback during hash computation loop with current/total counts.

**Expected Files Touched**:
- `Sources/MediaHub/HashCoverageMaintenance.swift` (update)

**Steps**:
1. In the hash computation loop (after line 315), initialize progress throttle (if progress callback provided)
2. After each file hash completes (after line 327, after hash computation), invoke progress callback with `ProgressUpdate(stage: "computing", current: fileIndex + 1, total: candidatesResult.candidates.count, message: nil)` (throttled)
3. Verify progress callback is invoked with correct current/total counts

**Done When**:
- Progress callback is invoked during hash computation loop
- Callback includes correct stage name and current/total counts
- Throttling is applied (callbacks limited to 1/second)

**Dependencies**: T-026

---

### T-028: Invoke Progress Callback at Hash Computation Completion
**Priority**: P1  
**Summary**: Invoke progress callback at hash computation completion with final counts.

**Expected Files Touched**:
- `Sources/MediaHub/HashCoverageMaintenance.swift` (update)

**Steps**:
1. Before returning `HashComputationResult` (after line 336), invoke progress callback with `ProgressUpdate(stage: "complete", current: computedHashes.count, total: candidatesResult.candidates.count, message: nil)` (not throttled, final update)
2. Verify progress callback is invoked at completion
3. Verify callback includes final counts

**Done When**:
- Progress callback is invoked at hash computation completion
- Callback includes correct stage name and final counts
- Final update is not throttled

**Dependencies**: T-027

---

### T-029: Add Unit Tests for Hash Maintenance Progress Callback Invocation
**Priority**: P1  
**Summary**: Create unit tests verifying hash maintenance progress callbacks are invoked correctly.

**Expected Files Touched**:
- `Tests/MediaHubTests/HashCoverageMaintenanceTests.swift` (update or new)

**Steps**:
1. Add test `testHashMaintenanceProgressCallbackInvocation()`:
   - Create mock progress callback that records all invocations
   - Call `computeMissingHashes` with progress callback
   - Verify callback is invoked during hash computation loop with current/total counts
   - Verify callback is invoked at completion
   - Verify callback receives correct `ProgressUpdate` data
2. Add test `testHashMaintenanceProgressThrottling()`:
   - Create mock progress callback that records invocations
   - Call `computeMissingHashes` with progress callback on library with multiple files
   - Verify throttling logic works (callbacks are throttled, no exact timing requirements)

**Done When**:
- Progress callback tests compile and pass
- Tests verify callbacks are invoked with correct data
- Tests verify throttling works correctly

**Dependencies**: T-028

---

## Phase 7 — Hash Maintenance Cancellation Integration

**Plan Reference**: Phase 7 (lines 347-370)  
**Goal**: Add cancellation support to `HashCoverageMaintenance.computeMissingHashes`  
**Dependencies**: Phase 6 (Hash Maintenance Progress Integration)

### T-030: Add CancellationToken Parameter to HashCoverageMaintenance.computeMissingHashes
**Priority**: P1  
**Summary**: Add optional `cancellationToken` parameter to `computeMissingHashes` method signature.

**Expected Files Touched**:
- `Sources/MediaHub/HashCoverageMaintenance.swift` (update)

**Steps**:
1. Add optional parameter `cancellationToken: CancellationToken? = nil` to `computeMissingHashes` method signature
2. Verify method signature compiles
3. Verify backward compatibility (existing callers without cancellationToken parameter continue to work)

**Done When**:
- Method signature includes cancellationToken parameter with `nil` default
- Existing callers compile without modification
- Method signature is correct

**Dependencies**: T-002, T-028

---

### T-031: Check Cancellation Between Files During Hash Computation
**Priority**: P1  
**Summary**: Check cancellation at safe points during hash computation (between files, after current file hash completes).

**Expected Files Touched**:
- `Sources/MediaHub/HashCoverageMaintenance.swift` (update)

**Steps**:
1. In the hash computation loop (after line 327, after hash computation completes), add cancellation check:
   - Check `cancellationToken?.isCanceled`
   - If `true`, throw `CancellationError.cancelled`
2. Verify cancellation check occurs after current file hash completes (safe point)
3. Verify `CancellationError.cancelled` is thrown when cancellation requested

**Done When**:
- Cancellation is checked between files (after current file hash completes)
- `CancellationError.cancelled` is thrown when cancellation requested
- Cancellation occurs at safe point (no partial hash state)

**Dependencies**: T-030

---

### T-032: Ensure Already-Computed Hashes Remain on Hash Cancellation
**Priority**: P1  
**Summary**: Verify hash cancellation preserves already-computed hashes (no rollback, atomic index update).

**Expected Files Touched**:
- `Sources/MediaHub/HashCoverageMaintenance.swift` (update)

**Steps**:
1. Verify cancellation check occurs after hash computation completes (hash is already computed and stored in `computedHashes` map)
2. Verify `computedHashes` map contains all hashes computed before cancellation
3. Verify index update (if any) uses write-then-rename pattern (atomic, no partial index state)
4. Verify `applyComputedHashesAndWriteIndex` preserves already-computed hashes even if canceled

**Done When**:
- Already-computed hashes remain if canceled
- No rollback of completed hashes
- Index update (if any) is atomic (write-then-rename pattern)

**Dependencies**: T-031

---

### T-033: Add Unit Tests for Hash Maintenance Cancellation
**Priority**: P1  
**Summary**: Create unit tests verifying hash maintenance cancellation works correctly.

**Expected Files Touched**:
- `Tests/MediaHubTests/HashCoverageMaintenanceTests.swift` (update or new)

**Steps**:
1. Add test `testHashMaintenanceCancellationDuringComputation()`:
   - Create `CancellationToken` instance
   - Start hash computation operation with cancellation token
   - Compute hashes for first few files
   - Cancel token during hash computation
   - Verify `CancellationError.cancelled` is thrown
   - Verify already-computed hashes remain in `computedHashes` map
   - Verify no partial index state
2. Add test `testHashMaintenanceCancellationAtomicity()`:
   - Create `CancellationToken` instance
   - Start hash computation operation with cancellation token
   - Cancel token during file hash computation
   - Verify current file hash completes atomically before cancellation
   - Verify no partial hash state

**Done When**:
- Cancellation tests compile and pass
- Tests verify cancellation works during hash computation
- Tests verify already-computed hashes remain
- Tests verify atomicity (no partial state)

**Dependencies**: T-032

---

## Phase 8 — Integration Testing & Performance Validation

**Plan Reference**: Phase 8 (lines 372-395)  
**Goal**: Verify backward compatibility, zero overhead when unused, and integration correctness  
**Dependencies**: Phase 7 (Hash Maintenance Cancellation Integration)

### T-034: Run All Existing Tests and Verify No Regressions
**Priority**: P1  
**Summary**: Run all existing tests and verify backward compatibility.

**Expected Files Touched**:
- No code changes (test execution only)

**Steps**:
1. Run `swift test` to execute all existing tests
2. Verify all existing tests pass (no regressions)
3. Verify CLI commands continue to work without modification
4. Verify Core API callers (tests, CLI) continue to work without modification

**Done When**:
- All existing tests pass
- CLI commands work without modification
- No regressions detected

**Dependencies**: T-015, T-024, T-033

---

### T-035: Verify Zero Overhead When Progress/Cancel Are Nil
**Priority**: P1  
**Summary**: Verify code review confirms no additional allocations or work when progress/cancel are `nil`.

**Expected Files Touched**:
- No code changes (code review only)

**Steps**:
1. Code review: Verify `executeDetection` has no allocations or computations when progress/cancel are `nil` (conditional checks only)
2. Code review: Verify `executeImport` has no allocations or computations when progress/cancel are `nil` (conditional checks only)
3. Code review: Verify `computeMissingHashes` has no allocations or computations when progress/cancel are `nil` (conditional checks only)
4. Verify conditional checks use `if let` or `guard let` patterns

**Done When**:
- Code review confirms no allocations or computations when parameters are `nil`
- Conditional checks verified for all operations

**Dependencies**: T-034

---

### T-036: [P2] Optional: Integration Test: Progress/Cancel End-to-End
**Priority**: P2  
**Summary**: Optional integration tests verifying progress/cancel work correctly across all operations (post-freeze if needed).

**Expected Files Touched**:
- `Tests/MediaHubTests/ProgressCancelIntegrationTests.swift` (new, optional)

**Steps**:
1. Add optional test `testDetectionProgressCancelIntegration()` (if needed post-freeze)
2. Add optional test `testImportProgressCancelIntegration()` (if needed post-freeze)
3. Add optional test `testHashMaintenanceProgressCancelIntegration()` (if needed post-freeze)

**Done When**:
- Optional integration tests compile and pass (if implemented)
- Tests verify progress/cancel work correctly (if implemented)

**Dependencies**: T-035

**Note**: Optional/post-freeze. Slice is complete without this task. Functional unit tests from previous phases are sufficient.

---

### T-037: [P2] Optional: Verify Thread Safety of Cancellation Token in Operations
**Priority**: P2  
**Summary**: Optional integration tests verifying thread safety of cancellation token in operations (post-freeze if needed).

**Expected Files Touched**:
- `Tests/MediaHubTests/ProgressCancelIntegrationTests.swift` (update, optional)

**Steps**:
1. Add optional test `testCancellationTokenThreadSafetyInOperations()` (if needed post-freeze)
2. Thread safety of `CancellationToken` itself is already tested in T-004

**Done When**:
- Optional thread safety tests compile and pass (if implemented)

**Dependencies**: T-036

**Note**: Optional/post-freeze. Slice is complete without this task. Thread safety of `CancellationToken` is verified in T-004.

---

## Phase 9 — Optional Polish (P2)

**Note**: Slice is complete without Phase 9. Phase 9 tasks are optional/post-freeze.

### T-038: [P2] Optional: CLI Integration with Core Progress API
**Priority**: P2  
**Summary**: Optionally wire CLI `ProgressIndicator` to Core progress API (internal implementation detail, user-facing output unchanged).

**Expected Files Touched**:
- `Sources/MediaHubCLI/DetectCommand.swift` (update, optional)
- `Sources/MediaHubCLI/ImportCommand.swift` (update, optional)
- `Sources/MediaHubCLI/IndexCommand.swift` (update, optional)

**Steps**:
1. Optionally create progress callback that forwards to `ProgressIndicator.show`
2. Optionally pass progress callback to Core APIs in CLI commands
3. Verify CLI user-facing output remains unchanged (stderr via `ProgressIndicator`)
4. Verify this is internal implementation detail (no CLI behavior change)

**Done When**:
- CLI optionally uses Core progress API internally
- User-facing output remains unchanged
- No CLI behavior change

**Dependencies**: T-037

**Note**: Optional/post-freeze. Slice is complete without this task.

---

## Task Dependency Graph

```
T-001 (ProgressUpdate)
  └─> T-002 (CancellationToken)
  └─> T-003 (CancellationError)
  └─> T-005 (Detection Progress Parameter)
  └─> T-016 (Import Progress Parameter)
  └─> T-025 (Hash Progress Parameter)

T-002 └─> T-004 (Thread Safety Tests)
T-002 └─> T-011 (Detection Cancel Parameter)
T-002 └─> T-021 (Import Cancel Parameter)
T-002 └─> T-030 (Hash Cancel Parameter)

T-005 └─> T-006 (Detection Progress Throttling)
T-006 └─> T-007 (Detection Scanning Progress)
T-007 └─> T-008 (Detection Comparison Progress)
T-008 └─> T-009 (Detection Completion Progress)
T-009 └─> T-010 (Detection Progress Tests)

T-011 └─> T-012 (Detection Scanning Cancellation)
T-012 └─> T-013 (Detection Comparison Cancellation)
T-013 └─> T-014 (Detection Cancellation Safety)
T-014 └─> T-015 (Detection Cancellation Tests)

T-016 └─> T-017 (Import Progress Throttling)
T-017 └─> T-018 (Import Loop Progress)
T-018 └─> T-019 (Import Completion Progress)
T-019 └─> T-020 (Import Progress Tests)

T-021 └─> T-022 (Import Cancellation Check)
T-022 └─> T-023 (Import Cancellation Safety)
T-023 └─> T-024 (Import Cancellation Tests)

T-025 └─> T-026 (Hash Progress Throttling)
T-026 └─> T-027 (Hash Loop Progress)
T-027 └─> T-028 (Hash Completion Progress)
T-028 └─> T-029 (Hash Progress Tests)

T-030 └─> T-031 (Hash Cancellation Check)
T-031 └─> T-032 (Hash Cancellation Safety)
T-032 └─> T-033 (Hash Cancellation Tests)

T-015, T-024, T-033 └─> T-034 (All Tests)
T-034 └─> T-035 (Zero Overhead Code Review)

T-035 └─> T-036 (Optional Integration Tests, P2)
T-036 └─> T-037 (Optional Thread Safety Tests, P2)
T-037 └─> T-038 (Optional CLI Integration, P2)
```

---

## Summary

- **Total Tasks**: 38 (34 P1, 4 P2 optional)
- **Phases**: 8 implementation phases + 1 optional polish phase
- **Dependencies**: Sequential within phases, cross-phase dependencies for cancellation (requires progress first)
- **Testing**: Functional unit tests for each component (required), optional integration tests (P2/post-freeze)
- **Backward Compatibility**: All tasks maintain backward compatibility (optional parameters with `nil` defaults)
- **Minimal API**: ProgressThrottle duplication is acceptable (no shared helper required)
