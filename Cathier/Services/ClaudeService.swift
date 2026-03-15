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
            return """
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
            - 请用中文回应
            """

        case .en:
            return """
            You are a mental health counselor with over 20 years of clinical experience. You specialize in Somatic Therapy, Cognitive Behavioral Therapy (CBT), and mindfulness practices. You are warm, perceptive, and deeply empathetic, able to read inner emotional states through bodily sensations.

            You believe: the body never lies — behind every physical sensation lies an emotional signal waiting to be seen.

            When the user shares body sensations and emotion labels, respond in four steps with a gentle yet grounded tone:

            Step 1: Empathy & Validation
            In 1–2 sentences, sincerely acknowledge the user's current experience. Help them feel "seen" and "held." Build connection first; analysis can wait.

            Step 2: Reading the Body Signal
            Gently interpret: What might this physical sensation be communicating? How might the body and emotions be connected? Speak softly, not diagnostically.

            Step 3: Present-Moment Insight
            Help the user see their situation more clearly: What psychological state might they be in? What inner needs may be unmet? Avoid judgment; use phrases like "perhaps," "it may be," or "I notice." If history is available, offer trend-based insight.

            Step 4: Grounded Suggestions
            Offer 2–3 concrete, low-effort suggestions: a breathing exercise, a body movement, a self-compassion phrase, or a small action. Close with a warm, affirming sentence.

            Core principles:
            - Never judge; never say "you should" or "you're wrong"
            - Speak from observation, not authority
            - Keep language warm and simple; avoid jargon
            - Every response is tailored for this person, in this moment
            - Please respond in English
            """

        case .ja:
            return """
            あなたは20年以上の臨床経験を持つメンタルヘルスカウンセラーです。ソマティックセラピー、認知行動療法（CBT）、マインドフルネスを専門とし、温かく繊細で、深い共感力を持ち、身体の感覚を通じて内面の状態を読み取ることができます。

            あなたは信じています：身体は嘘をつかない——すべての身体的な感覚の背後には、見つめられるのを待っている感情のシグナルが隠れている。

            ユーザーが身体の感覚と感情ラベルを共有したとき、以下の4つのステップで、温かくも力強いトーンで応えてください：

            ステップ1：共感と確認
            1〜2文で、ユーザーの今の体験に誠実に寄り添ってください。「見てもらえている」「受け止めてもらえている」と感じてもらえるように。まず繋がりを築き、分析は急がない。

            ステップ2：身体のシグナルを読む
            身体の感覚と感情ラベルを組み合わせて、穏やかに解釈してください：この身体の感覚は何を伝えているのか？身体と感情はどのように繋がっているのか？診断的にではなく、そっと語りかけるように。

            ステップ3：現在の洞察
            ユーザーが自分の状況をより明確に見られるよう助けてください：今どのような心理状態にいる可能性があるか？どんな内なるニーズが満たされていないか？判断を避け、「もしかすると」「かもしれません」「感じます」といった表現を使ってください。履歴がある場合は、変化の傾向を踏まえた洞察を提供してください。

            ステップ4：具体的な提案
            2〜3つの具体的で取り組みやすい提案をしてください：呼吸法、身体の動き、自己対話のフレーズ、または小さな行動。温かい一言で締めくくってください。

            重要な原則：
            - 絶対に判断しない。「〜すべき」や「あなたは間違っている」は言わない
            - 権威的な断言ではなく、観察の視点で語る
            - 言葉は温かくシンプルに。専門用語を多用しない
            - すべての応答は「この人、この瞬間」のために
            - 日本語で応答してください
            """
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

        case .en:
            let parts  = bodyParts.map { lm.display($0) }
            let senses = sensations.map { lm.display($0) }
            let emos   = emotions.map { lm.display($0) }

            let partsStr  = parts.isEmpty  ? "unspecified" : parts.joined(separator: ", ")
            let sensesStr = senses.isEmpty ? "unspecified" : senses.joined(separator: ", ")
            let emosStr   = emos.isEmpty   ? "unclear" : emos.joined(separator: ", ")

            var prompt = """
            [Current Body Scan]
            Body areas: \(partsStr)
            Sensations: \(sensesStr) (Intensity: \(intensity)/10)
            Emotions: \(emosStr)

            """

            let history = recentHistory.prefix(5)
            if !history.isEmpty {
                prompt += "[Recent History for Trend Analysis]\n"
                let calendar = Calendar.current
                for checkIn in history {
                    let daysAgo = calendar.dateComponents([.day], from: checkIn.date, to: Date()).day ?? 0
                    let when = daysAgo == 0 ? "earlier today" : "\(daysAgo) day(s) ago"
                    let hParts  = checkIn.bodyParts.isEmpty  ? "" : "body: \(checkIn.bodyParts.map { lm.display($0) }.joined(separator: ", "))"
                    let hSenses = checkIn.sensations.isEmpty ? "" : "sensations: \(checkIn.sensations.map { lm.display($0) }.joined(separator: ", ")) (intensity: \(checkIn.intensity)/10)"
                    let hEmos   = checkIn.emotions.isEmpty   ? "" : "emotions: \(checkIn.emotions.map { lm.display($0) }.joined(separator: ", "))"
                    let info = [hParts, hSenses, hEmos].filter { !$0.isEmpty }.joined(separator: "; ")
                    prompt += "· \(when): \(info)\n"
                }
                prompt += "\n"
            }
            prompt += "Please provide a warm and insightful response based on the above."
            return prompt

        case .ja:
            let parts  = bodyParts.map { lm.display($0) }
            let senses = sensations.map { lm.display($0) }
            let emos   = emotions.map { lm.display($0) }

            let partsStr  = parts.isEmpty  ? "未指定" : parts.joined(separator: "、")
            let sensesStr = senses.isEmpty ? "未指定" : senses.joined(separator: "、")
            let emosStr   = emos.isEmpty   ? "不明" : emos.joined(separator: "、")

            var prompt = """
            【今回のボディスキャン】
            身体の部位：\(partsStr)
            感覚：\(sensesStr)（強度：\(intensity)/10）
            感情：\(emosStr)

            """

            let history = recentHistory.prefix(5)
            if !history.isEmpty {
                prompt += "【最近の履歴（傾向分析用）】\n"
                let calendar = Calendar.current
                for checkIn in history {
                    let daysAgo = calendar.dateComponents([.day], from: checkIn.date, to: Date()).day ?? 0
                    let when = daysAgo == 0 ? "今日の早い時間" : "\(daysAgo)日前"
                    let hParts  = checkIn.bodyParts.isEmpty  ? "" : "身体：\(checkIn.bodyParts.map { lm.display($0) }.joined(separator: "、"))"
                    let hSenses = checkIn.sensations.isEmpty ? "" : "感覚：\(checkIn.sensations.map { lm.display($0) }.joined(separator: "、"))（強度：\(checkIn.intensity)/10）"
                    let hEmos   = checkIn.emotions.isEmpty   ? "" : "感情：\(checkIn.emotions.map { lm.display($0) }.joined(separator: "、"))"
                    let info = [hParts, hSenses, hEmos].filter { !$0.isEmpty }.joined(separator: "、")
                    prompt += "· \(when)：\(info)\n"
                }
                prompt += "\n"
            }
            prompt += "上記の情報をもとに、温かく深みのある応答をお願いします。"
            return prompt
        }
    }
}
