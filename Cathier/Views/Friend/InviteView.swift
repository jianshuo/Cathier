import CloudKit
import SwiftUI

struct AddFriendView: View {
    @Environment(FriendViewModel.self) private var vm
    @Environment(LanguageManager.self) private var lm
    @Environment(\.dismiss) private var dismiss

    @State private var sendingToID: String?
    @State private var sendError: String?

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoadingUsers && vm.allUsers.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    userList
                }
            }
            .navigationTitle(lm.searchNavTitle)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: Binding(
                get: { vm.searchQuery },
                set: { vm.searchQuery = $0 }
            ), prompt: lm.searchPlaceholder)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lm.manageCancel) { dismiss() }
                }
            }
        }
        .task { await vm.loadAllUsers() }
        .onDisappear { vm.searchQuery = "" }
    }

    private var userList: some View {
        List {
            if vm.filteredUsers.isEmpty {
                Text(vm.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
                     ? lm.searchHint
                     : lm.searchNoResults)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(vm.filteredUsers) { profile in
                    userRow(profile)
                }
            }
        }
        .listStyle(.plain)
    }

    private func userRow(_ profile: UserProfile) -> some View {
        HStack(spacing: 12) {
            Text(profile.avatarEmoji)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(Color(.systemGray5))
                .clipShape(Circle())

            Text(profile.displayName)
                .font(.subheadline)
                .fontWeight(.medium)

            Spacer()

            actionButton(for: profile)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func actionButton(for profile: UserProfile) -> some View {
        if vm.isFriend(profile) {
            Text(lm.searchAlreadyFriends)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemGray5))
                .clipShape(Capsule())
        } else if vm.hasSentRequest(to: profile) {
            Text(lm.searchRequested)
                .font(.caption)
                .foregroundColor(.cathierAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.cathierAccent.opacity(0.12))
                .clipShape(Capsule())
        } else {
            Button { sendRequest(to: profile) } label: {
                if sendingToID == profile.id.recordName {
                    ProgressView()
                        .frame(width: 60, height: 28)
                } else {
                    Text(lm.searchAdd)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.cathierAccent)
                        .clipShape(Capsule())
                        .contentShape(Capsule())
                }
            }
            .buttonStyle(.plain)
            .disabled(sendingToID != nil)
        }
    }

    private func sendRequest(to profile: UserProfile) {
        sendingToID = profile.id.recordName
        sendError = nil
        Task {
            do {
                try await vm.sendFriendRequest(to: profile)
            } catch {
                sendError = error.localizedDescription
            }
            sendingToID = nil
        }
    }
}
