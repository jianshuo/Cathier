import SwiftUI

struct InviteView: View {
    @Environment(FriendViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    @State private var inviteLink: String?
    @State private var isGenerating = false
    @State private var generateError: String?

    @State private var manualCode = ""
    @State private var isAccepting = false
    @State private var acceptError: String?
    @State private var acceptSuccess = false

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // ── Send invite ──────────────────────────────────────────
                VStack(alignment: .leading, spacing: 12) {
                    Label("邀请好友", systemImage: "link")
                        .font(.headline)

                    Text("生成一个邀请链接，发给对方。对方点击后即可互相添加。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if let link = inviteLink {
                        HStack {
                            Text(link)
                                .font(.caption)
                                .fontDesign(.monospaced)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                            Spacer()
                            ShareLink(item: link) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }

                    if let error = generateError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    Button(action: generateAction) {
                        if isGenerating {
                            ProgressView().tint(.white)
                        } else {
                            Text(inviteLink == nil ? "生成邀请链接" : "重新生成")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(isGenerating ? Color.gray : Color.orange)
                    .cornerRadius(12)
                    .disabled(isGenerating)
                }
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)

                // ── Accept invite ────────────────────────────────────────
                VStack(alignment: .leading, spacing: 12) {
                    Label("输入邀请码", systemImage: "keyboard")
                        .font(.headline)

                    Text("如果朋友把邀请码发给了你，在这里输入。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if acceptSuccess {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("添加成功！")
                                .font(.subheadline)
                                .foregroundColor(.green)
                        }
                    }

                    TextField("输入8位邀请码…", text: $manualCode)
                        .textFieldStyle(.plain)
                        .textInputAutocapitalization(.characters)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .onChange(of: manualCode) { _, _ in acceptError = nil; acceptSuccess = false }

                    if let error = acceptError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    Button(action: acceptAction) {
                        if isAccepting {
                            ProgressView().tint(.white)
                        } else {
                            Text("确认添加")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(canAccept ? Color.orange : Color(.systemGray3))
                    .cornerRadius(12)
                    .disabled(!canAccept || isAccepting)
                }
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
            }
            .padding(20)
        }
        .navigationTitle("邀请 / 添加好友")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var canAccept: Bool {
        manualCode.trimmingCharacters(in: .whitespaces).count >= 6
    }

    private func generateAction() {
        isGenerating = true
        generateError = nil
        Task {
            do {
                inviteLink = try await vm.generateInviteLink()
            } catch {
                generateError = error.localizedDescription
            }
            isGenerating = false
        }
    }

    private func acceptAction() {
        isAccepting = true
        acceptError = nil
        Task {
            do {
                try await vm.acceptInvite(code: manualCode.trimmingCharacters(in: .whitespaces))
                acceptSuccess = true
                manualCode = ""
            } catch {
                acceptError = error.localizedDescription
            }
            isAccepting = false
        }
    }
}
