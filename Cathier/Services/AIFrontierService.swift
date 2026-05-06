import Foundation
import Observation

@Observable
final class AIFrontierService {
    static let shared = AIFrontierService()

    private(set) var todayNews: DailyAINews? = nil
    var isGenerating = false
    var generateError: String? = nil

    private let storageKey = "aiFrontierNews_v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let news = try? JSONDecoder().decode(DailyAINews.self, from: data),
           Calendar.current.isDateInToday(news.date) {
            todayNews = news
        }
    }

    func generateTodayNewsIfNeeded() async {
        if let existing = todayNews, Calendar.current.isDateInToday(existing.date) { return }
        await generateNews()
    }

    func regenerate() async {
        todayNews = nil
        UserDefaults.standard.removeObject(forKey: storageKey)
        await generateNews()
    }

    private func generateNews() async {
        guard !isGenerating else { return }
        isGenerating = true
        generateError = nil

        do {
            let headline = try await ClaudeService.generateDailyAINews(
                language: LanguageManager.shared.currentLanguage
            )
            let entry = DailyAINews(date: Date(), headline: headline)
            todayNews = entry
            if let data = try? JSONEncoder().encode(entry) {
                UserDefaults.standard.set(data, forKey: storageKey)
            }
        } catch {
            generateError = error.localizedDescription
        }

        isGenerating = false
    }
}
