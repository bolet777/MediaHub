import SwiftUI

struct CreateLibraryWizard: View {
    @StateObject private var state = CreateWizardState()
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
                    isForAdopt: false
                )
            case .preview:
                WizardPreviewView(
                    createPreviewResult: state.previewResult,
                    adoptPreviewResult: nil,
                    isForAdopt: false,
                    isLoading: false,
                    errorMessage: state.errorMessage
                )
            case .confirmation:
                WizardConfirmationView(
                    createPreviewResult: state.previewResult,
                    adoptPreviewResult: nil,
                    isForAdopt: false,
                    isExecuting: state.isExecuting,
                    onConfirm: {
                        executeCreate()
                    },
                    onCancel: {
                        cancelWizard()
                    }
                )
            case .executing:
                VStack {
                    ProgressView("Creating library...")
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
                let validation = WizardPathValidator.validatePath(path, isForAdopt: false)
                if case .valid = validation {
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
                let validation = WizardPathValidator.validatePath(path, isForAdopt: false)
                switch validation {
                case .valid:
                    state.errorMessage = nil
                    state.currentStep = .preview
                    generatePreview()
                case .invalid(let message):
                    state.errorMessage = message
                case .alreadyAdopted:
                    state.errorMessage = "This location already contains a MediaHub library"
                }
            }
        case .preview:
            if state.previewResult != nil {
                state.currentStep = .confirmation
            }
        case .confirmation:
            executeCreate()
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
                let validation = WizardPathValidator.validatePath(state.selectedPath!, isForAdopt: false)
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
        
        if let previewResult = CreatePreviewSimulator.simulatePreview(at: path) {
            state.previewResult = previewResult
            state.errorMessage = nil
        } else {
            state.errorMessage = "Failed to generate preview. Please check the path."
            state.previewResult = nil
        }
    }
    
    private func executeCreate() {
        guard let path = state.selectedPath else {
            state.errorMessage = "No path selected"
            return
        }
        
        state.currentStep = .executing
        state.isExecuting = true
        state.errorMessage = nil
        
        CreateExecutionOrchestrator.executeCreate(at: path) { result in
            Task { @MainActor in
                switch result {
                case .success(_):
                    // Close wizard
                    dismiss()
                    // Open newly created library
                    onCompletion?(path)
                    // Reset state
                    state.currentStep = .pathSelection
                    state.selectedPath = nil
                    state.previewResult = nil
                    state.isExecuting = false
                    state.errorMessage = nil
                case .failure(let error):
                    state.errorMessage = error.localizedDescription
                    state.currentStep = .confirmation
                    state.isExecuting = false
                }
            }
        }
    }
}

// Placeholder views for each step
struct PathSelectionPlaceholderView: View {
    var body: some View {
        Text("Path Selection (Placeholder)")
            .foregroundColor(.secondary)
    }
}

struct PreviewPlaceholderView: View {
    var body: some View {
        Text("Preview (Placeholder)")
            .foregroundColor(.secondary)
    }
}

struct ConfirmationPlaceholderView: View {
    var body: some View {
        Text("Confirmation (Placeholder)")
            .foregroundColor(.secondary)
    }
}

struct ExecutingPlaceholderView: View {
    var body: some View {
        Text("Executing (Placeholder)")
            .foregroundColor(.secondary)
    }
}
