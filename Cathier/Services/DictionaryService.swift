import Foundation

/// Universal dictionary entry — all fields optional so one struct works for emotions, sensations, and body parts.
struct DictionaryEntry: Codable {
    // Shared
    var nameZh: String
    var nameEn: String
    var description: String?
    var differs: [String: String]?

    // Emotion fields
    var emoji: String?
    var category: String?
    var intensity: Int?
    var similarTo: [String]?
    var origin: String?
    var experience: String?
    var embodiment: String?
    var imagery: String?
    var developmentalStage: String?
    var formativeEvents: String?
    var personalityImpact: String?
    var transformation: String?
    var literaryReference: String?

    // Sensation fields
    var howItFeels: String?
    var commonLocations: [String]?
    var relatedEmotions: [String]?
    var signalMeaning: String?
    var selfCare: String?
    var intensitySpectrum: String?

    // Body part fields
    var howToLocate: String?
    var commonSensations: [String]?
    var emotionalConnection: String?
    var awarenessGuide: String?
    var culturalNote: String?
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

    // MARK: - Emotions

    static func emotion(for id: String) -> DictionaryEntry? {
        shared.sections["emotions"]?.entries[id]
    }

    static var emotionsByCategory: [(category: String, emotions: [(id: String, entry: DictionaryEntry)])] {
        let all = shared.sections["emotions"]?.entries ?? [:]
        var grouped: [String: [(id: String, entry: DictionaryEntry)]] = [:]
        for (id, entry) in all {
            grouped[entry.category ?? "", default: []].append((id: id, entry: entry))
        }
        for key in grouped.keys {
            grouped[key]?.sort { ($0.entry.intensity ?? 0) > ($1.entry.intensity ?? 0) }
        }
        let categoryOrder = ConfigService.shared.categories.map(\.nameZh)
        return categoryOrder.compactMap { cat in
            guard let emotions = grouped[cat], !emotions.isEmpty else { return nil }
            return (category: cat, emotions: emotions)
        }
    }

    // MARK: - Body Parts

    static var bodyPartEntries: [(id: String, entry: DictionaryEntry)] {
        let all = shared.sections["bodyParts"]?.entries ?? [:]
        let order = ConfigService.shared.bodyParts
        return order.compactMap { name in
            guard let entry = all[name] else { return nil }
            return (id: name, entry: entry)
        }
    }

    static func bodyPart(for name: String) -> DictionaryEntry? {
        shared.sections["bodyParts"]?.entries[name]
    }

    // MARK: - Sensations

    static var sensationEntries: [(id: String, entry: DictionaryEntry)] {
        let all = shared.sections["sensations"]?.entries ?? [:]
        return all.map { (id: $0.key, entry: $0.value) }
            .sorted { $0.entry.nameZh < $1.entry.nameZh }
    }

    static func sensation(for name: String) -> DictionaryEntry? {
        shared.sections["sensations"]?.entries[name]
    }
}
