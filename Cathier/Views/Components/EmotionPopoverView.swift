import SwiftUI

struct EmotionPopoverView: View {
    let emotion: Emotion
    let categoryColor: Color
    var onSimilarTap: ((String) -> Void)?
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: emoji + name + intensity bar
            HStack {
                Text("\(emotion.emoji) \(emotion.nameZh)")
                    .font(.headline)
                Spacer()
                intensityBar
            }

            // Description
            if let desc = emotion.descriptionText, !desc.isEmpty {
                Text(desc)
                    .font(.custom("InstrumentSerif-Regular", size: 15))
                    .foregroundStyle(.primary)
                    .lineSpacing(4)
            }

            // Similar emotions + inline differs
            if let similar = emotion.similarTo, !similar.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(similar, id: \.self) { name in
                        HStack(alignment: .top, spacing: 4) {
                            Button(name) {
                                onSimilarTap?(name)
                            }
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(themeManager.accentColor)

                            if let diff = emotion.differs?[name] {
                                Text(diff)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 280)
        .background(Color.cathierSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(.separator), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
    }

    private var intensityBar: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(level <= emotion.intensity ? categoryColor : categoryColor.opacity(0.2))
                    .frame(width: 12, height: 4)
            }
        }
    }
}
