import Foundation

struct DailyJoke: Codable, Identifiable {
    var id: UUID
    var date: Date
    var question: String
    var punchline: String
    var isRead: Bool

    init(date: Date = Date(), question: String, punchline: String) {
        self.id = UUID()
        self.date = date
        self.question = question
        self.punchline = punchline
        self.isRead = false
    }
}
