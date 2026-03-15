import CloudKit
import Foundation

final class CloudKitService {
    static let shared = CloudKitService()

    // ⚠️ Replace with your container ID from Xcode → Signing & Capabilities → iCloud
    private let container = CKContainer(identifier: "iCloud.com.wangjianshuo.Cathier")
    private var db: CKDatabase { container.publicCloudDatabase }

    // MARK: - Account

    func accountStatus() async throws -> CKAccountStatus {
        try await container.accountStatus()
    }

    func fetchCurrentUserRecordID() async throws -> CKRecord.ID {
        try await container.userRecordID()
    }

    // MARK: - UserProfile

    func fetchProfile(id: CKRecord.ID) async throws -> UserProfile? {
        do {
            let record = try await db.record(for: id)
            return UserProfile(record: record)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    func saveProfile(_ profile: UserProfile) async throws -> UserProfile {
        let record = try await db.save(profile.toRecord())
        return UserProfile(record: record) ?? profile
    }

    // MARK: - InviteCode

    func saveInvite(_ invite: InviteRecord) async throws -> InviteRecord {
        let record = try await db.save(invite.toRecord())
        return InviteRecord(record: record) ?? invite
    }

    func fetchInvite(code: String) async throws -> InviteRecord? {
        // Invite code IS the record name — direct fetch, no query or indexing needed.
        do {
            let record = try await db.record(for: CKRecord.ID(recordName: "invite_\(code)"))
            return InviteRecord(record: record)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    func deleteInvite(id: CKRecord.ID) async throws {
        _ = try await db.deleteRecord(withID: id)
    }

    // MARK: - Friendship

    func saveFriendship(_ friendship: FriendshipRecord) async throws -> FriendshipRecord {
        let record = try await db.save(friendship.toRecord())
        return FriendshipRecord(record: record) ?? friendship
    }

    /// CloudKit doesn't support OR predicates, so we run two queries in parallel.
    func fetchFriendships(profileRef: CKRecord.Reference) async throws -> [FriendshipRecord] {
        async let asInitiator = fetchFriendships(field: "initiatorRef", ref: profileRef)
        async let asAccepter = fetchFriendships(field: "accepterRef", ref: profileRef)
        let (a, b) = try await (asInitiator, asAccepter)
        return a + b
    }

    private func fetchFriendships(field: String, ref: CKRecord.Reference) async throws -> [FriendshipRecord] {
        let predicate = NSPredicate(format: "%K == %@", field, ref)
        let query = CKQuery(recordType: FriendshipRecord.recordType, predicate: predicate)
        let (results, _) = try await db.records(matching: query)
        return results
            .compactMap { try? $0.1.get() }
            .compactMap { FriendshipRecord(record: $0) }
    }

    func deleteFriendship(id: CKRecord.ID) async throws {
        _ = try await db.deleteRecord(withID: id)
    }

    func fetchFriendProfiles(
        friendships: [FriendshipRecord],
        myProfileRef: CKRecord.Reference
    ) async throws -> [UserProfile] {
        let ids = friendships.map { $0.friendRef(myProfileRef: myProfileRef).recordID }
        guard !ids.isEmpty else { return [] }
        let results = try await db.records(for: ids)
        return results.values
            .compactMap { try? $0.get() }
            .compactMap { UserProfile(record: $0) }
    }

    // MARK: - SharedCheckIn

    func saveSharedCheckIn(_ checkIn: FriendCheckIn) async throws {
        _ = try await db.save(checkIn.toRecord())
    }

    func deleteSharedCheckIn(localID: String) async throws {
        _ = try await db.deleteRecord(withID: CKRecord.ID(recordName: localID))
    }

    func fetchFriendCheckIns(friendProfileRefs: [CKRecord.Reference]) async throws -> [FriendCheckIn] {
        guard !friendProfileRefs.isEmpty else { return [] }
        let predicate = NSPredicate(format: "ownerRef IN %@", friendProfileRefs)
        let query = CKQuery(recordType: FriendCheckIn.recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        let (results, _) = try await db.records(matching: query, resultsLimit: 50)
        return results
            .compactMap { try? $0.1.get() }
            .compactMap { FriendCheckIn(record: $0) }
    }
}
