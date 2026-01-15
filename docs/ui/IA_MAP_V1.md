# IA Map — MediaHub v1

This document defines the **Information Architecture** of MediaHub v1.

It explicitly separates:
- the **complete functional space** (what exists)
- from the **visible UI v1** (what the user actually sees)

This document is a **product contract**, not a wireframe.

---

## Core Principles

- The IA map is **wide** to protect the product vision
- The visible UI is **narrow** to preserve simplicity
- Complexity is handled by **hiding**, not by removing
- No screen exists without a clear user intent

---

## IA Map — Complete Product Space

This represents everything MediaHub v1 supports conceptually,
even if not visible at all times.

```
MediaHub
├─ Home
├─ Libraries
│  ├─ Create / Adopt Library (Wizard)
│  └─ Library Detail
│     ├─ Overview (Dashboard)
│     ├─ Sources
│     ├─ Operations
│     │  ├─ Detect
│     │  ├─ Import
│     │  └─ Maintenance
│     ├─ Index & Hashing
│     ├─ History / Audit
│     └─ Library Settings
├─ Reports & Audit (Global)
├─ App Settings
└─ Help / Diagnostics
```

---

## IA Map — Visible UI v1 (UX Contract)

This defines what the user sees **90% of the time**.

```
Home
└─ + New Library…

Library View
├─ Header
├─ Status
├─ Sources
├─ Actions
└─ Recent History
```

Rules:
- No tabs visible by default
- No nested navigation
- One mental model: *one library, one surface*

---

## Home

**Purpose**
- Orientation
- First action

**Visible Elements**
- Primary CTA: `+ New Library…`
- Optional recent libraries list

Nothing else is shown.

---

## Library View (Single Main Surface)

This is the **core UI surface** of MediaHub.

### Header
- Library name
- Library path
- Identity only (no actions)

---

### Status

Purpose: communicate library health in **one glance**.

Rules:
- Exactly one primary state
- At most one warning
- At most one suggested action

Examples:
- `Library healthy`
- `Hash coverage: 72% — action required`

---

### Sources

Purpose: show **where media comes from**.

Rules:
- One line per source
- Clear, readable status
- No details unless user acts

Examples:
- `iPhone Backup — No new items`
- `Camera Archive — 45 new items detected`

---

### Actions

Purpose: the **only place where the user acts**.

Rules:
- Maximum 3 actions visible
- Disabled if not applicable
- No hidden side effects

Typical actions:
- Detect
- Import
- Run maintenance

---

### Recent History

Purpose: short-term memory.

Rules:
- Show only recent operations
- One-line summaries
- Link to full history when needed

---

## Contextual Surfaces (Hidden by Default)

These surfaces exist but are **never shown automatically**.

They are opened explicitly and closed immediately after use.

- Create / Adopt Library wizard
- Detect preview & results
- Import preview & results
- Maintenance configuration
- Full History / Audit view
- Index & Hashing details

---

## Navigation Rules

- Sidebar lists **libraries only**
- No global feature navigation
- All operations open as:
  - modal
  - sheet
  - or transient view

---

## Evolution Rules

Future features must:
- Attach to an existing surface
- Or remain hidden until explicitly required

No new permanent top-level screens
without strong justification.

---

## Summary

> The IA map is intentionally larger than the UI.  
> Simplicity is enforced by restraint, not by limitation.
