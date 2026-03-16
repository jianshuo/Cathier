import SwiftUI
import SwiftData

struct AIFeedbackView: View {
    @Environment(CheckInViewModel.self) private var viewModel
    @Environment(FriendViewModel.self) private var friendVM
    @Environment(\.modelContext) private var modelContext
    @Environment(LanguageManager.self) private var lm
    let onDismiss: () -> Void

    @State private var selectedTier: FriendCheckIn.PrivacyTier? = nil
    @State private var shareAIFeedback: Bool = false

    private var hasFriends: Bool { friendVM.currentProfile != nil && !friendVM.friends.isEmpty }

    var body: some View {
        @Bindable var vm = viewModel
        ScrollView {
            VStack(spacing: 24) {
                summaryCard
                aiFeedbackCard

                // Note input
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

                // Share options (only shown when user has friends)
                if hasFriends {
                    shareSection
                }

                // Save button
                Button(action: saveAction) {
                    Text(lm.aiSave)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.orange)
                .cornerRadius(14)
                .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .task {
            if viewModel.aiFeedback.isEmpty && !viewModel.isLoadingAI {
                let history = fetchRecentHistory()
                await viewModel.fetchAIFeedback(recentHistory: history)
            }
        }
    }

    // MARK: - Share section

    private var shareSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
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
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
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
                    .foregroundColor(isSelected ? .orange : .secondary)
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
                    .foregroundColor(.orange)
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
        .tint(.orange)
    }

    // MARK: - History

    private func fetchRecentHistory() -> [CheckIn] {
        var descriptor = FetchDescriptor<CheckIn>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 5
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Save action

    private func saveAction() {
        let checkIn = viewModel.save(context: modelContext)
        if let tier = selectedTier {
            let includeAI = tier == .full ? false : shareAIFeedback
            Task { try? await friendVM.shareCheckIn(checkIn, tier: tier, shareAIFeedback: includeAI) }
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
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
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
                    let color = EmotionData.category(for: emotion)?.color ?? .orange
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

    // MARK: - AI Feedback Card

    private var aiFeedbackCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundColor(.orange)
                Text(lm.aiCompanion)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }

            if viewModel.isLoadingAI {
                loadingView
            } else if let error = viewModel.aiError {
                errorView(error)
            } else if !viewModel.aiFeedback.isEmpty {
                Text(viewModel.aiFeedback)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineSpacing(4)
                    .transition(.opacity)
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.08), Color.orange.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(16)
        .animation(.easeInOut, value: viewModel.isLoadingAI)
    }

    private var loadingView: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.orange)
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
                    .foregroundColor(.orange)
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
        case ..<4: return .green
        case ..<7: return .orange
        default:   return .red
        }
    }
}
