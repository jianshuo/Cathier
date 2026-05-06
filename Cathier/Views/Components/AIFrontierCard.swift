import SwiftUI

struct AIFrontierCard: View {
    let news: DailyAINews
    var onRegenerate: (() -> Void)? = nil
    @Environment(LanguageManager.self) private var lm

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            content
        }
        .background(Color.cathierSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.cathierAccent.opacity(0.25), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.cathierAccent)
                    .frame(width: 6, height: 6)
                Text(headerTitle)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.cathierAccent)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            Spacer()
            if let onRegenerate {
                Button(action: onRegenerate) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundColor(Color.cathierAccent)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.cathierAccentLight)
    }

    private var content: some View {
        Text(news.headline)
            .font(.cathierSerif(.body))
            .foregroundColor(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(14)
    }

    private var headerTitle: String {
        switch lm.currentLanguage {
        case .zh: return "今日AI最前沿"
        case .ja: return "今日のAIフロンティア"
        default:  return "AI Frontier"
        }
    }
}
