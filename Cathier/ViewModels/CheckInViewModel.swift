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
    /// Maps each selected body part to its chosen sensations.
    var bodySensations: [String: Set<String>] = [:]
    var intensity: Double = 5
    var triggerEvent: String = ""

    /// Flat list of unique sensation names selected across all body parts.
    var allSelectedSensations: [String] {
        Array(Set(bodySensations.values.flatMap { $0 })).sorted()
    }

    /// Encodes per-body-part sensations as "bodypart:sensation" strings for storage.
    var encodedSensations: [String] {
        bodySensations.keys.sorted().flatMap { part in
            (bodySensations[part] ?? []).sorted().map { "\(part):\($0)" }
        }
    }

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
        !selectedBodyParts.isEmpty
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
                sensations: encodedSensations,
                intensity: Int(intensity),
                emotions: allEmotions,
                triggerEvent: triggerEvent,
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
            sensations: encodedSensations,
            intensity: Int(intensity),
            emotions: allEmotions,
            note: note,
            aiFeedback: aiFeedback,
            triggerEvent: triggerEvent
        )
        context.insert(checkIn)
        try? context.save()
        return checkIn
    }

    func reset() {
        currentStep = .bodyScan
        selectedBodyParts = []
        bodySensations = [:]
        intensity = 5
        triggerEvent = ""
        selectedCategory = nil
        selectedEmotions = []
        customEmotion = ""
        aiFeedback = ""
        isLoadingAI = false
        aiError = nil
        note = ""
    }
}
