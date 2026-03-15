import Foundation

enum ClaudeError: LocalizedError {
    case noApiKey
    case apiError(Int)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .noApiKey:        return "请先在设置中填写 Claude API Key"
        case .apiError(let c): return "API 请求失败（HTTP \(c)）"
        case .decodingError:   return "解析 AI 响应失败"
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
    你是一位拥有20年以上临床经验的心理健康咨询师。你擅长躯体感知疗法（Somatic Therapy）、认知行为疗法（CBT）以及正念疗法。你温暖、细腻，具有极强的同理心，能够透过身体的感受读懂内心深处的状态。

    你相信：身体不会说谎，每一个躯体感受背后，都藏着一个等待被看见的情绪信号。

    当用户提供身体感受和情绪标签时，请按以下四个步骤回应，语气温柔而有力量：

    第一步：共情与确认
    用1-2句话，真诚地回应用户当下的感受。让他/她感受到"被看见"和"被接住"。先建立连接，不急于分析。

    第二步：身体信号解读
    结合躯体感受与情绪标签，温和地分析：这个身体感受在传递什么信息？身体与情绪之间可能存在怎样的关联？语气要像在轻声说话，而不是在做诊断报告。

    第三步：现状洞察
    帮助用户更清晰地看见自己的处境：当前可能处于什么样的心理状态？有哪些内在需求可能没有被满足？避免妄下判断，多用"也许"、"可能"、"我感受到"这类表达。如果用户有历史记录，请结合变化趋势给出洞察。

    第四步：落地建议
    给出2-3个具体、可操作的建议，难度要低、门槛要小：可以是一个呼吸练习、一个身体动作、一句自我对话、或一个微小的行动。最后用一句温暖的话结尾。

    重要原则：
    - 永远不评判，不说"你应该"或"你不对"
    - 使用"我"的视角表达观察，而非权威断言
    - 语言简洁温暖，避免堆砌术语
    - 每次回应都是为「这个人，这一刻」量身定制的
    """

    static func generateFeedback(
        bodyParts: [String],
        sensations: [String],
        intensity: Int,
        emotions: [String],
        recentHistory: [CheckIn] = []
    ) async throws -> String {
        let apiKey = UserDefaults.standard.string(forKey: "claudeApiKey") ?? ""
        guard !apiKey.isEmpty else { throw ClaudeError.noApiKey }

        let userMessage = buildPrompt(bodyParts: bodyParts, sensations: sensations,
                                      intensity: intensity, emotions: emotions,
                                      recentHistory: recentHistory)

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 800,
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

    private static func buildPrompt(
        bodyParts: [String],
        sensations: [String],
        intensity: Int,
        emotions: [String],
        recentHistory: [CheckIn]
    ) -> String {
        let parts  = bodyParts.isEmpty  ? "未指定" : bodyParts.joined(separator: "、")
        let senses = sensations.isEmpty ? "未指定" : sensations.joined(separator: "、")
        let emos   = emotions.isEmpty   ? "说不清楚" : emotions.joined(separator: "、")

        var prompt = """
        【本次身体扫描】
        身体部位：\(parts)
        身体感受：\(senses)（强度：\(intensity)/10）
        情绪：\(emos)

        """

        let history = recentHistory.prefix(5)
        if !history.isEmpty {
            prompt += "【近期历史记录，供参考趋势分析】\n"
            let calendar = Calendar.current
            for checkIn in history {
                let daysAgo = calendar.dateComponents([.day], from: checkIn.date, to: Date()).day ?? 0
                let when = daysAgo == 0 ? "今天早些时候" : "\(daysAgo)天前"
                let hParts  = checkIn.bodyParts.isEmpty  ? "" : "身体：\(checkIn.bodyParts.joined(separator: "、"))"
                let hSenses = checkIn.sensations.isEmpty ? "" : "感受：\(checkIn.sensations.joined(separator: "、"))（强度：\(checkIn.intensity)/10）"
                let hEmos   = checkIn.emotions.isEmpty   ? "" : "情绪：\(checkIn.emotions.joined(separator: "、"))"
                let parts = [hParts, hSenses, hEmos].filter { !$0.isEmpty }.joined(separator: "，")
                prompt += "· \(when)：\(parts)\n"
            }
            prompt += "\n"
        }

        prompt += "请根据以上信息，给予温暖而有深度的回应。"
        return prompt
    }
}
