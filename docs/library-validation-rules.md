# Library Validation Rules

**Component**: Library Validation & Integrity  
**Task**: 7.1  
**Status**: Accepted

## Validation Overview

MediaHub validates library integrity when opening libraries to ensure:
- Libraries are valid and usable
- Corruption is detected early
- Users receive clear error messages
- Invalid libraries are rejected with actionable feedback

## Validation Rules

### Required Validation Checks

A valid MediaHub library must pass all of the following checks:

#### 1. Structure Validation

**Check**: Library root structure is valid

**Requirements**:
- Library root directory exists and is accessible
- `.mediahub/` directory exists
- `.mediahub/library.json` file exists

**Failure**: `LibraryStructureError.structureInvalid`

#### 2. Metadata File Validation

**Check**: Metadata file is present and readable

**Requirements**:
- Metadata file exists at `.mediahub/library.json`
- File is readable (permissions allow read access)
- File is not empty

**Failure**: `LibraryOpeningError.metadataNotFound` or `LibraryOpeningError.permissionDenied`

#### 3. Metadata Content Validation

**Check**: Metadata content is valid

**Requirements**:
- JSON is valid and parseable
- All required fields are present:
  - `version` (metadata format version)
  - `libraryId` (UUID v4 format)
  - `createdAt` (ISO-8601 timestamp)
  - `libraryVersion` (MediaHub library version)
  - `rootPath` (absolute path)
- UUID format is valid
- Timestamp format is valid
- Path is absolute

**Failure**: `LibraryOpeningError.metadataCorrupted`

#### 4. Metadata Consistency Validation

**Check**: Metadata is internally consistent

**Requirements**:
- `libraryId` matches UUID v4 format
- `createdAt` is a valid ISO-8601 timestamp
- `rootPath` matches actual library location (or is stale but identifier matches)

**Failure**: `LibraryOpeningError.metadataCorrupted`

#### 5. Permission Validation

**Check**: Library directory has required permissions

**Requirements**:
- Library root directory is readable
- Metadata directory is readable
- Metadata file is readable

**Failure**: `LibraryOpeningError.permissionDenied`

### Optional Validation Checks

These checks provide additional validation but don't block library opening:

#### 6. Path Consistency (Warning)

**Check**: Metadata `rootPath` matches actual library location

**Note**: Path may be stale after moves - this is acceptable as long as identifier matches

**Warning**: Path mismatch detected (library may have been moved)

#### 7. Version Compatibility (Warning)

**Check**: Metadata format version is supported

**Note**: Future versions may add version checks

**Warning**: Unsupported metadata format version

## Validation Strictness

### Strict Validation (Default)

- All required checks must pass
- Invalid libraries are rejected
- Clear error messages provided
- No auto-repair (user intervention required)

### Lenient Validation (Future)

- Some checks may be warnings instead of errors
- Auto-repair for minor issues (future enhancement)
- Graceful degradation for non-critical problems

## Corruption Detection

### Corruption Scenarios

1. **Missing Metadata File**
   - Detection: File doesn't exist
   - Handling: Reject with clear error

2. **Corrupted JSON**
   - Detection: JSON parsing fails
   - Handling: Reject with parsing error details

3. **Invalid UUID**
   - Detection: `libraryId` doesn't match UUID format
   - Handling: Reject with invalid identifier error

4. **Invalid Timestamp**
   - Detection: `createdAt` doesn't match ISO-8601 format
   - Handling: Reject with invalid timestamp error

5. **Missing Required Fields**
   - Detection: Required field is missing or empty
   - Handling: Reject with missing field error

6. **Permission Issues**
   - Detection: File system permission errors
   - Handling: Reject with permission denied error

7. **Structure Mismatch**
   - Detection: Required directories/files missing
   - Handling: Reject with structure invalid error

## Error Message Generation

### Error Message Requirements

- **Clear**: User understands what went wrong
- **Actionable**: User knows what to do next
- **Specific**: Identifies the exact problem
- **Non-technical**: Avoids implementation details where possible

### Error Message Format

```
[Error Type]: [Specific Problem]

[What this means]

[What you can do]
```

### Example Error Messages

**Missing Metadata**:
```
Library metadata not found

The library at "/path/to/library" is missing its metadata file (.mediahub/library.json).

This library may be corrupted or incomplete. You may need to recreate the library or restore from backup.
```

**Corrupted Metadata**:
```
Library metadata is corrupted

The library metadata file could not be read or parsed.

The metadata file may be damaged. You may need to restore from backup or recreate the library.
```

**Invalid Structure**:
```
Library structure is invalid

The library is missing required directories or files.

This library may be corrupted. You may need to restore from backup or recreate the library.
```

## Validation Integration

### When Validation Occurs

- **Library Opening**: Full validation before opening
- **Library Creation**: Structure validation after creation
- **Library Discovery**: Lightweight validation (structure only)

### Validation Order

1. Structure validation (fast, fails early)
2. Metadata file validation
3. Metadata content validation
4. Permission validation
5. Consistency validation

## Validation

This specification addresses:
- ✅ FR-008: Validate library integrity when opening
- ✅ FR-002: Ensure library is identifiable as MediaHub library
- ✅ Edge cases: corrupted metadata, missing files, invalid permissions
