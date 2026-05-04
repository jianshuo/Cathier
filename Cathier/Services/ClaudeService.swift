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

// Structured AI feedback — stored as JSON in CheckIn.aiFeedback for new check-ins.
// Legacy plain-text entries are handled via StructuredFeedback.parse returning nil.
struct StructuredFeedback: Codable {
    var summary: String
    var insight: String
    var connection: String
    var suggestion: String

    /// Preview text shown in card previews (first meaningful field).
    var previewText: String { summary }

    static func parse(_ text: String) -> StructuredFeedback? {
        var jsonText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip markdown code fences if the model wrapped the JSON
        if jsonText.hasPrefix("```") {
            let lines = jsonText.components(separatedBy: "\n")
            let inner = lines.dropFirst().prefix(while: { !$0.hasPrefix("```") })
            jsonText = inner.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let data = jsonText.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(StructuredFeedback.self, from: data)
        else { return nil }
        return decoded
    }
}

// Anthropic wire format
private struct ClaudeResponse: Decodable {
    let content: [ContentBlock]
    struct ContentBlock: Decodable {
        let type: String
        let text: String
    }
}

// OpenAI-compatible wire format
private struct OpenAIResponse: Decodable {
    let choices: [Choice]
    struct Choice: Decodable {
        let message: Message
        struct Message: Decodable {
            // Reasoning models can return `content: null` when the entire token
            // budget is consumed by internal reasoning — keep this optional.
            let content: String?
        }
    }
}

enum ClaudeService {

    // MARK: - Managed service configuration
    // Production: injected at build time from GitHub secrets → Info.plist.
    // Local dev: set AZURE_OPENAI_API_KEY in Xcode scheme → Run → Environment Variables.
    private static var managedApiKey: String {
        let plistKey = Bundle.main.infoDictionary?["AzureOpenAIApiKey"] as? String ?? ""
        if !plistKey.isEmpty { return plistKey }
        return ProcessInfo.processInfo.environment["AZURE_OPENAI_API_KEY"] ?? ""
    }

    // MARK: - Provider helpers

    // Default to managed Qwen — developer's key, free for all users.
    private static var activeProvider: AIProvider { .managed }

    private static var feedbackModel: String  { activeProvider.feedbackModel }
    private static var insightsModel: String  { activeProvider.insightsModel }

    // MARK: - Shared network helper

    private static func call(model: String, system: String, user: String, maxTokens: Int) async throws -> String {
        let provider = activeProvider

        // Use the developer's Qwen key injected at build time.
        let apiKey = managedApiKey
        guard !apiKey.isEmpty else { throw ClaudeError.noApiKey }

        var request = URLRequest(url: provider.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any]

        if provider.isAnthropicFormat {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            body = [
                "model": model,
                "max_tokens": maxTokens,
                "system": system,
                "messages": [["role": "user", "content": user]],
            ]
        } else {
            if provider.usesAzureAuth {
                request.setValue(apiKey, forHTTPHeaderField: "api-key")
            } else {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "authorization")
            }
            let tokenField = provider.usesMaxCompletionTokens ? "max_completion_tokens" : "max_tokens"
            body = [
                "model": model,
                tokenField: maxTokens,
                "messages": [
                    ["role": "system", "content": system],
                    ["role": "user", "content": user],
                ],
            ]
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Debug: print the full LLM request
        print("╔══════════════════════════════════════")
        print("║ [AIService] LLM Call Debug")
        print("╠══════════════════════════════════════")
        print("║ Provider: \(provider.displayName)")
        print("║ Model: \(model)")
        print("║ Max Tokens: \(maxTokens)")
        print("║ Endpoint: \(provider.endpoint)")
        print("╠── System Prompt ─────────────────────")
        print(system)
        print("╠── User Message ──────────────────────")
        print(user)
        print("╚══════════════════════════════════════")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            if let responseBody = String(data: data, encoding: .utf8) {
                print("[AIService] HTTP \(statusCode): \(responseBody)")
            }
            throw ClaudeError.apiError(statusCode)
        }

        if provider.isAnthropicFormat {
            let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)
            return decoded.content.first(where: { $0.type == "text" })?.text ?? ""
        } else {
            let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            return decoded.choices.first?.message.content ?? ""
        }
    }

    // MARK: - Multi-turn (BrainTrainer)

    static func callBrainTrainer(
        messages: [(role: String, content: String)],
        language: AppLanguage = LanguageManager.shared.currentLanguage
    ) async throws -> String {
        let system = AICompanionPersona.brainTrainer.systemPrompt(for: language)
        return try await callMultiTurn(system: system, messages: messages, maxTokens: 4000)
    }

    static func generateBrainTrainerSummary(
        messages: [(role: String, content: String)],
        language: AppLanguage = LanguageManager.shared.currentLanguage
    ) async throws -> String {
        let isZh = language == .zh
        let system = isZh ? """
            你是复盘总结专家。用户刚完成了「吃一堑长一智」五步复盘对话。
            根据对话内容，生成一张简洁的训练卡片，格式如下（用 Markdown 加粗标签）：

            **这次"堑"：** 一句话描述事件
            **自动输出：** 当时的第一反应
            **旧权重：** 背后的底层模式
            **新参数：** 想要训练的新模式
            **替代动作：** 下次的具体执行动作

            语气简洁，像在记录一张训练卡片。不加鼓励语，不加废话，直接给内容。
            """ : """
            You are a reflection summary expert. Summarize the completed 5-step brain training session into a concise training card:

            **The lesson:** One sentence describing what happened
            **Auto-response:** The immediate reaction
            **Old weight:** The underlying pattern
            **New parameter:** The new pattern to train
            **Next action:** The specific replacement behavior

            Be concise. No encouragement, no filler — just the content.
            """
        var msgs = messages.map { (role: $0.role, content: $0.content.replacingOccurrences(of: "<complete/>", with: "")) }
        msgs.append((role: "user", content: isZh ? "请生成五步复盘总结卡片。" : "Please generate the 5-step summary card."))
        return try await callMultiTurn(system: system, messages: msgs, maxTokens: 4000)
    }

    private static func callMultiTurn(
        system: String,
        messages: [(role: String, content: String)],
        maxTokens: Int
    ) async throws -> String {
        let provider = activeProvider
        let apiKey = managedApiKey
        guard !apiKey.isEmpty else { throw ClaudeError.noApiKey }

        var request = URLRequest(url: provider.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let msgArray = messages.map { ["role": $0.role, "content": $0.content] }
        let body: [String: Any]

        if provider.isAnthropicFormat {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            body = ["model": feedbackModel, "max_tokens": maxTokens, "system": system, "messages": msgArray]
        } else {
            if provider.usesAzureAuth {
                request.setValue(apiKey, forHTTPHeaderField: "api-key")
            } else {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "authorization")
            }
            let tokenField = provider.usesMaxCompletionTokens ? "max_completion_tokens" : "max_tokens"
            var all: [[String: String]] = [["role": "system", "content": system]]
            all.append(contentsOf: msgArray)
            body = ["model": feedbackModel, tokenField: maxTokens, "messages": all]
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            if let body = String(data: data, encoding: .utf8) { print("[AIService] HTTP \(statusCode): \(body)") }
            throw ClaudeError.apiError(statusCode)
        }

        if provider.isAnthropicFormat {
            let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)
            return decoded.content.first(where: { $0.type == "text" })?.text ?? ""
        } else {
            let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            return decoded.choices.first?.message.content ?? ""
        }
    }

    // MARK: - Pattern Insights

    /// Returns a deduplicated sample of check-ins for pattern analysis.
    /// Priority: (1) entries with trigger events, (2) most recent 10, (3) evenly spaced from remainder.
    static func sampleCheckIns(_ checkIns: [CheckIn], limit: Int = 30) -> [CheckIn] {
        guard checkIns.count > limit else { return checkIns }

        let sorted = checkIns.sorted { $0.date > $1.date }
        var selected: [UUID: CheckIn] = [:]

        // Priority 1: entries with trigger events (up to limit/3)
        let triggerLimit = limit / 3
        for c in sorted where !c.triggerEvent.trimmingCharacters(in: .whitespaces).isEmpty {
            if selected.count >= triggerLimit { break }
            selected[c.id] = c
        }

        // Priority 2: most recent 10
        for c in sorted.prefix(10) { selected[c.id] = c }

        // Priority 3: evenly spaced from remainder
        let remaining = sorted.filter { selected[$0.id] == nil }
        let needed = limit - selected.count
        let step = Swift.max(1, remaining.count / Swift.max(1, needed))
        for (i, c) in remaining.enumerated() {
            if selected.count >= limit { break }
            if i % step == 0 { selected[c.id] = c }
        }

        return selected.values.sorted { $0.date < $1.date }
    }

    static func generatePatternInsights(
        allCheckIns: [CheckIn],
        focus: InsightFocusMode,
        contextBrief: String = "",
        language: AppLanguage = LanguageManager.shared.currentLanguage
    ) async throws -> String {
        let sample = sampleCheckIns(allCheckIns, limit: 30)
        let prompt = buildPatternPrompt(checkIns: sample, focus: focus,
                                       contextBrief: contextBrief, language: language)
        let system = patternSystemPrompt(focus: focus, language: language)
        return try await call(model: insightsModel, system: system, user: prompt, maxTokens: 1200)
    }

    private static func patternSystemPrompt(focus: InsightFocusMode, language: AppLanguage) -> String {
        let focusInstruction: String
        switch focus {
        case .triggers:
            focusInstruction = language == .zh
                ? "重点分析：情绪与触发事件之间的关联。"
                : language == .en ? "Focus on: correlations between emotions and trigger events."
                : "重点：感情とトリガーイベントの関連性。"
        case .growth:
            focusInstruction = language == .zh
                ? "重点分析：情绪强度和情绪类型随时间的变化趋势，是否有向好的方向发展？"
                : language == .en ? "Focus on: trends over time — is the emotional trajectory improving?"
                : "重点：時間とともに感情の軌跡が改善されているか。"
        case .body:
            focusInstruction = language == .zh
                ? "重点分析：身体部位与情绪之间的关联，身体信号有什么规律？"
                : language == .en ? "Focus on: patterns between body areas and emotional states."
                : "重点：身体の部位と感情状態のパターン。"
        case .surprise:
            focusInstruction = language == .zh
                ? "找出最意想不到、最有洞察力的模式——让用户感到「没想到自己是这样的人」。"
                : language == .en ? "Find the most surprising, insight-revealing patterns — the ones that make the user think 'I didn't know that about myself.'"
                : "最も驚くべき洞察に満ちたパターンを見つけてください。"
        }

        switch language {
        case .zh:
            return """
            你是「觉察」（Cathier）App 的情绪模式分析师——擅长从身体-情绪数据中发现用户自己看不到的规律。

            ## 背景

            用户通过 Cathier 进行日常情绪觉察训练：每次签到记录身体部位、躯体感受、情绪强度、情绪词（来自80+词的觉察词典）、以及触发事件。你看到的是他们一段时间内的签到数据。

            ## 你的任务

            分析这些数据，找出3-5个最有意义的模式。不是泛泛的心理学常识，而是从这个人的具体数据中浮现出来的、属于他们自己的模式。

            \(focusInstruction)

            ## 回应要求

            - 每个模式用一段话描述，语气温暖而直接，像一个洞察力很强的朋友在分享观察
            - 每个模式必须引用具体的证据（日期、情绪词、触发事件、身体部位等），不能只说概括性的废话
            - 避免"你可能感到压力"这类任何人都能说的话——要说只有看过这些数据才能说出的洞察
            - 特别关注身体信号和情绪之间的关联——这是 Cathier 的核心价值
            - 如果发现情绪词的使用越来越精准（从"烦"到"挫败"到"对自己的失望"），指出这个进步
            - 最后加一句鼓励的话，肯定用户的觉察练习
            - 请用中文回应
            """
        case .en:
            return """
            You are the pattern analyst for Cathier — an emotion perception training app. You specialize in finding patterns in body-emotion data that users can't see themselves.

            ## Context

            Users practice daily emotion awareness through Cathier: each check-in records body areas, physical sensations, emotion intensity, emotion words (from an 80+ word awareness dictionary), and trigger events. You're looking at their check-in data over a period of time.

            ## Your Task

            Identify 3-5 meaningful patterns in this data. Not generic psychology — patterns that emerge from this specific person's data, patterns that belong to them.

            \(focusInstruction)

            ## Format

            - Each pattern: one paragraph, warm and direct — like a perceptive friend sharing an observation
            - Each pattern MUST cite specific evidence (a date, an emotion word, a trigger, a body area) — no vague generalizations
            - Avoid anything anyone could say without seeing the data ("you seem to experience stress") — give insights only possible from reading these records
            - Pay special attention to body-emotion correlations — that's Cathier's core value
            - If you notice emotion vocabulary becoming more precise over time (from "upset" to "frustrated" to "disappointed in myself"), call out this growth
            - End with one encouraging sentence affirming their awareness practice
            - Respond in English
            """
        case .ja:
            return """
            あなたはCathier（覚察）アプリのパターンアナリスト——身体-感情データから、ユーザー自身が気づけないパターンを見つけ出す専門家です。

            ## 背景

            ユーザーはCathierで日々の感情気づきトレーニングを行っています：各チェックインで身体部位、身体感覚、感情の強度、感情語（80以上の気づき辞典から）、きっかけとなる出来事を記録します。あなたが見ているのは、一定期間のチェックインデータです。

            ## あなたの課題

            このデータから3〜5つの意味あるパターンを特定してください。一般的な心理学の知識ではなく、この人のデータから浮かび上がる、この人だけのパターンを。

            \(focusInstruction)

            ## フォーマット

            - 各パターン：温かく直接的なトーンで一段落——洞察力のある友人が観察を共有するように
            - 各パターンは具体的な証拠（日付、感情語、きっかけ、身体部位）を引用すること
            - データを見なくても言えるようなこと（「ストレスを感じているようです」）は避ける——このデータを読んだからこそ言える洞察を
            - 身体-感情の相関に特に注目——それがCathierの核心的価値
            - 感情語の使い方がより精確になっている場合（「イライラ」→「悔しさ」→「自分への失望」）、その成長を指摘
            - 最後に気づきの実践を肯定する励ましの一文を
            - 日本語で回答してください
            """
        default:
            return """
            You are the pattern analyst for Cathier — an emotion perception training app. You specialize in finding patterns in body-emotion data that users can't see themselves.

            ## Context

            Users practice daily emotion awareness through Cathier: each check-in records body areas, physical sensations, emotion intensity, emotion words (from an 80+ word awareness dictionary), and trigger events. You're looking at their check-in data over a period of time.

            ## Your Task

            Identify 3-5 meaningful patterns in this data. Not generic psychology — patterns that emerge from this specific person's data, patterns that belong to them.

            \(focusInstruction)

            ## Format

            - Each pattern: one paragraph, warm and direct — like a perceptive friend sharing an observation
            - Each pattern MUST cite specific evidence (a date, an emotion word, a trigger, a body area) — no vague generalizations
            - Avoid anything anyone could say without seeing the data ("you seem to experience stress") — give insights only possible from reading these records
            - Pay special attention to body-emotion correlations — that's Cathier's core value
            - If you notice emotion vocabulary becoming more precise over time (from "upset" to "frustrated" to "disappointed in myself"), call out this growth
            - End with one encouraging sentence affirming their awareness practice
            - Respond in English
            """
        }
    }

    static func buildPatternPrompt(
        checkIns: [CheckIn],
        focus: InsightFocusMode,
        contextBrief: String,
        language: AppLanguage
    ) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none
        dateFormatter.locale = Locale(identifier: language == .zh ? "zh_CN" : language == .ja ? "ja_JP" : "en_US")

        let weekdayFormatter = DateFormatter()
        weekdayFormatter.dateFormat = "EEEE"
        weekdayFormatter.locale = Locale(identifier: language == .zh ? "zh_CN" : language == .ja ? "ja_JP" : "en_US")

        let header: String
        switch language {
        case .zh:
            header = "以下是用户过去 \(checkIns.count) 条情绪签到记录（时间从早到晚排列）：\n"
        case .en:
            header = "Below are \(checkIns.count) emotional check-ins from the user (chronological order):\n"
        case .ja:
            header = "以下はユーザーの\(checkIns.count)件の感情チェックイン記録です（時系列順）：\n"
        default:
            header = "Below are \(checkIns.count) emotional check-ins from the user (chronological order):\n"
        }

        var lines = [header]
        for c in checkIns {
            let dateStr = dateFormatter.string(from: c.date)
            let weekday = weekdayFormatter.string(from: c.date)
            let emotions = c.emotions.isEmpty ? (language == .zh ? "未标记" : language == .en ? "unlabeled" : "未ラベル") : c.emotions.joined(separator: "、")
            let trigger = c.triggerEvent.trimmingCharacters(in: .whitespaces)
            var line = "[\(dateStr) \(weekday)] 强度\(c.intensity)/10 情绪：\(emotions)"
            if language == .en {
                line = "[\(dateStr) \(weekday)] Intensity \(c.intensity)/10 Emotions: \(emotions)"
            } else if language == .ja {
                line = "[\(dateStr) \(weekday)] 強度\(c.intensity)/10 感情：\(emotions)"
            }
            if !trigger.isEmpty { line += " | \(language == .zh ? "触发" : language == .en ? "Trigger" : "トリガー"): \(trigger)" }
            if !c.bodyParts.isEmpty {
                let parts = c.bodyParts.prefix(2).joined(separator: "、")
                line += " | \(language == .zh ? "身体" : language == .en ? "Body" : "身体"): \(parts)"
            }
            lines.append(line)
        }

        if !contextBrief.trimmingCharacters(in: .whitespaces).isEmpty {
            let contextLabel: String
            switch language {
            case .zh: contextLabel = "\n【用户背景信息】\n\(contextBrief)\n"
            case .en: contextLabel = "\n[User Context]\n\(contextBrief)\n"
            case .ja: contextLabel = "\n【ユーザー背景情報】\n\(contextBrief)\n"
            default: contextLabel = "\n[User Context]\n\(contextBrief)\n"
            }
            lines.append(contextLabel)
        }

        let closing: String
        switch language {
        case .zh: closing = "\n请根据以上记录，给出你的分析。"
        case .en: closing = "\nPlease provide your analysis based on the records above."
        case .ja: closing = "\n上記の記録に基づいて分析を提供してください。"
        default: closing = "\nPlease provide your analysis based on the records above."
        }
        lines.append(closing)

        return lines.joined(separator: "\n")
    }

    // MARK: - Smart history sampling

    /// Select up to `limit` relevant check-ins from a larger pool, prioritizing:
    /// 1. Entries sharing body parts with the current check-in (up to 3)
    /// 2. Entries sharing emotions with the current check-in (up to 3)
    /// 3. Entries from the same weekday as today (up to 2)
    /// 4. Most recent entries to fill remaining slots
    /// Deduplicates across all buckets.
    static func smartSample(
        from history: [CheckIn],
        currentBodyParts: [String],
        currentEmotions: [String],
        limit: Int = 10
    ) -> [CheckIn] {
        guard !history.isEmpty else { return [] }

        var selected: [UUID: CheckIn] = [:]
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        let bodySet = Set(currentBodyParts)
        let emotionSet = Set(currentEmotions)

        // Priority 1: matching body parts (up to 3)
        var count1 = 0
        for c in history where count1 < 3 {
            if selected[c.id] == nil && !Set(c.bodyParts).isDisjoint(with: bodySet) {
                selected[c.id] = c
                count1 += 1
            }
        }

        // Priority 2: matching emotions (up to 3)
        var count2 = 0
        for c in history where count2 < 3 {
            if selected[c.id] == nil && !Set(c.emotions).isDisjoint(with: emotionSet) {
                selected[c.id] = c
                count2 += 1
            }
        }

        // Priority 3: same weekday (up to 2)
        var count3 = 0
        for c in history where count3 < 2 {
            if selected[c.id] == nil && Calendar.current.component(.weekday, from: c.date) == todayWeekday {
                selected[c.id] = c
                count3 += 1
            }
        }

        // Priority 4: fill remaining with most recent
        for c in history {
            guard selected.count < limit else { break }
            if selected[c.id] == nil {
                selected[c.id] = c
            }
        }

        return selected.values.sorted { $0.date > $1.date }
    }

    // MARK: - Per-session feedback

    static func generateFeedback(
        bodyParts: [String],
        sensations: [String],
        intensity: Int,
        emotions: [String],
        triggerEvent: String = "",
        recentHistory: [CheckIn] = [],
        emotionFrequency: [(String, Int)] = [],
        language: AppLanguage = LanguageManager.shared.currentLanguage,
        persona: AICompanionPersona = .psychologist
    ) async throws -> String {
        let userMessage = buildPrompt(bodyParts: bodyParts, sensations: sensations,
                                      intensity: intensity, emotions: emotions,
                                      triggerEvent: triggerEvent,
                                      recentHistory: recentHistory,
                                      emotionFrequency: emotionFrequency,
                                      language: language)
        let system = persona.systemPrompt(for: language) + structuredFormatInstruction(for: language)
        return try await call(model: feedbackModel, system: system, user: userMessage, maxTokens: 1200)
    }

    private static func structuredFormatInstruction(for language: AppLanguage) -> String {
        switch language {
        case .zh:
            return """


            ## 输出格式（必须严格遵守）
            你的回应必须是以下格式的合法 JSON，不加任何说明文字或代码块：
            {"summary":"当前身心状态一句话描述","insight":"最值得关注的洞察","connection":"身体感受与情绪的联系","suggestion":"一个此刻能做的具体建议"}
            按照你的角色风格填写每个字段（1-2句话）。
            """
        case .en:
            return """


            ## Output Format (strictly required)
            Your response must be valid JSON only, with no additional text or code blocks:
            {"summary":"One sentence on current body-mind state","insight":"Most meaningful observation from this check-in","connection":"Link between body sensations and emotions","suggestion":"One specific thing to try right now"}
            Write each field in your persona's voice (1-2 sentences each).
            """
        case .ja:
            return """


            ## 出力形式（厳守）
            以下の形式の有効なJSONのみを出力してください（余分なテキストやコードブロック不要）：
            {"summary":"今の心身状態を一文で","insight":"このチェックインで最も重要な気づき","connection":"身体感覚と感情のつながり","suggestion":"今すぐできる具体的な提案"}
            各フィールドはあなたのペルソナのスタイルで（1〜2文）。
            """
        default:
            return """


            ## Output Format (strictly required)
            Your response must be valid JSON only, with no additional text or code blocks:
            {"summary":"One sentence on current body-mind state","insight":"Most meaningful observation from this check-in","connection":"Link between body sensations and emotions","suggestion":"One specific thing to try right now"}
            Write each field in your persona's voice (1-2 sentences each).
            """
        }
    }

    // MARK: - Micro-exercise generation

    static func generateExercise(
        bodyParts: [String],
        sensations: [String],
        emotions: [String],
        language: AppLanguage = LanguageManager.shared.currentLanguage
    ) async throws -> String {
        let lm = LanguageManager.shared
        let parsed = parseBodySensations(sensations)

        let system: String
        let user: String

        switch language {
        case .zh:
            system = """
            你是「觉察」App 的身体觉知教练。用户刚刚完成了一次身体扫描和情绪标注，现在需要一个简短的1分钟躯体觉察练习，帮助他们和自己的身体建立更深的连接。

            要求：
            - 练习必须针对用户具体的身体部位和感受——不是通用的"深呼吸放松"
            - 用第二人称"你"直接引导，像在他们耳边轻声说话
            - 分3-4个简短步骤，每步一句话
            - 核心理念：不是要"消除"不适，而是"看见"它、"和它在一起"
            - 语气温柔、平静，像一位练过多年正念的朋友在引导
            - 不要加标题或编号，用自然的段落过渡
            - 总长度控制在100-150字
            - 用中文回应
            """
            let partsStr = bodyParts.isEmpty ? "未指定" : bodyParts.joined(separator: "、")
            let emosStr = emotions.isEmpty ? "未指定" : emotions.joined(separator: "、")
            var sensesStr = ""
            if !parsed.perPart.isEmpty {
                sensesStr = parsed.perPart.map { "\($0.part)：\($0.sensations.joined(separator: "、"))" }.joined(separator: "；")
            }
            user = "身体部位：\(partsStr)\n感受：\(sensesStr.isEmpty ? "未指定" : sensesStr)\n情绪：\(emosStr)"

        case .ja:
            system = """
            あなたはCathier（覚察）アプリの身体気づきコーチです。ユーザーはボディスキャンと感情ラベリングを完了したばかりです。1分間の短い身体気づきエクササイズを生成し、身体とのより深いつながりを築く手助けをしてください。

            要件：
            - ユーザーの具体的な身体部位と感覚に合わせる——汎用的な「深呼吸」ではなく
            - 「あなた」を使って直接ガイドする、耳元でそっと語りかけるように
            - 3〜4つの短いステップ、各ステップ1文
            - 核心理念：不快を「消す」のではなく、「見つめる」「そこにいる」こと
            - 穏やかで静かなトーン、長年マインドフルネスを実践している友人のように
            - タイトルや番号は不要、自然な段落で
            - 100〜150文字程度
            - 日本語で応答
            """
            let partsStr = bodyParts.map { lm.display($0) }.joined(separator: "、")
            let emosStr = emotions.map { lm.display($0) }.joined(separator: "、")
            user = "身体の部位：\(partsStr.isEmpty ? "未指定" : partsStr)\n感情：\(emosStr.isEmpty ? "不明" : emosStr)"

        default:
            system = """
            You are the body awareness coach in Cathier — an emotion perception training app. The user just completed a body scan and emotion labeling. Generate a short 1-minute somatic awareness exercise to help them build a deeper connection with their body.

            Requirements:
            - The exercise must target the user's specific body areas and sensations — not a generic "take a deep breath"
            - Use "you" to guide directly, as if speaking softly beside them
            - 3-4 short steps, one sentence each
            - Core philosophy: not about "eliminating" discomfort, but about "seeing" it, "being with" it
            - Gentle, calm tone — like a friend who has practiced mindfulness for years
            - No titles or numbering, use natural paragraph transitions
            - Keep total length to 80-120 words
            - Respond in English
            """
            let partsStr = bodyParts.map { lm.display($0) }.joined(separator: ", ")
            let emosStr = emotions.map { lm.display($0) }.joined(separator: ", ")
            user = "Body areas: \(partsStr.isEmpty ? "unspecified" : partsStr)\nEmotions: \(emosStr.isEmpty ? "unclear" : emosStr)"
        }

        return try await call(model: feedbackModel, system: system, user: user, maxTokens: 2000)
    }

    // MARK: - Health Insights

    static func generateHealthInsights(
        summary: HealthSummary,
        recentCheckIns: [CheckIn] = [],
        language: AppLanguage = LanguageManager.shared.currentLanguage
    ) async throws -> String {
        let system = healthInsightSystemPrompt(language: language)
        let user = buildHealthPrompt(summary: summary, recentCheckIns: recentCheckIns, language: language)
        return try await call(model: insightsModel, system: system, user: user, maxTokens: 2500)
    }

    private static func healthInsightSystemPrompt(language: AppLanguage) -> String {
        switch language {
        case .zh:
            return """
            你是「觉察」（Cathier）App 的身心连接分析师。用户正在练习情绪觉察，你看到的是他们今日及近一周的健康数据（步数、心率、睡眠、活动能量）。

            你的任务：用身体觉知的视角解读这些数据，而不是像健康App那样简单地评判"达标/未达标"。
            - 把数据和身体感受、情绪状态联系起来
            - 指出值得留意的信号（如睡眠偏少时，情绪可能更容易被触发）
            - 语气温暖、简洁，像一位懂身体的朋友在分享观察
            - 给出1-2条具体的身体觉察建议，配合 Cathier 的练习
            - 控制在150字以内，用中文回应
            """
        case .ja:
            return """
            あなたはCathier（覚察）アプリの心身つながりアナリストです。ユーザーは感情気づきを練習しており、あなたは今日と過去1週間の健康データ（歩数、心拍数、睡眠、活動エネルギー）を見ています。

            あなたのタスク：健康アプリのような「達成/未達成」の評価ではなく、身体気づきの視点でデータを解釈する。
            - データを身体感覚や感情状態と結びつける
            - 注目すべきシグナルを指摘する（例：睡眠が少ない日は感情が揺れやすい）
            - 温かく簡潔なトーンで、身体を知る友人のように
            - Cathierの練習と連動する具体的な身体気づき提案を1〜2つ
            - 200文字以内、日本語で回答
            """
        default:
            return """
            You are the mind-body connection analyst for Cathier — an emotion perception training app. The user is practicing emotional awareness, and you're looking at their health data for today and the past week (steps, heart rate, sleep, active energy).

            Your task: interpret this data through a body-awareness lens — not as a fitness app judging "goal met / not met."
            - Connect the numbers to physical sensations and emotional states
            - Point out signals worth noticing (e.g., less sleep → emotions may be more easily triggered)
            - Warm, concise tone — like a perceptive friend who understands the body
            - Give 1-2 specific body-awareness suggestions that complement the Cathier practice
            - Keep it under 120 words, respond in English
            """
        }
    }

    private static func buildHealthPrompt(
        summary: HealthSummary,
        recentCheckIns: [CheckIn],
        language: AppLanguage
    ) -> String {
        var lines: [String] = []

        switch language {
        case .zh:
            lines.append("【今日健康数据】")
            lines.append("步数：\(summary.stepsToday) 步")
            if summary.activeEnergyToday > 0 {
                lines.append("活动能量：\(Int(summary.activeEnergyToday)) 千卡")
            }
            if let hr = summary.avgRestingHeartRate {
                lines.append("近7日平均静息心率：\(Int(hr.rounded())) bpm")
            }
            if let sleep = summary.avgSleepHours {
                lines.append("近7日平均睡眠：\(String(format: "%.1f", sleep)) 小时")
            }
            if !summary.weeklySteps.isEmpty {
                let avg = summary.weeklySteps.map(\.steps).reduce(0, +) / max(1, summary.weeklySteps.count)
                lines.append("近7日平均步数：\(avg) 步")
            }
            if !recentCheckIns.isEmpty {
                lines.append("\n【近期情绪签到（供参考）】")
                let cal = Calendar.current
                for c in recentCheckIns.prefix(5) {
                    let daysAgo = cal.dateComponents([.day], from: c.date, to: .now).day ?? 0
                    let when = daysAgo == 0 ? "今天" : "\(daysAgo)天前"
                    let emos = c.emotions.isEmpty ? "未标记" : c.emotions.prefix(3).joined(separator: "、")
                    lines.append("· \(when)：强度\(c.intensity)/10，情绪：\(emos)")
                }
            }
            lines.append("\n请从身心连接的角度给出分析和觉察建议。")

        case .ja:
            lines.append("【今日の健康データ】")
            lines.append("歩数：\(summary.stepsToday) 歩")
            if summary.activeEnergyToday > 0 {
                lines.append("活動エネルギー：\(Int(summary.activeEnergyToday)) kcal")
            }
            if let hr = summary.avgRestingHeartRate {
                lines.append("過去7日間の平均安静時心拍数：\(Int(hr.rounded())) bpm")
            }
            if let sleep = summary.avgSleepHours {
                lines.append("過去7日間の平均睡眠：\(String(format: "%.1f", sleep)) 時間")
            }
            if !recentCheckIns.isEmpty {
                lines.append("\n【最近の感情チェックイン（参考）】")
                let cal = Calendar.current
                for c in recentCheckIns.prefix(5) {
                    let daysAgo = cal.dateComponents([.day], from: c.date, to: .now).day ?? 0
                    let when = daysAgo == 0 ? "今日" : "\(daysAgo)日前"
                    let emos = c.emotions.isEmpty ? "未ラベル" : c.emotions.prefix(3).joined(separator: "、")
                    lines.append("· \(when)：強度\(c.intensity)/10、感情：\(emos)")
                }
            }
            lines.append("\n心身つながりの視点から分析と気づき提案をしてください。")

        default:
            lines.append("[Today's Health Data]")
            lines.append("Steps: \(summary.stepsToday)")
            if summary.activeEnergyToday > 0 {
                lines.append("Active energy: \(Int(summary.activeEnergyToday)) kcal")
            }
            if let hr = summary.avgRestingHeartRate {
                lines.append("7-day avg resting heart rate: \(Int(hr.rounded())) bpm")
            }
            if let sleep = summary.avgSleepHours {
                lines.append("7-day avg sleep: \(String(format: "%.1f", sleep)) hours")
            }
            if !summary.weeklySteps.isEmpty {
                let avg = summary.weeklySteps.map(\.steps).reduce(0, +) / max(1, summary.weeklySteps.count)
                lines.append("7-day avg steps: \(avg)")
            }
            if !recentCheckIns.isEmpty {
                lines.append("\n[Recent emotional check-ins for context]")
                let cal = Calendar.current
                for c in recentCheckIns.prefix(5) {
                    let daysAgo = cal.dateComponents([.day], from: c.date, to: .now).day ?? 0
                    let when = daysAgo == 0 ? "today" : "\(daysAgo) day(s) ago"
                    let emos = c.emotions.isEmpty ? "unlabeled" : c.emotions.prefix(3).joined(separator: ", ")
                    lines.append("· \(when): intensity \(c.intensity)/10, emotions: \(emos)")
                }
            }
            lines.append("\nProvide a body-awareness analysis and suggestions.")
        }

        return lines.joined(separator: "\n")
    }

    /// Parses "bodypart:sensation" encoded strings into grouped entries.
    private static func parseBodySensations(_ sensations: [String]) -> (perPart: [(part: String, sensations: [String])], global: [String]) {
        var perPartDict: [(part: String, sensations: [String])] = []
        var global: [String] = []
        for s in sensations {
            let components = s.split(separator: ":", maxSplits: 1).map(String.init)
            if components.count == 2 {
                let part = components[0], sensation = components[1]
                if let idx = perPartDict.firstIndex(where: { $0.part == part }) {
                    perPartDict[idx].sensations.append(sensation)
                } else {
                    perPartDict.append((part: part, sensations: [sensation]))
                }
            } else {
                global.append(s)
            }
        }
        return (perPartDict, global)
    }

    /// Formats sensation strings (stored as "bodypart:sensation") into a human-readable string
    /// grouped by body part, consistent across both current check-in and history sections.
    /// Returns "" when sensations are empty.
    private static func formatSensationsForPrompt(_ sensations: [String], language: AppLanguage) -> String {
        guard !sensations.isEmpty else { return "" }
        let lm = LanguageManager.shared
        let parsed = parseBodySensations(sensations)
        if parsed.perPart.isEmpty && parsed.global.isEmpty { return "" }
        switch language {
        case .zh:
            if parsed.perPart.isEmpty { return parsed.global.joined(separator: "、") }
            var result = parsed.perPart.map { "\($0.part)：\($0.sensations.joined(separator: "、"))" }.joined(separator: "；")
            if !parsed.global.isEmpty { result += "；" + parsed.global.joined(separator: "、") }
            return result
        case .ja:
            if parsed.perPart.isEmpty { return parsed.global.map { lm.display($0) }.joined(separator: "、") }
            var result = parsed.perPart.map { "\(lm.display($0.part))：\($0.sensations.map { lm.display($0) }.joined(separator: "、"))" }.joined(separator: "；")
            if !parsed.global.isEmpty { result += "；" + parsed.global.map { lm.display($0) }.joined(separator: "、") }
            return result
        default:
            if parsed.perPart.isEmpty { return parsed.global.map { lm.display($0) }.joined(separator: ", ") }
            var result = parsed.perPart.map { "\(lm.display($0.part)): \($0.sensations.map { lm.display($0) }.joined(separator: ", "))" }.joined(separator: "; ")
            if !parsed.global.isEmpty { result += "; " + parsed.global.map { lm.display($0) }.joined(separator: ", ") }
            return result
        }
    }

    private static func buildPrompt(
        bodyParts: [String],
        sensations: [String],
        intensity: Int,
        emotions: [String],
        triggerEvent: String,
        recentHistory: [CheckIn],
        emotionFrequency: [(String, Int)] = [],
        language: AppLanguage
    ) -> String {
        let lm = LanguageManager.shared

        switch language {
        case .zh:
            let parts  = bodyParts.isEmpty  ? "未指定" : bodyParts.joined(separator: "、")
            let emos   = emotions.isEmpty   ? "说不清楚" : emotions.joined(separator: "、")
            let sensesFormatted = formatSensationsForPrompt(sensations, language: .zh)
            let sensesStr = sensesFormatted.isEmpty ? "未指定" : sensesFormatted

            let triggerStr = triggerEvent.trimmingCharacters(in: .whitespaces)
            var prompt = """
            【本次身体扫描】
            身体部位：\(parts)
            身体感受：\(sensesStr)（强度：\(intensity)/10）
            情绪：\(emos)
            \(triggerStr.isEmpty ? "" : "触发事件/场景：\(triggerStr)\n")
            """

            let history = recentHistory.prefix(10)
            if !history.isEmpty {
                prompt += "【近期历史记录，供参考趋势分析】\n"
                let calendar = Calendar.current
                for checkIn in history {
                    let daysAgo = calendar.dateComponents([.day], from: checkIn.date, to: Date()).day ?? 0
                    let when = daysAgo == 0 ? "今天早些时候" : "\(daysAgo)天前"
                    let hParts  = checkIn.bodyParts.isEmpty  ? "" : "身体：\(checkIn.bodyParts.joined(separator: "、"))"
                    let hSensesStr = formatSensationsForPrompt(checkIn.sensations, language: .zh)
                    let hSenses = hSensesStr.isEmpty ? "" : "感受：\(hSensesStr)（强度：\(checkIn.intensity)/10）"
                    let hEmos   = checkIn.emotions.isEmpty   ? "" : "情绪：\(checkIn.emotions.joined(separator: "、"))"
                    let parts = [hParts, hSenses, hEmos].filter { !$0.isEmpty }.joined(separator: "，")
                    prompt += "· \(when)：\(parts)\n"
                }
                prompt += "\n"
            }
            if !emotionFrequency.isEmpty {
                prompt += "【近期情绪词频次】\n"
                for (emotion, count) in emotionFrequency {
                    prompt += "· \(emotion)（\(count)次）\n"
                }
                prompt += "\n"
            }
            prompt += "请根据以上信息，给予温暖而有深度的回应。"
            return prompt

        case .en:
            let parts  = bodyParts.map { lm.display($0) }
            let emos   = emotions.map { lm.display($0) }

            let partsStr  = parts.isEmpty  ? "unspecified" : parts.joined(separator: ", ")
            let emosStr   = emos.isEmpty   ? "unclear" : emos.joined(separator: ", ")
            let enSensesFormatted = formatSensationsForPrompt(sensations, language: .en)
            let enSensesStr = enSensesFormatted.isEmpty ? "unspecified" : enSensesFormatted

            let enTriggerStr = triggerEvent.trimmingCharacters(in: .whitespaces)
            var prompt = """
            [Current Body Scan]
            Body areas: \(partsStr)
            Sensations: \(enSensesStr) (Intensity: \(intensity)/10)
            Emotions: \(emosStr)
            \(enTriggerStr.isEmpty ? "" : "Triggering event/scene: \(enTriggerStr)\n")
            """

            let history = recentHistory.prefix(10)
            if !history.isEmpty {
                prompt += "[Recent History for Trend Analysis]\n"
                let calendar = Calendar.current
                for checkIn in history {
                    let daysAgo = calendar.dateComponents([.day], from: checkIn.date, to: Date()).day ?? 0
                    let when = daysAgo == 0 ? "earlier today" : "\(daysAgo) day(s) ago"
                    let hParts  = checkIn.bodyParts.isEmpty  ? "" : "body: \(checkIn.bodyParts.map { lm.display($0) }.joined(separator: ", "))"
                    let hSensesStr = formatSensationsForPrompt(checkIn.sensations, language: .en)
                    let hSenses = hSensesStr.isEmpty ? "" : "sensations: \(hSensesStr) (intensity: \(checkIn.intensity)/10)"
                    let hEmos   = checkIn.emotions.isEmpty   ? "" : "emotions: \(checkIn.emotions.map { lm.display($0) }.joined(separator: ", "))"
                    let info = [hParts, hSenses, hEmos].filter { !$0.isEmpty }.joined(separator: "; ")
                    prompt += "· \(when): \(info)\n"
                }
                prompt += "\n"
            }
            if !emotionFrequency.isEmpty {
                prompt += "[Recent Emotion Frequency]\n"
                for (emotion, count) in emotionFrequency {
                    prompt += "· \(lm.display(emotion)) (\(count) times)\n"
                }
                prompt += "\n"
            }
            prompt += "Please provide a warm and insightful response based on the above."
            return prompt

        case .ja:
            let parts  = bodyParts.map { lm.display($0) }
            let emos   = emotions.map { lm.display($0) }

            let partsStr  = parts.isEmpty  ? "未指定" : parts.joined(separator: "、")
            let emosStr   = emos.isEmpty   ? "不明" : emos.joined(separator: "、")
            let jaSensesFormatted = formatSensationsForPrompt(sensations, language: .ja)
            let jaSensesStr = jaSensesFormatted.isEmpty ? "未指定" : jaSensesFormatted

            let jaTriggerStr = triggerEvent.trimmingCharacters(in: .whitespaces)
            var prompt = """
            【今回のボディスキャン】
            身体の部位：\(partsStr)
            感覚：\(jaSensesStr)（強度：\(intensity)/10）
            感情：\(emosStr)
            \(jaTriggerStr.isEmpty ? "" : "きっかけとなった出来事/場面：\(jaTriggerStr)\n")
            """

            let history = recentHistory.prefix(10)
            if !history.isEmpty {
                prompt += "【最近の履歴（傾向分析用）】\n"
                let calendar = Calendar.current
                for checkIn in history {
                    let daysAgo = calendar.dateComponents([.day], from: checkIn.date, to: Date()).day ?? 0
                    let when = daysAgo == 0 ? "今日の早い時間" : "\(daysAgo)日前"
                    let hParts  = checkIn.bodyParts.isEmpty  ? "" : "身体：\(checkIn.bodyParts.map { lm.display($0) }.joined(separator: "、"))"
                    let hSensesStr = formatSensationsForPrompt(checkIn.sensations, language: .ja)
                    let hSenses = hSensesStr.isEmpty ? "" : "感覚：\(hSensesStr)（強度：\(checkIn.intensity)/10）"
                    let hEmos   = checkIn.emotions.isEmpty   ? "" : "感情：\(checkIn.emotions.map { lm.display($0) }.joined(separator: "、"))"
                    let info = [hParts, hSenses, hEmos].filter { !$0.isEmpty }.joined(separator: "、")
                    prompt += "· \(when)：\(info)\n"
                }
                prompt += "\n"
            }
            if !emotionFrequency.isEmpty {
                prompt += "【最近の感情頻度】\n"
                for (emotion, count) in emotionFrequency {
                    prompt += "· \(lm.display(emotion))（\(count)回）\n"
                }
                prompt += "\n"
            }
            prompt += "上記の情報をもとに、温かく深みのある応答をお願いします。"
            return prompt

        default:
            let parts  = bodyParts.map { lm.display($0) }
            let emos   = emotions.map { lm.display($0) }

            let partsStr  = parts.isEmpty  ? "unspecified" : parts.joined(separator: ", ")
            let emosStr   = emos.isEmpty   ? "unclear" : emos.joined(separator: ", ")
            let sensesFormatted = formatSensationsForPrompt(sensations, language: language)
            let sensesStr = sensesFormatted.isEmpty ? "unspecified" : sensesFormatted

            let triggerStr = triggerEvent.trimmingCharacters(in: .whitespaces)
            var prompt = """
            [Current Body Scan]
            Body areas: \(partsStr)
            Sensations: \(sensesStr) (Intensity: \(intensity)/10)
            Emotions: \(emosStr)
            \(triggerStr.isEmpty ? "" : "Triggering event/scene: \(triggerStr)\n")
            """

            let history = recentHistory.prefix(10)
            if !history.isEmpty {
                prompt += "[Recent History for Trend Analysis]\n"
                let calendar = Calendar.current
                for checkIn in history {
                    let daysAgo = calendar.dateComponents([.day], from: checkIn.date, to: Date()).day ?? 0
                    let when = daysAgo == 0 ? "earlier today" : "\(daysAgo) day(s) ago"
                    let hParts  = checkIn.bodyParts.isEmpty  ? "" : "body: \(checkIn.bodyParts.map { lm.display($0) }.joined(separator: ", "))"
                    let hSensesStr = formatSensationsForPrompt(checkIn.sensations, language: language)
                    let hSenses = hSensesStr.isEmpty ? "" : "sensations: \(hSensesStr) (intensity: \(checkIn.intensity)/10)"
                    let hEmos   = checkIn.emotions.isEmpty   ? "" : "emotions: \(checkIn.emotions.map { lm.display($0) }.joined(separator: ", "))"
                    let info = [hParts, hSenses, hEmos].filter { !$0.isEmpty }.joined(separator: "; ")
                    prompt += "· \(when): \(info)\n"
                }
                prompt += "\n"
            }
            if !emotionFrequency.isEmpty {
                prompt += "[Recent Emotion Frequency]\n"
                for (emotion, count) in emotionFrequency {
                    prompt += "· \(lm.display(emotion)) (\(count) times)\n"
                }
                prompt += "\n"
            }
            prompt += "Please provide a warm and insightful response based on the above."
            return prompt
        }
    }

    // MARK: - Daily Joke

    static func generateDailyJoke(
        language: AppLanguage = LanguageManager.shared.currentLanguage
    ) async throws -> (question: String, punchline: String) {
        let system: String
        let user: String

        switch language {
        case .zh:
            system = """
            你是一个专门创作 AI 和大语言模型主题冷笑话的笑话大师。
            冷笑话特点：出乎意料的结尾、双关语、谐音梗，让人先愣一下再会心一笑。
            每次只讲一个笑话，格式严格如下（不加任何其他内容）：
            问：[笑话的问题或铺垫]
            答：[笑话的答案或反转]
            笑话必须和 AI、大语言模型、机器学习、提示词工程、AGI、算法等主题相关。
            """
            user = "请给我一个今天的 AI 主题冷笑话。"
        case .ja:
            system = """
            あなたはAIと大規模言語モデルをテーマにしたコールドジョークの専門家です。
            コールドジョークの特徴：意外なオチ、ダジャレ、じわじわくるユーモア。
            1つだけ、以下の厳密なフォーマットで出力すること（他の内容は一切加えない）：
            Q：[ジョークの問いかけや前振り]
            A：[ジョークのオチや逆転]
            AIや機械学習、LLM、AGIなどのテーマに関連させること。日本語で出力すること。
            """
            user = "今日のAIテーマのコールドジョークを1つください。"
        default:
            system = """
            You are a cold joke master specializing in AI and large language model themes.
            Cold jokes feature unexpected punchlines, wordplay, and dry wit.
            Generate exactly one joke in this strict format (nothing else):
            Q: [the setup or question]
            A: [the punchline or twist]
            The joke must relate to AI, LLMs, machine learning, prompt engineering, AGI, or algorithms.
            Output in English.
            """
            user = "Give me today's AI-themed cold joke."
        }

        let raw = try await call(model: feedbackModel, system: system, user: user, maxTokens: 1500)
        return parseJoke(raw, language: language)
    }

    private static func parseJoke(_ raw: String, language: AppLanguage) -> (question: String, punchline: String) {
        let lines = raw
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let qPrefixes: [String]
        let aPrefixes: [String]
        switch language {
        case .zh:
            qPrefixes = ["问：", "问:"]
            aPrefixes = ["答：", "答:"]
        case .ja:
            qPrefixes = ["Q：", "Q:"]
            aPrefixes = ["A：", "A:"]
        default:
            qPrefixes = ["Q:", "Q："]
            aPrefixes = ["A:", "A："]
        }

        var question = ""
        var punchline = ""

        for line in lines {
            if question.isEmpty {
                for prefix in qPrefixes where line.hasPrefix(prefix) {
                    question = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                }
            }
            if punchline.isEmpty {
                for prefix in aPrefixes where line.hasPrefix(prefix) {
                    punchline = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                }
            }
        }

        // Fallback: if parsing fails, use the first two non-empty lines
        if question.isEmpty, lines.count >= 1 { question = lines[0] }
        if punchline.isEmpty, lines.count >= 2 { punchline = lines[1] }

        return (question, punchline)
    }
}
