import SwiftUI

struct CheckInCard: View {
    let checkIn: CheckIn
    @State private var showDetail = false
    @State private var showCopied = false
    @Environment(LanguageManager.self) private var lm

    var body: some View {
        Button(action: { showDetail = true }) {
            VStack(alignment: .leading, spacing: 10) {
                // Top row: time + share indicator + intensity badge
                HStack {
                    Text(timeString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if checkIn.shareLevel != nil {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                            .foregroundColor(.cathierAccent.opacity(0.8))
                    }
                    Spacer()
                    IntensityBadge(intensity: checkIn.intensity, label: lm.aiIntensityBadge(checkIn.intensity))
                }

                // Body parts + sensations (grouped per body part)
                if !checkIn.bodyParts.isEmpty || !checkIn.sensations.isEmpty {
                    bodySensationView
                }

                // Emotion tags
                if !checkIn.emotions.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(checkIn.emotions, id: \.self) { emotion in
                            let color = EmotionData.category(for: emotion)?.color ?? .cathierAccent
                            let emoji = EmotionData.emoji(for: emotion)
                            Text(emoji.isEmpty ? emotion : "\(emoji) \(emotion)")
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
                        Image(systemName: showCopied ? "checkmark" : "sparkles")
                            .font(.caption2)
                            .foregroundColor(showCopied ? .cathierAccent : .cathierAccent)
                            .padding(.top, 2)
                            .animation(.easeOut(duration: 0.1), value: showCopied)
                        Text(StructuredFeedback.parse(checkIn.aiFeedback)?.previewText ?? checkIn.aiFeedback)
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !checkIn.aiFeedback.isEmpty {
                Button {
                    copyAIFeedback()
                } label: {
                    Label(lm.detailCopyAI, systemImage: "doc.on.doc")
                }
            }
        }
        .sheet(isPresented: $showDetail) {
            CheckInDetailView(checkIn: checkIn)
        }
    }

    private var bodySensationView: some View {
        let grouped = groupedSensations(checkIn.sensations)
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(checkIn.bodyParts, id: \.self) { part in
                let sensations = grouped[part] ?? []
                let partName = lm.display(part)
                HStack(spacing: 4) {
                    Text(partName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.cathierAccent)
                    if !sensations.isEmpty {
                        Text(sensations.map { lm.display($0) }.joined(separator: " · "))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            // Legacy data without body part prefix
            let unmatched = checkIn.sensations
                .filter { !$0.contains(":") }
                .map { lm.display($0) }
            if !unmatched.isEmpty {
                Text(unmatched.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func groupedSensations(_ sensations: [String]) -> [String: [String]] {
        var result: [String: [String]] = [:]
        for s in sensations {
            let components = s.split(separator: ":", maxSplits: 1).map(String.init)
            if components.count == 2 {
                result[components[0], default: []].append(components[1])
            }
        }
        return result
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: checkIn.date)
    }

    private func copyAIFeedback() {
        let text: String
        if let s = StructuredFeedback.parse(checkIn.aiFeedback) {
            text = [s.summary, s.insight, s.connection, s.suggestion]
                .filter { !$0.isEmpty }
                .joined(separator: "\n\n")
        } else {
            text = checkIn.aiFeedback
        }
        UIPasteboard.general.string = text
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeOut(duration: 0.1)) { showCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.2)) { showCopied = false }
        }
    }
}
