import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                AuthLabScreen()
            }
            .tabItem {
                Label("Auth", systemImage: "lock.shield")
            }

            BuilderPrototypeScreen()
                .tabItem {
                    Label("Builder", systemImage: "wand.and.stars")
                }
        }
        .tint(.orange)
    }
}

#Preview {
    ContentView()
}
