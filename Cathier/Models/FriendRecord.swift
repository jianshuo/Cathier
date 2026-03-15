import CloudKit
import Foundation

// Invite created by the sender (A). Deleted after B accepts or A cancels.
struct InviteRecord: Identifiable {
    static let recordType = "InviteCode"

    let id: CKRecord.ID
    let fromProfileRef: CKRecord.Reference
    let inviteCode: String
    let createdAt: Date

    init(fromProfileRef: CKRecord.Reference) {
        // Use the invite code as the record name so we can fetch by ID — no query needed.
        let code = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8)).uppercased()
        self.inviteCode = code
        self.id = CKRecord.ID(recordName: "invite_\(code)")
        self.fromProfileRef = fromProfileRef
        self.createdAt = Date()
    }

    init?(record: CKRecord) {
        guard record.recordType == Self.recordType,
              let fromProfileRef = record["fromProfileRef"] as? CKRecord.Reference,
              let inviteCode = record["inviteCode"] as? String,
              let createdAt = record["createdAt"] as? Date
        else { return nil }
        self.id = record.recordID
        self.fromProfileRef = fromProfileRef
        self.inviteCode = inviteCode
        self.createdAt = createdAt
    }

    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: Self.recordType, recordID: id)
        record["fromProfileRef"] = fromProfileRef
        record["inviteCode"] = inviteCode
        record["createdAt"] = createdAt
        return record
    }
}

// Friendship created by the accepter (B). Represents confirmed mutual connection.
struct FriendshipRecord: Identifiable {
    static let recordType = "Friendship"

    let id: CKRecord.ID
    let initiatorRef: CKRecord.Reference  // the inviter A
    let accepterRef: CKRecord.Reference   // the accepter B (record creator)
    let inviteCode: String
    let createdAt: Date

    init(initiatorRef: CKRecord.Reference, accepterRef: CKRecord.Reference, inviteCode: String) {
        self.id = CKRecord.ID(recordName: UUID().uuidString)
        self.initiatorRef = initiatorRef
        self.accepterRef = accepterRef
        self.inviteCode = inviteCode
        self.createdAt = Date()
    }

    init?(record: CKRecord) {
        guard record.recordType == Self.recordType,
              let initiatorRef = record["initiatorRef"] as? CKRecord.Reference,
              let accepterRef = record["accepterRef"] as? CKRecord.Reference,
              let inviteCode = record["inviteCode"] as? String,
              let createdAt = record["createdAt"] as? Date
        else { return nil }
        self.id = record.recordID
        self.initiatorRef = initiatorRef
        self.accepterRef = accepterRef
        self.inviteCode = inviteCode
        self.createdAt = createdAt
    }

    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: Self.recordType, recordID: id)
        record["initiatorRef"] = initiatorRef
        record["accepterRef"] = accepterRef
        record["inviteCode"] = inviteCode
        record["createdAt"] = createdAt
        return record
    }

    /// Returns the reference to the other person given my own profile ref.
    func friendRef(myProfileRef: CKRecord.Reference) -> CKRecord.Reference {
        initiatorRef.recordID == myProfileRef.recordID ? accepterRef : initiatorRef
    }
}
