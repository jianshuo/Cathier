# Cathier — 情绪感知训练

An iOS app for emotion awareness and body-mind check-ins, with AI-assisted reflection, a rich awareness dictionary, and optional friend sharing.

## Features

### Core Check-in Flow (3 steps)
- **Body Scan** — select body parts, choose sensations per part, describe trigger events, rate intensity (1–10)
- **Emotion Labeling** — browse 9 categories with 80+ emotion words, long-press for quick definitions, add custom emotions
- **AI Reflection** — personalized feedback from Claude/Qwen; includes micro-exercise suggestions for breathing and grounding

### Daily Journal
- **Daily mood** selector (5 moods) + gains/learnings free-text
- One entry per day, optionally shared with friends

### Pattern Insights
- On-demand AI analysis of your emotional history (requires 7+ check-ins)
- Four focus modes: Stress Triggers / Growth / Body Signals / Surprise Me
- Intensity chart (Swift Charts) + narrative insights in Instrument Serif
- Insight history with date, focus mode, and check-in count

### 觉察词典 (Awareness Dictionary)
- **Emotions** (79 entries) — deep psychological profiles: origin, experience, embodiment, imagery, developmental stage, formative events, personality impact, transformation, literary reference, similar emotions
- **Body Sensations** (65 entries) — how it feels, common locations, related emotions, what the body is saying, self-care suggestions, intensity spectrum
- **Body Parts** (24 entries) — how to locate, common sensations, emotional connection, awareness practice, cultural meaning
- All content in Chinese, designed as a reference companion for the check-in flow

### Friend Sharing
- CloudKit-based social features with invite codes
- Three privacy tiers: Category only / Emotions / Full detail
- Friend feed with merged check-ins and journals
- Emoji reactions on friend check-ins
- Per-person card tint palette for visual distinction

### Settings & Personalization
- **Language** — Chinese / English / Japanese
- **Reminders** — configurable daily notification times
- **Context Brief** — "About You" text injected into AI pattern analysis for personalized insights
- **Awareness Dictionary** — browse all emotions, sensations, and body parts
- Milestone nudge at 30 check-ins encouraging first pattern analysis

## Tech Stack

- **SwiftUI** + **SwiftData** (iOS 17+)
- **CloudKit** (public database for friend features)
- **Anthropic Claude / Qwen API** (user-supplied key, stored in UserDefaults)
- **Swift Charts** (intensity visualization)
- Xcode 26 / iOS 26.2 deployment target
- Version 1.8

## Project Structure

```
Cathier/
├── CathierApp.swift              — App entry, deep link handler, milestone nudge
├── ContentView.swift             — TabView: 此刻 / 日记 / 好友 / 设置
├── DesignSystem.swift            — Instrument Serif font extension
├── emotion_config.json           — Compact config (body parts, sensations, 9 categories, 79 emotions)
├── dictionary.json               — Rich reference (79 emotions + 65 sensations + 24 body parts)
├── Models/
│   ├── CheckIn.swift             — @Model SwiftData entity
│   ├── DailyJournal.swift        — @Model daily mood + gains
│   ├── EmotionData.swift         — Emotion/category structs, lookup helpers
│   ├── UserProfile.swift         — CloudKit user profile
│   ├── FriendCheckIn.swift       — Shared check-in + PrivacyTier enum
│   ├── FriendRecord.swift        — Invite + Friendship records
│   ├── ReactionRecord.swift      — Emoji reactions
│   └── AIProvider.swift          — AI provider abstraction
├── Services/
│   ├── ClaudeService.swift       — AI feedback + pattern insights
│   ├── CloudKitService.swift     — CloudKit public DB operations
│   ├── ConfigService.swift       — Loads emotion_config.json
│   ├── DictionaryService.swift   — Loads dictionary.json (emotions + sensations + body parts)
│   ├── NotificationService.swift — Local notification scheduling
│   └── GitHubService.swift       — Feedback submission
├── ViewModels/
│   ├── CheckInViewModel.swift    — 3-step flow state
│   ├── FriendViewModel.swift     — Friends, sharing, reactions
│   └── InsightsViewModel.swift   — Pattern analysis state
├── Views/
│   ├── TodayView.swift           — Home dashboard
│   ├── JournalView.swift         — Check-in history by date
│   ├── InsightsView.swift        — Pattern insights sheet
│   ├── EmotionExplorerView.swift — 3-tab dictionary (emotions/sensations/body parts)
│   ├── SettingsView.swift        — Preferences
│   ├── DailyJournalEntryView.swift — Journal editor
│   ├── AboutView.swift / FeedbackView.swift
│   ├── CheckIn/                  — BodyScanView, EmotionLabelView, AIFeedbackView, MicroExerciseView, CheckInFlowView
│   ├── Friend/                   — FriendFeedView, FriendSetupView, FriendManageView, InviteView
│   └── Components/               — CheckInCard, CheckInDetailView, DailyJournalCard, EmotionPopoverView, MarkdownText
└── Localization/
    ├── LanguageManager.swift     — Language switching
    └── Strings.swift             — All UI strings (zh/en/ja)
```

## Getting Started

### Prerequisites

- Xcode 16+
- An Apple Developer account (for CloudKit)
- An [Anthropic API key](https://console.anthropic.com/) (optional — required for AI features)

### Setup

1. Clone the repo
   ```bash
   git clone https://github.com/jianshuo/Cathier.git
   ```

2. Open `Cathier.xcodeproj` in Xcode

3. In **Signing & Capabilities**, change the Team and Bundle Identifier to your own

4. Create a CloudKit container `iCloud.<your-bundle-id>` in the [Apple Developer portal](https://developer.apple.com/account/)

5. Update `CloudKitService.swift` with your container identifier:
   ```swift
   let container = CKContainer(identifier: "iCloud.<your-bundle-id>")
   ```

6. In the CloudKit Dashboard, create record types in the **Public Database**:
   - `UserProfile` — `displayName` (String), `avatarEmoji` (String), `createdAt` (Date)
   - `InviteCode` — `inviteCode` (String), `fromProfileRef` (Reference), `createdAt` (Date), `expiresAt` (Date)
   - `Friendship` — `initiatorRef` (Reference), `accepterRef` (Reference), `inviteCode` (String), `createdAt` (Date)
   - `SharedCheckIn` — `ownerRef` (Reference), `date` (Date), `emotions` (List<String>), `bodyParts` (List<String>), `sensations` (List<String>), `intensity` (Int64), `aiFeedback` (String), `note` (String), `privacyTier` (String)

7. Build and run on a simulator or device

8. Enter your Anthropic API key in the **Settings** tab to enable AI features

9. Optionally fill in the **About You** field in Settings to give Claude context for personalized pattern insights

## Privacy

- Check-in data is stored **locally on device** (SwiftData) and never sent to our servers
- Emotion/body data is sent to **Anthropic** only to generate AI feedback and pattern insights (stateless, no history stored server-side)
- The optional "About You" context brief is stored **locally** in UserDefaults and is only included in pattern analysis prompts
- Pattern insight history is stored **locally** in UserDefaults
- Friend features use **Apple CloudKit** — data is governed by Apple's privacy policy
- No advertising, analytics SDKs, or tracking of any kind

See [PRIVACY_POLICY.md](./PRIVACY_POLICY.md) for the full privacy policy.

## License

MIT License — see [LICENSE](./LICENSE)
