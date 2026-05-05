import SwiftUI
import UIKit

struct MicroExerciseView: View {
    let bodyParts: [String]
    let sensations: [String]
    let emotions: [String]
    @Environment(\.dismiss) private var dismiss
    @Environment(LanguageManager.self) private var lm
    @Environment(ThemeManager.self) private var themeManager
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
                .tint(themeManager.accentColor)
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
                .foregroundColor(themeManager.accentColor)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button(lm.exerciseRetry) {
                Task { await loadExercise() }
            }
            .foregroundColor(themeManager.accentColor)
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
                .background(themeManager.accentColorLight)
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
                    .background(themeManager.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

            case .running:
                VStack(spacing: 16) {
                    ZStack {
                        // Background track
                        Circle()
                            .stroke(themeManager.accentColor.opacity(0.2), lineWidth: 16)

                        // Progress ring
                        Circle()
                            .trim(from: 0, to: Double(60 - remaining) / 60.0)
                            .stroke(
                                AngularGradient(
                                    gradient: Gradient(colors: [
                                        themeManager.accentColor.opacity(0.6),
                                        themeManager.accentColor
                                    ]),
                                    center: .center,
                                    startAngle: .degrees(0),
                                    endAngle: .degrees(360 * Double(60 - remaining) / 60.0)
                                ),
                                style: StrokeStyle(lineWidth: 16, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1), value: remaining)

                        // Time label in center
                        Text(formattedTime)
                            .font(.system(size: 48, weight: .light, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(themeManager.accentColor)
                    }
                    .frame(width: 200, height: 200)

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
        // Start haptic: short gentle tap
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        Task {
            while remaining > 0 && timerState == .running {
                try? await Task.sleep(for: .seconds(1))
                guard timerState == .running else { break }
                remaining -= 1
            }
            if timerState == .running {
                timerState = .done
                // End haptic: distinct double-tap notification
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
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
