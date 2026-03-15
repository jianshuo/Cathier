import SwiftUI

struct FriendManageView: View {
    @Environment(FriendViewModel.self) private var vm
    @Environment(LanguageManager.self) private var lm
    @State private var showInviteView = false
    @State private var removingFriend: UserProfile?
    @State private var showRemoveAlert = false

    var body: some View {
        List {
            Section {
                Button(action: { showInviteView = true }) {
                    Label(lm.manageInviteAction, systemImage: "person.badge.plus")
                        .foregroundColor(.orange)
                }
            }

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
            } else {
                Section {
                    Text(lm.manageNoFriends)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle(lm.manageNavTitle)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showInviteView) {
            NavigationStack { InviteView() }
        }
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
}
