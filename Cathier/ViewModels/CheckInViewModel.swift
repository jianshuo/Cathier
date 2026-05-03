import Foundation
import SwiftData
import Observation

struct BrainTrainerMessage: Identifiable {
    let id = UUID()
    let role: String              // "user" or "assistant"
    let displayContent: String    // shown in chat bubbles
    let apiContent: String        // sent to the API (may include hidden step annotation)
    let isInitialContext: Bool

    init(role: String, content: String, isInitialContext: Bool, stepAnnotation: Int? = nil) {
        self.role = role
        self.displayContent = content
        self.isInitialContext = isInitialContext
        if let step = stepAnnotation {
            self.apiContent = "（第 \(step) 步回答）\(content)"
        } else {
            self.apiContent = content
        }
    }
}

enum CheckInStep: CaseIterable {
    case bodyScan
    case emotionLabel
    case aiFeedback
}

@MainActor
@Observable
final class CheckInViewModel {
    // MARK: - Navigation
    var currentStep: CheckInStep = .bodyScan

    // MARK: - Step 1: Body Scan
    var selectedBodyParts: Set<String> = []
    var bodySensations: [String: Set<String>] = [:]
    var intensity: Double = 5
    var triggerEvent: String = ""

    var allSelectedSensations: [String] {
        Array(Set(bodySensations.values.flatMap { $0 })).sorted()
    }

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
    var brainTrainerComplete = false
    var brainTrainerSummary = ""
    var isGeneratingSummary = false
    private var brainTrainerTask: Task<Void, Never>?

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

    func startBrainTrainerSession() {
        guard brainTrainerMessages.isEmpty else { return }
        brainTrainerTask?.cancel()
        brainTrainerTask = Task {
            let ctx = BrainTrainerMessage(role: "user", content: buildBrainTrainerContext(), isInitialContext: true)
            brainTrainerMessages.append(ctx)
            isBrainTrainerLoading = true
            brainTrainerError = nil
            do {
                let apiMsgs = brainTrainerMessages.map { (role: $0.role, content: $0.apiContent) }
                let reply = try await ClaudeService.callBrainTrainer(messages: apiMsgs)
                guard !Task.isCancelled else { return }
                brainTrainerMessages.append(BrainTrainerMessage(role: "assistant", content: reply, isInitialContext: false))
            } catch {
                guard !Task.isCancelled else { return }
                brainTrainerError = error.localizedDescription
            }
            isBrainTrainerLoading = false
        }
    }

    func sendBrainTrainerMessage(_ text: String) {
        brainTrainerTask?.cancel()
        brainTrainerTask = Task {
            let step = brainTrainerMessages.filter { $0.role == "user" && !$0.isInitialContext }.count + 1
            let userMsg = BrainTrainerMessage(role: "user", content: text, isInitialContext: false, stepAnnotation: step)
            brainTrainerMessages.append(userMsg)
            isBrainTrainerLoading = true
            brainTrainerError = nil
            do {
                let apiMsgs = brainTrainerMessages.map { (role: $0.role, content: $0.apiContent) }
                let reply = try await ClaudeService.callBrainTrainer(messages: apiMsgs)
                guard !Task.isCancelled else { return }
                brainTrainerMessages.append(BrainTrainerMessage(role: "assistant", content: reply, isInitialContext: false))
                if reply.contains("<complete/>") {
                    brainTrainerComplete = true
                }
            } catch {
                guard !Task.isCancelled else { return }
                brainTrainerError = error.localizedDescription
                if !brainTrainerMessages.isEmpty {
                    brainTrainerMessages.removeLast()
                }
            }
            isBrainTrainerLoading = false
        }
    }

    func generateBrainTrainerSummary() async {
        isGeneratingSummary = true
        brainTrainerError = nil
        do {
            let apiMsgs = brainTrainerMessages.map { (role: $0.role, content: $0.apiContent) }
            brainTrainerSummary = try await ClaudeService.generateBrainTrainerSummary(messages: apiMsgs)
        } catch {
            brainTrainerError = error.localizedDescription
        }
        isGeneratingSummary = false
    }

    var brainTrainerTranscript: String {
        brainTrainerSummary.isEmpty
            ? brainTrainerMessages
                .filter { !$0.isInitialContext }
                .map { $0.role == "assistant" ? "AI：\($0.displayContent)" : "我：\($0.displayContent)" }
                .joined(separator: "\n\n")
            : brainTrainerSummary
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

        let key = "totalCheckInCount"
        let newTotal = UserDefaults.standard.integer(forKey: key) + 1
        UserDefaults.standard.set(newTotal, forKey: key)

        return checkIn
    }

    func reset() {
        brainTrainerTask?.cancel()
        brainTrainerTask = nil
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
        brainTrainerComplete = false
        brainTrainerSummary = ""
        isGeneratingSummary = false
    }
}
