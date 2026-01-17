import Foundation
import MediaHub

struct AdoptPreviewResult: Codable, Equatable {
    let metadataLocation: String
    let libraryId: String
    let libraryVersion: String
    let baselineScanSummary: BaselineScanSummary
}
