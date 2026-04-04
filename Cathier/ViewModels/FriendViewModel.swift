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
