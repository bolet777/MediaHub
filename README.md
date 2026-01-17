# MediaHub

MediaHub is a macOS media library system designed as a transparent, filesystem‑first alternative to Photos.app.
It focuses on scalability, determinism, and long‑term maintainability for users managing large photo and video collections.

---

## About MediaHub

MediaHub is designed to replace Photos.app and Image Capture for users who want a simple, reliable, and scalable way to import, organize, and manage large photo and video libraries.

It keeps the simplicity and familiarity of Photos.app, while removing its structural limitations: embedded libraries, fragile backups, poor interoperability, and lack of control over long-term storage.

### Who MediaHub is For

MediaHub is built for:
- macOS users already comfortable with Photos.app
- Users managing large or growing libraries
- People who care about backup, portability, and long-term access
- Users who want to use external tools (DigiKam, ON1, exiftool, Finder)

MediaHub is not aimed at:
- Cloud-first or mobile-only workflows
- Fully automatic "magic" organization
- Opaque, embedded, or vendor-locked storage models

### Core Problem It Solves

Photos.app works well for casual usage, but becomes limiting when:
- Libraries grow large
- Backups must be transparent and reliable
- Multiple libraries are needed
- External editing tools must coexist
- Files must remain usable outside a proprietary container

MediaHub solves this by treating media as normal files on disk, organized in a clear and predictable structure (Year/Month folders), while still providing a Photos-like import experience through Sources and deterministic workflows.

### Design Principles

MediaHub follows these non-negotiable principles (see [`CONSTITUTION.md`](CONSTITUTION.md) for details):
- **Simple by default**: The core experience must feel no more complex than Photos.app
- **Transparent storage**: Files live in normal folders, usable without MediaHub
- **Safe operations**: No destructive actions without explicit confirmation
- **Deterministic behavior**: Same inputs produce the same results
- **Interoperability first**: External tools must not "break" MediaHub
- **Scalable by design**: Multiple libraries, large volumes, long-term usage are first-class concerns

---

## Current Status

The MediaHub core is fully implemented, tested, and validated through the following slices:

- **Slice 1 — Library Entity & Identity**
  - Persistent, identifiable libraries on disk
  - Multiple independent libraries
  - Validation, discovery, and identity persistence across moves/renames

- **Slice 2 — Sources & Import Detection**
  - Folder‑based Sources
  - Read‑only, deterministic detection of new media
  - Explainable detection results
  - Persistent Source–Library associations

- **Slice 3 — Import Execution & Media Organization**
  - Real media import (copy)
  - Deterministic Year/Month (YYYY/MM) organization
  - Collision handling (rename / skip / error)
  - Atomic and interruption‑safe import
  - Known‑items tracking to prevent re‑imports
  - Auditable import results

- **Slice 4 — CLI Tool & Packaging**
  - Command‑line interface (CLI) executable
  - Library, source, detection, and import commands
  - JSON output support and progress feedback

- **Slice 5 — Safety Features & Dry‑Run Operations**
  - Dry‑run mode for import operations (preview without copying)
  - Explicit confirmation prompts for import operations
  - Read‑only guarantees for detection operations
  - Safety‑first error handling

- **Slice 6 — Library Adoption**
  - Adopt existing library directories organized in YYYY/MM
  - Baseline scan of existing media files
  - Idempotent adoption (safe re-runs)

- **Slice 7 — Baseline Index**
  - Persistent baseline index for fast library content queries
  - Incremental index updates during import
  - Read-only index usage in detect (fallback to full scan if needed)

- **Slice 8 — Advanced Hashing & Deduplication**
  - Content-based duplicate detection using SHA-256 hashing
  - Cross-source duplicate detection (detects duplicates even with different paths)
  - Baseline Index v1.1 with optional hash storage
  - Hash computation and storage during import
  - Hash-based duplicate detection during detect

- **Slice 9 — Hash Coverage & Maintenance**
  - `mediahub index hash` command for computing missing hashes
  - Incremental and idempotent hash computation
  - Hash coverage reporting in status command

- **Slice 9b — Duplicate Reporting & Audit**
  - `mediahub duplicates` command for duplicate file reporting
  - Multiple output formats (text, JSON, CSV)
  - Deterministic ordering and read-only operations

- **Slice 9c — Performance & Scale Observability**
  - Performance measurement for status, index hash, and duplicates commands
  - Scale metrics reporting (file count, total size, hash coverage)
  - Graceful degradation when baseline index is missing

- **Slice 10 — Source Media Types + Library Statistics**
  - Source media type filtering (images, videos, both)
  - Library statistics computation (total items, by year, by media type)
  - Status command integration with statistics display

- **Slice 11 — UI Shell v1 + Library Discovery**
  - SwiftPM MediaHubUI app shell (SwiftUI macOS application)
  - Folder-based library discovery (read-only, deterministic order)
  - Library opening via Core APIs + StatusView display
  - Error handling and moved/deleted library detection

All slices through 11 are frozen and covered by automated validation.

---

## What MediaHub Does Today

- Create and manage multiple independent media libraries
- Store libraries as standard filesystem structures (no proprietary containers)
- Attach one or more folder-based Sources to a library
- Detect new photos and videos deterministically
- Import all detected items from a Source (via `--all` flag; fine-grained selection is P2)
- Organize media by Year / Month (YYYY/MM)
- Handle filename collisions predictably
- Track imported items to avoid duplicates
- Produce transparent, auditable import results
- Preview import operations with dry‑run mode
- Preserve compatibility with external tools (Finder, backup software, DigiKam, etc.)

### Source vs Library Model

**Source**: An input location that MediaHub reads from. Currently, MediaHub supports **folder-based Sources** only. Sources are **read‑only** — MediaHub never modifies Source files during detection or import. Sources are attached to Libraries and scanned to detect new media items available for import. (iPhone and Photos.app integration are planned for future slices.)

**Library**: The final destination controlled by MediaHub. A Library contains a `.mediahub/` metadata directory and organizes media in Year/Month (YYYY/MM) folders. MediaHub manages Library structure and metadata, but files remain accessible without MediaHub (transparent storage). Libraries are the "source of truth" for imported media and are never modified by external tools during normal operation.

### Library Adoption

**Status**: ✅ Implemented (Slice 6)

MediaHub can adopt an existing filesystem library already organized as `YYYY/MM` by creating the `.mediahub/` metadata directory **without modifying existing media files**.

- Adoption performs a baseline scan and creates an initial index.
- Adoption is idempotent and safe to re-run.
- External tools can continue to access the media files directly.

---

## Architecture Overview

MediaHub is implemented as a Swift Package with a strict separation of concerns:

- **Library Core**: identity, structure, validation, discovery
- **Source Management**: source identity, validation, detection
- **Import Engine**: timestamp resolution, destination mapping, collision handling, atomic copy
- **Tracking & Audit**: known‑items persistence and import result storage
- **CLI Interface**: command‑line tool for library, source, detection, and import operations
- **Safety Features**: dry‑run mode, confirmation prompts, read‑only guarantees

Design decisions are documented using Architecture Decision Records (ADRs).

---

## Project Structure

```
MediaHub/
├── Package.swift
├── Sources/
│   ├── MediaHub/                    # Core library
│   │   ├── Library*                 # Slice 1: Library entity, identity, validation
│   │   │   ├── LibraryMetadata.swift
│   │   │   ├── LibraryIdentifier.swift
│   │   │   ├── LibraryStructure.swift
│   │   │   ├── LibraryCreation.swift
│   │   │   ├── LibraryOpening.swift
│   │   │   ├── LibraryIdentityPersistence.swift
│   │   │   ├── LibraryValidation.swift
│   │   │   └── LibraryDiscovery.swift
│   │   ├── Source*                  # Slice 2: Sources & detection
│   │   │   ├── Source.swift
│   │   │   ├── SourceIdentity.swift
│   │   │   ├── SourceValidation.swift
│   │   │   ├── SourceAssociation.swift
│   │   │   ├── SourceScanning.swift
│   │   │   ├── LibraryComparison.swift
│   │   │   ├── DetectionResult.swift
│   │   │   └── DetectionOrchestration.swift
│   │   ├── Import*                  # Slice 3: Import execution & orchestration
│   │   │   ├── ImportExecution.swift
│   │   │   └── ImportResult.swift
│   │   ├── TimestampExtraction.swift
│   │   ├── DestinationMapping.swift
│   │   ├── CollisionHandling.swift
│   │   ├── AtomicFileCopy.swift
│   │   └── KnownItemsTracking.swift
│   ├── MediaHubCLI/                 # Slice 4: CLI tool
│   │   ├── main.swift
│   │   ├── LibraryCommand.swift
│   │   ├── SourceCommand.swift
│   │   ├── DetectCommand.swift
│   │   ├── ImportCommand.swift
│   │   ├── StatusCommand.swift
│   │   └── ...
│   └── MediaHubUI/                  # Slice 11: SwiftUI macOS app
│       ├── MediaHubUIApp.swift
│       ├── ContentView.swift
│       ├── AppState.swift
│       ├── LibraryDiscoveryService.swift
│       ├── StatusView.swift
│       └── ...
├── Tests/
│   └── MediaHubTests/               # Unit & integration tests (100+)
├── docs/
│   ├── adr/                         # ADR 001–016
│   ├── library-structure-specification.md
│   ├── library-validation-rules.md
│   ├── path-to-identifier-mapping-strategy.md
│   └── discovery-scope-slice1.md
└── specs/
    ├── 001-library-entity/
    ├── 002-sources-import-detection/
    ├── 003-import-execution-media-organization/
    ├── 004-cli-tool-packaging/
    ├── 005-safety-features-dry-run/
    ├── archive/                      # Historical documents
    │   └── RAPPORT_ADOPTION_LIBRAIRIE.md
    └── STATUS.md                     # Project status and roadmap tracking
```

---

## Validation & Quality

- Swift Package Manager project
- 100+ automated unit and integration tests
- Validation documents per slice
- Deterministic behavior enforced by tests
- No UI‑driven logic in the core

Build:
```bash
swift build
```

Test:
```bash
swift test
```

---

## Explicitly Out of Scope (As of Slice 11)

- Photos.app or device‑specific integrations
- UI-driven business logic (the desktop UI orchestrates CLI workflows; business logic stays in core/CLI)
- Metadata enrichment (tags, faces, albums)
- Pipelines, automation, or scheduling
- Cloud sync or backup features

---

## Roadmap

### North Star
A transparent, safety-first macOS desktop app for importing, organizing, auditing, and maintaining large photo/video libraries — with a CLI backend that remains scriptable and deterministic.

### Product Pillars
- **Safety & Trust**: no-touch rules, explicit confirmations, dry-run guarantees.
- **Determinism & Idempotence**: reproducible outcomes, interruption-safe operations.
- **Scalability**: large libraries, incremental indexing, bounded operations.
- **Auditability**: explainable decisions, reportable outputs, traceable state.
- **Desktop Experience**: a modern macOS UI that uses the CLI/core as a backend.

### Completed Slices (1–13b)
- ✅ Slice 1: Library Entity & Identity
- ✅ Slice 2: Sources & Import Detection
- ✅ Slice 3: Import Execution & Media Organization
- ✅ Slice 4: CLI Tool & Packaging
- ✅ Slice 5: Safety Features & Dry‑Run Operations
- ✅ Slice 6: Library Adoption
- ✅ Slice 7: Baseline Index
- ✅ Slice 8: Advanced Hashing & Deduplication
- ✅ Slice 9: Hash Coverage & Maintenance
- ✅ Slice 9b: Duplicate Reporting & Audit
- ✅ Slice 9c: Performance & Scale Observability
- ✅ Slice 10: Source Media Types + Library Statistics
- ✅ Slice 11: UI Shell v1 + Library Discovery
- ✅ Slice 12: UI Create / Adopt Wizard v1
- ✅ Slice 13: UI Sources + Detect + Import (P1)
- ✅ Slice 13b: UI Integration & UX Polish

### Planned Slices (Next)
- ▶️ **Slice 14 — Progress + Cancel API minimale**
  - Add progress reporting and cancellation support to core operations (detect, import, hash)

- ▶️ **Slice 15 — UI Operations UX (progress / cancel)**
  - Progress bars, step indicators, and cancellation UI for detect/import/hash operations

- ▶️ **Slice 16 — UI Hash Maintenance + Coverage**
  - Hash maintenance UI (batch/limit operations) and coverage insights with duplicate detection (read-only)

- ▶️ **Slice 17 — History / Audit UX + Export Center**
  - Operation timeline (detect/import/maintenance), run details, and export capabilities (JSON/CSV/TXT)

- ▶️ **Slice 18 — macOS Permissions + Distribution Hardening**
  - Sandbox strategy, notarization, security-scoped bookmarks, and distribution hardening

For detailed status and per-slice validation, see `specs/STATUS.md`.

---

## License

To be determined

---