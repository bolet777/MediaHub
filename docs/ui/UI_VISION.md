

# UI Vision — MediaHub v1

This document defines the **UI/UX contract** for MediaHub v1.

It locks the **model mental**, the **interaction philosophy**, and the **visual discipline**
so the UI remains **powerful, calm, and deterministic**, aligned with the CLI‑backend architecture.

This is a **product vision document**, not a design spec.

---

## Product Positioning (UI Perspective)

**MediaHub is not a photo application.**

It is a **library maintenance and orchestration tool**.

The UI exists to:
- Observe the state of libraries
- Orchestrate safe, explicit operations
- Explain outcomes clearly

Non‑goals:
- Browsing photos
- Editing media
- Tagging, albums, curation
- Automated or silent behavior

---

## Core UI Principles

### 1. Calm by Default

- Minimal text
- Generous whitespace
- Few visible controls

> The UI should feel almost empty when nothing requires attention.

---

### 2. Progressive Disclosure

- Show **only what is useful now**
- Advanced or rare information is hidden by default
- Details appear only:
  - when a problem exists
  - when the user explicitly requests an action

---

### 3. Action‑Driven UI

Every visible element must satisfy at least one:
- Explains the current state
- Enables a safe action

If it does neither → it does not belong on screen.

---

### 4. Deterministic & Trustworthy

- No implicit behavior
- No silent background jobs
- All operations are:
  - previewable (dry‑run)
  - confirmable
  - reportable

---

### 5. CLI as Backend, UI as Orchestrator

- The UI never re‑implements business logic
- The UI maps directly to CLI commands
- The UI expresses **intent and results**, not internal mechanics

---

## Visible UI Structure (v1)

The user normally interacts with **one single surface per library**.

Visible structure:
- Header (identity)
- Status
- Sources
- Actions
- Recent history

No tabs are visible by default.

---

## Text & Microcopy Rules

- Maximum **one sentence per section**
- Use plain, human language
- Prefer verbs over nouns

Examples:
- `Library healthy`
- `No new items`
- `45 new items detected`

Avoid:
- Technical jargon
- Internal terminology (BaselineIndex, hash_db, etc.)

---

## Numbers & Metrics

Rules:
- A number must lead to an action
- Decorative metrics are forbidden

Allowed:
- Hash coverage percentage (only if < 100%)
- New items count

Hidden by default:
- Detailed statistics
- Historical aggregates

---

## Application States

### App‑Level States
- Home (no library selected)
- Library selected
- Operation running
- Error / blocked

### Operation States
- Preview (dry‑run)
- Confirm
- Running
- Completed
- Failed

---

## Error Handling Philosophy

- Errors are explicit
- Errors explain what happened
- Errors suggest a next action

No stack traces or raw technical output in the UI.

---

## Visual Tone & Style

- macOS native components
- System typography and colors
- No decorative branding
- Neutral, professional appearance

MediaHub should feel like a **system utility**, not a consumer app.

---

## Non‑Goals (UI)

The UI must never:
- Browse or render media
- Modify files directly
- Infer user intent
- Run background operations silently
- Hide destructive consequences

---

## Summary

> MediaHub’s UI should feel **quiet, reliable, and intentional**.  
> It stays invisible when things are healthy  
> and becomes explicit only when action is required.