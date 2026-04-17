
import SwiftUI
import Swinject

private struct ResolverKey: EnvironmentKey {
    static let defaultValue: Resolver = Assembler([]).resolver
}

extension EnvironmentValues {
    var resolver: Resolver {
        get { self[ResolverKey.self] }
        set { self[ResolverKey.self] = newValue }
    }
}
