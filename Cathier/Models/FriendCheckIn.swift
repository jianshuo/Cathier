import CloudKit
import Foundation

/// A check-in shared by a friend, fetched from CloudKit Public DB (read-only).
struct FriendCheckIn: Identifiable {
    static let recordType = "SharedCheckIn"

    let id: CKRecord.ID
    let ownerRef: CKRecord.Reference
    let localID: String
    let date: Date
    let emotions: [String]
    let bodyParts: [String]
    let sensations: [String]
    let intensity: Int
    let note: String
    let aiFeedback: String
    let privacyTier: PrivacyTier

    enum PrivacyTier: String, CaseIterable, Identifiable {
        case category = "category"
        case emotions = "emotions"
        case full = "full"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .category: return "只分享情绪大类"
            case .emotions: return "分享情绪词"
            case .full: return "完整分享"
            }
        }

        var description: String {
            switch self {
            case .category: return "好友只看到情绪大类和强度"
            case .emotions: return "好友看到具体情绪词"
            case .full: return "好友看到全部内容含笔记"
            }
        }
    }

    /// Build from a local CheckIn before uploading.
    init(ownerRef: CKRecord.Reference, checkIn: CheckIn, privacyTier: PrivacyTier, shareAIFeedback: Bool = false) {
        self.id = CKRecord.ID(recordName: checkIn.id.uuidString)
        self.ownerRef = ownerRef
        self.localID = checkIn.id.uuidString
        self.date = checkIn.date
        self.emotions = checkIn.emotions
        self.bodyParts = checkIn.bodyParts
        self.sensations = checkIn.sensations
        self.intensity = checkIn.intensity
        self.note = privacyTier == .full ? checkIn.note : ""
        self.aiFeedback = (privacyTier == .full || shareAIFeedback) ? checkIn.aiFeedback : ""
        self.privacyTier = privacyTier
    }

    init?(record: CKRecord) {
        guard record.recordType == Self.recordType,
              let ownerRef = record["ownerRef"] as? CKRecord.Reference,
              let localID = record["localID"] as? String,
              let date = record["date"] as? Date,
              let emotions = record["emotions"] as? [String],
              let tierRaw = record["privacyTier"] as? String,
              let tier = PrivacyTier(rawValue: tierRaw)
        else { return nil }
        self.id = record.recordID
        self.ownerRef = ownerRef
        self.localID = localID
        self.date = date
        self.emotions = emotions
        self.bodyParts = record["bodyParts"] as? [String] ?? []
        self.sensations = record["sensations"] as? [String] ?? []
        self.intensity = (record["intensity"] as? Int64).map(Int.init) ?? 5
        self.note = record["note"] as? String ?? ""
        self.aiFeedback = record["aiFeedback"] as? String ?? ""
        self.privacyTier = tier
    }

    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: Self.recordType, recordID: id)
        record["ownerRef"] = ownerRef
        record["localID"] = localID
        record["date"] = date
        record["emotions"] = emotions as CKRecordValue
        record["bodyParts"] = bodyParts as CKRecordValue
        record["sensations"] = sensations as CKRecordValue
        record["intensity"] = Int64(intensity)
        record["note"] = note
        record["aiFeedback"] = aiFeedback
        record["privacyTier"] = privacyTier.rawValue
        return record
    }
}
