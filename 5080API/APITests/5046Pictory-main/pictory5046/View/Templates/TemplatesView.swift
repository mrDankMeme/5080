import SwiftUI

struct TemplatesView: View {
    @ObservedObject var mainViewModel: MainViewModel

    @EnvironmentObject var apiManager: APIManager
    
    private var groupedTemplates: [[EffectWithTemplate]] {
        let effects: [EffectWithTemplate] = apiManager.allEffects
        
        let grouped: [String: [EffectWithTemplate]] =
            Dictionary(grouping: effects) { (effect: EffectWithTemplate) -> String in
                if let title = effect.template.title, !title.isEmpty {
                    return title
                } else {
                    return "Unknown"
                }
            }
        
        let sortedKeys: [String] = grouped.keys.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        
        return sortedKeys.map { (key: String) -> [EffectWithTemplate] in
            let values: [EffectWithTemplate] = grouped[key] ?? []
            
            return values.sorted { (e1: EffectWithTemplate, e2: EffectWithTemplate) -> Bool in
                (e1.template.title ?? "") < (e2.template.title ?? "")
            }
        }
    }

    var body: some View {
        ZStack {
            Color.primaryBackground.ignoresSafeArea()
                
            if apiManager.isTemplatesLoading && apiManager.allEffects.isEmpty {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.3)
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 20) {
                        ForEach(groupedTemplates.indices, id: \.self) { index in
                            TemplatesGroupView(
                                mainViewModel: mainViewModel,
                                effectsWithTemplates: groupedTemplates[index]
                            )
                        }
                    }
                    .padding(.top)
                }
            }
        }
        .navigationDestination(item: $mainViewModel.selectedEffect) { item in
            SelectedTemplateView(
                mainViewModel: mainViewModel,
                effectWithTemplate: item
            )
        }
    }
}
