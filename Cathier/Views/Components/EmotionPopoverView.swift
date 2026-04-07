import SwiftUI

struct EmotionPopoverView: View {
    let emotion: Emotion
    let categoryColor: Color
    var onSimilarTap: ((String) -> Void)?

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
                    .foregroundStyle(Color.cathierTextPrimary)
                    .lineSpacing(4)
            }

            // Similar emotions
            if let similar = emotion.similarTo, !similar.isEmpty {
                HStack(spacing: 4) {
                    Text("相似:")
                        .font(.caption)
                        .foregroundStyle(Color.cathierTextSecondary)
                    ForEach(Array(similar.enumerated()), id: \.offset) { index, name in
                        if index > 0 {
                            Text("·")
                                .font(.caption)
                                .foregroundStyle(Color.cathierTextMuted)
                        }
                        Button(name) {
                            onSimilarTap?(name)
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.cathierAccent)
                    }
                }

                // Differs
                if let differs = emotion.differs {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(differs.keys.sorted()), id: \.self) { key in
                            if let diff = differs[key] {
                                Text("vs \(key): \(diff)")
                                    .font(.caption)
                                    .foregroundStyle(Color.cathierTextSecondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: 280)
        .background(Color.cathierSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.cathierBorder, lineWidth: 1)
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
