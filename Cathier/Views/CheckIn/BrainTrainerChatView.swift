import SwiftUI

struct BrainTrainerChatView: View {
    @Environment(CheckInViewModel.self) private var viewModel
    @Environment(LanguageManager.self) private var lm
    @Environment(FriendViewModel.self) private var friendVM

    /// Called when the user taps Save on the summary screen.
    /// Passes the share tier the user chose, or nil to keep it private.
    let onSave: (FriendCheckIn.PrivacyTier?) -> Void

    @State private var inputText = ""
    @FocusState private var inputFocused: Bool

    /// Persists the user's last share choice across BrainTrainer sessions.
    /// Kept on a separate key from the regular check-in's lastShareTierRaw so
    /// BrainTrainer transcripts (more personal) get their own default.
    @AppStorage("brainTrainerLastShareTier") private var lastShareTierRaw: String = "none"
    @State private var selectedTier: FriendCheckIn.PrivacyTier? = nil

    private var hasFriends: Bool {
        friendVM.currentProfile != nil && !friendVM.friends.isEmpty
    }

    private var visibleMessages: [BrainTrainerMessage] {
        viewModel.brainTrainerMessages.filter { !$0.isInitialContext }
    }

    var body: some View {
        if viewModel.brainTrainerComplete {
            summaryView
        } else {
            chatView
        }
    }

    // MARK: - Summary (shown after all 5 steps complete)

    private var summaryView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.cathierAccent)
                        Text("复盘完成")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.cathierAccent)
                    }

                    if viewModel.isGeneratingSummary {
                        HStack(spacing: 10) {
                            ProgressView().tint(.cathierAccent)
                            Text("正在生成总结…")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else if !viewModel.brainTrainerSummary.isEmpty {
                        // Plain Text instead of MarkdownText: the 5-line summary
                        // card stays readable with the `**` markers stripped, and
                        // dropping the AttributedString render path eliminates the
                        // last layout-cycle vector for the watchdog crash.
                        Text(stripMarkdownEmphasis(viewModel.brainTrainerSummary))
                            .font(.cathierSerif(.body))
                            .lineSpacing(5)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity)
                    } else if let err = viewModel.brainTrainerError {
                        errorRow(err)
                    }
                }
                .padding(16)
            }
            .background(Color.cathierAccentLight)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.cathierAccent.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if hasFriends {
                shareSection
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }

            Spacer(minLength: 0)
            saveButton
        }
        .task {
            if viewModel.brainTrainerSummary.isEmpty && !viewModel.isGeneratingSummary {
                await viewModel.generateBrainTrainerSummary()
            }
        }
        .onAppear {
            // Restore previous selection; "none" or unknown → nil (don't share).
            selectedTier = FriendCheckIn.PrivacyTier(rawValue: lastShareTierRaw)
        }
        .onChange(of: selectedTier) { _, newTier in
            lastShareTierRaw = newTier?.rawValue ?? "none"
        }
    }

    // MARK: - Share Section
    //
    // The BrainTrainer creates a CheckIn whose only substantive content is the
    // transcript stored in aiFeedback — bodyParts / emotions / sensations are
    // empty (no body-scan step). So the only meaningful privacy choices are
    // "don't share" vs "share the full transcript". Offering category /
    // emotions tiers here would just publish an empty record. Picking from a
    // 2-option list also keeps the summary screen compact next to the 5-line
    // training card.

    private var shareSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.caption)
                    .foregroundColor(.cathierAccent)
                Text(lm.aiShareTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            VStack(spacing: 8) {
                tierRow(
                    label: lm.aiDontShare,
                    description: lm.aiOnlySelf,
                    icon: "lock.fill",
                    tier: nil
                )
                Divider()
                tierRow(
                    label: lm.tierFullName,
                    description: lm.tierFullDesc,
                    icon: "doc.text.fill",
                    tier: .full
                )
            }
            .padding(12)
            .background(Color.cathierSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func tierRow(label: String, description: String, icon: String,
                         tier: FriendCheckIn.PrivacyTier?) -> some View {
        let isSelected = selectedTier == tier
        return Button(action: { selectedTier = tier }) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .cathierAccent : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .medium : .regular)
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Chat (5-step conversation)

    private var chatView: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    // VStack (not LazyVStack): the BrainTrainer conversation is
                    // bounded — 1 context message + 5 question/answer rounds ≈
                    // 11 visible bubbles — so lazy materialization buys nothing
                    // and its separate layout pass compounded the SwiftUI
                    // layout cycle that watchdog-killed the app.
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(visibleMessages) { msg in
                            if msg.role == "assistant" {
                                assistantBubble(msg)
                            } else {
                                userBubble(msg)
                            }
                        }
                        if viewModel.isBrainTrainerLoading {
                            loadingBubble
                        }
                        if let err = viewModel.brainTrainerError {
                            errorRow(err)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onChange(of: viewModel.brainTrainerMessages.count) { _, _ in scrollToBottom(proxy) }
                .onChange(of: viewModel.isBrainTrainerLoading) { _, _ in scrollToBottom(proxy) }
            }

            Divider()
            inputBar
        }
    }

    // MARK: - Bubbles

    private func assistantBubble(_ msg: BrainTrainerMessage) -> some View {
        let clean = msg.displayContent.replacingOccurrences(of: "<complete/>", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        let parsed = parseOptions(clean)
        // No outer .frame(maxWidth: .infinity) wrapping the MarkdownText bubble:
        // MarkdownText already applies it internally, and a second flexible-width
        // ancestor inside a LazyVStack > ScrollView contributed to the SwiftUI
        // layout cycle that watchdog-killed the app at 0x8BADF00D.
        return VStack(alignment: .leading, spacing: 10) {
            if !parsed.mainText.isEmpty {
                Text(stripMarkdownEmphasis(parsed.mainText))
                    .font(.cathierSerif(.body))
                    .lineSpacing(4)
                    .foregroundColor(.primary)
                    .padding(14)
                    .surfaceCard()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !parsed.options.isEmpty {
                optionChips(parsed.options)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func userBubble(_ msg: BrainTrainerMessage) -> some View {
        Text(msg.displayContent)
            .font(.body)
            .foregroundColor(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.cathierAccentLight)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var loadingBubble: some View {
        HStack(spacing: 8) {
            ProgressView()
                .tint(.cathierAccent)
                .scaleEffect(0.8)
            Text(lm.aiLoading)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .surfaceCard()
    }

    private func errorRow(_ message: String) -> some View {
        HStack(spacing: 8) {
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
            Button(lm.aiRetry) {
                viewModel.startBrainTrainerSession()
            }
            .font(.caption)
            .foregroundColor(.cathierAccent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Option chips

    private func optionChips(_ options: [String]) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                Button(action: { send(option) }) {
                    Text("\(index + 1). \(option)")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.cathierBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isBrainTrainerLoading)
            }
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("输入或选择上方选项…", text: $inputText, axis: .vertical)
                .font(.body)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .focused($inputFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            Button(action: submitInput) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(canSend ? .cathierAccent : .secondary)
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.cathierSurface)
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespaces).isEmpty && !viewModel.isBrainTrainerLoading
    }

    private var saveButton: some View {
        Button(action: { onSave(selectedTier) }) {
            Text(lm.aiSave)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.cathierAccent)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .padding(.top, 6)
        .background(Color.cathierSurface)
    }

    // MARK: - Helpers

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo("bottom") }
    }

    private func submitInput() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        inputText = ""
        inputFocused = false
        send(text)
    }

    private func send(_ text: String) {
        viewModel.sendBrainTrainerMessage(text)
    }

    // Line-scan the AI reply for bullet-list options. Any line whose trimmed
    // form starts with `- `, `* `, or `• ` is treated as an option; everything
    // else is prose. The previous <options><option>…</option></options> parser
    // crashed when the model emitted malformed or out-of-order tags — a stray
    // `</option>` before its matching `<option>` produced an inverted
    // Range<String.Index> and Swift fatal-errored before any catch could fire.
    // Line iteration has no such slicing and can't crash on bad input.
    private func parseOptions(_ text: String) -> (mainText: String, options: [String]) {
        var proseLines: [String] = []
        var options: [String] = []
        for line in text.components(separatedBy: "\n") {
            if let option = bulletOption(in: line) {
                options.append(option)
            } else {
                proseLines.append(line)
            }
        }
        let prose = proseLines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (prose, options)
    }

    /// Remove markdown emphasis markers (`**bold**`, `*italic*`) without
    /// running the AttributedString markdown parser. The BrainTrainer flow
    /// renders these strings as plain Text — keeping the markers literal
    /// would print "**堑**：..." with visible asterisks, which is uglier
    /// than just stripping them.
    private func stripMarkdownEmphasis(_ text: String) -> String {
        text
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
    }

    private func bulletOption(in line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        for prefix in ["- ", "* ", "• "] {
            if trimmed.hasPrefix(prefix) {
                let content = String(trimmed.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return content.isEmpty ? nil : content
            }
        }
        return nil
    }
}

/// The cathierSurface card style shared by the BrainTrainer chat bubbles:
/// surface fill, continuous rounded corners, and a hairline border.
private struct SurfaceCard: ViewModifier {
    var cornerRadius: CGFloat = 12
    func body(content: Content) -> some View {
        content
            .background(Color.cathierSurface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
    }
}

private extension View {
    func surfaceCard(cornerRadius: CGFloat = 12) -> some View {
        modifier(SurfaceCard(cornerRadius: cornerRadius))
    }
}
