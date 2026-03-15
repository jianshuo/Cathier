import Foundation
import SwiftData

@Model
final class CheckIn {
    var id: UUID = UUID()
    var date: Date = Date()
    var bodyParts: [String] = [String]()
    var sensations: [String] = [String]()
    var intensity: Int = 5
    var emotions: [String] = [String]()
    var note: String = ""
    var aiFeedback: String = ""
    /// Mirrors FriendCheckIn.PrivacyTier.rawValue when shared; nil = private.
    var shareLevel: String? = nil

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
