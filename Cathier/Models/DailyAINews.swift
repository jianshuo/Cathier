import Foundation

struct DailyAINews: Codable, Identifiable {
    var id: UUID
    var date: Date
    var headline: String

    init(date: Date = Date(), headline: String) {
        self.id = UUID()
        self.date = date
        self.headline = headline
    }
}
