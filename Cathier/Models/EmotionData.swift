import SwiftUI

// MARK: - Models

enum EmotionValence: String {
    case positive, negative, neutral
}

struct Emotion: Identifiable {
    let id: String
    let nameZh: String
    let nameEn: String
    let emoji: String
    let intensity: Int  // 1–5
}

struct EmotionCategory: Identifiable {
    let id: String
    let nameZh: String
    let nameEn: String
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
}
