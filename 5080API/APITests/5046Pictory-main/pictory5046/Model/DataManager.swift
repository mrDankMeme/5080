import Foundation
import SwiftData

enum DataManager {
    static let container: ModelContainer = {
        let schema = Schema([TemplateResult.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}
