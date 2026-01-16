import SwiftUI

struct StatusView: View {
    @ObservedObject var viewModel: StatusViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.isLoading {
                Text("Loading status…")
                    .foregroundColor(.secondary)
            } else if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
            } else if let status = viewModel.status {
                Text("Library Status")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    // Baseline index
                    if let baselinePresent = status.isBaselineIndexPresent {
                        Text("Baseline index: \(baselinePresent ? "Present" : "Missing")")
                    } else {
                        Text("Baseline index: N/A")
                    }
                    
                    // Hash index
                    if let hashPresent = status.isHashIndexPresent {
                        Text("Hash index: \(hashPresent ? "Present" : "Missing")")
                    } else {
                        Text("Hash index: N/A")
                    }
                    
                    // Items count
                    if let count = status.itemsCount {
                        Text("Items: \(count)")
                    } else {
                        Text("Items: N/A")
                    }
                    
                    // Last scan date
                    if let scanDate = status.lastScanDate {
                        Text("Last scan: \(formatDate(scanDate))")
                    } else {
                        Text("Last scan: N/A")
                    }
                }
            } else {
                Text("No status loaded.")
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
