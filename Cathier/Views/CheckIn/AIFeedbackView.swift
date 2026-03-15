import SwiftUI
import SwiftData

struct AIFeedbackView: View {
    @Environment(CheckInViewModel.self) private var viewModel
    @Environment(FriendViewModel.self) private var friendVM
    @Environment(\.modelContext) private var modelContext
    let onDismiss: () -> Void

    @State private var selectedTier: FriendCheckIn.PrivacyTier? = nil

    private var hasFriends: Bool { friendVM.currentProfile != nil && !friendVM.friends.isEmpty }

    var body: some View {
        @Bindable var vm = viewModel
        ScrollView {
            VStack(spacing: 24) {
                summaryCard
                aiFeedbackCard

                // Note input
                VStack(alignment: .leading, spacing: 8) {
                    Text("添加备注（可选）")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("记录一些额外的想法…", text: $vm.note, axis: .vertical)
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
                    Text("保存记录")
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
                Text("分享给好友？")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            VStack(spacing: 8) {
                // Not sharing option
                tierRow(label: "不分享", description: "仅自己可见", icon: "lock.fill", tier: nil)
                Divider()
                ForEach(FriendCheckIn.PrivacyTier.allCases) { tier in
                    tierRow(label: tier.displayName, description: tier.description,
                            icon: tierIcon(tier), tier: tier)
                    if tier != FriendCheckIn.PrivacyTier.allCases.last {
                        Divider()
                    }
                }
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
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
            Task { try? await friendVM.shareCheckIn(checkIn, tier: tier) }
        }
        onDismiss()
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("此刻的感受")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                IntensityBadge(intensity: Int(viewModel.intensity))
            }

            if !viewModel.selectedBodyParts.isEmpty {
                labelRow(icon: "figure.mind.and.body",
                         items: Array(viewModel.selectedBodyParts))
            }

            if !viewModel.selectedSensations.isEmpty {
                labelRow(icon: "waveform",
                         items: Array(viewModel.selectedSensations))
            }

            if !viewModel.allEmotions.isEmpty {
                emotionRow
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
    }

    // MARK: - AI Feedback Card

    private var aiFeedbackCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundColor(.orange)
                Text("AI 陪伴")
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
            Text("正在感受你的感受…")
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
                Text("重试")
                    .font(.subheadline)
                    .foregroundColor(.orange)
            }
        }
    }
}

// MARK: - Intensity Badge

struct IntensityBadge: View {
    let intensity: Int

    var body: some View {
        Text("强度 \(intensity)/10")
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
