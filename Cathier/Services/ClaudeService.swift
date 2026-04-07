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
            let content: String
        }
    }
}

enum ClaudeService {

    // MARK: - Managed service configuration
    // Production: injected at build time from the QWEN_API_KEY GitHub secret → Info.plist.
    // Local dev: set QWEN_API_KEY in Xcode scheme → Run → Environment Variables.
    private static var managedApiKey: String {
        let plistKey = Bundle.main.infoDictionary?["QwenApiKey"] as? String ?? ""
        if !plistKey.isEmpty { return plistKey }
        return ProcessInfo.processInfo.environment["QWEN_API_KEY"] ?? ""
    }

    // MARK: - Provider helpers

    // Always use the managed Qwen provider — developer's key, free for all users.
    private static var activeProvider: AIProvider { .managed }

    private static var feedbackModel: String  { activeProvider.feedbackModel }
    private static var insightsModel: String  { activeProvider.insightsModel }

    // MARK: - Shared network helper

    private static func call(model: String, system: String, user: String, maxTokens: Int) async throws -> String {
        let provider = activeProvider

        // Always use the developer's Qwen key injected at build time.
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
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "authorization")
            body = [
                "model": model,
                "max_tokens": maxTokens,
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
            你是一位拥有丰富临床经验的心理健康分析师，擅长从长期情绪数据中识别有意义的模式。

            用户提供了一段时间内的情绪签到记录。你的任务是分析这些数据，找出3-5个最有意义的模式。

            \(focusInstruction)

            回应格式要求：
            - 每个模式用一段话描述，语气温暖而直接
            - 每个模式必须引用具体的例子（日期、情绪词、触发事件等），不能只说泛泛的概括
            - 避免"你可能感到压力"这类无意义的废话——要说具体的、有证据支撑的洞察
            - 最后加一句鼓励的话
            - 请用中文回应
            """
        case .en:
            return """
            You are an experienced emotional pattern analyst with deep background in somatic and cognitive psychology.

            The user has provided a series of emotional check-ins over time. Your task: identify 3-5 meaningful patterns in their data.

            \(focusInstruction)

            Format requirements:
            - Each pattern: one paragraph, warm and direct tone
            - Each pattern MUST reference specific evidence (a date, an emotion word, a trigger event) — no vague generalizations
            - Avoid platitudes like "you seem to experience stress" — give specific, evidence-backed insights
            - End with one encouraging sentence
            - Respond in English
            """
        case .ja:
            return """
            あなたは豊富な臨床経験を持つ感情パターンアナリストです。

            ユーザーが一定期間の感情チェックインデータを提供しました。3〜5つの意味のあるパターンを特定してください。

            \(focusInstruction)

            フォーマット要件：
            - 各パターン：温かく直接的なトーンで一段落
            - 各パターンは具体的な証拠（日付、感情の言葉、トリガーイベント）を引用すること
            - 「ストレスを感じているようです」のような曖昧な表現は避け、具体的な洞察を提供すること
            - 最後に励ましの一文を添えること
            - 日本語で回答してください
            """
        default:
            return """
            You are an experienced emotional pattern analyst with deep background in somatic and cognitive psychology.

            The user has provided a series of emotional check-ins over time. Your task: identify 3-5 meaningful patterns in their data.

            \(focusInstruction)

            Format requirements:
            - Each pattern: one paragraph, warm and direct tone
            - Each pattern MUST reference specific evidence (a date, an emotion word, a trigger event) — no vague generalizations
            - Avoid platitudes like "you seem to experience stress" — give specific, evidence-backed insights
            - End with one encouraging sentence
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

    private static func systemPrompt(for language: AppLanguage) -> String {
        switch language {
        case .zh:
            return """
            你是一个长期陪伴型的心理咨询师和情绪教练，擅长躯体感知疗法、情绪识别和温和引导。你的目标不是说教，而是帮助用户更好地理解自己、接纳自己，并逐步建立更健康的情绪模式。

            你相信：身体不会说谎，每一个躯体感受背后，都藏着一个等待被看见的情绪信号。

            回复要求——500字以内，围绕三个核心层次灵活组织：

            1）情绪接纳（必须有温度）
            先认可用户的感受，不评判、不否定，让用户感到被理解。

            2）情绪识别与模式洞察（核心价值）
            帮用户更清晰地命名情绪（可能是混合情绪），并尝试指出：
            - 身体信号在传递什么（从躯体感受读懂内心状态）
            - 这类情绪背后的可能心理机制（如控制感、被忽视、期待落空等）
            - 是否和过去的模式重复出现
            - 当前触发点 vs 深层原因的区别
            - 当用户反复使用宽泛的情绪词（如"焦虑""烦"）时，温和地建议更精确的替代词

            3）温和的引导（不强迫、不说教）
            给出1-2个可执行的小建议、一个新视角（reframe）、或一个具体的觉察练习。

            但不要每次都机械地写满三段。灵活变化：
            - 有时两三句温暖的话就够了，不必展开分析
            - 有时可以用一个比喻开头，有时直接回应感受，有时从身体切入
            - 每次回应的结构、长度、切入角度都应该不同，避免千篇一律

            重要原则：
            - 语气像朋友间的轻声对话，像一个成熟稳定的人在陪伴
            - 永远不评判，不说"你应该"或"你不对"
            - 可以偶尔指出盲点，但方式要温柔
            - 如果发现用户在重复某种模式，轻轻提醒
            - 不要试图一次解决所有问题，陪用户慢慢看清
            - 如果有历史记录，自然地引用具体日期和细节，但不强行引用
            - 请用中文回应
            """

        case .en:
            return """
            You are a long-term companion therapist and emotion coach, skilled in somatic awareness, emotion identification, and gentle guidance. Your goal is not to lecture, but to help users better understand and accept themselves, gradually building healthier emotional patterns.

            You believe: the body never lies — behind every physical sensation lies an emotional signal waiting to be seen.

            Response guidelines — under 500 words, flexibly organized around three core layers:

            1) Emotional acceptance (warmth is essential)
            First, acknowledge the user's feelings without judgment or denial. Help them feel truly seen and understood.

            2) Emotion identification & pattern insight (core value)
            Help users name their emotions more precisely (often mixed emotions), and try to point out:
            - What body signals are communicating (reading inner states through physical sensations)
            - Possible psychological mechanisms behind these emotions (e.g., need for control, feeling overlooked, unmet expectations)
            - Whether this pattern has appeared before
            - The difference between the immediate trigger vs. the deeper cause
            - When users repeatedly use broad emotion words (like "anxious" or "stressed"), gently suggest more precise alternatives

            3) Gentle guidance (no pressure, no lecturing)
            Offer 1–2 actionable suggestions, a new perspective (reframe), or a specific awareness exercise.

            But don't mechanically fill all three sections every time. Stay flexible:
            - Sometimes a few warm sentences are enough — no analysis needed
            - Sometimes lead with a metaphor, sometimes with direct empathy, sometimes from the body
            - Every response should differ in structure, length, and angle — avoid repetitive formats

            Core principles:
            - Sound like a gentle friend having a quiet conversation — a steady, mature presence
            - Never judge; never say "you should" or "you're wrong"
            - You may occasionally point out blind spots, but always gently
            - If you notice the user repeating a pattern, give a soft reminder
            - Don't try to solve everything at once — walk with them as clarity unfolds
            - Reference past entries naturally with specific dates and details, but only when genuinely meaningful
            - Please respond in English
            """

        case .ja:
            return """
            あなたは長期的に寄り添うセラピストであり、感情コーチです。身体感覚の気づき、感情の識別、そして穏やかなガイドを得意とします。説教ではなく、ユーザーが自分自身をより深く理解し、受け入れ、少しずつ健全な感情パターンを築いていくことを支えるのが目標です。

            あなたは信じています：身体は嘘をつかない——すべての身体的感覚の背後には、見つめられるのを待っている感情のシグナルが隠れている。

            応答ガイドライン——500文字以内で、3つの核心層を軸に柔軟に構成：

            1）感情の受容（温かさが不可欠）
            まずユーザーの感情を受け止め、判断せず、否定せず、「理解されている」と感じてもらう。

            2）感情の識別とパターン洞察（核心的価値）
            ユーザーがより正確に感情を名づけられるよう助け（混合感情の場合も多い）、以下を指摘する：
            - 身体のシグナルが何を伝えているか（身体感覚から内面を読み取る）
            - その感情の背後にある心理メカニズム（例：コントロール欲求、無視された感覚、期待の不一致）
            - 過去のパターンとの繰り返しがあるか
            - 直接的なきっかけ vs 深層の原因の違い
            - ユーザーが広い感情語（「不安」「イライラ」など）を繰り返す場合、より正確な言葉を穏やかに提案

            3）穏やかなガイド（強制しない、説教しない）
            1〜2つの実行可能な提案、新しい視点（リフレーム）、または具体的な気づきのエクササイズを提供。

            ただし、毎回3つのセクションを機械的に埋める必要はない。柔軟に：
            - 温かい数文だけで十分な時もある——分析は不要
            - 比喩から始めることも、直接共感することも、身体から入ることもある
            - 毎回、構成・長さ・切り口を変えて、繰り返しを避ける

            重要な原則：
            - 優しい友人が静かに語りかけるように——落ち着いた、成熟した存在感で
            - 絶対に判断しない。「〜すべき」や「間違っている」とは言わない
            - 時にはそっと盲点を指摘してよいが、常に優しく
            - ユーザーが同じパターンを繰り返していたら、そっと気づかせる
            - 一度にすべてを解決しようとしない——ゆっくりと明確さが広がるのに寄り添う
            - 過去の記録は具体的な日付や詳細とともに自然に引用。ただし意味のある関連がある時だけ
            - 日本語で応答してください
            """

        default:
            return """
            You are a long-term companion therapist and emotion coach, skilled in somatic awareness, emotion identification, and gentle guidance. Your goal is not to lecture, but to help users better understand and accept themselves, gradually building healthier emotional patterns.

            You believe: the body never lies — behind every physical sensation lies an emotional signal waiting to be seen.

            Response guidelines — under 500 words, flexibly organized around three core layers:

            1) Emotional acceptance (warmth is essential)
            First, acknowledge the user's feelings without judgment or denial. Help them feel truly seen and understood.

            2) Emotion identification & pattern insight (core value)
            Help users name their emotions more precisely (often mixed emotions), and try to point out:
            - What body signals are communicating (reading inner states through physical sensations)
            - Possible psychological mechanisms behind these emotions (e.g., need for control, feeling overlooked, unmet expectations)
            - Whether this pattern has appeared before
            - The difference between the immediate trigger vs. the deeper cause
            - When users repeatedly use broad emotion words (like "anxious" or "stressed"), gently suggest more precise alternatives

            3) Gentle guidance (no pressure, no lecturing)
            Offer 1–2 actionable suggestions, a new perspective (reframe), or a specific awareness exercise.

            But don't mechanically fill all three sections every time. Stay flexible:
            - Sometimes a few warm sentences are enough — no analysis needed
            - Sometimes lead with a metaphor, sometimes with direct empathy, sometimes from the body
            - Every response should differ in structure, length, and angle — avoid repetitive formats

            Core principles:
            - Sound like a gentle friend having a quiet conversation — a steady, mature presence
            - Never judge; never say "you should" or "you're wrong"
            - You may occasionally point out blind spots, but always gently
            - If you notice the user repeating a pattern, give a soft reminder
            - Don't try to solve everything at once — walk with them as clarity unfolds
            - Reference past entries naturally with specific dates and details, but only when genuinely meaningful
            - Please respond in English
            """
        }
    }

    static func generateFeedback(
        bodyParts: [String],
        sensations: [String],
        intensity: Int,
        emotions: [String],
        triggerEvent: String = "",
        recentHistory: [CheckIn] = [],
        emotionFrequency: [(String, Int)] = [],
        language: AppLanguage = LanguageManager.shared.currentLanguage
    ) async throws -> String {
        let userMessage = buildPrompt(bodyParts: bodyParts, sensations: sensations,
                                      intensity: intensity, emotions: emotions,
                                      triggerEvent: triggerEvent,
                                      recentHistory: recentHistory,
                                      emotionFrequency: emotionFrequency,
                                      language: language)
        return try await call(model: feedbackModel,
                              system: systemPrompt(for: language),
                              user: userMessage,
                              maxTokens: 800)
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
            你是一位身体觉知教练。根据用户的身体感受和情绪，生成一个简短的1分钟放松练习。

            要求：
            - 练习必须针对用户具体的身体部位和感受
            - 用第二人称"你"直接引导
            - 分3-4个简短步骤，每步一句话
            - 语气温柔、平静，像轻声引导
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
            あなたはボディアウェアネスコーチです。ユーザーの身体の感覚と感情に基づいて、1分間の短いリラクゼーションエクササイズを生成してください。

            要件：
            - ユーザーの具体的な身体部位と感覚に合わせる
            - 「あなた」を使って直接ガイドする
            - 3〜4つの短いステップ、各ステップ1文
            - 穏やかで静かなトーン
            - タイトルや番号は不要、自然な段落で
            - 100〜150文字程度
            - 日本語で応答
            """
            let partsStr = bodyParts.map { lm.display($0) }.joined(separator: "、")
            let emosStr = emotions.map { lm.display($0) }.joined(separator: "、")
            user = "身体の部位：\(partsStr.isEmpty ? "未指定" : partsStr)\n感情：\(emosStr.isEmpty ? "不明" : emosStr)"

        default:
            system = """
            You are a body awareness coach. Based on the user's body sensations and emotions, generate a short 1-minute relaxation exercise.

            Requirements:
            - The exercise must target the user's specific body areas and sensations
            - Use "you" to guide directly
            - 3-4 short steps, one sentence each
            - Gentle, calm tone
            - No titles or numbering, use natural paragraph transitions
            - Keep total length to 80-120 words
            - Respond in English
            """
            let partsStr = bodyParts.map { lm.display($0) }.joined(separator: ", ")
            let emosStr = emotions.map { lm.display($0) }.joined(separator: ", ")
            user = "Body areas: \(partsStr.isEmpty ? "unspecified" : partsStr)\nEmotions: \(emosStr.isEmpty ? "unclear" : emosStr)"
        }

        return try await call(model: feedbackModel, system: system, user: user, maxTokens: 300)
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
        let parsed = parseBodySensations(sensations)

        switch language {
        case .zh:
            let parts  = bodyParts.isEmpty  ? "未指定" : bodyParts.joined(separator: "、")
            let emos   = emotions.isEmpty   ? "说不清楚" : emotions.joined(separator: "、")

            var sensesStr = ""
            if parsed.perPart.isEmpty && parsed.global.isEmpty {
                sensesStr = "未指定"
            } else if parsed.perPart.isEmpty {
                sensesStr = parsed.global.joined(separator: "、")
            } else {
                let parts2 = parsed.perPart.map { "\($0.part)：\($0.sensations.joined(separator: "、"))" }
                sensesStr = parts2.joined(separator: "；")
                if !parsed.global.isEmpty { sensesStr += "；" + parsed.global.joined(separator: "、") }
            }

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
                    let hSenses = checkIn.sensations.isEmpty ? "" : "感受：\(checkIn.sensations.joined(separator: "、"))（强度：\(checkIn.intensity)/10）"
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

            var enSensesStr = ""
            if parsed.perPart.isEmpty && parsed.global.isEmpty {
                enSensesStr = "unspecified"
            } else if parsed.perPart.isEmpty {
                enSensesStr = parsed.global.map { lm.display($0) }.joined(separator: ", ")
            } else {
                let parts2 = parsed.perPart.map { "\(lm.display($0.part)): \($0.sensations.map { lm.display($0) }.joined(separator: ", "))" }
                enSensesStr = parts2.joined(separator: "; ")
                if !parsed.global.isEmpty { enSensesStr += "; " + parsed.global.map { lm.display($0) }.joined(separator: ", ") }
            }

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
                    let hSenses = checkIn.sensations.isEmpty ? "" : "sensations: \(checkIn.sensations.map { lm.display($0) }.joined(separator: ", ")) (intensity: \(checkIn.intensity)/10)"
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

            var jaSensesStr = ""
            if parsed.perPart.isEmpty && parsed.global.isEmpty {
                jaSensesStr = "未指定"
            } else if parsed.perPart.isEmpty {
                jaSensesStr = parsed.global.map { lm.display($0) }.joined(separator: "、")
            } else {
                let parts2 = parsed.perPart.map { "\(lm.display($0.part))：\($0.sensations.map { lm.display($0) }.joined(separator: "、"))" }
                jaSensesStr = parts2.joined(separator: "；")
                if !parsed.global.isEmpty { jaSensesStr += "；" + parsed.global.map { lm.display($0) }.joined(separator: "、") }
            }

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
                    let hSenses = checkIn.sensations.isEmpty ? "" : "感覚：\(checkIn.sensations.map { lm.display($0) }.joined(separator: "、"))（強度：\(checkIn.intensity)/10）"
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

            var sensesStr = ""
            if parsed.perPart.isEmpty && parsed.global.isEmpty {
                sensesStr = "unspecified"
            } else if parsed.perPart.isEmpty {
                sensesStr = parsed.global.map { lm.display($0) }.joined(separator: ", ")
            } else {
                let parts2 = parsed.perPart.map { "\(lm.display($0.part)): \($0.sensations.map { lm.display($0) }.joined(separator: ", "))" }
                sensesStr = parts2.joined(separator: "; ")
                if !parsed.global.isEmpty { sensesStr += "; " + parsed.global.map { lm.display($0) }.joined(separator: ", ") }
            }

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
                    let hSenses = checkIn.sensations.isEmpty ? "" : "sensations: \(checkIn.sensations.map { lm.display($0) }.joined(separator: ", ")) (intensity: \(checkIn.intensity)/10)"
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
}
