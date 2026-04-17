//
//  AppLanguage.swift
//  Claude
//
//  Created by Niiaz Khasanov on 2/6/26.
//

import Foundation

enum AppLanguage {
    static var code: String {
        Bundle.main.preferredLocalizations.first ?? "en"
    }

    static var isRussian: Bool {
        code.hasPrefix("ru")
    }

    static var isEnglish: Bool {
        code.hasPrefix("en")
    }
}
