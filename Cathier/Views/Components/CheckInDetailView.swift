import SwiftUI

struct CheckInDetailView: View {
    let checkIn: CheckIn
    @Environment(\.dismiss) private var dismiss
    @Environment(LanguageManager.self) private var lm

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Header: date + intensity
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dateString)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(timeString)
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        Spacer()
                        IntensityBadge(intensity: checkIn.intensity, label: lm.aiIntensityBadge(checkIn.intensity))
                    }

                    // Body parts & sensations
                    if !checkIn.bodyParts.isEmpty || !checkIn.sensations.isEmpty {
                        sectionCard {
                            Label(lm.detailBodySection, systemImage: "figure.mind.and.body")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            let parsed = parsedSensations(checkIn.sensations)
                            if parsed.perPart.isEmpty {
                                // Legacy: flat sensation list with body parts shown separately
                                if !checkIn.bodyParts.isEmpty {
                                    FlowLayout(spacing: 8) {
                                        ForEach(checkIn.bodyParts, id: \.self) { part in
                                            chip(lm.display(part), color: .blue)
                                        }
                                    }
                                }
                                if !parsed.global.isEmpty {
                                    FlowLayout(spacing: 8) {
                                        ForEach(parsed.global, id: \.self) { s in
                                            chip(lm.display(s), color: .teal)
                                        }
                                    }
                                }
                            } else {
                                // New format: per-body-part sensations
                                ForEach(parsed.perPart, id: \.part) { entry in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(lm.display(entry.part))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.blue)
                                        FlowLayout(spacing: 6) {
                                            ForEach(entry.sensations, id: \.self) { s in
                                                chip(lm.display(s), color: .teal)
                                            }
                                        }
                                    }
                                }
                                if !parsed.global.isEmpty {
                                    FlowLayout(spacing: 8) {
                                        ForEach(parsed.global, id: \.self) { s in
                                            chip(lm.display(s), color: .teal)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Emotions
                    if !checkIn.emotions.isEmpty {
                        sectionCard {
                            Label(lm.detailEmotionsSection, systemImage: "heart.fill")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            FlowLayout(spacing: 8) {
                                ForEach(checkIn.emotions, id: \.self) { emotion in
                                    let color = EmotionData.category(for: emotion)?.color ?? .orange
                                    let emoji = EmotionData.emoji(for: emotion)
                                    chip(emoji.isEmpty ? emotion : "\(emoji) \(emotion)", color: color)
                                }
                            }
                        }
                    }

                    // Trigger event
                    if !checkIn.triggerEvent.isEmpty {
                        sectionCard {
                            Label(lm.detailTriggerSection, systemImage: "bolt.fill")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            Text(checkIn.triggerEvent)
                                .font(.body)
                                .foregroundColor(.primary)
                                .lineSpacing(4)
                        }
                    }

                    // AI feedback — full, no line limit, Markdown rendered
                    if !checkIn.aiFeedback.isEmpty {
                        sectionCard {
                            Label(lm.aiCompanion, systemImage: "sparkles")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                            MarkdownText(raw: checkIn.aiFeedback,
                                         font: .body,
                                         paragraphSpacing: 8,
                                         lineSpacing: 5)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
                        )
                    }

                    // Note — full, no line limit
                    if !checkIn.note.isEmpty {
                        sectionCard {
                            Label(lm.detailNoteSection, systemImage: "pencil")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            Text(checkIn.note)
                                .font(.body)
                                .foregroundColor(.primary)
                                .lineSpacing(4)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle(lm.detailNavTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(lm.detailDone) { dismiss() }
                }
            }
        }
    }

    // MARK: - Helpers

    struct ParsedSensations {
        var perPart: [(part: String, sensations: [String])]
        var global: [String]
    }

    private func parsedSensations(_ sensations: [String]) -> ParsedSensations {
        var perPartDict: [(part: String, sensations: [String])] = []
        var global: [String] = []
        for s in sensations {
            let components = s.split(separator: ":", maxSplits: 1).map(String.init)
            if components.count == 2 {
                let part = components[0], sensation = components[1]
                if let idx = perPartDict.firstIndex(where: { $0.part == part }) {
                    perPartDict[idx].sensations.append(sensation)
                } else {
                    perPartDict.append((part: part, sensations: [sensation]))
                }
            } else {
                global.append(s)
            }
        }
        return ParsedSensations(perPart: perPartDict, global: global)
    }

    @ViewBuilder
    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
    }

    private func chip(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.12))
            .foregroundColor(color)
            .clipShape(Capsule())
    }

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = lm.detailDateFormat
        return f.string(from: checkIn.date)
    }

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: checkIn.date)
    }
}
