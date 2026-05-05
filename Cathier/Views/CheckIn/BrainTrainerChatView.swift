import SwiftUI

struct BrainTrainerChatView: View {
    @Environment(CheckInViewModel.self) private var viewModel
    @Environment(LanguageManager.self) private var lm
    @Environment(ThemeManager.self) private var themeManager
    let onSave: () -> Void

    @State private var inputText = ""
    @FocusState private var inputFocused: Bool

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
                            .foregroundColor(themeManager.accentColor)
                        Text("复盘完成")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(themeManager.accentColor)
                    }

                    if viewModel.isGeneratingSummary {
                        HStack(spacing: 10) {
                            ProgressView().tint(themeManager.accentColor)
                            Text("正在生成总结…")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else if !viewModel.brainTrainerSummary.isEmpty {
                        MarkdownText(raw: viewModel.brainTrainerSummary,
                                     font: .cathierSerif(.body),
                                     paragraphSpacing: 8,
                                     lineSpacing: 5)
                            .foregroundColor(.primary)
                            .transition(.opacity)
                    } else if let err = viewModel.brainTrainerError {
                        errorRow(err)
                    }
                }
                .padding(16)
            }
            .background(themeManager.accentColorLight)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(themeManager.accentColor.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Spacer(minLength: 0)
            saveButton
        }
        .task {
            if viewModel.brainTrainerSummary.isEmpty && !viewModel.isGeneratingSummary {
                await viewModel.generateBrainTrainerSummary()
            }
        }
    }

    // MARK: - Chat (5-step conversation)

    private var chatView: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
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
                .onChange(of: viewModel.brainTrainerMessages.count) { _, _ in
                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo("bottom")
                    }
                }
                .onChange(of: viewModel.isBrainTrainerLoading) { _, _ in
                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo("bottom")
                    }
                }
            }

            Divider()
            inputBar
        }
    }

    // MARK: - Bubbles

    private func assistantBubble(_ msg: BrainTrainerMessage) -> some View {
        let clean = msg.displayContent.replacingOccurrences(of: "<complete/>", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        let parsed = parseOptions(clean)
        return VStack(alignment: .leading, spacing: 10) {
            if !parsed.mainText.isEmpty {
                MarkdownText(raw: parsed.mainText,
                             font: .cathierSerif(.body),
                             paragraphSpacing: 6,
                             lineSpacing: 4)
                    .foregroundColor(.primary)
                    .padding(14)
                    .background(Color.cathierSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !parsed.options.isEmpty {
                optionChips(parsed.options)
            }
        }
    }

    private func userBubble(_ msg: BrainTrainerMessage) -> some View {
        Text(msg.displayContent)
            .font(.body)
            .foregroundColor(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(themeManager.accentColorLight)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var loadingBubble: some View {
        HStack(spacing: 8) {
            ProgressView()
                .tint(themeManager.accentColor)
                .scaleEffect(0.8)
            Text(lm.aiLoading)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.cathierSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
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
            .foregroundColor(themeManager.accentColor)
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
                    .foregroundColor(canSend ? themeManager.accentColor : .secondary)
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
        Button(action: onSave) {
            Text(lm.aiSave)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(themeManager.accentColor)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .padding(.top, 6)
        .background(Color.cathierSurface)
    }

    // MARK: - Helpers

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

    // Parse <options><option>…</option></options> blocks out of AI response.
    // Returns prose (text outside the block) + extracted option strings.
    private func parseOptions(_ text: String) -> (mainText: String, options: [String]) {
        guard let blockStart = text.range(of: "<options>"),
              let blockEnd   = text.range(of: "</options>") else {
            return (text, [])
        }

        let before = String(text[text.startIndex..<blockStart.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let after  = String(text[blockEnd.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let prose  = [before, after].filter { !$0.isEmpty }.joined(separator: "\n\n")

        var options: [String] = []
        var remaining = String(text[blockStart.upperBound..<blockEnd.lowerBound])
        while let s = remaining.range(of: "<option>"),
              let e = remaining.range(of: "</option>") {
            let option = String(remaining[s.upperBound..<e.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !option.isEmpty { options.append(option) }
            remaining = String(remaining[e.upperBound...])
        }

        return (prose, options)
    }
}
