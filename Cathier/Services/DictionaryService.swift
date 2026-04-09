import Foundation

/// Loads dictionary.json — the rich reference data for emotions (and future body parts / sensations).
/// Separate from ConfigService so emotion_config.json stays small for the check-in flow.
struct DictionaryEntry: Codable {
    var nameZh: String
    var nameEn: String
    var emoji: String
    var category: String
    var intensity: Int
    var description: String?
    var similarTo: [String]?
    var differs: [String: String]?
    var origin: String?
    var experience: String?
    var embodiment: String?
    var imagery: String?
    var developmentalStage: String?
    var formativeEvents: String?
    var personalityImpact: String?
    var transformation: String?
    var literaryReference: String?
}

struct DictionarySection: Codable {
    var description: String
    var entries: [String: DictionaryEntry]
}

struct DictionaryData: Codable {
    var version: Int
    var sections: [String: DictionarySection]
}

enum DictionaryService {
    private static var cache: DictionaryData?

    static var shared: DictionaryData {
        if let cache { return cache }
        guard let url = Bundle.main.url(forResource: "dictionary", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(DictionaryData.self, from: data) else {
            return DictionaryData(version: 0, sections: [:])
        }
        cache = decoded
        return decoded
    }

    static var emotionEntries: [(id: String, entry: DictionaryEntry)] {
        guard let section = shared.sections["emotions"] else { return [] }
        return section.entries.map { (id: $0.key, entry: $0.value) }
            .sorted { $0.entry.category < $1.entry.category || ($0.entry.category == $1.entry.category && $0.entry.intensity > $1.entry.intensity) }
    }

    static func emotion(for id: String) -> DictionaryEntry? {
        shared.sections["emotions"]?.entries[id]
    }

    /// Group emotions by category, preserving category order from ConfigService.
    static var emotionsByCategory: [(category: String, emotions: [(id: String, entry: DictionaryEntry)])] {
        let all = shared.sections["emotions"]?.entries ?? [:]
        var grouped: [String: [(id: String, entry: DictionaryEntry)]] = [:]
        for (id, entry) in all {
            grouped[entry.category, default: []].append((id: id, entry: entry))
        }
        // Sort emotions within each category by intensity descending
        for key in grouped.keys {
            grouped[key]?.sort { $0.entry.intensity > $1.entry.intensity }
        }
        // Maintain a stable category order
        let categoryOrder = ConfigService.shared.categories.map(\.nameZh)
        return categoryOrder.compactMap { cat in
            guard let emotions = grouped[cat], !emotions.isEmpty else { return nil }
            return (category: cat, emotions: emotions)
        }
    }
}
