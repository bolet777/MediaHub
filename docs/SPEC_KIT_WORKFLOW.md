# Spec-Kit Workflow Documentation

**Purpose**: Complete guide to Spec-Kit commands, rules, and workflows for MediaHub development  
**Last Updated**: 2026-01-27  
**Audience**: Developers and AI agents working on MediaHub slices

---

## Table of Contents

1. [Overview](#overview)
2. [Spec-Kit Commands](#spec-kit-commands)
3. [Review Rules](#review-rules)
4. [Implementation Workflows](#implementation-workflows)
5. [Best Practices](#best-practices)
6. [Troubleshooting](#troubleshooting)

---

## Overview

Spec-Kit is MediaHub's **strict development methodology** that ensures quality, safety, and maintainability through:

- **Phase-based development**: spec → plan → tasks → validation → implementation
- **Automatic reviews**: Each phase is reviewed before proceeding
- **SAFE PASS discipline**: Small, reversible, auditable implementation steps
- **Staging-only workflow**: No automatic commits, human reviews and commits manually

### Core Principles

1. **No code before design**: spec, plan, tasks, and validation must be approved
2. **Explicit OK/KO decisions**: Each phase must pass review before proceeding
3. **Minimal, additive changes**: Prefer small increments over large refactors
4. **Determinism and idempotence**: Same input → same output, safe to re-run
5. **Human control**: Final commits are human responsibility

---

## Spec-Kit Commands

### `/speckit.start` - Automated Full Workflow

**Purpose**: Generate all Spec-Kit documents (spec, plan, tasks, validation) with automatic reviews and fixes.

**Usage**:
```bash
/speckit.start Slice 12
/speckit.start --max-fixes=3 Create UI wizard
```

**Features**:
- Automatically generates: `spec.md` → `plan.md` → `tasks.md` → `validation.md`
- Automatic review after each document generation
- Automatic fixes for common issues (up to N attempts, configurable)
- Supports "Slice N" format (reads `STATUS.md` to extract slice description)
- Configurable max auto-fixes: `--max-fixes=N` (default: 2, max: 5, min: 1)

**Workflow**:
1. Parse input (slice identifier or feature description)
2. Generate `spec.md` → review → auto-fix if KO → repeat until OK
3. Generate `plan.md` → review → auto-fix if KO → repeat until OK
4. Generate `tasks.md` → review → auto-fix if KO → repeat until OK
5. Generate `validation.md` → review → auto-fix if KO → repeat until OK
6. Final report with all documents and their status

**Output**: All Spec-Kit documents ready for implementation, or blocking issues if any phase fails after max auto-fixes.

---

### `/speckit.implementSlice` - Single Task Implementation

**Purpose**: Implement ONE task from `tasks.md` following SAFE PASS discipline (staging only, no commit).

**Usage**:
```bash
/speckit.implementSlice T-001
/speckit.implementSlice T-014b
```

**Features**:
- One task per command (no chaining)
- Extracts task details from `tasks.md` (source of truth)
- Pre-checks dependencies and scope
- Implements following task "Steps"
- Review using `impl_review.mdc` (OK/KO decision)
- Stages changes with `git add` (NO commit)
- Generates structured staging summary

**Workflow**:
1. Parse task ID and locate `tasks.md`
2. Extract task details (title, priority, summary, files, steps, done when, dependencies)
3. Pre-check: dependencies, scope boundaries, file access
4. Implement: Execute steps from task definition
5. Review: Apply `impl_review.mdc` rules (OK/KO)
6. Stage: `git add` modified files, generate summary

**Output**: Staging summary with:
- Intent (what this task accomplishes)
- Files changed (created/modified)
- What was done
- What was intentionally NOT done
- Done When criteria checklist
- Review decision (OK/KO)
- Next steps

**Important**: This command does NOT create git commits. Human reviews staged changes and commits manually.

---

### `/speckit.runSlice` - End-to-End Slice Implementation

**Purpose**: Implement entire slice by running all tasks sequentially with user prompts between tasks.

**Usage**:
```bash
/speckit.runSlice Slice 12
/speckit.runSlice specs/012-ui-create-adopt-wizard-v1
/speckit.runSlice --skip-completed
```

**Features**:
- Builds ordered task list from `tasks.md` (respects phases + dependencies)
- Executes each task using `/speckit.implementSlice` logic
- User prompt after each task: "Continue to next task? (yes/no)"
- Stops immediately if any task review is KO
- Stops cleanly if user says "no"
- Generates comprehensive final report

**Workflow**:
1. Locate `tasks.md` (parse slice identifier or infer from directory)
2. Build ordered task list (topological sort: phases + dependencies)
3. For each task:
   - Execute using `implementSlice` logic (pre-check, implement, review, stage)
   - If OK: Prompt user to continue
   - If KO: Stop immediately
   - If user says "no": Stop cleanly
4. Generate final report (completed, skipped, failed, pending tasks)

**Output**: Final report with:
- Execution summary (completed, skipped, failed, pending counts)
- Detailed task status
- Where execution stopped and why
- Staged changes summary
- Next steps

**Important**: All changes are staged only. Human reviews all staged changes and commits manually when ready.

---

### Other Spec-Kit Commands

- `/speckit.spec` - Generate `spec.md` only
- `/speckit.plan` - Generate `plan.md` only
- `/speckit.tasks` - Generate `tasks.md` and `validation.md` (both reviewed)
- `/speckit.analyze` - Analyze codebase for slice context

---

## Review Rules

### `.cursor/rules/review.mdc` - Spec-Kit Document Review

**Purpose**: Review Spec-Kit documents (spec.md, plan.md, tasks.md, validation.md) before proceeding to next phase.

**Trigger**: Automatic after each Spec-Kit document generation, or manual: `review spec`, `review plan`, `review tasks`, `review validation`

**Review Criteria**:

#### For `spec.md`:
- Scope is explicit and tightly bounded
- Non-goals are explicitly listed
- UI / Core / CLI responsibilities are clearly separated
- No Core or CLI behavior assumed that does not exist
- Safety rules are explicit (read-only, confirmations, no silent writes)
- Determinism & idempotence rules are stated
- Backward compatibility guarantees are explicit

#### For `plan.md`:
- Plan implements spec exactly (no additions)
- Sequencing is safe and minimal
- Read-only steps always precede mutating steps
- Async vs sync Core APIs are explicitly accounted for
- UI state transitions are coherent and deterministic

#### For `tasks.md`:
- **Pre-Review Scan** (mandatory):
  - Count all tasks
  - Scan for anti-patterns (multi-responsibility, verification tasks, polish tasks, size violations)
  - Sample verification (check random tasks against checklist)
  - Phase 9 check (all must be P2/optional)
- **Per-Task Checklist**:
  - Creates ≤ 1 new file OR updates ≤ 1 existing file
  - Single responsibility (Core API OR UI state OR error mapping, NOT multiple)
  - ≤ 8 steps
  - Concrete "Done When" criteria
  - Can be completed in 1-2 commands max
  - Can be committed independently

#### For `validation.md`:
- Every success criterion from spec.md is validated
- Checks are concrete and runnable
- Manual steps are explicit and reproducible
- Error paths are validated, not just happy paths
- Determinism can be observed or verified
- Validation does NOT assume features not implemented in this slice

**Output Format**:
- **OK**: "DECISION: OK" + "NEXT STEP: [command]"
- **KO**: "DECISION: KO" + "BLOCKING ISSUES: [list]" + "REALIGNMENT PROMPT: [text]"

**Automatic Fixes**: When review returns KO, attempts automatic fixes for clearly detectable patterns (see `review.mdc` "Automatic Fixes" section). Maximum 2 attempts per document (configurable).

---

### `.cursor/rules/impl_review.mdc` - Implementation Review

**Purpose**: Review task implementations to verify they match task definition exactly and are safe to stage.

**Trigger**: Automatic after each task implementation in `/speckit.implementSlice` or `/speckit.runSlice`.

**Review Criteria**:

1. **Task Completeness**: All "Done When" criteria from tasks.md are satisfied
2. **Scope Containment**: Only files in "Expected Files Touched" are modified
3. **No Scope Creep**: No new features, flags, or data models beyond task scope
4. **No Unrelated Refactors**: Only changes required for the task
5. **Deterministic Behavior**: Same input produces same output
6. **Clean, Idiomatic Code**: Follows language/framework conventions

**Output Format**:
- **OK**: "DECISION: OK" + "READY FOR STAGING: [confirmation]"
- **KO**: "DECISION: KO" + "BLOCKING ISSUES: [list]" + "CORRECTIVE PROMPT: [text]"

**Important**: Implementation review is **mandatory** before staging. If KO, changes are NOT staged.

---

## Implementation Workflows

### Workflow 1: Full Slice with Automated Design

**Use case**: Starting a new slice from scratch.

```bash
# 1. Generate all Spec-Kit documents with automatic reviews
/speckit.start Slice 12

# Output: All documents ready (spec.md, plan.md, tasks.md, validation.md)
# OR: Blocking issues if any phase fails after max auto-fixes

# 2. Implement entire slice with user prompts
/speckit.runSlice Slice 12

# For each task:
# - Implements task
# - Reviews implementation
# - Stages changes
# - Prompts: "Continue to next task? (yes/no)"
# - User can stop at any time

# 3. Human reviews all staged changes
git status
git diff --staged

# 4. Human tests manually
# (run app, test features, etc.)

# 5. Human commits when ready
git commit -m "Implement Slice 12: UI Create / Adopt Wizard v1"
```

---

### Workflow 2: One Task at a Time

**Use case**: Implementing tasks individually with full control.

```bash
# 1. Generate all Spec-Kit documents
/speckit.start Slice 12

# 2. Implement one task
/speckit.implementSlice T-001

# Output: Staging summary
# - Files changed
# - What was done
# - Review decision (OK/KO)

# 3. Human reviews, tests, commits
git status
# (test manually)
git commit -m "T-001: Create Wizard State Models"

# 4. Continue with next task
/speckit.implementSlice T-002
# ... repeat
```

---

### Workflow 3: Resume After Stopping

**Use case**: Continuing implementation after stopping early.

```bash
# Option A: Use --skip-completed flag
/speckit.runSlice --skip-completed

# Automatically skips tasks that appear already implemented
# (checks "Done When" criteria)

# Option B: Continue with specific task
/speckit.implementSlice T-015

# Option C: Continue from where you stopped
/speckit.runSlice
# Will prompt for each remaining task
```

---

## Best Practices

### 1. Always Start with `/speckit.start`

Before implementing, ensure all Spec-Kit documents are ready:
- `spec.md` - Functional requirements
- `plan.md` - Technical architecture
- `tasks.md` - Implementation tasks
- `validation.md` - Validation runbook

All documents must pass review before implementation.

---

### 2. Use `/speckit.runSlice` for Full Slices

For implementing entire slices, use `/speckit.runSlice`:
- Automatically handles task ordering (phases + dependencies)
- User can stop at any task boundary
- Comprehensive final report

---

### 3. Use `/speckit.implementSlice` for Individual Tasks

For fine-grained control:
- Implement one task at a time
- Review and commit after each task
- Useful for complex tasks or when debugging

---

### 4. Review Staged Changes Before Committing

Always review staged changes before committing:
```bash
git status          # See what's staged
git diff --staged   # See changes in detail
# (test manually)
git commit -m "..." # Commit when ready
```

---

### 5. Respect Task Dependencies

Tasks in `tasks.md` have explicit dependencies. The system enforces:
- Dependencies must be completed before dependent tasks
- Tasks are executed in correct order (topological sort)

If a dependency is missing, the system will stop with a clear error.

---

### 6. Keep Tasks Small and Focused

Each task should:
- Modify ≤ 1 new file OR ≤ 1 existing file
- Have single responsibility (not multiple)
- Be completable in 1-2 commands max
- Have concrete "Done When" criteria

If a task is too large, split it (e.g., T-014 → T-014, T-014b, T-014c).

---

### 7. No Automatic Commits

**Important**: Spec-Kit commands stage changes only. Human responsibility:
- Review staged changes
- Test manually
- Create final commit(s)

This ensures human oversight and quality control.

---

## Troubleshooting

### Issue: "tasks.md not found"

**Solution**: 
- Run `/speckit.tasks` first to generate tasks.md
- Or navigate to slice directory: `cd specs/012-ui-create-adopt-wizard-v1`
- Or provide explicit path: `/speckit.runSlice specs/012-ui-create-adopt-wizard-v1`

---

### Issue: "Task T-XXX not found in tasks.md"

**Solution**:
- Verify task ID format: `T-001`, `T-014b` (not `T-1`, `T14`)
- Check tasks.md for correct task ID
- Ensure you're in the correct slice directory

---

### Issue: "Dependency T-XXX not completed"

**Solution**:
- Complete the dependency task first: `/speckit.implementSlice T-XXX`
- Or use `--skip-completed` flag if dependency is already done

---

### Issue: "Review KO - Blocking issues"

**Solution**:
- Read the blocking issues carefully
- Apply the corrective prompt
- Re-run the command: `/speckit.implementSlice T-XXX`

For Spec-Kit documents (spec.md, plan.md, etc.):
- Fix issues manually
- Re-run the generation command: `/speckit.start` or `/speckit.plan`, etc.

---

### Issue: "Circular dependency detected"

**Solution**:
- Review tasks.md for circular dependencies
- Fix dependency graph manually
- Re-run `/speckit.runSlice`

---

### Issue: "Unexpected files staged"

**Solution**:
- Unstage unexpected files: `git restore --staged <file>`
- Verify task "Expected Files Touched" section
- Re-run implementation if needed

---

## Command Reference Quick Guide

| Command | Purpose | Output |
|---------|---------|--------|
| `/speckit.start Slice N` | Generate all Spec-Kit documents | spec.md, plan.md, tasks.md, validation.md |
| `/speckit.implementSlice T-XXX` | Implement one task | Staged changes + summary |
| `/speckit.runSlice Slice N` | Implement entire slice | Staged changes + final report |
| `review spec` | Review spec.md | OK/KO decision |
| `review plan` | Review plan.md | OK/KO decision |
| `review tasks` | Review tasks.md | OK/KO decision |
| `review validation` | Review validation.md | OK/KO decision |

---

## Related Documentation

- [`docs/AI_CONTEXT.md`](AI_CONTEXT.md) - Global development contract
- [`specs/STATUS.md`](../specs/STATUS.md) - Slice tracking and roadmap
- [`.cursor/rules/speckit.mdc`](../.cursor/rules/speckit.mdc) - Spec-Kit rules
- [`.cursor/rules/review.mdc`](../.cursor/rules/review.mdc) - Document review rules
- [`.cursor/rules/impl_review.mdc`](../.cursor/rules/impl_review.mdc) - Implementation review rules

---

## Summary

Spec-Kit ensures quality and safety through:

1. **Strict phase discipline**: spec → plan → tasks → validation → implementation
2. **Automatic reviews**: Each phase reviewed before proceeding
3. **SAFE PASS implementation**: Small, reversible, auditable steps
4. **Human control**: Final commits are human responsibility
5. **Comprehensive tooling**: Automated workflows with manual oversight

For questions or issues, refer to the troubleshooting section or review the rule files directly.
