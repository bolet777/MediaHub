# Validation Checklist: Slice 1 — Library Entity (P1)

**Feature**: MediaHub Library Entity  
**Specification**: `specs/001-library-entity/spec.md`  
**Tasks**: `specs/001-library-entity/tasks.md` (P1 only)  
**Constitution**: `CONSTITUTION.md`  
**Created**: 2025-01-27

## Overview

This document provides a concrete validation package for Slice 1 (P1) of the MediaHub Library Entity feature. It includes explicit commands to run, acceptance scenarios to verify, and clear pass/fail criteria.

## Validation Result

Status: VALIDATED  
Date: 2026-01-12  
Evidence: `swift build` (PASS), `swift test` (PASS)

## Validation Commands

### 1. Build the Package

```bash
swift build
```

**Pass Criteria**: Build completes without errors or warnings.

**Fail Criteria**: Any compilation errors or warnings.

---

### 2. Run All Tests

```bash
swift test
```

**Pass Criteria**: All tests pass without failures.

**Fail Criteria**: Any test failures or crashes.

---

### 3. Run Tests with Verbose Output

```bash
swift test --verbose
```

**Pass Criteria**: All tests pass, output shows test execution details.

**Fail Criteria**: Any test failures or crashes.

---

## Acceptance Scenarios

### Scenario 1: Create Library in Empty Folder

**Given**: An empty directory exists  
**When**: A user creates a new MediaHub library at that location  
**Then**: The library structure is created and can be opened

**Test Coverage**: `LibraryCreationTests.testCreateLibraryInEmptyFolder`

**Pass Criteria**:
- Library structure is created (`.mediahub/` directory exists)
- Metadata file (`.mediahub/library.json`) is created
- Metadata contains valid UUID identifier
- Metadata contains valid ISO-8601 timestamp
- Library can be opened and validated after creation
- Library structure matches specification

**Fail Criteria**:
- Structure creation fails
- Metadata file is missing or invalid
- Identifier is not a valid UUID
- Timestamp is not valid ISO-8601
- Library cannot be opened after creation
- Structure does not match specification

---

### Scenario 2: Attach/Open Existing Library by Path

**Given**: A MediaHub library exists on disk  
**When**: A user opens the library by specifying its path  
**Then**: The library is recognized and opened successfully

**Test Coverage**: `LibraryOpeningTests.testOpenExistingLibraryByPath`

**Pass Criteria**:
- Library is detected at the specified path
- Metadata is read successfully
- Library structure is validated
- Library is set as active library
- Opened library contains correct metadata
- Library can be used for subsequent operations

**Fail Criteria**:
- Library is not detected
- Metadata read fails
- Structure validation fails
- Library is not set as active
- Opened library metadata is incorrect

---

### Scenario 3: Move/Rename Library and Re-open (Identity Persistence)

**Given**: A MediaHub library exists at path A  
**When**: The library is moved/renamed to path B and reopened  
**Then**: The library maintains its unique identifier and can be opened

**Test Coverage**: `LibraryIdentityPersistenceTests.testLibraryIdentityPersistsAfterMove`

**Pass Criteria**:
- Library identifier remains unchanged after move
- Library can be opened at new location
- Identifier-based lookup works after move
- Registry updates correctly when path changes
- Identity validation passes after move

**Fail Criteria**:
- Library identifier changes after move
- Library cannot be opened at new location
- Identifier-based lookup fails
- Registry does not update
- Identity validation fails

---

### Scenario 4: Corrupted/Missing Metadata Produces Clear Error

**Given**: A library directory exists but metadata is corrupted or missing  
**When**: A user attempts to open the library  
**Then**: A clear, actionable error message is provided

**Test Coverage**: 
- `LibraryValidationTests.testOpenLibraryWithMissingMetadata`
- `LibraryValidationTests.testOpenLibraryWithCorruptedMetadata`

**Pass Criteria**:
- Missing metadata is detected
- Corrupted metadata is detected
- Error messages are clear and actionable
- Error messages explain what went wrong
- Error messages suggest remediation steps
- Validation errors are properly categorized

**Fail Criteria**:
- Missing metadata is not detected
- Corrupted metadata is not detected
- Error messages are unclear or generic
- Error messages don't explain the issue
- Error messages don't suggest remediation
- Validation errors are misclassified

---

### Scenario 5: Prevent Creating Inside Existing Library

**Given**: A MediaHub library already exists at a location  
**When**: A user attempts to create a new library at that location  
**Then**: The system detects the existing library and offers to open/attach it instead

**Test Coverage**: `LibraryCreationTests.testPreventCreatingInsideExistingLibrary`

**Pass Criteria**:
- Existing library is detected before creation
- Creation is prevented
- User is offered to open existing library
- Error message is clear and actionable
- System does not create duplicate library structure

**Fail Criteria**:
- Existing library is not detected
- Creation proceeds despite existing library
- No offer to open existing library
- Error message is unclear
- Duplicate library structure is created

---

## Test Execution Checklist

### Pre-Test Setup

- [ ] Ensure test environment is clean (no leftover test libraries)
- [ ] Verify Swift toolchain is available (`swift --version`)
- [ ] Verify package can be built (`swift build`)

### Test Execution

- [ ] Run `swift test` - all tests pass
- [ ] Run `swift test --verbose` - verify detailed output
- [ ] Check test coverage for all P1 scenarios
- [ ] Verify tests use temporary directories (filesystem isolation)
- [ ] Verify tests are deterministic (same inputs produce same outputs)

### Post-Test Verification

- [ ] All temporary test directories are cleaned up
- [ ] No test artifacts remain in filesystem
- [ ] Test output shows all scenarios covered
- [ ] No memory leaks or resource issues

---

## Key P1 Workflow Tests

### Test Suite: LibraryCreationTests

1. **testCreateLibraryInEmptyFolder**
   - Creates library in empty temp directory
   - Verifies structure creation
   - Verifies metadata creation
   - Verifies library can be opened

2. **testPreventCreatingInsideExistingLibrary**
   - Creates a library first
   - Attempts to create another at same location
   - Verifies existing library is detected
   - Verifies creation is prevented
   - Verifies offer to open existing library

3. **testCreateLibraryInNonEmptyDirectoryWithConfirmation**
   - Creates library in non-empty directory
   - Verifies confirmation workflow
   - Verifies library is created after confirmation

### Test Suite: LibraryOpeningTests

1. **testOpenExistingLibraryByPath**
   - Creates a library
   - Opens it by path
   - Verifies library is opened correctly
   - Verifies library is set as active

2. **testOpenLibraryByIdentifier**
   - Creates a library
   - Opens it by identifier
   - Verifies library is opened correctly

### Test Suite: LibraryIdentityPersistenceTests

1. **testLibraryIdentityPersistsAfterMove**
   - Creates a library
   - Records original identifier
   - Moves library to new location
   - Reopens library at new location
   - Verifies identifier is unchanged

2. **testLibraryIdentityPersistsAfterRename**
   - Creates a library
   - Records original identifier
   - Renames library directory
   - Reopens library at new path
   - Verifies identifier is unchanged

### Test Suite: LibraryValidationTests

1. **testOpenLibraryWithMissingMetadata**
   - Creates library structure without metadata
   - Attempts to open library
   - Verifies clear error message for missing metadata

2. **testOpenLibraryWithCorruptedMetadata**
   - Creates library with corrupted metadata file
   - Attempts to open library
   - Verifies clear error message for corrupted metadata

3. **testValidateLibraryStructure**
   - Creates valid library
   - Verifies validation passes
   - Removes required structure elements
   - Verifies validation fails with clear errors

---

## Pass/Fail Criteria Summary

### Overall Pass Criteria

✅ All tests pass (`swift test` exits with code 0)  
✅ All acceptance scenarios are covered by tests  
✅ Tests use temporary directories (filesystem isolation)  
✅ Tests are deterministic  
✅ Error messages are clear and actionable  
✅ Library identity persists across moves/renames  
✅ Existing libraries are detected and protected  
✅ Corrupted/missing metadata produces clear errors  

### Overall Fail Criteria

❌ Any test failures  
❌ Missing test coverage for acceptance scenarios  
❌ Tests modify filesystem outside temp directories  
❌ Tests are non-deterministic  
❌ Error messages are unclear or generic  
❌ Library identity is lost after moves/renames  
❌ Existing libraries are not detected  
❌ Corrupted/missing metadata errors are unclear  

---

## Validation Report Template

After running validation, document results:

```
Validation Date: [DATE]
Swift Version: [VERSION]
Package Version: [VERSION]

Build Status: [PASS/FAIL]
Test Status: [PASS/FAIL]
Test Count: [NUMBER]

Scenario Coverage:
- Scenario 1 (Create in Empty Folder): [PASS/FAIL]
- Scenario 2 (Open by Path): [PASS/FAIL]
- Scenario 3 (Identity Persistence): [PASS/FAIL]
- Scenario 4 (Corrupted/Missing Metadata): [PASS/FAIL]
- Scenario 5 (Prevent Creating Inside Existing): [PASS/FAIL]

Issues Found: [LIST ANY ISSUES]
Notes: [ANY ADDITIONAL NOTES]
```

---

## References

- Specification: `specs/001-library-entity/spec.md`
- Tasks: `specs/001-library-entity/tasks.md`
- Constitution: `CONSTITUTION.md`
- Test Files: `Tests/MediaHubTests/`
