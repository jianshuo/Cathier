import SwiftUI
import SwiftData

/// Content view (no NavigationStack), suitable for both NavigationLink push and sheet wrapping.
struct BrainTrainerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(LanguageManager.self) private var lm
    @Environment(FriendViewModel.self) private var friendVM
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
                    .environment(friendVM)
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

    private func saveAction(tier: FriendCheckIn.PrivacyTier?) {
        viewModel.aiFeedback = viewModel.brainTrainerTranscript
        let checkIn = viewModel.save(context: modelContext)
        if let tier {
            // The BrainTrainer transcript lives in aiFeedback; pass
            // shareAIFeedback: true so non-full tiers (not currently offered
            // in the UI, but kept honest for the future) still carry the
            // transcript when shared.
            Task { try? await friendVM.shareCheckIn(checkIn, tier: tier, shareAIFeedback: true) }
        }
        dismiss()
    }

    // MARK: - Localized strings

    private struct Strings {
        let navTitle, introHeadline, introSubtitle, promptLabel, promptPlaceholder, continueLabel: String

        static func make(_ lang: AppLanguage) -> Strings {
            switch lang {
            case .zh: return Strings(
                navTitle: "吃一堑长一智",
                introHeadline: "刚才踩了什么坑？",
                introSubtitle: "我们花几分钟做一次五步复盘——不复盘事件，而是复盘解释事件的旧模型，训练一个新版本。",
                promptLabel: "一句话描述这次的「堑」",
                promptPlaceholder: "比如：开会时被问到细节没答上来…",
                continueLabel: "开始复盘")
            case .ja: return Strings(
                navTitle: "失敗から学ぶ",
                introHeadline: "今、何でつまずいた？",
                introSubtitle: "5ステップで振り返ります。出来事ではなく、出来事を解釈する古いモデルを更新します。",
                promptLabel: "今回の「つまずき」を一言で",
                promptPlaceholder: "例：会議で詳細を答えられなかった…",
                continueLabel: "振り返りを始める")
            default: return Strings(
                navTitle: "Lesson from Setback",
                introHeadline: "What just tripped you up?",
                introSubtitle: "We'll do a 5-step review — not of the event, but of the old model that interpreted it. Train a new version.",
                promptLabel: "Describe the setback in one line",
                promptPlaceholder: "e.g., Got asked a detail in a meeting and froze...",
                continueLabel: "Begin Review")
            }
        }
    }

    private var s: Strings { .make(lm.currentLanguage) }
    private var navTitle: String { s.navTitle }
    private var introHeadline: String { s.introHeadline }
    private var introSubtitle: String { s.introSubtitle }
    private var promptLabel: String { s.promptLabel }
    private var promptPlaceholder: String { s.promptPlaceholder }
    private var continueLabel: String { s.continueLabel }
}
