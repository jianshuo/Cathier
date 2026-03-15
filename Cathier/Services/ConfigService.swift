import SwiftUI

// MARK: - Codable DTOs

struct EmotionConfig: Codable {
    var version: Int
    var bodyParts: [String]
    var sensations: [String]
    var categories: [EmotionCategoryDTO]
}

struct EmotionCategoryDTO: Codable {
    var id: String
    var nameZh: String
    var nameEn: String
    var colorHex: String
    var icon: String
    var valence: String
    var emotions: [EmotionDTO]

    func toEmotionCategory() -> EmotionCategory {
        EmotionCategory(
            id: id,
            nameZh: nameZh,
            nameEn: nameEn,
            color: Color(hex: colorHex),
            icon: icon,
            valence: EmotionValence(rawValue: valence) ?? .neutral,
            emotions: emotions.map {
                Emotion(id: $0.id, nameZh: $0.nameZh, nameEn: $0.nameEn,
                        emoji: $0.emoji, intensity: $0.intensity)
            }
        )
    }
}

struct EmotionDTO: Codable {
    var id: String
    var nameZh: String
    var nameEn: String
    var emoji: String
    var intensity: Int
}

// MARK: - ConfigService

@Observable
final class ConfigService {
    static let shared = ConfigService()

    private(set) var bodyParts: [String] = []
    private(set) var sensations: [String] = []
    private(set) var categories: [EmotionCategory] = []

    private let remoteURL = URL(string: "https://raw.githubusercontent.com/jianshuo/Cathier/main/Cathier/emotion_config.json")!
    private let cacheURL: URL = {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("emotion_config_cache.json")
    }()

    init() {
        loadFromDiskOrBundle()
    }

    // MARK: - Load (sync, called at init)

    private func loadFromDiskOrBundle() {
        if let data = try? Data(contentsOf: cacheURL),
           let config = try? JSONDecoder().decode(EmotionConfig.self, from: data) {
            apply(config)
            return
        }
        if let url = Bundle.main.url(forResource: "emotion_config", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let config = try? JSONDecoder().decode(EmotionConfig.self, from: data) {
            apply(config)
        }
    }

    // MARK: - Remote refresh (async, called at app launch)

    func refreshFromGitHub() async {
        guard let (data, response) = try? await URLSession.shared.data(from: remoteURL),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let config = try? JSONDecoder().decode(EmotionConfig.self, from: data) else { return }
        try? data.write(to: cacheURL, options: .atomic)
        apply(config)
    }

    // MARK: - Apply

    private func apply(_ config: EmotionConfig) {
        bodyParts = config.bodyParts
        sensations = config.sensations
        categories = config.categories.map { $0.toEmotionCategory() }
    }

    // MARK: - Lookup

    func category(for emotion: String) -> EmotionCategory? {
        categories.first { $0.nameZh == emotion || $0.children.contains(emotion) }
    }
}

// MARK: - Color hex extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8)  & 0xFF) / 255.0
        let b = Double( int        & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
