import SwiftUI

struct EmotionLabelView: View {
    var onSkip: () -> Void = {}
    @Environment(CheckInViewModel.self) private var viewModel
    @Environment(ConfigService.self) private var config
    @Environment(LanguageManager.self) private var lm

    var body: some View {
        @Bindable var vm = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Selected emotions summary
                if !viewModel.allEmotions.isEmpty {
                    selectedEmotionsView
                }

                // Category grid
                sectionLabel(lm.emotionQuestion)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(config.categories) { category in
                        CategoryButton(
                            category: category,
                            displayName: lm.display(category.nameZh),
                            isSelected: viewModel.selectedCategory == category.nameZh
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if viewModel.selectedCategory == category.nameZh {
                                    viewModel.selectedCategory = nil
                                } else {
                                    viewModel.selectedCategory = category.nameZh
                                }
                            }
                        }
                    }
                }

                // Sub-emotion chips
                if let categoryName = viewModel.selectedCategory,
                   let category = config.categories.first(where: { $0.nameZh == categoryName }) {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel(lm.emotionSpecific)
                        FlowLayout(spacing: 10) {
                            ForEach(category.emotions) { emotion in
                                ChipView(
                                    label: "\(emotion.emoji) \(emotion.nameZh)",
                                    isSelected: viewModel.selectedEmotions.contains(emotion.nameZh),
                                    color: category.color
                                ) {
                                    toggleEmotion(emotion.nameZh)
                                }
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Divider()

                // Custom emotion input
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel(lm.emotionCustomPrompt)
                    TextField(lm.emotionCustomPlaceholder, text: $vm.customEmotion)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }

                // Next Button
                Button(action: {
                    withAnimation { viewModel.currentStep = .aiFeedback }
                }) {
                    Text(lm.emotionGenAI)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(viewModel.canProceedFromEmotionLabel ? Color.orange : Color(.systemGray3))
                        .cornerRadius(14)
                }
                .disabled(!viewModel.canProceedFromEmotionLabel)
                .padding(.top, 8)

                // Skip to save without AI
                Button(action: {
                    onSkip()
                }) {
                    Text(lm.emotionSkip)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
    }

    @ViewBuilder
    private var selectedEmotionsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(lm.emotionSelected)
                .font(.caption)
                .foregroundColor(.secondary)
            FlowLayout(spacing: 8) {
                ForEach(viewModel.allEmotions, id: \.self) { emotion in
                    let color = EmotionData.category(for: emotion)?.color ?? .orange
                    let emoji = EmotionData.emoji(for: emotion)
                    HStack(spacing: 4) {
                        Text(emoji.isEmpty ? emotion : "\(emoji) \(emotion)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Button {
                            viewModel.selectedEmotions.remove(emotion)
                            if emotion == viewModel.customEmotion { viewModel.customEmotion = "" }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption2)
                                .fontWeight(.bold)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(color.opacity(0.15))
                    .foregroundColor(color)
                    .clipShape(Capsule())
                }
            }
        }
        .padding(14)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.headline)
    }

    private func toggleEmotion(_ emotion: String) {
        if viewModel.selectedEmotions.contains(emotion) {
            viewModel.selectedEmotions.remove(emotion)
        } else {
            viewModel.selectedEmotions.insert(emotion)
        }
    }
}

// MARK: - Category Button

private struct CategoryButton: View {
    let category: EmotionCategory
    let displayName: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: category.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : category.color)
                Text(displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(isSelected ? category.color : Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
