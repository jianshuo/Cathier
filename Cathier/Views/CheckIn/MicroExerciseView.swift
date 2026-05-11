import SwiftUI
import UIKit
import AVFoundation

// MARK: - Speech manager

@Observable
private final class ExerciseSpeechManager: NSObject, AVSpeechSynthesizerDelegate {
    enum PlayState { case idle, playing, paused, done }

    var playState: PlayState = .idle

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func play(text: String, language: AppLanguage) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: voiceLocale(for: language))
        utterance.rate = 0.40
        utterance.pitchMultiplier = 0.95
        utterance.volume = 1.0
        utterance.postUtteranceDelay = 0.3

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)

        synthesizer.speak(utterance)
        playState = .playing
    }

    func pause() {
        synthesizer.pauseSpeaking(at: .word)
        playState = .paused
    }

    func resume() {
        synthesizer.continueSpeaking()
        playState = .playing
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        playState = .idle
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        playState = .done
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func voiceLocale(for language: AppLanguage) -> String {
        switch language {
        case .zh: return "zh-CN"
        case .ja: return "ja-JP"
        case .ko: return "ko-KR"
        case .fr: return "fr-FR"
        case .de: return "de-DE"
        case .es: return "es-ES"
        case .it: return "it-IT"
        case .pt: return "pt-BR"
        case .ru: return "ru-RU"
        case .ar: return "ar-SA"
        case .hi: return "hi-IN"
        case .th: return "th-TH"
        case .vi: return "vi-VN"
        case .tr: return "tr-TR"
        default:  return "en-US"
        }
    }
}

// MARK: - MicroExerciseView

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
    @State private var speechManager = ExerciseSpeechManager()

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
        .onDisappear { speechManager.stop() }
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

            // Audio guidance
            audioControls

            // Timer
            timerSection
        }
    }

    // MARK: - Audio controls

    private var audioControls: some View {
        VStack(spacing: 12) {
            switch speechManager.playState {
            case .idle:
                Button(action: { speechManager.play(text: exerciseText, language: lm.currentLanguage) }) {
                    HStack(spacing: 8) {
                        Image(systemName: "headphones")
                            .font(.subheadline)
                        Text(lm.exerciseListenAudio)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.cathierAccent.opacity(0.12))
                    .foregroundColor(.cathierAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

            case .playing:
                VStack(spacing: 10) {
                    audioPlayingIndicator

                    HStack(spacing: 12) {
                        Button(action: { speechManager.pause() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "pause.fill")
                                Text(lm.meditationPause)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.cathierAccent)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        Button(action: { speechManager.stop() }) {
                            Text(lm.meditationStop)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }

            case .paused:
                HStack(spacing: 12) {
                    Button(action: { speechManager.resume() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                            Text(lm.meditationResume)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.cathierAccent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    Button(action: { speechManager.stop() }) {
                        Text(lm.meditationStop)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

            case .done:
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.cathierAccent)
                    Text(lm.exerciseAudioDone)
                        .font(.subheadline)
                        .foregroundColor(.cathierAccent)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var audioPlayingIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.cathierAccent)
                    .frame(width: 4, height: i % 2 == 0 ? 20 : 14)
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever()
                        .delay(Double(i) * 0.1),
                        value: speechManager.playState
                    )
            }
        }
        .frame(height: 28)
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
                VStack(spacing: 16) {
                    ZStack {
                        // Background track
                        Circle()
                            .stroke(Color.cathierAccent.opacity(0.2), lineWidth: 16)

                        // Progress ring
                        Circle()
                            .trim(from: 0, to: Double(60 - remaining) / 60.0)
                            .stroke(
                                AngularGradient(
                                    gradient: Gradient(colors: [
                                        Color.cathierAccent.opacity(0.6),
                                        Color.cathierAccent
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
                            .foregroundColor(.cathierAccent)
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
                        .foregroundColor(.cathierAccent)
                    Text(lm.exerciseDone)
                        .font(.headline)
                        .foregroundColor(.cathierAccent)
                    Button(action: { dismiss() }) {
                        Text(lm.exerciseClose)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.cathierAccent)
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
