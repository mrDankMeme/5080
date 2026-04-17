import Foundation

protocol SitePreviewSceneViewModelFactoryProtocol {
    func make(project: SiteMakerProjectSummary) -> SitePreviewSceneViewModel?
}

final class DefaultSitePreviewSceneViewModelFactory: SitePreviewSceneViewModelFactoryProtocol {
    func make(project: SiteMakerProjectSummary) -> SitePreviewSceneViewModel? {
        guard
            let previewURLString = project.previewURLString,
            let previewURL = URL(string: previewURLString)
        else {
            return nil
        }

        return SitePreviewSceneViewModel(
            id: project.id,
            titleText: project.name,
            previewURL: previewURL
        )
    }
}
