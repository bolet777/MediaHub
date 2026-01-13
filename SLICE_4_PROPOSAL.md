# Slice 4 Proposal: Codebase-Informed Audit & Recommendation

**Date**: 2026-01-13  
**Status**: Proposal  
**Context**: Slices 1-3 complete, validated, and frozen

---

## 1. Current Capability Map

### What MediaHub Can Do Today (End-to-End User Workflow)

**As a Developer/Technical User:**
1. ✅ Create a new MediaHub library at a specified path
2. ✅ Open an existing library by path or identifier
3. ✅ Attach folder-based Sources to a library (persistent associations)
4. ✅ Run detection on a Source to find new media items
5. ✅ View detection results (new vs. known items, with explanations)
6. ✅ Import selected candidate items from detection results
7. ✅ Files are copied (not moved) to library in YYYY/MM organization
8. ✅ Collision handling (rename/skip/error policies)
9. ✅ Imported items are tracked to prevent re-imports
10. ✅ View import results (JSON audit trail)

**What Works Well:**
- Complete import pipeline: Source → Detection → Import → Organization
- Deterministic behavior (same inputs → same outputs)
- Safe operations (atomic copies, no source modification)
- Transparent storage (standard filesystem, JSON metadata)
- Robust error handling and validation
- 100+ tests covering all components

### What Is Missing to Be "Usable" by a Non-Developer

**Critical Gaps:**
1. ❌ **No User Interface** — All operations require programmatic API calls
2. ❌ **No Entry Point** — No executable, CLI, or app bundle
3. ❌ **No User Feedback** — No progress indicators, status updates, or error dialogs
4. ❌ **No Library Management UI** — Cannot browse libraries, sources, or import history visually
5. ❌ **No Import Workflow UI** — Cannot select items, preview, or configure import options interactively
6. ❌ **No Results Visualization** — Import/detection results only available as JSON files

**Usability Blockers:**
- A non-developer cannot use MediaHub without writing Swift code
- No way to discover or open libraries without knowing exact paths
- No visual feedback during long-running operations (detection, import)
- No error recovery guidance for common issues (permissions, disk space, etc.)

**What Would Make It "Usable":**
- Minimal UI to create/open libraries
- UI to attach sources and run detection
- UI to review detection results and select items for import
- Progress feedback during operations
- Error messages in user-friendly format
- Basic library/source browsing

---

## 2. Engineering Readiness Assessment

### Robust Components ✅

**Well-Architected & Tested:**
- **Library Identity & Metadata**: UUID-based identity, JSON persistence, validation — solid foundation
- **Source Management**: Clean separation, persistent associations, validation — production-ready
- **Detection Pipeline**: Deterministic, explainable results, graceful error handling — reliable
- **Import Execution**: Atomic operations, collision handling, known-items tracking — safe and tested
- **Error Handling**: Comprehensive error types with localized descriptions — good UX foundation

**Strengths:**
- Clean separation of concerns (Library, Source, Import domains)
- Protocol-based design enables testing and future extensibility
- Deterministic behavior enforced by tests
- Transparent storage model (JSON, standard filesystem)
- No technical debt markers (no TODOs, FIXMEs, or HACKs found)

### Risky/Fragile Areas ⚠️

**Performance Concerns:**
1. **Sequential Processing**: Import processes items one-by-one (line 86 in `ImportExecution.swift`)
   - **Risk**: Slow for large imports (1000+ items)
   - **Impact**: Acceptable for P1, but will be noticeable to users
   - **Mitigation**: Already documented as acceptable for P1; can be optimized later

2. **Full Library Scanning**: `LibraryContentQuery.scanLibraryContents()` scans entire library on each detection
   - **Risk**: O(n) scan time grows with library size (100k+ files)
   - **Impact**: Detection may be slow for large libraries
   - **Mitigation**: ADR 006 notes this as acceptable for P1; index can be added later

3. **No Caching/Indexing**: No persistent index of library contents or known items
   - **Risk**: Repeated scans of same data
   - **Impact**: Performance degrades as library grows
   - **Mitigation**: Acceptable for P1; optimization deferred

**Edge Cases & Graceful Degradation:**
1. **Known Items Tracking Failures**: If known-items query fails, detection treats as empty set (line 82-85 in `DetectionOrchestration.swift`)
   - **Risk**: May re-detect already imported items
   - **Impact**: Low (graceful degradation, but may confuse users)
   - **Status**: Documented as acceptable for P1

2. **Stale Known Items**: Manual file deletion leaves stale entries (no auto-cleanup)
   - **Risk**: Detection may incorrectly exclude deleted items
   - **Impact**: Low (P1 limitation, can be addressed later)
   - **Status**: Documented in ADR 013

3. **Source Path Changes**: No automatic detection of moved/renamed sources
   - **Risk**: Sources become "inaccessible" after moves
   - **Impact**: Medium (user must re-attach)
   - **Status**: P2 feature, acceptable for now

**API Surface:**
- **Public APIs are well-defined** but **not yet packaged for consumption**
- No executable target, no CLI, no app bundle
- APIs are library-only (Swift Package)

### Tech Debt Assessment

**No Critical Tech Debt Found:**
- ✅ No TODOs, FIXMEs, or HACKs in source code
- ✅ All P1 requirements implemented
- ✅ Tests cover core functionality
- ✅ Error handling is comprehensive
- ✅ Code follows Swift best practices

**Acceptable Deferred Work (P2):**
- Performance optimizations (parallel processing, indexing)
- Advanced duplicate detection (hashing, fuzzy matching)
- Source path change detection
- Known-items reconciliation
- Resume capability for interrupted operations

**Foundation Quality:**
- The codebase is **ready to build on top of**
- Core operations are safe, tested, and deterministic
- Architecture supports extension without breaking changes
- No refactoring needed before adding UI or CLI

---

## 3. Slice 4 Candidate Options

### Option A: Minimal UI Enablement (SwiftUI App)

**Goal**: Enable non-developers to use MediaHub through a basic macOS app.

**User Value:**
- Create/open libraries without writing code
- Attach sources and run detection with visual feedback
- Review detection results and select items for import
- View import progress and results
- Basic library/source management

**Leverages Current Code:**
- All existing APIs (LibraryCreation, LibraryOpening, DetectionOrchestration, ImportExecution)
- Error types with localized descriptions (ready for UI display)
- DetectionResult and ImportResult models (ready for UI binding)
- JSON persistence (no changes needed)

**New Components Required:**
- SwiftUI app target (macOS app)
- Library management views (create, open, list)
- Source management views (attach, list, status)
- Detection workflow views (run, progress, results)
- Import workflow views (select items, configure options, progress)
- Results/history views (import history, detection history)
- Error presentation layer (convert errors to user-friendly messages)

**Risks / Hidden Scope:**
- **SwiftUI Learning Curve**: If team is new to SwiftUI, may add complexity
- **State Management**: Need to manage library state, source state, detection/import state
- **Async Operations**: Detection and import are long-running; need proper async/await integration
- **Error Recovery UX**: Need to design error recovery flows (permissions, disk space, etc.)
- **Testing UI**: UI testing adds complexity; may need to maintain testability of core logic
- **App Sandboxing**: macOS app sandboxing may require permission handling for file access

**Test/Validation Strategy:**
- Unit tests for view models/state management
- Integration tests for UI → API interactions
- Manual acceptance testing for user workflows
- Test with real libraries and sources

**Estimated Complexity**: **L** (Large)
- Significant UI work (6-8 major views)
- State management complexity
- Async operation handling
- Error handling UX
- App packaging and distribution

---

### Option B: CLI Tool + Packaging

**Goal**: Provide a command-line interface for MediaHub operations, packaged as an executable.

**User Value:**
- Use MediaHub from terminal without writing Swift code
- Scriptable operations (automation-friendly)
- Clear command structure and help text
- Progress feedback and error messages
- Suitable for power users and automation

**Leverages Current Code:**
- All existing APIs (same as Option A)
- Error types (can be formatted for CLI output)
- Result models (can be serialized to JSON/table format)
- Deterministic behavior (perfect for CLI)

**New Components Required:**
- Executable target (command-line tool)
- CLI argument parsing (Swift Argument Parser)
- Command structure (create, open, attach, detect, import, list, status)
- Output formatting (JSON, table, human-readable)
- Progress indicators (for long-running operations)
- Help/documentation system

**Risks / Hidden Scope:**
- **Output Formatting**: Need to design readable output for complex data (detection results, import results)
- **Progress Feedback**: CLI progress indicators for async operations
- **Error Messages**: CLI-friendly error formatting
- **Command Discovery**: Help system and command structure design
- **Scripting Support**: May need to support non-interactive mode for scripts

**Test/Validation Strategy:**
- Unit tests for CLI parsing and formatting
- Integration tests for end-to-end CLI workflows
- Manual testing with real libraries
- Test scriptability (non-interactive mode)

**Estimated Complexity**: **M** (Medium)
- CLI is simpler than UI but still requires:
  - Command structure design
  - Output formatting
  - Progress handling
  - Help system

---

### Option C: Pipelines/Automation Layer

**Goal**: Add a pipeline/automation system for scheduled or triggered import workflows.

**User Value:**
- Automate detection and import workflows
- Schedule periodic imports from sources
- Trigger imports on source changes (file system events)
- Define reusable import configurations
- Background processing

**Leverages Current Code:**
- DetectionOrchestration and ImportExecution (core operations)
- Source associations (persistent source definitions)
- Known-items tracking (prevents duplicates in automation)

**New Components Required:**
- Pipeline definition model (source → detection → import configuration)
- Pipeline execution engine (orchestrates detection + import)
- Scheduling system (timer-based or event-based triggers)
- File system monitoring (watch sources for changes)
- Pipeline persistence (save/load pipeline configurations)
- Pipeline status/history tracking

**Risks / Hidden Scope:**
- **File System Monitoring**: macOS file system event APIs (FSEvents) complexity
- **Background Processing**: App lifecycle, background execution permissions
- **Error Handling in Automation**: How to handle errors without user interaction
- **Resource Management**: Multiple pipelines, concurrent execution
- **State Management**: Pipeline state, execution state, error recovery
- **Testing Automation**: Testing time-based and event-based triggers

**Test/Validation Strategy:**
- Unit tests for pipeline execution
- Integration tests for scheduled workflows
- Test file system event handling
- Test error recovery in automation context

**Estimated Complexity**: **L** (Large)
- Significant new domain (pipeline/automation)
- File system monitoring complexity
- Background processing requirements
- State management for automation

---

### Option D: Performance/Indexing Improvements

**Goal**: Optimize performance for large libraries and add indexing to speed up detection.

**User Value:**
- Faster detection on large libraries (100k+ files)
- Faster import operations (parallel processing)
- Better scalability as libraries grow
- Reduced resource usage

**Leverages Current Code:**
- Existing APIs (can be optimized without breaking changes)
- Library structure (can add index files to `.mediahub/`)
- Known-items tracking (can be optimized)

**New Components Required:**
- Library content index (persistent index of library files)
- Index building/updating logic (incremental updates)
- Parallel import processing (concurrent file copying)
- Index query API (replace full library scan)
- Index maintenance (rebuild, validate, repair)

**Risks / Hidden Scope:**
- **Index Consistency**: Keeping index in sync with actual library contents
- **Index Corruption**: Handling corrupted or stale indexes
- **Migration**: Migrating existing libraries to use indexes
- **Parallel Processing Safety**: Ensuring determinism with parallel operations
- **Performance Testing**: Need large test libraries to validate improvements

**Test/Validation Strategy:**
- Performance benchmarks (before/after)
- Index consistency tests
- Migration tests (existing libraries)
- Large library stress tests

**Estimated Complexity**: **M-L** (Medium to Large)
- Indexing adds complexity but is well-scoped
- Parallel processing requires careful design
- Migration path for existing libraries

---

### Option E: Photos.app Investigation Spike (No Commitment)

**Goal**: Research and prototype integration with Photos.app or device import workflows.

**User Value:**
- Understand feasibility of importing from Photos.app libraries
- Understand feasibility of direct device import (iPhone, camera)
- Inform future slice decisions
- No production commitment

**Leverages Current Code:**
- ImportExecution (can import from any source once files are accessible)
- Source model (can extend to Photos.app or device sources)

**New Components Required:**
- Research into Photos.app library structure and APIs
- Research into device import APIs (Image Capture, PhotoKit)
- Prototype source adapter for Photos.app
- Prototype device import workflow
- Documentation of findings and recommendations

**Risks / Hidden Scope:**
- **API Limitations**: Photos.app may not expose needed APIs
- **Sandboxing**: macOS app sandboxing may restrict access
- **Device Access**: Device import may require special permissions or workflows
- **No Deliverable**: This is research only, no production feature

**Test/Validation Strategy:**
- Prototype validation (proof of concept)
- API exploration and documentation
- Feasibility assessment

**Estimated Complexity**: **S-M** (Small to Medium)
- Research and prototyping
- No production commitment
- Can be time-boxed

---

## 4. Recommended Slice 4: Option B — CLI Tool + Packaging

### Why CLI Tool is the Best Next Step

**1. Lowest Risk, Highest Value**
- CLI is simpler than UI but provides immediate usability
- Enables non-developers to use MediaHub without writing code
- Scriptable operations enable automation and future pipeline work
- Minimal new domain knowledge required (just CLI design)

**2. Leverages Existing Strengths**
- Current APIs are well-suited for CLI (synchronous operations, clear error types)
- Deterministic behavior is perfect for CLI (predictable output)
- JSON result models can be easily formatted for CLI output
- Error handling is already comprehensive (just needs formatting)

**3. Foundation for Future Slices**
- CLI can be used to test and validate future features
- CLI output can inform UI design (what information users need)
- CLI commands can be wrapped by automation/pipelines later
- CLI provides a stable API surface for future UI to build on

**4. Aligns with Project Goals**
- Filesystem-first approach fits CLI workflow
- Transparent operations (CLI shows exactly what's happening)
- Interoperability (CLI can be integrated into other tools)
- No UI complexity to maintain yet

**5. Addresses Critical Gap**
- Current gap: "No Entry Point" — CLI solves this immediately
- Enables real-world usage and feedback
- Validates core workflows with actual users

### Proposed Slice 4 Scope

**P1 (Must Have):**
1. **Executable Target**: Swift Package executable target
2. **Core Commands**:
   - `mediahub library create <path>` — Create new library
   - `mediahub library open <path>` — Open library (set active)
   - `mediahub library list` — List known libraries
   - `mediahub source attach <path>` — Attach source to active library
   - `mediahub source list` — List sources for active library
   - `mediahub detect <source-id>` — Run detection on source
   - `mediahub import <source-id> [--items <paths>]` — Import items from detection
   - `mediahub status` — Show active library and status
3. **Output Formatting**: Human-readable output with JSON option (`--json`)
4. **Progress Feedback**: Progress indicators for detection and import
5. **Error Handling**: User-friendly error messages
6. **Help System**: `--help` for all commands

**P2 (Nice to Have, Defer if Needed):**
- `mediahub import --all` — Import all new items from detection
- `mediahub history` — Show import/detection history
- `mediahub config` — Configure default options (collision policy, etc.)
- Interactive mode for item selection
- Colored output and better formatting

**Out of Scope:**
- Full UI (defer to future slice)
- Pipelines/automation (can build on CLI later)
- Performance optimizations (acceptable for now)
- Photos.app integration (defer to future slice)

**Success Criteria:**
- Non-developer can use MediaHub via CLI without writing code
- All core workflows accessible via CLI
- CLI output is clear and actionable
- CLI is scriptable (non-interactive mode)

---

## 5. Spec-Kit Readiness

### Suggested `/speckit.specify` Prompt Starter

```
Specify Slice 4: CLI Tool + Packaging for MediaHub

Context:
- MediaHub Slices 1-3 are complete, validated, and frozen
- Core functionality exists: library management, source attachment, detection, import
- All operations work via Swift Package APIs but require programmatic access
- Goal: Enable non-developers to use MediaHub via command-line interface

Requirements:
1. Create a Swift Package executable target for MediaHub CLI
2. Design command structure for all core operations:
   - Library management (create, open, list)
   - Source management (attach, list)
   - Detection (run detection on source)
   - Import (import selected items from detection)
   - Status/info commands
3. Implement CLI argument parsing (use Swift Argument Parser)
4. Format output for human readability (with --json option for scripting)
5. Add progress indicators for long-running operations (detection, import)
6. Format errors for CLI (user-friendly messages)
7. Implement help system (--help for all commands)

Constraints:
- Must use existing MediaHub APIs (no changes to core logic)
- Must maintain deterministic behavior
- Must support non-interactive mode (scriptable)
- Must follow MediaHub Constitution (transparent, safe, deterministic)
- P1 scope only (P2 features can be documented but deferred)

Success Criteria:
- Non-developer can use MediaHub via CLI without writing code
- All core workflows accessible via CLI
- CLI output is clear and actionable
- CLI is scriptable (non-interactive mode)

Deliverables:
- Executable target in Package.swift
- CLI command implementations
- Output formatting utilities
- Progress indicator utilities
- Help/documentation
- Unit tests for CLI parsing and formatting
- Integration tests for CLI workflows
- Validation document

Reference:
- Existing APIs: LibraryCreation, LibraryOpening, DetectionOrchestration, ImportExecution
- Error types: All error enums have localized descriptions
- Result models: DetectionResult, ImportResult (JSON-serializable)
- Constitution: docs/CONSTITUTION.md
- Existing slices: specs/001-*, specs/002-*, specs/003-*
```

---

## Appendix: Quick Reference

### Current API Surface (Ready for CLI)

**Library Operations:**
- `LibraryCreator.createLibrary(...)` — Create library
- `LibraryOpener.openLibrary(...)` — Open library
- `LibraryDiscovery.discoverLibraries(...)` — Discover libraries

**Source Operations:**
- `SourceAssociator.attachSource(...)` — Attach source
- `SourceAssociationReader.read(...)` — Read sources

**Detection Operations:**
- `DetectionOrchestrator.executeDetection(...)` — Run detection
- Returns `DetectionResult` with candidates and summary

**Import Operations:**
- `ImportExecutor.executeImport(...)` — Execute import
- Returns `ImportResult` with imported/skipped/failed items

**All operations throw typed errors with localized descriptions.**

---

**End of Proposal**
