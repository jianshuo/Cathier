# TODOS

## WeChat Mini Program — iOS Feature Parity

The goal is to make the Mini Program look and function as close to the iOS app as possible. Below is the gap analysis and prioritized task list.

### Feature Parity Matrix

| Feature | iOS | Mini Program | Gap |
|---------|-----|-------------|-----|
| **Tab Bar** | 4 tabs (此刻/日记/好友/设置) | 3 tabs (此刻/日记/觉察词典) | Missing: 好友 tab; 设置 is not a tab (accessed via icon) |
| **Body Scan** | ✅ body parts + per-part sensations + trigger + intensity | ✅ implemented | Minor: verify sensation encoding matches iOS format |
| **Emotion Label** | ✅ 9 categories, long-press popover, custom emotion | ✅ 9 categories, detail modal | Gap: no long-press popover; emotion popover → dictionary detail link missing |
| **AI Feedback** | ✅ Claude/Qwen, micro-exercise, share options | ✅ Hunyuan | Gap: no micro-exercise suggestions; no share privacy tier picker |
| **Check-in Card** | Body parts grouped with sensations, emotion chips, AI preview | Flat display | Gap: body+sensation grouping (part name bold + sensations after) |
| **Check-in Detail** | Full-screen sheet with all fields + share options | ❌ Not implemented | Missing: tap card → detail view |
| **Daily Journal** | Mood selector (5 emoji) + gains text + share toggle | ❌ Not implemented | Missing entirely |
| **Pattern Insights** | 4 focus modes, intensity chart, AI narrative, history | ❌ Not implemented | Missing entirely |
| **Friend System** | CloudKit: invite, feed, privacy tiers, reactions | ❌ Not implemented | Missing entirely (lower priority for China market) |
| **觉察词典** | 3 tabs, emotion/sensation/body-part detail sheets | ✅ 3 tabs, detail modals | Gap: verify content matches iOS dictionary.json v3; detail sheet styling |
| **Settings** | Language, reminders, context brief, dictionary link, feedback, about | ⚠️ Partial | Gap: no language picker; reminder not wired; feedback stub; about is modal |
| **Emotion Popover** | Long-press emotion chip → popover with description + "深入了解" | ❌ Not implemented | Missing: long-press gesture on emotion chips in check-in flow |
| **Notifications** | Configurable reminder times, milestone nudge at 30 check-ins | ⚠️ Template placeholder | Gap: subscription template ID not configured |
| **Intensity Badge** | Color-coded pill (yellow/orange/red by level) | ⚠️ Basic | Gap: verify color coding matches iOS spec |
| **Body+Sensation Display** | Per-part grouping: **part** (bold accent) + sensations (secondary) | Flat text | Gap: cards show flat list, not grouped per body part |

---

### P0 — Must Fix (Visual & UX parity)

#### MP-01: Check-in card body+sensation grouped display
**What:** In today page and journal page, display body parts and sensations grouped per part: part name in bold accent color, followed by its sensations in secondary color. Match iOS CheckInCard layout.
**Reference:** DESIGN.md → Component Inventory → CheckInCard
**Files:** `pages/today/today.wxml`, `pages/journal/journal.wxml`, corresponding `.wxss`

#### MP-02: Check-in detail view
**What:** Tap a check-in card → navigate to a detail page showing all fields: date/time, intensity badge, body parts (grouped with sensations), emotions (colored chips), trigger event, full AI feedback (Instrument Serif), user note.
**Reference:** DESIGN.md → Check-in Flow → Step 3 summary card layout
**Files:** Create `pages/checkin-detail/` page

#### MP-03: Intensity badge color coding
**What:** Verify the intensity badge uses the iOS color scheme: 1-3 yellow, 4-6 orange, 7-8 accent (#F2700A), 9-10 red. Add intensity label text (e.g. "7 中等").
**Reference:** DESIGN.md → Component Inventory → IntensityBadge
**Files:** All pages that display intensity

#### MP-04: Emotion chip styling parity
**What:** Ensure emotion chips in check-in cards use per-category colors (not one flat color). Match the 9 category hex colors from DESIGN.md.
**Reference:** DESIGN.md → Emotion Category table (激情 #FF5933, 快乐 #FFBF00, etc.)
**Files:** `pages/today/`, `pages/journal/`

---

### P1 — Important Features Missing

#### MP-05: Daily Journal
**What:** Add daily journal feature: mood selector (5 emoji moods: 😄很开心 / 😊不错 / 😐还好 / 😔不太好 / 😢很难过) + gains/learnings text editor. One per day. Show on Today page below check-ins. Store in cloud DB `daily_journals` collection.
**Reference:** DESIGN.md → Daily Journal Design; Data Models → DailyJournal
**Files:** Create `pages/journal-entry/` page; update `pages/today/`

#### MP-06: Micro-exercise after AI feedback
**What:** After AI feedback loads in step 3, show a "试试觉察练习" button. Tapping opens a simple breathing or grounding exercise based on the user's selected body parts and sensations. Match iOS MicroExerciseView.
**Reference:** DESIGN.md → Micro-Exercise Design
**Files:** Create component or page for exercise; update `pages/ai-feedback/`

#### MP-07: Long-press emotion popover in check-in flow
**What:** During emotion labeling (step 2), long-press an emotion chip → show a bottom sheet with: emoji + name + intensity bar + description + similar emotions with differences + "深入了解" link to full dictionary entry.
**Reference:** DESIGN.md → Component Inventory → Emotion Popover (280px width, serif description)
**Files:** `pages/emotion-label/`

#### MP-08: Settings — wire reminders end-to-end
**What:** Configure actual WeChat subscription message template ID (replace `TEMPLATE_ID_PLACEHOLDER`). Wire the reminder toggle and time picker to actually schedule subscription messages via `subscribe-trigger` cloud function. Add milestone nudge at 30 check-ins.
**Reference:** iOS NotificationService behavior
**Files:** `miniprogram/utils/subscribe.js`, `pages/settings/settings.js`, `cloudfunctions/subscribe-trigger/`

---

### P2 — Feature Enrichment

#### MP-09: Pattern Insights
**What:** Add pattern insights feature accessible from journal page. Requirements:
- Minimum 7 check-ins to unlock
- 4 focus modes: 压力触发 / 成长 / 身体信号 / 随机探索
- Call AI (Hunyuan) with last 30 check-ins + focus mode prompt
- Display: intensity trend (could use wx-charts or simple canvas), AI narrative in Instrument Serif
- Store insight history in cloud DB
**Reference:** DESIGN.md → Pattern Insights
**Files:** Create `pages/insights/` page; update `pages/journal/` toolbar

#### MP-10: AI feedback share options (privacy tiers)
**What:** In step 3 (AI feedback), before saving, allow user to set share level:
- 不分享 (private, default)
- 仅类别 (category names only)
- 情绪 (full emotion labels + body parts)
- 完整 (everything including notes and AI)
This prepares for future friend sharing, and the field is already in the data model (`shareLevel`).
**Reference:** DESIGN.md → Privacy Tiers table
**Files:** `pages/ai-feedback/`

#### MP-11: Dictionary detail sheet styling parity
**What:** Verify dictionary detail modals match iOS EmotionDictionarySheet / SensationDictionarySheet / BodyPartDictionarySheet layouts exactly:
- Hero header: large emoji/icon + name (Instrument Serif) + English subtitle + intensity bar
- Section pattern: icon + label (caption semibold) + body (serif, 6pt line spacing)
- Literary/cultural quotes: italic serif, tinted background
- Chips for related items (sage for sensations, accent for emotions)
**Reference:** DESIGN.md → 觉察词典 detail sheet tables
**Files:** `pages/dictionary/dictionary.wxml` and `.wxss`

#### MP-12: Settings parity
**What:** Add missing settings features:
- Feedback button → navigate to feedback form or WeChat feedback API
- About → dedicated page (not modal) with version, privacy policy link, terms link
- Context brief → ensure "About You" text is injected into AI prompts (both per-session and pattern insights)
**Files:** `pages/settings/`

---

### P3 — Polish & Nice-to-Have

#### MP-13: Emotion categories — match iOS 9-category structure
**What:** Verify the mini program uses exactly the same 9 categories as iOS (激情/快乐/平静/爱与关怀/愤怒/恐惧/悲伤/羞愧/惊讶) with matching colors, icons, and emotion lists. The current mini program data may have fewer categories (7 reported).
**Files:** `miniprogram/data/emotions.js`

#### MP-14: Check-in flow step indicator
**What:** Ensure the step indicator at the top of the check-in flow matches iOS: 3 horizontal segments, 4px height, `--accent` fill for completed/current steps. Not dots, not numbers.
**Files:** All check-in step pages (`body-scan`, `emotion-label`, `ai-feedback`)

#### MP-15: Add 4th tab (设置) or keep as icon
**What:** Decide: iOS has 4 tabs (此刻/日记/好友/设置). Mini program has 3 (此刻/日记/觉察词典). Since friend system is not planned for mini program, either:
- Option A: Add 设置 as 4th tab, keep 觉察词典 accessible from settings
- Option B: Keep current 3-tab layout with settings accessible from today page icon
**Decision needed from product owner.**

#### MP-16: Instrument Serif font for reflection moments
**What:** Verify Instrument Serif is loaded and used for: AI feedback body text, pattern insights narrative, dictionary detail body text, dictionary hero names. If not loadable in WeChat (font licensing), use a similar serif fallback (e.g. 思源宋体 / Noto Serif SC).
**Files:** `app.wxss` font-face declarations

#### MP-17: WeChat share card
**What:** `share.js` has `getCheckInShareData()` defined but not wired to UI. Add share button on check-in detail page to generate WeChat share cards.
**Files:** `pages/checkin-detail/`, `miniprogram/utils/share.js`

---

## iOS App — Future Features

### Living Pattern Engine (Approach C)
**Priority:** P3
**What:** Compute emotion×trigger correlations and intensity×weekday patterns in pure Swift; feed computed results to Claude for narration. Updates after each new check-in rather than re-sending full history.
**Why:** Once the app has 30+ check-ins, native math finds patterns faster and cheaper than sending all history to Claude on every analysis tap.
**Depends on:** Approach B (pattern analysis via full history send) shipped and validated.

### Insights Sharing with Friends
**Priority:** P4
**What:** Decide if and how pattern insight narratives can be shared with friends via CloudKit.
**Why:** Shared long-term patterns could deepen the social layer.
**Depends on:** Approach B shipped; privacy model designed.

### WeChat Regulatory Research (AI Content Policy)
**Priority:** P1 (pre-implementation blocker)
**What:** Research WeChat's current platform policy on AI-generated emotional/psychological content before finalizing the AI feedback prompt tone.
**Why:** WeChat has rejected 工具-categorized apps when AI responses read as emotional counseling.
**Effort:** S (human: ~half day)
**Depends on:** Nothing. Do this BEFORE implementation.

---

## Completed

- ✅ Context Brief for Claude (iOS)
- ✅ Emotion Dictionary / 觉察词典 (iOS + Mini Program)
- ✅ Body+sensation grouped display in cards (iOS)
- ✅ Per-person card tint in friend feed (iOS)
- ✅ Emotion popover on long-press (iOS)
- ✅ Daily Journal (iOS)
- ✅ Micro-exercises (iOS)
- ✅ Pattern Insights with 4 focus modes (iOS)
