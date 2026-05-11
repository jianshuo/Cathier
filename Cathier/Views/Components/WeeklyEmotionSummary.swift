import SwiftUI

struct WeeklyEmotionSummary: View {
    let topEmotions: [(emotion: String, count: Int)]
    @Environment(LanguageManager.self) private var lm

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(sectionTitle)
                .font(.headline)
            FlowLayout(spacing: 8) {
                ForEach(Array(topEmotions.enumerated()), id: \.offset) { _, item in
                    let color = EmotionData.category(for: item.emotion)?.color ?? .cathierAccent
                    let emoji = EmotionData.emoji(for: item.emotion)
                    let name = lm.display(item.emotion)
                    HStack(spacing: 4) {
                        Text(emoji.isEmpty ? name : "\(emoji) \(name)")
                            .font(.caption)
                            .fontWeight(.medium)
                        if item.count > 1 {
                            Text("×\(item.count)")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(color.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.12))
                    .foregroundColor(color)
                    .clipShape(Capsule())
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var sectionTitle: String {
        switch lm.currentLanguage {
        case .zh: return "本周情绪"
        case .ja: return "今週の気持ち"
        default:  return "This Week"
        }
    }
}
