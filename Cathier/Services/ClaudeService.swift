import Foundation

enum ClaudeError: LocalizedError {
    case noApiKey
    case apiError(Int)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .noApiKey:       return "请先在设置中填写 Claude API Key"
        case .apiError(let c): return "API 请求失败（HTTP \(c)）"
        case .decodingError:  return "解析 AI 响应失败"
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
    private static let systemPrompt = """
    你是一个温和、好奇、非评判的情绪陪伴者。用户刚完成一次身体扫描和情绪识别练习。
    请给出简短（2-3句话，不超过80字）、温暖的回应，帮助用户更好地理解自己的情绪体验。
    原则：先共情，再（可选地）提供认知视角；不做诊断；不给清单式建议；语气温和。
    若情绪强度≥7分，优先共情，可以提供一个简单的落地练习（如：深呼吸三次）。
    """

    static func generateFeedback(
        bodyParts: [String],
        sensations: [String],
        intensity: Int,
        emotions: [String]
    ) async throws -> String {
        let apiKey = UserDefaults.standard.string(forKey: "claudeApiKey") ?? ""
        guard !apiKey.isEmpty else { throw ClaudeError.noApiKey }

        let userMessage = buildPrompt(bodyParts: bodyParts, sensations: sensations,
                                      intensity: intensity, emotions: emotions)

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 300,
            "system": systemPrompt,
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

    private static func buildPrompt(bodyParts: [String], sensations: [String],
                                     intensity: Int, emotions: [String]) -> String {
        let parts = bodyParts.isEmpty ? "未指定" : bodyParts.joined(separator: "、")
        let senses = sensations.isEmpty ? "未指定" : sensations.joined(separator: "、")
        let emos = emotions.isEmpty ? "说不清楚" : emotions.joined(separator: "、")
        return """
        用户完成了一次身体扫描：
        - 身体部位：\(parts)
        - 感受描述：\(senses)（强度：\(intensity)/10）
        - 情绪：\(emos)
        请给予简短温暖的回应。
        """
    }
}
