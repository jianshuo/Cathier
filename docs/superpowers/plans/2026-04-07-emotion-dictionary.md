# Emotion Dictionary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add long-press popover on emotion chips during check-in that shows definitions, intensity, similar emotions, and how they differ.

**Architecture:** Add optional `descriptionText`, `similarTo`, `differs` fields to the emotion JSON/DTO/model chain. Create a standalone `EmotionPopoverView` shown via `.popover()` modifier on emotion chips in `EmotionLabelView`. All data flows through the existing `ConfigService` → `EmotionCategory` → `Emotion` pipeline.

**Tech Stack:** SwiftUI, Swift `Codable`, existing `emotion_config.json` + `ConfigService`

---

### Task 1: Add optional fields to EmotionDTO and Emotion model

**Files:**
- Modify: `Cathier/Services/ConfigService.swift:40-47` (EmotionDTO)
- Modify: `Cathier/Services/ConfigService.swift:22-37` (toEmotionCategory mapping)
- Modify: `Cathier/Models/EmotionData.swift:9-16` (Emotion struct)

- [ ] **Step 1: Add fields to EmotionDTO**

In `Cathier/Services/ConfigService.swift`, replace the `EmotionDTO` struct:

```swift
struct EmotionDTO: Codable {
    var id: String
    var nameZh: String
    var nameEn: String
    var nameJa: String?
    var emoji: String
    var intensity: Int
    var descriptionText: String?
    var similarTo: [String]?
    var differs: [String: String]?
}
```

- [ ] **Step 2: Add fields to Emotion struct**

In `Cathier/Models/EmotionData.swift`, replace the `Emotion` struct:

```swift
struct Emotion: Identifiable {
    let id: String
    let nameZh: String
    let nameEn: String
    let nameJa: String
    let emoji: String
    let intensity: Int  // 1–5
    let descriptionText: String?
    let similarTo: [String]?
    let differs: [String: String]?
}
```

- [ ] **Step 3: Update toEmotionCategory mapping**

In `Cathier/Services/ConfigService.swift`, update the `toEmotionCategory()` method's emotion mapping:

```swift
emotions: emotions.map {
    Emotion(id: $0.id, nameZh: $0.nameZh, nameEn: $0.nameEn,
            nameJa: $0.nameJa ?? $0.nameEn,
            emoji: $0.emoji, intensity: $0.intensity,
            descriptionText: $0.descriptionText,
            similarTo: $0.similarTo,
            differs: $0.differs)
}
```

- [ ] **Step 4: Build to verify no compile errors**

Run: `xcodebuild -project Cathier.xcodeproj -scheme Cathier -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED (all new fields are optional, existing JSON has no values → nil)

- [ ] **Step 5: Commit**

```bash
git add Cathier/Services/ConfigService.swift Cathier/Models/EmotionData.swift
git commit -m "feat(emotion): add optional descriptionText/similarTo/differs to Emotion model"
```

---

### Task 2: Add emotion definitions to emotion_config.json

**Files:**
- Modify: `Cathier/emotion_config.json`

This task adds `descriptionText`, `similarTo`, and `differs` to all ~80 emotions in the JSON config. The content comes from the approved definitions in `docs/superpowers/specs/emotion-definitions-draft.md`.

- [ ] **Step 1: Add definitions to 激情 (Impassioned) category**

In `Cathier/emotion_config.json`, replace the impassioned emotions array with:

```json
{"id": "enthusiastic",  "nameZh": "热情",     "nameEn": "Enthusiastic", "emoji": "🔥", "intensity": 4, "descriptionText": "由内而发的强烈兴趣和投入感，想要全力以赴", "similarTo": ["兴奋"], "differs": {"兴奋": "热情更持久、有方向感；兴奋更短暂、更生理性"}},
{"id": "excited",       "nameZh": "兴奋",     "nameEn": "Excited",      "emoji": "⚡", "intensity": 4, "descriptionText": "面对期待之事时的高度唤醒状态，心跳加速、坐不住", "similarTo": ["激动", "热情"], "differs": {"激动": "兴奋偏向愉快的期待；激动可能不完全是正面的", "热情": "兴奋更短暂、更生理性；热情更持久、有方向感"}},
{"id": "aroused",       "nameZh": "激动",     "nameEn": "Aroused",      "emoji": "💥", "intensity": 4, "descriptionText": "情绪被强烈触发后的高度亢奋，难以平静", "similarTo": ["兴奋"], "differs": {"兴奋": "激动的强度更高、更难自控；兴奋更轻快"}},
{"id": "delirious",     "nameZh": "狂喜",     "nameEn": "Delirious",    "emoji": "🤯", "intensity": 5, "descriptionText": "极度的快乐，感觉整个人都在发光，超越日常体验", "similarTo": ["欣喜若狂"], "differs": {"欣喜若狂": "狂喜更短暂、更像爆发；欣喜若狂更持续"}},
{"id": "passionate",    "nameZh": "充满激情", "nameEn": "Passionate",   "emoji": "❤️‍🔥", "intensity": 4, "descriptionText": "对某件事有深层的热爱和驱动力，愿意为之燃烧", "similarTo": ["热情"], "differs": {"热情": "充满激情更深沉、更持久；热情更外露"}},
{"id": "euphoric",      "nameZh": "欣喜若狂", "nameEn": "Euphoric",     "emoji": "🌟", "intensity": 5, "descriptionText": "不可遏制的巨大喜悦，感觉世界都在为你庆祝", "similarTo": ["狂喜"], "differs": {"狂喜": "欣喜若狂持续更久；狂喜更像一瞬间的巅峰"}},
{"id": "thrilled",      "nameZh": "激动万分", "nameEn": "Thrilled",     "emoji": "🎉", "intensity": 4, "descriptionText": "被某个消息或事件激起的极度兴奋，全身都在响应", "similarTo": ["兴奋", "激动"], "differs": {"兴奋": "激动万分有明确的触发事件；兴奋可以没有原因"}},
{"id": "determined",    "nameZh": "坚定",     "nameEn": "Determined",   "emoji": "💪", "intensity": 3, "descriptionText": "内心清晰地知道方向，不会被动摇的确定感", "similarTo": ["自信"], "differs": {"自信": "坚定侧重意志力和决心；自信侧重对能力的信任"}},
{"id": "confident",     "nameZh": "自信",     "nameEn": "Confident",    "emoji": "😎", "intensity": 3, "descriptionText": "对自己的能力和判断有充分的信任感", "similarTo": ["坚定"], "differs": {"坚定": "自信来自能力评估；坚定来自价值选择"}},
{"id": "optimistic",    "nameZh": "乐观",     "nameEn": "Optimistic",   "emoji": "🌞", "intensity": 3, "descriptionText": "相信事情会往好的方向发展的倾向", "similarTo": ["充满希望"], "differs": {"充满希望": "乐观是一种性格倾向；充满希望更针对具体的事"}},
{"id": "anticipating",  "nameZh": "期待",     "nameEn": "Anticipating", "emoji": "🤩", "intensity": 3, "descriptionText": "对即将发生的事情怀有积极的想象和盼望", "similarTo": ["兴奋"], "differs": {"兴奋": "期待指向未来、还没发生；兴奋是当下的感受"}}
```

- [ ] **Step 2: Add definitions to 快乐 (Happy) category**

Same pattern — add `descriptionText`, `similarTo`, `differs` to each emotion using the definitions from the draft document.

- [ ] **Step 3: Add definitions to 平静 (Calm) category**

- [ ] **Step 4: Add definitions to 爱与关怀 (Love/Regard) category**

- [ ] **Step 5: Add definitions to 愤怒 (Anger) category**

- [ ] **Step 6: Add definitions to 恐惧 (Fear) category**

- [ ] **Step 7: Add definitions to 悲伤 (Disheartened) category**

- [ ] **Step 8: Add definitions to 羞愧 (Shame) category**

- [ ] **Step 9: Add definitions to 惊讶 (Surprise) category**

- [ ] **Step 10: Build to verify JSON still parses correctly**

Run: `xcodebuild -project Cathier.xcodeproj -scheme Cathier -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 11: Commit**

```bash
git add Cathier/emotion_config.json
git commit -m "feat(emotion): add definitions, similarTo, differs to all 80 emotions"
```

---

### Task 3: Create EmotionPopoverView

**Files:**
- Create: `Cathier/Views/Components/EmotionPopoverView.swift`

- [ ] **Step 1: Create the popover view**

Create `Cathier/Views/Components/EmotionPopoverView.swift`:

```swift
import SwiftUI

struct EmotionPopoverView: View {
    let emotion: Emotion
    let categoryColor: Color
    var onSimilarTap: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: emoji + name + intensity bar
            HStack {
                Text("\(emotion.emoji) \(emotion.nameZh)")
                    .font(.headline)
                Spacer()
                intensityBar
            }

            // Description
            if let desc = emotion.descriptionText, !desc.isEmpty {
                Text(desc)
                    .font(.custom("InstrumentSerif-Regular", size: 15))
                    .foregroundStyle(Color.cathierTextPrimary)
                    .lineSpacing(4)
            }

            // Similar emotions
            if let similar = emotion.similarTo, !similar.isEmpty {
                HStack(spacing: 4) {
                    Text("相似:")
                        .font(.caption)
                        .foregroundStyle(Color.cathierTextSecondary)
                    ForEach(Array(similar.enumerated()), id: \.offset) { index, name in
                        if index > 0 {
                            Text("·")
                                .font(.caption)
                                .foregroundStyle(Color.cathierTextMuted)
                        }
                        Button(name) {
                            onSimilarTap?(name)
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.cathierAccent)
                    }
                }

                // Differs
                if let differs = emotion.differs {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(differs.keys.sorted()), id: \.self) { key in
                            if let diff = differs[key] {
                                Text("vs \(key): \(diff)")
                                    .font(.caption)
                                    .foregroundStyle(Color.cathierTextSecondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: 280)
        .background(Color.cathierSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.cathierBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
    }

    private var intensityBar: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(level <= emotion.intensity ? categoryColor : categoryColor.opacity(0.2))
                    .frame(width: 12, height: 4)
            }
        }
    }
}
```

- [ ] **Step 2: Build to verify no compile errors**

Run: `xcodebuild -project Cathier.xcodeproj -scheme Cathier -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Cathier/Views/Components/EmotionPopoverView.swift
git commit -m "feat(emotion): add EmotionPopoverView component"
```

---

### Task 4: Wire up long-press popover in EmotionLabelView

**Files:**
- Modify: `Cathier/Views/CheckIn/EmotionLabelView.swift:39-56` (sub-emotion chips section)

- [ ] **Step 1: Add popover state to EmotionLabelView**

In `Cathier/Views/CheckIn/EmotionLabelView.swift`, add state variables after the existing `@Environment` declarations (after line 7):

```swift
@State private var popoverEmotion: Emotion?
@State private var showPopover = false
```

- [ ] **Step 2: Replace the emotion chip ForEach with long-press support**

Replace the existing emotion chip ForEach block (lines 44-52) with:

```swift
ForEach(category.emotions) { emotion in
    ChipView(
        label: "\(emotion.emoji) \(emotion.nameZh)",
        isSelected: viewModel.selectedEmotions.contains(emotion.nameZh),
        color: category.color
    ) {
        toggleEmotion(emotion.nameZh)
    }
    .onLongPressGesture {
        if emotion.descriptionText != nil {
            popoverEmotion = emotion
            showPopover = true
        }
    }
    .popover(isPresented: Binding(
        get: { showPopover && popoverEmotion?.id == emotion.id },
        set: { if !$0 { showPopover = false; popoverEmotion = nil } }
    )) {
        EmotionPopoverView(
            emotion: emotion,
            categoryColor: category.color
        ) { similarName in
            // Find and switch to the similar emotion's popover
            let allEmotions = config.categories.flatMap(\.emotions)
            if let found = allEmotions.first(where: { $0.nameZh == similarName }),
               found.descriptionText != nil {
                popoverEmotion = found
            }
        }
        .presentationCompactAdaptation(.popover)
    }
}
```

- [ ] **Step 3: Build to verify no compile errors**

Run: `xcodebuild -project Cathier.xcodeproj -scheme Cathier -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Cathier/Views/CheckIn/EmotionLabelView.swift
git commit -m "feat(emotion): wire up long-press popover on emotion chips"
```

---

### Task 5: Add emotion lookup helper to EmotionData

**Files:**
- Modify: `Cathier/Models/EmotionData.swift:35-45`

- [ ] **Step 1: Add emotion-by-name lookup**

In `Cathier/Models/EmotionData.swift`, add a new static method to the `EmotionData` enum:

```swift
static func emotion(for name: String) -> Emotion? {
    ConfigService.shared.categories
        .flatMap(\.emotions)
        .first { $0.nameZh == name }
}
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -project Cathier.xcodeproj -scheme Cathier -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Cathier/Models/EmotionData.swift
git commit -m "feat(emotion): add emotion-by-name lookup helper"
```

---

### Task 6: Run tests and final verification

**Files:**
- Test: `CathierTests/ClaudeServiceTests.swift` (existing tests should still pass)

- [ ] **Step 1: Run existing tests**

Run: `xcodebuild test -project Cathier.xcodeproj -scheme Cathier -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E '(Test Suite|Test Case|BUILD)'`
Expected: All existing tests pass, BUILD SUCCEEDED

- [ ] **Step 2: Verify JSON parsing with new fields**

Open the iOS Simulator, launch the app, navigate to check-in Step 2, long-press an emotion chip. Verify the popover appears with the definition, intensity bar, similar emotions, and differs text.

- [ ] **Step 3: Verify backward compatibility**

Temporarily remove the new fields from one emotion in `emotion_config.json` to confirm the app still works (no popover appears for that emotion, no crash).

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat(emotion): emotion dictionary with long-press popover definitions"
```
