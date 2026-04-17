import Foundation

struct AIImageInspirationCard: Identifiable, Hashable {
    let id: String
    let title: String
    let prompt: String
    let imageAssetName: String
}

enum AIImageInspirationCatalog {
    static let cards: [AIImageInspirationCard] = [
        AIImageInspirationCard(
            id: "levitating_embrace",
            title: "Levitating Embrace",
            prompt: "Detailed portrait photo of a couple levitating, holding hands, face-to-face against a golden, sun-kissed cloudy sky at sunset. Detailed and ethereal. 8k.",
            imageAssetName: "ttv_inspiration_1"
        ),
        AIImageInspirationCard(
            id: "natures_whisper",
            title: "Nature's Whisper",
            prompt: "Detailed portrait of a dark-skinned woman wearing a white puffer jacket and gold sunglasses, nestled among lush green jungle leaves and branches. A small yellow bird perches on her hand. Warm lighting. 8k.",
            imageAssetName: "ttv_inspiration_2"
        ),
        AIImageInspirationCard(
            id: "opera_waves",
            title: "Opera Waves",
            prompt: "Detailed wide-angle photo of a stylish woman with long hair in a black top and red-striped wide-leg pants standing on steps. Behind her is the iconic Sydney Opera House, integrated with massive, stylized Hokusai-style Great Wave woodblock print illustrations. Detailed sky and architecture. 8k.",
            imageAssetName: "ttv_inspiration_3"
        ),
        AIImageInspirationCard(
            id: "mountain_radiance",
            title: "Mountain Radiance",
            prompt: "Detailed portrait of a young man standing in a field of blooming pink rhododendrons in a mountain valley. Golden sun rays burst through clouds over the distant peak. Cinematic light, sharp focus. 8k.",
            imageAssetName: "ttv_inspiration_4"
        ),
        AIImageInspirationCard(
            id: "bulldog_vibe",
            title: "Bulldog Vibe",
            prompt: "Detailed 3D render of a stylized French bulldog wearing round sunglasses, a black t-shirt with a white skull print, and baggy pants, standing coolly. Flat warm-yellow background. Playful, detailed textures. 8k.",
            imageAssetName: "ttv_inspiration_5"
        ),
        AIImageInspirationCard(
            id: "canyon_blast",
            title: "Canyon Blast",
            prompt: "Detailed 3D render of the character Lightning McQueen from Cars, parked on a cracked desert floor. In the background, a large mushroom cloud and dark smoke plume from a massive explosion billow into the dusty sky. Detailed texture. 8k.",
            imageAssetName: "ttv_inspiration_6"
        )
    ]
}
