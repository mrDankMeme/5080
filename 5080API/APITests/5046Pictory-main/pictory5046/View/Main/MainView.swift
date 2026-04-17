import SwiftUI

struct MainView: View {
    @StateObject private var mainViewModel = MainViewModel()
    
    @EnvironmentObject private var apiManager: APIManager

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    NavBar(mainViewModel: mainViewModel)
                        .padding(.horizontal)
                    
                    Group {
                        switch mainViewModel.selectedTab {
                        case .home: HomeView(mainViewModel: mainViewModel)
                        case .enhancer: EnhancerView(mainViewModel: mainViewModel)
                        case .video: VideoView(mainViewModel: mainViewModel)
                        case .templates: TemplatesView(mainViewModel: mainViewModel)
                        case .history: HistoryView(mainViewModel: mainViewModel)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    TabBarView(mainViewModel: mainViewModel)
                }
                .background(Color.primaryBackground)
                .edgesIgnoringSafeArea(.bottom)
                
                if mainViewModel.showSuccessBanner {
                    VStack {
                        SuccessBanner(title: mainViewModel.successBannerText)
                        
                        Spacer()
                    }
                }
            }
            .onAppear() {
                Task {
                    await mainViewModel.retryIncompleteTemplateResults(apiManager: apiManager, container: DataManager.container)
                }
            }
        }
    }
}

#Preview {
    MainView()
}
