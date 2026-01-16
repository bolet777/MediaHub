---
description: Start a new slice with full Spec-Kit workflow automation (spec → plan → tasks → validation, all with automatic reviews and fixes)
---

## User Input

```text
$ARGUMENTS
```

Parse the user input to extract:
1. **Slice identifier or feature description**: Either "Slice N" / "slice N" format OR a feature description (required)
2. **Max auto-fixes parameter**: Optional `--max-fixes=N` or `--max-fixes N` (default: 2)

**Input Parsing Logic**:

1. **If input matches "Slice N" or "slice N" pattern** (e.g., "Slice 12", "slice 13"):
   - Extract slice number N
   - Read `specs/STATUS.md` and find the slice in the "Planned Slices" table
   - Extract the "Goal" column as the feature description
   - If slice not found in STATUS.md: ERROR "Slice N not found in STATUS.md Planned Slices table"
   - Use the Goal text as the feature description for subsequent workflows

2. **If input is a feature description** (doesn't match "Slice N" pattern):
   - Use the input text directly as the feature description

3. **Extract max-fixes parameter**:
   - Look for `--max-fixes=N` or `--max-fixes N` in the input
   - Default to 2 if not specified
   - Validate: minimum 1, maximum 5

**Examples**:
- `/speckit.start Slice 12` → Reads STATUS.md, extracts Goal for Slice 12, max-fixes = 2 (default)
- `/speckit.start slice 13 --max-fixes=3` → Reads STATUS.md, extracts Goal for Slice 13, max-fixes = 3
- `/speckit.start Create UI wizard for library management` → Uses description directly, max-fixes = 2
- `/speckit.start --max-fixes=3 Create UI wizard` → Uses description directly, max-fixes = 3

**Configuration**:
- **MAX_AUTO_FIXES**: Parse from `--max-fixes` parameter, default to 2 if not specified
- **MIN_AUTO_FIXES**: Always at least 1 (safety minimum)
- **MAX_AUTO_FIXES_LIMIT**: Cap at 5 maximum (prevent infinite loops)
- **STATUS_FILE**: `specs/STATUS.md` (absolute path from repo root)

## Workflow Overview

This command orchestrates the complete Spec-Kit workflow with automatic reviews and corrections:

1. **Parse input and extract feature description** (from STATUS.md if "Slice N" format, or use input directly)
2. **Generate spec.md** → Review → Auto-fix if KO → Repeat until OK
3. **Generate plan.md** → Review → Auto-fix if KO → Repeat until OK
4. **Generate tasks.md** → Review → Auto-fix if KO → Repeat until OK
5. **Generate validation.md** → Review → Auto-fix if KO → Repeat until OK
6. **Final Report** with all documents and their status

## Execution Flow

### Phase 0: Parse Input and Extract Feature Description

1. **Parse user input**:
   - Check if input matches pattern: `(?i)^\s*slice\s+(\d+)\s*$` or contains `slice\s+\d+`
   - If match: Extract slice number N
   - If no match: Treat entire input (minus `--max-fixes` flags) as feature description

2. **If "Slice N" format**:
   - Read `specs/STATUS.md` (absolute path from repo root)
   - Find the "Planned Slices" table section
   - Locate row where first column (Slice) equals N
   - Extract the "Goal" column value as the feature description
   - If slice not found: **ERROR** "Slice N not found in STATUS.md Planned Slices table. Available slices: [list]"
   - Store feature description for use in subsequent phases

3. **If direct feature description**:
   - Remove `--max-fixes=N` flags from input
   - Use remaining text as feature description

4. **Extract MAX_AUTO_FIXES**:
   - Parse `--max-fixes=N` or `--max-fixes N` from input
   - Default: 2
   - Validate: minimum 1, maximum 5
   - Store as MAX_AUTO_FIXES variable

5. **Output parsed values**:
   ```
   Feature Description: [extracted description]
   Max Auto-Fixes: [MAX_AUTO_FIXES]
   Slice Number: [N] (if applicable)
   ```

### Phase 1: Generate spec.md

1. **Execute `/speckit.specify` workflow**:
   - Follow the complete `/speckit.specify` command workflow
   - Generate spec.md in the appropriate slice directory
   - Complete all steps including quality validation

2. **Automatic Review**:
   - Apply review rules from `.cursor/rules/review.mdc`
   - Run systematic review of spec.md against phase-specific criteria
   - If **OK**: Proceed to Phase 2
   - If **KO**: Attempt automatic fixes (see Automatic Fixes section below)

3. **Auto-Fix Attempts** (if KO):
   - Maximum MAX_AUTO_FIXES auto-fix attempts per document (default: 2, configurable via --max-fixes)
   - Apply fixes from "Automatic Fixes" section in review.mdc
   - Re-run review after each fix attempt
   - If still KO after MAX_AUTO_FIXES attempts: **STOP** and report blocking issues
   - If OK after fix: Proceed to Phase 2

4. **Output Status**:
   ```
   Phase: spec.md
   Status: [OK/KO]
   Auto-fixes applied: [count]
   Blocking issues (if KO): [list]
   ```

### Phase 2: Generate plan.md

1. **Execute `/speckit.plan` workflow**:
   - Follow the complete `/speckit.plan` command workflow
   - Generate plan.md in the slice directory
   - Complete all planning phases

2. **Automatic Review**:
   - Apply review rules from `.cursor/rules/review.mdc`
   - Run systematic review of plan.md against phase-specific criteria
   - If **OK**: Proceed to Phase 3
   - If **KO**: Attempt automatic fixes

3. **Auto-Fix Attempts** (if KO):
   - Maximum MAX_AUTO_FIXES auto-fix attempts (default: 2, configurable via --max-fixes)
   - Apply fixes from "Automatic Fixes" section
   - Re-run review after each fix attempt
   - If still KO after MAX_AUTO_FIXES attempts: **STOP** and report blocking issues
   - If OK after fix: Proceed to Phase 3

4. **Output Status**:
   ```
   Phase: plan.md
   Status: [OK/KO]
   Auto-fixes applied: [count]
   Blocking issues (if KO): [list]
   ```

### Phase 3: Generate tasks.md and validation.md

1. **Execute `/speckit.tasks` workflow**:
   - Follow the complete `/speckit.tasks` command workflow
   - Generate tasks.md in the slice directory
   - Complete task generation including dependency graph

2. **Automatic Review of tasks.md**:
   - Apply review rules from `.cursor/rules/review.mdc`
   - Perform mandatory Pre-Review Scan (count tasks, scan for anti-patterns, sample verification, Phase 9 check)
   - Run systematic review of tasks.md against phase-specific criteria
   - If **OK**: Proceed to validation.md generation
   - If **KO**: Attempt automatic fixes

3. **Auto-Fix Attempts for tasks.md** (if KO):
   - Maximum MAX_AUTO_FIXES auto-fix attempts (default: 2, configurable via --max-fixes)
   - Apply fixes from "Automatic Fixes" section (especially Pattern 1-4 fixes)
   - Re-run review after each fix attempt
   - If still KO after MAX_AUTO_FIXES attempts: **STOP** and report blocking issues
   - If OK after fix: Proceed to validation.md generation

4. **Generate validation.md**:
   - Follow the validation.md generation steps from `/speckit.tasks` command
   - Generate validation.md in the slice directory
   - Complete all validation sections

5. **Automatic Review of validation.md**:
   - Apply review rules from `.cursor/rules/review.mdc`
   - Run systematic review of validation.md against phase-specific criteria
   - If **OK**: Proceed to Final Report
   - If **KO**: Attempt automatic fixes

6. **Auto-Fix Attempts for validation.md** (if KO):
   - Maximum MAX_AUTO_FIXES auto-fix attempts (default: 2, configurable via --max-fixes)
   - Apply fixes from "Automatic Fixes" section
   - Re-run review after each fix attempt
   - If still KO after MAX_AUTO_FIXES attempts: **STOP** and report blocking issues
   - If OK after fix: Proceed to Final Report

7. **Output Status**:
   ```
   Phase: tasks.md
   Status: [OK/KO]
   Auto-fixes applied: [count]
   Blocking issues (if KO): [list]
   
   Phase: validation.md
   Status: [OK/KO]
   Auto-fixes applied: [count]
   Blocking issues (if KO): [list]
   ```

### Phase 4: Final Report

Generate a comprehensive summary report:

```markdown
# Slice [N] - [Name] - Spec-Kit Workflow Complete

**Feature Description**: [extracted feature description from Phase 0]
**Slice Number**: [N if "Slice N" format was used, otherwise "N/A"]
**Slice Directory**: [path]
**Generated**: [timestamp]
**Max Auto-Fixes Used**: [MAX_AUTO_FIXES value, e.g., "2 (default)" or "3 (via --max-fixes)"]

## Documents Generated

| Document | Status | Auto-Fixes | Notes |
|----------|--------|------------|-------|
| spec.md | ✅ OK / ❌ KO | [count] | [blocking issues if KO] |
| plan.md | ✅ OK / ❌ KO | [count] | [blocking issues if KO] |
| tasks.md | ✅ OK / ❌ KO | [count] | [blocking issues if KO] |
| validation.md | ✅ OK / ❌ KO | [count] | [blocking issues if KO] |

## Summary

- **Max Auto-Fixes Configuration**: [MAX_AUTO_FIXES value used, e.g., "2 (default)" or "3 (via --max-fixes)"]
- **Total Auto-Fixes Applied**: [sum across all documents]
- **All Documents Ready**: [Yes/No]
- **Blocking Issues**: [list if any]

## Next Steps

- **If all OK**: 
  ```
  All documents are ready for implementation.
  NEXT STEP: `/speckit.implement` (start with T-001)
  ```

- **If any KO**: 
  ```
  Fix blocking issues in [document(s)], then:
  - Re-run `/speckit.start` to regenerate from scratch, OR
  - Continue manually with `/speckit.specify`, `/speckit.plan`, `/speckit.tasks`
  ```
```

## Automatic Fixes

When a review returns KO, attempt these automatic fixes (see `.cursor/rules/review.mdc` "Automatic Fixes" section for details):

### For spec.md:
- Add missing non-goals if scope is too broad
- Clarify UI/Core/CLI boundaries if blurred
- Add explicit safety rules if missing
- Fix API signatures to match existing Core APIs
- Add missing confirmation handler integration requirements

### For plan.md:
- Split phases that combine preview + execution
- Add explicit async handling if missing
- Clarify sequencing if unsafe
- Separate read-only steps from mutating steps

### For tasks.md:
- **Pattern 1**: Split tasks that violate multi-responsibility (skeleton → Core call → error mapping)
- **Pattern 2**: Mark "Verify" tasks as manual verification (or require test file)
- **Pattern 3**: Downgrade "Polish" tasks to P2
- **Pattern 4**: Split oversized tasks (>8 steps, multiple responsibilities)

### For validation.md:
- Add missing success criteria coverage
- Make vague checks more concrete (add specific commands/steps)
- Add error path validation if missing
- Add determinism verification if missing

**Auto-fix limits**: Maximum MAX_AUTO_FIXES auto-fix attempts per document (default: 2, configurable via --max-fixes parameter). If still KO after MAX_AUTO_FIXES attempts, stop and report blocking issues.

**Configuration**:
- Default: 2 attempts per document
- Minimum: 1 attempt (safety minimum)
- Maximum: 5 attempts (prevents infinite loops)
- Override: Use `--max-fixes=N` in command (e.g., `/speckit.start --max-fixes=3 Create UI wizard`)

## Error Handling

- **If any phase fails after MAX_AUTO_FIXES auto-fix attempts**: Stop workflow immediately, report all blocking issues, provide clear next steps
- **Configuration used**: Report the MAX_AUTO_FIXES value used in the final report
- **If user interrupts**: Save current state, report what was completed, allow resumption
- **If file conflicts**: Report conflict, ask user to resolve, then continue

## Important Notes

- This command is **idempotent**: Re-running it will regenerate documents (with user confirmation if files exist)
- All reviews use the strict rules from `.cursor/rules/review.mdc`
- All fixes must preserve document structure and numbering
- Auto-fixes are **conservative**: Only fix clearly detectable patterns, not semantic issues
- Complex issues requiring human judgment will stop the workflow for manual intervention
- **Max auto-fixes is configurable**: Use `--max-fixes=N` to increase attempts (default: 2, max: 5, min: 1)
