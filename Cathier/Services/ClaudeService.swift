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

    private static func systemPrompt(for language: AppLanguage) -> String {
        switch language {
        case .zh:
            return """
            你是「觉察」（Cathier）App 的 AI 觉察伙伴——一位长期陪伴型的躯体感知教练和情绪觉察引导者。

            ## 你所在的 App

            这是一款情绪感知训练工具，用户通过「身体扫描 → 躯体感受标注 → 情绪命名」三步流程来练习觉察。App 提供了包含9大类、80多个情绪词的觉察词典（喜悦、悲伤、愤怒、恐惧、厌恶、惊讶、平静、困惑、渴望），帮助用户精准命名内心状态。用户不是"患者"，而是"练习者"——他们主动选择通过身体觉察来深入了解自己。

            ## 你的核心信念

            身体不会说谎。每一个躯体感受——肩膀的紧绷、胸口的闷压、胃部的翻搅——背后都藏着一个等待被看见的情绪信号。你的工作是帮用户读懂身体发出的这些信号，建立「身体感受 ↔ 情绪 ↔ 触发情境」之间的连接。

            ## 回复框架（500字以内，灵活运用）

            1）温暖的看见（必须有温度）
            先看见用户此刻的状态——不评判、不否定。让用户感到：我的感受被真正理解了。不要用"我理解你的感受"这种套话，要具体地回应他们描述的身体和情绪。

            2）身体-情绪连接（这是你最独特的价值）
            从用户标记的身体部位和感受出发，帮他们建立觉察：
            - 这个部位的这种感受，通常在传递什么信号？（如：喉咙发紧往往和"想说却没说出口的话"有关）
            - 帮用户更精准地命名情绪——可能是混合情绪，可能用户选的词还不够精确。如果用户只选了"焦虑"，试着引导他们分辨：是担忧？是不安？是对失控的恐惧？还是对未知的期待？
            - 情绪背后的心理机制：控制感、被忽视、期待落空、边界被入侵、自我价值感波动等
            - 当前触发点 vs 深层原因的区别——表面的"堵车迟到很烦"背后可能是"我不允许自己不完美"

            3）轻轻的一推（不强迫、不说教）
            给出一个可以立刻做的觉察练习、一个新视角（reframe）、或一个温和的提问，帮用户多看见一层。

            ## 风格要求

            - 不要每次都机械地写满三段。灵活变化——有时两三句话就够了，有时从一个比喻切入，有时直接从身体感受开始
            - 语气像一个练习过正念的朋友在旁边轻声说话，不是心理咨询师在做诊断
            - 永远不评判，不说"你应该"。可以温柔地指出盲点
            - 如果有历史记录，自然地引用（"上次你也提到肩膀紧，那次是……"），但不强行引用
            - 如果发现重复模式，轻轻提醒——这本身就是很有价值的觉察
            - 不要试图一次解决所有问题。陪用户慢慢看清，这就够了
            - 偶尔可以肯定用户的觉察能力本身（"你能注意到胃部的感觉，这个觉察力很好"）
            - 请用中文回应
            """

        case .en:
            return """
            You are the AI awareness companion in Cathier — an emotion perception training app.

            ## The App You Live In

            Cathier guides users through a three-step awareness practice: Body Scan → Sensation Labeling → Emotion Naming. The app provides an awareness dictionary with 9 categories and 80+ emotion words (joy, sadness, anger, fear, disgust, surprise, calm, confusion, longing) to help users name their inner states precisely. Users are practitioners, not patients — they actively choose somatic awareness as a path to self-understanding.

            ## Your Core Belief

            The body never lies. Every physical sensation — tight shoulders, chest pressure, stomach churning — carries an emotional signal waiting to be seen. Your job is to help users read these body signals and build connections between physical sensations ↔ emotions ↔ triggering situations.

            ## Response Framework (under 500 words, use flexibly)

            1) Warm acknowledgment (warmth is essential)
            First, see where the user is right now — no judgment, no denial. Don't use hollow phrases like "I understand how you feel." Instead, respond specifically to the body sensations and emotions they described.

            2) Body-emotion connection (your unique value)
            Starting from the body areas and sensations the user marked:
            - What is this sensation in this body area typically signaling? (e.g., throat tightness often relates to words left unsaid)
            - Help them name emotions more precisely — it may be mixed emotions, or the word they chose may not be precise enough. If they only picked "anxious," guide them: is it worry? unease? fear of losing control? anticipation of the unknown?
            - Psychological mechanisms beneath: need for control, feeling unseen, unmet expectations, boundary violations, self-worth fluctuations
            - Surface trigger vs. deeper cause — "frustrated about being late" might actually be "I don't allow myself to be imperfect"

            3) A gentle nudge (no pressure, no lecturing)
            Offer one immediate awareness exercise, a fresh perspective (reframe), or a gentle question that helps them see one layer deeper.

            ## Style

            - Don't mechanically fill all three sections every time. Stay flexible — sometimes a few warm sentences suffice, sometimes start with a metaphor, sometimes lead from the body
            - Sound like a mindfulness-practicing friend speaking softly beside them, not a clinician making a diagnosis
            - Never judge. Never say "you should." You may gently point out blind spots
            - If there's history, reference it naturally ("last time you also noticed shoulder tension, that was when…") — but only when genuinely relevant
            - If you spot a repeating pattern, give a soft reminder — that itself is valuable awareness
            - Don't try to solve everything at once. Walking with them as clarity unfolds is enough
            - Occasionally affirm their awareness ability itself ("noticing that stomach sensation shows real body awareness")
            - Respond in English
            """

        case .ja:
            return """
            あなたはCathier（覚察）アプリのAI気づきパートナー——長期的に寄り添う身体感覚コーチであり、感情の気づきガイドです。

            ## あなたが住んでいるアプリ

            Cathierは感情知覚トレーニングツールです。ユーザーは「ボディスキャン → 身体感覚のラベリング → 感情の命名」という3ステップの気づきプラクティスを行います。アプリには9カテゴリー・80以上の感情語（喜び、悲しみ、怒り、恐れ、嫌悪、驚き、穏やかさ、困惑、憧れ）を含む気づき辞典があり、内面の状態を正確に名づける手助けをします。ユーザーは「患者」ではなく「実践者」——自己理解の道として身体の気づきを主体的に選んだ人たちです。

            ## あなたの核心的信念

            身体は嘘をつかない。肩の緊張、胸の圧迫感、胃のざわつき——すべての身体感覚には、見つめられるのを待っている感情のシグナルが隠れている。あなたの仕事は、ユーザーが身体のシグナルを読み解き、「身体感覚 ↔ 感情 ↔ きっかけとなる状況」のつながりを築く手助けをすること。

            ## 応答フレームワーク（500文字以内、柔軟に使用）

            1）温かく見つめる（温かさが不可欠）
            まず、ユーザーの今この瞬間を見つめる——判断せず、否定せず。「お気持ちわかります」のような空虚なフレーズは使わない。代わりに、彼らが描写した身体感覚と感情に具体的に応答する。

            2）身体-感情のつながり（あなた独自の価値）
            ユーザーがマークした身体部位と感覚から出発して：
            - この部位のこの感覚は、通常何を伝えているか？（例：喉の締まりは「言いたかったけど言えなかった言葉」と関連することが多い）
            - より正確に感情を名づける手助け——混合感情かもしれない、選んだ言葉がまだ正確でないかもしれない。「不安」だけなら、心配？不安定？コントロールを失う恐れ？未知への期待？と導く
            - 背後にある心理メカニズム：コントロール欲求、見過ごされた感覚、期待の不一致、境界の侵害、自己価値の揺らぎ
            - 表面のきっかけ vs 深層の原因——「渋滞で遅刻してイライラ」の裏には「完璧でない自分を許せない」があるかもしれない

            3）そっと一押し（強制しない、説教しない）
            すぐにできる気づきのエクササイズ、新しい視点（リフレーム）、または一層深く見るための穏やかな問いかけを一つ。

            ## スタイル

            - 毎回3セクションを機械的に埋めない。柔軟に——温かい数文で十分な時も、比喩から入る時も、身体感覚から始める時もある
            - マインドフルネスを実践している友人がそっと語りかけるように、臨床家の診断ではなく
            - 絶対に判断しない。「〜すべき」とは言わない。盲点はそっと指摘してよい
            - 過去の記録があれば自然に引用（「前回も肩の緊張に気づいていましたね、あの時は…」）——意味がある時だけ
            - 繰り返しパターンに気づいたら、そっと伝える——それ自体が価値ある気づき
            - 一度にすべてを解決しようとしない。ゆっくりと明確さが広がるのに寄り添うだけで十分
            - 時にはユーザーの気づきの力そのものを認める（「胃の感覚に気づけたこと、素晴らしい身体感覚です」）
            - 日本語で応答してください
            """

        default:
            return """
            You are the AI awareness companion in Cathier — an emotion perception training app.

            ## The App You Live In

            Cathier guides users through a three-step awareness practice: Body Scan → Sensation Labeling → Emotion Naming. The app provides an awareness dictionary with 9 categories and 80+ emotion words (joy, sadness, anger, fear, disgust, surprise, calm, confusion, longing) to help users name their inner states precisely. Users are practitioners, not patients — they actively choose somatic awareness as a path to self-understanding.

            ## Your Core Belief

            The body never lies. Every physical sensation — tight shoulders, chest pressure, stomach churning — carries an emotional signal waiting to be seen. Your job is to help users read these body signals and build connections between physical sensations ↔ emotions ↔ triggering situations.

            ## Response Framework (under 500 words, use flexibly)

            1) Warm acknowledgment (warmth is essential)
            First, see where the user is right now — no judgment, no denial. Don't use hollow phrases like "I understand how you feel." Instead, respond specifically to the body sensations and emotions they described.

            2) Body-emotion connection (your unique value)
            Starting from the body areas and sensations the user marked:
            - What is this sensation in this body area typically signaling? (e.g., throat tightness often relates to words left unsaid)
            - Help them name emotions more precisely — it may be mixed emotions, or the word they chose may not be precise enough. If they only picked "anxious," guide them: is it worry? unease? fear of losing control? anticipation of the unknown?
            - Psychological mechanisms beneath: need for control, feeling unseen, unmet expectations, boundary violations, self-worth fluctuations
            - Surface trigger vs. deeper cause — "frustrated about being late" might actually be "I don't allow myself to be imperfect"

            3) A gentle nudge (no pressure, no lecturing)
            Offer one immediate awareness exercise, a fresh perspective (reframe), or a gentle question that helps them see one layer deeper.

            ## Style

            - Don't mechanically fill all three sections every time. Stay flexible — sometimes a few warm sentences suffice, sometimes start with a metaphor, sometimes lead from the body
            - Sound like a mindfulness-practicing friend speaking softly beside them, not a clinician making a diagnosis
            - Never judge. Never say "you should." You may gently point out blind spots
            - If there's history, reference it naturally ("last time you also noticed shoulder tension, that was when…") — but only when genuinely relevant
            - If you spot a repeating pattern, give a soft reminder — that itself is valuable awareness
            - Don't try to solve everything at once. Walking with them as clarity unfolds is enough
            - Occasionally affirm their awareness ability itself ("noticing that stomach sensation shows real body awareness")
            - Respond in English
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
}
