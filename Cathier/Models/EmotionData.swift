import SwiftUI

// MARK: - Models

enum EmotionValence: String {
    case positive, negative, neutral
}

struct Emotion: Identifiable {
    let id: String
    let nameZh: String
    let nameEn: String
    let nameJa: String
    let emoji: String
    let intensity: Int  // 1–5
    let descriptionText: String?
    let similarTo: [String]?
    let differs: [String: String]?
}

struct EmotionCategory: Identifiable {
    let id: String
    let nameZh: String
    let nameEn: String
    let nameJa: String
    let color: Color
    let icon: String
    let valence: EmotionValence
    let emotions: [Emotion]

    // Backward-compat accessors used by existing views
    var name: String { nameZh }
    var children: [String] { emotions.map(\.nameZh) }
}

// MARK: - EmotionData (delegates to ConfigService)

enum EmotionData {
    static func category(for emotion: String) -> EmotionCategory? {
        ConfigService.shared.category(for: emotion)
    }

    static func emotion(for name: String) -> Emotion? {
        ConfigService.shared.categories
            .flatMap(\.emotions)
            .first { $0.nameZh == name }
    }

    static func emoji(for emotion: String) -> String {
        ConfigService.shared.categories
            .flatMap(\.emotions)
            .first { $0.nameZh == emotion }?.emoji ?? ""
    }
}
