import SwiftUI
import AVFoundation

// MARK: - Speech manager (NSObject subclass required for AVSpeechSynthesizerDelegate)

@Observable
private final class MeditationSpeechManager: NSObject, AVSpeechSynthesizerDelegate {
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
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        utterance.postUtteranceDelay = 0.5

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

    // MARK: AVSpeechSynthesizerDelegate

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

// MARK: - GuidedMeditationView

struct GuidedMeditationView: View {
    let bodyParts: [String]
    let sensations: [String]
    let emotions: [String]

    @Environment(\.dismiss) private var dismiss
    @Environment(LanguageManager.self) private var lm

    @State private var script: String = ""
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var speechManager = MeditationSpeechManager()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if isLoading {
                        loadingView
                    } else if let error = errorMessage {
                        errorView(error)
                    } else {
                        meditationContent
                    }
                }
                .padding(20)
            }
            .navigationTitle(lm.meditationNavTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: stopAndDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .task { await loadScript() }
        .onDisappear { speechManager.stop() }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.4)
                .tint(.cathierAccent)
            Text(lm.meditationLoading)
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
            Button(lm.meditationRetry) {
                Task { await loadScript() }
            }
            .foregroundColor(.cathierAccent)
        }
        .padding(.vertical, 40)
    }

    // MARK: - Meditation content

    private var meditationContent: some View {
        VStack(spacing: 24) {
            Text(script)
                .font(.cathierSerif(.body))
                .lineSpacing(6)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.cathierAccentLight)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            audioControls
        }
    }

    // MARK: - Audio controls

    private var audioControls: some View {
        VStack(spacing: 16) {
            switch speechManager.playState {
            case .idle:
                Button(action: { speechManager.play(text: script, language: lm.currentLanguage) }) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                        Text(lm.meditationPlay)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.cathierAccent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

            case .playing:
                VStack(spacing: 12) {
                    playingIndicator

                    HStack(spacing: 16) {
                        Button(action: { speechManager.pause() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "pause.fill")
                                Text(lm.meditationPause)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.cathierAccent)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        Button(action: { speechManager.stop() }) {
                            Text(lm.meditationStop)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }

            case .paused:
                HStack(spacing: 16) {
                    Button(action: { speechManager.resume() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                            Text(lm.meditationResume)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.cathierAccent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button(action: { speechManager.stop() }) {
                        Text(lm.meditationStop)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

            case .done:
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.cathierAccent)
                    Text(lm.meditationDone)
                        .font(.headline)
                        .foregroundColor(.cathierAccent)
                    Button(action: stopAndDismiss) {
                        Text(lm.meditationClose)
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

    private var playingIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.cathierAccent)
                    .frame(width: 4, height: CGFloat.random(in: 12...28))
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever()
                        .delay(Double(i) * 0.1),
                        value: speechManager.playState
                    )
            }
        }
        .frame(height: 32)
    }

    // MARK: - Load script

    private func loadScript() async {
        isLoading = true
        errorMessage = nil
        do {
            script = try await ClaudeService.generateGuidedMeditation(
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

    private func stopAndDismiss() {
        speechManager.stop()
        dismiss()
    }
}
