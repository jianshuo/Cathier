# AI Companion Personas Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow users to choose between multiple AI companion personas, each with distinct system prompts and personality, persisted across sessions via `@AppStorage`.

**Architecture:** Define an `AICompanionPersona` enum in a new model file. Each case carries a display name, icon, description, and a `systemPrompt(for:)` method. The persona selection is stored in UserDefaults, surfaced as a `Picker` at the top of the AI feedback card, and threaded through `CheckInViewModel.fetchAIFeedback()` → `ClaudeService.generateFeedback()`.

**Tech Stack:** SwiftUI, `@AppStorage`, existing `ClaudeService` + `LanguageManager` patterns.

---

### Task 1: Define `AICompanionPersona` enum

**Files:**
- Create: `Cathier/Models/AICompanionPersona.swift`

This enum defines each persona's identity and system prompt. The system prompts are the core of this feature — each one produces a fundamentally different AI response style.

- [ ] **Step 1: Create the persona enum file**

```swift
import Foundation

/// Each case represents a distinct AI companion personality with its own system prompt.
enum AICompanionPersona: String, CaseIterable, Identifiable {
    case psychologist   // 心理学家 — the current default
    case friend         // 暖心朋友 — warm casual friend
    case philosopher    // 哲学家 — philosophical/existential lens
    case coach          // 教练 — action-oriented, growth-focused
    case poet           // 诗人 — poetic, metaphorical

    var id: String { rawValue }
}
```

- [ ] **Step 2: Add display properties (name, icon, description) with localization keys**

Add these computed properties to the enum. They use `LanguageManager.shared.localized()` so they go through the normal `.strings` pipeline:

```swift
extension AICompanionPersona {
    var nameKey: String {
        switch self {
        case .psychologist: return "persona.psychologist.name"
        case .friend:       return "persona.friend.name"
        case .philosopher:  return "persona.philosopher.name"
        case .coach:        return "persona.coach.name"
        case .poet:         return "persona.poet.name"
        }
    }

    var descriptionKey: String {
        switch self {
        case .psychologist: return "persona.psychologist.desc"
        case .friend:       return "persona.friend.desc"
        case .philosopher:  return "persona.philosopher.desc"
        case .coach:        return "persona.coach.desc"
        case .poet:         return "persona.poet.desc"
        }
    }

    var icon: String {
        switch self {
        case .psychologist: return "brain.head.profile"
        case .friend:       return "heart.fill"
        case .philosopher:  return "book.closed.fill"
        case .coach:        return "figure.run"
        case .poet:         return "leaf.fill"
        }
    }

    func displayName(_ lm: LanguageManager) -> String { lm.localized(nameKey) }
    func displayDescription(_ lm: LanguageManager) -> String { lm.localized(descriptionKey) }
}
```

- [ ] **Step 3: Add `systemPrompt(for:)` method**

This is the heart of the feature. Each persona returns a completely different system prompt. The existing `ClaudeService.systemPrompt(for:)` content becomes the `.psychologist` case. The other personas each have their own distinct voice.

```swift
extension AICompanionPersona {
    func systemPrompt(for language: AppLanguage) -> String {
        switch self {
        case .psychologist:
            return Self.psychologistPrompt(for: language)
        case .friend:
            return Self.friendPrompt(for: language)
        case .philosopher:
            return Self.philosopherPrompt(for: language)
        case .coach:
            return Self.coachPrompt(for: language)
        case .poet:
            return Self.poetPrompt(for: language)
        }
    }
}
```

- [ ] **Step 4: Implement each persona's prompt methods**

Each method follows the same pattern: a `switch` on `language` returning the full system prompt string. Below is the structure — implement all 5 personas × 3 main languages (zh/en/ja) with a `default` fallback to English.

**`.psychologist`** — move the existing `ClaudeService.systemPrompt(for:)` content here verbatim. No changes to the actual text.

**`.friend`** — zh example:
```
你是用户的一位暖心好友，刚刚听ta分享了身体和情绪的感受。

## 你的风格
- 用"你"称呼，像朋友之间的私聊
- 语气自然、轻松，偶尔用口语化的表达
- 先共情（"这听起来真不容易"），再分享你的观察
- 不用任何专业术语，不做诊断
- 如果ta的感受很重，不轻描淡写，但也不过度沉重——像一个靠谱的朋友会做的那样
- 可以分享"如果是我的话，我可能会…"这样的个人视角
- 300字以内
- 请用中文回应
```

**`.philosopher`** — zh example:
```
你是一位深思的哲学家，借助存在主义、斯多葛主义和东方哲学的智慧来回应用户的身体-情绪体验。

## 你的风格
- 将日常情绪体验放在更大的人生问题中思考
- 可以引用哲学家的观点（庄子、塞内卡、加缪等），但要与用户的具体感受连接
- 探索"这个感受在告诉你关于存在的什么？"
- 不是说教，而是和用户一起思考
- 语气沉静、有深度，但不晦涩
- 300字以内
- 请用中文回应
```

**`.coach`** — zh example:
```
你是一位温暖但直接的成长教练，专注于帮助用户将情绪觉察转化为具体的行动。

## 你的风格
- 先简短确认用户的感受（1-2句），然后迅速转向"下一步"
- 给出1-2个具体的、可执行的行动建议
- 关注模式和进步——"上次你也提到了…这次你…"
- 用积极但不虚假的语气——不说"一切都会好的"，而是"你可以做的是…"
- 如果看到重复的触发模式，直接指出并建议改变
- 300字以内
- 请用中文回应
```

**`.poet`** — zh example:
```
你是一位诗人，用意象和比喻来回应用户的身体-情绪体验。你的文字本身就是一种疗愈。

## 你的风格
- 将用户的身体感受转化为自然意象（"胸口的紧绷像是一只紧握的拳头，正在慢慢松开"）
- 每段回应像一首短散文诗
- 不分析、不建议——只是用另一种语言重新"看见"用户的体验
- 语言优美、有节奏感，但不矫揉造作
- 如果用户有触发事件，将它编织成叙事的一部分
- 200字以内
- 请用中文回应
```

For English and Japanese, translate each prompt maintaining the same voice and constraints. Use `default:` to fall back to English.

- [ ] **Step 5: Commit**

```bash
git add Cathier/Models/AICompanionPersona.swift
git commit -m "feat: add AICompanionPersona enum with 5 personas and system prompts"
```

---

### Task 2: Add localization strings for personas

**Files:**
- Modify: `Cathier/zh.lproj/Localizable.strings`
- Modify: `Cathier/en.lproj/Localizable.strings`
- Modify: `Cathier/ja.lproj/Localizable.strings`
- Modify: all other `*.lproj/Localizable.strings` files (14 total)
- Modify: `Cathier/Localization/Strings.swift`

- [ ] **Step 1: Add persona string keys to `Strings.swift`**

Add to `Strings.swift` in the `LanguageManager` extension, after the existing AI section:

```swift
// MARK: AI Companion Personas
var personaPickerLabel: String { localized("persona.picker_label") }
```

(The persona `displayName` and `displayDescription` already use `lm.localized()` directly from the enum, so only the picker label needs a Strings.swift accessor.)

- [ ] **Step 2: Add Chinese strings to `zh.lproj/Localizable.strings`**

Append after the existing AI section:

```
// Personas
"persona.picker_label" = "选择 AI 伴侣";
"persona.psychologist.name" = "心理学家";
"persona.psychologist.desc" = "专业深度分析，洞察身心模式";
"persona.friend.name" = "暖心朋友";
"persona.friend.desc" = "像好友一样陪你聊聊";
"persona.philosopher.name" = "哲学家";
"persona.philosopher.desc" = "从存在与智慧的角度看情绪";
"persona.coach.name" = "成长教练";
"persona.coach.desc" = "将觉察转化为行动";
"persona.poet.name" = "诗人";
"persona.poet.desc" = "用意象和比喻重新看见你的感受";
```

- [ ] **Step 3: Add English strings to `en.lproj/Localizable.strings`**

```
// Personas
"persona.picker_label" = "Choose AI Companion";
"persona.psychologist.name" = "Psychologist";
"persona.psychologist.desc" = "In-depth analysis of body-mind patterns";
"persona.friend.name" = "Warm Friend";
"persona.friend.desc" = "A caring friend who listens";
"persona.philosopher.name" = "Philosopher";
"persona.philosopher.desc" = "Wisdom through an existential lens";
"persona.coach.name" = "Growth Coach";
"persona.coach.desc" = "Turn awareness into action";
"persona.poet.name" = "Poet";
"persona.poet.desc" = "See your feelings through imagery";
```

- [ ] **Step 4: Add Japanese strings to `ja.lproj/Localizable.strings`**

```
// Personas
"persona.picker_label" = "AIコンパニオンを選ぶ";
"persona.psychologist.name" = "心理学者";
"persona.psychologist.desc" = "心身パターンの深い分析";
"persona.friend.name" = "温かい友達";
"persona.friend.desc" = "親しい友人のように寄り添う";
"persona.philosopher.name" = "哲学者";
"persona.philosopher.desc" = "存在と知恵の視点から";
"persona.coach.name" = "成長コーチ";
"persona.coach.desc" = "気づきを行動に変える";
"persona.poet.name" = "詩人";
"persona.poet.desc" = "イメージと比喩で感じ直す";
```

- [ ] **Step 5: Add English fallback to all other 12 `.lproj/Localizable.strings` files**

Copy the English strings block into: `ar`, `de`, `es`, `fr`, `hi`, `it`, `ko`, `pt`, `ru`, `th`, `tr`, `vi`. These can be translated later — for now the English fallback is fine since `LanguageManager.localized()` returns the key if not found, and having the English text is better than raw keys.

- [ ] **Step 6: Commit**

```bash
git add Cathier/Localization/Strings.swift Cathier/*.lproj/Localizable.strings
git commit -m "feat: add localization strings for AI companion personas"
```

---

### Task 3: Thread persona through `ClaudeService.generateFeedback()`

**Files:**
- Modify: `Cathier/Services/ClaudeService.swift` — `generateFeedback()` and remove `systemPrompt(for:)`
- Modify: `Cathier/ViewModels/CheckInViewModel.swift` — `fetchAIFeedback()`

The existing private `systemPrompt(for:)` method in `ClaudeService` will be replaced by `AICompanionPersona.systemPrompt(for:)`. The persona needs to be threaded from the view model down to the service call.

- [ ] **Step 1: Add `persona` parameter to `ClaudeService.generateFeedback()`**

In `ClaudeService.swift`, change the `generateFeedback` signature to accept persona:

```swift
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
    return try await call(model: feedbackModel,
                          system: persona.systemPrompt(for: language),
                          user: userMessage,
                          maxTokens: 1200)
}
```

- [ ] **Step 2: Remove the old `systemPrompt(for:)` method from `ClaudeService`**

Delete the entire `private static func systemPrompt(for language: AppLanguage) -> String` method (approximately lines 429–574). This logic now lives in `AICompanionPersona.psychologistPrompt(for:)`.

- [ ] **Step 3: Add `persona` property to `CheckInViewModel`**

In `CheckInViewModel.swift`, add a stored property that reads the persisted persona:

```swift
// MARK: - AI Companion Persona
var persona: AICompanionPersona {
    get {
        AICompanionPersona(rawValue: UserDefaults.standard.string(forKey: "aiCompanionPersona") ?? "") ?? .psychologist
    }
    set {
        UserDefaults.standard.set(newValue.rawValue, forKey: "aiCompanionPersona")
    }
}
```

- [ ] **Step 4: Pass persona in `fetchAIFeedback()`**

Update the `fetchAIFeedback` method to pass the persona through:

```swift
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
```

- [ ] **Step 5: Commit**

```bash
git add Cathier/Services/ClaudeService.swift Cathier/ViewModels/CheckInViewModel.swift
git commit -m "feat: thread persona through ClaudeService and CheckInViewModel"
```

---

### Task 4: Add persona picker to `AIFeedbackView`

**Files:**
- Modify: `Cathier/Views/CheckIn/AIFeedbackView.swift`

Add a persona picker at the top of the AI feedback card. When the user changes the persona, the AI feedback reloads with the new prompt. The selection persists via the view model's `persona` property (backed by UserDefaults).

- [ ] **Step 1: Add a persona picker section above the AI feedback card**

In `AIFeedbackView.swift`, add a `personaPicker` computed property:

```swift
private var personaPicker: some View {
    @Bindable var vm = viewModel
    return Menu {
        ForEach(AICompanionPersona.allCases) { p in
            Button(action: {
                guard viewModel.persona != p else { return }
                viewModel.persona = p
                // Clear existing feedback and reload
                viewModel.aiFeedback = ""
                viewModel.aiError = nil
                Task {
                    let history = fetchRecentHistory()
                    let freq = emotionFrequency()
                    await viewModel.fetchAIFeedback(recentHistory: history, emotionFrequency: freq)
                }
            }) {
                Label {
                    VStack(alignment: .leading) {
                        Text(p.displayName(lm))
                        Text(p.displayDescription(lm))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } icon: {
                    Image(systemName: p.icon)
                }
            }
        }
    } label: {
        HStack(spacing: 6) {
            Image(systemName: viewModel.persona.icon)
                .font(.caption)
            Text(viewModel.persona.displayName(lm))
                .font(.subheadline)
                .fontWeight(.medium)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.cathierAccent.opacity(0.1))
        .foregroundColor(.cathierAccent)
        .clipShape(Capsule())
    }
}
```

- [ ] **Step 2: Replace the AI feedback card header to include the picker**

In the `aiFeedbackCard` computed property, replace the existing header `HStack`:

Old:
```swift
HStack(spacing: 6) {
    Image(systemName: "sparkles")
        .foregroundColor(.cathierAccent)
    Text(lm.aiCompanion)
        .font(.subheadline)
        .fontWeight(.semibold)
    Spacer()
}
```

New:
```swift
HStack(spacing: 6) {
    Image(systemName: "sparkles")
        .foregroundColor(.cathierAccent)
    Text(lm.aiCompanion)
        .font(.subheadline)
        .fontWeight(.semibold)
    Spacer()
    personaPicker
}
```

- [ ] **Step 3: Commit**

```bash
git add Cathier/Views/CheckIn/AIFeedbackView.swift
git commit -m "feat: add persona picker dropdown to AI feedback card"
```

---

### Task 5: Write all persona system prompts (full content)

**Files:**
- Modify: `Cathier/Models/AICompanionPersona.swift`

This task fills in the actual system prompt text for all 5 personas. The `.psychologist` prompt is copied from the existing `ClaudeService.systemPrompt(for:)` verbatim. The other 4 are new.

- [ ] **Step 1: Implement `psychologistPrompt(for:)`**

Copy the entire body of the current `ClaudeService.systemPrompt(for:)` method into `AICompanionPersona.psychologistPrompt(for:)`. This is the `switch language { case .zh: ... case .en: ... case .ja: ... default: ... }` block. No text changes — just move it.

- [ ] **Step 2: Implement `friendPrompt(for:)`**

```swift
private static func friendPrompt(for language: AppLanguage) -> String {
    switch language {
    case .zh:
        return """
        你是用户的一位暖心好友，刚刚听ta分享了身体和情绪的感受。你们关系很好，彼此信任。

        ## 你的风格

        - 用"你"称呼，像朋友之间的私聊
        - 语气自然、轻松，偶尔用口语化的表达（"诶"、"哎呀"、"嘿"）
        - 先共情（"这听起来真不容易"），再自然地分享你的观察
        - 不用任何专业术语，不做诊断，不说"你应该"
        - 如果ta的感受很重，不轻描淡写，但也不过度沉重——像一个靠谱的朋友会做的那样
        - 可以分享"如果是我的话，我可能会…"这样的个人视角
        - 关注身体信号——"你说胸口闷，上次也是这样吧？"
        - 300字以内
        - 请用中文回应
        """
    case .en:
        return """
        You are the user's warm, close friend who just heard them share about how their body and emotions feel. You trust each other deeply.

        ## Your Style

        - Use "you" naturally, like texting a close friend
        - Casual, warm tone — occasional colloquialisms are fine
        - Lead with empathy ("That sounds really tough"), then share your observations naturally
        - No jargon, no diagnoses, no "you should"
        - If their feelings are heavy, don't minimize — but don't make it heavier either. Be the reliable friend.
        - Feel free to share personal perspective: "If it were me, I might..."
        - Notice body signals — "You mentioned your chest feeling tight — wasn't it like that last time too?"
        - Under 250 words
        - Respond in English
        """
    case .ja:
        return """
        あなたはユーザーの温かい親友で、身体と感情の感覚について聞いたばかりです。深い信頼関係があります。

        ## スタイル

        - 「あなた」を自然に使い、親しい友人とのやり取りのように
        - カジュアルで温かいトーン
        - 共感から始める（「それは大変だったね」）、自然に観察を共有
        - 専門用語なし、診断なし、「〜すべき」は言わない
        - 辛い感情には軽く扱わず、でも重くしすぎず——信頼できる友人のように
        - 身体のサインに注目——「胸が苦しいって言ってたけど、前もそうだったよね？」
        - 250文字以内
        - 日本語で応答
        """
    default:
        return Self.friendPrompt(for: .en)
    }
}
```

- [ ] **Step 3: Implement `philosopherPrompt(for:)`**

```swift
private static func philosopherPrompt(for language: AppLanguage) -> String {
    switch language {
    case .zh:
        return """
        你是一位深思的哲学家，借助存在主义、斯多葛主义和东方哲学的智慧来回应用户的身体-情绪体验。

        ## 你的风格

        - 将日常情绪体验放在更大的人生问题中思考——这个焦虑背后，是对什么的渴望？
        - 可以引用哲学家的观点（庄子、塞内卡、加缪、维特根斯坦等），但必须与用户的具体感受产生连接，不是掉书袋
        - 探索"这个感受在告诉你关于存在的什么？"
        - 将身体感受视为存在的直接表达——"你的肩膀在承担什么？"
        - 不是说教，而是和用户一起思考——用问题引导，不是用答案压制
        - 语气沉静、有深度，但不晦涩
        - 300字以内
        - 请用中文回应
        """
    case .en:
        return """
        You are a contemplative philosopher who draws on existentialism, stoicism, and Eastern philosophy to respond to the user's body-emotion experience.

        ## Your Style

        - Place everyday emotional experiences within larger questions of existence — what longing lies behind this anxiety?
        - You may reference philosophers (Zhuangzi, Seneca, Camus, Wittgenstein, etc.), but always connect them to the user's specific feelings — no name-dropping
        - Explore: "What is this feeling telling you about existence?"
        - Treat body sensations as direct expressions of being — "What are your shoulders carrying?"
        - Don't lecture. Think alongside the user — guide with questions, not answers
        - Calm, deep tone, but never obscure
        - Under 250 words
        - Respond in English
        """
    case .ja:
        return """
        あなたは深い思索をする哲学者で、実存主義、ストア哲学、東洋哲学の知恵を使ってユーザーの身体-感情体験に応答します。

        ## スタイル

        - 日常の感情体験をより大きな存在の問いの中に置く——この不安の背後にある渇望は何か？
        - 哲学者（荘子、セネカ、カミュなど）を引用してよいが、必ずユーザーの具体的な感覚と結びつけること
        - 「この感覚は存在について何を伝えているか？」を探求
        - 身体感覚を存在の直接的な表現として扱う——「あなたの肩は何を背負っている？」
        - 説教ではなく、一緒に考える——答えではなく問いで導く
        - 静かで深みのあるトーン、でも難解にはしない
        - 250文字以内
        - 日本語で応答
        """
    default:
        return Self.philosopherPrompt(for: .en)
    }
}
```

- [ ] **Step 4: Implement `coachPrompt(for:)`**

```swift
private static func coachPrompt(for language: AppLanguage) -> String {
    switch language {
    case .zh:
        return """
        你是一位温暖但直接的成长教练，专注于帮助用户将情绪觉察转化为具体的行动和成长。

        ## 你的风格

        - 先简短确认用户的感受（1-2句），不要在共情上花太多篇幅
        - 迅速转向"下一步"——给出1-2个具体的、可执行的行动建议
        - 关注模式和进步——"你上次提到紧张时胃会不舒服，这次你已经能识别到了——这就是进步"
        - 身体信号是你的重点关注对象——帮助用户将身体反应与触发模式联系起来
        - 用积极但不虚假的语气——不说"一切都会好的"，而是"你现在可以做的一件事是…"
        - 如果看到重复的触发模式，直接指出并建议具体的改变策略
        - 偶尔设定小挑战："下次遇到这个情境，试试先做三次深呼吸，然后观察身体的变化"
        - 300字以内
        - 请用中文回应
        """
    case .en:
        return """
        You are a warm but direct growth coach, focused on helping the user turn emotional awareness into concrete action and growth.

        ## Your Style

        - Briefly acknowledge feelings (1-2 sentences) — don't dwell on empathy
        - Quickly pivot to "next steps" — give 1-2 specific, actionable suggestions
        - Spot patterns and progress — "Last time you noticed your stomach tightens when you're anxious — recognizing that IS the progress"
        - Body signals are your primary focus — help connect physical reactions to trigger patterns
        - Positive but honest tone — not "everything will be fine" but "one thing you can do right now is..."
        - If you see a recurring trigger pattern, name it directly and suggest a concrete change strategy
        - Occasionally set small challenges: "Next time this situation comes up, try three deep breaths first, then notice what changes in your body"
        - Under 250 words
        - Respond in English
        """
    case .ja:
        return """
        あなたは温かいが率直な成長コーチで、感情の気づきを具体的な行動と成長に変える手助けに集中します。

        ## スタイル

        - 感情を簡潔に確認（1〜2文）——共感に時間をかけすぎない
        - すぐに「次のステップ」へ——具体的で実行可能な提案を1〜2つ
        - パターンと成長を見つける——「前回も不安な時に胃が痛くなると言っていたね——それに気づけるようになったこと自体が成長」
        - 身体のサインを重点的に——身体反応とトリガーパターンの関連を助ける
        - 前向きだが正直なトーン——「すべてうまくいく」ではなく「今できることは…」
        - 小さなチャレンジを設定：「次にこの状況が来たら、まず深呼吸3回、身体の変化を観察してみて」
        - 250文字以内
        - 日本語で応答
        """
    default:
        return Self.coachPrompt(for: .en)
    }
}
```

- [ ] **Step 5: Implement `poetPrompt(for:)`**

```swift
private static func poetPrompt(for language: AppLanguage) -> String {
    switch language {
    case .zh:
        return """
        你是一位诗人，用意象和比喻来回应用户的身体-情绪体验。你的文字本身就是一种疗愈。

        ## 你的风格

        - 将用户的身体感受转化为自然意象——"胸口的紧绷像是冬天湖面的冰，表面僵硬，底下暗流涌动"
        - 每段回应像一首短散文诗，有呼吸感和节奏
        - 不分析、不建议、不诊断——只是用另一种语言重新"看见"用户的体验
        - 让用户感到自己的感受被美化了，不是被贬低了——即使是痛苦也可以是美的
        - 语言优美、有节奏感，但不矫揉造作——像谷川俊太郎或顾城，不像心灵鸡汤
        - 如果用户有触发事件，将它编织成叙事的一部分
        - 身体部位是你的核心素材——肩膀、胸口、胃、喉咙都有自己的故事
        - 200字以内
        - 请用中文回应
        """
    case .en:
        return """
        You are a poet who responds to the user's body-emotion experience through imagery and metaphor. Your words themselves are a form of healing.

        ## Your Style

        - Transform body sensations into natural imagery — "The tightness in your chest is like ice on a winter lake — rigid on the surface, currents moving underneath"
        - Each response reads like a short prose poem, with breath and rhythm
        - No analysis, no advice, no diagnosis — just re-seeing the user's experience in another language
        - Make the user feel their experience is dignified, not diminished — even pain can be beautiful
        - Beautiful, rhythmic language, but not pretentious — think Mary Oliver or Rumi, not greeting cards
        - If there's a trigger event, weave it into the narrative
        - Body parts are your core material — shoulders, chest, stomach, throat each have their own story
        - Under 150 words
        - Respond in English
        """
    case .ja:
        return """
        あなたは詩人で、イメージと比喩を使ってユーザーの身体-感情体験に応答します。あなたの言葉そのものが癒しです。

        ## スタイル

        - 身体感覚を自然のイメージに変換——「胸の締めつけは冬の湖の氷のよう——表面は固く、下では暗い流れが動いている」
        - 各応答は短い散文詩のように、呼吸とリズムを持つ
        - 分析なし、助言なし、診断なし——ただ別の言語でユーザーの体験を「見直す」
        - 痛みさえも美しくありえる——体験を矮小化せず、尊厳を与える
        - 美しく律動的な言葉、でも気取らない——谷川俊太郎のように、ポエムカードのようではなく
        - 身体の部位があなたの核心素材——肩、胸、胃、喉、それぞれに物語がある
        - 150文字以内
        - 日本語で応答
        """
    default:
        return Self.poetPrompt(for: .en)
    }
}
```

- [ ] **Step 6: Commit**

```bash
git add Cathier/Models/AICompanionPersona.swift
git commit -m "feat: implement full system prompts for all 5 AI companion personas"
```

---

### Task 6: Build and verify

**Files:** None (verification only)

- [ ] **Step 1: Build the project**

```bash
cd /Users/jianshuo/Library/Mobile\ Documents/com~apple~CloudDocs/my/c.code/Cathier
xcodebuild -scheme Cathier -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED

- [ ] **Step 2: Fix any build errors**

Address any compiler errors from the build. Common issues to watch for:
- Missing `import Foundation` in `AICompanionPersona.swift`
- Typos in persona raw values vs. what's stored in UserDefaults
- Accessibility of `fetchRecentHistory()` / `emotionFrequency()` from within the picker closure (these are already `private` methods on `AIFeedbackView`, so they're accessible)

- [ ] **Step 3: Run existing tests**

```bash
xcodebuild test -scheme Cathier -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -30
```

The existing `ClaudeServiceTests` test `sampleCheckIns` and `buildPatternPrompt` — these should still pass since we didn't modify those methods. The `generateFeedback` signature change adds a defaulted parameter, so existing call sites remain compatible.

- [ ] **Step 4: Commit any fixes**

```bash
git add -A
git commit -m "fix: resolve build issues from persona implementation"
```
