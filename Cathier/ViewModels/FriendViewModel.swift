import CloudKit
import Foundation
import Observation

@Observable
final class FriendViewModel {

    enum AccountState {
        case loading
        case unavailable(String)
        case needsProfile
        case ready(UserProfile)
    }

    var accountState: AccountState = .loading
    var friends: [UserProfile] = []
    var friendships: [FriendshipRecord] = []
    var friendCheckIns: [FriendCheckIn] = []
    var isLoadingFeed = false
    var error: String?

    // Friend requests
    var pendingRequests: [FriendRequestRecord] = []
    var pendingRequestSenders: [UserProfile] = []
    var sentRequestRecipientIDs: Set<String> = []

    // Reactions: keyed by check-in recordName → list of reactions
    var reactions: [String: [ReactionRecord]] = [:]

    // All users + local search filter
    var allUsers: [UserProfile] = []
    var isLoadingUsers = false
    var searchQuery: String = ""

    var filteredUsers: [UserProfile] {
        let q = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return allUsers }
        return allUsers.filter { $0.displayName.localizedCaseInsensitiveContains(q) }
    }

    private let ck = CloudKitService.shared
    private(set) var myProfileID: CKRecord.ID?

    var currentProfile: UserProfile? {
        if case .ready(let p) = accountState { return p }
        return nil
    }

    var pendingRequestCount: Int { pendingRequests.count }

    // MARK: - Initialise

    func initialize() async {
        guard case .loading = accountState else { return }
        t("FriendVM.initialize() — START")
        do {
            t("ck.accountStatus() — START")
            let status = try await ck.accountStatus()
            t("ck.accountStatus() — END: \(status.rawValue)")
            guard status == .available else {
                accountState = .unavailable("请在「系统设置」中登录 iCloud 以使用好友功能")
                return
            }
            t("ck.fetchCurrentUserRecordID() — START")
            let userRecordID = try await ck.fetchCurrentUserRecordID()
            t("ck.fetchCurrentUserRecordID() — END")
            myProfileID = userRecordID
            let profileID = CKRecord.ID(recordName: "profile_\(userRecordID.recordName)")
            t("ck.fetchProfile() — START")
            if let profile = try await ck.fetchProfile(id: profileID) {
                t("ck.fetchProfile() — END: found profile")
                accountState = .ready(profile)
                await loadFriendsAndFeed()
            } else {
                t("ck.fetchProfile() — END: no profile (needsSetup)")
                accountState = .needsProfile
            }
        } catch {
            t("FriendVM.initialize() — ERROR: \(error)")
            accountState = .unavailable("iCloud 暂时无法连接，请稍后再试")
        }
        t("FriendVM.initialize() — DONE")
    }

    // MARK: - Profile setup

    func createProfile(displayName: String, avatarEmoji: String) async throws {
        guard let userRecordID = myProfileID else { return }
        let profileID = CKRecord.ID(recordName: "profile_\(userRecordID.recordName)")
        let profile = UserProfile(id: profileID, displayName: displayName, avatarEmoji: avatarEmoji)
        let saved = try await ck.saveProfile(profile)
        accountState = .ready(saved)
        await loadFriendsAndFeed()
    }

    // MARK: - Friends & Feed

    func loadFriendsAndFeed() async {
        guard let profile = currentProfile else { return }
        isLoadingFeed = true
        defer { isLoadingFeed = false }
        do {
            async let friendshipsTask = ck.fetchFriendships(profileRef: profile.reference)
            async let receivedTask = ck.fetchReceivedRequests(toProfileRef: profile.reference)
            async let sentTask = ck.fetchSentRequests(fromProfileRef: profile.reference)

            let (fetchedFriendships, received, sent) = try await (friendshipsTask, receivedTask, sentTask)

            friendships = fetchedFriendships
            friends = try await ck.fetchFriendProfiles(friendships: friendships, myProfileRef: profile.reference)

            pendingRequests = received
            sentRequestRecipientIDs = Set(sent.map { $0.toProfileRef.recordID.recordName })

            if !received.isEmpty {
                pendingRequestSenders = try await ck.fetchProfiles(ids: received.map { $0.fromProfileRef.recordID })
            } else {
                pendingRequestSenders = []
            }

            let allRefs = friends.map { $0.reference } + [profile.reference]
            friendCheckIns = try await ck.fetchFriendCheckIns(friendProfileRefs: allRefs)

            // Load reactions for all visible check-ins
            let checkInRefs = friendCheckIns.map { CKRecord.Reference(recordID: $0.id, action: .none) }
            let fetchedReactions = try await ck.fetchReactions(for: checkInRefs)
            var grouped: [String: [ReactionRecord]] = [:]
            for r in fetchedReactions {
                let key = r.checkInRef.recordID.recordName
                grouped[key, default: []].append(r)
            }
            reactions = grouped
        } catch {
            self.error = error.localizedDescription
        }
    }

    func removeFriend(_ friend: UserProfile) async {
        guard let fs = friendship(with: friend) else { return }
        do {
            try await ck.deleteFriendship(id: fs.id)
            friendships.removeAll { $0.id == fs.id }
            friends.removeAll { $0.id == friend.id }
            friendCheckIns.removeAll { $0.ownerRef.recordID == friend.id }
        } catch {
            self.error = "删除好友失败：\(error.localizedDescription)"
        }
    }

    // MARK: - Load all users (for Add Friend screen)

    func loadAllUsers() async {
        guard !isLoadingUsers else { return }
        isLoadingUsers = true
        defer { isLoadingUsers = false }
        do {
            let all = try await ck.fetchAllProfiles()
            let myID = currentProfile?.id
            allUsers = all
                .filter { $0.id != myID }
                .sorted { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Friend Requests

    func sendFriendRequest(to profile: UserProfile) async throws {
        guard let myProfile = currentProfile else { throw ckError("未登录") }
        guard profile.id != myProfile.id else { throw ckError("不能添加自己") }
        guard !isFriend(profile) && !hasSentRequest(to: profile) else { return }

        let request = FriendRequestRecord(fromProfileRef: myProfile.reference, toProfileRef: profile.reference)
        _ = try await ck.saveFriendRequest(request)
        sentRequestRecipientIDs.insert(profile.id.recordName)
    }

    func acceptRequest(_ request: FriendRequestRecord) async throws {
        guard let myProfile = currentProfile else { throw ckError("未登录") }
        let fs = FriendshipRecord(initiatorRef: request.fromProfileRef, accepterRef: myProfile.reference)
        // Run both CloudKit writes; if either fails, throw before touching local state.
        let saved = try await ck.saveFriendship(fs)
        try await ck.deleteFriendRequest(id: request.id)
        // Both succeeded — update local state (no reload to avoid CloudKit propagation race).
        friendships.append(saved)
        if let senderProfile = pendingRequestSenders.first(where: { $0.id == request.fromProfileRef.recordID }) {
            friends.append(senderProfile)
        }
        pendingRequests.removeAll { $0.id == request.id }
        pendingRequestSenders.removeAll { $0.id == request.fromProfileRef.recordID }
    }

    func declineRequest(_ request: FriendRequestRecord) async throws {
        try await ck.deleteFriendRequest(id: request.id)
        pendingRequests.removeAll { $0.id == request.id }
        pendingRequestSenders.removeAll { $0.id == request.fromProfileRef.recordID }
    }

    // MARK: - Shared check-ins

    func shareCheckIn(_ checkIn: CheckIn, tier: FriendCheckIn.PrivacyTier, shareAIFeedback: Bool = false) async throws {
        guard let profile = currentProfile else { return }
        let shared = FriendCheckIn(ownerRef: profile.reference, checkIn: checkIn, privacyTier: tier, shareAIFeedback: shareAIFeedback)
        try await ck.saveSharedCheckIn(shared)
        checkIn.shareLevel = tier.rawValue
    }

    func unshareCheckIn(_ checkIn: CheckIn) async throws {
        try await ck.deleteSharedCheckIn(localID: checkIn.id.uuidString)
        checkIn.shareLevel = nil
    }

    // MARK: - Reactions

    func reactions(for checkIn: FriendCheckIn) -> [ReactionRecord] {
        reactions[checkIn.id.recordName] ?? []
    }

    func myReaction(on checkIn: FriendCheckIn) -> ReactionRecord? {
        guard let myProfile = currentProfile else { return nil }
        return reactions(for: checkIn).first { $0.fromProfileRef.recordID == myProfile.id }
    }

    func reactionCount(emoji: String, on checkIn: FriendCheckIn) -> Int {
        reactions(for: checkIn).filter { $0.emoji == emoji }.count
    }

    /// Display names of everyone who reacted with a given emoji.
    /// The current user is shown as "你" (always first if present).
    func reactorNames(emoji: String, on checkIn: FriendCheckIn) -> [String] {
        let rs = reactions(for: checkIn).filter { $0.emoji == emoji }
        let myID = currentProfile?.id
        return rs
            .sorted { a, _ in a.fromProfileRef.recordID == myID }  // self first
            .map { r in
                r.fromProfileRef.recordID == myID
                    ? "你"
                    : (profile(for: r.fromProfileRef)?.displayName ?? "…")
            }
    }

    /// Toggle: tap the same emoji removes it; tap a different emoji replaces it; tap with none adds it.
    func toggleReaction(emoji: String, on checkIn: FriendCheckIn) async {
        guard let myProfile = currentProfile else { return }
        let key = checkIn.id.recordName
        let checkInRef = CKRecord.Reference(recordID: checkIn.id, action: .none)
        let existing = myReaction(on: checkIn)

        if let existing {
            // Remove from local state immediately
            reactions[key]?.removeAll { $0.id == existing.id }
            try? await ck.deleteReaction(id: existing.id)

            if existing.emoji == emoji { return }  // same emoji → just remove
        }

        // Add new reaction
        let newReaction = ReactionRecord(
            checkInRef: checkInRef,
            fromProfileRef: myProfile.reference,
            emoji: emoji
        )
        reactions[key, default: []].append(newReaction)
        try? await ck.saveReaction(newReaction)
    }

    // MARK: - Helpers

    func profile(for ownerRef: CKRecord.Reference) -> UserProfile? {
        if let currentProfile, ownerRef.recordID == currentProfile.id {
            return currentProfile
        }
        return friends.first { $0.id == ownerRef.recordID }
    }

    func friendship(with friend: UserProfile) -> FriendshipRecord? {
        guard let myProfile = currentProfile else { return nil }
        return friendships.first {
            ($0.initiatorRef.recordID == myProfile.id && $0.accepterRef.recordID == friend.id) ||
            ($0.accepterRef.recordID == myProfile.id && $0.initiatorRef.recordID == friend.id)
        }
    }

    func isFriend(_ profile: UserProfile) -> Bool {
        friendship(with: profile) != nil
    }

    func hasSentRequest(to profile: UserProfile) -> Bool {
        sentRequestRecipientIDs.contains(profile.id.recordName)
    }

    func sender(for request: FriendRequestRecord) -> UserProfile? {
        pendingRequestSenders.first { $0.id == request.fromProfileRef.recordID }
    }

    private func ckError(_ message: String) -> NSError {
        NSError(domain: "Cathier", code: 0, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
