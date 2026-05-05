import CloudKit
import Foundation

/// A check-in publicly shared on the Plaza — visible to all users.
struct PlazaPost: Identifiable {
    static let recordType = "PlazaPost"

    let id: CKRecord.ID
    let ownerRef: CKRecord.Reference
    let displayName: String
    let avatarEmoji: String
    let date: Date
    let emotions: [String]
    let bodyParts: [String]
    let sensations: [String]
    let intensity: Int
    let aiFeedback: String
    let privacyTier: FriendCheckIn.PrivacyTier

    init(ownerProfile: UserProfile, checkIn: CheckIn, privacyTier: FriendCheckIn.PrivacyTier, shareAIFeedback: Bool = false) {
        self.id = CKRecord.ID(recordName: "plaza_\(checkIn.id.uuidString)")
        self.ownerRef = ownerProfile.reference
        self.displayName = ownerProfile.displayName
        self.avatarEmoji = ownerProfile.avatarEmoji
        self.date = checkIn.date
        self.emotions = checkIn.emotions
        self.bodyParts = (privacyTier == .category) ? [] : checkIn.bodyParts
        self.sensations = (privacyTier == .category) ? [] : checkIn.sensations
        self.intensity = checkIn.intensity
        self.aiFeedback = (privacyTier == .full || shareAIFeedback) ? checkIn.aiFeedback : ""
        self.privacyTier = privacyTier
    }

    init?(record: CKRecord) {
        guard record.recordType == Self.recordType,
              let ownerRef = record["ownerRef"] as? CKRecord.Reference,
              let displayName = record["displayName"] as? String,
              let avatarEmoji = record["avatarEmoji"] as? String,
              let date = record["date"] as? Date,
              let emotions = record["emotions"] as? [String],
              let tierRaw = record["privacyTier"] as? String,
              let tier = FriendCheckIn.PrivacyTier(rawValue: tierRaw)
        else { return nil }
        self.id = record.recordID
        self.ownerRef = ownerRef
        self.displayName = displayName
        self.avatarEmoji = avatarEmoji
        self.date = date
        self.emotions = emotions
        self.bodyParts = record["bodyParts"] as? [String] ?? []
        self.sensations = record["sensations"] as? [String] ?? []
        self.intensity = (record["intensity"] as? Int64).map(Int.init) ?? 5
        self.aiFeedback = record["aiFeedback"] as? String ?? ""
        self.privacyTier = tier
    }

    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: Self.recordType, recordID: id)
        record["ownerRef"] = ownerRef
        record["displayName"] = displayName
        record["avatarEmoji"] = avatarEmoji
        record["date"] = date
        record["emotions"] = emotions as CKRecordValue
        record["bodyParts"] = bodyParts as CKRecordValue
        record["sensations"] = sensations as CKRecordValue
        record["intensity"] = Int64(intensity)
        record["aiFeedback"] = aiFeedback
        record["privacyTier"] = privacyTier.rawValue
        return record
    }
}
