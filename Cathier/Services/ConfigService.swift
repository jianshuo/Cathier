import SwiftUI

// MARK: - Codable DTOs

struct EmotionConfig: Codable {
    var version: Int
    var bodyParts: [String]
    var sensations: SensationsData
    var categories: [EmotionCategoryDTO]
}

/// Supports both old flat array format and new per-body-part dictionary format.
enum SensationsData: Codable {
    case flat([String])
    case perPart([String: [String]])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let dict = try? container.decode([String: [String]].self) {
            self = .perPart(dict)
        } else if let arr = try? container.decode([String].self) {
            self = .flat(arr)
        } else {
            self = .flat([])
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .flat(let arr): try container.encode(arr)
        case .perPart(let dict): try container.encode(dict)
        }
    }

    /// Returns sensations for a specific body part, or all sensations if flat.
    func sensations(for bodyPart: String) -> [String] {
        switch self {
        case .flat(let arr): return arr
        case .perPart(let dict): return dict[bodyPart] ?? []
        }
    }
}

struct EmotionCategoryDTO: Codable {
    var id: String
    var nameZh: String
    var nameEn: String
    var nameJa: String?
    var colorHex: String
    var icon: String
    var valence: String
    var emotions: [EmotionDTO]

    func toEmotionCategory() -> EmotionCategory {
        EmotionCategory(
            id: id,
            nameZh: nameZh,
            nameEn: nameEn,
            nameJa: nameJa ?? nameEn,
            color: Color(hex: colorHex) ?? .gray,
            icon: icon,
            valence: EmotionValence(rawValue: valence) ?? .neutral,
            emotions: emotions.map {
                Emotion(id: $0.id, nameZh: $0.nameZh, nameEn: $0.nameEn,
                        nameJa: $0.nameJa ?? $0.nameEn,
                        emoji: $0.emoji, intensity: $0.intensity,
                        descriptionText: $0.descriptionText,
                        similarTo: $0.similarTo,
                        differs: $0.differs)
            }
        )
    }
}

struct EmotionDTO: Codable {
    var id: String
    var nameZh: String
    var nameEn: String
    var nameJa: String?
    var emoji: String
    var intensity: Int
    var descriptionText: String?
    var similarTo: [String]?
    var differs: [String: String]?
}

// MARK: - ConfigService

@Observable
final class ConfigService {
    static let shared = ConfigService()

    private(set) var bodyParts: [String] = []
    private(set) var sensationsData: SensationsData = .flat([])

    /// Returns sensations specific to a body part (or all if using old flat config).
    func sensations(for bodyPart: String) -> [String] {
        sensationsData.sensations(for: bodyPart)
    }
    private(set) var categories: [EmotionCategory] = []

    init() {
        t("ConfigService.init() — START")
        loadFromBundle()
        t("ConfigService.init() — END")
    }

    private func loadFromBundle() {
        if let url = Bundle.main.url(forResource: "emotion_config", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let config = try? JSONDecoder().decode(EmotionConfig.self, from: data) {
            apply(config)
        }
    }

    // MARK: - Apply

    private func apply(_ config: EmotionConfig) {
        bodyParts = config.bodyParts
        sensationsData = config.sensations
        categories = config.categories.map { $0.toEmotionCategory() }
    }

    // MARK: - Lookup (searches across all languages for robust color/category resolution)

    func category(for emotion: String) -> EmotionCategory? {
        categories.first { cat in
            cat.nameZh == emotion || cat.nameEn == emotion || cat.nameJa == emotion ||
            cat.emotions.contains { e in
                e.nameZh == emotion || e.nameEn == emotion || e.nameJa == emotion
            }
        }
    }
}

