import Foundation
import Observation

@Observable
final class JokeService {
    static let shared = JokeService()

    private(set) var todayJoke: DailyJoke? = nil
    private(set) var jokeHistory: [DailyJoke] = []
    var isGenerating = false
    var generateError: String? = nil

    private let historyKey = "jokeHistory_v1"

    private init() {
        loadHistory()
        todayJoke = jokeHistory.first { Calendar.current.isDateInToday($0.date) }
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let jokes = try? JSONDecoder().decode([DailyJoke].self, from: data)
        else { return }
        jokeHistory = jokes
    }

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(jokeHistory) else { return }
        UserDefaults.standard.set(data, forKey: historyKey)
    }

    func generateTodayJokeIfNeeded() async {
        if let existing = jokeHistory.first(where: { Calendar.current.isDateInToday($0.date) }) {
            todayJoke = existing
            return
        }
        await generateNewJoke()
    }

    func regenerate() async {
        jokeHistory.removeAll { Calendar.current.isDateInToday($0.date) }
        todayJoke = nil
        saveHistory()
        await generateNewJoke()
    }

    private func generateNewJoke() async {
        guard !isGenerating else { return }
        isGenerating = true
        generateError = nil

        do {
            let (question, punchline) = try await ClaudeService.generateDailyJoke(
                language: LanguageManager.shared.currentLanguage
            )
            let entry = DailyJoke(date: Date(), question: question, punchline: punchline)
            jokeHistory.insert(entry, at: 0)
            todayJoke = entry
            saveHistory()
        } catch {
            generateError = error.localizedDescription
        }

        isGenerating = false
    }

    func markRead(id: UUID) {
        guard let idx = jokeHistory.firstIndex(where: { $0.id == id }) else { return }
        jokeHistory[idx].isRead = true
        if jokeHistory[idx].id == todayJoke?.id {
            todayJoke = jokeHistory[idx]
        }
        saveHistory()
    }
}
