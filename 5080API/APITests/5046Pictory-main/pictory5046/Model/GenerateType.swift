enum GenerateType: String, Identifiable, CaseIterable {
    case textToImage = "Text to photo"
    case imageToImage = "Photo to photo"
    case textToVideo = "Text to video"
    case animatePhoto = "Animate Photo"
    case frameVideo = "Photos to video"
    case enhancePhoto = "Enhance Photo"
    case template = "Template"
    
    var id: String { self.rawValue }
}

enum HistoryGenType: String, Identifiable, CaseIterable {
    case enhancer = "Enhancer"
    case generation = "Generation"
    case template = "Template"
   
    var id: String { rawValue }
}
