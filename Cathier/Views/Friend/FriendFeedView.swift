import CloudKit
import SwiftData
import SwiftUI

/// Entry point for the Friend tab. Switches on account state.
struct FriendFeedView: View {
    @Environment(FriendViewModel.self) private var vm
    @Environment(LanguageManager.self) private var lm

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
            .navigationTitle(lm.friendNavTitle)
            .navigationBarTitleDisplayMode(.large)
        }
        .task { await vm.initialize() }
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
    @Environment(LanguageManager.self) private var lm
    @Query(filter: #Predicate<DailyJournal> { $0.isShared }, sort: \DailyJournal.date, order: .reverse)
    private var sharedJournals: [DailyJournal]

    @State private var showAddFriendView = false

    private var hasFeedContent: Bool {
        !vm.friendCheckIns.isEmpty || !sharedJournals.isEmpty
    }

    var body: some View {
        Group {
            if vm.isLoadingFeed && vm.friendCheckIns.isEmpty && sharedJournals.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.friends.isEmpty {
                emptyFriendsView
            } else if !hasFeedContent {
                emptyFeedView
            } else {
                feedList
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: FriendManageView()) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "person.2.fill")
                        if vm.pendingRequestCount > 0 {
                            Text("\(vm.pendingRequestCount)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(3)
                                .background(Color.red)
                                .clipShape(Circle())
                                .offset(x: 10, y: -8)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAddFriendView) {
            AddFriendView()
        }
        .refreshable { await vm.loadFriendsAndFeed() }
    }

    // Unified feed item merging check-ins and shared journals, sorted latest first.
    private enum FeedItem: Identifiable {
        case checkIn(FriendCheckIn)
        case journal(DailyJournal)

        var id: String {
            switch self {
            case .checkIn(let c): return c.id.recordName
            case .journal(let j): return j.id.uuidString
            }
        }
        var date: Date {
            switch self {
            case .checkIn(let c): return c.date
            case .journal(let j): return j.date
            }
        }
    }

    private var mergedFeed: [FeedItem] {
        let checkIns = vm.friendCheckIns.map { FeedItem.checkIn($0) }
        let journals = sharedJournals.map { FeedItem.journal($0) }
        return (checkIns + journals).sorted { $0.date > $1.date }
    }

    private var feedList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                friendAvatarRow
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                Divider()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)

                ForEach(mergedFeed) { item in
                    switch item {
                    case .checkIn(let checkIn):
                        FriendCheckInCard(item: checkIn, owner: vm.profile(for: checkIn.ownerRef))
                    case .journal(let journal):
                        SharedJournalFeedRow(journal: journal, profile: vm.currentProfile)
                    }
                }

                Spacer(minLength: 24)
            }
        }
    }

    private var friendAvatarRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                Button(action: { showAddFriendView = true }) {
                    VStack(spacing: 4) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 22))
                            .foregroundColor(.cathierAccent)
                            .frame(width: 52, height: 52)
                            .background(Color.cathierAccent.opacity(0.12))
                            .clipShape(Circle())
                        Text(lm.manageAddFriend)
                            .font(.caption2)
                            .foregroundColor(.cathierAccent)
                            .lineLimit(1)
                            .frame(width: 52)
                    }
                }
                .buttonStyle(.plain)

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
            Text(lm.friendNoFriends)
                .font(.headline)
            Text(lm.friendAddHint)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button(action: { showAddFriendView = true }) {
                Text(lm.friendAddFriend)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Color.cathierAccent)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyFeedView: some View {
        VStack(spacing: 20) {
            Text("💤")
                .font(.system(size: 48))
            Text(lm.friendEmptyFeed)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button(action: { showAddFriendView = true }) {
                Label(lm.manageAddFriend, systemImage: "person.badge.plus")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Color.cathierAccent)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Per-person card tint palette

/// Five warm, muted tints — same aesthetic family, subtly different per person.
/// Picked deterministically from the owner's CloudKit record name hash.
private let cardTintPalette: [Color] = [
    Color(red: 0.878, green: 0.929, blue: 0.886), // sage    #E0EDE2
    Color(red: 0.996, green: 0.922, blue: 0.847), // peach   #FEEBD8
    Color(red: 0.918, green: 0.898, blue: 0.949), // lavender #EAE5F2
    Color(red: 0.961, green: 0.929, blue: 0.855), // wheat   #F5EDDA
    Color(red: 0.886, green: 0.929, blue: 0.953), // sky     #E3EEF3
]

private func cardTint(for profile: UserProfile?) -> Color {
    guard let profile else { return cardTintPalette[0] }
    let index = abs(profile.id.recordName.hashValue) % cardTintPalette.count
    return cardTintPalette[index]
}

// MARK: - Friend check-in card

struct FriendCheckInCard: View {
    let item: FriendCheckIn
    let owner: UserProfile?
    @Environment(LanguageManager.self) private var lm
    @Environment(FriendViewModel.self) private var vm
    @State private var showFullAI = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerRow
            emotionRow
            if item.privacyTier != .category, !item.bodyParts.isEmpty {
                bodyRow
            }
            if !item.aiFeedback.isEmpty {
                aiSnippet
            }
            reactionRow
        }
        .padding(14)
        .background(cardTint(for: owner))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 20)
        .padding(.vertical, 5)
        .sheet(isPresented: $showFullAI) {
            FriendAIDetailView(item: item, owner: owner)
        }
    }

    private var headerRow: some View {
        HStack(spacing: 10) {
            Text(owner?.avatarEmoji ?? "🙂")
                .font(.system(size: 28))
                .frame(width: 40, height: 40)
                .background(Color(.systemGray5))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(owner?.displayName ?? lm.friendDefaultName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(item.date.feedRelativeString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            IntensityBadge(intensity: item.intensity, label: lm.aiIntensityBadge(item.intensity))
        }
    }

    private var emotionRow: some View {
        FlowLayout(spacing: 6) {
            ForEach(visibleEmotions, id: \.self) { label in
                let color: Color = (item.privacyTier == .category)
                    ? .cathierSage
                    : EmotionData.category(for: label)?.color ?? .cathierSage
                Text(lm.display(label))
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.18))
                    .foregroundColor(color)
                    .clipShape(Capsule())
            }
        }
    }

    /// For .category tier, deduplicate and show category names; otherwise show emotion words.
    private var visibleEmotions: [String] {
        switch item.privacyTier {
        case .category:
            var seen = Set<String>()
            return item.emotions.compactMap { EmotionData.category(for: $0)?.nameZh }
                .filter { seen.insert($0).inserted }
        case .emotions, .full:
            return item.emotions
        }
    }

    private var bodyRow: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: "figure.stand")
                    .font(.caption2)
                    .foregroundColor(.cathierSage)
                Text(item.bodyParts.prefix(4).map { lm.display($0) }.joined(separator: "  ·  "))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if !cleanSensations.isEmpty {
                Text(cleanSensations.prefix(6).joined(separator: "  ·  "))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 16)
            }
        }
    }

    /// Sensation names with the "bodypart:" prefix stripped.
    private var cleanSensations: [String] {
        item.sensations.map { s in
            let parts = s.split(separator: ":", maxSplits: 1)
            return lm.display(parts.count == 2 ? String(parts[1]) : s)
        }
    }

    private var aiSnippet: some View {
        Button(action: { showFullAI = true }) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.caption2)
                    .foregroundColor(.cathierAccent)
                    .padding(.top, 3)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.aiFeedback.firstSentence)
                        .font(.cathierSerif(.subheadline))
                        .foregroundColor(.primary)
                        .lineSpacing(2)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(lm.aiReadMore)
                        .font(.caption2)
                        .foregroundColor(.cathierAccent)
                }
            }
            .padding(10)
            .background(Color.cathierAccentLight)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.cathierAccent.opacity(0.15), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var reactionRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ReactionRecord.allEmojis, id: \.self) { emoji in
                    let names = vm.reactorNames(emoji: emoji, on: item)
                    let isMine = vm.myReaction(on: item)?.emoji == emoji
                    Button {
                        Task { await vm.toggleReaction(emoji: emoji, on: item) }
                    } label: {
                        HStack(spacing: 3) {
                            Text(emoji)
                                .font(.system(size: 14))
                            if !names.isEmpty {
                                Text(names.joined(separator: " · "))
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(isMine ? .white : .secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isMine ? Color.cathierAccent : Color(.systemGray5))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 2)
    }
}

// MARK: - Shared journal feed row

struct SharedJournalFeedRow: View {
    let journal: DailyJournal
    let profile: UserProfile?
    @Environment(LanguageManager.self) private var lm

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerRow
            if !journal.gains.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(journal.gains)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineSpacing(2)
                    .lineLimit(4)
            }
        }
        .padding(14)
        .background(cardTint(for: profile))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 20)
        .padding(.vertical, 5)
    }

    private var headerRow: some View {
        HStack(spacing: 10) {
            Text(profile?.avatarEmoji ?? "🙂")
                .font(.system(size: 28))
                .frame(width: 40, height: 40)
                .background(Color(.systemGray5))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(profile?.displayName ?? lm.friendDefaultName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(journal.date.feedRelativeString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let mood = journal.dailyMood {
                Text("\(mood.emoji) \(mood.label(for: lm.currentLanguage))")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.cathierAccentLight)
                    .foregroundColor(Color.cathierAccent)
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - Friend AI detail sheet

struct FriendAIDetailView: View {
    let item: FriendCheckIn
    let owner: UserProfile?
    @Environment(LanguageManager.self) private var lm
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Owner header
                    HStack(spacing: 10) {
                        Text(owner?.avatarEmoji ?? "🙂")
                            .font(.system(size: 28))
                            .frame(width: 40, height: 40)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(owner?.displayName ?? lm.friendDefaultName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(item.date.feedRelativeString)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Full AI text
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.subheadline)
                            .foregroundColor(.cathierAccent)
                            .padding(.top, 2)
                        Text(item.aiFeedback)
                            .font(.cathierSerif(.body))
                            .foregroundColor(.primary)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(Color.cathierAccentLight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.cathierAccent.opacity(0.15), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .padding(20)
            }
            .navigationTitle(lm.aiFullInterpretation)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Date helper

private extension Date {
    var feedRelativeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter.string(from: self)
    }
}

// MARK: - String helper

private extension String {
    /// Returns the first sentence (up to the first .。!！?？ or newline), falling back to a 120-char prefix.
    var firstSentence: String {
        let terminators = CharacterSet(charactersIn: ".。!！?？\n")
        if let range = unicodeScalars.indices.first(where: { terminators.contains(unicodeScalars[$0]) }) {
            let endIndex = unicodeScalars.index(after: range)
            return String(self[..<endIndex]).trimmingCharacters(in: .whitespaces)
        }
        return count > 120 ? String(prefix(120)) + "…" : self
    }
}
