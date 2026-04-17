import SwiftUI

struct TemplatesGroupView: View {
    @ObservedObject var mainViewModel: MainViewModel

    let effectsWithTemplates: [EffectWithTemplate]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(effectsWithTemplates.first?.template.title ?? "")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(effectsWithTemplates) { item in
                        Button {
                            mainViewModel.selectedEffect = item
                        } label: {
                            TemplateCard(
                                effectWithTemplate: item
                            )
                            .contentShape(Rectangle())
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
