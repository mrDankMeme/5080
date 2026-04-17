

import Foundation

extension String {

    
   var localizable: String {
        let value = NSLocalizedString(self, comment: "")
#if DEBUG
        if value == self {
            print("⚠️ Missing localization key: \(self)")
        }
#endif

        return value
    }

    
    func localizable(_ args: CVarArg...) -> String {
        let format = NSLocalizedString(self, comment: "")
        #if DEBUG
        if format == self {
            print("⚠️ Missing localization format key: \(self)")
        }
        #endif
        
        return String(format: format, locale: Locale.current, arguments: args)
    }

    func capitalizingFirstLetter() -> String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
