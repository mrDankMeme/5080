import SwiftUI

extension Font {
    static func instrumentSans(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        switch weight {
        default:
            .custom("InstrumentSans-SemiBold", size: size)
        }
    }
}
