import Foundation

enum LinksEnum {
    case privacy, terms, share, support
    
    var link: String {
        switch self {
            case .privacy:  "https://docs.google.com/document/d/1PwrgnuLt7DmDEa2UxhUMyeveRtgSFfeuI5MNDDySnNk/edit?usp=sharing"
            case .terms:    "https://docs.google.com/document/d/16xZjXfEqx8IEWDKMHOV7sUMM67BeWlaz473DRsDG7tM/edit?usp=sharing"
            case .share:    "https://apps.apple.com/us/app/artifex-ai-photo-generator/id6760009343"
            case .support:  "https://forms.gle/fBxp2shZDtvLVeX89"
        }
    }
}
