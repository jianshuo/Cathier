import CloudKit

struct UserProfile: Identifiable {
    static let recordType = "UserProfile"

    let id: CKRecord.ID
    let displayName: String
    let avatarEmoji: String

    var reference: CKRecord.Reference {
        CKRecord.Reference(recordID: id, action: .none)
    }

    init(id: CKRecord.ID, displayName: String, avatarEmoji: String) {
        self.id = id
        self.displayName = displayName
        self.avatarEmoji = avatarEmoji
    }

    init?(record: CKRecord) {
        guard record.recordType == Self.recordType,
              let displayName = record["displayName"] as? String,
              let avatarEmoji = record["avatarEmoji"] as? String
        else { return nil }
        self.id = record.recordID
        self.displayName = displayName
        self.avatarEmoji = avatarEmoji
    }

    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: Self.recordType, recordID: id)
        record["displayName"] = displayName
        record["avatarEmoji"] = avatarEmoji
        return record
    }
}
