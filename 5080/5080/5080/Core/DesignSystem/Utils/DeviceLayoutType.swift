import UIKit

enum DeviceLayoutType {
    
    case smallStatusBar
    
    case notch
    
    case dynamicIsland

    case iPad
    
    case unknown
}

struct DeviceLayout {
    
    // MARK: - Публичные шорткаты
    
    static var type: DeviceLayoutType {
        current()
    }
    
    static var isDynamicIsland: Bool {
        current() == .dynamicIsland
    }
    
    static var isNotch: Bool {
        current() == .notch
    }
    
    static var isSmallStatusBarPhone: Bool {
        current() == .smallStatusBar
    }
    static var isPad: Bool {
        current() == .iPad
    }
    static var isUnknown: Bool {
        current() == .unknown
    }
    
    private static func current() -> DeviceLayoutType {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .iPad
        }

        if isPadHardware() {
            return .iPad
        }

        if isPadLikeCanvas(UIScreen.main.bounds.size) {
            return .iPad
        }

        guard let window = keyWindow else {
            if isPadLikeCanvas(UIScreen.main.bounds.size) {
                return .iPad
            }
            return .unknown
        }

        if window.traitCollection.userInterfaceIdiom == .pad {
            return .iPad
        }

        if isPadLikeCanvas(window.bounds.size) {
            return .iPad
        }
        
        let insets = window.safeAreaInsets
        let top = insets.top
        let bottom = insets.bottom
        
        // MARK: Dynamic Island
   
        if top >= 50, bottom > 0 {
            return .dynamicIsland
        }
        
        // MARK: Обычный notch (iPhone X → 13, 14/15 non-Pro)
       
        if top >= 44, bottom > 0 {
            return .notch
        }
        
        // MARK: Маленький статус-бар (iPhone 7 / 8 / SE и подобные)
      
        if top <= 20, bottom == 0 {
            return .smallStatusBar
        }

        if isPadLikeCanvas(window.bounds.size) {
            return .iPad
        }
        
        return .unknown
    }
    
    private static var keyWindow: UIWindow? {
        
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        
        
        for scene in scenes {
            if let key = scene.windows.first(where: { $0.isKeyWindow }) {
                return key
            }
        }
        
        return UIApplication.shared.windows.first(where: { $0.isKeyWindow })
    }

    private static func isPadLikeCanvas(_ size: CGSize) -> Bool {
        let minSide = min(size.width, size.height)
        return minSide >= 600
    }

    private static func isPadHardware() -> Bool {
#if targetEnvironment(simulator)
        if let simulatedModel = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"],
           simulatedModel.lowercased().contains("ipad") {
            return true
        }
#endif

        var systemInfo = utsname()
        uname(&systemInfo)

        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
        return machine.lowercased().contains("ipad")
    }
}
