import SwiftUI

struct CheckInCard: View {
    let checkIn: CheckIn
    @State private var showDetail = false

    var body: some View {
        Button(action: { showDetail = true }) {
            VStack(alignment: .leading, spacing: 10) {
                // Top row: time + intensity badge
                HStack {
                    Text(timeString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    IntensityBadge(intensity: checkIn.intensity)
                }

                // Body parts + sensations
                if !checkIn.bodyParts.isEmpty || !checkIn.sensations.isEmpty {
                    let bodyText = [checkIn.bodyParts, checkIn.sensations]
                        .flatMap { $0 }
                        .joined(separator: " · ")
                    Text(bodyText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                // Emotion tags
                if !checkIn.emotions.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(checkIn.emotions, id: \.self) { emotion in
                            let color = EmotionData.category(for: emotion)?.color ?? .orange
                            Text(emotion)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(color.opacity(0.15))
                                .foregroundColor(color)
                                .clipShape(Capsule())
                        }
                    }
                }

                // AI feedback preview
                if !checkIn.aiFeedback.isEmpty {
                    Divider()
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .padding(.top, 2)
                        Text(markdownText(checkIn.aiFeedback))
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .lineLimit(3)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // Note preview
                if !checkIn.note.isEmpty {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "pencil")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                        Text(checkIn.note)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
            }
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            CheckInDetailView(checkIn: checkIn)
        }
    }

    private func markdownText(_ raw: String) -> AttributedString {
        (try? AttributedString(markdown: raw,
            options: .init(interpretedSyntax: .inlinesOnlyPreservingWhitespace)))
        ?? AttributedString(raw)
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: checkIn.date)
    }
}
