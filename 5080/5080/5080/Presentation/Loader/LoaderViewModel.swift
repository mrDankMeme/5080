

import Foundation
import Combine
import SwiftUI

@MainActor
final class LoaderViewModel: ObservableObject {

    @Published private(set) var progress: CGFloat = 0
    @Published private(set) var isFinished: Bool = false

    private var task: Task<Void, Never>?

    deinit {
        task?.cancel()
    }

    func start(duration: TimeInterval = 1.5) {
        task?.cancel()
        progress = 0
        isFinished = false

        task = Task { @MainActor in
            
            try? await Task.sleep(nanoseconds: 20_000_000)

            withAnimation(.linear(duration: duration)) {
                self.progress = 1.0
            }

            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }

            self.isFinished = true
        }
    }
}
