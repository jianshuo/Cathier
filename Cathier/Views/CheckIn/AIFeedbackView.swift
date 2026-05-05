import SwiftUI
import SwiftData

struct AIFeedbackView: View {
    @Environment(CheckInViewModel.self) private var viewModel
    @Environment(FriendViewModel.self) private var friendVM
    @Environment(\.modelContext) private var modelContext
    @Environment(LanguageManager.self) private var lm
    let onDismiss: () -> Void

    // Persist last chosen tier; "none" = don't share, defaults to "full"
    @AppStorage("lastShareTierRaw") private var lastShareTierRaw: String = FriendCheckIn.PrivacyTier.full.rawValue
    @AppStorage("lastPlazaTierRaw") private var lastPlazaTierRaw: String = "none"
    @State private var selectedTier: FriendCheckIn.PrivacyTier? = nil
    @State private var selectedPlazaTier: FriendCheckIn.PrivacyTier? = nil
    @State private var shareAIFeedback: Bool = false
    @State private var showExercise = false
    @State private var aiFeedbackCopied = false
    @State private var isSavingPlaza = false
    @State private var plazaError: String?

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
                    Group {
                        if isSavingPlaza {
                            ProgressView().tint(.white)
                        } else {
                            Text(lm.aiSave)
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.cathierAccent)
                .clipShape(Capsule())
                .padding(.top, 8)
                .disabled(isSavingPlaza)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .onAppear {
            selectedTier = FriendCheckIn.PrivacyTier(rawValue: lastShareTierRaw)
            selectedPlazaTier = FriendCheckIn.PrivacyTier(rawValue: lastPlazaTierRaw)
        }
        .onChange(of: selectedTier) { _, newTier in
            lastShareTierRaw = newTier?.rawValue ?? "none"
        }
        .onChange(of: selectedPlazaTier) { _, newTier in
            lastPlazaTierRaw = newTier?.rawValue ?? "none"
        }
        .task {
            if viewModel.aiFeedback.isEmpty && !viewModel.isLoadingAI {
                let history = fetchRecentHistory()
                let freq = emotionFrequency()
                await viewModel.fetchAIFeedback(recentHistory: history, emotionFrequency: freq)
            }
        }
        .alert("分享到广场失败", isPresented: Binding(
            get: { plazaError != nil },
            set: { if !$0 { plazaError = nil } }
        )) {
            Button("好", role: .cancel) { plazaError = nil }
        } message: {
            Text(plazaError ?? "")
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
                    .foregroundColor(.cathierAccent)
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
            .background(Color.cathierAccentLight)
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
                    .foregroundColor(.cathierAccent)
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
                    .foregroundColor(isSelected ? .cathierAccent : .secondary)
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
                    .foregroundColor(.cathierAccent)
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
        .tint(.cathierAccent)
    }

    // MARK: - Plaza section

    private var plazaSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "person.3.fill")
                    .font(.caption)
                    .foregroundColor(.cathierAccent)
                Text(lm.plazaShareSectionTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            VStack(spacing: 8) {
                // Not sharing option
                plazaTierRow(label: lm.aiDontShare, description: lm.aiOnlySelf, icon: "lock.fill", tier: nil)
                Divider()
                ForEach(FriendCheckIn.PrivacyTier.allCases) { tier in
                    plazaTierRow(label: tierDisplayName(tier), description: plazaTierDescription(tier),
                                 icon: tierIcon(tier), tier: tier)
                    if tier != FriendCheckIn.PrivacyTier.allCases.last {
                        Divider()
                    }
                }
            }
            .padding(12)
            .background(Color.cathierSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func plazaTierRow(label: String, description: String, icon: String,
                              tier: FriendCheckIn.PrivacyTier?) -> some View {
        let isSelected = selectedPlazaTier == tier
        return Button(action: { selectedPlazaTier = tier }) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .cathierAccent : .secondary)
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
        guard let plazaTier = selectedPlazaTier, let profile = friendVM.currentProfile else {
            onDismiss()
            return
        }
        // Plaza share: await the upload so failures surface to the user instead
        // of being silently swallowed. isPlazaShared is only flipped on success.
        let post = PlazaPost(ownerProfile: profile, checkIn: checkIn, privacyTier: plazaTier, shareAIFeedback: plazaTier == .full)
        isSavingPlaza = true
        Task {
            do {
                try await CloudKitService.shared.savePlazaPost(post)
                await MainActor.run {
                    checkIn.isPlazaShared = true
                    isSavingPlaza = false
                    onDismiss()
                }
            } catch {
                await MainActor.run {
                    isSavingPlaza = false
                    plazaError = error.localizedDescription
                }
            }
        }
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
                    let color = EmotionData.category(for: emotion)?.color ?? .cathierAccent
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
            .background(Color.cathierAccent.opacity(0.1))
            .foregroundColor(.cathierAccent)
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
                    .foregroundColor(.cathierAccent)
                Text(lm.aiCompanion)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                if !viewModel.aiFeedback.isEmpty && !viewModel.isLoadingAI {
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
        .background(Color.cathierAccentLight)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.cathierAccent.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animation(.easeInOut, value: viewModel.isLoadingAI)
    }

    private var loadingView: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.cathierAccent)
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
                    .foregroundColor(.cathierAccent)
            }
        }
    }
}

// MARK: - Structured Feedback View

struct StructuredFeedbackView: View {
    let feedback: StructuredFeedback
    @Environment(LanguageManager.self) private var lm

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            feedbackRow(icon: "waveform", titleKey: "summary", content: feedback.summary, color: .cathierAccent)
            Divider().padding(.leading, 26)
            feedbackRow(icon: "sparkles", titleKey: "insight", content: feedback.insight, color: .cathierAccent)
            Divider().padding(.leading, 26)
            feedbackRow(icon: "figure.mind.and.body", titleKey: "connection", content: feedback.connection, color: .cathierAccent)
            Divider().padding(.leading, 26)
            feedbackRow(icon: "lightbulb", titleKey: "suggestion", content: feedback.suggestion, color: .cathierAccent)
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
        case ..<7: return .cathierAccent
        default:   return .red
        }
    }
}
