# MediaHub Constitution

## 1. Purpose

MediaHub must provide a simple, reliable, and scalable macOS application for importing, organizing, and managing large photo and video libraries.

MediaHub must replace Photos.app and Image Capture for users who require:
- Transparent, file-based storage that remains usable outside the application
- Structural robustness and scalability for large or long-lived libraries
- Full interoperability with external tools (DigiKam, ON1, exiftool, Finder)
- A familiar, Photos.app-like user experience without proprietary container limitations

## 2. Intended Audience and Non-Audience

### Intended Audience

MediaHub must serve:
- macOS users already comfortable with Photos.app
- Users managing large or growing libraries
- People who require transparent backups, portability, and long-term access
- Users who integrate external editing and management tools into their workflow

### Non-Audience

MediaHub must not target:
- Cloud-first or mobile-only workflows
- Users seeking fully automatic "magic" organization without explicit control
- Users who prefer opaque, embedded, or vendor-locked storage models

## 3. Non-Negotiable Design Principles

### 3.1 Simplicity of User Experience

MediaHub must prioritize simplicity of user experience over internal simplicity. The core experience must feel no more complex than Photos.app.

### 3.2 Transparent Storage

MediaHub must store all media files as normal files in standard folder structures on disk. Files must remain directly accessible and usable without MediaHub at all times.

### 3.3 Safe Operations

MediaHub must not perform destructive actions without explicit user confirmation. All operations that modify or delete files must be reversible or clearly indicated.

### 3.4 Deterministic Behavior

MediaHub must produce deterministic results. The same inputs must produce the same outputs. Re-running pipelines or operations must be safe and idempotent.

### 3.5 Interoperability First

MediaHub must not break when external tools modify files. External tools must be able to read, write, and edit media files without corrupting MediaHub's organization or metadata.

### 3.6 Scalability by Design

MediaHub must support multiple libraries, large volumes, and long-term usage as first-class concerns. Performance and structure must not degrade as libraries grow.

## 4. Invariants

### 4.1 Data Safety

- MediaHub must never move or delete source files without explicit user consent
- MediaHub must preserve all original file data during import and organization
- MediaHub must maintain file integrity; corruption must be detectable and recoverable
- MediaHub must support transparent backup strategies; libraries must be backup-friendly

### 4.2 Determinism

- MediaHub must produce identical results when given identical inputs
- Pipeline operations must be idempotent; re-execution must not cause duplication or inconsistency
- MediaHub must maintain consistent state; the same library state must produce the same representation

### 4.3 Storage

- MediaHub must use standard file system structures; no proprietary containers or embedded databases
- MediaHub must organize files in predictable, human-readable folder hierarchies
- MediaHub must not require files to be locked or inaccessible to other applications
- MediaHub must support multiple libraries as independent, portable collections

## 5. Anti-Goals

MediaHub must not:

- Become an all-in-one embedded library system that locks files in proprietary containers
- Require cloud services or online connectivity for core functionality
- Automatically organize or modify files without explicit user direction
- Prioritize internal architectural elegance over user experience simplicity
- Create dependencies that prevent files from being used outside MediaHub
- Implement opaque or "magic" behaviors that users cannot understand or control
- Lock users into MediaHub-specific workflows that cannot be replaced by external tools

## 6. Relationship to Future Specifications

### 6.1 Constitutional Authority

This Constitution is the supreme normative document for MediaHub. All future specifications, designs, and implementations must conform to these principles and invariants.

### 6.2 Specification Constraints

Future specifications must:
- Adhere to all principles defined in Section 3
- Maintain all invariants defined in Section 4
- Avoid all anti-goals defined in Section 5
- Justify any design decisions that appear to conflict with this Constitution

### 6.3 Implementation Freedom

This Constitution constrains what MediaHub must be and must not be, but does not prescribe:
- Technical architecture or implementation details
- User interface design or interaction patterns
- Concrete pipeline implementations or algorithms
- Specific file organization schemes (beyond transparency and predictability)

### 6.4 Amendment Process

This Constitution may be amended only when:
- A proposed change addresses a fundamental gap or contradiction
- The change maintains alignment with MediaHub's core purpose
- The change does not violate existing principles or invariants without explicit justification

---

**Note:** Pipelines are a core concept of MediaHub, but their concrete implementation is intentionally left open to specification. All pipeline implementations must, however, conform to the principles and invariants defined herein.
