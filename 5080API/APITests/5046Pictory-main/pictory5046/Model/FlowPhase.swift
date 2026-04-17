import SwiftUI

enum FlowPhase: Equatable {
    case picking
    case creating(resultId: UUID, jobId: String)
    case result(UIImage)
}
