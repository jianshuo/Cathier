import SwiftUI

struct MicroExerciseView: View {
    let bodyParts: [String]
    let sensations: [String]
    let emotions: [String]
    @Environment(\.dismiss) private var dismiss
    @Environment(LanguageManager.self) private var lm
    @State private var exerciseText: String = ""
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var timerState: TimerState = .idle
    @State private var remaining: Int = 60

    private enum TimerState {
        case idle, running, done
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if isLoading {
                        loadingView
                    } else if let error = errorMessage {
                        errorView(error)
                    } else {
                        exerciseContent
                    }
                }
                .padding(20)
            }
            .navigationTitle(lm.exerciseNavTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .task { await loadExercise() }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.4)
                .tint(.cathierAccent)
            Text(lm.exerciseLoading)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundColor(.cathierAccent)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button(lm.exerciseRetry) {
                Task { await loadExercise() }
            }
            .foregroundColor(.cathierAccent)
        }
        .padding(.vertical, 40)
    }

    // MARK: - Exercise content

    private var exerciseContent: some View {
        VStack(spacing: 24) {
            // Exercise text
            Text(exerciseText)
                .font(.cathierSerif(.body))
                .lineSpacing(5)
                .padding(16)
                .background(Color.cathierAccentLight)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Timer
            timerSection
        }
    }

    private var timerSection: some View {
        VStack(spacing: 16) {
            switch timerState {
            case .idle:
                Button(action: startTimer) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                        Text(lm.exerciseStart)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.cathierAccent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

            case .running:
                VStack(spacing: 12) {
                    Text(formattedTime)
                        .font(.system(size: 48, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.cathierAccent)

                    ProgressView(value: Double(60 - remaining), total: 60)
                        .tint(.cathierAccent)
                        .scaleEffect(y: 2)
                        .clipShape(Capsule())

                    Button(lm.exerciseStop) {
                        timerState = .done
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)

            case .done:
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.cathierSage)
                    Text(lm.exerciseDone)
                        .font(.headline)
                        .foregroundColor(.cathierSage)
                    Button(action: { dismiss() }) {
                        Text(lm.exerciseClose)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.cathierSage)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
        }
    }

    private var formattedTime: String {
        let m = remaining / 60
        let s = remaining % 60
        return String(format: "%d:%02d", m, s)
    }

    private func startTimer() {
        remaining = 60
        timerState = .running
        Task {
            while remaining > 0 && timerState == .running {
                try? await Task.sleep(for: .seconds(1))
                guard timerState == .running else { break }
                remaining -= 1
            }
            if timerState == .running {
                timerState = .done
            }
        }
    }

    // MARK: - Load exercise

    private func loadExercise() async {
        isLoading = true
        errorMessage = nil
        do {
            exerciseText = try await ClaudeService.generateExercise(
                bodyParts: bodyParts,
                sensations: sensations,
                emotions: emotions,
                language: lm.currentLanguage
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
