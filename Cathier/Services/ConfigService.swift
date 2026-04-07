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
            color: Color(hex: colorHex),
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
    private(set) var sensations: [String] = []
    private(set) var categories: [EmotionCategory] = []

    private let remoteURL = URL(string: "https://raw.githubusercontent.com/jianshuo/Cathier/main/Cathier/emotion_config.json")!
    private let cacheURL: URL = {
        // cachesDirectory is NEVER iCloud-synced. Using documentDirectory caused a
        // 3-second main-thread block when iCloud had the file but it wasn't downloaded.
        FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("emotion_config_cache.json")
    }()

    init() {
        t("ConfigService.init() — START")
        // Load bundle synchronously (always local, < 5 ms).
        t("ConfigService: loading from bundle — START")
        loadFromBundle()
        t("ConfigService: loading from bundle — END")
        // Check cache asynchronously so we never block the main thread.
        Task.detached(priority: .utility) {
            t("ConfigService: loading from cache (background) — START")
            guard let data = try? Data(contentsOf: self.cacheURL),
                  let config = try? JSONDecoder().decode(EmotionConfig.self, from: data) else {
                t("ConfigService: no valid cache found")
                return
            }
            t("ConfigService: applying cache (background) — START")
            await MainActor.run { self.apply(config) }
            t("ConfigService: applying cache (background) — END")
        }
        t("ConfigService.init() — END")
    }

    private func loadFromBundle() {
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
