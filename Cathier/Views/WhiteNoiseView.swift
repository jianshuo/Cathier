import SwiftUI
import AVFoundation

// MARK: - Noise Engine

@Observable
private final class NoiseEngine {
    enum NoiseType: String, CaseIterable {
        case white, pink, brown
    }

    enum TimerOption: Int, CaseIterable {
        case none = 0, min15 = 15, min30 = 30, min60 = 60
    }

    var isPlaying = false
    var secondsRemaining: Int = 0

    private var audioEngine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private var timerTask: Task<Void, Never>?

    // Pink noise filter state — internal DSP, not observed.
    // @ObservationIgnored required because @Observable generates an
    // ObservationTracked accessor per stored property, and the macro
    // rejects multi-variable `var a, b, c: Float` declarations. These
    // never drive UI, so observation is unnecessary anyway.
    @ObservationIgnored private var b0: Float = 0
    @ObservationIgnored private var b1: Float = 0
    @ObservationIgnored private var b2: Float = 0
    @ObservationIgnored private var b3: Float = 0
    @ObservationIgnored private var b4: Float = 0
    @ObservationIgnored private var b5: Float = 0
    @ObservationIgnored private var b6: Float = 0

    // Brown noise filter state
    @ObservationIgnored private var lastBrown: Float = 0

    func start(type: NoiseType, timer: TimerOption) {
        stop()

        let engine = AVAudioEngine()
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        let sampleRate = Float(format.sampleRate)

        let node = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, buffers in
            guard let self else { return noErr }
            let ablPointer = UnsafeMutableAudioBufferListPointer(buffers)
            for frame in 0..<Int(frameCount) {
                let sample = self.nextSample(type: type, sampleRate: sampleRate)
                for buffer in ablPointer {
                    let buf = buffer.mData!.assumingMemoryBound(to: Float.self)
                    buf[frame] = sample
                }
            }
            return noErr
        }

        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)

        try? engine.start()

        self.audioEngine = engine
        self.sourceNode = node
        isPlaying = true

        if timer != .none {
            secondsRemaining = timer.rawValue * 60
            timerTask = Task { [weak self] in
                while let self, self.secondsRemaining > 0 {
                    try? await Task.sleep(for: .seconds(1))
                    await MainActor.run { self.secondsRemaining -= 1 }
                }
                await MainActor.run { self?.stop() }
            }
        }
    }

    func stop() {
        timerTask?.cancel()
        timerTask = nil
        audioEngine?.stop()
        audioEngine = nil
        sourceNode = nil
        isPlaying = false
        secondsRemaining = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func nextSample(type: NoiseType, sampleRate: Float) -> Float {
        switch type {
        case .white:
            return Float.random(in: -0.25...0.25)

        case .pink:
            // Paul Kellet's pink noise algorithm
            let white = Float.random(in: -1...1)
            b0 = 0.99886 * b0 + white * 0.0555179
            b1 = 0.99332 * b1 + white * 0.0750759
            b2 = 0.96900 * b2 + white * 0.1538520
            b3 = 0.86650 * b3 + white * 0.3104856
            b4 = 0.55000 * b4 + white * 0.5329522
            b5 = -0.7616 * b5 - white * 0.0168980
            let pink = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362) * 0.11
            b6 = white * 0.115926
            return pink

        case .brown:
            let white = Float.random(in: -1...1)
            lastBrown = (lastBrown + (0.02 * white)) / 1.02
            return lastBrown * 3.5
        }
    }
}

// MARK: - WhiteNoiseView

struct WhiteNoiseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LanguageManager.self) private var lm

    @State private var engine = NoiseEngine()
    @State private var selectedType: NoiseEngine.NoiseType = .pink
    @State private var selectedTimer: NoiseEngine.TimerOption = .none
    @State private var animPhase: Bool = false

    private let sageColor = Color(red: 107/255, green: 143/255, blue: 113/255)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    waveformDisplay
                        .padding(.top, 8)

                    timerCountdown

                    noiseTypePicker
                        .disabled(engine.isPlaying)

                    timerPicker
                        .disabled(engine.isPlaying)

                    controlButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .navigationTitle(localizedNavTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { engine.stop(); dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel(localizedClose)
                }
            }
            .background(Color.cathierBackground.ignoresSafeArea())
        }
        .onDisappear { engine.stop() }
    }

    // MARK: - Waveform

    private var waveformDisplay: some View {
        HStack(spacing: 5) {
            ForEach(0..<12, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(sageColor)
                    .frame(width: 6, height: engine.isPlaying ? barHeight(index: i) : 8)
                    .animation(
                        engine.isPlaying
                            ? .easeInOut(duration: 0.45 + Double(i % 4) * 0.08)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.07)
                            : .easeInOut(duration: 0.2),
                        value: animPhase
                    )
            }
        }
        .frame(height: 60)
        .onChange(of: engine.isPlaying) { _, playing in
            animPhase = playing
        }
    }

    private func barHeight(index: Int) -> CGFloat {
        let heights: [CGFloat] = [14, 26, 40, 52, 44, 32, 20, 36, 50, 42, 28, 18]
        return animPhase ? heights[index] : 8
    }

    // MARK: - Timer countdown

    @ViewBuilder
    private var timerCountdown: some View {
        if engine.secondsRemaining > 0 {
            let mins = engine.secondsRemaining / 60
            let secs = engine.secondsRemaining % 60
            Text(String(format: "%d:%02d", mins, secs))
                .font(.system(.title2, design: .monospaced))
                .foregroundColor(sageColor)
        }
    }

    // MARK: - Noise type picker

    private var noiseTypePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localizedTypeLabel)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                ForEach(NoiseEngine.NoiseType.allCases, id: \.self) { type in
                    noiseTypeButton(type)
                }
            }
        }
    }

    // Extracted from the ForEach body. Inlining the ternary-laden modifier
    // chain inside @ViewBuilder pushed Swift past the type-checker timeout
    // ("expression too complex"). Breaking each option into a named view
    // lets the inferencer solve each piece independently.
    private func noiseTypeButton(_ type: NoiseEngine.NoiseType) -> some View {
        let isSelected = (selectedType == type)
        let background: Color = isSelected ? sageColor.opacity(0.18) : Color.cathierSurface
        let foreground: Color = isSelected ? sageColor : .secondary
        let stroke: Color = isSelected ? sageColor : Color.cathierAccent.opacity(0.2)

        return Button(action: { selectedType = type }) {
            VStack(spacing: 6) {
                Text(noiseEmoji(type))
                    .font(.title3)
                Text(typeName(type))
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(background)
            .foregroundColor(foreground)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(stroke, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Timer picker

    private var timerPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localizedTimerLabel)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                ForEach(NoiseEngine.TimerOption.allCases, id: \.self) { option in
                    timerButton(option)
                }
            }
        }
    }

    private func timerButton(_ option: NoiseEngine.TimerOption) -> some View {
        let isSelected = (selectedTimer == option)
        let background: Color = isSelected ? sageColor.opacity(0.18) : Color.cathierSurface
        let foreground: Color = isSelected ? sageColor : .secondary
        let stroke: Color = isSelected ? sageColor : Color.cathierAccent.opacity(0.2)

        return Button(action: { selectedTimer = option }) {
            Text(timerName(option))
                .font(.caption)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(background)
                .foregroundColor(foreground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(stroke, lineWidth: 1.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Control button

    private var controlButton: some View {
        Button(action: togglePlayback) {
            HStack(spacing: 10) {
                Image(systemName: engine.isPlaying ? "stop.fill" : "play.fill")
                Text(engine.isPlaying ? localizedStop : localizedPlay)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(engine.isPlaying ? Color.cathierSurface : sageColor)
            .foregroundColor(engine.isPlaying ? sageColor : .white)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(sageColor, lineWidth: engine.isPlaying ? 1.5 : 0)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: engine.isPlaying)
    }

    // MARK: - Actions

    private func togglePlayback() {
        if engine.isPlaying {
            engine.stop()
        } else {
            engine.start(type: selectedType, timer: selectedTimer)
        }
    }

    // MARK: - Localization helpers

    private func noiseEmoji(_ type: NoiseEngine.NoiseType) -> String {
        switch type {
        case .white: return "🌊"
        case .pink: return "🌧️"
        case .brown: return "🌲"
        }
    }

    private func typeName(_ type: NoiseEngine.NoiseType) -> String {
        switch type {
        case .white: return lm.whiteNoiseTypeWhite
        case .pink: return lm.whiteNoiseTypePink
        case .brown: return lm.whiteNoiseTypeBrown
        }
    }

    private func timerName(_ option: NoiseEngine.TimerOption) -> String {
        switch option {
        case .none: return lm.whiteNoiseTimerNone
        case .min15: return lm.whiteNoiseTimer15
        case .min30: return lm.whiteNoiseTimer30
        case .min60: return lm.whiteNoiseTimer60
        }
    }

    private var localizedNavTitle: String { lm.whiteNoiseNavTitle }
    private var localizedPlay: String { lm.whiteNoisePlay }
    private var localizedStop: String { lm.whiteNoiseStop }
    private var localizedClose: String { lm.whiteNoiseClose }
    private var localizedTypeLabel: String { lm.whiteNoiseTypeLabel }
    private var localizedTimerLabel: String { lm.whiteNoiseTimerLabel }
}
