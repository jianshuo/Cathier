import SwiftUI

struct EmotionLabelView: View {
    @Environment(CheckInViewModel.self) private var viewModel

    var body: some View {
        @Bindable var vm = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Selected emotions summary
                if !viewModel.allEmotions.isEmpty {
                    selectedEmotionsView
                }

                // Category grid
                sectionLabel("这种感受，更接近哪种情绪？")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(EmotionData.categories) { category in
                        CategoryButton(
                            category: category,
                            isSelected: viewModel.selectedCategory == category.name
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if viewModel.selectedCategory == category.name {
                                    viewModel.selectedCategory = nil
                                } else {
                                    viewModel.selectedCategory = category.name
                                }
                            }
                        }
                    }
                }

                // Sub-emotion chips
                if let categoryName = viewModel.selectedCategory,
                   let category = EmotionData.categories.first(where: { $0.name == categoryName }) {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel("更具体是…")
                        FlowLayout(spacing: 10) {
                            ForEach(category.children, id: \.self) { emotion in
                                ChipView(
                                    label: emotion,
                                    isSelected: viewModel.selectedEmotions.contains(emotion),
                                    color: category.color
                                ) {
                                    toggleEmotion(emotion)
                                }
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Divider()

                // Custom emotion input
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("或者，你想用自己的词描述")
                    TextField("输入情绪词…", text: $vm.customEmotion)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }

                // Next Button
                Button(action: {
                    withAnimation { viewModel.currentStep = .aiFeedback }
                }) {
                    Text("生成 AI 反馈")
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
                    withAnimation { viewModel.currentStep = .aiFeedback }
                }) {
                    Text("跳过，直接保存")
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
            Text("已选择")
                .font(.caption)
                .foregroundColor(.secondary)
            FlowLayout(spacing: 8) {
                ForEach(viewModel.allEmotions, id: \.self) { emotion in
                    let color = EmotionData.category(for: emotion)?.color ?? .orange
                    HStack(spacing: 4) {
                        Text(emotion)
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
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: category.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : category.color)
                Text(category.name)
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
