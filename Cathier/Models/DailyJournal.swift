import Foundation
import SwiftData

// MARK: - Mood Enum

enum DailyMood: String, CaseIterable, Identifiable {
    case veryHappy = "veryHappy"
    case good      = "good"
    case okay      = "okay"
    case notGreat  = "notGreat"
    case bad       = "bad"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .veryHappy: return "😄"
        case .good:      return "😊"
        case .okay:      return "😐"
        case .notGreat:  return "😔"
        case .bad:       return "😢"
        }
    }

    func label(for language: AppLanguage) -> String {
        switch language {
        case .zh: return labelZh
        case .en: return labelEn
        case .ja: return labelJa
        }
    }

    private var labelZh: String {
        switch self {
        case .veryHappy: return "很开心"
        case .good:      return "不错"
        case .okay:      return "还好"
        case .notGreat:  return "不太好"
        case .bad:       return "很难过"
        }
    }

    private var labelEn: String {
        switch self {
        case .veryHappy: return "Very Happy"
        case .good:      return "Good"
        case .okay:      return "Okay"
        case .notGreat:  return "Not Great"
        case .bad:       return "Sad"
        }
    }

    private var labelJa: String {
        switch self {
        case .veryHappy: return "とても幸せ"
        case .good:      return "良い"
        case .okay:      return "まあまあ"
        case .notGreat:  return "あまりよくない"
        case .bad:       return "悲しい"
        }
    }
}

// MARK: - DailyJournal Model

@Model
final class DailyJournal {
    var id: UUID = UUID()
    /// Creation date; day component is used to enforce one entry per day.
    var date: Date = Date()
    /// Stores `DailyMood.rawValue`.
    var mood: String = ""
    /// Today's gains, learnings, or reflections.
    var gains: String = ""
    /// Whether the entry is shared with friends.
    var isShared: Bool = false
    /// Whether the mood field is included when sharing.
    var shareMood: Bool = true
    /// Whether the gains field is included when sharing.
    var shareGains: Bool = true

    init(
        date: Date = Date(),
        mood: String,
        gains: String,
        isShared: Bool = false,
        shareMood: Bool = true,
        shareGains: Bool = true
    ) {
        self.id = UUID()
        self.date = date
        self.mood = mood
        self.gains = gains
        self.isShared = isShared
        self.shareMood = shareMood
        self.shareGains = shareGains
    }

    var dailyMood: DailyMood? {
        DailyMood(rawValue: mood)
    }
}
