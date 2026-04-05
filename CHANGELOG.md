# Cathier — Feature Changelog

## v1.3 — Multi-Language, Design System & Social Feed

### Features
- **15 Languages supported** — added 12 new languages (on top of original 3) for broad international reach
- **Warm color design system** — replaced all cool/blue tones with warm palette (terracotta, sage, amber) app-wide; Instrument Serif font bundled and registered
- **Qwen AI — free for all users** — removed IAP and API key input; all users get free Qwen access by default
- **Friend feed richer cards** — emotions, body parts, AI snippet always visible; per-person card tint via 5-color warm palette keyed by profile ID hash
- **Persistent share tier** — last chosen share level (none/partial/full) remembered across check-ins; default set to full
- **Friend AI detail view** — tap a friend's feed card to see their AI reflection in full
- **Add Friend merged into feed** — add-friend button integrated directly into the friend activity feed (no separate screen)
- **Show all users by default** in Add Friend search

### Design System
- Color tokens via asset catalog (`cathierAccent`, `cathierAccentLight`, warm palette)
- `Font` extension for Instrument Serif (regular + italic)
- `DesignSystem.swift` with `UIColor`-backed tokens
- TodayView: terracotta gradient hero, sage journal icon
- AIFeedbackView: warm color tokens + Instrument Serif for reflection text
- InsightsView: narrative uses Instrument Serif + `cathierAccentLight` background
- FriendFeedView: sage for friend context, fixed blue mood chip

---

## v1.2 — Pattern Insights, Social Sharing & Subscriptions

### Features
- **On-Demand Pattern Analysis** — analyze check-in history for recurring emotional patterns; powered by `claude-sonnet-4-6`; focus mode picker; intensity chart (Swift Charts); history cards persisted in UserDefaults
- **Context Brief ("About You")** — user-written context injected into pattern prompts for personalized insights
- **Insight staleness signal** — insight flagged stale after 5 new check-ins since last analysis
- **Share AI feedback with friends** — option to share AI reflection with friends at check-in time
- **Own shared check-ins appear in friends feed** — you see your own shared entries alongside friends'
- **Per-check-in share settings** — change share level for individual entries in detail view
- **Daily Mood & Gains journal module** — dedicated journal tab with mood summary and gains tracking
- **Multi-provider AI support** — `AIProvider` enum; `SubscriptionManager` for managed access
- **About page in Settings** — lists Cathy as app owner

### UX Improvements
- Milestone nudge: one-time local notification at 30 check-ins
- Skip button saves directly without triggering AI feedback
- Absolute timestamps for friend check-ins (instead of relative)
- Dynamic version number from Bundle in Settings

---

## v1.1 — Friends, Triggers & Body Sensations

### Features
- **Friend system** — CloudKit-based friend graph; invite via deep link (`cathier://invite?code=`); accept invite code; friend list with swipe-to-remove
- **Friend activity feed** — see friends' shared check-ins; loading / unavailable / setup / home states
- **Trigger event/scene field** — add a trigger context to each body scan check-in
- **Per-body-part sensation selection** — select sensations for each individual body part
- **Emoji icons on emotion tags**
- **User feedback mechanism in Settings** — submit feedback via GitHub PAT-authenticated API

### Internationalization
- Japanese and English language support with in-app language switcher
- String migration to `.lproj` catalogs

---

## v1.0 — Core Check-In Experience

### Features
- **3-step check-in flow** — body scan → emotion label → AI feedback
- **AI somatic therapist feedback** — per-session reflection via `claude-haiku-4-5`; history context included in prompt; rendered as Markdown
- **18 → 23 body parts** (chakra-aligned, breath, face, spine, limbs)
- **80+ emotion words** across 9 categories with valence mapping
- **Check-in history** — `JournalView` lists past check-ins; tap card to read full AI feedback (`CheckInDetailView`)
- **CloudKit sync** — SwiftData `CheckIn` records synced via CloudKit private DB
- **Remote emotion config** — emotion data loaded from JSON, updatable from GitHub
- **Reminder notifications** — configurable reminder times via `NotificationService`
- **Insight nudge** — local notification prompting pattern analysis after milestone

---

## CI / Infra

- GitHub Actions: TestFlight upload, App Store review submission, auto-merge Claude PRs
- Fastlane: `reject_pending_version_if_needed` guard before release, `deliver` handles review submission
- Xcode 26.2 / iOS 26.2 deployment target
- ASC API Key via base64-encoded env var; build numbers offset by run attempt
