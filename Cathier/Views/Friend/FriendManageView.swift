import SwiftUI

struct FriendManageView: View {
    @Environment(FriendViewModel.self) private var vm
    @State private var showInviteView = false
    @State private var removingFriend: UserProfile?
    @State private var showRemoveAlert = false

    var body: some View {
        List {
            Section {
                Button(action: { showInviteView = true }) {
                    Label("邀请好友 / 输入邀请码", systemImage: "person.badge.plus")
                        .foregroundColor(.orange)
                }
            }

            if !vm.friends.isEmpty {
                Section("已连接的好友 (\(vm.friends.count))") {
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
                                    Text("连接于 \(fs.createdAt.formatted(date: .abbreviated, time: .omitted))")
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
                                Label("断开连接", systemImage: "person.fill.xmark")
                            }
                        }
                    }
                }
            } else {
                Section {
                    Text("还没有好友，发送邀请链接来连接吧")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("好友管理")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showInviteView) {
            NavigationStack { InviteView() }
        }
        .alert("断开与「\(removingFriend?.displayName ?? "")」的连接？", isPresented: $showRemoveAlert) {
            Button("断开连接", role: .destructive) {
                if let friend = removingFriend {
                    Task { await vm.removeFriend(friend) }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("双方将不再能看到彼此分享的情绪记录")
        }
    }
}
