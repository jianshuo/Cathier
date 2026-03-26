import SwiftUI

// MARK: - Language Enum

enum AppLanguage: String, CaseIterable, Identifiable {
    case zh = "zh"
    case en = "en"
    case ja = "ja"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .zh: return "中文"
        case .en: return "English"
        case .ja: return "日本語"
        }
    }
}

// MARK: - Language Manager

@Observable
final class LanguageManager {
    static let shared = LanguageManager()

    var currentLanguage: AppLanguage

    init() {
        let stored = UserDefaults.standard.string(forKey: "appLanguage") ?? "zh"
        currentLanguage = AppLanguage(rawValue: stored) ?? .zh
    }

    func set(_ lang: AppLanguage) {
        currentLanguage = lang
        UserDefaults.standard.set(lang.rawValue, forKey: "appLanguage")
    }

    // MARK: - Localization

    func localized(_ key: String) -> String {
        languageBundle.localizedString(forKey: key, value: key, table: nil)
    }

    /// Translates a Chinese body/emotion/sensation term to the current language.
    /// For Chinese, returns the term as-is. For others, looks up Terms.strings.
    func display(_ zhTerm: String) -> String {
        if currentLanguage == .zh { return zhTerm }
        return languageBundle.localizedString(forKey: zhTerm, value: zhTerm, table: "Terms")
    }

    private var languageBundle: Bundle {
        guard let path = Bundle.main.path(forResource: currentLanguage.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return .main }
        return bundle
    }
}
