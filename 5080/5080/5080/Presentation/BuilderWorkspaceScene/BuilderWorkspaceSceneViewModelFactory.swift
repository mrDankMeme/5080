import Foundation

protocol BuilderWorkspaceSceneViewModelFactoryProtocol {
    func make(launch: BuilderSceneLaunch) -> BuilderWorkspaceSceneViewModel
}

final class DefaultBuilderWorkspaceSceneViewModelFactory: BuilderWorkspaceSceneViewModelFactoryProtocol {
    private let createProjectUseCase: CreateSiteMakerProjectUseCaseProtocol
    private let fetchProjectUseCase: FetchSiteMakerProjectUseCaseProtocol
    private let uploadAssetUseCase: UploadSiteMakerAssetUseCaseProtocol
    private let clarifyProjectUseCase: ClarifySiteMakerProjectUseCaseProtocol
    private let generateProjectUseCase: GenerateSiteMakerProjectUseCaseProtocol
    private let editProjectUseCase: EditSiteMakerProjectUseCaseProtocol

    init(
        createProjectUseCase: CreateSiteMakerProjectUseCaseProtocol,
        fetchProjectUseCase: FetchSiteMakerProjectUseCaseProtocol,
        uploadAssetUseCase: UploadSiteMakerAssetUseCaseProtocol,
        clarifyProjectUseCase: ClarifySiteMakerProjectUseCaseProtocol,
        generateProjectUseCase: GenerateSiteMakerProjectUseCaseProtocol,
        editProjectUseCase: EditSiteMakerProjectUseCaseProtocol
    ) {
        self.createProjectUseCase = createProjectUseCase
        self.fetchProjectUseCase = fetchProjectUseCase
        self.uploadAssetUseCase = uploadAssetUseCase
        self.clarifyProjectUseCase = clarifyProjectUseCase
        self.generateProjectUseCase = generateProjectUseCase
        self.editProjectUseCase = editProjectUseCase
    }

    func make(launch: BuilderSceneLaunch) -> BuilderWorkspaceSceneViewModel {
        BuilderWorkspaceSceneViewModel(
            launch: launch,
            createProjectUseCase: createProjectUseCase,
            fetchProjectUseCase: fetchProjectUseCase,
            uploadAssetUseCase: uploadAssetUseCase,
            clarifyProjectUseCase: clarifyProjectUseCase,
            generateProjectUseCase: generateProjectUseCase,
            editProjectUseCase: editProjectUseCase
        )
    }
}
