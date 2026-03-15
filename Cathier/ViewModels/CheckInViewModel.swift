import Foundation
import SwiftData
import Observation

enum CheckInStep: CaseIterable {
    case bodyScan
    case emotionLabel
    case aiFeedback
}

@Observable
final class CheckInViewModel {
    // MARK: - Navigation
    var currentStep: CheckInStep = .bodyScan

    // MARK: - Step 1: Body Scan
    var selectedBodyParts: Set<String> = []
    var selectedSensations: Set<String> = []
    var intensity: Double = 5

    // MARK: - Step 2: Emotion Label
    var selectedCategory: String? = nil
    var selectedEmotions: Set<String> = []
    var customEmotion: String = ""

    // MARK: - Step 3: AI Feedback
    var aiFeedback: String = ""
    var isLoadingAI = false
    var aiError: String? = nil
    var note: String = ""

    // MARK: - Computed
    var allEmotions: [String] {
        var list = Array(selectedEmotions)
        let trimmed = customEmotion.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { list.append(trimmed) }
        return list
    }

    var canProceedFromBodyScan: Bool {
        !selectedBodyParts.isEmpty || !selectedSensations.isEmpty
    }

    var canProceedFromEmotionLabel: Bool {
        !selectedEmotions.isEmpty || !customEmotion.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Actions
    func fetchAIFeedback(recentHistory: [CheckIn] = []) async {
        isLoadingAI = true
        aiError = nil
        do {
            aiFeedback = try await ClaudeService.generateFeedback(
                bodyParts: Array(selectedBodyParts),
                sensations: Array(selectedSensations),
                intensity: Int(intensity),
                emotions: allEmotions,
                recentHistory: recentHistory,
                language: LanguageManager.shared.currentLanguage
            )
        } catch {
            aiError = error.localizedDescription
        }
        isLoadingAI = false
    }

    @discardableResult
    func save(context: ModelContext) -> CheckIn {
        let checkIn = CheckIn(
            date: Date(),
            bodyParts: Array(selectedBodyParts),
            sensations: Array(selectedSensations),
            intensity: Int(intensity),
            emotions: allEmotions,
            note: note,
            aiFeedback: aiFeedback
        )
        context.insert(checkIn)
        try? context.save()
        return checkIn
    }

    func reset() {
        currentStep = .bodyScan
        selectedBodyParts = []
        selectedSensations = []
        intensity = 5
        selectedCategory = nil
        selectedEmotions = []
        customEmotion = ""
        aiFeedback = ""
        isLoadingAI = false
        aiError = nil
        note = ""
    }
}
