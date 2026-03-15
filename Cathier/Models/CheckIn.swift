import Foundation
import SwiftData

@Model
final class CheckIn {
    var id: UUID
    var date: Date
    var bodyParts: [String]
    var sensations: [String]
    var intensity: Int
    var emotions: [String]
    var note: String
    var aiFeedback: String
    /// Mirrors FriendCheckIn.PrivacyTier.rawValue when shared; nil = private.
    var shareLevel: String?

    init(
        date: Date = Date(),
        bodyParts: [String] = [],
        sensations: [String] = [],
        intensity: Int = 5,
        emotions: [String] = [],
        note: String = "",
        aiFeedback: String = ""
    ) {
        self.id = UUID()
        self.date = date
        self.bodyParts = bodyParts
        self.sensations = sensations
        self.intensity = intensity
        self.emotions = emotions
        self.note = note
        self.aiFeedback = aiFeedback
    }
}
