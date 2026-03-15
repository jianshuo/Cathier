import Foundation

enum ClaudeError: LocalizedError {
    case noApiKey
    case apiError(Int)
    case decodingError

    var errorDescription: String? {
        let lm = LanguageManager.shared
        switch self {
        case .noApiKey:        return lm.claudeNoApiKey
        case .apiError(let c): return lm.claudeApiError(c)
        case .decodingError:   return lm.claudeDecodeError
        }
    }
}

private struct ClaudeResponse: Decodable {
    let content: [ContentBlock]
    struct ContentBlock: Decodable {
        let type: String
        let text: String
    }
}

enum ClaudeService {

    private static func systemPrompt(for language: AppLanguage) -> String {
        switch language {
        case .zh:
            return "你是一位温暖、善解人意的情绪陪伴助手。当用户分享他们的情绪时，给予简短、真诚的反馈，让他们感到被理解。语言简洁温暖，不超过3句话。请用中文回应。"
        case .en:
            return "You are a warm, empathetic emotional companion. When a user shares their emotions, provide brief and sincere feedback that helps them feel understood. Keep your response concise and warm — no more than 3 sentences. Please respond in English."
        case .ja:
            return "あなたは温かく共感的な感情サポートアシスタントです。ユーザーが感情を共有したとき、短く誠実なフィードバックを返し、理解されていると感じてもらえるようにしてください。3文以内で簡潔に温かく応答してください。日本語で応答してください。"
        }
    }

    static func generateFeedback(
        bodyParts: [String],
        sensations: [String],
        intensity: Int,
        emotions: [String],
        recentHistory: [CheckIn] = [],
        language: AppLanguage = LanguageManager.shared.currentLanguage
    ) async throws -> String {
        let apiKey = UserDefaults.standard.string(forKey: "claudeApiKey") ?? ""
        guard !apiKey.isEmpty else { throw ClaudeError.noApiKey }

        let userMessage = buildPrompt(bodyParts: bodyParts, sensations: sensations,
                                      intensity: intensity, emotions: emotions,
                                      recentHistory: recentHistory,
                                      language: language)

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 800,
            "system": systemPrompt(for: language),
            "messages": [["role": "user", "content": userMessage]],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            if let body = String(data: data, encoding: .utf8) {
                print("[ClaudeService] HTTP \(statusCode): \(body)")
            }
            throw ClaudeError.apiError(statusCode)
        }

        let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        return decoded.content.first(where: { $0.type == "text" })?.text ?? ""
    }

    private static func buildPrompt(
        bodyParts: [String],
        sensations: [String],
        intensity: Int,
        emotions: [String],
        recentHistory: [CheckIn],
        language: AppLanguage
    ) -> String {
        let lm = LanguageManager.shared

        switch language {
        case .zh:
            let emos = emotions.isEmpty ? "说不清楚" : emotions.joined(separator: "、")
            return "我现在的情绪是：\(emos)。"

        case .en:
            let emos = emotions.map { lm.display($0) }
            let emosStr = emos.isEmpty ? "unclear" : emos.joined(separator: ", ")
            return "My current emotions are: \(emosStr)."

        case .ja:
            let emos = emotions.map { lm.display($0) }
            let emosStr = emos.isEmpty ? "不明" : emos.joined(separator: "、")
            return "今の私の感情は：\(emosStr)。"
        }
    }
}
