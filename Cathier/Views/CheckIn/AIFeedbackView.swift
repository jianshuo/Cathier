import SwiftUI
import SwiftData

struct AIFeedbackView: View {
    @Environment(CheckInViewModel.self) private var viewModel
    @Environment(FriendViewModel.self) private var friendVM
    @Environment(\.modelContext) private var modelContext
    @Environment(LanguageManager.self) private var lm
    @Environment(ThemeManager.self) private var themeManager
    let onDismiss: () -> Void

    // Persist last chosen tier; "none" = don't share, defaults to "full"
    @AppStorage("lastShareTierRaw") private var lastShareTierRaw: String = FriendCheckIn.PrivacyTier.full.rawValue
    @State private var selectedTier: FriendCheckIn.PrivacyTier? = nil
    @State private var shareAIFeedback: Bool = false
    @State private var shareToPlaza: Bool = false
    @State private var plazaTier: FriendCheckIn.PrivacyTier = .emotions
    @State private var showExercise = false
    @State private var aiFeedbackCopied = false

    private var hasFriends: Bool { friendVM.currentProfile != nil && !friendVM.friends.isEmpty }
    private var hasProfile: Bool { friendVM.currentProfile != nil }

    var body: some View {
        standardBody
    }

    // MARK: - Standard layout

    private var standardBody: some View {
        @Bindable var vm = viewModel
        return ScrollView {
            VStack(spacing: 24) {
                summaryCard
                aiFeedbackCard

                if !viewModel.aiFeedback.isEmpty && !viewModel.isLoadingAI {
                    exerciseButton
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(lm.aiNoteLabel)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField(lm.aiNotePlaceholder, text: $vm.note, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(3...6)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }

                if hasFriends {
                    shareSection
                }

                if hasProfile {
                    plazaSection
                }

                Button(action: saveAction) {
                    Text(lm.aiSave)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(themeManager.accentColor)
                .clipShape(Capsule())
                .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .onAppear {
            selectedTier = FriendCheckIn.PrivacyTier(rawValue: lastShareTierRaw)
        }
        .onChange(of: selectedTier) { _, newTier in
            lastShareTierRaw = newTier?.rawValue ?? "none"
        }
        .task {
            if viewModel.aiFeedback.isEmpty && !viewModel.isLoadingAI {
                let history = fetchRecentHistory()
                let freq = emotionFrequency()
                await viewModel.fetchAIFeedback(recentHistory: history, emotionFrequency: freq)
            }
        }
        .sheet(isPresented: $showExercise) {
            MicroExerciseView(
                bodyParts: Array(viewModel.selectedBodyParts),
                sensations: viewModel.encodedSensations,
                emotions: viewModel.allEmotions
            )
            .environment(lm)
        }
    }

    // MARK: - Micro-exercise button

    private var exerciseButton: some View {
        Button(action: { showExercise = true }) {
            HStack(spacing: 10) {
                Image(systemName: "wind")
                    .font(.subheadline)
                    .foregroundColor(.cathierSage)
                VStack(alignment: .leading, spacing: 2) {
                    Text(lm.exerciseTryThis)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text(lm.exerciseTryHint)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(Color.cathierSageLight)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Share section

    private var shareSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.caption)
                    .foregroundColor(themeManager.accentColor)
                Text(lm.aiShareTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            VStack(spacing: 8) {
                // Not sharing option
                tierRow(label: lm.aiDontShare, description: lm.aiOnlySelf, icon: "lock.fill", tier: nil)
                Divider()
                ForEach(FriendCheckIn.PrivacyTier.allCases) { tier in
                    tierRow(label: tierDisplayName(tier), description: tierDescription(tier),
                            icon: tierIcon(tier), tier: tier)
                    if tier != FriendCheckIn.PrivacyTier.allCases.last {
                        Divider()
                    }
                }

                // AI feedback toggle (shown when sharing at non-full tier with AI feedback available)
                if let tier = selectedTier, tier != .full, !viewModel.aiFeedback.isEmpty {
                    Divider()
                    aiFeedbackToggleRow
                }
            }
            .padding(12)
            .background(Color.cathierSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func tierDisplayName(_ tier: FriendCheckIn.PrivacyTier) -> String {
        switch tier {
        case .category: return lm.tierCategoryName
        case .emotions: return lm.tierEmotionsName
        case .full:     return lm.tierFullName
        }
    }

    private func tierDescription(_ tier: FriendCheckIn.PrivacyTier) -> String {
        switch tier {
        case .category: return lm.tierCategoryDesc
        case .emotions: return lm.tierEmotionsDesc
        case .full:     return lm.tierFullDesc
        }
    }

    private func tierRow(label: String, description: String, icon: String,
                         tier: FriendCheckIn.PrivacyTier?) -> some View {
        let isSelected = selectedTier == tier
        return Button(action: { selectedTier = tier }) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? themeManager.accentColor : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .medium : .regular)
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func tierIcon(_ tier: FriendCheckIn.PrivacyTier) -> String {
        switch tier {
        case .category: return "tag.fill"
        case .emotions: return "heart.fill"
        case .full: return "doc.text.fill"
        }
    }

    private var aiFeedbackToggleRow: some View {
        Toggle(isOn: $shareAIFeedback) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .foregroundColor(themeManager.accentColor)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 2) {
                    Text(lm.aiShareAIFeedbackToggle)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Text(lm.aiShareAIFeedbackDesc)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .tint(themeManager.accentColor)
    }

    // MARK: - Plaza section

    private var plazaSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "person.3.fill")
                    .font(.caption)
                    .foregroundColor(.cathierSage)
                Text(lm.plazaShareSectionTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            VStack(spacing: 0) {
                Toggle(isOn: $shareToPlaza) {
                    HStack(spacing: 12) {
                        Image(systemName: "globe.asia.australia.fill")
                            .foregroundColor(.cathierSage)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(lm.plazaShareToggle)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Text(lm.plazaShareDesc)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .tint(.cathierSage)
                .padding(12)

                if shareToPlaza {
                    Divider().padding(.horizontal, 12)
                    plazaTierPicker.padding(12)
                }
            }
            .background(Color.cathierSageLight)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var plazaTierPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(FriendCheckIn.PrivacyTier.allCases) { tier in
                plazaTierRow(tier)
                if tier != FriendCheckIn.PrivacyTier.allCases.last {
                    Divider()
                }
            }
        }
    }

    private func plazaTierRow(_ tier: FriendCheckIn.PrivacyTier) -> some View {
        let isSelected = plazaTier == tier
        return Button(action: { plazaTier = tier }) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .cathierSage : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tierDisplayName(tier))
                        .font(.subheadline)
                        .fontWeight(isSelected ? .medium : .regular)
                        .foregroundColor(.primary)
                    Text(plazaTierDescription(tier))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    private func plazaTierDescription(_ tier: FriendCheckIn.PrivacyTier) -> String {
        switch tier {
        case .category: return lm.plazaTierCategoryDesc
        case .emotions: return lm.plazaTierEmotionsDesc
        case .full:     return lm.plazaTierFullDesc
        }
    }

    // MARK: - History

    private func fetchRecentHistory() -> [CheckIn] {
        var descriptor = FetchDescriptor<CheckIn>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 20
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return ClaudeService.smartSample(
            from: all,
            currentBodyParts: Array(viewModel.selectedBodyParts),
            currentEmotions: viewModel.allEmotions,
            limit: 10
        )
    }

    /// Count emotion frequency from recent check-ins for vocabulary coaching.
    private func emotionFrequency() -> [(String, Int)] {
        var descriptor = FetchDescriptor<CheckIn>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 10
        let recent = (try? modelContext.fetch(descriptor)) ?? []
        var counts: [String: Int] = [:]
        for checkIn in recent {
            for emotion in checkIn.emotions {
                counts[emotion, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }.prefix(3).map { ($0.key, $0.value) }
    }

    // MARK: - Save action

    private func saveAction() {
        let checkIn = viewModel.save(context: modelContext)
        if let tier = selectedTier {
            let includeAI = tier == .full ? false : shareAIFeedback
            Task { try? await friendVM.shareCheckIn(checkIn, tier: tier, shareAIFeedback: includeAI) }
        }
        if shareToPlaza, let profile = friendVM.currentProfile {
            let post = PlazaPost(ownerProfile: profile, checkIn: checkIn, privacyTier: plazaTier, shareAIFeedback: plazaTier == .full)
            checkIn.isPlazaShared = true
            Task { try? await CloudKitService.shared.savePlazaPost(post) }
        }
        onDismiss()
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(lm.aiFeelingsSummary)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                IntensityBadge(intensity: Int(viewModel.intensity), label: lm.aiIntensityBadge(Int(viewModel.intensity)))
            }

            if !viewModel.selectedBodyParts.isEmpty {
                labelRow(icon: "figure.mind.and.body",
                         items: viewModel.selectedBodyParts.map { lm.display($0) })
            }

            if !viewModel.allSelectedSensations.isEmpty {
                labelRow(icon: "waveform",
                         items: viewModel.allSelectedSensations.map { lm.display($0) })
            }

            if !viewModel.allEmotions.isEmpty {
                emotionRow
            }

            if !viewModel.triggerEvent.trimmingCharacters(in: .whitespaces).isEmpty {
                labelRow(icon: "bolt.fill",
                         items: [viewModel.triggerEvent.trimmingCharacters(in: .whitespaces)])
            }
        }
        .padding(16)
        .background(Color.cathierSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func labelRow(icon: String, items: [String]) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 16)
            Text(items.joined(separator: " · "))
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }

    private var emotionRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "heart.fill")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 16)
            FlowLayout(spacing: 6) {
                ForEach(viewModel.allEmotions, id: \.self) { emotion in
                    let color = EmotionData.category(for: emotion)?.color ?? themeManager.accentColor
                    Text(lm.display(emotion))
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
    }

    // MARK: - Persona Picker

    private var personaPicker: some View {
        Menu {
            ForEach(AICompanionPersona.allCases.filter { $0 != .brainTrainer }) { p in
                Button(action: {
                    guard viewModel.persona != p else { return }
                    viewModel.persona = p
                    viewModel.aiFeedback = ""
                    viewModel.aiError = nil
                    Task {
                        let history = fetchRecentHistory()
                        let freq = emotionFrequency()
                        await viewModel.fetchAIFeedback(recentHistory: history, emotionFrequency: freq)
                    }
                }) {
                    Label {
                        VStack(alignment: .leading) {
                            Text(p.displayName(lm))
                            Text(p.displayDescription(lm))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: p.icon)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: viewModel.persona.icon)
                    .font(.caption)
                Text(viewModel.persona.displayName(lm))
                    .font(.subheadline)
                    .fontWeight(.medium)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(themeManager.accentColor.opacity(0.1))
            .foregroundColor(themeManager.accentColor)
            .clipShape(Capsule())
        }
    }

    // MARK: - AI Feedback Card

    private func copyAIFeedback() {
        UIPasteboard.general.string = viewModel.aiFeedback
        withAnimation(.easeInOut(duration: 0.2)) { aiFeedbackCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.2)) { aiFeedbackCopied = false }
        }
    }

    private var aiFeedbackCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundColor(themeManager.accentColor)
                Text(lm.aiCompanion)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                if !viewModel.aiFeedback.isEmpty && !viewModel.isLoadingAI {
                    Button(action: copyAIFeedback) {
                        Image(systemName: aiFeedbackCopied ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                            .foregroundColor(aiFeedbackCopied ? .cathierSage : .secondary)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(lm.detailCopyAI)
                    .animation(.easeInOut(duration: 0.2), value: aiFeedbackCopied)
                }
                personaPicker
            }

            if viewModel.isLoadingAI {
                loadingView
            } else if let error = viewModel.aiError {
                errorView(error)
            } else if !viewModel.aiFeedback.isEmpty {
                if let structured = StructuredFeedback.parse(viewModel.aiFeedback) {
                    StructuredFeedbackView(feedback: structured)
                        .transition(.opacity)
                } else {
                    MarkdownText(raw: viewModel.aiFeedback,
                                 font: .cathierSerif(.body),
                                 paragraphSpacing: 8,
                                 lineSpacing: 5)
                        .foregroundColor(.primary)
                        .transition(.opacity)
                }
            }
        }
        .padding(16)
        .background(themeManager.accentColor.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(themeManager.accentColor.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animation(.easeInOut, value: viewModel.isLoadingAI)
    }

    private var loadingView: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(themeManager.accentColor)
            Text(lm.aiLoading)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }

    private func errorView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button(action: {
                Task { await viewModel.fetchAIFeedback() }
            }) {
                Text(lm.aiRetry)
                    .font(.subheadline)
                    .foregroundColor(themeManager.accentColor)
            }
        }
    }
}

// MARK: - Structured Feedback View

struct StructuredFeedbackView: View {
    let feedback: StructuredFeedback
    @Environment(LanguageManager.self) private var lm
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            feedbackRow(icon: "waveform", titleKey: "summary", content: feedback.summary, color: themeManager.accentColor)
            Divider().padding(.leading, 26)
            feedbackRow(icon: "sparkles", titleKey: "insight", content: feedback.insight, color: themeManager.accentColor)
            Divider().padding(.leading, 26)
            feedbackRow(icon: "figure.mind.and.body", titleKey: "connection", content: feedback.connection, color: .cathierSage)
            Divider().padding(.leading, 26)
            feedbackRow(icon: "lightbulb", titleKey: "suggestion", content: feedback.suggestion, color: .cathierSage)
        }
    }

    private func sectionTitle(_ key: String) -> String {
        switch lm.currentLanguage {
        case .zh:
            switch key {
            case "summary":    return "此刻状态"
            case "insight":    return "值得注意"
            case "connection": return "身心联系"
            case "suggestion": return "可以尝试"
            default: return key
            }
        case .ja:
            switch key {
            case "summary":    return "今の状態"
            case "insight":    return "気づき"
            case "connection": return "身心のつながり"
            case "suggestion": return "やってみよう"
            default: return key
            }
        default:
            switch key {
            case "summary":    return "Current State"
            case "insight":    return "Key Insight"
            case "connection": return "Body & Mind"
            case "suggestion": return "Try This"
            default: return key
            }
        }
    }

    @ViewBuilder
    private func feedbackRow(icon: String, titleKey: String, content: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 16, alignment: .center)
                .padding(.top, 3)
            VStack(alignment: .leading, spacing: 4) {
                Text(sectionTitle(titleKey))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Text(content)
                    .font(.cathierSerif(.body))
                    .foregroundColor(.primary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Intensity Badge

struct IntensityBadge: View {
    let intensity: Int
    var label: String? = nil

    var body: some View {
        Text(label ?? "强度 \(intensity)/10")
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(intensityColor.opacity(0.15))
            .foregroundColor(intensityColor)
            .clipShape(Capsule())
    }

    private var intensityColor: Color {
        switch intensity {
        case ..<4: return .yellow
        case ..<7: return .orange
        default:   return .red
        }
    }
}
