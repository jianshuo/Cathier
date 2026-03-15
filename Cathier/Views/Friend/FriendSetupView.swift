import SwiftUI

struct FriendSetupView: View {
    @Environment(FriendViewModel.self) private var vm
    @Environment(LanguageManager.self) private var lm

    @State private var displayName = ""
    @State private var avatarEmoji = "🙂"
    @State private var isLoading = false
    @State private var error: String?

    private let suggestedEmojis = [
        "🙂","😄","😎","🤩","🥰","😊","🤔","😴",
        "🌟","🦋","🌈","🍀","🌸","🔥","⚡","🎯",
        "🐱","🐶","🦊","🐼","🐨","🦁","🐸","🐧",
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    Text(avatarEmoji)
                        .font(.system(size: 72))
                    Text(lm.setupTitle)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(lm.setupSubtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)

                // Emoji picker
                VStack(alignment: .leading, spacing: 10) {
                    Text(lm.setupChooseEmoji)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                        ForEach(suggestedEmojis, id: \.self) { emoji in
                            Button(action: { avatarEmoji = emoji }) {
                                Text(emoji)
                                    .font(.title2)
                                    .frame(width: 40, height: 40)
                                    .background(avatarEmoji == emoji ? Color.orange.opacity(0.2) : Color(.systemGray6))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(avatarEmoji == emoji ? Color.orange : Color.clear, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)

                // Name input
                VStack(alignment: .leading, spacing: 8) {
                    Text(lm.setupNicknameLabel)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    TextField(lm.setupNicknamePlaceholder, text: $displayName)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                .padding(.horizontal, 20)

                if let error {
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .padding(.horizontal, 20)
                }

                Button(action: confirmAction) {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text(lm.setupDone)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canConfirm ? Color.orange : Color(.systemGray3))
                .cornerRadius(14)
                .disabled(!canConfirm || isLoading)
                .padding(.horizontal, 20)
            }
        }
    }

    private var canConfirm: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func confirmAction() {
        isLoading = true
        error = nil
        Task {
            do {
                try await vm.createProfile(
                    displayName: displayName.trimmingCharacters(in: .whitespaces),
                    avatarEmoji: avatarEmoji
                )
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
}
