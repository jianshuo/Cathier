import SwiftUI

struct FriendManageView: View {
    @Environment(FriendViewModel.self) private var vm
    @Environment(LanguageManager.self) private var lm
    @State private var removingFriend: UserProfile?
    @State private var showRemoveAlert = false

    var body: some View {
        List {
            // Pending incoming requests
            if !vm.pendingRequests.isEmpty {
                Section(lm.requestPendingSection) {
                    ForEach(vm.pendingRequests) { request in
                        requestRow(request)
                    }
                }
            }

            // Connected friends
            if !vm.friends.isEmpty {
                Section(lm.manageConnectedFriends(vm.friends.count)) {
                    ForEach(vm.friends) { friend in
                        HStack(spacing: 12) {
                            Text(friend.avatarEmoji)
                                .font(.title2)
                                .frame(width: 40, height: 40)
                                .background(Color(.systemGray5))
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(friend.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                if let fs = vm.friendship(with: friend) {
                                    Text(lm.manageConnectedOn(fs.createdAt.formatted(date: .abbreviated, time: .omitted)))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                removingFriend = friend
                                showRemoveAlert = true
                            } label: {
                                Label(lm.manageDisconnect, systemImage: "person.fill.xmark")
                            }
                        }
                    }
                }
            } else if vm.pendingRequests.isEmpty {
                Section {
                    Text(lm.manageNoFriends)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle(lm.manageNavTitle)
        .navigationBarTitleDisplayMode(.inline)
        .alert(lm.manageDisconnectAlert(removingFriend?.displayName ?? ""), isPresented: $showRemoveAlert) {
            Button(lm.manageDisconnect, role: .destructive) {
                if let friend = removingFriend {
                    Task { await vm.removeFriend(friend) }
                }
            }
            Button(lm.manageCancel, role: .cancel) {}
        } message: {
            Text(lm.manageDisconnectMessage)
        }
    }

    private func requestRow(_ request: FriendRequestRecord) -> some View {
        HStack(spacing: 12) {
            let sender = vm.sender(for: request)
            Text(sender?.avatarEmoji ?? "🙂")
                .font(.title2)
                .frame(width: 40, height: 40)
                .background(Color(.systemGray5))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(sender?.displayName ?? lm.friendDefaultName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(lm.requestFrom)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button(lm.requestDecline) {
                    Task { try? await vm.declineRequest(request) }
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                .contentShape(Rectangle())
                .buttonStyle(.plain)

                Button(lm.requestAccept) {
                    Task { try? await vm.acceptRequest(request) }
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange)
                .clipShape(Capsule())
                .contentShape(Capsule())
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}
