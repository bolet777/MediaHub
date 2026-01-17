---
description: Implement a single task from tasks.md following SAFE PASS discipline (staging only, no commit)
---

## User Input

```text
$ARGUMENTS
```

The user input is the task ID (e.g., `T-001`, `T-014b`). Parse and extract the task ID.

## Core Rules (NON-NEGOTIABLE)

1. **One task per command** - No chaining, no auto-continuation
2. **tasks.md is source of truth** - Extract all task details from tasks.md
3. **Strict scope control** - Modify ONLY files listed in task, no spec/plan/tasks/validation.md changes
4. **Staging only** - Stage changes with `git add`, DO NOT create commits
5. **Implementation review** - Use `.cursor/rules/impl_review.mdc` for OK/KO decision

## Execution Flow

### Step 1: Parse Task ID and Locate tasks.md

1. **Extract task ID** from `$ARGUMENTS`:
   - Expected format: `T-XXX` or `T-XXXb`, `T-XXXc` (e.g., `T-001`, `T-014b`)
   - If invalid format: **ERROR** "Invalid task ID format. Expected: T-XXX (e.g., T-001)"

2. **Locate tasks.md**:
   - Check current directory and parent directories for `specs/*/tasks.md`
   - If multiple found: Use the most recent or ask user to specify
   - If not found: **ERROR** "tasks.md not found. Run `/speckit.tasks` first or navigate to slice directory."

3. **Extract slice context**:
   - Read slice number and name from tasks.md header
   - Store for use in staging summary

### Step 2: Extract Task Details from tasks.md

1. **Find task section**:
   - Search for `### T-XXX:` pattern matching the task ID
   - If not found: **ERROR** "Task T-XXX not found in tasks.md"

2. **Extract task information**:
   - **Title**: From `### T-XXX: [Title]`
   - **Priority**: From `**Priority**: P?`
   - **Summary**: From `**Summary**: [text]`
   - **Expected Files Touched**: From `**Expected Files Touched**:` section (list all files)
   - **Steps**: From `**Steps**:` section (numbered list)
   - **Done When**: From `**Done When**:` section (criteria list)
   - **Dependencies**: From `**Dependencies**:` section (task IDs or "None")

3. **Validate task structure**:
   - All required sections must be present
   - Expected Files Touched must list at least one file
   - Steps must be non-empty
   - Done When must have at least one criterion

### Step 3: Pre-Check (Dependencies and Scope)

1. **Check dependencies**:
   - If dependencies listed: Verify each dependency task is completed
   - Check if dependency files exist and are implemented
   - If dependency missing: **STOP** "Dependency T-XXX not completed. Complete dependencies first."
   - If dependency incomplete: **STOP** "Dependency T-XXX appears incomplete. Verify completion first."

2. **Verify task not already implemented**:
   - Check if all files in "Expected Files Touched" exist and match "Done When" criteria
   - If task appears complete: **STOP** "Task T-XXX appears already implemented. Verify Done When criteria."

3. **Verify scope boundaries**:
   - Confirm task does NOT modify: `spec.md`, `plan.md`, `tasks.md`, `validation.md`
   - If task attempts to modify these: **STOP** "Task T-XXX attempts to modify Spec-Kit documents. This is not allowed."

4. **Check file access**:
   - Verify all files in "Expected Files Touched" are accessible
   - For new files: Verify parent directories exist or can be created
   - If file access issues: **STOP** with specific error message

### Step 4: Implement Task

1. **Read implementation context** (if needed):
   - Read `plan.md` for architecture and tech stack context
   - Read `spec.md` for functional requirements (if task references them)
   - Read existing code files that task will modify (for context)

2. **Implement following Steps**:
   - Execute each step from the task's Steps section
   - Follow SAFE PASS discipline:
     - Minimal, additive changes only
     - 1-2 commands max (build/test if required)
     - No unrelated refactors
     - Deterministic and idempotent behavior

3. **Build/Test if required**:
   - If task involves code changes: Run build command (e.g., `swift build`)
   - If task involves tests: Run test command (e.g., `swift test`)
   - If build/test fails: **STOP** and report errors before proceeding to review

4. **Verify "Done When" criteria**:
   - Check each criterion from "Done When" section
   - If any criterion not met: Continue implementation or **STOP** with specific missing items

### Step 5: Implementation Review

1. **Apply review rules**:
   - Use `.cursor/rules/impl_review.mdc` for systematic review
   - Review against:
     - Task completeness vs "Done When"
     - No scope creep (only files in "Expected Files Touched")
     - No unrelated refactors
     - Deterministic behavior
     - Clean, idiomatic code

2. **Review decision**:
   - **OK**: Proceed to Step 6 (Staging)
   - **KO**: **STOP**, display blocking issues, provide minimal corrective prompt
   - Do NOT proceed to staging if review is KO

3. **If KO**:
   - List blocking issues (maximum 3-7)
   - Provide minimal corrective prompt (what needs to change, not full rewrite)
   - Ask: "Fix issues and re-run `/speckit.implementSlice T-XXX`"

### Step 6: Staging (NO COMMIT)

1. **Stage modified files**:
   - For each file in "Expected Files Touched":
     - If file was created: `git add <file>`
     - If file was modified: `git add <file>`
   - **DO NOT** stage files NOT in "Expected Files Touched"
   - **DO NOT** create any git commit

2. **Verify staging**:
   - Run `git status` to confirm only expected files are staged
   - If unexpected files staged: Unstage them with `git restore --staged <file>`

3. **Generate staging summary**:
   - Create structured summary in this format:

```markdown
# Task T-XXX Implementation Complete

**Task**: [Title from tasks.md]
**Priority**: [P?]
**Summary**: [Summary from tasks.md]

## Intent
[Brief description of what this task accomplishes, extracted from Summary and Steps]

## Files Changed
[List all files from "Expected Files Touched" with status: created/modified]

## What Was Done
[Bullet list of what was implemented, based on Steps executed]
- [Specific implementation detail]
- [Another implementation detail]

## What Was Intentionally NOT Done
[Explicit list of what was NOT implemented, if applicable]
- [Item that is out of scope for this task]
- [Item deferred to another task]

## Done When Criteria
[Checklist of "Done When" criteria with status]
- [✅/❌] [Criterion 1]
- [✅/❌] [Criterion 2]

## Review Decision
[OK / KO from Step 5]

## Next Steps
- **If OK**: Review staged changes, test manually, then commit when ready
- **If KO**: Fix issues and re-run `/speckit.implementSlice T-XXX`
- **Next task**: `/speckit.implementSlice T-XXX+1` (if dependencies allow)
```

4. **Output staging summary**:
   - Display the summary to user
   - Confirm files are staged (show `git status` output)
   - Remind: "Changes are staged. Review and test, then commit manually when ready."

## Error Handling

- **If task not found**: Stop with clear error message
- **If dependencies missing**: Stop with list of missing dependencies
- **If build/test fails**: Stop with error output, do not stage
- **If review KO**: Stop with blocking issues, do not stage
- **If scope violation**: Stop immediately, do not modify files

## Important Notes

- **No automatic commits**: This command stages only, human creates final commit
- **One task at a time**: No chaining or auto-continuation
- **Strict scope**: Only modify files listed in task
- **SAFE PASS discipline**: Minimal, additive, reversible changes
- **Review is mandatory**: Must pass impl_review.mdc before staging

## Example Usage

```bash
/speckit.implementSlice T-001
→ Implements T-001, stages changes, outputs summary

/speckit.implementSlice T-014b
→ Implements T-014b, stages changes, outputs summary
```
