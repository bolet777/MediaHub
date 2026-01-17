import Foundation
import Combine

@MainActor
final class CreateWizardState: ObservableObject {
    @Published var currentStep: WizardStep = .pathSelection
    @Published var selectedPath: String? = nil
    @Published var previewResult: CreatePreviewResult? = nil
    @Published var isExecuting: Bool = false
    @Published var errorMessage: String? = nil
}
