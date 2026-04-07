# Emotion Dictionary — Design Spec

## Summary

Add in-context emotion definitions via long-press popover on emotion chips during check-in Step 2 (EmotionLabelView). Users can understand what each emotion means and how it differs from similar emotions without leaving the flow.

## Data Model Changes

### emotion_config.json

Add three optional fields to each emotion object:

```json
{
  "id": "anxious",
  "nameZh": "焦虑",
  "nameEn": "Anxious",
  "emoji": "😰",
  "intensity": 4,
  "descriptionText": "对未来不确定事物的持续担忧，常伴随身体紧绷",
  "similarTo": ["担心", "紧张"],
  "differs": {"担心": "担心更具体，焦虑更弥散", "紧张": "紧张偏短暂，焦虑更持久"}
}
```

- `descriptionText: String?` — single-language definition (Chinese as base, translations in Strings.swift)
- `similarTo: [String]?` — array of similar emotion nameZh values
- `differs: [String: String]?` — key = similar emotion nameZh, value = how they differ

### EmotionDTO (ConfigService.swift)

Add optional properties to match:

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

### Emotion (EmotionData.swift)

Add matching properties:

```swift
struct Emotion: Identifiable {
    let id: String
    let nameZh: String
    let nameEn: String
    let nameJa: String
    let emoji: String
    let intensity: Int
    let descriptionText: String?
    let similarTo: [String]?
    let differs: [String: String]?
}
```

### Backward Compatibility

- All new fields are optional (`String?`, `[String]?`, `[String: String]?`)
- Old app + new JSON: old app ignores unknown keys (Swift JSONDecoder default)
- New app + old JSON: fields decode as nil, popover simply doesn't show
- No breaking change in either direction

### Localization

- `description` and `differs` values stored in Chinese (base language) in the JSON
- Translations added to `Strings.swift` keyed by emotion `id` (e.g., `emotionDesc_anxious`)
- Follows existing `LanguageManager` pattern used throughout the app

## UI Design

### Interaction

- **Trigger:** Long-press on any emotion chip in EmotionLabelView (Step 2 of check-in)
- **Dismiss:** Tap anywhere outside the popover
- **Similar emotion tap:** Tapping a similar emotion name in the popover switches to that emotion's popover

### Popover Layout

```
┌─────────────────────────┐
│ 😰 焦虑        ████░ 4/5│  ← emoji + name + intensity bar
│                         │
│ 对未来不确定事物的持续    │  ← description (Instrument Serif, 15pt)
│ 担忧，常伴随身体紧绷     │
│                         │
│ 相似: 担心 · 紧张        │  ← tappable similar emotion links
│ vs 担心: 担心更具体，     │  ← differs text (caption style)
│    焦虑更弥散            │
└─────────────────────────┘
```

### Visual Styling

- **Container:** `cathierSurface` background, `cathierBorder` 1pt stroke, `cornerRadius: 12, style: .continuous`
- **Header row:** emoji + nameZh in `.headline`, intensity bar using category color (small horizontal bar, 4pt height)
- **Description:** Instrument Serif, 15pt regular, `cathierTextPrimary`, 1.5 line height — consistent with AI feedback card (reflective moments use serif)
- **Similar emotions:** `.caption` style, `cathierAccent` color, tappable
- **Differs text:** `.caption` style, `cathierTextSecondary`
- **Shadow:** subtle drop shadow (radius: 8, opacity: 0.12)
- **Max width:** 280pt
- **Positioning:** centered above/below the tapped chip using `.popover()` modifier

### Empty State

If an emotion has no `descriptionText` (nil), the long-press does nothing — no popover appears. This gracefully handles old data or emotions that haven't been annotated yet.

## Implementation Scope

### Files to modify
1. `emotion_config.json` — add description/similarTo/differs to all ~80 emotions
2. `ConfigService.swift` — add optional fields to `EmotionDTO`, pass through in `toEmotionCategory()`
3. `EmotionData.swift` — add optional fields to `Emotion` struct
4. `EmotionLabelView.swift` — add `.onLongPressGesture` to emotion chips, show popover
5. `Strings.swift` — add translated description strings keyed by emotion id

### New files
1. `Views/Components/EmotionPopoverView.swift` — the popover card view

### Content generation
- ~80 emotion descriptions need to be written (Chinese base + translations)
- Can be generated with AI and reviewed for accuracy
- Each description: 1-2 sentences, ~20-40 Chinese characters
- Each differs entry: 1 sentence comparing two emotions

## Out of Scope

- Standalone emotion dictionary page (can be added later)
- Search functionality
- Emotion relationship graph/visualization
- Body scan area descriptions (separate feature)
