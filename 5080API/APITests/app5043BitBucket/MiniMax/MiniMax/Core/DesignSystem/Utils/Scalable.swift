
import UIKit

// MARK: - ScreenScale (безопасный кеш коэффициента)
enum ScreenScale {
    
    static var ratio: CGFloat = 1.0

    static func configure(designWidth: CGFloat = 375) {
        let bounds = UIScreen.main.bounds
        let shortSide = min(bounds.width, bounds.height)
        let isPadLikeCanvas = shortSide >= 600
        let isPadHardware: Bool = {
            if UIDevice.current.userInterfaceIdiom == .pad {
                return true
            }
#if targetEnvironment(simulator)
            if let simulatedModel = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"],
               simulatedModel.lowercased().contains("ipad") {
                return true
            }
#endif
            return false
        }()

        if isPadLikeCanvas || isPadHardware {
            Self.ratio = 1.0
            return
        }

        let current = bounds.width
        Self.ratio = max(0.5, min(1.8, current / max(1, designWidth)))
    }
}

// MARK: - Протокол
protocol Scalable {
    var scale: Self { get }
}

// MARK: - Базовые типы

extension CGFloat: Scalable {
    var scale: CGFloat { self * ScreenScale.ratio }
}

extension Int {
    var scale: CGFloat { CGFloat(self).scale }
}

extension Double {
    var scale: CGFloat { CGFloat(self).scale }
}

extension CGPoint: Scalable {
    var scale: CGPoint {
        CGPoint(x: x.scale, y: y.scale)
    }
}

extension CGSize: Scalable {
    var scale: CGSize {
        CGSize(width: width.scale, height: height.scale)
    }
}

extension CGRect: Scalable {
    var scale: CGRect {
        CGRect(origin: origin.scale, size: size.scale)
    }
}

extension UIFont {
    var scale: UIFont {
        UIFont(name: fontName, size: pointSize.scale)
            ?? UIFont.systemFont(ofSize: pointSize.scale)
    }
}

extension UIEdgeInsets: Scalable {
    var scale: UIEdgeInsets {
        UIEdgeInsets(
            top: top.scale,
            left: left.scale,
            bottom: bottom.scale,
            right: right.scale
        )
    }
}
