# AI Context — MediaHub

This document defines the **global development contract** for MediaHub when working with AI agents (Cursor, ChatGPT, etc.).

It is authoritative and must be read before starting or continuing any slice.

---

## Project Overview

MediaHub is a **SwiftPM project** with a **CLI-first architecture**.

The CLI is the backend and source of truth.
The macOS UI (MediaHubUI) is a **read-only orchestrator** built with SwiftUI.

No business logic may be introduced in the UI.

---

## Repository Structure

- Core logic: `Sources/MediaHub/`
- CLI: `Sources/MediaHubCLI/` (Swift ArgumentParser)
- UI (SwiftUI, SwiftPM target): `Sources/MediaHubUI/`
- Tests: `Tests/MediaHubTests/`
- Specs (Spec-Kit): `specs/`
- Global slice tracking: `specs/STATUS.md`

---

## Spec-Kit Workflow (NON-NEGOTIABLE)

All development is **slice-based** and follows **Spec-Kit** strictly:
spec.md → plan.md → tasks.md → validation.md
→ implementation (SAFE passes)
→ review → freeze

Rules:
- **No code** before spec + plan + tasks + validation are approved.
- No phase may be skipped.
- Each phase must receive an explicit **OK / KO** before proceeding.
- Prefer minimal, additive changes.

---

## SAFE Implementation Rules

All implementation must follow SAFE passes:

- One logical zone at a time
- 1–2 commands max per pass (`swift build`, `swift test`, etc.)
- Read-only first (dry-run, in-memory)
- Writes only after guards are in place
- Atomic writes only (write → rename)
- Determinism and idempotence are mandatory

---

## Safety & Scope Constraints

- Never overwrite or mutate user data silently
- Backward compatibility is mandatory
- No refactors unless explicitly required by the slice
- No new CLI commands or flags unless explicitly scoped
- Avoid scope creep at all times

---

## UI-Specific Rules (MediaHubUI)

- UI is a **read-only orchestrator**
- UI may call Core APIs, not the CLI binary
- No filesystem mutations from UI
- No long-running work on MainActor
- Errors must be user-facing, stable, and actionable
- Status semantics must match CLI **semantically**, not structurally

---

## Iteration Protocol

We work in a strict loop:

1. Human runs a prompt or command in Cursor
2. Cursor generates/updates files
3. Human pastes results or diffs back
4. AI reviews and responds with:
   - **OK → next prompt**
   - **KO → minimal realignment prompt**

The AI must always generate the **next prompt**.

---

## Slice Continuity

Before starting a new slice, always read:
- `specs/STATUS.md`
- Previous slice specs, plan, tasks, validation

Do not assume future requirements.

Default to the **safest, smallest, most reversible** option.