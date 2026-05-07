import SwiftUI
import SwiftData

struct CheckInDetailView: View {
    let checkIn: CheckIn
    @Environment(\.dismiss) private var dismiss
    @Environment(LanguageManager.self) private var lm
    @Environment(FriendViewModel.self) private var friendVM
    @Query(sort: \CheckIn.date, order: .reverse) private var allCheckIns: [CheckIn]
    @State private var isBusy = false
    @State private var shareError: String?
    @State private var aiFeedbackCopied = false
    @State private var dictionaryItem: DictionaryEmotionItem?

    private struct DictionaryEmotionItem: Identifiable {
        let id = UUID()
        let entry: DictionaryEntry
        let color: Color
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Header: date + intensity
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dateString)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(timeString)
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            IntensityBadge(intensity: checkIn.intensity, label: lm.aiIntensityBadge(checkIn.intensity))
                            if let ctx = intensityContext {
                                Text(ctx.label)
                                    .font(.caption2)
                                    .foregroundColor(ctx.color)
                            }
                        }
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
                                            chip(lm.display(part), color: .cathierAccent)
                                        }
                                    }
                                }
                                if !parsed.global.isEmpty {
                                    FlowLayout(spacing: 8) {
                                        ForEach(parsed.global, id: \.self) { s in
                                            chip(lm.display(s), color: .cathierAccent)
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
                                            .foregroundColor(.cathierAccent)
                                        FlowLayout(spacing: 6) {
                                            ForEach(entry.sensations, id: \.self) { s in
                                                chip(lm.display(s), color: .cathierAccent)
                                            }
                                        }
                                    }
                                }
                                if !parsed.global.isEmpty {
                                    FlowLayout(spacing: 8) {
                                        ForEach(parsed.global, id: \.self) { s in
                                            chip(lm.display(s), color: .cathierAccent)
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
                                    let color = EmotionData.category(for: emotion)?.color ?? .cathierAccent
                                    let emoji = EmotionData.emoji(for: emotion)
                                    Button {
                                        if let em = EmotionData.emotion(for: emotion),
                                           let entry = DictionaryService.emotion(for: em.id) {
                                            dictionaryItem = DictionaryEmotionItem(entry: entry, color: color)
                                        }
                                    } label: {
                                        chip(emoji.isEmpty ? emotion : "\(emoji) \(emotion)",
                                             color: color,
                                             count: emotionFrequency[emotion])
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityHint(lm.currentLanguage == .zh ? "点击深入了解" : lm.currentLanguage == .ja ? "タップして詳細を見る" : "Tap to explore")
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
                            HStack {
                                Label(lm.aiCompanion, systemImage: "sparkles")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.cathierAccent)
                                Spacer()
                                ShareLink(item: aiFeedbackShareText) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 28, height: 28)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(lm.currentLanguage == .zh ? "分享" : lm.currentLanguage == .ja ? "共有" : "Share")
                                Button(action: copyAIFeedback) {
                                    Image(systemName: aiFeedbackCopied ? "checkmark" : "doc.on.doc")
                                        .font(.caption)
                                        .foregroundColor(aiFeedbackCopied ? .cathierAccent : .secondary)
                                        .frame(width: 28, height: 28)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(lm.detailCopyAI)
                                .animation(.easeInOut(duration: 0.2), value: aiFeedbackCopied)
                            }
                            if let structured = StructuredFeedback.parse(checkIn.aiFeedback) {
                                StructuredFeedbackView(feedback: structured)
                            } else {
                                MarkdownText(raw: checkIn.aiFeedback,
                                             font: .body,
                                             paragraphSpacing: 8,
                                             lineSpacing: 5)
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.cathierAccent.opacity(0.25), lineWidth: 1)
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
                                .font(.cathierSerif(.body))
                                .foregroundColor(.primary)
                                .lineSpacing(4)
                        }
                    }

                    // Share settings
                    shareSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle(lm.detailNavTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ShareLink(item: fullCheckInSummaryText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel(shareFullLabel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(lm.detailDone) { dismiss() }
                }
            }
            .sheet(item: $dictionaryItem) { item in
                EmotionDictionarySheet(entry: item.entry, categoryColor: item.color)
            }
        }
    }

    // MARK: - Share section

    private var currentTier: FriendCheckIn.PrivacyTier? {
        checkIn.shareLevel.flatMap { FriendCheckIn.PrivacyTier(rawValue: $0) }
    }

    @ViewBuilder
    private var shareSection: some View {
        let isShared = currentTier != nil
        sectionCard {
            Label("分享给好友", systemImage: "person.2.fill")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            if isShared, let tier = currentTier {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.cathierAccent)
                    Text(tier.displayName)
                        .font(.subheadline)
                    Text("·")
                        .foregroundColor(.secondary)
                    Text(tier.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 10) {
                    Menu {
                        ForEach(FriendCheckIn.PrivacyTier.allCases) { t in
                            Button {
                                Task { await doShare(tier: t) }
                            } label: {
                                Label(t.displayName, systemImage: t == tier ? "checkmark" : "")
                            }
                        }
                    } label: {
                        Label("修改级别", systemImage: "slider.horizontal.3")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isBusy)

                    Button(role: .destructive) {
                        Task { await doUnshare() }
                    } label: {
                        Label("取消分享", systemImage: "xmark.circle")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isBusy)
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.secondary)
                    Text("仅自己可见")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if friendVM.currentProfile != nil {
                    Menu {
                        ForEach(FriendCheckIn.PrivacyTier.allCases) { t in
                            Button {
                                Task { await doShare(tier: t) }
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(t.displayName)
                                    Text(t.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    } label: {
                        Label(isBusy ? "处理中…" : "分享给好友", systemImage: "square.and.arrow.up")
                            .font(.subheadline)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isBusy)
                } else {
                    Text("在「好友」页面设置账号后可分享")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let err = shareError {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isShared ? Color.cathierAccent.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    private func doShare(tier: FriendCheckIn.PrivacyTier) async {
        isBusy = true
        shareError = nil
        do {
            try await friendVM.shareCheckIn(checkIn, tier: tier)
        } catch {
            shareError = error.localizedDescription
        }
        isBusy = false
    }

    private func doUnshare() async {
        isBusy = true
        shareError = nil
        do {
            try await friendVM.unshareCheckIn(checkIn)
        } catch {
            shareError = error.localizedDescription
        }
        isBusy = false
    }

    // MARK: - Copy AI Feedback

    private func copyAIFeedback() {
        let text: String
        if let s = StructuredFeedback.parse(checkIn.aiFeedback) {
            text = [s.summary, s.insight, s.connection, s.suggestion].joined(separator: "\n\n")
        } else {
            text = checkIn.aiFeedback
        }
        UIPasteboard.general.string = text
        withAnimation(.easeInOut(duration: 0.2)) { aiFeedbackCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.2)) { aiFeedbackCopied = false }
        }
    }

    private var aiFeedbackShareText: String {
        if let s = StructuredFeedback.parse(checkIn.aiFeedback) {
            return [s.summary, s.insight, s.connection, s.suggestion]
                .filter { !$0.isEmpty }
                .joined(separator: "\n\n")
        }
        return checkIn.aiFeedback
    }

    private var shareFullLabel: String {
        switch lm.currentLanguage {
        case .zh: return "分享记录"
        case .ja: return "記録を共有"
        default:  return "Share record"
        }
    }

    private var fullCheckInSummaryText: String {
        var lines: [String] = []

        lines.append("\(dateString)  \(timeString)")
        lines.append("")

        let intensityLabel: String
        switch lm.currentLanguage {
        case .zh: intensityLabel = "强度"
        case .ja: intensityLabel = "強度"
        default:  intensityLabel = "Intensity"
        }
        lines.append("\(intensityLabel): \(checkIn.intensity)/10")

        if !checkIn.bodyParts.isEmpty || !checkIn.sensations.isEmpty {
            lines.append("")
            let bodyLabel: String
            switch lm.currentLanguage {
            case .zh: bodyLabel = "身体部位"
            case .ja: bodyLabel = "身体部位"
            default:  bodyLabel = "Body"
            }
            lines.append("\(bodyLabel):")
            let parsed = parsedSensations(checkIn.sensations)
            if parsed.perPart.isEmpty {
                for part in checkIn.bodyParts {
                    lines.append("· \(lm.display(part))")
                }
            } else {
                for entry in parsed.perPart {
                    let sensStr = entry.sensations.map { lm.display($0) }.joined(separator: ", ")
                    lines.append("· \(lm.display(entry.part)): \(sensStr)")
                }
            }
        }

        if !checkIn.emotions.isEmpty {
            lines.append("")
            let emotionLabel: String
            switch lm.currentLanguage {
            case .zh: emotionLabel = "情绪"
            case .ja: emotionLabel = "気持ち"
            default:  emotionLabel = "Emotions"
            }
            lines.append("\(emotionLabel): \(checkIn.emotions.map { lm.display($0) }.joined(separator: ", "))")
        }

        let trigger = checkIn.triggerEvent.trimmingCharacters(in: .whitespaces)
        if !trigger.isEmpty {
            lines.append("")
            let triggerLabel: String
            switch lm.currentLanguage {
            case .zh: triggerLabel = "发生了什么"
            case .ja: triggerLabel = "きっかけ"
            default:  triggerLabel = "Trigger"
            }
            lines.append("\(triggerLabel): \(trigger)")
        }

        if !checkIn.aiFeedback.isEmpty {
            lines.append("")
            let aiLabel: String
            switch lm.currentLanguage {
            case .zh: aiLabel = "AI 觉察"
            case .ja: aiLabel = "AI の気づき"
            default:  aiLabel = "AI Reflection"
            }
            lines.append("\(aiLabel):")
            if let s = StructuredFeedback.parse(checkIn.aiFeedback) {
                let parts = [s.summary, s.insight, s.connection, s.suggestion].filter { !$0.isEmpty }
                lines.append(parts.joined(separator: "\n\n"))
            } else {
                lines.append(checkIn.aiFeedback)
            }
        }

        let note = checkIn.note.trimmingCharacters(in: .whitespaces)
        if !note.isEmpty {
            lines.append("")
            let noteLabel: String
            switch lm.currentLanguage {
            case .zh: noteLabel = "我的想法"
            case .ja: noteLabel = "メモ"
            default:  noteLabel = "Notes"
            }
            lines.append("\(noteLabel):")
            lines.append(note)
        }

        return lines.joined(separator: "\n")
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

    private func chip(_ label: String, color: Color, count: Int? = nil) -> some View {
        HStack(spacing: 4) {
            Text(label)
            if let count, count > 1 {
                Text("×\(count)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(color.opacity(0.65))
            }
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.12))
        .foregroundColor(color)
        .clipShape(Capsule())
    }

    /// Count of times each emotion was recorded in the last 30 days, across all check-ins.
    private var emotionFrequency: [String: Int] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        var counts: [String: Int] = [:]
        for ci in allCheckIns where ci.date >= cutoff {
            for emotion in ci.emotions { counts[emotion, default: 0] += 1 }
        }
        return counts
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

    // MARK: - Intensity Baseline Context

    private struct IntensityContext {
        let label: String
        let color: Color
    }

    /// Compares this check-in's intensity to the 30-day average (excluding itself).
    /// Returns nil when there is insufficient history or the difference is not notable.
    private var intensityContext: IntensityContext? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recent = allCheckIns.filter { $0.id != checkIn.id && $0.date >= cutoff }
        guard recent.count >= 3 else { return nil }
        let avg = Double(recent.map(\.intensity).reduce(0, +)) / Double(recent.count)
        let diff = Double(checkIn.intensity) - avg
        guard abs(diff) >= 1.5 else { return nil }
        let avgText = String(format: "%.1f", avg)
        let label: String
        switch lm.currentLanguage {
        case .zh: label = diff > 0 ? "↑ 高于均值 \(avgText)" : "↓ 低于均值 \(avgText)"
        case .ja: label = diff > 0 ? "↑ 平均 \(avgText) より高" : "↓ 平均 \(avgText) より低"
        default:  label = diff > 0 ? "↑ Above avg \(avgText)" : "↓ Below avg \(avgText)"
        }
        return IntensityContext(label: label, color: diff > 0 ? .cathierAccent : .cathierAccent)
    }
}
