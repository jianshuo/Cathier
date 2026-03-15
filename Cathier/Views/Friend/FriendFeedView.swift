import Combine
import SwiftUI

/// Entry point for the Friend tab. Switches on account state.
struct FriendFeedView: View {
    @Environment(FriendViewModel.self) private var vm

    var body: some View {
        NavigationStack {
            Group {
                switch vm.accountState {
                case .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .unavailable(let message):
                    unavailableView(message)

                case .needsProfile:
                    FriendSetupView()

                case .ready:
                    FriendHomeView()
                }
            }
            .navigationTitle("好友")
            .navigationBarTitleDisplayMode(.large)
        }
        .task { await vm.initialize() }
        .onReceive(NotificationCenter.default.publisher(for: .cathierInviteReceived)) { note in
            guard let code = note.userInfo?["code"] as? String else { return }
            vm.pendingInviteCode = code
            vm.showInviteAcceptSheet = true
        }
        .sheet(isPresented: Binding(
            get: { vm.showInviteAcceptSheet },
            set: { vm.showInviteAcceptSheet = $0 }
        )) {
            if let code = vm.pendingInviteCode {
                InviteAcceptSheet(code: code)
            }
        }
    }

    @ViewBuilder
    private func unavailableView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "icloud.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Home (after setup)

private struct FriendHomeView: View {
    @Environment(FriendViewModel.self) private var vm

    var body: some View {
        Group {
            if vm.isLoadingFeed && vm.friendCheckIns.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.friends.isEmpty {
                emptyFriendsView
            } else if vm.friendCheckIns.isEmpty {
                emptyFeedView
            } else {
                feedList
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: FriendManageView()) {
                    Image(systemName: "person.2.fill")
                }
            }
        }
        .refreshable { await vm.loadFriendsAndFeed() }
    }

    private var feedList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Friend avatars row
                friendAvatarRow
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                Divider()
                    .padding(.horizontal, 20)

                // Check-in feed
                ForEach(vm.friendCheckIns) { item in
                    FriendCheckInCard(item: item, owner: vm.profile(for: item.ownerRef))
                    Divider()
                        .padding(.leading, 72)
                }
            }
        }
    }

    private var friendAvatarRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(vm.friends) { friend in
                    VStack(spacing: 4) {
                        Text(friend.avatarEmoji)
                            .font(.system(size: 36))
                            .frame(width: 52, height: 52)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                        Text(friend.displayName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .frame(width: 52)
                    }
                }
            }
        }
    }

    private var emptyFriendsView: some View {
        VStack(spacing: 20) {
            Text("🤝")
                .font(.system(size: 56))
            Text("还没有好友")
                .font(.headline)
            Text("邀请朋友互相分享情绪吧")
                .font(.subheadline)
                .foregroundColor(.secondary)
            NavigationLink(destination: InviteView()) {
                Text("邀请好友")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Color.orange)
                    .cornerRadius(22)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyFeedView: some View {
        VStack(spacing: 16) {
            Text("💤")
                .font(.system(size: 48))
            Text("好友还没有分享任何情绪")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Friend check-in card

struct FriendCheckInCard: View {
    let item: FriendCheckIn
    let owner: UserProfile?

    @State private var expanded = false

    var body: some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() } }) {
            VStack(alignment: .leading, spacing: 0) {
                headerRow
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)

                if expanded {
                    expandedContent
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var headerRow: some View {
        HStack(spacing: 12) {
            Text(owner?.avatarEmoji ?? "🙂")
                .font(.system(size: 28))
                .frame(width: 44, height: 44)
                .background(Color(.systemGray5))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(owner?.displayName ?? "朋友")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 6) {
                    categoryChip
                    Text(item.date.relativeString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var categoryChip: some View {
        if let category = item.emotions.first.flatMap({ EmotionData.category(for: $0) }) {
            Text(category.nameZh)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(category.color.opacity(0.15))
                .foregroundColor(category.color)
                .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Intensity
            HStack {
                IntensityBadge(intensity: item.intensity)
                Spacer()
            }

            // Emotions (shown for .emotions and .full tiers)
            if item.privacyTier != .category && !item.emotions.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(item.emotions, id: \.self) { emotion in
                        let color = EmotionData.category(for: emotion)?.color ?? .orange
                        Text(emotion)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(color.opacity(0.12))
                            .foregroundColor(color)
                            .clipShape(Capsule())
                    }
                }
            }

            // Full tier extras
            if item.privacyTier == .full {
                if !item.bodyParts.isEmpty {
                    Text(item.bodyParts.joined(separator: " · "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if !item.note.isEmpty {
                    Text(item.note)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
        }
    }
}

// MARK: - Invite accept sheet (shown via deep link)

private struct InviteAcceptSheet: View {
    let code: String
    @Environment(FriendViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = false
    @State private var error: String?
    @State private var accepted = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if accepted {
                    VStack(spacing: 12) {
                        Text("🎉")
                            .font(.system(size: 56))
                        Text("已成功添加好友！")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 12) {
                        Text("🤝")
                            .font(.system(size: 48))
                        Text("收到一个好友邀请")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("邀请码：\(code)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fontDesign(.monospaced)
                    }
                    .frame(maxWidth: .infinity)

                    if let error {
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button(action: acceptAction) {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("接受邀请")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isLoading ? Color.gray : Color.orange)
                    .cornerRadius(14)
                    .disabled(isLoading)
                    .padding(.horizontal, 24)
                }
            }
            .padding()
            .navigationTitle("好友邀请")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("稍后再说") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func acceptAction() {
        isLoading = true
        error = nil
        Task {
            do {
                try await vm.acceptInvite(code: code)
                accepted = true
                vm.pendingInviteCode = nil
                vm.showInviteAcceptSheet = false
                try? await Task.sleep(for: .seconds(1.2))
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Date helper

private extension Date {
    var relativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
