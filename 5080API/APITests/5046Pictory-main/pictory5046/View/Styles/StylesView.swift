import SwiftUI

struct StylesView: View {
    @ObservedObject var mainViewModel: MainViewModel

    @EnvironmentObject var apiManager: APIManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Style")
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal)
                
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    Button {
                        mainViewModel.selectedStyle = nil
                    } label: {
                        EmptyStyleCard(isSelected: mainViewModel.selectedStyle?.id == nil)
                    }
                    
                    ForEach(Array(apiManager.photoStyles.enumerated()), id: \.0) { index, item in
                        Button {
                            mainViewModel.selectedStyle = item
                        } label: {
                            StyleCard(style: item, isSelected: mainViewModel.selectedStyle?.id == item.id)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
