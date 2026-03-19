import Foundation
import SwiftData

// MARK: - Supporting types

enum InsightFocusMode: String, CaseIterable, Codable {
    case triggers, growth, body, surprise
}

struct InsightRecord: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date
    var checkInCount: Int
    var focusMode: InsightFocusMode
    var insightText: String
}

// MARK: - ViewModel

@Observable
final class InsightsViewModel {

    // MARK: State

    enum LoadState {
        case idle
        case loading
        case loaded(String)
        case error(String)
    }

    var loadState: LoadState = .idle
    var selectedFocus: InsightFocusMode = .triggers
    var insightHistory: [InsightRecord] = []

    // MARK: Computed

    var isLoading: Bool {
        if case .loading = loadState { return true }
        return false
    }

    var isStale: Bool {
        let lastCount = UserDefaults.standard.integer(forKey: "lastInsightCheckInCount")
        let current   = UserDefaults.standard.integer(forKey: "totalCheckInCount")
        return current >= lastCount + 5
    }

    // MARK: Init

    init() {
        loadHistory()
        loadFocusPreference()
    }

    // MARK: Analysis

    func analyze(allCheckIns: [CheckIn]) async {
        guard !allCheckIns.isEmpty else { return }

        loadState = .loading

        let contextBrief = UserDefaults.standard.string(forKey: "contextBrief") ?? ""
        let language = LanguageManager.shared.currentLanguage

        do {
            let text = try await ClaudeService.generatePatternInsights(
                allCheckIns: allCheckIns,
                focus: selectedFocus,
                contextBrief: contextBrief,
                language: language
            )
            loadState = .loaded(text)

            // Persist to history
            let record = InsightRecord(
                date: Date(),
                checkInCount: allCheckIns.count,
                focusMode: selectedFocus,
                insightText: text
            )
            insightHistory.insert(record, at: 0)
            saveHistory()

            // Update staleness marker
            UserDefaults.standard.set(allCheckIns.count, forKey: "lastInsightCheckInCount")
            UserDefaults.standard.set(allCheckIns.count, forKey: "totalCheckInCount")

        } catch {
            loadState = .error(error.localizedDescription)
        }
    }

    // MARK: Focus preference

    func setFocus(_ mode: InsightFocusMode) {
        selectedFocus = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "insightFocusMode")
    }

    private func loadFocusPreference() {
        if let raw = UserDefaults.standard.string(forKey: "insightFocusMode"),
           let mode = InsightFocusMode(rawValue: raw) {
            selectedFocus = mode
        }
    }

    // MARK: History persistence

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: "insightHistory"),
              let records = try? JSONDecoder().decode([InsightRecord].self, from: data)
        else { return }
        insightHistory = records
    }

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(insightHistory) else { return }
        UserDefaults.standard.set(data, forKey: "insightHistory")
    }
}
