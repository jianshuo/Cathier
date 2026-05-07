import SwiftUI
import SwiftData

struct CheckInFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(LanguageManager.self) private var lm
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel = CheckInViewModel()

    var body: some View {
        NavigationStack {
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
            .transition(reduceMotion
                ? .opacity
                : .asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))
            )
            .animation(.easeInOut(duration: reduceMotion ? 0.2 : 0.3), value: viewModel.currentStep)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                StepProgressBar(currentStep: viewModel.currentStep)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
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

// MARK: - Step Progress Bar

private struct StepProgressBar: View {
    let currentStep: CheckInStep
    private let steps = CheckInStep.allCases

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                Capsule()
                    .fill(stepIndex(step) <= stepIndex(currentStep)
                          ? Color.cathierAccent
                          : Color.cathierAccent.opacity(0.18))
                    .frame(height: 4)
                    .animation(.easeOut(duration: 0.2), value: currentStep)
            }
        }
        .accessibilityHidden(true)
    }

    private func stepIndex(_ step: CheckInStep) -> Int {
        steps.firstIndex(of: step) ?? 0
    }
}

// MARK: - Chip View (shared component)

struct ChipView: View {
    let label: String
    let isSelected: Bool
    var color: Color = .cathierAccent
    /// How many times this item appeared in recent check-ins. Shows ×N badge when > 1.
    var recentCount: Int? = nil
    let action: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
            if let count = recentCount, count > 1 {
                Text("×\(count)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(color.opacity(0.6))
            }
        }
        .font(.subheadline)
        .fontWeight(isSelected ? .semibold : .regular)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(isSelected ? color.opacity(0.15) : Color(.systemGray6))
        .foregroundColor(isSelected ? color : .primary)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(isSelected ? color : Color.clear, lineWidth: 1.5)
        )
        .contentShape(Capsule())
        .onTapGesture {
            UIImpactFeedbackGenerator(style: isSelected ? .light : .medium).impactOccurred()
            action()
        }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
