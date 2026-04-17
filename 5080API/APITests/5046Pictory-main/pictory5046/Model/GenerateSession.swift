import SwiftUI

struct GenerateSession: Identifiable {
    let id = UUID()
    let resultId: UUID
    let jobId: String
    let generationType: GenerateType
    
    var isVideo: Bool {
        generationType == .animatePhoto
    }
}
