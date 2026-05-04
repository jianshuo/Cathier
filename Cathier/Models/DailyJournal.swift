import Foundation
import SwiftData
import SwiftUI

// MARK: - Mood Enum

enum DailyMood: String, CaseIterable, Identifiable {
    // rawValues preserved for CloudKit / SwiftData backward compatibility.
    // The 5 original cases reuse the old rawValues so stored data still decodes.
    case passionate    = "passionate"
    case joyful        = "veryHappy"
    case sunny         = "sunny"
    case cheerful      = "good"
    case lightFeeling  = "light"
    case calm          = "okay"
    case serene        = "serene"
    case thoughtful    = "thoughtful"
    case introspective = "introspective"
    case tender        = "tender"
    case wistful       = "wistful"
    case nostalgic     = "nostalgic"
    case heavy         = "notGreat"
    case weary         = "weary"
    case somber        = "bad"
    case overwhelmed   = "overwhelmed"

    var id: String { rawValue }

    // MARK: Color

    var colorHex: String {
        switch self {
        case .passionate:    return "#E84040"
        case .joyful:        return "#F2700A"
        case .sunny:         return "#F5A020"
        case .cheerful:      return "#8BBF3A"
        case .lightFeeling:  return "#3DB86B"
        case .calm:          return "#20A890"
        case .serene:        return "#3AAAC8"
        case .thoughtful:    return "#3870C0"
        case .introspective: return "#5850B0"
        case .tender:        return "#9858A8"
        case .wistful:       return "#C870A0"
        case .nostalgic:     return "#E07878"
        case .heavy:         return "#B88060"
        case .weary:         return "#8890A0"
        case .somber:        return "#4A6070"
        case .overwhelmed:   return "#2E3E50"
        }
    }

    var themeColor: Color {
        Color(hex: colorHex) ?? .orange
    }

    // Legacy emoji kept for views that still reference it
    var emoji: String {
        switch self {
        case .passionate:    return "🔥"
        case .joyful:        return "😄"
        case .sunny:         return "☀️"
        case .cheerful:      return "😊"
        case .lightFeeling:  return "🌿"
        case .calm:          return "😌"
        case .serene:        return "💧"
        case .thoughtful:    return "💭"
        case .introspective: return "🔮"
        case .tender:        return "🌸"
        case .wistful:       return "🌧️"
        case .nostalgic:     return "🍂"
        case .heavy:         return "😔"
        case .weary:         return "😮‍💨"
        case .somber:        return "😢"
        case .overwhelmed:   return "🌑"
        }
    }

    // MARK: Labels

    func label(for language: AppLanguage) -> String {
        switch language {
        case .zh: return labelZh
        case .ja: return labelJa
        default:  return labelEn
        }
    }

    private var labelZh: String {
        switch self {
        case .passionate:    return "热情"
        case .joyful:        return "喜悦"
        case .sunny:         return "明朗"
        case .cheerful:      return "愉快"
        case .lightFeeling:  return "轻盈"
        case .calm:          return "平静"
        case .serene:        return "宁静"
        case .thoughtful:    return "思索"
        case .introspective: return "内省"
        case .tender:        return "温柔"
        case .wistful:       return "惆怅"
        case .nostalgic:     return "哀愁"
        case .heavy:         return "沉重"
        case .weary:         return "疲惫"
        case .somber:        return "低沉"
        case .overwhelmed:   return "压抑"
        }
    }

    private var labelEn: String {
        switch self {
        case .passionate:    return "Passionate"
        case .joyful:        return "Joyful"
        case .sunny:         return "Sunny"
        case .cheerful:      return "Cheerful"
        case .lightFeeling:  return "Light"
        case .calm:          return "Calm"
        case .serene:        return "Serene"
        case .thoughtful:    return "Thoughtful"
        case .introspective: return "Introspective"
        case .tender:        return "Tender"
        case .wistful:       return "Wistful"
        case .nostalgic:     return "Nostalgic"
        case .heavy:         return "Heavy"
        case .weary:         return "Weary"
        case .somber:        return "Somber"
        case .overwhelmed:   return "Overwhelmed"
        }
    }

    private var labelJa: String {
        switch self {
        case .passionate:    return "情熱"
        case .joyful:        return "喜び"
        case .sunny:         return "晴れやか"
        case .cheerful:      return "楽しい"
        case .lightFeeling:  return "軽やか"
        case .calm:          return "穏やか"
        case .serene:        return "静寂"
        case .thoughtful:    return "思索"
        case .introspective: return "内省"
        case .tender:        return "優しさ"
        case .wistful:       return "物悲しい"
        case .nostalgic:     return "哀愁"
        case .heavy:         return "重い"
        case .weary:         return "疲れ"
        case .somber:        return "沈んだ"
        case .overwhelmed:   return "圧倒"
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

    init(
        date: Date = Date(),
        mood: String,
        gains: String,
        isShared: Bool = false
    ) {
        self.id = UUID()
        self.date = date
        self.mood = mood
        self.gains = gains
        self.isShared = isShared
    }

    var dailyMood: DailyMood? {
        DailyMood(rawValue: mood)
    }
}
