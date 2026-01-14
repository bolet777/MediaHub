# Validation Checklist: Baseline Index (Slice 7)

**Feature**: Baseline Index  
**Specification**: `specs/007-baseline-index/spec.md`  
**Plan**: `specs/007-baseline-index/plan.md`  
**Tasks**: `specs/007-baseline-index/tasks.md`  
**Created**: 2026-01-14

## Overview

This validation checklist provides end-to-end (E2E) validation steps for the Baseline Index feature. All validations are deterministic and can be automated. The primary validation method is `swift test`, with manual CLI commands for E2E verification.

**Note**: All CLI commands use `swift run MediaHubCLI` for portability. If a local `mediahub` binary exists, it can be used instead, but the checklist must work without it.

## Primary Validation: Unit Tests

**Command**: `swift test`

**Expected Result**: All tests pass (including new Baseline Index tests)

**Coverage**:
- Core index functionality (reader, writer, validator)
- Path normalization
- Index creation during adoption
- Index usage in detection (read-only)
- Incremental index updates during import
- Dry-run behavior (zero writes)
- Fallback behavior (missing/invalid index)

---

## E2E Validation Checklist

### 1. Library Adoption: Index Creation and Preservation

#### 1.1 Index Creation (Absent Index)

**Setup**:
```bash
# Create test library directory with media files
mkdir -p /tmp/test-library/{2024/01,2024/02}
touch /tmp/test-library/2024/01/photo1.jpg
touch /tmp/test-library/2024/02/photo2.jpg
```

**Command**:
```bash
swift run MediaHubCLI library adopt /tmp/test-library
```

**Verification**:
- [ ] `.mediahub/registry/index.json` exists
- [ ] Index file is valid JSON (parseable)
- [ ] Index contains `version: "1.0"`
- [ ] Index `entryCount` matches number of media files (2)
- [ ] Index `entries` array contains normalized paths for both files
- [ ] No files created outside `.mediahub/**` (no-touch rule)

**JSON Output Check** (if `--json` supported):
- [ ] Result includes `indexCreated: true`
- [ ] Result includes `indexSkippedReason: null`
- [ ] Result includes `indexMetadata.version: "1.0"`
- [ ] Result includes `indexMetadata.entryCount: 2`

#### 1.2 Index Preservation (Valid Existing Index)

**Setup**:
```bash
# Library already adopted with index from 1.1
# Note: Get original index lastUpdated timestamp
```

**Command**:
```bash
swift run MediaHubCLI library adopt /tmp/test-library
```

**Verification**:
- [ ] Index file exists and is unchanged (same `lastUpdated` timestamp)
- [ ] Index `entryCount` unchanged
- [ ] No files created outside `.mediahub/**` (no-touch rule)

**JSON Output Check** (if `--json` supported):
- [ ] Result includes `indexCreated: false`
- [ ] Result includes `indexSkippedReason: "already_valid"`
- [ ] Result includes `indexMetadata` with existing index stats

#### 1.3 Dry-Run: Zero Writes

**Command**:
```bash
swift run MediaHubCLI library adopt /tmp/test-library --dry-run
```

**Verification**:
- [ ] No `.mediahub/registry/index.json` created (or unchanged if exists)
- [ ] No files created outside `.mediahub/**` (no-touch rule)

**JSON Output Check** (if `--json` supported):
- [ ] Result includes `indexCreated: false`
- [ ] Result includes `indexSkippedReason: "dry_run"`

---

### 2. Detection: Index Usage and Fallback (Read-Only)

#### 2.1 Index Usage (Valid Index)

**Setup**:
```bash
# Library with valid index from 1.1
# Attach source and run detection
```

**Command**:
```bash
swift run MediaHubCLI detect <source-id> --library /tmp/test-library --json
```

**Verification**:
- [ ] Detection completes successfully
- [ ] `.mediahub/registry/index.json` is NOT modified (read-only guarantee)
- [ ] Index `lastUpdated` timestamp unchanged
- [ ] No files created outside `.mediahub/**` (no-touch rule)

**JSON Output Check**:
- [ ] Result includes `indexUsed: true`
- [ ] Result includes `indexFallbackReason: null`
- [ ] Result includes `indexMetadata.version: "1.0"`
- [ ] Result includes `indexMetadata.entryCount: 2`
- [ ] Result includes `indexMetadata.lastUpdated` (ISO8601 timestamp)

#### 2.2 Fallback (Absent Index)

**Setup**:
```bash
# Remove index file
rm /tmp/test-library/.mediahub/registry/index.json
```

**Command**:
```bash
swift run MediaHubCLI detect <source-id> --library /tmp/test-library --json
```

**Verification**:
- [ ] Detection completes successfully (fallback to full scan)
- [ ] `.mediahub/registry/index.json` is NOT created (read-only guarantee)
- [ ] No files created outside `.mediahub/**` (no-touch rule)

**JSON Output Check**:
- [ ] Result includes `indexUsed: false`
- [ ] Result includes `indexFallbackReason` (non-null, indicates cause: e.g., "missing", "invalid", "unsupported_version", "decoding_failed", etc.)
- [ ] Result includes `indexMetadata: null`

#### 2.3 Fallback (Invalid Index)

**Setup**:
```bash
# Corrupt index file
echo '{"invalid": "json"' > /tmp/test-library/.mediahub/registry/index.json
```

**Command**:
```bash
swift run MediaHubCLI detect <source-id> --library /tmp/test-library --json
```

**Verification**:
- [ ] Detection completes successfully (fallback to full scan)
- [ ] `.mediahub/registry/index.json` is NOT modified (read-only guarantee)
- [ ] No files created outside `.mediahub/**` (no-touch rule)

**JSON Output Check**:
- [ ] Result includes `indexUsed: false`
- [ ] Result includes `indexFallbackReason` (non-null, indicates cause: e.g., "corrupted", "invalid", "unsupported_version", "decoding_failed", etc.)
- [ ] Result includes `indexMetadata: null`

---

### 3. Import: Incremental Index Updates

#### 3.1 Index Update (Valid Index at Start)

**Setup**:
```bash
# Library with valid index from 1.1
# Source with new files to import
```

**Command**:
```bash
swift run MediaHubCLI import <source-id> --all --library /tmp/test-library --json
```

**Verification**:
- [ ] Import completes successfully
- [ ] `.mediahub/registry/index.json` is updated (new `lastUpdated` timestamp)
- [ ] Index `entryCount` increased by number of successfully imported files
- [ ] Index `entries` array contains normalized paths for imported files
- [ ] No files created outside `.mediahub/**` (no-touch rule)

**JSON Output Check**:
- [ ] Result includes `indexUpdateAttempted: true`
- [ ] Result includes `indexUpdated: true`
- [ ] Result includes `indexUpdateSkippedReason: null`
- [ ] Result includes `indexMetadata.version: "1.0"`
- [ ] Result includes `indexMetadata.entryCount` (increased)
- [ ] Result includes `indexMetadata.lastUpdated` (new timestamp)

#### 3.2 No Index Update (Absent Index at Start)

**Setup**:
```bash
# Remove index file
rm /tmp/test-library/.mediahub/registry/index.json
```

**Command**:
```bash
swift run MediaHubCLI import <source-id> --all --library /tmp/test-library --json
```

**Verification**:
- [ ] Import completes successfully
- [ ] `.mediahub/registry/index.json` is NOT created (only updates if valid at start)
- [ ] No files created outside `.mediahub/**` (no-touch rule)

**JSON Output Check**:
- [ ] Result includes `indexUpdateAttempted: false`
- [ ] Result includes `indexUpdated: false`
- [ ] Result includes `indexUpdateSkippedReason` (non-null, indicates cause: e.g., "index_missing", "index_invalid", etc.)
- [ ] Result includes `indexMetadata: null`

#### 3.3 Dry-Run: Zero Writes

**Setup**:
```bash
# Library with valid index from 1.1
# Note: Get original index lastUpdated timestamp
```

**Command**:
```bash
swift run MediaHubCLI import <source-id> --all --library /tmp/test-library --dry-run --json
```

**Verification**:
- [ ] Import preview completes successfully
- [ ] `.mediahub/registry/index.json` is NOT modified (dry-run = zero writes)
- [ ] Index `lastUpdated` timestamp unchanged
- [ ] No files created outside `.mediahub/**` (no-touch rule)

**JSON Output Check**:
- [ ] Result includes `indexUpdateAttempted: true`
- [ ] Result includes `indexUpdated: false`
- [ ] Result includes `indexUpdateSkippedReason: "dry_run"`
- [ ] Result includes `indexMetadata` (from existing index, not updated)

---

### 4. No-Touch Rules Verification

**Objective**: Ensure no files are created outside `.mediahub/**` directory

**Verification Steps**:
1. Before each command, record all files in library root (excluding `.mediahub/`)
2. After each command, verify no new files created outside `.mediahub/**`
3. Verify no modifications to media files (read-only operations)

**Commands to Verify**:
- [ ] `library adopt` (index creation)
- [ ] `detect` (read-only, no writes)
- [ ] `import` (index update only in `.mediahub/**`)

**Expected Result**: Zero files created/modified outside `.mediahub/**`

---

### 5. JSON Output Schema Validation

**Objective**: Verify JSON output includes index fields without breaking existing schema

#### 5.1 Detection Result JSON

**Required Fields**:
- [ ] `indexUsed: bool` (present)
- [ ] `indexFallbackReason: string | null` (present)
- [ ] `indexMetadata: object | null` (present, includes `version`, `entryCount`, `lastUpdated` when used)

**Backward Compatibility**:
- [ ] All existing fields still present (no breaking changes)
- [ ] JSON schema is valid (parseable by existing tools)

#### 5.2 Import Result JSON

**Required Fields**:
- [ ] `indexUpdateAttempted: bool` (present)
- [ ] `indexUpdated: bool` (present)
- [ ] `indexUpdateSkippedReason: string | null` (present)
- [ ] `indexMetadata: object | null` (present, includes `version`, `entryCount`, `lastUpdated` when available)

**Backward Compatibility**:
- [ ] All existing fields still present (no breaking changes)
- [ ] JSON schema is valid (parseable by existing tools)

#### 5.3 Adoption Result JSON (if supported)

**Required Fields**:
- [ ] `indexCreated: bool` (present)
- [ ] `indexSkippedReason: string | null` (present)
- [ ] `indexMetadata: object | null` (present, includes `version`, `entryCount` when available)

**Backward Compatibility**:
- [ ] All existing fields still present (no breaking changes)
- [ ] JSON schema is valid (parseable by existing tools)

---

### 6. Deterministic Behavior Validation

**Objective**: Verify index format is deterministic (same library state produces identical JSON structure)

**Test 6.1: Idempotent Adoption (Valid Index Preserved)**:
1. Create library with known set of files
2. Run `swift run MediaHubCLI library adopt /tmp/test-library` (creates index)
3. Record index `created` and `lastUpdated` timestamps
4. Run `swift run MediaHubCLI library adopt /tmp/test-library` again (idempotent)
5. Compare `index.json` files

**Verification**:
- [ ] Index file is unchanged (same `created` and `lastUpdated` timestamps)
- [ ] Index `entryCount` unchanged
- [ ] Index `entries` array unchanged (same paths, same order)

**Test 6.2: Index Recreation (After Deletion)**:
1. Remove index file: `rm /tmp/test-library/.mediahub/registry/index.json`
2. Run `swift run MediaHubCLI library adopt /tmp/test-library` again
3. Compare new index with original

**Verification**:
- [ ] New index is created (new `created` and `lastUpdated` timestamps)
- [ ] Index `entries` array is sorted by normalized path (deterministic order)
- [ ] JSON encoding is stable (same structure, entries in same order)
- [ ] Only `created` and `lastUpdated` timestamps differ from original

---

### 7. Error Handling Validation

**Objective**: Verify graceful degradation when index operations fail

#### 7.1 Index Creation Failure During Adoption

**Test**: Simulate index write failure (e.g., read-only filesystem)

**Verification**:
- [ ] Adoption completes successfully (index is optional)
- [ ] Error is logged/reported (non-fatal)
- [ ] Library metadata is created (adoption succeeds)

#### 7.2 Index Update Failure During Import

**Test**: Simulate index update failure (e.g., disk full)

**Verification**:
- [ ] Import completes successfully (index update is optional)
- [ ] Error is logged/reported (non-fatal)
- [ ] Files are imported (import succeeds)

---

## Validation Summary

### Automated Validation

- **Primary**: `swift test` (all tests pass)
- **Coverage**: Unit tests, integration tests, E2E tests

### Manual Validation

- **E2E Commands**: Run commands above and verify outputs
- **JSON Schema**: Validate JSON output structure
- **No-Touch Rules**: Verify no files outside `.mediahub/**`

### Success Criteria

- [ ] All unit tests pass (`swift test`)
- [ ] All E2E validations pass (checklist above)
- [ ] No files created outside `.mediahub/**` (no-touch rules)
- [ ] JSON output includes index fields (backward compatible)
- [ ] Index operations are deterministic (same state = same JSON)
- [ ] Error handling is graceful (operations succeed even if index fails)

---

## Notes

- **Performance Tests**: Not included (non-blocking, out of scope for P1)
- **CLI Commands**: Minimal commands (1-2 at a time) for validation
- **Determinism**: All validations are deterministic (no flaky tests)
- **No New Requirements**: This validation checklist does not introduce new requirements beyond the spec
