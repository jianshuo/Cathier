# Cathier — 情绪感知训练

An iOS app for emotion awareness and body-mind check-ins, with AI-assisted reflection and optional friend sharing.

## Features

- **Body Scan** — identify physical sensations and body areas holding tension
- **Emotion Labeling** — choose from 80+ emotion words across 9 categories
- **AI Companion** — receive personalized reflections powered by Claude (Anthropic), using your own API key
- **Pattern Insights** — on-demand analysis of your emotional history; choose a focus (stress triggers, growth, body signals, or surprise me) and Claude narrates 3-5 meaningful patterns across your last 30 check-ins
- **Journal** — review your check-in history grouped by day, with one-tap access to Pattern Insights
- **Friend Sharing** — share check-ins with friends at three privacy levels (category only / emotions / full) via CloudKit
- **Reminders** — set daily reminder times via local notifications; milestone nudge fires at 30 check-ins to encourage first pattern analysis

## Tech Stack

- **SwiftUI** + **SwiftData** (iOS 17+)
- **CloudKit** (public database for friend features)
- **Anthropic Claude API** (user-supplied API key, stored in UserDefaults)
- Xcode 26 / iOS 26.2 deployment target

## Getting Started

### Prerequisites

- Xcode 16+
- An Apple Developer account (for CloudKit)
- An [Anthropic API key](https://console.anthropic.com/) (optional — required for AI feedback feature)

### Setup

1. Clone the repo
   ```bash
   git clone https://github.com/jianshuo/Cathier.git
   ```

2. Open `Cathier.xcodeproj` in Xcode

3. In **Signing & Capabilities**, change the Team and Bundle Identifier to your own

4. Create a CloudKit container `iCloud.<your-bundle-id>` in the [Apple Developer portal](https://developer.apple.com/account/)

5. Update `CloudKitService.swift` line with your container identifier:
   ```swift
   let container = CKContainer(identifier: "iCloud.<your-bundle-id>")
   ```

6. In the CloudKit Dashboard, create the following record types in the **Public Database**:
   - `UserProfile` — `displayName` (String), `avatarEmoji` (String), `createdAt` (Date)
   - `InviteCode` — `inviteCode` (String), `fromProfileRef` (Reference), `createdAt` (Date), `expiresAt` (Date)
   - `Friendship` — `initiatorRef` (Reference), `accepterRef` (Reference), `inviteCode` (String), `createdAt` (Date)
   - `SharedCheckIn` — `ownerRef` (Reference), `date` (Date), `emotions` (List<String>), `bodyParts` (List<String>), `sensations` (List<String>), `intensity` (Int64), `aiFeedback` (String), `note` (String), `privacyTier` (String)

7. Build and run on a simulator or device

8. Enter your Anthropic API key in the **Settings** tab to enable AI feedback

9. Optionally fill in the **About You** field in Settings to give Claude context about your life situation, making pattern insights more personally relevant

## Privacy

- Check-in data is stored **locally on device** (SwiftData) and never sent to our servers
- Emotion/body data is sent to **Anthropic** only to generate AI feedback and pattern insights (stateless, no history stored server-side)
- The optional "About You" context brief is stored **locally** in UserDefaults and is only included in pattern analysis prompts — never sent independently
- Pattern insight history is stored **locally** in UserDefaults as a JSON array
- Friend features use **Apple CloudKit** — data is governed by Apple's privacy policy
- No advertising, analytics SDKs, or tracking of any kind

See [PRIVACY_POLICY.md](./PRIVACY_POLICY.md) for the full privacy policy.

## License

MIT License — see [LICENSE](./LICENSE)
