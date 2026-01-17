import Foundation
import Combine

@MainActor
final class AdoptWizardState: ObservableObject {
    @Published var currentStep: WizardStep = .pathSelection
    @Published var selectedPath: String? = nil
    @Published var previewResult: AdoptPreviewResult? = nil
    @Published var isExecuting: Bool = false
    @Published var errorMessage: String? = nil
}
