import CloudKit
import Foundation

// MARK: - FriendRequest (sent by A, pending acceptance by B)

struct FriendRequestRecord: Identifiable {
    static let recordType = "FriendRequest"

    let id: CKRecord.ID
    let fromProfileRef: CKRecord.Reference
    let toProfileRef: CKRecord.Reference
    let createdAt: Date

    init(fromProfileRef: CKRecord.Reference, toProfileRef: CKRecord.Reference) {
        self.id = CKRecord.ID(recordName: UUID().uuidString)
        self.fromProfileRef = fromProfileRef
        self.toProfileRef = toProfileRef
        self.createdAt = Date()
    }

    init?(record: CKRecord) {
        guard record.recordType == Self.recordType,
              let fromProfileRef = record["fromProfileRef"] as? CKRecord.Reference,
              let toProfileRef = record["toProfileRef"] as? CKRecord.Reference,
              let createdAt = record["createdAt"] as? Date
        else { return nil }
        self.id = record.recordID
        self.fromProfileRef = fromProfileRef
        self.toProfileRef = toProfileRef
        self.createdAt = createdAt
    }

    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: Self.recordType, recordID: id)
        record["fromProfileRef"] = fromProfileRef
        record["toProfileRef"] = toProfileRef
        record["createdAt"] = createdAt
        return record
    }
}

// MARK: - Friendship (confirmed mutual connection)

struct FriendshipRecord: Identifiable {
    static let recordType = "Friendship"

    let id: CKRecord.ID
    let initiatorRef: CKRecord.Reference  // the requester
    let accepterRef: CKRecord.Reference   // the approver
    let createdAt: Date

    init(initiatorRef: CKRecord.Reference, accepterRef: CKRecord.Reference) {
        self.id = CKRecord.ID(recordName: UUID().uuidString)
        self.initiatorRef = initiatorRef
        self.accepterRef = accepterRef
        self.createdAt = Date()
    }

    init?(record: CKRecord) {
        guard record.recordType == Self.recordType,
              let initiatorRef = record["initiatorRef"] as? CKRecord.Reference,
              let accepterRef = record["accepterRef"] as? CKRecord.Reference,
              let createdAt = record["createdAt"] as? Date
        else { return nil }
        self.id = record.recordID
        self.initiatorRef = initiatorRef
        self.accepterRef = accepterRef
        self.createdAt = createdAt
    }

    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: Self.recordType, recordID: id)
        record["initiatorRef"] = initiatorRef
        record["accepterRef"] = accepterRef
        record["createdAt"] = createdAt
        return record
    }

    func friendRef(myProfileRef: CKRecord.Reference) -> CKRecord.Reference {
        initiatorRef.recordID == myProfileRef.recordID ? accepterRef : initiatorRef
    }
}
