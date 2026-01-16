---
description: Generate an actionable, dependency-ordered tasks.md for the feature based on available design artifacts.
handoffs: 
  - label: Analyze For Consistency
    agent: speckit.analyze
    prompt: Run a project analysis for consistency
    send: true
  - label: Implement Project
    agent: speckit.implement
    prompt: Start the implementation in phases
    send: true
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Outline

1. **Setup**: Run `.specify/scripts/bash/check-prerequisites.sh --json` from repo root and parse FEATURE_DIR and AVAILABLE_DOCS list. All paths must be absolute. For single quotes in args like "I'm Groot", use escape syntax: e.g 'I'\''m Groot' (or double-quote if possible: "I'm Groot").

2. **Load design documents**: Read from FEATURE_DIR:
   - **Required**: plan.md (tech stack, libraries, structure), spec.md (user stories with priorities)
   - **Optional**: data-model.md (entities), contracts/ (API endpoints), research.md (decisions), quickstart.md (test scenarios)
   - Note: Not all projects have all documents. Generate tasks based on what's available.

3. **Execute task generation workflow**:
   - Load plan.md and extract tech stack, libraries, project structure
   - Load spec.md and extract user stories with their priorities (P1, P2, P3, etc.)
   - If data-model.md exists: Extract entities and map to user stories
   - If contracts/ exists: Map endpoints to user stories
   - If research.md exists: Extract decisions for setup tasks
   - Generate tasks organized by user story (see Task Generation Rules below)
   - Generate dependency graph showing user story completion order
   - Create parallel execution examples per user story
   - Validate task completeness (each user story has all needed tasks, independently testable)

4. **Generate tasks.md**: Use `.specify/templates/tasks-template.md` as structure, fill with:
   - Correct feature name from plan.md
   - Phase 1: Setup tasks (project initialization)
   - Phase 2: Foundational tasks (blocking prerequisites for all user stories)
   - Phase 3+: One phase per user story (in priority order from spec.md)
   - Each phase includes: story goal, independent test criteria, tests (if requested), implementation tasks
   - Final Phase: Polish & cross-cutting concerns
   - All tasks must follow the strict checklist format (see Task Generation Rules below)
   - Clear file paths for each task
   - Dependencies section showing story completion order
   - Parallel execution examples per story
   - Implementation strategy section (MVP first, incremental delivery)

5. **Automatic Review of tasks.md**: After generating tasks.md, automatically trigger review:
   - Apply review rules from `.cursor/rules/review.mdc`
   - Perform mandatory Pre-Review Scan (count tasks, scan for anti-patterns, sample verification, Phase 9 check)
   - Run systematic review of tasks.md against phase-specific criteria
   - If KO: Stop workflow, display blocking issues, provide realignment prompt
   - If OK: Proceed to step 6

6. **Generate validation.md**: After tasks.md review passes, generate validation runbook:
   - Load spec.md to extract:
     - Success criteria (all measurable outcomes)
     - User stories with acceptance scenarios
     - Safety rules (read-only, confirmations, determinism)
     - Backward compatibility requirements
   - Load plan.md to understand:
     - Technical context (platform, frameworks, build commands)
     - Architecture decisions affecting validation
   - Load tasks.md to understand:
     - Implementation structure
     - Task dependencies
     - Test fixtures needed
   - Generate validation.md with structure:
     - **Header**: Slice number, title, author, date, status
     - **Validation Overview**: 
       - Description referencing spec.md success criteria
       - Key Validation Principles (extracted from spec.md safety rules)
       - Validation Approach (manual/automated based on feature type)
     - **1. Preconditions**:
       - System Requirements (OS, language versions, tools)
       - Build and Run Commands (exact commands to build/run)
       - Cleanup Before Validation (commands to reset test state)
     - **2. Test Fixtures**:
       - Fixture Setup Commands (create test data, libraries, etc.)
       - Expected results for each fixture
     - **3. Validation Checklist**:
       - One section per user story from spec.md
       - For each user story:
         - Extract all acceptance scenarios from spec.md
         - Create numbered checks (Check X.Y: [Description])
         - Each check includes:
           - Setup requirements
           - Steps (runnable commands or UI actions)
           - Expected Results (checklist with ✅ items)
           - Pass/Fail criteria (specific, measurable)
           - Timing requirements (if specified in spec.md)
           - Determinism verification (if applicable)
     - **4. Error Path Validation**:
       - Validation of error handling from spec.md
       - Test error scenarios with expected error messages
     - **5. Determinism Verification**:
       - Checks for deterministic behavior (same input → same output)
       - Repeatability tests
     - **6. Safety Guarantees Validation**:
       - Read-only operations verification
       - Confirmation dialogs verification (if applicable)
       - Zero mutation checks
   - Write validation.md to FEATURE_DIR/validation.md

7. **Automatic Review of validation.md**: After generating validation.md, automatically trigger review:
   - Apply review rules from `.cursor/rules/review.mdc`
   - Run systematic review of validation.md against phase-specific criteria for validation.md:
     - Verify all success criteria from spec.md are covered
     - Verify checks are concrete and runnable (not vague)
     - Verify manual steps are explicit and reproducible
     - Verify error paths are validated (not just happy paths)
     - Verify determinism can be observed or verified
     - Verify safety guarantees are validated
     - Verify validation does NOT assume features not implemented in this slice
   - If KO: Stop workflow, display blocking issues, provide realignment prompt
   - If OK: Proceed to step 8

8. **Report**: Output paths to generated tasks.md and validation.md, summary, and review decisions:
   - Total task count
   - Task count per user story
   - Parallel opportunities identified
   - Independent test criteria for each story
   - Suggested MVP scope (typically just User Story 1)
   - Format validation: Confirm ALL tasks follow the checklist format (checkbox, ID, labels, file paths)
   - Tasks.md review decision: OK or KO
   - Validation.md review decision: OK or KO
   - If both reviews OK: "NEXT STEP: `/speckit.implement`"
   - If any review KO: "Fix issues, then re-run `/speckit.tasks`"

Context for task generation: $ARGUMENTS

The tasks.md should be immediately executable - each task must be specific enough that an LLM can complete it without additional context.

## Task Generation Rules

**CRITICAL**: Tasks MUST be organized by user story to enable independent implementation and testing.

**Tests are OPTIONAL**: Only generate test tasks if explicitly requested in the feature specification or if user requests TDD approach.

### Checklist Format (REQUIRED)

Every task MUST strictly follow this format:

```text
- [ ] [TaskID] [P?] [Story?] Description with file path
```

**Format Components**:

1. **Checkbox**: ALWAYS start with `- [ ]` (markdown checkbox)
2. **Task ID**: Sequential number (T001, T002, T003...) in execution order
3. **[P] marker**: Include ONLY if task is parallelizable (different files, no dependencies on incomplete tasks)
4. **[Story] label**: REQUIRED for user story phase tasks only
   - Format: [US1], [US2], [US3], etc. (maps to user stories from spec.md)
   - Setup phase: NO story label
   - Foundational phase: NO story label  
   - User Story phases: MUST have story label
   - Polish phase: NO story label
5. **Description**: Clear action with exact file path

**Examples**:

- ✅ CORRECT: `- [ ] T001 Create project structure per implementation plan`
- ✅ CORRECT: `- [ ] T005 [P] Implement authentication middleware in src/middleware/auth.py`
- ✅ CORRECT: `- [ ] T012 [P] [US1] Create User model in src/models/user.py`
- ✅ CORRECT: `- [ ] T014 [US1] Implement UserService in src/services/user_service.py`
- ❌ WRONG: `- [ ] Create User model` (missing ID and Story label)
- ❌ WRONG: `T001 [US1] Create model` (missing checkbox)
- ❌ WRONG: `- [ ] [US1] Create User model` (missing Task ID)
- ❌ WRONG: `- [ ] T001 [US1] Create model` (missing file path)

### Task Organization

1. **From User Stories (spec.md)** - PRIMARY ORGANIZATION:
   - Each user story (P1, P2, P3...) gets its own phase
   - Map all related components to their story:
     - Models needed for that story
     - Services needed for that story
     - Endpoints/UI needed for that story
     - If tests requested: Tests specific to that story
   - Mark story dependencies (most stories should be independent)

2. **From Contracts**:
   - Map each contract/endpoint → to the user story it serves
   - If tests requested: Each contract → contract test task [P] before implementation in that story's phase

3. **From Data Model**:
   - Map each entity to the user story(ies) that need it
   - If entity serves multiple stories: Put in earliest story or Setup phase
   - Relationships → service layer tasks in appropriate story phase

4. **From Setup/Infrastructure**:
   - Shared infrastructure → Setup phase (Phase 1)
   - Foundational/blocking tasks → Foundational phase (Phase 2)
   - Story-specific setup → within that story's phase

### Phase Structure

- **Phase 1**: Setup (project initialization)
- **Phase 2**: Foundational (blocking prerequisites - MUST complete before user stories)
- **Phase 3+**: User Stories in priority order (P1, P2, P3...)
  - Within each story: Tests (if requested) → Models → Services → Endpoints → Integration
  - Each phase should be a complete, independently testable increment
- **Final Phase**: Polish & Cross-Cutting Concerns
