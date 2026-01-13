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

All five slices are frozen and covered by automated validation.

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

**Status**: ⚠️ **Not yet implemented** (planned for Slice 6)

**What MediaHub can do today**:
- Open existing MediaHub libraries (with `.mediahub/library.json`)
- Import into libraries that already contain media files (collision handling works correctly)
- Detect existing media files in libraries via `LibraryContentQuery` (baseline scan works)

**What MediaHub cannot do yet**:
- Adopt an existing library (e.g., `/Volumes/Photos/Photos/Librairie_Amateur` organized in YYYY/MM) by creating `.mediahub/` metadata without modifying existing media files
- Bootstrap a "virgin" library (existing YYYY/MM structure without MediaHub metadata) with a dedicated command

**Note**: Library adoption is architecturally compatible and planned for Slice 6. The core system already supports working with existing media files, but there is no explicit command to adopt a non-legacy library. See `specs/archive/RAPPORT_ADOPTION_LIBRAIRIE.md` for detailed analysis.

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
│   └── MediaHubCLI/                 # Slice 4: CLI tool
│       ├── main.swift
│       ├── LibraryCommand.swift
│       ├── SourceCommand.swift
│       ├── DetectCommand.swift
│       ├── ImportCommand.swift
│       ├── StatusCommand.swift
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

## Explicitly Out of Scope (As of Slice 5)

- Photos.app or device‑specific integrations
- User interface / media browsing
- Advanced duplicate detection (hashing, fuzzy matching) — planned for Slice 8
- Metadata enrichment (tags, faces, albums)
- Pipelines, automation, or scheduling
- Cloud sync or backup features
- Library adoption — planned for Slice 6

---

## Roadmap

### Completed Slices (1–5)
- ✅ **Slice 1**: Library Entity & Identity
- ✅ **Slice 2**: Sources & Import Detection
- ✅ **Slice 3**: Import Execution & Media Organization
- ✅ **Slice 4**: CLI Tool & Packaging
- ✅ **Slice 5**: Safety Features & Dry‑Run Operations

### Planned Slices

- **Slice 6 — Library Adoption**
  - Adopt existing media libraries (YYYY/MM structure) as MediaHub libraries
  - Create `.mediahub/` metadata without modifying existing media files
  - Command: `mediahub library adopt <path>`
  - No‑touch guarantee for existing media

- **Slice 7 — Baseline Index**
  - Performance optimization for large libraries
  - Create baseline index of existing media files
  - Incremental index updates

- **Slice 8 — Advanced Hashing & Deduplication**
  - Content‑based file identification (hash/checksum)
  - Cross‑source duplicate detection
  - Global deduplication beyond path‑based known‑items

For detailed status and decisions, see `specs/STATUS.md`.

---

## License

To be determined

---