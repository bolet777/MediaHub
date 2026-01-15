# CLI ↔ UI Mapping — MediaHub v1

This document defines the **contract between UI actions and CLI commands**.

**Rule:** the UI never implements business logic.

---

## Core Principle

> Every UI action must map to a **single, explicit CLI command**.

- No hidden behavior  
- No background jobs without explicit user intent  
- No command chaining without confirmation  

---

## Library Lifecycle

### Create New Library

**UI Action**
- Create a new empty library

**CLI**
```bash
mediahub library create <path>
```

**UI Responsibilities**
- Path selection
- Explicit confirmation
- Error display

---

### Adopt Existing Library

**UI Action**
- Adopt an existing on-disk library

**CLI**
```bash
mediahub library adopt <path> --dry-run
mediahub library adopt <path>
```

**UI Responsibilities**
- Show dry-run preview
- Explain “no media modified”
- Require explicit confirmation

---

## Sources

### Attach Source

**UI Action**
- Attach a read-only source to a library

**CLI**
```bash
mediahub source attach <library> <path>
```

**UI Responsibilities**
- Path selection
- Validation error display

---

### Detect

**UI Action**
- Detect new items from a source

**CLI**
```bash
mediahub detect <library> <source> --dry-run
mediahub detect <library> <source>
```

**UI Responsibilities**
- Show dry-run preview
- Display new item count
- Render detection report

---

## Import

### Import Media

**UI Action**
- Import detected items into a library

**CLI**
```bash
mediahub import <library> <source> --dry-run
mediahub import <library> <source>
```

**UI Responsibilities**
- Preview summary
- Require confirmation
- Show progress feedback
- Display results report

---

## Maintenance & Hashing

### Run Hash Maintenance

**UI Action**
- Compute missing hashes for a library

**CLI**
```bash
mediahub index hash <library> --dry-run
mediahub index hash <library>
```

**UI Responsibilities**
- Show hash coverage delta
- Expose batch / limit controls (if available)
- Display maintenance report

---

## Status

### Library Status Panel

**UI Action**
- Display current library health

**CLI**
```bash
mediahub status <library>
```

**UI Responsibilities**
- Translate CLI output to plain language
- Show only actionable signals
- Hide non-actionable metrics

---

## History & Audit

### Recent History

**UI Action**
- Display recent operations for a library

**CLI Source**
- Execution reports stored on disk

**UI Responsibilities**
- List recent runs
- Allow opening full reports
- Never modify historical data

---

## Error Handling

- CLI errors are authoritative
- UI reformats messages for clarity
- No silent retries
- No automatic recovery without user approval

---

## Non-Goals

The UI must **never**:
- Mutate data directly
- Infer user intent
- Chain multiple commands implicitly
- Execute background operations silently

---

## Summary

> **CLI defines truth.**  
> **UI expresses intent.**  
> **Reports are the contract.**