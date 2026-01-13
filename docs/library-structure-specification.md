# Library Root Structure Specification

**Component**: Library Root Structure  
**Tasks**: 2.1, 2.2, 2.3  
**Status**: Accepted

## Minimum Library Structure

A MediaHub library is identified by the presence of the following structure:

```
LibraryRoot/
├── .mediahub/
│   └── library.json
```

### Required Elements

1. **`.mediahub/` directory**: Hidden directory containing library metadata
   - Must exist at the root of the library
   - Contains library metadata files
   - Hidden to keep metadata separate from user content

2. **`library.json` file**: Library metadata file
   - Must exist at `.mediahub/library.json`
   - Contains library identity and metadata
   - JSON format (see ADR 001)

### Minimum Identification Requirements

A directory is considered a valid MediaHub library if:
- The `.mediahub/` directory exists
- The `.mediahub/library.json` file exists
- The `library.json` file contains valid metadata (see LibraryMetadata structure)

## Metadata Directory Naming Convention

**Decision**: Use `.mediahub/` (hidden directory)

**Rationale**:
- Hidden directory keeps metadata separate from user content
- Follows common pattern of hidden configuration directories (`.git/`, `.vscode/`, etc.)
- Clear naming indicates MediaHub ownership
- Prevents accidental user modification
- Still accessible via Finder (show hidden files) or command line

**Alternatives Considered**:
- `Library/` - Rejected: Could be confused with user content
- `.library/` - Rejected: Too generic, could conflict with system directories
- `MediaHub/` - Rejected: Visible directory clutters root

## Future-Compatible Structure Rules

### Extension Rules

To ensure future additions don't break library identification:

1. **Required Elements Never Change**
   - `.mediahub/library.json` must always exist
   - Location and name of metadata file must remain constant

2. **New Directories/Files**
   - New directories may be added at the root level
   - New files may be added to `.mediahub/` directory
   - New files may be added at the root level
   - **Rule**: Only `.mediahub/library.json` is required for identification

3. **Structure Validation**
   - Validation checks for required elements only
   - Additional elements are ignored (forward compatibility)
   - Missing optional elements do not invalidate a library

4. **Versioning**
   - Metadata format versioning (in `library.json`) handles schema evolution
   - Structure changes are additive only (never remove required elements)

### Example Future Extensions

Future versions may add:
- `.mediahub/config.json` - Library configuration
- `Media/` - Media files directory
- `Metadata/` - Additional metadata storage
- `.mediahub/cache/` - Cache directory

All of these are optional and don't affect library identification.

## Legacy Library Support

Libraries created by prior versions (e.g., MediaVault) may have different structures. Detection and adoption logic (Component 5) handles these cases.

## Validation

This specification addresses:
- ✅ FR-002: Store library metadata that makes library identifiable
- ✅ FR-011: Define a minimal, standard, and future-compatible library folder structure
- ✅ FR-005a: Support attaching to existing libraries without re-import
