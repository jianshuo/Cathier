import SwiftUI
import SwiftData

/// Content view (no NavigationStack), suitable for both NavigationLink push and sheet wrapping.
struct BrainTrainerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(LanguageManager.self) private var lm
    @State private var viewModel = CheckInViewModel()
    @State private var phase: Phase = .intro
    @FocusState private var triggerFocused: Bool

    private enum Phase { case intro, chat }

    var body: some View {
        Group {
            switch phase {
            case .intro:
                introView
            case .chat:
                BrainTrainerChatView(onSave: saveAction)
                    .environment(viewModel)
                    .environment(lm)
            }
        }
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.cathierBackground.ignoresSafeArea())
    }

    // MARK: - Intro

    private var introView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "gearshape.2.fill")
                            .font(.title2)
                            .foregroundColor(.cathierAccent)
                        Text(introHeadline)
                            .font(.cathierSerif(.title2))
                            .foregroundColor(.primary)
                    }
                    Text(introSubtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineSpacing(3)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(promptLabel)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    TextField(promptPlaceholder, text: $viewModel.triggerEvent, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(3...6)
                        .focused($triggerFocused)
                        .padding(14)
                        .background(Color.cathierSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                }

                Button(action: startChat) {
                    Text(continueLabel)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canContinue ? Color.cathierAccent : Color.cathierAccent.opacity(0.4))
                        .clipShape(Capsule())
                }
                .disabled(!canContinue)
                .padding(.top, 4)

                Spacer(minLength: 24)
            }
            .padding(20)
        }
        .onAppear { triggerFocused = true }
    }

    private var canContinue: Bool {
        !viewModel.triggerEvent.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func startChat() {
        triggerFocused = false
        phase = .chat
        viewModel.startBrainTrainerSession()
    }

    private func saveAction() {
        viewModel.aiFeedback = viewModel.brainTrainerTranscript
        _ = viewModel.save(context: modelContext)
        dismiss()
    }

    // MARK: - Localized strings

    private var navTitle: String {
        switch lm.currentLanguage {
        case .zh: return "吃一堑长一智"
        case .ja: return "失敗から学ぶ"
        default:  return "Lesson from Setback"
        }
    }

    private var introHeadline: String {
        switch lm.currentLanguage {
        case .zh: return "刚才踩了什么坑？"
        case .ja: return "今、何でつまずいた？"
        default:  return "What just tripped you up?"
        }
    }

    private var introSubtitle: String {
        switch lm.currentLanguage {
        case .zh: return "我们花几分钟做一次五步复盘——不复盘事件，而是复盘解释事件的旧模型，训练一个新版本。"
        case .ja: return "5ステップで振り返ります。出来事ではなく、出来事を解釈する古いモデルを更新します。"
        default:  return "We'll do a 5-step review — not of the event, but of the old model that interpreted it. Train a new version."
        }
    }

    private var promptLabel: String {
        switch lm.currentLanguage {
        case .zh: return "一句话描述这次的「堑」"
        case .ja: return "今回の「つまずき」を一言で"
        default:  return "Describe the setback in one line"
        }
    }

    private var promptPlaceholder: String {
        switch lm.currentLanguage {
        case .zh: return "比如：开会时被问到细节没答上来…"
        case .ja: return "例：会議で詳細を答えられなかった…"
        default:  return "e.g., Got asked a detail in a meeting and froze..."
        }
    }

    private var continueLabel: String {
        switch lm.currentLanguage {
        case .zh: return "开始复盘"
        case .ja: return "振り返りを始める"
        default:  return "Begin Review"
        }
    }
}
