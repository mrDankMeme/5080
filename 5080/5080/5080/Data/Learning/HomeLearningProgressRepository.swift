import Foundation

final class UserDefaultsLearningProgressRepository: LearningProgressRepository {

    private let userDefaults: UserDefaults
    private let storageKey: String

    init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "learning_home_progress_v1"
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
    }

    func loadSnapshot() -> LearningProgressSnapshot {
        guard let data = userDefaults.data(forKey: storageKey) else {
            return .empty
        }

        do {
            return try JSONDecoder().decode(LearningProgressSnapshot.self, from: data)
        } catch {
            return .empty
        }
    }

    func saveSnapshot(_ snapshot: LearningProgressSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else {
            return
        }

        userDefaults.set(data, forKey: storageKey)
    }
}
