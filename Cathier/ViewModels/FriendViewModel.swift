import CloudKit
import Foundation
import Observation

@Observable
final class FriendViewModel {

    enum AccountState {
        case loading
        case unavailable(String)  // message to show user
        case needsProfile
        case ready(UserProfile)
    }

    var accountState: AccountState = .loading
    var friends: [UserProfile] = []
    var friendships: [FriendshipRecord] = []
    var friendCheckIns: [FriendCheckIn] = []
    var isLoadingFeed = false
    var error: String?

    /// Set when app opens a cathier://invite?code= deep link
    var pendingInviteCode: String?
    var showInviteAcceptSheet = false

    private let ck = CloudKitService.shared
    private(set) var myProfileID: CKRecord.ID?

    var currentProfile: UserProfile? {
        if case .ready(let p) = accountState { return p }
        return nil
    }

    // MARK: - Initialise

    func initialize() async {
        do {
            let status = try await ck.accountStatus()
            guard status == .available else {
                accountState = .unavailable("请在「系统设置」中登录 iCloud 以使用好友功能")
                return
            }
            let userRecordID = try await ck.fetchCurrentUserRecordID()
            myProfileID = userRecordID
            let profileID = CKRecord.ID(recordName: "profile_\(userRecordID.recordName)")
            if let profile = try await ck.fetchProfile(id: profileID) {
                accountState = .ready(profile)
                await loadFriendsAndFeed()
            } else {
                accountState = .needsProfile
            }
        } catch {
            accountState = .unavailable("iCloud 暂时无法连接，请稍后再试")
        }
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
            friendships = try await ck.fetchFriendships(profileRef: profile.reference)
            friends = try await ck.fetchFriendProfiles(friendships: friendships, myProfileRef: profile.reference)
            let allRefs = friends.map { $0.reference } + [profile.reference]
            friendCheckIns = try await ck.fetchFriendCheckIns(friendProfileRefs: allRefs)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func removeFriend(_ friend: UserProfile) async {
        guard let profile = currentProfile,
              let fs = friendship(with: friend)
        else { return }
        try? await ck.deleteFriendship(id: fs.id)
        friendships.removeAll { $0.id == fs.id }
        friends.removeAll { $0.id == friend.id }
        friendCheckIns.removeAll { $0.ownerRef.recordID == friend.id }
        // Refresh full list in background in case we couldn't delete (not the owner)
        await loadFriendsAndFeed()
        _ = profile  // suppress warning
    }

    // MARK: - Invite

    func generateInviteLink() async throws -> String {
        guard let profile = currentProfile else { throw ckError("未登录") }
        let invite = InviteRecord(fromProfileRef: profile.reference)
        let saved = try await ck.saveInvite(invite)
        return "cathier://invite?code=\(saved.inviteCode)"
    }

    func acceptInvite(code: String) async throws {
        guard let myProfile = currentProfile else { throw ckError("未登录") }
        guard let invite = try await ck.fetchInvite(code: code.uppercased()) else {
            throw ckError("邀请码无效或已过期")
        }
        guard invite.fromProfileRef.recordID != myProfile.id else {
            throw ckError("不能添加自己哦")
        }
        let alreadyFriend = friendships.contains {
            $0.initiatorRef.recordID == invite.fromProfileRef.recordID ||
            $0.accepterRef.recordID == invite.fromProfileRef.recordID
        }
        guard !alreadyFriend else { return }  // already connected, silently succeed

        let fs = FriendshipRecord(
            initiatorRef: invite.fromProfileRef,
            accepterRef: myProfile.reference,
            inviteCode: code.uppercased()
        )
        let saved = try await ck.saveFriendship(fs)
        friendships.append(saved)
        await loadFriendsAndFeed()
    }

    // MARK: - Shared check-ins (Phase 2)

    func shareCheckIn(_ checkIn: CheckIn, tier: FriendCheckIn.PrivacyTier) async throws {
        guard let profile = currentProfile else { return }
        let shared = FriendCheckIn(ownerRef: profile.reference, checkIn: checkIn, privacyTier: tier)
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

    private func ckError(_ message: String) -> NSError {
        NSError(domain: "Cathier", code: 0, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
