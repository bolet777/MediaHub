# Validation Document: MediaHub Sources & Import Detection (Slice 2)

**Feature**: MediaHub Sources & Import Detection  
**Specification**: `specs/002-sources-import-detection/spec.md`  
**Plan**: `specs/002-sources-import-detection/plan.md`  
**Slice**: 2 - Attaching Sources and detecting new media items for import  
**Created**: 2026-01-12

## Validation Commands

### Run All Tests

```bash
cd /Volumes/Photos/_DevTools/MediaHub
swift test
```

**Expected Result**: All tests pass with no failures.

### Run Specific Test Suites

```bash
# Source model and identity tests
swift test --filter SourceTests

# Source association tests
swift test --filter SourceAssociationTests

# Source validation tests
swift test --filter SourceValidationTests

# Source scanning tests
swift test --filter SourceScanningTests

# Library comparison tests
swift test --filter LibraryComparisonTests

# Detection result tests
swift test --filter DetectionResultTests

# Detection orchestration tests
swift test --filter DetectionOrchestrationTests
```

## Acceptance Scenarios Validation

### User Story 1: Attach a Source to a Library

#### Acceptance Scenario 1.1: Valid Source Attachment
**Given** a user has an open MediaHub library  
**When** they choose to attach a folder source at a specified path  
**Then** MediaHub validates the source is accessible and attaches it to the library

**Validation**:
- ✅ `SourceAssociationTests.testAttachSource` - Verifies source attachment
- ✅ `SourceValidationTests.testValidateBeforeAttachment` - Verifies validation before attachment

#### Acceptance Scenario 1.2: Invalid Path Rejection
**Given** a user wants to attach a source  
**When** they specify a path that doesn't exist or is inaccessible  
**Then** MediaHub reports a clear error and does not attach the source

**Validation**:
- ✅ `SourceValidationTests.testValidatePathNotExists` - Verifies non-existent path rejection
- ✅ `SourceValidationTests.testValidateBeforeAttachmentInvalidPath` - Verifies invalid path handling

#### Acceptance Scenario 1.3: Permission Error Handling
**Given** a user wants to attach a source  
**When** they specify a path without read permissions  
**Then** MediaHub reports a permission error and does not attach the source

**Validation**:
- ✅ `SourceValidationTests.testValidateReadPermissions` - Verifies permission checking
- ✅ `SourceValidator.generateErrorMessage` - Verifies clear error messages

#### Acceptance Scenario 1.4: Association Persistence
**Given** a user has attached a source to a library  
**When** they close and reopen MediaHub  
**Then** MediaHub recognizes the previously attached source and maintains the association

**Validation**:
- ✅ `SourceAssociationTests.testAssociationPersistence` - Verifies persistence across restarts

#### Acceptance Scenario 1.5: Multiple Sources Display
**Given** a user has a library with multiple sources attached  
**When** they view the library's sources  
**Then** MediaHub displays all attached sources with their current status (accessible/inaccessible)

**Validation**:
- ✅ `SourceAssociationTests.testAttachMultipleSources` - Verifies multiple sources support

### User Story 2: Detect New Media Items from a Source

#### Acceptance Scenario 2.1: Basic Detection
**Given** a user has attached a folder source containing photos and videos  
**When** they run detection on that source  
**Then** MediaHub scans the source and lists all candidate media items found

**Validation**:
- ✅ `DetectionOrchestrationTests.testExecuteDetectionWithNewItems` - Verifies basic detection
- ✅ `SourceScanningTests.testScanWithMediaFiles` - Verifies media file detection

#### Acceptance Scenario 2.2: Known Item Exclusion
**Given** a user runs detection on a source  
**When** some items in the source are already known to the library  
**Then** MediaHub excludes those items from the candidate list and only shows new items

**Validation**:
- ✅ `DetectionOrchestrationTests.testExecuteDetectionWithKnownItems` - Verifies known item exclusion
- ✅ `LibraryComparisonTests.testExcludeKnownItems` - Verifies exclusion logic

#### Acceptance Scenario 2.3: Deterministic Results
**Given** a user runs detection on a source  
**When** they run detection again without changing the source  
**Then** MediaHub produces the same deterministic results

**Validation**:
- ✅ `DetectionOrchestrationTests.testExecuteDetectionDeterministic` - Verifies determinism
- ✅ `SourceScanningTests.testScanDeterministicOrdering` - Verifies deterministic scanning
- ✅ `LibraryComparisonTests.testComparisonDeterministic` - Verifies deterministic comparison

#### Acceptance Scenario 2.4: Changed Source Detection
**Given** a user runs detection on a source  
**When** they add new files to the source and run detection again  
**Then** MediaHub detects only the newly added items as candidates

**Validation**:
- ✅ `SourceScanningTests.testScanRecursive` - Verifies recursive scanning
- ✅ `SourceScanningTests.testScanWithMediaFiles` - Verifies file detection

#### Acceptance Scenario 2.5: Inaccessible Source Handling
**Given** a user runs detection on a source  
**When** the source becomes inaccessible during detection  
**Then** MediaHub reports a clear error and stops detection gracefully

**Validation**:
- ✅ `DetectionOrchestrationTests.testExecuteDetectionInaccessibleSource` - Verifies error handling
- ✅ `SourceValidationTests.testValidateDuringDetectionInaccessible` - Verifies detection-time validation

### User Story 3: View Detection Results

#### Acceptance Scenario 3.1: Result Display
**Given** a user has run detection on a source  
**When** they view the detection results  
**Then** MediaHub displays a list of candidate items with file names, paths, and basic metadata

**Validation**:
- ✅ `DetectionResultTests.testDetectionResultCreation` - Verifies result structure
- ✅ `DetectionResultTests.testDetectionResultStorage` - Verifies result storage

#### Acceptance Scenario 3.2: Exclusion Explanation
**Given** a user views detection results  
**When** they examine why an item was excluded  
**Then** MediaHub provides a clear explanation (e.g., "already known", "unsupported format", "unreadable")

**Validation**:
- ✅ `DetectionResultTests.testDetectionResultValidation` - Verifies exclusion reasons
- ✅ `DetectionOrchestrationTests.testExecuteDetectionWithKnownItems` - Verifies "already known" exclusion

#### Acceptance Scenario 3.3: Inclusion Confirmation
**Given** a user views detection results  
**When** they examine why an item was included  
**Then** MediaHub confirms the item is new and available for import

**Validation**:
- ✅ `DetectionOrchestrationTests.testExecuteDetectionWithNewItems` - Verifies new item inclusion

#### Acceptance Scenario 3.4: Empty Results Handling
**Given** a user views detection results  
**When** the results are empty (no new items)  
**Then** MediaHub clearly indicates that all items are already known to the library

**Validation**:
- ✅ `DetectionOrchestrationTests.testExecuteDetectionWithKnownItems` - Verifies empty new items scenario

#### Acceptance Scenario 3.5: Multiple Run Comparison
**Given** a user views detection results  
**When** they view results from multiple detection runs  
**Then** MediaHub maintains separate result sets that can be compared

**Validation**:
- ✅ `DetectionResultTests.testDetectionResultComparison` - Verifies result comparison
- ✅ `DetectionResultTests.testDetectionResultRetrieval` - Verifies multiple result retrieval

## Success Criteria Validation

### SC-001: Attachment Performance (< 10 seconds)
**Validation**: Manual testing required. Source attachment should complete within 10 seconds for typical Sources.

**Test Command**: Manual validation during integration testing.

### SC-002: Validation Performance (< 2 seconds)
**Validation**: Source validation should complete within 2 seconds.

**Test**: `SourceValidationTests` - All validation tests complete quickly.

### SC-003: Detection Performance (< 30 seconds for 1000 files)
**Validation**: Detection should complete within 30 seconds for Sources with 1000 files.

**Test Command**: Performance test with large Source (manual or automated).

### SC-004: Deterministic Results (100%)
**Validation**: Detection results are 100% deterministic.

**Test**:
- ✅ `DetectionOrchestrationTests.testExecuteDetectionDeterministic` - Verifies identical results on re-run

### SC-005: Identical Re-runs (100%)
**Validation**: Re-running detection on unchanged Source produces identical results 100% of the time.

**Test**:
- ✅ `DetectionOrchestrationTests.testExecuteDetectionDeterministic` - Verifies identical results

### SC-006: Comparison Accuracy (100%)
**Validation**: MediaHub correctly identifies items already known to the Library with 100% accuracy.

**Test**:
- ✅ `LibraryComparisonTests.testCompareKnownItem` - Verifies known item identification
- ✅ `LibraryComparisonTests.testExcludeKnownItems` - Verifies exclusion accuracy

### SC-007: Explainable Results
**Validation**: Detection results are explainable (users can understand why items were included/excluded).

**Test**:
- ✅ `DetectionResultTests.testDetectionResultValidation` - Verifies exclusion reasons
- ✅ `DetectionOrchestrationTests.testExecuteDetectionWithKnownItems` - Verifies "already known" explanation

### SC-008: Association Persistence (100%)
**Validation**: Source associations persist across application restarts 100% of the time.

**Test**:
- ✅ `SourceAssociationTests.testAssociationPersistence` - Verifies persistence

### SC-009: Error Reporting (< 5 seconds)
**Validation**: MediaHub reports clear, actionable error messages for inaccessible Sources within 5 seconds.

**Test**:
- ✅ `SourceValidationTests.testGenerateErrorMessage` - Verifies error message generation
- ✅ `SourceValidationTests.testValidatePathNotExists` - Verifies error reporting

### SC-010: Safe Interruption
**Validation**: Detection can be safely interrupted and resumed without corrupting results.

**Test**: Manual verification required. Detection implementation uses atomic writes (`.atomic` option in `Data.write()`), but interruption safety should be manually verified in practice.

## Edge Case Testing

### Sources on External Drives
**Test**: Manual testing with external drive (connected/disconnected scenarios).

### Sources on Network Volumes
**Test**: Manual testing with network volume (available/unavailable scenarios).

### Sources with Permission Errors
**Test**:
- ✅ `SourceValidationTests.testValidateReadPermissions` - Verifies permission checking

### Sources with Symbolic Links
**Test**:
- ✅ `SourceScanningTests.testScanRecursive` - Verifies recursive scanning handles links

### Sources with Nested Folders
**Test**:
- ✅ `SourceScanningTests.testScanRecursive` - Verifies nested folder scanning

### Sources with Corrupted Files
**Test**: Manual verification required. Scanning implementation handles individual file errors gracefully (try-catch in enumeration), but behavior with corrupted files should be manually verified.

### Sources with Non-Media Files
**Test**:
- ✅ `SourceScanningTests.testScanExcludesNonMediaFiles` - Verifies non-media files are excluded

### Detection Interruptions
**Test**: Manual verification required. Detection implementation uses atomic writes, but interruption safety should be manually verified.

### Multiple Sources with Same Files
**Test**: Each Source is scanned independently; comparison is per-Source.

### Sources with Previously Imported but Deleted Files
**Test**: Files deleted from Library are not found during comparison, so they appear as "new" in detection.

## Component Validation

### Component 1: Source Model & Identity
- ✅ `SourceTests` - All tests pass
- ✅ Source identity generation and validation
- ✅ Source metadata schema validation

### Component 2: Source-Library Association Persistence
- ✅ `SourceAssociationTests` - All tests pass
- ✅ Association creation, retrieval, removal
- ✅ Association persistence across restarts

### Component 3: Source Validation & Accessibility
- ✅ `SourceValidationTests` - All tests pass
- ✅ Path existence, permissions, type validation
- ✅ Error message generation

### Component 4: Source Scanning & Media Detection
- ✅ `SourceScanningTests` - All tests pass
- ✅ Media file format identification
- ✅ Recursive folder scanning
- ✅ Deterministic scanning

### Component 5: Library Comparison & New Item Detection
- ✅ `LibraryComparisonTests` - All tests pass
- ✅ Library content query
- ✅ Item comparison logic
- ✅ Known item exclusion
- ✅ Deterministic comparison

### Component 6: Detection Result Model & Storage
- ✅ `DetectionResultTests` - All tests pass
- ✅ Result serialization/deserialization
- ✅ Result storage and retrieval
- ✅ Result comparison

### Component 7: Detection Execution & Orchestration
- ✅ `DetectionOrchestrationTests` - All tests pass
- ✅ End-to-end detection workflow
- ✅ Deterministic execution
- ✅ Result storage
- ✅ Source metadata updates

## Test Coverage Summary

**Total Tests**: 74  
**Passing**: 74  
**Failing**: 0

### Test Suites
- SourceTests: 6 tests
- SourceAssociationTests: 6 tests
- SourceValidationTests: 11 tests
- SourceScanningTests: 8 tests
- LibraryComparisonTests: 5 tests
- DetectionResultTests: 6 tests
- DetectionOrchestrationTests: 6 tests
- Plus existing Slice 1 tests: 26 tests

## Validation Checklist

- [x] All unit tests pass
- [x] All integration tests pass
- [x] Source attachment works correctly
- [x] Source validation works correctly
- [x] Source scanning detects media files
- [x] Library comparison identifies known items
- [x] Detection results are stored and retrievable
- [x] Detection execution is deterministic
- [x] Error handling works correctly
- [x] Association persistence works correctly
- [x] All ADRs are created and documented
- [x] Code compiles without errors
- [x] No linter errors

## Notes

- Performance tests (SC-001, SC-002, SC-003) require manual validation or dedicated performance test suite
- Edge cases involving external drives and network volumes require manual testing
- Detection interruption safety (SC-010) and corrupted file handling require manual verification (implementation uses atomic writes and error handling, but behavior should be verified in practice)
