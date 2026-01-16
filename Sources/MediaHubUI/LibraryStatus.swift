import Foundation

struct LibraryStatus: Equatable {
    let libraryPath: String
    let isBaselineIndexPresent: Bool?   // nil = unknown / N/A
    let isHashIndexPresent: Bool?       // nil = unknown / N/A
    let itemsCount: Int?                // nil = N/A
    let lastScanDate: Date?             // optional if readily available later; can be nil always for now
    
    var summaryLines: [String] {
        var lines: [String] = []
        lines.append("Library: \(libraryPath)")
        
        if let baselinePresent = isBaselineIndexPresent {
            lines.append("Baseline index: \(baselinePresent ? "Present" : "Missing")")
        }
        
        if let hashPresent = isHashIndexPresent {
            lines.append("Hash index: \(hashPresent ? "Present" : "Missing")")
        }
        
        if let count = itemsCount {
            lines.append("Items: \(count)")
        }
        
        if let scanDate = lastScanDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            lines.append("Last scan: \(formatter.string(from: scanDate))")
        }
        
        return lines
    }
}
