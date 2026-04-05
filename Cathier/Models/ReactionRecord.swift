import CloudKit
import Foundation

// MARK: - Reaction (emoji response to a friend's check-in)

struct ReactionRecord: Identifiable {
    static let recordType = "Reaction"

    /// Three supported reaction emojis.
    static let allEmojis: [String] = ["❤️", "🤗", "💪"]

    let id: CKRecord.ID
    let checkInRef: CKRecord.Reference   // → SharedCheckIn record
    let fromProfileRef: CKRecord.Reference // → UserProfile of reactor
    let emoji: String
    let createdAt: Date

    /// Deterministic record name so each (user, checkIn) pair has at most one reaction.
    static func recordID(profileID: CKRecord.ID, checkInID: CKRecord.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: "reaction_\(profileID.recordName)_\(checkInID.recordName)")
    }

    init(checkInRef: CKRecord.Reference, fromProfileRef: CKRecord.Reference, emoji: String) {
        self.id = ReactionRecord.recordID(
            profileID: fromProfileRef.recordID,
            checkInID: checkInRef.recordID
        )
        self.checkInRef = checkInRef
        self.fromProfileRef = fromProfileRef
        self.emoji = emoji
        self.createdAt = Date()
    }

    init?(record: CKRecord) {
        guard record.recordType == Self.recordType,
              let checkInRef = record["checkInRef"] as? CKRecord.Reference,
              let fromProfileRef = record["fromProfileRef"] as? CKRecord.Reference,
              let emoji = record["emoji"] as? String,
              let createdAt = record["createdAt"] as? Date
        else { return nil }
        self.id = record.recordID
        self.checkInRef = checkInRef
        self.fromProfileRef = fromProfileRef
        self.emoji = emoji
        self.createdAt = createdAt
    }

    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: Self.recordType, recordID: id)
        record["checkInRef"] = checkInRef
        record["fromProfileRef"] = fromProfileRef
        record["emoji"] = emoji
        record["createdAt"] = createdAt
        return record
    }
}
