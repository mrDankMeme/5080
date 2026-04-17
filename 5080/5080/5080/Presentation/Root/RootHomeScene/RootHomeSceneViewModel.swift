import Combine
import Foundation

struct RootHomeLaunchRequest: Hashable {
    let mode: RootHomeGenerationMode
    let prompt: String
}

enum RootHomeGenerationMode: String, Hashable {
    case textToVideo
    case frameToVideo
    case animateImage
    case aiImage

    var title: String {
        switch self {
        case .textToVideo:
            return "Text to Video"
        case .frameToVideo:
            return "Frame to Video"
        case .animateImage:
            return "Animate Image"
        case .aiImage:
            return "AI Image"
        }
    }
}

enum RootHomePromptCardPreview: Hashable {
    case asset(String)
    case media(URL)
}

struct RootHomePromptCard: Identifiable, Hashable {
    let id: String
    let title: String
    let prompt: String
    let preview: RootHomePromptCardPreview
    let mode: RootHomeGenerationMode
}

@MainActor
final class RootHomeSceneViewModel: ObservableObject {
    @Published private(set) var isReady = true
    @Published private(set) var isSubscribed = false
    @Published private(set) var availableTokens = 0
    @Published private(set) var trendingCards: [RootHomePromptCard]

    let appTitle: String
    let modeSections: [RootHomeModeSection]
    let featuredCards: [RootHomePromptCard]

    private let historyRepository: HistoryRepository
    private let defaultTrendingCards: [RootHomePromptCard]
    private var onSelectLaunch: ((RootHomeLaunchRequest) -> Void)?
    private var onOpenTokensPaywall: (() -> Void)?
    private var cancellables = Set<AnyCancellable>()

    init(
        purchaseManager: PurchaseManager,
        historyRepository: HistoryRepository,
        appTitle: String,
        modeSections: [RootHomeModeSection],
        featuredCards: [RootHomePromptCard],
        trendingCards: [RootHomePromptCard]
    ) {
        self.historyRepository = historyRepository
        self.appTitle = appTitle
        self.modeSections = modeSections
        self.featuredCards = featuredCards
        self.defaultTrendingCards = trendingCards
        self.trendingCards = trendingCards
        self.isSubscribed = purchaseManager.isSubscribed
        self.availableTokens = max(0, purchaseManager.availableGenerations)

        purchaseManager.$isSubscribed
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.isSubscribed = value
            }
            .store(in: &cancellables)

        purchaseManager.$availableGenerations
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.availableTokens = max(0, value)
            }
            .store(in: &cancellables)

        historyRepository.entriesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] entries in
                self?.syncTrendingCards(with: entries)
            }
            .store(in: &cancellables)

        syncTrendingCards(with: historyRepository.entries())
    }

    convenience init() {
        self.init(
            purchaseManager: PurchaseManager.shared,
            historyRepository: InMemoryHistoryRepository()
        )
    }

    convenience init(
        purchaseManager: PurchaseManager,
        historyRepository: HistoryRepository
    ) {
        self.init(
            purchaseManager: purchaseManager,
            historyRepository: historyRepository,
            appTitle: Self.resolveAppTitle(),
            modeSections: Self.makeDefaultModeSections(),
            featuredCards: Self.makeFeaturedCards(),
            trendingCards: Self.makeDefaultTrendingCards()
        )
    }

    var formattedTokens: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: availableTokens)) ?? "\(availableTokens)"
    }

    func configureCallbacks(
        onSelectLaunch: @escaping (RootHomeLaunchRequest) -> Void,
        onOpenTokensPaywall: @escaping () -> Void
    ) {
        self.onSelectLaunch = onSelectLaunch
        self.onOpenTokensPaywall = onOpenTokensPaywall
    }

    func selectCard(_ card: RootHomePromptCard) {
        let trimmedPrompt = card.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { return }

        onSelectLaunch?(
            RootHomeLaunchRequest(
                mode: card.mode,
                prompt: trimmedPrompt
            )
        )
    }

    func openTokensPaywall() {
        onOpenTokensPaywall?()
    }

    private func syncTrendingCards(with entries: [HistoryEntry]) {
        let generatedCards = Self.makeGeneratedCards(
            from: entries,
            historyRepository: historyRepository
        )

        if generatedCards.isEmpty {
            trendingCards = defaultTrendingCards
            return
        }

        trendingCards = defaultTrendingCards + generatedCards
    }
}

private extension RootHomeSceneViewModel {
    static func resolveAppTitle() -> String {
        return "Base44"
    }

    static func makeDefaultModeSections() -> [RootHomeModeSection] {
        [
            RootHomeModeSection(
                id: "video",
                title: "Video",
                primaryOption: RootHomeModeOption(
                    id: RootHomeModeOptionID.textToVideo,
                    title: RootHomeGenerationMode.textToVideo.title,
                    iconAssetName: "mode_text_to_video_32"
                ),
                secondaryOptions: [
                    RootHomeModeOption(
                        id: RootHomeModeOptionID.animateImage,
                        title: RootHomeGenerationMode.animateImage.title,
                        iconAssetName: "mode_animate_image_32"
                    ),
                    RootHomeModeOption(
                        id: RootHomeModeOptionID.frameToVideo,
                        title: RootHomeGenerationMode.frameToVideo.title,
                        iconAssetName: "mode_frame_to_video_32"
                    )
                ]
            ),
            RootHomeModeSection(
                id: "voice",
                title: "Voice",
                primaryOption: nil,
                secondaryOptions: [
                    RootHomeModeOption(
                        id: RootHomeModeOptionID.voiceGen,
                        title: "Voice Gen",
                        iconAssetName: "mode_voice_gen_32"
                    ),
                    RootHomeModeOption(
                        id: RootHomeModeOptionID.transcribe,
                        title: "Transcribe",
                        iconAssetName: "mode_transcribe_32"
                    )
                ]
            ),
            RootHomeModeSection(
                id: "photo",
                title: "Photo",
                primaryOption: RootHomeModeOption(
                    id: RootHomeModeOptionID.aiImage,
                    title: RootHomeGenerationMode.aiImage.title,
                    iconAssetName: "mode_ai_image_32"
                ),
                secondaryOptions: []
            )
        ]
    }

    static func makeFeaturedCards() -> [RootHomePromptCard] {
        [
            RootHomePromptCard(
                id: "dynamic_sports",
                title: "Dynamic Sports",
                prompt: "Cinematic shot of a tennis player hitting a serve, dynamic angle, sun flare, 4k ultra realistic, high speed photography style.",
                preview: .asset("home_featured_dynamic_sports"),
                mode: .textToVideo
            ),
            RootHomePromptCard(
                id: "surreal_fashion_frame",
                title: "Surreal Fashion",
                prompt: "High fashion editorial, woman in suit, red background, floating marble tiles, mesmerizing loop, surreal atmosphere, studio lighting.",
                preview: .asset("home_featured_surreal_fashion_frame"),
                mode: .frameToVideo
            ),
            RootHomePromptCard(
                id: "cinematic_dreamscapes",
                title: "Cinematic Dreamscapes",
                prompt: "A peaceful portrait of a person in glasses and a beige sweatshirt, floating serenely on a cloud over a stunning sunset cloud-ocean. Bring this surreal moment to life with subtle motion and light effects.",
                preview: .asset("home_featured_cinematic_dreamscapes"),
                mode: .animateImage
            ),
            RootHomePromptCard(
                id: "surreal_fashion_ai_image",
                title: "Surreal Fashion",
                prompt: "High fashion editorial, woman in suit, red background, floating marble tiles, mesmerizing loop, surreal atmosphere, studio lighting.",
                preview: .asset("home_featured_surreal_fashion_ai_image"),
                mode: .aiImage
            )
        ]
    }

    static func makeDefaultTrendingCards() -> [RootHomePromptCard] {
        makeDefaultCards()
    }

    // Keep the curated 12-card trending catalog and append ready user generations after it.
    static func makeDefaultCards() -> [RootHomePromptCard] {
        [
            RootHomePromptCard(
                id: "magenta_royalty",
                title: "Magenta Royalty",
                prompt: "Close-up of a majestic pink-furred leopard wearing an intricate crystal crown, resting its head on a white marble surface in a luxury room, cinematic lighting.",
                preview: .asset("home_trending_magenta_royalty"),
                mode: .textToVideo
            ),
            RootHomePromptCard(
                id: "arcade_legends",
                title: "Arcade Legends",
                prompt: "Detailed portrait photo of a stylish elderly man with a long white beard and sunglasses, wearing a vibrant pastel retro 80s tracksuit and vintage sneakers. He holds a large pink boombox in a detailed vintage arcade with neon-lit gaming cabinets. Highly detailed, 8k.",
                preview: .asset("home_trending_arcade_legends"),
                mode: .aiImage
            ),
            RootHomePromptCard(
                id: "prismatic_dreams",
                title: "Prismatic Dreams",
                prompt: "A minimalist wide shot of a person sitting on a chair in a golden field, reading a book. A vibrant, flowing ribbon of rainbow-colored light arches across the bright blue sky. Surrealist photography, peaceful atmosphere, high resolution.",
                preview: .asset("home_trending_prismatic_dreams"),
                mode: .frameToVideo
            ),
            RootHomePromptCard(
                id: "urban_vantage",
                title: "Urban Vantage",
                prompt: "A detailed low-angle perspective shot. A curly-haired woman in a red windbreaker sits on a brick parapet ledge. Her white sneaker with a red sole dominates the extreme foreground. Her gaze is downward and direct. Modern glass skyscrapers and a traditional brick building are visible against a clear blue sky. Crisp, harsh sunlight. Highly detailed, 8k.",
                preview: .asset("home_trending_urban_vantage"),
                mode: .animateImage
            ),
            RootHomePromptCard(
                id: "sky_drifter",
                title: "Sky Drifter",
                prompt: "Full shot of a person in an all-white puffer jacket and pants, wearing white sunglasses and floating peacefully in a clear blue sky with a black helmet. Fashion photography, surreal, detailed, high resolution.",
                preview: .asset("home_trending_sky_drifter"),
                mode: .animateImage
            ),
            RootHomePromptCard(
                id: "lemon_cloud",
                title: "Lemon Cloud",
                prompt: "Surreal portrait photo of a woman in a light blue dress sitting on a giant glass bottle filled with lemons, floating among clouds. Detailed.",
                preview: .asset("home_trending_lemon_cloud"),
                mode: .aiImage
            ),
            RootHomePromptCard(
                id: "dream_voyage",
                title: "Dream Voyage",
                prompt: "Whimsical stylized illustration of a red-haired woman holding a birthday cake, sitting on Saturn's rings. Poppies field. Starry night. Detailed.",
                preview: .asset("home_trending_dream_voyage"),
                mode: .textToVideo
            ),
            RootHomePromptCard(
                id: "arctic_explorer",
                title: "Arctic Explorer",
                prompt: "Portrait photo of a stylish man wearing a light blue puffer jacket, blue jeans, white knit hat, and blue mirror sunglasses, sitting on a huge blue iceberg block. Snow-capped mountains and clear sky in the background. High detail.",
                preview: .asset("home_trending_arctic_explorer"),
                mode: .aiImage
            ),
            RootHomePromptCard(
                id: "desert_hyperdrive",
                title: "Desert Hyperdrive",
                prompt: "Cinematic wide shot of a sleek red electric hypercar parked in a vast, sun-drenched canyon with layered white rock formations. Clear blue sky with soft clouds, professional automotive photography, 8k.",
                preview: .asset("home_trending_desert_hyperdrive"),
                mode: .textToVideo
            ),
            RootHomePromptCard(
                id: "pastel_reverie",
                title: "Pastel Reverie",
                prompt: "A surreal scene of a girl in pink and white striped pajamas sitting calmly on a massive, majestic white lion. A soft pink fluffy cloud hangs above in a minimalist light blue room. Ethereal atmosphere, soft pastel colors.",
                preview: .asset("home_trending_pastel_reverie"),
                mode: .animateImage
            )
        ]
    }

    static func makeGeneratedCards(
        from entries: [HistoryEntry],
        historyRepository: HistoryRepository
    ) -> [RootHomePromptCard] {
        entries
            .sorted(by: { $0.createdAt > $1.createdAt })
            .compactMap { entry in
                guard entry.status == .ready else { return nil }
                guard let mode = RootHomeGenerationMode(historyFlowKind: entry.flowKind) else { return nil }
                guard let mediaURL = historyRepository.mediaURL(for: entry) else { return nil }
                guard let prompt = resolvedPrompt(for: entry) else { return nil }

                return RootHomePromptCard(
                    id: "history_\(entry.id.uuidString)",
                    title: generatedCardTitle(from: entry.createdAt),
                    prompt: prompt,
                    preview: .media(mediaURL),
                    mode: mode
                )
            }
            .prefix(12)
            .map { $0 }
    }

    static func resolvedPrompt(for entry: HistoryEntry) -> String? {
        let prompt = entry.prompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !prompt.isEmpty {
            return prompt
        }

        let title = entry.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
    }

    static func generatedCardTitle(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("d MMM")
        return formatter.string(from: date)
    }
}

private extension RootHomeGenerationMode {
    init?(historyFlowKind: HistoryFlowKind) {
        switch historyFlowKind {
        case .textToVideo:
            self = .textToVideo
        case .frameToVideo:
            self = .frameToVideo
        case .animateImage:
            self = .animateImage
        case .aiImage:
            self = .aiImage
        case .voiceGen, .transcribe:
            return nil
        }
    }
}
