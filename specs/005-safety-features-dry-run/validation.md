# Validation: Safety Features & Dry-Run Operations (Slice 5)

**Feature**: Safety Features & Dry-Run Operations  
**Specification**: `specs/005-safety-features-dry-run/spec.md`  
**Plan**: `specs/005-safety-features-dry-run/plan.md`  
**Tasks**: `specs/005-safety-features-dry-run/tasks.md`  
**Created**: 2026-01-27

## Structure Sanity Validation (MUST RUN BEFORE BUILD)

**CRITICAL**: These validations MUST pass before attempting to build. If any fail, STOP and fix the structure issues.

### Structure Validation 1: CLI Code Location
- **Check**: Verify all CLI changes are in `Sources/MediaHubCLI/` (NOT `Sources/MediaHub/`)
- **Command**: `find Sources/MediaHubCLI -name "*.swift" -newer specs/005-safety-features-dry-run/spec.md -type f | wc -l | xargs -I {} test {} -gt 0 && echo "PASS: CLI files modified" || echo "INFO: No CLI files modified yet"`
- **Expected**: `PASS: CLI files modified` or `INFO: No CLI files modified yet` (during implementation)
- **Status**: ⬜ TODO

### Structure Validation 2: Core Code Changes Minimal
- **Check**: Verify core changes are minimal (only `ImportExecution.swift` for dry-run support)
- **Command**: `find Sources/MediaHub -name "*.swift" -newer specs/005-safety-features-dry-run/spec.md -type f | grep -v ImportExecution.swift | wc -l | xargs -I {} test {} -eq 0 && echo "PASS: Only ImportExecution.swift modified in core" || echo "WARN: Other core files modified (verify this is intentional)"`
- **Expected**: `PASS: Only ImportExecution.swift modified in core` (or intentional changes documented)
- **Status**: ⬜ TODO

### Structure Validation 3: No Breaking Changes to Existing CLI
- **Check**: Verify existing CLI commands still work without new flags
- **Command**: `swift run mediahub import --help | grep -q "dry-run\|yes" && echo "PASS: New flags available" || echo "INFO: New flags not yet added"`
- **Expected**: `PASS: New flags available` (after implementation)
- **Status**: ⬜ TODO

**If any structure validation fails, DO NOT proceed with build. Fix structure issues first.**

---

## Safety Features Smoke Test Checklist

This checklist provides a quick validation that safety features are properly implemented and functional.

### Smoke Test 1: Dry-Run Flag Recognition
- **Test**: Verify `--dry-run` flag is recognized by CLI
- **Command**: `swift run mediahub import --help | grep -q "dry-run" && echo "PASS" || echo "FAIL"`
- **Expected**: `PASS`
- **Status**: ⬜ TODO

### Smoke Test 2: Dry-Run Performs Zero File Operations
- **Test**: Run dry-run import and verify no source files or library media files are copied
- **Setup**: Create test library and source with media files
- **Command**: `swift run mediahub import <source-id> --all --dry-run --library <path> && find <library-path> -type f -not -path "*/.mediahub/*" | wc -l | xargs -I {} test {} -eq 0 && echo "PASS: No media files copied" || echo "FAIL: Media files were copied"`
- **Expected**: `PASS: No media files copied`
- **Status**: ⬜ TODO

### Smoke Test 3: Dry-Run Preview Accuracy
- **Test**: Compare dry-run preview with actual import results
- **Setup**: Run dry-run, note preview, then run actual import, compare results
- **Command**: Manual comparison of dry-run preview vs actual import
- **Expected**: Dry-run preview matches actual import results (same destination paths, same collision handling)
- **Status**: ⬜ TODO

### Smoke Test 4: Confirmation Prompt Appears
- **Test**: Verify confirmation prompt appears when `--yes` is not provided
- **Command**: `echo "no" | swift run mediahub import <source-id> --all --library <path> 2>&1 | grep -q "Import.*items" && echo "PASS: Confirmation prompt appeared" || echo "FAIL: No confirmation prompt"`
- **Expected**: `PASS: Confirmation prompt appeared`
- **Status**: ⬜ TODO

### Smoke Test 5: --yes Flag Bypasses Confirmation
- **Test**: Verify `--yes` flag skips confirmation prompt
- **Command**: `swift run mediahub import <source-id> --all --yes --library <path> 2>&1 | grep -q "Import.*items" && echo "FAIL: Confirmation appeared" || echo "PASS: Confirmation skipped"`
- **Expected**: `PASS: Confirmation skipped`
- **Status**: ⬜ TODO

### Smoke Test 6: Dry-Run Skips Confirmation
- **Test**: Verify dry-run does not prompt for confirmation
- **Command**: `swift run mediahub import <source-id> --all --dry-run --library <path> 2>&1 | grep -q "Import.*items" && echo "FAIL: Confirmation appeared" || echo "PASS: Confirmation skipped for dry-run"`
- **Expected**: `PASS: Confirmation skipped for dry-run`
- **Status**: ⬜ TODO

### Smoke Test 7: Non-Interactive Mode Requires --yes
- **Test**: Verify non-interactive mode fails without `--yes` flag
- **Command**: `swift run mediahub import <source-id> --all --library <path> < /dev/null 2>&1 | grep -q "non-interactive\|--yes" && echo "PASS: Non-interactive error shown" || echo "FAIL: No error for non-interactive mode"`
- **Expected**: `PASS: Non-interactive error shown`
- **Status**: ⬜ TODO

### Smoke Test 8: Read-Only Guarantee Documentation
- **Test**: Verify detection help text mentions read-only guarantee for source and media files
- **Command**: `swift run mediahub detect --help | grep -qi "read-only\|does not modify.*source\|does not copy.*media" && echo "PASS: Read-only guarantee documented" || echo "FAIL: Read-only guarantee not documented"`
- **Expected**: `PASS: Read-only guarantee documented`
- **Status**: ⬜ TODO

### Smoke Test 9: JSON Output with dryRun Field
- **Test**: Verify JSON output includes `dryRun: true` when `--dry-run` is used
- **Command**: `swift run mediahub import <source-id> --all --dry-run --json --library <path> | jq -e '.dryRun == true' && echo "PASS: dryRun field present" || echo "FAIL: dryRun field missing"`
- **Expected**: `PASS: dryRun field present`
- **Status**: ⬜ TODO

### Smoke Test 10: Interruption Handling
- **Test**: Verify interruption (Ctrl+C) during import reports progress
- **Command**: Manual test - start import, press Ctrl+C, verify progress is reported
- **Expected**: Interruption reports what was imported before cancellation
- **Status**: ⬜ TODO

---

## Functional Requirements Validation

### FR-001: --dry-run Flag Support
- **Test**: Verify `--dry-run` flag is available on import command
- **Status**: ⬜ TODO
- **Result**: ⬜ PASS / ⬜ FAIL

### FR-002: Detailed Preview Information
- **Test**: Verify dry-run shows source paths, destination paths, collision handling
- **Status**: ⬜ TODO
- **Result**: ⬜ PASS / ⬜ FAIL

### FR-003: Zero File System Modifications in Dry-Run
- **Test**: Verify dry-run performs zero file operations on source files or library media files (tested in Smoke Test 2)
- **Status**: ⬜ TODO
- **Result**: ⬜ PASS / ⬜ FAIL

### FR-004: --yes Flag Support
- **Test**: Verify `--yes` flag bypasses confirmation (tested in Smoke Test 5)
- **Status**: ⬜ TODO
- **Result**: ⬜ PASS / ⬜ FAIL

### FR-005: Confirmation Prompts
- **Test**: Verify confirmation prompt appears before import (tested in Smoke Test 4)
- **Status**: ⬜ TODO
- **Result**: ⬜ PASS / ⬜ FAIL

### FR-006: Clear Confirmation Prompt
- **Test**: Verify confirmation prompt shows import summary (item count, source, destination)
- **Status**: ⬜ TODO
- **Result**: ⬜ PASS / ⬜ FAIL

### FR-007: User Cancellation Handling
- **Test**: Verify user cancellation exits with code 0
- **Status**: ⬜ TODO
- **Result**: ⬜ PASS / ⬜ FAIL

### FR-008: Non-Interactive Mode Detection
- **Test**: Verify non-interactive mode requires `--yes` flag (tested in Smoke Test 7)
- **Status**: ⬜ TODO
- **Result**: ⬜ PASS / ⬜ FAIL

### FR-009: Read-Only Documentation
- **Test**: Verify detection is documented as read-only (tested in Smoke Test 8)
- **Status**: ⬜ TODO
- **Result**: ⬜ PASS / ⬜ FAIL

### FR-010: Read-Only Guarantee Enforcement
- **Test**: Verify detection operations never modify source files or copy media files (already enforced by core; detection may write result files in `.mediahub/` directory)
- **Status**: ⬜ TODO
- **Result**: ⬜ PASS / ⬜ FAIL

### FR-011: Clear Error Messages
- **Test**: Verify error messages are clear and actionable
- **Status**: ⬜ TODO
- **Result**: ⬜ PASS / ⬜ FAIL

### FR-012: Interruption Handling
- **Test**: Verify interruption handling reports progress (tested in Smoke Test 10)
- **Status**: ⬜ TODO
- **Result**: ⬜ PASS / ⬜ FAIL

### FR-013: Library Integrity Preservation
- **Test**: Verify import errors don't leave library in inconsistent state
- **Status**: ⬜ TODO
- **Result**: ⬜ PASS / ⬜ FAIL

### FR-014: JSON Output with dryRun Field
- **Test**: Verify JSON output includes `dryRun: true` (tested in Smoke Test 9)
- **Status**: ⬜ TODO
- **Result**: ⬜ PASS / ⬜ FAIL

### FR-015: Dry-Run Preview Accuracy
- **Test**: Verify dry-run preview matches actual import (tested in Smoke Test 3)
- **Status**: ⬜ TODO
- **Result**: ⬜ PASS / ⬜ FAIL

### FR-016: Dry-Run Consistency
- **Test**: Verify dry-run and actual import produce consistent results
- **Status**: ⬜ TODO
- **Result**: ⬜ PASS / ⬜ FAIL

---

## Success Criteria Validation

### SC-001: Dry-Run Preview Accuracy
- **Target**: 100% accuracy (dry-run preview matches actual import results)
- **Test**: Compare dry-run preview with actual import results
- **Status**: ⬜ TODO
- **Result**: ⬜ PASS / ⬜ FAIL

### SC-002: Zero File Operations in Dry-Run
- **Target**: Zero file operations on source files or library media files verified by tests
- **Test**: Run dry-run and verify no source files or library media files are created/modified/deleted
- **Status**: ⬜ TODO
- **Result**: ⬜ PASS / ⬜ FAIL

### SC-003: Confirmation Prompts
- **Target**: Confirmation prompts appear when appropriate
- **Test**: Verify confirmation appears when `--yes` is not provided and not in dry-run
- **Status**: ⬜ TODO
- **Result**: ⬜ PASS / ⬜ FAIL

### SC-004: --yes Flag for Scripting
- **Target**: `--yes` flag works correctly in non-interactive mode
- **Test**: Verify `--yes` flag bypasses confirmation
- **Status**: ⬜ TODO
- **Result**: ⬜ PASS / ⬜ FAIL

### SC-005: Non-Interactive Mode Error
- **Target**: Clear error message when non-interactive mode requires `--yes`
- **Test**: Verify error message instructs user to use `--yes`
- **Status**: ⬜ TODO
- **Result**: ⬜ PASS / ⬜ FAIL

### SC-006: Read-Only Documentation
- **Target**: Detection explicitly documented as read-only for source and media files
- **Test**: Verify CLI help and documentation state read-only guarantee (clarifies that detection never modifies source files or copies media, though it may write result files in `.mediahub/` directory)
- **Status**: ⬜ TODO
- **Result**: ⬜ PASS / ⬜ FAIL

### SC-007: Library Integrity Preservation
- **Target**: No partial files after import errors
- **Test**: Simulate import errors and verify no partial files are left
- **Status**: ⬜ TODO
- **Result**: ⬜ PASS / ⬜ FAIL

### SC-008: Interruption Handling
- **Target**: Interruption reports what was imported before cancellation
- **Test**: Interrupt import and verify progress is reported
- **Status**: ⬜ TODO
- **Result**: ⬜ PASS / ⬜ FAIL

### SC-009: Dry-Run Accuracy
- **Target**: Dry-run preview matches actual import behavior
- **Test**: Compare dry-run preview with actual import results
- **Status**: ⬜ TODO
- **Result**: ⬜ PASS / ⬜ FAIL

### SC-010: JSON Output with dryRun Field
- **Target**: JSON output includes `dryRun: true` when `--dry-run` is used
- **Test**: Verify JSON output contains `dryRun: true` field
- **Status**: ⬜ TODO
- **Result**: ⬜ PASS / ⬜ FAIL

### SC-011: No Regression in Core Functionality
- **Target**: All existing tests still pass
- **Test**: Run `swift test` and verify all tests pass
- **Status**: ⬜ TODO
- **Result**: ⬜ PASS / ⬜ FAIL

### SC-012: Compatibility with Existing CLI Features
- **Target**: Safety features work with all existing CLI commands and options
- **Test**: Verify safety features work with `--json`, `--library`, etc.
- **Status**: ⬜ TODO
- **Result**: ⬜ PASS / ⬜ FAIL

---

## Test Execution Summary

### Unit Tests
- **Command**: `swift test --filter MediaHubTests`
- **Status**: ⬜ TODO
- **Result**: ⬜ PASS / ⬜ FAIL
- **Notes**: 

### Integration Tests
- **Command**: `swift test --filter MediaHubCLITests` (if created)
- **Status**: ⬜ TODO
- **Result**: ⬜ PASS / ⬜ FAIL
- **Notes**: 

### CLI Smoke Tests
- **Command**: `scripts/smoke_cli.sh`
- **Status**: ⬜ TODO
- **Result**: ⬜ PASS / ⬜ FAIL
- **Notes**: 

### Manual Testing
- **Dry-Run Accuracy**: ⬜ TODO
- **Confirmation Prompts**: ⬜ TODO
- **Interruption Handling**: ⬜ TODO
- **Error Handling**: ⬜ TODO

---

## Validation Checklist

- [ ] All structure validations pass
- [ ] All smoke tests pass
- [ ] All functional requirements validated
- [ ] All success criteria met
- [ ] All existing tests pass (no regressions)
- [ ] CLI smoke tests pass
- [ ] Manual testing completed
- [ ] Documentation updated (if needed)
- [ ] Ready for next slice

---

## Notes

_Add any notes, observations, or issues encountered during validation here._
