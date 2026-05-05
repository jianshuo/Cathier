# Design System & Functional Specification — Cathier

> This document serves as the complete reference for replicating Cathier on any platform (iOS, WeChat Mini Program, Web). It covers visual design tokens, every screen, every interaction, data models, and component specs.

## Product Context
- **What this is:** An iOS app for daily emotion awareness practice — body scans, emotion labeling (80+ words), AI-assisted reflection, an awareness dictionary (emotions + sensations + body parts), daily journaling, micro-exercises, and optional friend sharing with reactions.
- **Who it's for:** People who want to go deeper with emotional self-awareness, not casual mood loggers. Practitioners, not patients.
- **Space/industry:** Wellness / emotion tracking. Peers: How We Feel, Daylio, Reflectly, Finch, Moodnotes.
- **Project type:** Native iOS app (SwiftUI / iOS 26.2)
- **Version:** 1.8
- **Languages:** Chinese (primary), English, Japanese

## Aesthetic Direction
- **Direction:** Organic / Notebook — warm, grounded, quiet. Like a quality Japanese stationery brand or a Moleskine, not a wellness product.
- **Decoration level:** Intentional — subtle warm paper texture on key surfaces (check-in cards, AI feedback). Sparse use only.
- **Mood:** The app should feel like a focused practice space. Calm but present. Not therapeutic reassurance — not a comfort object. Something you open because you want to go deeper.
- **Design thesis:** Every wellness app uses pastels and rounded "baby" forms because they assume fragile users. Cathier's users are practitioners. The name 情绪感知训练 (emotion perception training) says it clearly. Design for active practice, not reassurance.
- **Reference:** Moleskine, Hobonichi Techo, Japanese stationery brands. Moodnotes by ustwo (for the "clinical precision + non-clinical look" balance).

## Typography

### Typefaces
- **Display / Reflection:** Instrument Serif (Google Fonts, free) — used for AI feedback, Pattern Insights, dictionary detail sheets, hero moments. Adds a journal/editorial personality no competitor uses. [Download](https://fonts.google.com/specimen/Instrument+Serif)
- **UI / Body:** System font — SF Pro on iOS, system-ui / PingFang SC on WeChat, -apple-system on web. All interface text, labels, body copy, navigation.
- **Data / Numbers:** Monospace system font — SF Mono on iOS, Menlo/Consolas on other platforms. Intensity scores, check-in counts.

### When to use Instrument Serif
Use it for moments that should feel like reading a journal entry — not for UI chrome:
- AI feedback body text
- Pattern Insights body text
- Dictionary detail sheet body text
- Dictionary hero names
- Empty state headlines with emotional resonance
- Do NOT use for: tab labels, buttons, form labels, navigation titles, chips

### Type Scale
| Token | Size | Weight | Usage |
|-------|------|--------|-------|
| largeTitle | 34px | Regular | Screen titles (此刻, 日记, 觉察词典) |
| title | 28px | Regular | Section headers, dictionary hero names |
| title2 | 22px | Semibold | Card titles, subheadings |
| headline | 17px | Semibold | List row titles, category headers |
| body | 17px | Regular | All body copy, AI feedback |
| callout | 16px | Regular | Secondary body, dictionary callout quotes |
| subheadline | 15px | Regular | Supporting text, chip labels |
| footnote | 13px | Regular | Timestamps, captions |
| caption | 12px | Medium | Labels, chips, metadata, section labels in detail sheets |
| caption2 | 11px | Semibold + uppercase + 0.08em tracking | Section divider labels |

**Platform mapping:**
- iOS: use Dynamic Type styles (`.font(.body)`, `.font(.caption)` etc.)
- WeChat Mini Program: define in `app.wxss` as CSS classes (`.text-body { font-size: 34rpx; }` etc., using rpx units)
- Web: use rem units with CSS custom properties

## Color

### Approach
Restrained — one bright energetic accent (orange) + warm neutrals. **Single accent system**: orange is the only brand color. Earlier versions used a sage secondary accent for friend / growth / positive states; that has been retired in favor of a unified orange so the brand reads coherently. Color is rare and meaningful. The warm off-white background is a deliberate departure from the pure-white iOS default — it makes the app feel analog, physical, present.

### Light Mode Palette
```
Background:      #F7F5F1  — warm off-white, like paper. Not pure white.
Surface:         #FFFFFF  — cards, sheets, inputs
Surface Alt:     #FAF9F7  — grouped table backgrounds
Border:          #E0DDD6  — warm gray borders
Text Primary:    #1A1613  — near-black, warm undertone
Text Secondary:  #5C5650  — secondary text
Text Muted:      #8A837A  — timestamps, captions, placeholders

Accent:          #F2700A  — bright orange. Single brand color. Used sparingly.
Accent Light:    #FEEBD8  — orange tint. Chip backgrounds, AI card header, positive states.
Accent Hover:    #D96308  — pressed/hover state for orange elements.

Semantic Success: #F2700A (accent)
Semantic Warning: #B45309
Semantic Error:   #C4614A
Semantic Info:    #1D4ED8

Note: legacy `cathierSage` / `cathierSageLight` color sets remain in the asset catalog but are no longer referenced from code. Do not introduce new sage usage.
```

### Dark Mode Palette
```
Background:      #1C1714  — deep walnut. Not pure black.
Surface:         #2A2420
Surface Alt:     #231F1B
Border:          #3D3630
Text Primary:    #F0EDE8
Text Secondary:  #B5AFA9
Text Muted:      #7A736D

Accent:          #F5861A  — slightly lighter orange for dark backgrounds
Accent Light:    #3D2210
```

### Color Tokens (cross-platform)
| Token | Light | Dark | Usage |
|-------|-------|------|-------|
| `--background` | #F7F5F1 | #1C1714 | Page background |
| `--surface` | #FFFFFF | #2A2420 | Cards, sheets, inputs |
| `--surface-alt` | #FAF9F7 | #231F1B | Grouped backgrounds |
| `--border` | #E0DDD6 | #3D3630 | Borders, dividers |
| `--text-primary` | #1A1613 | #F0EDE8 | Primary text |
| `--text-secondary` | #5C5650 | #B5AFA9 | Secondary text |
| `--text-muted` | #8A837A | #7A736D | Timestamps, placeholders |
| `--accent` | #F2700A | #F5861A | Brand accent (orange) — single accent system |
| `--accent-light` | #FEEBD8 | #3D2210 | Orange tint backgrounds, positive states |
| `--accent-hover` | #D96308 | — | Pressed/hover state |

**Platform implementation:**
- iOS: `Assets.xcassets` color sets with light/dark variants, named `cathierBackground`, `cathierAccent`, etc.
- WeChat: CSS variables in `app.wxss` (`:root { --background: #F7F5F1; }`)
- Web: CSS custom properties on `:root`

## Spacing

- **Base unit:** 8pt
- **Density:** Comfortable — screens should feel like turning pages, not scrolling a feed.

| Token | Value | Usage |
|-------|-------|-------|
| 2xs | 2pt | Micro gaps within a component |
| xs | 4pt | Icon gaps, tight inline elements |
| sm | 8pt | Chip gaps, list row internal spacing |
| md | 16pt | Card padding, section internal gaps |
| lg | 20pt | Screen horizontal margins |
| xl | 24pt | Between sections on a screen |
| 2xl | 32pt | Between major content groups |
| 3xl | 48pt | Above primary CTAs, between hero elements |

**Screen margins:** 20pt horizontal (matches iOS standard). Never go below 16pt.

## Layout

- **Approach:** Grid-disciplined for navigation / data screens. Editorial moments for reflection / insights screens where Instrument Serif appears.
- **Safe area:** Always respect safeAreaInsets. Bottom content should never be cut off by home indicator.
- **Tab bar:** System UITabBar with custom tint = cathierAccent.
- **Sheet presentations:** Use `.presentationDetents` with `.medium` and `.large`. Sheet background = cathierSurface.
- **Max content width:** N/A for iOS full-screen, but limit text blocks to ~680pt on iPad.

## Border Radius

| Token | Value | Usage |
|-------|-------|-------|
| Tight | 4pt | Small inputs, segmented controls |
| Small | 8pt | List row separators, inline tags |
| Medium | 12pt | Cards, check-in cards, AI feedback |
| Large | 20pt | Bottom sheets, modal surfaces |
| Full | 9999pt | Buttons, pills, chips |

Use `.cornerRadius()` or `.clipShape(RoundedRectangle(cornerRadius:))`. Prefer continuous corners: `RoundedRectangle(cornerRadius: 12, style: .continuous)`.

## Motion

- **Approach:** Intentional — slow, deliberate transitions. Nothing bouncy or springy.
- **Guiding principle:** The check-in flow should feel like a quiet ritual, not a gamified app.

| Token | Curve | Duration | Usage |
|-------|-------|----------|-------|
| Micro | easeOut | 0.10s | Tap feedback, toggle state |
| Short | easeOut | 0.20s | Button press, chip select |
| Medium | easeInOut | 0.35s | Card appear, modal open |
| Long | easeInOut | 0.50s | Check-in flow step transitions |

**SwiftUI:**
- Use `withAnimation(.easeInOut(duration: 0.35))` for card appearances
- Use `transition(.opacity.combined(with: .move(edge: .bottom)))` for sheet content
- Avoid `.spring()` — it undermines the calm, deliberate feel
- For the check-in step transitions: `AnyTransition.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))` with `.easeInOut(duration: 0.5)`

## AI Reflection Visual Language

The AI feedback card is a key brand moment. It should feel like reading a thoughtful note, not a chatbot response.

- **Container:** `cathierSurface` background, `cathierBorder` stroke, `cornerRadius: 12, style: .continuous`
- **Header strip:** `cathierAccentLight` background, "Cathier AI" label in `caption2` style, terracotta dot indicator
- **Body text:** Instrument Serif, 17pt regular, `cathierTextPrimary`, 1.55 line height
- **Key words in body text:** can be emphasized with `cathierAccent` color (for emotion words user labeled)
- **Footer:** "Save" and "Share" in `caption` style, `cathierAccent` and `cathierTextMuted` respectively

## Check-in Flow Design

The 3-step flow (Body Scan → Emotion Labeling → AI Feedback) is the core product loop. Each step should feel discrete and focused.

### Progress indicator
Simple segmented bar at the bottom, not a progress ring. 3 segments, filled in `cathierAccent`. Height: 4pt. Bottom aligned above home indicator.

### Step transitions
`AnyTransition.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))` — moves forward like turning pages.

### Body area chips (Step 1)
- Unselected: `cathierBackground` fill, `cathierBorder` stroke, `cathierTextSecondary` text
- Selected: `cathierAccentLight` fill, `cathierAccent` stroke, `cathierAccent` text
- `cornerRadius: 9999` (full pill)

### Emotion chips (Step 2)
- Same chip style as body areas
- Positive/growth emotions: use the same accent chip style — there is no separate positive-state color in the unified palette

## 觉察词典 (Awareness Dictionary) Design

The dictionary is a reference companion — not a textbook. It should feel like browsing a beautifully typeset field guide.

### Navigation
- **Segmented picker** at top: 情绪 / 身体感受 / 身体部位 (3 tabs)
- Navigation title: "觉察词典" in large title style

### Emotion tab
- Grouped by 9 categories, each with category icon + name in category color
- Emotion chips: `Capsule()` shape, category color at 10% opacity, category color text
- Tap → full-screen sheet

### Sensation tab
- Flat flow layout of all sensation chips
- Accent color (`cathierAccent` at 10% opacity)
- Tap → full-screen sheet

### Body Part tab
- List rows with name (zh) + name (en) + chevron
- `secondarySystemBackground` row background, 10pt corner radius
- Tap → full-screen sheet

### Detail Sheets (all three types)
- **Hero header:** centered, large icon/emoji + name (Instrument Serif title) + English subtitle
- **Section pattern:** icon (caption, accent color) + label (caption, semibold, secondary, 0.5pt tracking) + body (Instrument Serif, 6pt line spacing)
- **Literary/cultural quotes:** italic Instrument Serif callout, accent color at 6% background, 8pt corner radius
- **Chip lists** (related emotions, common locations, common sensations): Capsule chips in appropriate color family
- **Differs/similar section:** rounded card with `secondarySystemBackground`, 12pt corner radius, 14pt padding
- Background: `cathierBackground` (warm off-white)

### Color assignments
| Dictionary type | Accent color | Chip color |
|---|---|---|
| Emotions | Per-category color | Category color |
| Sensations | `cathierAccent` | Accent |
| Body Parts | `cathierAccent` | Accent for header and sensation chips within |

## Daily Journal Design

- Mood selector: 5 emoji moods in a horizontal row
- Gains/learnings: TextEditor with placeholder, `subheadline` font
- One entry per day; existing entry shown as `DailyJournalCard` on TodayView
- Card style: same as check-in cards (`secondarySystemBackground`, 14pt corner radius)

## Micro-Exercise Design

Appears after AI feedback loads in Step 3 of the check-in flow. Tailored to the user's selected body parts and sensations.

- Breathing exercises, grounding techniques, body awareness prompts
- Instrument Serif for instruction text
- Calm, step-by-step pacing — no timers or gamification

## Friend Feature Visual Language

Friend-related UI should feel warm but distinct from the core check-in flow.

- Shared check-in cards: per-person tint from a 5-color warm palette (sage, peach, lavender, wheat, sky), picked deterministically from CloudKit record name hash
- "Shared with friends" indicators: accent color (orange) — same as primary brand
- Privacy tier labels: clearly readable, `caption2` style, never ambiguous
- **Emoji reactions:** horizontal scroll of reaction buttons below each friend check-in. Selected reaction: `cathierAccent` background + white text. Unselected: `systemGray5` background. Names of reactors shown inline.
- **Body part + sensation display:** grouped per body part — part name in bold accent, sensations in secondary. No truncation, wrap to new lines.

## Accessibility

- All colors must pass WCAG AA contrast. Check especially: `cathierTextMuted` on `cathierBackground` (target ≥ 4.5:1)
- Support Dynamic Type — never hardcode font sizes
- All interactive elements minimum 44×44pt tap target
- VoiceOver labels on all icon-only buttons
- Reduce Motion: when `accessibilityReduceMotion` is true, use `.opacity` transitions only (no movement)

---

# Functional Specification (Screen-by-Screen)

## Navigation Structure

4-tab bottom navigation:

| Tab | Label (zh) | Label (en) | Icon | Color |
|-----|-----------|-----------|------|-------|
| 1 | 此刻 | Now | house.fill | accent when active |
| 2 | 日记 | Journal | book.fill | accent when active |
| 3 | 好友 | Friends | person.2.fill | accent when active |
| 4 | 设置 | Settings | gearshape.fill | accent when active |

## Tab 1: 此刻 (Today)

**Purpose:** Home dashboard — start a check-in, see today's entries, write daily journal.

**Layout (top to bottom):**
1. **Greeting** — time-aware ("早上好" / "下午好" / "晚上好"), `title2` weight
2. **Start Check-in Button** — full-width, `--accent` background, white text, `headline` font, 14px corner radius, 16px vertical padding. This is the primary CTA.
3. **Today's Check-ins** — section header "今日记录" + list of `CheckInCard` components. Empty state: subtle hint text.
4. **Daily Journal** — if today's journal exists: show `DailyJournalCard`. If not: prompt to create ("写下今日收获").

## Tab 2: 日记 (Journal)

**Purpose:** Historical log of all check-ins.

**Layout:**
- Grouped by date sections: "今天", "昨天", then date strings (e.g. "2026-04-08")
- Each section contains `CheckInCard` items
- Swipe left on a card → delete
- **Toolbar button** (top-right): opens Pattern Insights sheet
- **Empty state:** book icon + "还没有记录" hint

## Tab 3: 好友 (Friends)

**Purpose:** Social sharing hub.

**States:**
1. **Loading** — centered spinner
2. **iCloud Unavailable** — icon + error message (specific: not authenticated / network / service)
3. **Needs Profile** → Profile Setup screen
4. **Ready** → Friend Home

### Friend Home Layout:
1. **Friend Avatar Row** — horizontal scroll: [+ Add Friend button] + [friend emoji avatars with name below]. Context menu on avatar: disconnect.
2. **Divider**
3. **Merged Feed** — `FriendCheckInCard` and `SharedJournalCard` items sorted newest first
4. **Toolbar** (top-right): friend management icon with pending request badge (red circle + count)

### FriendCheckInCard:
| Element | Position | Style |
|---------|----------|-------|
| Avatar emoji | Left, 40x40 circle, gray5 bg | system size 28 |
| Name + relative date | Right of avatar | subheadline bold + caption secondary |
| Intensity badge | Top-right | colored pill |
| Emotion chips | Below header | capsule pills in category colors |
| Body parts + sensations | Below emotions | per-part grouping: **part name** (bold accent) + sensations (secondary) |
| AI snippet | Below body | accent-light bg, serif font, "阅读更多" link |
| Reaction row | Bottom | horizontal scroll of emoji buttons with reactor names |

**Card background:** per-person tint from 5-color palette:
| Color | Hex | Name |
|-------|-----|------|
| 1 | #E0EDE2 | sage |
| 2 | #FEEBD8 | peach |
| 3 | #EAE5F2 | lavender |
| 4 | #F5EDDA | wheat |
| 5 | #E3EEF3 | sky |

Tint assigned by: `abs(cloudKitRecordName.hashValue) % 5`

### Privacy Tiers (for sharing):
| Tier | rawValue | What's visible |
|------|----------|----------------|
| category | "category" | Emotion category names only (deduplicated) |
| emotions | "emotions" | Full emotion labels + body parts |
| full | "full" | Everything including notes and AI feedback |

## Tab 4: 设置 (Settings)

**Sections:**
1. **Language** — picker: 中文 / English / 日本語
2. **Notifications** — toggle + time pickers (default 09:00, 18:00) + save button
3. **Context Brief** — multi-line text editor ("关于你"), injected into AI pattern prompts
4. **探索** — NavigationLink to 觉察词典
5. **Feedback** — opens feedback form
6. **About** — app info

## Check-in Flow (3-Step Modal)

Full-screen modal, progress indicator at top (3 segments, 4px height, `--accent` fill).

### Step 1: Body Scan

**Layout (scrollable):**
1. **Section: "选择身体部位"** — FlowLayout of body part chips
   - Chip states: unselected (`--background` fill, `--border` stroke) / selected (`--accent-light` fill, `--accent` stroke)
   - 24 body parts total (see data below)
2. **For each selected body part:** sensation picker
   - Part name as sub-header
   - FlowLayout of sensation chips (part-specific, from `emotion_config.json` sensations map)
3. **Trigger Event** — optional text field ("发生了什么事？")
4. **Intensity Slider** — 1–10, color gradient: yellow (1-3) → orange (4-6) → red (7-10)
5. **Next Button** — disabled until ≥1 body part selected

### Step 2: Emotion Labeling

**Layout (scrollable):**
1. **Selected Emotions Summary** (top, if any selected) — horizontal chips with × remove button, accent-light background card
2. **Section: "你在感受什么？"** — 2-column grid of 9 category buttons
   - Each: icon + category name, category color bg when selected
3. **When category selected:** expand sub-section with emotion chips
   - FlowLayout, same chip style as body parts but in category color
   - **Long-press (0.5s)** on emotion chip → popover with description + similar emotions + "深入了解" button
4. **Custom Emotion** — text field ("输入自定义情绪")
5. **Generate AI Button** — `--accent` bg, disabled until ≥1 emotion selected
6. **Skip Button** — secondary text, saves without AI

### Step 3: AI Feedback

**Layout (scrollable):**
1. **Summary Card** — intensity badge, body parts, sensations (grouped per part), emotion chips, trigger text
2. **AI Reflection Card** — `--accent-light` background, `--accent` border, `--accent` sparkle icon
   - Loading: spinner + "正在思考..."
   - Error: retry button
   - Success: Instrument Serif body text, markdown rendered
3. **Micro-Exercise Button** (appears after AI loads) — opens exercise suggestions
4. **Note Field** — optional text area ("你的想法...")
5. **Share Options** (only if user has friends set up):
   - Privacy tier picker (don't share / category / emotions / full)
   - Toggle: include AI feedback in share
6. **Save Button** — full-width, `--accent` bg

## Pattern Insights (Sheet from Journal)

**Prerequisite:** ≥7 check-ins

**Layout:**
1. **Focus Picker** — horizontal scroll chips: 压力触发 / 成长 / 身体信号 / 随机探索
2. **Analyze Button**
3. **Loading state** — spinner + message
4. **Results:**
   - **Intensity Chart** — line + area chart of last 30 check-ins, date axis
   - **Narrative Card** — 3-5 AI-generated patterns, Instrument Serif, accent-light bg
5. **History** — collapsible list of past insights (date + focus + check-in count)

## 觉察词典 (Awareness Dictionary)

**Navigation:** Settings → 探索 → 觉察词典

**Top:** segmented picker — 情绪 / 身体感受 / 身体部位

### Emotions Tab:
- 9 category groups, each: icon + category name (headline, category color)
- Emotion chips in FlowLayout: `emoji + nameZh`, capsule, category color @ 10%, tap → sheet

### Sensations Tab:
- All 65 sensations in FlowLayout: nameZh, capsule, accent @ 10%, tap → sheet

### Body Parts Tab:
- 24 rows: nameZh (left) + nameEn (right) + chevron, tap → sheet

### Emotion Detail Sheet:
| Section | Icon | Content |
|---------|------|---------|
| 释义 | text.quote | description |
| 源起 | sparkle | origin |
| 体验 | heart.text.clipboard | experience |
| 具身感受 | figure.mind.and.body | embodiment |
| 意象 | eye | imagery |
| 发展阶段 | figure.2.arms.open | developmentalStage |
| 塑造事件 | clock.arrow.circlepath | formativeEvents |
| 性格影响 | person.fill.questionmark | personalityImpact |
| 转化 | arrow.triangle.2.circlepath | transformation |
| 文学 | book.closed | literaryReference (italic, tinted bg) |
| 相近情绪 | arrow.left.arrow.right | similarTo + differs (card bg) |

**Hero:** large emoji (56px) + nameZh (Instrument Serif title) + nameEn (subheadline secondary) + 5-bar intensity indicator in category color

### Sensation Detail Sheet:
| Section | Icon | Content |
|---------|------|---------|
| 释义 | text.quote | description |
| 具体体验 | hand.raised | howItFeels |
| 常见部位 | figure.stand | commonLocations (accent chips) |
| 常伴随情绪 | heart | relatedEmotions (accent chips) |
| 身体在说什么 | exclamationmark.bubble | signalMeaning |
| 可以做什么 | leaf | selfCare |
| 强度光谱 | chart.bar | intensitySpectrum (tinted bg) |
| 区别 | arrow.left.arrow.right | differs (card bg) |

**Hero:** hand icon (40px, accent) + nameZh (serif title) + nameEn

### Body Part Detail Sheet:
| Section | Icon | Content |
|---------|------|---------|
| 简介 | text.quote | description |
| 如何找到 | location.magnifyingglass | howToLocate |
| 常见感受 | hand.point.up.braille | commonSensations (accent chips) |
| 情绪关联 | heart | emotionalConnection |
| 觉察练习 | eye | awarenessGuide |
| 文化含义 | book.closed | culturalNote (italic, tinted bg) |

**Hero:** figure icon (40px, accent) + nameZh (serif title) + nameEn

## Daily Journal

**Entry point:** "写下今日收获" button on TodayView, or tap existing journal card to edit.

**Layout:**
1. **Mood Selector** — 5 emoji buttons in horizontal row:
   | Mood | Emoji | Label (zh) |
   |------|-------|-----------|
   | veryHappy | 😄 | 很开心 |
   | good | 😊 | 不错 |
   | okay | 😐 | 还好 |
   | notGreat | 😔 | 不太好 |
   | bad | 😢 | 很难过 |
2. **Gains Text Editor** — multi-line, placeholder "今天有什么收获？"
3. **Save Button**

One journal per day enforced. Can be shared with friends (toggle).

---

# Data Models (platform-agnostic)

## CheckIn
| Field | Type | Description |
|-------|------|-------------|
| id | UUID | Unique identifier |
| date | DateTime | When the check-in was created |
| bodyParts | String[] | Selected body part names (e.g. ["头部", "胸口"]) |
| sensations | String[] | Encoded as "bodypart:sensation" (e.g. ["头部:紧绷", "胸口:压迫"]) |
| intensity | Int (1-10) | Self-reported intensity |
| emotions | String[] | Selected emotion names (e.g. ["焦虑", "悲伤"]) |
| note | String | Optional user reflection |
| aiFeedback | String | AI-generated feedback text |
| triggerEvent | String | Optional trigger description |
| shareLevel | String? | null=private, "category"/"emotions"/"full" |

## DailyJournal
| Field | Type | Description |
|-------|------|-------------|
| id | UUID | Unique identifier |
| date | DateTime | One per day |
| mood | String | DailyMood rawValue ("veryHappy"/"good"/"okay"/"notGreat"/"bad") |
| gains | String | Free-text reflection |
| isShared | Bool | Whether shared with friends |

## Emotion Category (from emotion_config.json)
| Category (zh) | Category (en) | Icon | Color Hex | Valence | Count |
|---------------|---------------|------|-----------|---------|-------|
| 激情 | Impassioned | bolt.fill | #FF5933 | positive | 11 |
| 快乐 | Happy | sun.max.fill | #FFBF00 | positive | 10 |
| 平静 | Calm | leaf.fill | #33ADE6 | positive | 9 |
| 爱与关怀 | Love / Regard | heart.fill | #F272A5 | positive | 5 |
| 愤怒 | Anger | flame.fill | #F54538 | negative | 8 |
| 恐惧 | Fear | exclamationmark.triangle.fill | #AD52DE | negative | 8 |
| 悲伤 | Disheartened | cloud.drizzle.fill | #5C8ABF | negative | 12 |
| 羞愧 | Shame | eye.slash.fill | #8C6647 | negative | 8 |
| 惊讶 | Surprise | sparkles | #FF9400 | neutral | 8 |

## Body Parts (24)
头部, 眼睛, 脸部, 喉咙, 颈部, 肩膀, 手臂, 手掌, 胸口, 呼吸, 背部, 腹部, 腰部, 骨盆, 大腿, 双脚, 整个身体, 顶轮, 眉心轮, 喉轮, 心轮, 脐轮, 骶轮, 海底轮

Sensations are mapped per-body-part in `emotion_config.json` (e.g. 头部 → [沉重, 紧绷, 压迫, 刺痛, 胀痛, 嗡鸣, 发热, 昏沉, 放松]).

---

# Component Inventory

## CheckInCard (used in TodayView, JournalView)
| Element | Style |
|---------|-------|
| Container | `--surface-alt` bg, 14px corner radius, 14px padding |
| Time | `caption`, `--text-secondary` |
| Share indicator | person.2.fill icon, `--accent` @ 80% opacity |
| Intensity badge | colored pill (see IntensityBadge below) |
| Body parts + sensations | Per-part rows: **part name** (`subheadline` bold `--accent`) + sensations (`subheadline` `--text-secondary`) |
| Emotion chips | FlowLayout, capsule, category color @ 15% bg, category color text, `caption` |
| AI preview | sparkle icon + serif text, 3 lines max, chevron right |
| Note preview | pencil icon + text, 2 lines max |
| Tap action | opens CheckInDetailView sheet |

## IntensityBadge
- Capsule shape, `caption` font, bold
- Color by intensity: 1-3 yellow, 4-6 orange, 7-8 accent, 9-10 red
- Shows number + label (e.g. "7 中等")

## Chip (reused everywhere)
- Capsule shape, full border-radius
- Horizontal padding: 10-14px, vertical: 4-8px
- Font: `caption` or `subheadline` depending on context
- States: unselected (tint bg + tint text) / selected (solid bg + white text)

## Emotion Popover (long-press on emotion chip during check-in)
- Width: 280px, max-height: 300px, scrollable
- 16px padding, `--surface` bg, 12px corner radius, drop shadow
- Header: emoji + nameZh (headline) + 5-bar intensity indicator
- Body: description in Instrument Serif
- Similar emotions: name buttons (accent) + difference text (secondary)
- Bottom: "深入了解这个情绪" button → dismisses popover, opens full dictionary sheet

---

# Data Files

| File | Size | Purpose | Loaded |
|------|------|---------|--------|
| `emotion_config.json` | ~30KB | Body parts, sensations map, 9 categories with 79 emotions (id, nameZh, nameEn, emoji, intensity, descriptionText, similarTo, differs) | At app launch, synchronously |
| `dictionary.json` | ~285KB | Rich reference: 79 emotions + 65 sensations + 24 body parts with deep psychological content | On demand, when user opens 觉察词典 |

Both files are bundled with the app. No remote fetching needed.

---

## Anti-patterns

Never do these in Cathier UI:
- Gradient backgrounds or gradient buttons
- Reintroducing a secondary accent (e.g. sage). The palette is intentionally single-accent; reach for the existing accent or warm neutrals.
- Bouncy spring animations
- Dense icon grids (3-column feature layouts)
- Pure white (#FFFFFF) as the screen background — use cathierBackground (#F7F5F1) for full-screen backgrounds
- SF Pro for moments that should feel like journal entries — that's what Instrument Serif is for
- Generic stock imagery or decorative blobs

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-03-27 | Initial design system created | /design-consultation based on competitive research + product context |
| 2026-03-27 | Terracotta (#C4614A) as primary accent | No emotion app in category uses warm earthy red. Distinctive in App Store screenshots. Evokes physical/body presence, appropriate for body scan feature. |
| 2026-03-27 | Updated accent to bright orange (#F2700A) | Terracotta read too dark and heavy in practice. Bright orange (#F2700A) is vivid and energetic — keeps the warm identity while actually reading as a strong accent color. Dark mode uses #F5861A. |
| 2026-03-27 | Instrument Serif for AI reflection text | Every competitor uses clean sans throughout. Serif for reflection moments creates "journal" personality that is genuinely different. |
| 2026-03-27 | Warm off-white (#F7F5F1) background | Makes the app feel analog and physical — reinforces body-awareness theme. Deliberate departure from default iOS pure white. |
| 2026-03-27 | No spring animations | The check-in flow should feel like a quiet ritual. Bouncy motion undermines the calm, deliberate feel of emotion awareness practice. |
| 2026-03-27 | Sage (#6B8F71) as secondary accent for friend/positive states | Keeps terracotta focused as the primary brand signal. Sage = growth, connection, calm. |
| 2026-04-07 | Emotion popover on long-press | In-context learning without leaving the check-in flow. Quick preview with "深入了解" link to full detail. |
| 2026-04-09 | Body part + sensation grouped display | Show body part name (bold accent) followed by its sensations (secondary) on each line. No truncation. Replaces flat joined string. |
| 2026-04-10 | 觉察词典 as 3-tab dictionary | Single entry point for emotions (79), sensations (65), and body parts (24). Segmented picker, not separate screens. Extensible for future content. |
| 2026-04-10 | Separate dictionary.json from emotion_config.json | Keep emotion_config.json small (~30KB) for fast app launch. dictionary.json (~285KB) loaded on demand for the explorer. |
| 2026-04-10 | Per-person card tint in friend feed | 5-color warm palette deterministically assigned by CloudKit record hash. Visually distinguishes friends without requiring avatars. |
| 2026-05-05 | Retired sage as secondary accent — single-accent system | Two brand colors fragmented the visual identity. Friend / growth / positive states now share the orange accent. Asset catalog still defines `cathierSage` for backward-compat but no view code references it. |
