//
//  LibraryValidationTests.swift
//  MediaHubTests
//
//  Tests for library validation and error handling (P1)
//

import XCTest
@testable import MediaHub

final class LibraryValidationTests: XCTestCase {
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        // Create a temporary directory for each test
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MediaHubTests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
    }
    
    override func tearDown() {
        // Clean up temporary directory
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        super.tearDown()
    }
    
    // MARK: - Scenario 4: Corrupted/Missing Metadata Produces Clear Error
    
    func testOpenLibraryWithMissingMetadata() throws {
        // Given: A library directory exists but metadata is missing
        let libraryPath = tempDirectory.appendingPathComponent("TestLibrary").path
        let libraryRootURL = URL(fileURLWithPath: libraryPath)
        
        // Create library structure without metadata file
        try FileManager.default.createDirectory(
            at: libraryRootURL,
            withIntermediateDirectories: true
        )
        
        let metadataDirURL = libraryRootURL.appendingPathComponent(LibraryStructure.metadataDirectoryName)
        try FileManager.default.createDirectory(
            at: metadataDirURL,
            withIntermediateDirectories: true
        )
        
        // Metadata file is intentionally not created
        
        // When: A user attempts to open the library
        let opener = LibraryOpener()
        
        // Then: A clear, actionable error message is provided
        XCTAssertThrowsError(
            try opener.openLibrary(at: libraryPath),
            "Should throw error for missing metadata"
        ) { error in
            guard let openingError = error as? LibraryOpeningError else {
                XCTFail("Error should be LibraryOpeningError")
                return
            }
            
            // Verify error is clear and actionable
            switch openingError {
            case .metadataNotFound, .structureInvalid:
                break // Expected error types
            default:
                XCTFail("Error should indicate missing metadata, got: \(openingError)")
            }
            
            // Verify error message is clear
            let errorMessage = openingError.localizedDescription
            XCTAssertFalse(
                errorMessage.isEmpty,
                "Error message should not be empty"
            )
            
            // Verify error message is actionable (mentions metadata or structure)
            XCTAssertTrue(
                errorMessage.lowercased().contains("metadata") ||
                errorMessage.lowercased().contains("library.json") ||
                errorMessage.lowercased().contains("structure"),
                "Error message should mention metadata, library.json, or structure"
            )
        }
        
        // Verify validation detects missing metadata
        let validationResult = LibraryValidator.validate(at: libraryPath)
        guard case .invalid(let validationError) = validationResult else {
            XCTFail("Validation should detect missing metadata")
            return
        }
        
        // Verify validation error indicates missing metadata or invalid structure
        // (structure validation may fail first)
        switch validationError {
        case .metadataMissing, .structureInvalid:
            break // Expected error types
        default:
            XCTFail("Validation error should indicate missing metadata or invalid structure, got: \(validationError)")
        }
        
        // Verify error message generation is clear
        let errorMessage = LibraryValidationErrorMessageGenerator.generateMessage(for: validationError)
        XCTAssertFalse(
            errorMessage.isEmpty,
            "Error message should not be empty"
        )
        
        XCTAssertTrue(
            errorMessage.contains("metadata"),
            "Error message should mention metadata"
        )
    }
    
    func testOpenLibraryWithCorruptedMetadata() throws {
        // Given: A library with corrupted metadata file
        let libraryPath = tempDirectory.appendingPathComponent("TestLibrary").path
        let libraryRootURL = URL(fileURLWithPath: libraryPath)
        
        // Create library structure
        try FileManager.default.createDirectory(
            at: libraryRootURL,
            withIntermediateDirectories: true
        )
        
        let metadataDirURL = libraryRootURL.appendingPathComponent(LibraryStructure.metadataDirectoryName)
        try FileManager.default.createDirectory(
            at: metadataDirURL,
            withIntermediateDirectories: true
        )
        
        // Create corrupted metadata file (invalid JSON)
        let metadataFileURL = metadataDirURL.appendingPathComponent(LibraryStructure.metadataFileName)
        try "invalid json content {{{{".write(
            to: metadataFileURL,
            atomically: true,
            encoding: .utf8
        )
        
        // When: A user attempts to open the library
        let opener = LibraryOpener()
        
        // Then: A clear, actionable error message is provided
        XCTAssertThrowsError(
            try opener.openLibrary(at: libraryPath),
            "Should throw error for corrupted metadata"
        ) { error in
            guard let openingError = error as? LibraryOpeningError else {
                XCTFail("Error should be LibraryOpeningError")
                return
            }
            
            // Verify error is clear and actionable
            switch openingError {
            case .metadataCorrupted, .structureInvalid:
                break // Expected error types
            default:
                XCTFail("Error should indicate corrupted metadata, got: \(openingError)")
            }
            
            // Verify error message is clear
            let errorMessage = openingError.localizedDescription
            XCTAssertFalse(
                errorMessage.isEmpty,
                "Error message should not be empty"
            )
            
            // Verify error message mentions corruption
            XCTAssertTrue(
                errorMessage.lowercased().contains("corrupt") ||
                errorMessage.lowercased().contains("invalid"),
                "Error message should mention corruption or invalid data"
            )
        }
        
        // Verify validation detects corrupted metadata
        let validationResult = LibraryValidator.validate(at: libraryPath)
        guard case .invalid(let validationError) = validationResult else {
            XCTFail("Validation should detect corrupted metadata")
            return
        }
        
        // Verify error message generation is clear
        let errorMessage = LibraryValidationErrorMessageGenerator.generateMessage(for: validationError)
        XCTAssertFalse(
            errorMessage.isEmpty,
            "Error message should not be empty"
        )
        
        XCTAssertTrue(
            errorMessage.lowercased().contains("corrupt") ||
            errorMessage.lowercased().contains("invalid"),
            "Error message should mention corruption"
        )
    }
    
    func testValidateLibraryStructure() throws {
        // Given: A valid library
        let libraryPath = tempDirectory.appendingPathComponent("TestLibrary").path
        let creator = LibraryCreator()
        
        let createExpectation = XCTestExpectation(description: "Library creation")
        var createResult: Result<LibraryMetadata, LibraryCreationError>?
        
        creator.createLibrary(at: libraryPath) { result in
            createResult = result
            createExpectation.fulfill()
        }
        
        wait(for: [createExpectation], timeout: 5.0)
        
        guard case .success = createResult else {
            XCTFail("Library creation should succeed")
            return
        }
        
        // When: Validating library structure
        let validationResult = LibraryValidator.validate(at: libraryPath)
        
        // Then: Validation passes
        guard case .valid = validationResult else {
            XCTFail("Valid library should pass validation")
            return
        }
        
        // When: Removing required structure elements
        let libraryRootURL = URL(fileURLWithPath: libraryPath)
        let metadataFileURL = LibraryStructureCreator.metadataFileURL(for: libraryRootURL)
        try FileManager.default.removeItem(at: metadataFileURL)
        
        // Then: Validation fails with clear errors
        let invalidResult = LibraryValidator.validate(at: libraryPath)
        guard case .invalid(let validationError) = invalidResult else {
            XCTFail("Invalid library should fail validation")
            return
        }
        
        // Verify validation error indicates missing metadata or invalid structure
        // (structure validation may fail first)
        switch validationError {
        case .metadataMissing, .structureInvalid:
            break // Expected error types
        default:
            XCTFail("Validation error should indicate missing metadata or invalid structure, got: \(validationError)")
        }
        
        // Verify error message is clear
        let errorMessage = LibraryValidationErrorMessageGenerator.generateMessage(for: validationError)
        XCTAssertFalse(
            errorMessage.isEmpty,
            "Error message should not be empty"
        )
    }
    
    func testCorruptionDetection() throws {
        // Given: A library with various corruption scenarios
        let libraryPath = tempDirectory.appendingPathComponent("TestLibrary").path
        let libraryRootURL = URL(fileURLWithPath: libraryPath)
        
        // Create library structure
        try FileManager.default.createDirectory(
            at: libraryRootURL,
            withIntermediateDirectories: true
        )
        
        let metadataDirURL = libraryRootURL.appendingPathComponent(LibraryStructure.metadataDirectoryName)
        try FileManager.default.createDirectory(
            at: metadataDirURL,
            withIntermediateDirectories: true
        )
        
        // When: Detecting corruption
        let corruptionIssues = LibraryCorruptionDetector.detectCorruption(at: libraryPath)
        
        // Then: Corruption is detected
        XCTAssertFalse(
            corruptionIssues.isEmpty,
            "Corruption should be detected for library without metadata"
        )
        
        // Verify corruption detection identifies missing metadata
        let hasMetadataMissing = corruptionIssues.contains { error in
            switch error {
            case .metadataMissing:
                return true
            default:
                return false
            }
        }
        XCTAssertTrue(
            hasMetadataMissing,
            "Corruption detection should identify missing metadata"
        )
    }
    
    func testValidationWithInvalidUUID() throws {
        // Given: A library with invalid UUID in metadata
        let libraryPath = tempDirectory.appendingPathComponent("TestLibrary").path
        let libraryRootURL = URL(fileURLWithPath: libraryPath)
        
        // Create library structure
        try FileManager.default.createDirectory(
            at: libraryRootURL,
            withIntermediateDirectories: true
        )
        
        let metadataDirURL = libraryRootURL.appendingPathComponent(LibraryStructure.metadataDirectoryName)
        try FileManager.default.createDirectory(
            at: metadataDirURL,
            withIntermediateDirectories: true
        )
        
        // Create metadata with invalid UUID
        let invalidMetadata = LibraryMetadata(
            libraryId: "not-a-valid-uuid",
            rootPath: libraryPath
        )
        
        let metadataFileURL = metadataDirURL.appendingPathComponent(LibraryStructure.metadataFileName)
        try LibraryMetadataSerializer.write(invalidMetadata, to: metadataFileURL)
        
        // When: Validating library
        let validationResult = LibraryValidator.validate(at: libraryPath)
        
        // Then: Validation fails with clear error
        guard case .invalid(let validationError) = validationResult else {
            XCTFail("Validation should fail for invalid UUID")
            return
        }
        
        // Verify error mentions UUID or indicates validation failure
        let errorMessage = validationError.localizedDescription
        XCTAssertTrue(
            errorMessage.lowercased().contains("uuid") ||
            errorMessage.lowercased().contains("identifier") ||
            errorMessage.lowercased().contains("invalid") ||
            errorMessage.lowercased().contains("corrupt"),
            "Error message should mention UUID, identifier, invalid, or corrupt"
        )
    }
    
    func testValidationWithInvalidTimestamp() throws {
        // Given: A library with invalid timestamp in metadata
        let libraryPath = tempDirectory.appendingPathComponent("TestLibrary").path
        let libraryRootURL = URL(fileURLWithPath: libraryPath)
        
        // Create library structure
        try FileManager.default.createDirectory(
            at: libraryRootURL,
            withIntermediateDirectories: true
        )
        
        let metadataDirURL = libraryRootURL.appendingPathComponent(LibraryStructure.metadataDirectoryName)
        try FileManager.default.createDirectory(
            at: metadataDirURL,
            withIntermediateDirectories: true
        )
        
        // Create metadata JSON with invalid timestamp manually
        let invalidMetadataJSON = """
        {
            "version": "1.0",
            "libraryId": "\(LibraryIdentifierGenerator.generate())",
            "createdAt": "not-a-valid-timestamp",
            "libraryVersion": "1.0",
            "rootPath": "\(libraryPath)"
        }
        """
        
        let metadataFileURL = metadataDirURL.appendingPathComponent(LibraryStructure.metadataFileName)
        try invalidMetadataJSON.write(
            to: metadataFileURL,
            atomically: true,
            encoding: .utf8
        )
        
        // When: Validating library
        let validationResult = LibraryValidator.validate(at: libraryPath)
        
        // Then: Validation fails with clear error
        guard case .invalid(let validationError) = validationResult else {
            XCTFail("Validation should fail for invalid timestamp")
            return
        }
        
        // Verify error mentions timestamp or indicates validation failure
        let errorMessage = validationError.localizedDescription
        XCTAssertTrue(
            errorMessage.lowercased().contains("timestamp") ||
            errorMessage.lowercased().contains("date") ||
            errorMessage.lowercased().contains("invalid") ||
            errorMessage.lowercased().contains("corrupt") ||
            errorMessage.lowercased().contains("decode"),
            "Error message should mention timestamp, date, invalid, corrupt, or decode"
        )
    }
}
