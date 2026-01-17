import SwiftUI

struct AdoptLibraryWizard: View {
    @StateObject private var state = AdoptWizardState()
    @Environment(\.dismiss) private var dismiss
    let onCompletion: ((String) -> Void)?
    
    init(onCompletion: ((String) -> Void)? = nil) {
        self.onCompletion = onCompletion
    }
    
    var body: some View {
        VStack(spacing: 20) {
            switch state.currentStep {
            case .pathSelection:
                WizardPathSelectionView(
                    selectedPath: $state.selectedPath,
                    errorMessage: $state.errorMessage,
                    isForAdopt: true
                )
            case .preview:
                WizardPreviewView(
                    createPreviewResult: nil,
                    adoptPreviewResult: state.previewResult,
                    isForAdopt: true,
                    isLoading: false,
                    errorMessage: state.errorMessage
                )
            case .confirmation:
                WizardConfirmationView(
                    createPreviewResult: nil,
                    adoptPreviewResult: state.previewResult,
                    isForAdopt: true,
                    isExecuting: state.isExecuting,
                    onConfirm: {
                        executeAdopt()
                    },
                    onCancel: {
                        cancelWizard()
                    }
                )
            case .executing:
                VStack {
                    ProgressView("Adopting library...")
                    if let errorMessage = state.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding()
                    }
                }
            }
            
            Spacer()
            
            // Navigation buttons
            HStack {
                if state.currentStep != .pathSelection {
                    Button("Back") {
                        navigateBack()
                    }
                }
                
                Spacer()
                
                if state.currentStep != .executing {
                    Button("Next") {
                        navigateNext()
                    }
                    .disabled(!canNavigateNext)
                }
            }
            .padding()
        }
        .frame(width: 500, height: 400)
        .padding()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    cancelWizard()
                }
            }
        }
    }
    
    private var canNavigateNext: Bool {
        switch state.currentStep {
        case .pathSelection:
            if let path = state.selectedPath {
                let validation = WizardPathValidator.validatePath(path, isForAdopt: true)
                if case .valid = validation {
                    return true
                }
                if case .alreadyAdopted = validation {
                    return true
                }
            }
            return false
        case .preview:
            return state.previewResult != nil
        case .confirmation:
            return true
        case .executing:
            return false
        }
    }
    
    private func navigateNext() {
        switch state.currentStep {
        case .pathSelection:
            if let path = state.selectedPath {
                let validation = WizardPathValidator.validatePath(path, isForAdopt: true)
                switch validation {
                case .valid, .alreadyAdopted:
                    // For adopt, already-adopted is OK (idempotent)
                    state.errorMessage = nil
                    state.currentStep = .preview
                    generatePreview()
                case .invalid(let message):
                    state.errorMessage = message
                }
            }
        case .preview:
            if state.previewResult != nil {
                state.currentStep = .confirmation
            }
        case .confirmation:
            executeAdopt()
        case .executing:
            break
        }
    }
    
    private func navigateBack() {
        switch state.currentStep {
        case .preview:
            state.currentStep = .pathSelection
            state.previewResult = nil
            // Clear error message when navigating back
            if state.selectedPath != nil {
                let validation = WizardPathValidator.validatePath(state.selectedPath!, isForAdopt: true)
                if case .invalid(let message) = validation {
                    state.errorMessage = message
                } else {
                    state.errorMessage = nil
                }
            }
        case .confirmation:
            state.currentStep = .preview
        case .executing:
            break
        case .pathSelection:
            break
        }
    }
    
    private func cancelWizard() {
        // Reset state
        state.currentStep = .pathSelection
        state.selectedPath = nil
        state.previewResult = nil
        state.isExecuting = false
        state.errorMessage = nil
        // Dismiss sheet
        dismiss()
    }
    
    private func generatePreview() {
        guard let path = state.selectedPath else {
            state.errorMessage = "No path selected"
            return
        }
        
        Task {
            do {
                let previewResult = try await AdoptPreviewOrchestrator.generatePreview(at: path)
                await MainActor.run {
                    state.previewResult = previewResult
                    state.errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    state.errorMessage = "Failed to generate preview: \(error.localizedDescription)"
                    state.previewResult = nil
                }
            }
        }
    }
    
    private func executeAdopt() {
        guard let path = state.selectedPath else {
            state.errorMessage = "No path selected"
            return
        }
        
        state.currentStep = .executing
        state.isExecuting = true
        state.errorMessage = nil
        
        Task {
            do {
                let result = try await AdoptExecutionOrchestrator.executeAdopt(at: path)
                
                await MainActor.run {
                    // Handle idempotent already-adopted case
                    if result.indexSkippedReason == "already_adopted" {
                        // Show idempotent message (not error), close wizard, open library
                        dismiss()
                        onCompletion?(path)
                        // Reset state
                        state.currentStep = .pathSelection
                        state.selectedPath = nil
                        state.previewResult = nil
                        state.isExecuting = false
                        state.errorMessage = nil
                    } else {
                        // Normal success case
                        dismiss()
                        onCompletion?(path)
                        // Reset state
                        state.currentStep = .pathSelection
                        state.selectedPath = nil
                        state.previewResult = nil
                        state.isExecuting = false
                        state.errorMessage = nil
                    }
                }
            } catch {
                await MainActor.run {
                    state.errorMessage = error.localizedDescription
                    state.currentStep = .confirmation
                    state.isExecuting = false
                }
            }
        }
    }
}
