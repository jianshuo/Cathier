import SwiftUI
import SwiftData

struct CheckInFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(LanguageManager.self) private var lm
    @State private var viewModel = CheckInViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                StepIndicatorView(currentStep: viewModel.currentStep)
                    .padding(.top, 8)
                    .padding(.horizontal, 24)

                Group {
                    switch viewModel.currentStep {
                    case .bodyScan:
                        BodyScanView()
                    case .emotionLabel:
                        EmotionLabelView(onSkip: {
                            _ = viewModel.save(context: modelContext)
                            dismiss()
                        })
                    case .aiFeedback:
                        AIFeedbackView(onDismiss: { dismiss() })
                    }
                }
                .environment(viewModel)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
                .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lm.checkInCancel) { dismiss() }
                }
            }
        }
    }

    private var navigationTitle: String {
        switch viewModel.currentStep {
        case .bodyScan:    return lm.checkInStepBodyScan
        case .emotionLabel: return lm.checkInStepEmotion
        case .aiFeedback:  return lm.checkInStepAI
        }
    }
}

// MARK: - Step Indicator

private struct StepIndicatorView: View {
    let currentStep: CheckInStep
    private let steps = CheckInStep.allCases
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                let isCompleted = stepIndex(step) < stepIndex(currentStep)
                let isCurrent = step == currentStep
                Circle()
                    .fill(isCompleted || isCurrent ? themeManager.accentColor : Color(.systemGray4))
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .stroke(isCurrent ? themeManager.accentColor : Color.clear, lineWidth: 2)
                            .frame(width: 16, height: 16)
                    )
                if index < steps.count - 1 {
                    Rectangle()
                        .fill(isCompleted ? themeManager.accentColor : Color(.systemGray4))
                        .frame(height: 2)
                }
            }
        }
        .padding(.vertical, 16)
        .animation(.easeInOut(duration: 0.3), value: currentStep)
    }

    private func stepIndex(_ step: CheckInStep) -> Int {
        steps.firstIndex(of: step) ?? 0
    }
}

// MARK: - Chip View (shared component)

struct ChipView: View {
    let label: String
    let isSelected: Bool
    var color: Color? = nil
    let action: () -> Void

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        let effectiveColor = color ?? themeManager.accentColor
        return Text(label)
            .font(.subheadline)
            .fontWeight(isSelected ? .semibold : .regular)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? effectiveColor.opacity(0.15) : Color(.systemGray6))
            .foregroundColor(isSelected ? effectiveColor : .primary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? effectiveColor : Color.clear, lineWidth: 1.5)
            )
            .contentShape(Capsule())
            .onTapGesture {
                UIImpactFeedbackGenerator(style: isSelected ? .light : .medium).impactOccurred()
                action()
            }
            .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
