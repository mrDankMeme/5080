import SwiftUI

public enum Tokens {

    // MARK: Colors
    public enum Color {
        public static var accent: SwiftUI.Color { SwiftUI.Color("Accent") }
        public static var accentPressed: SwiftUI.Color { SwiftUI.Color("AccentPressed") }
        public static var accentSoft: SwiftUI.Color { SwiftUI.Color("AccentSoft") }

        public static var textHead: SwiftUI.Color { SwiftUI.Color("TextHead") }
        public static var textPrimary: SwiftUI.Color { SwiftUI.Color("TextPrimary") }
        public static var textSecondary: SwiftUI.Color { SwiftUI.Color("TextSecondary") }
        public static var textThirdcondary: SwiftUI.Color { SwiftUI.Color("TextThirdcondary") }

        public static var backgroundMain: SwiftUI.Color { SwiftUI.Color("BackgroundMain") }
        public static var componentsBackground: SwiftUI.Color { SwiftUI.Color("ComponentsBackground") }
        public static var lightAccent: SwiftUI.Color { SwiftUI.Color("lightAccent") }

        public static var chatOptionsSheetBackground: SwiftUI.Color {
            SwiftUI.Color(hex: "222A3B") ?? SwiftUI.Color.white
        }
        public static var strokeColor: SwiftUI.Color {
            SwiftUI.Color(hex: "222A3B") ?? SwiftUI.Color.white.opacity(0.2)
        }
        public static var inkPrimary: SwiftUI.Color {
            SwiftUI.Color(hex: "141414") ?? SwiftUI.Color.black
        }
        public static var modeSheetCardBackground: SwiftUI.Color {
            SwiftUI.Color(hex: "F7F7F7") ?? SwiftUI.Color.white
        }
        public static var modeSheetOverlay: SwiftUI.Color {
            SwiftUI.Color(hex: "00000059") ?? SwiftUI.Color.black.opacity(0.35)
        }
        public static var modeSheetPill: SwiftUI.Color {
            SwiftUI.Color(hex: "E4E4E7") ?? SwiftUI.Color.gray.opacity(0.2)
        }
        public static var surfaceWhite: SwiftUI.Color {
            SwiftUI.Color(hex: "FFFFFF") ?? SwiftUI.Color.white
        }
        public static var cardSoftBackground: SwiftUI.Color {
            SwiftUI.Color(hex: "F7F7F7") ?? SwiftUI.Color.white
        }
        public static var voiceComposerBackground: SwiftUI.Color {
            SwiftUI.Color(hex: "FCFCFD") ?? SwiftUI.Color.white
        }
        public static var voiceComposerStroke: SwiftUI.Color {
            SwiftUI.Color(hex: "E7E7E8") ?? SwiftUI.Color.gray.opacity(0.18)
        }
        public static var strokeSoft: SwiftUI.Color {
            SwiftUI.Color(hex: "1414141A") ?? SwiftUI.Color.black.opacity(0.1)
        }
        public static var inkPrimary30: SwiftUI.Color {
            SwiftUI.Color(hex: "1414144D") ?? SwiftUI.Color.black.opacity(0.3)
        }
        public static var toastSurface: SwiftUI.Color {
            SwiftUI.Color(hex: "F2F2F2") ?? SwiftUI.Color.white
        }
        public static var destructive: SwiftUI.Color {
            SwiftUI.Color(hex: "FF4D4F") ?? SwiftUI.Color.red
        }
        public static var accentGradient: LinearGradient {
            LinearGradient(
                stops: [
                    .init(color: SwiftUI.Color(hex: "C37F79") ?? .pink, location: 0.0),
                    .init(color: SwiftUI.Color(hex: "48BCAA") ?? .mint, location: 1.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
    
    

    // MARK: Typography
    public enum Font {
        public static var title: SwiftUI.Font { .custom("SFProDisplay-Medium", size: 22.scale) }
        public static var h0Bold34: SwiftUI.Font { .custom("SFProDisplay-Bold", size: 34.scale) }
        public static var heavy28: SwiftUI.Font { .custom("SFProDisplay-Heavy", size: 28.scale) }
        public static var bold18: SwiftUI.Font { .custom("SFProDisplay-Bold", size: 18.21.scale) }
        public static var bold28: SwiftUI.Font { .custom("SFProDisplay-Bold", size: 28.scale) }
        public static var bold15: SwiftUI.Font { .custom("SFProDisplay-Bold", size: 15.scale) }
        public static var bold22: SwiftUI.Font { .custom("SFProDisplay-Bold", size: 22.scale) }

        public static var semibold16: SwiftUI.Font { .custom("SFProText-Semibold", size: 16.scale) }
        public static var bold16: SwiftUI.Font { .custom("SFProText-Bold", size: 16.scale) }
        public static var semibold24: SwiftUI.Font { .custom("SFProText-Semibold", size: 24.scale) }
        public static var semibold22: SwiftUI.Font { .custom("SFProText-Semibold", size: 22.scale) }
        public static var semibold17: SwiftUI.Font { .custom("SFProText-Semibold", size: 17.scale) }
        public static var bold17: SwiftUI.Font { .custom("SFProText-Bold", size: 17.scale) }
        public static var medium17: SwiftUI.Font { .custom("SFProText-Medium", size: 17.scale) }
        public static var medium14: SwiftUI.Font { .custom("SFProText-Medium", size: 14.scale) }
        public static var medium11: SwiftUI.Font { .custom("SFProText-Medium", size: 11.scale) }
        public static var semibold18: SwiftUI.Font { .custom("SFProText-Semibold", size: 18.scale) }
        public static var semibold15: SwiftUI.Font { .custom("SFProText-Semibold", size: 15.scale) }
        public static var semibold11: SwiftUI.Font { .custom("SFProText-Semibold", size: 11.scale) }
        public static var semibold13: SwiftUI.Font { .custom("SFProText-Semibold", size: 13.scale) }
        public static var regular17: SwiftUI.Font { .custom("SFProText-Regular", size: 17.scale) }
        public static var regular16: SwiftUI.Font { .custom("SFProText-Regular", size: 16.scale) }
        public static var medium22: SwiftUI.Font { .custom("SFProText-Medium", size: 22.scale) }
        public static var medium16: SwiftUI.Font { .custom("SFProText-Medium", size: 16.scale) }
        public static var semibold20: SwiftUI.Font { .custom("SFProText-Semibold", size: 20.scale) }
        public static var medium18: SwiftUI.Font { .custom("SFProText-Medium", size: 18.scale) }
        public static var medium15: SwiftUI.Font { .custom("SFProText-Medium", size: 15.scale) }
        public static var regular15: SwiftUI.Font { .custom("SFProText-Regular", size: 15.scale) }
        public static var regular14: SwiftUI.Font { .custom("SFProText-Regular", size: 14.scale) }
        public static var regular11: SwiftUI.Font { .custom("SFProText-Regular", size: 11.scale) }
        public static var regular13: SwiftUI.Font { .custom("SFProText-Regular", size: 13.scale) }
        public static var regular12: SwiftUI.Font { .custom("SFProText-Regular", size: 12.scale) }
        public static var medium13: SwiftUI.Font { .custom("SFProText-Medium", size: 13.scale) }
        public static var medium12: SwiftUI.Font { .custom("SFProText-Medium", size: 12.scale) }

        // MARK: - Lato
        public static var latoRegular14: SwiftUI.Font { .custom("Lato-Regular", size: 13.scale) }
        
        //MARK: - Bowlby_one
        public static var bowlbyOneRegular16: SwiftUI.Font { .custom("BowlbyOne-Regular", size: 16.scale) }

        // MARK: - Outfit (used in onboarding/paywall)
        public static var outfitBold28: SwiftUI.Font { .custom("Outfit-Bold", size: 28.scale) }
        public static var outfitSemibold18: SwiftUI.Font { .custom("Outfit-SemiBold", size: 18.scale) }
        public static var outfitSemibold16: SwiftUI.Font { .custom("Outfit-SemiBold", size: 16.scale) }
        public static var outfitSemibold22: SwiftUI.Font { .custom("Outfit-SemiBold", size: 22.scale) }
        public static var outfitBold25: SwiftUI.Font { .custom("Outfit-SemiBold", size: 25.scale) }
        public static var outfitBold23: SwiftUI.Font { .custom("Outfit-SemiBold", size: 23.scale) }
    }

    // MARK: Spacing & Radius
    public enum Spacing {
        public static var x2:  CGFloat { 2.scale }
        public static var x4:  CGFloat { 4.scale }
        public static var x6:  CGFloat { 6.scale }
        public static var x8:  CGFloat { 8.scale }
        public static var x12: CGFloat { 12.scale }
        public static var x16: CGFloat { 16.scale }
        public static var x20: CGFloat { 20.scale }
        public static var x24: CGFloat { 24.scale }
        public static var x32: CGFloat { 32.scale }
    }

    public enum Radius {
        public static var pill:   CGFloat { 24.scale }
        public static var medium: CGFloat { 16.scale }
        public static var small:  CGFloat { 12.scale }
    }

    // MARK: Shadow
    public enum Shadow {
        public static var card: ShadowStyle {
            ShadowStyle(
                color: .black.opacity(0.07),
                radius: 8.scale,
                y: 0.scale
            )
        }
    }
}

// MARK: Helpers
public struct ShadowStyle {
    public let color: Color
    public let radius: CGFloat
    public let y: CGFloat
}

public extension View {
    func apply(_ shadow: ShadowStyle) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: 0, y: shadow.y)
    }
}

extension Color {
    init?(hex: String) {
        var cleaned = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        if cleaned.hasPrefix("#") {
            cleaned.removeFirst()
        }

        guard cleaned.count == 6 || cleaned.count == 8 else {
            return nil
        }

        var value: UInt64 = 0
        guard Scanner(string: cleaned).scanHexInt64(&value) else {
            return nil
        }

        let r, g, b, a: Double

        if cleaned.count == 6 {
            r = Double((value & 0xFF0000) >> 16) / 255.0
            g = Double((value & 0x00FF00) >> 8)  / 255.0
            b = Double(value & 0x0000FF)         / 255.0
            a = 1.0
        } else {
            r = Double((value & 0xFF000000) >> 24) / 255.0
            g = Double((value & 0x00FF0000) >> 16) / 255.0
            b = Double((value & 0x0000FF00) >> 8)  / 255.0
            a = Double(value & 0x000000FF)         / 255.0
        }

        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
