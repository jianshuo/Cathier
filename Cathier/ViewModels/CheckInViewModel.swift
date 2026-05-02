import Foundation
import SwiftData
import Observation

struct BrainTrainerMessage: Identifiable {
    let id = UUID()
    let role: String       // "user" or "assistant"
    let content: String
    let isInitialContext: Bool
}

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

    // MARK: - BrainTrainer Chat
    var brainTrainerMessages: [BrainTrainerMessage] = []
    var isBrainTrainerLoading = false
    var brainTrainerError: String? = nil

    // MARK: - AI Companion Persona
    var persona: AICompanionPersona {
        get {
            AICompanionPersona(rawValue: UserDefaults.standard.string(forKey: "aiCompanionPersona") ?? "") ?? .psychologist
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "aiCompanionPersona")
        }
    }

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
    func fetchAIFeedback(recentHistory: [CheckIn] = [], emotionFrequency: [(String, Int)] = []) async {
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
                emotionFrequency: emotionFrequency,
                language: LanguageManager.shared.currentLanguage,
                persona: persona
            )
        } catch {
            aiError = error.localizedDescription
        }
        isLoadingAI = false
    }

    func startBrainTrainerSession() async {
        guard brainTrainerMessages.isEmpty else { return }
        let ctx = BrainTrainerMessage(role: "user", content: buildBrainTrainerContext(), isInitialContext: true)
        brainTrainerMessages.append(ctx)
        isBrainTrainerLoading = true
        brainTrainerError = nil
        do {
            let apiMsgs = brainTrainerMessages.map { (role: $0.role, content: $0.content) }
            let reply = try await ClaudeService.callBrainTrainer(messages: apiMsgs)
            brainTrainerMessages.append(BrainTrainerMessage(role: "assistant", content: reply, isInitialContext: false))
        } catch {
            brainTrainerError = error.localizedDescription
        }
        isBrainTrainerLoading = false
    }

    func sendBrainTrainerMessage(_ text: String) async {
        let userMsg = BrainTrainerMessage(role: "user", content: text, isInitialContext: false)
        brainTrainerMessages.append(userMsg)
        isBrainTrainerLoading = true
        brainTrainerError = nil
        do {
            let apiMsgs = brainTrainerMessages.map { (role: $0.role, content: $0.content) }
            let reply = try await ClaudeService.callBrainTrainer(messages: apiMsgs)
            brainTrainerMessages.append(BrainTrainerMessage(role: "assistant", content: reply, isInitialContext: false))
        } catch {
            brainTrainerError = error.localizedDescription
            brainTrainerMessages.removeLast()
        }
        isBrainTrainerLoading = false
    }

    var brainTrainerTranscript: String {
        brainTrainerMessages
            .filter { !$0.isInitialContext }
            .map { $0.role == "assistant" ? "AI：\($0.content)" : "我：\($0.content)" }
            .joined(separator: "\n\n")
    }

    private func buildBrainTrainerContext() -> String {
        var parts: [String] = []
        let event = triggerEvent.trimmingCharacters(in: .whitespaces)
        if !event.isEmpty { parts.append("触发事件：\(event)") }
        if !allEmotions.isEmpty { parts.append("情绪：\(allEmotions.joined(separator: "、"))") }
        if !selectedBodyParts.isEmpty { parts.append("身体部位：\(Array(selectedBodyParts).joined(separator: "、"))") }
        parts.append("强度：\(Int(intensity))/10")
        return parts.joined(separator: "\n")
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

        // Update running count for insights staleness and milestone nudge
        let key = "totalCheckInCount"
        let newTotal = UserDefaults.standard.integer(forKey: key) + 1
        UserDefaults.standard.set(newTotal, forKey: key)

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
        brainTrainerMessages = []
        isBrainTrainerLoading = false
        brainTrainerError = nil
    }
}
