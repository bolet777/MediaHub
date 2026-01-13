# MediaHub

MediaHub is a macOS media library system designed as a transparent, filesystem‑first alternative to Photos.app.
It focuses on scalability, determinism, and long‑term maintainability for users managing large photo and video collections.

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

All three slices are frozen and covered by automated validation.

---

## What MediaHub Does Today

- Create and manage multiple independent media libraries
- Store libraries as standard filesystem structures (no proprietary containers)
- Attach one or more Sources to a library
- Detect new photos and videos deterministically
- Import selected media safely into the library
- Organize media by Year / Month (YYYY/MM)
- Handle filename collisions predictably
- Track imported items to avoid duplicates
- Produce transparent, auditable import results
- Preserve compatibility with external tools (Finder, backup software, DigiKam, etc.)

---

## Architecture Overview

MediaHub is implemented as a Swift Package with a strict separation of concerns:

- **Library Core**: identity, structure, validation, discovery
- **Source Management**: source identity, validation, detection
- **Import Engine**: timestamp resolution, destination mapping, collision handling, atomic copy
- **Tracking & Audit**: known‑items persistence and import result storage

Design decisions are documented using Architecture Decision Records (ADRs).

---

## Project Structure

```
MediaHub/
├── Package.swift
├── Sources/
│   └── MediaHub/
│       ├── Library*                # Slice 1: Library entity, identity, validation
│       │   ├── LibraryMetadata.swift
│       │   ├── LibraryIdentifier.swift
│       │   ├── LibraryStructure.swift
│       │   ├── LibraryCreation.swift
│       │   ├── LibraryOpening.swift
│       │   ├── LibraryIdentityPersistence.swift
│       │   ├── LibraryValidation.swift
│       │   └── LibraryDiscovery.swift
│       ├── Source*                 # Slice 2: Sources & detection
│       │   ├── Source.swift
│       │   ├── SourceIdentity.swift
│       │   ├── SourceValidation.swift
│       │   ├── SourceAssociation.swift
│       │   ├── SourceScanning.swift
│       │   ├── LibraryComparison.swift
│       │   ├── DetectionResult.swift
│       │   └── DetectionOrchestration.swift
│       ├── Import*                 # Slice 3: Import execution & orchestration
│       │   ├── ImportExecution.swift
│       │   └── ImportResult.swift
│       ├── TimestampExtraction.swift
│       ├── DestinationMapping.swift
│       ├── CollisionHandling.swift
│       ├── AtomicFileCopy.swift
│       └── KnownItemsTracking.swift
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
    └── 003-import-execution-media-organization/
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

## Explicitly Out of Scope (As of Slice 3)

- Photos.app or device‑specific integrations
- User interface / media browsing
- Advanced duplicate detection (hashing, fuzzy matching)
- Metadata enrichment (tags, faces, albums)
- Pipelines, automation, or scheduling
- Cloud sync or backup features

---

## Roadmap (High‑Level)

- **Slice 4**: To be defined (e.g. UI enablement, pipelines, performance/indexing, Photos.app investigation)

---

## License

To be determined

---