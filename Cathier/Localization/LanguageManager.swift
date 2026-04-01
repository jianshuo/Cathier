import SwiftUI

// MARK: - Language Enum

enum AppLanguage: String, CaseIterable, Identifiable {
    case zh = "zh"
    case en = "en"
    case ja = "ja"
    case es = "es"
    case fr = "fr"
    case de = "de"
    case it = "it"
    case pt = "pt"
    case ko = "ko"
    case ru = "ru"
    case ar = "ar"
    case hi = "hi"
    case th = "th"
    case vi = "vi"
    case tr = "tr"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .zh: return "中文"
        case .en: return "English"
        case .ja: return "日本語"
        case .es: return "Español"
        case .fr: return "Français"
        case .de: return "Deutsch"
        case .it: return "Italiano"
        case .pt: return "Português"
        case .ko: return "한국어"
        case .ru: return "Русский"
        case .ar: return "العربية"
        case .hi: return "हिन्दी"
        case .th: return "ภาษาไทย"
        case .vi: return "Tiếng Việt"
        case .tr: return "Türkçe"
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
