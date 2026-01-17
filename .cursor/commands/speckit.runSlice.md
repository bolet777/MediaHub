---
description: Implement a slice end-to-end by running all tasks from tasks.md sequentially (staging only, no commit, with user prompts between tasks)
---

## User Input

```text
$ARGUMENTS
```

Parse the user input to extract:
1. **Slice identifier**: Either "Slice N" / "slice N" format, a path to slice directory, or empty (infer from current directory)
2. **Optional flags**: `--skip-completed` (skip tasks that appear already implemented)

**Examples**:
- `/speckit.runSlice` → Infer slice from current directory (find specs/*/tasks.md)
- `/speckit.runSlice Slice 12` → Use Slice 12 from STATUS.md
- `/speckit.runSlice specs/012-ui-create-adopt-wizard-v1` → Use explicit path
- `/speckit.runSlice --skip-completed` → Skip tasks that appear already done

## Core Rules (NON-NEGOTIABLE)

1. **Reuse implementSlice logic** - For each task, execute the same steps as `/speckit.implementSlice`
2. **Respect task order** - Build ordered list based on phases and explicit dependencies
3. **User prompts** - After each task staging, prompt user to continue
4. **Stop on KO** - If any task review is KO, stop immediately
5. **Staging only** - No commits, only `git add` operations
6. **Final report** - Provide comprehensive summary of completed, stopped, and pending tasks

## Execution Flow

### Step 1: Locate tasks.md

1. **Parse input**:
   - If input matches "Slice N" pattern: Read STATUS.md, find slice, construct path `specs/0XX-*/tasks.md`
   - If input is a path: Use it directly (append `/tasks.md` if needed)
   - If input is empty: Search current directory and parents for `specs/*/tasks.md`
   - If multiple tasks.md found: Ask user to specify or use most recent

2. **Validate tasks.md exists**:
   - If not found: **ERROR** "tasks.md not found. Run `/speckit.tasks` first or provide slice path."

3. **Extract slice context**:
   - Read slice number and name from tasks.md header
   - Store for use in final report

### Step 2: Build Ordered Task List

1. **Parse tasks.md structure**:
   - Find all `## Phase` sections (ordered by appearance)
   - Find all `### T-XXX:` task definitions within each phase
   - Extract for each task:
     - Task ID (T-XXX, T-XXXb, etc.)
     - Phase number/name
     - Dependencies (from "**Dependencies**: T-XXX" or "None")
     - Priority (P1, P2, etc.)

2. **Build dependency graph**:
   - Create a map: task → list of dependencies
   - Handle "None" dependencies (no dependencies)
   - Handle multiple dependencies (comma-separated or list format)

3. **Topological sort**:
   - Order tasks respecting:
     - Phase order (Phase 1 before Phase 2, etc.)
     - Explicit dependencies (T-002 depends on T-001 → T-001 before T-002)
     - Within same phase: maintain original order if no dependencies
   - If circular dependencies detected: **ERROR** "Circular dependency detected in tasks.md"

4. **Filter tasks** (if `--skip-completed` flag):
   - For each task, check if "Done When" criteria appear satisfied
   - If task appears complete: Skip it (but include in final report as "skipped")
   - If task incomplete: Include in execution list

5. **Output task execution plan**:
   ```
   Slice [N] - [Name] - Task Execution Plan
   
   Total tasks: [count]
   Tasks to execute: [count]
   Tasks skipped (if --skip-completed): [count]
   
   Execution order:
   1. T-001: [Title] (Phase 1)
   2. T-002: [Title] (Phase 1, depends on T-001)
   ...
   ```

### Step 3: Execute Tasks Sequentially

For each task in the ordered list:

1. **Display current task**:
   ```
   ──────────────────────────────────────
   Task [N]/[Total]: T-XXX - [Title]
   Phase: [Phase name]
   ──────────────────────────────────────
   ```

2. **Execute task using implementSlice logic**:
   - **Step 1**: Extract task details from tasks.md (same as implementSlice Step 2)
   - **Step 2**: Pre-check dependencies and scope (same as implementSlice Step 3)
   - **Step 3**: Implement task following Steps section (same as implementSlice Step 4)
   - **Step 4**: Implementation review using `.cursor/rules/impl_review.mdc` (same as implementSlice Step 5)
   - **Step 5**: Stage changes and generate summary (same as implementSlice Step 6)

3. **Handle review decision**:
   - **If OK**: Proceed to user prompt
   - **If KO**: **STOP IMMEDIATELY**, display blocking issues, proceed to final report

4. **User prompt** (if OK):
   ```
   Task T-XXX completed and staged.
   
   Continue to next task? (yes/no)
   ```
   - Wait for user response
   - If user says "no", "stop", "quit", "exit": **STOP CLEANLY**, proceed to final report
   - If user says "yes", "continue", "next", "y": Continue to next task
   - If user says "skip": Skip current task, continue to next (mark as skipped in report)

5. **Track execution**:
   - Completed tasks: List of task IDs that passed review and were staged
   - Skipped tasks: List of task IDs skipped by user or --skip-completed
   - Failed tasks: List of task IDs that failed review (KO)
   - Pending tasks: List of task IDs not yet executed

### Step 4: Final Report

Generate comprehensive final report:

```markdown
# Slice [N] - [Name] - Implementation Run Complete

**Started**: [timestamp]
**Ended**: [timestamp]
**Duration**: [duration]

## Execution Summary

| Status | Count | Tasks |
|--------|-------|-------|
| ✅ Completed | [N] | T-001, T-002, ... |
| ⏭️ Skipped | [N] | T-005, T-010, ... |
| ❌ Failed | [N] | T-015 (if any) |
| ⏳ Pending | [N] | T-016, T-017, ... |

## Completed Tasks

[For each completed task, show brief summary]
- **T-001**: [Title] - [Brief what was done]
- **T-002**: [Title] - [Brief what was done]
...

## Skipped Tasks

[If any tasks were skipped]
- **T-005**: [Title] - Skipped (appeared already implemented)
- **T-010**: [Title] - Skipped by user

## Failed Tasks

[If any tasks failed review]
- **T-015**: [Title] - Failed review
  - Blocking issues: [list]
  - Corrective prompt: [prompt from review]

## Stopped At

[If execution stopped before completing all tasks]
- **Stopped at**: T-XXX
- **Reason**: [User stopped / Review KO / Dependency missing]

## Pending Tasks

[If execution stopped early, list remaining tasks]
- T-016: [Title] (Phase 4)
- T-017: [Title] (Phase 4)
...

## Staged Changes

All completed tasks have been staged with `git add`.
**No commits were created.**

Review staged changes:
```bash
git status
git diff --staged
```

## Next Steps

- **If all tasks completed**: Review all staged changes, test manually, then commit:
  ```bash
  git commit -m "Implement Slice [N]: [Name]"
  ```

- **If stopped early**: 
  - Fix issues in failed tasks (if any)
  - Continue with: `/speckit.runSlice` (will skip completed tasks if --skip-completed)
  - Or implement remaining tasks individually: `/speckit.implementSlice T-XXX`

- **If review needed**: Review staged changes before committing
```

## Error Handling

- **If tasks.md not found**: Stop with clear error message
- **If circular dependencies**: Stop with dependency cycle details
- **If task review KO**: Stop immediately, do not continue to next task
- **If user stops**: Stop cleanly, generate final report with current state
- **If file access issues**: Stop with specific error, do not stage partial changes

## Important Notes

- **No automatic commits**: All changes are staged only, human creates final commit
- **User control**: User can stop at any task boundary
- **Respects dependencies**: Tasks are executed in correct order
- **Reuses implementSlice logic**: Same quality gates and review process
- **Clean stops**: If stopped, final report shows exactly where and why

## Example Usage

```bash
# Infer slice from current directory
/speckit.runSlice

# Explicit slice identifier
/speckit.runSlice Slice 12

# Explicit path
/speckit.runSlice specs/012-ui-create-adopt-wizard-v1

# Skip already-completed tasks
/speckit.runSlice --skip-completed
```

## Example Execution Flow

```
/speckit.runSlice Slice 12

→ Locates specs/012-ui-create-adopt-wizard-v1/tasks.md
→ Builds ordered task list (T-001, T-002, ..., T-038)
→ Executes T-001: implements, reviews, stages, shows summary
→ Prompts: "Continue to next task? (yes/no)"
→ User: "yes"
→ Executes T-002: implements, reviews, stages, shows summary
→ Prompts: "Continue to next task? (yes/no)"
→ User: "no"
→ Generates final report showing T-001, T-002 completed, T-003-T-038 pending
```
