# App Store Submission Guide — Cathier

**情绪感知训练 iOS App**

This guide covers every step required to submit Cathier to the Apple App Store, from prerequisites through post-review. Steps are ordered chronologically; complete them in sequence.

---

## Section 1: Prerequisites Checklist

Complete all items before touching Xcode or App Store Connect.

### Apple Developer Program

- [ ] Enrolled in the Apple Developer Program at https://developer.apple.com ($99 USD/year)
- [ ] Enrollment shows status **Active** in your developer account
- [ ] You have accepted the latest Apple Developer Program License Agreement in your account

### Bundle ID

- [ ] Bundle ID created in Apple Developer portal: **Identifiers** → **+** → **App IDs** → **App**
  - Bundle ID: `com.wangjianshuo.Cathier` (or your actual reverse-domain ID)
  - Description: `Cathier`
  - Capabilities required: **iCloud** (check it now; you will configure it further in Section 6)

### Certificates

- [ ] **Apple Distribution Certificate** created and installed in Keychain
  - Developer portal → Certificates → + → Apple Distribution
  - Download the `.cer`, double-click to install
- [ ] Alternatively, use **Automatic Signing** in Xcode (recommended for individual developers)

### Provisioning Profile

- [ ] **App Store Distribution Profile** created in Developer portal → Profiles → +
  - Type: App Store Connect
  - App ID: select `com.wangjianshuo.Cathier`
  - Certificate: select your Distribution certificate
- [ ] Alternatively, Xcode Automatic Signing handles this when you select "Distribution" destination

### CloudKit Container (Prerequisite)

- [ ] Container `iCloud.com.wangjianshuo.Cathier` created in Developer portal (see Section 6 for full setup)

---

## Section 2: Xcode Preparation

### Version and Build Numbers

Open the project in Xcode. Select the `Cathier` target → **General** tab.

- **Version (CFBundleShortVersionString):** Set to `1.0` for your first submission
  - Format: `MAJOR.MINOR` or `MAJOR.MINOR.PATCH` (e.g., `1.0.0`)
  - This is the user-visible version shown on the App Store
- **Build (CFBundleVersion):** Set to `1`
  - Increment by 1 for every build you upload to App Store Connect (you can never reuse a build number for the same version)

### Deployment Target

- Verify **Minimum Deployments** is set appropriately. Cathier uses SwiftData (@Model) which requires iOS 17+. Recommended: **iOS 17.0** (this maximizes audience while maintaining SwiftData compatibility)

### Signing & Capabilities Verification

Select the `Cathier` target → **Signing & Capabilities** tab:

- [ ] **Team:** Your developer account selected
- [ ] **Bundle Identifier:** `com.wangjianshuo.Cathier` (exact match with Developer portal)
- [ ] **Automatically manage signing:** Checked (recommended) OR manual signing with Distribution profile
- [ ] **iCloud** capability present:
  - [ ] **CloudKit** checkbox is checked
  - [ ] Container `iCloud.com.wangjianshuo.Cathier` listed and checked
- [ ] **Push Notifications** capability: Add if you implemented rich push notifications for reminders (UNUserNotificationCenter with local notifications does NOT require this capability; only remote/APNs push does)
- [ ] **URL Types** configured:
  - Select the `Cathier` target → **Info** tab → **URL Types** → **+**
  - URL Schemes: `cathier`
  - Identifier: `com.wangjianshuo.Cathier`
  - This enables `cathier://invite?code=XXXXXXXX` deep links to work

### Info.plist Entries to Verify

In `Cathier/Info.plist`, confirm:

- `NSUserNotificationsUsageDescription` — Required if you request notification permission
  - Suggested value: `"Cathier will send you gentle reminders to check in with yourself."`
- No `NSLocationWhenInUseUsageDescription` or other unnecessary permission keys (do not request permissions you don't use)

### Build for Distribution (Archive)

1. Connect no device, or select **Any iOS Device (arm64)** as destination
2. Menu: **Product → Archive**
3. Wait for the archive to complete — it appears in the Xcode Organizer window
4. Verify: no build errors, no critical warnings (warnings are OK; errors block submission)
5. In Organizer, select your new archive → **Validate App** first before distributing
   - Fix any validation errors before proceeding

---

## Section 3: App Store Connect Setup

### Create the App

1. Go to https://appstoreconnect.apple.com
2. **My Apps → +** → **New App**
3. Fill in the form:
   - **Platforms:** iOS
   - **Name:** `Cathier` (this is the App Store display name — max 30 characters)
   - **Primary Language:** Simplified Chinese (or English if your primary market is English)
   - **Bundle ID:** Select `com.wangjianshuo.Cathier` (must match exactly)
   - **SKU:** A unique internal identifier, not visible to users. Example: `cathier-ios-v1`
   - **User Access:** Full Access (unless you have a team)
4. Click **Create**

### App Name and Subtitle

- **Name:** `Cathier`
- **Subtitle** (optional, max 30 characters): `情绪感知训练` or `Emotion Awareness Training`
  - The subtitle appears below the app name in search results. Keep it descriptive and keyword-rich.

### Categories

- **Primary Category:** Health & Fitness
- **Secondary Category:** Lifestyle

These are the most appropriate categories. Health & Fitness is where users searching for wellness tools look; Lifestyle covers the journaling/self-reflection angle.

### Age Rating

In App Store Connect → your app → **Age Rating**, fill in the questionnaire:

| Question | Answer | Rationale |
|---|---|---|
| Cartoon or Fantasy Violence | None | No violence |
| Realistic Violence | None | No violence |
| Sexual Content or Nudity | None | No sexual content |
| Profanity or Crude Humor | None | No profanity |
| Medical/Treatment Information | Infrequent/Mild | AI-generated wellness responses |
| Alcohol, Tobacco, or Drug Use | None | No such content |
| Horror/Fear Themes | None | No such content |
| Mature/Suggestive Themes | None | No such content |
| Gambling | None | No gambling |
| Unrestricted Web Access | None | No web browser |
| User Generated Content | No | CloudKit shared check-ins are user-controlled and only visible to confirmed friends |

**Expected Rating: 4+**

Note: If Apple considers the AI-generated content as "Medical/Treatment Information" at a higher threshold, you may receive a **12+** rating. Either rating is acceptable and will not prevent publication.

---

## Section 4: App Metadata

### App Description

Below are templates for both English and Chinese. Customize the bracketed sections.

**English Description (max 4,000 characters):**

```
Cathier helps you develop a deeper connection with your emotional life through gentle, science-informed body scan check-ins.

HOW IT WORKS

1. Body Scan — Tap where you feel something in your body right now. Chest? Shoulders? Stomach? Noticing the physical location of emotion is the first step.

2. Sensation & Intensity — Choose words that describe what that physical feeling is like: tight, heavy, warm, buzzing. Rate its intensity from 1 to 10.

3. Emotion Recognition — Name the emotion using Cathier's structured emotion vocabulary, organized by category. No need to know the "right" word — just pick what feels closest.

4. AI Reflection — Optionally receive a short, empathetic response from Claude AI. Two to three sentences of gentle companionship, not advice or diagnosis. (Requires your own Anthropic API key.)

5. Journal — Look back at your history to notice patterns. When do you feel what, and where in your body?

FRIEND SHARING (OPTIONAL)

Connect with close friends and share check-ins at a privacy level you choose:
• Category only — share just the emotion type and intensity
• Emotion words — share the specific labels
• Full — share everything, including your note

All friend data is stored in Apple CloudKit, not our servers.

PRIVACY FIRST

• All check-ins are stored locally on your device — never on our servers
• No account required
• No advertising, no tracking, no analytics SDKs
• AI feature uses your own API key, which never leaves your device

Cathier is a personal wellness tool for emotional self-awareness. It is not a mental health treatment or clinical service.
```

**Chinese Description (Simplified):**

```
Cathier 帮助你通过温和的身体扫描签到，与自己的情绪建立更深的连接。

如何使用

1. 身体扫描 — 点击你现在有感觉的身体部位。胸口？肩膀？胃部？注意情绪在身体里的位置，是情绪感知的第一步。

2. 感受与强度 — 用词语描述那种身体感受：紧绷、沉重、温热、颤动。给强度打分，从 1 到 10。

3. 情绪识别 — 从 Cathier 的情绪词汇表中为这种情绪命名，按类别整理，超过 80 个情绪词供选择。不必找到"正确"答案，选最接近的就好。

4. AI 陪伴 — 可选择接收来自 Claude AI 的简短、温暖回应。两三句温和的陪伴，不是建议，也不是诊断。（需要你自己的 Anthropic API 密钥。）

5. 情绪日记 — 回顾历史记录，发现规律。什么时候有什么感受，身体里在哪里？

好友分享（可选）

与亲密好友连接，按你选择的隐私等级分享签到：
• 只分享情绪大类和强度
• 分享具体情绪词
• 完整分享，含个人笔记

所有好友数据存储在 Apple CloudKit，而非我们的服务器。

隐私优先

• 所有签到仅存储在你的设备本地，从不上传到我们的服务器
• 无需注册账号
• 无广告、无追踪、无数据分析 SDK
• AI 功能使用你自己的 API 密钥，密钥永远不会离开你的设备

Cathier 是一款用于情绪自我感知的个人健康工具，不是心理健康治疗或临床服务。
```

### Keywords

App Store keywords (max 100 characters total, comma-separated, no spaces after commas):

**English:** `emotion,mood,check-in,body scan,mindfulness,journal,AI,mental wellness,feelings,reflection`

**Chinese:** `情绪,心情,签到,身体扫描,正念,日记,AI,情绪感知,感受,反思`

Tips:
- Do not repeat words already in your app name or subtitle
- Focus on search terms users would actually type
- Mix emotional wellness terms with feature terms (body scan, AI)

### What's New (First Version)

```
Welcome to Cathier!

This is the first release of Cathier — a body-first emotion check-in app.

• 3-step body scan → emotion labeling → AI reflection flow
• 80+ emotion words organized by category
• Optional friend sharing with granular privacy tiers
• Reminder notifications at times you choose
• All data stored locally on your device
```

Chinese:
```
欢迎使用 Cathier！

这是 Cathier 的首次发布——一款以身体感知为起点的情绪签到应用。

• 三步流程：身体扫描 → 情绪标注 → AI 陪伴
• 超过 80 个按类别整理的情绪词
• 可选好友分享功能，支持精细隐私等级控制
• 自定义提醒通知时间
• 所有数据仅存储在你的设备本地
```

### Support and Marketing URLs

- **Support URL:** [YOUR_SUPPORT_URL] — Required. Minimum: a public page with your contact email. Options: GitHub repo, Notion page, simple website.
- **Marketing URL:** [YOUR_MARKETING_URL] — Optional but recommended. Can be the same as Support URL initially.
- **Privacy Policy URL:** [YOUR_PRIVACY_POLICY_URL] — **Required.** Must be a publicly accessible URL hosting your privacy policy. See Section 7.

### Screenshots

App Store Connect requires screenshots for the following sizes (you must provide at least the 6.9" and 5.5" sizes, or 6.9" alone if you select "Use 6.7-inch display" for older sizes):

| Required Sizes | Dimensions (portrait) | Device |
|---|---|---|
| 6.9-inch (required) | 1320 × 2868 px | iPhone 16 Pro Max |
| 6.5-inch | 1242 × 2688 px | iPhone 11 Pro Max (older required size) |
| 5.5-inch | 1242 × 2208 px | iPhone 8 Plus (older required size) |

**Screenshot suggestions for Cathier (5–10 screenshots):**

1. Today tab showing the "开始今日签到" prompt — establishes the core loop
2. Body scan step — visual of the body part selector
3. Emotion label step — showing the emotion wheel categories and words
4. AI feedback view — showing a warm response example (blur any real data)
5. Journal view — showing a list of past check-ins with emotion chips
6. Friend feed view — showing the shared check-in cards (use sample/dummy data)
7. Settings view — showing reminder configuration and API key field

Use Xcode Simulator to capture screenshots. For final submissions, use real device screenshots or use SimulatorKit for accurate rendering.

---

## Section 5: App Privacy (Nutrition Label)

This is the **most critical section** for Cathier. Apple reviewers scrutinize privacy labels carefully. Incorrect labels are a common rejection reason.

Navigate to App Store Connect → your app → **App Privacy**.

### Step 1: "Do you collect data from this app?"

Answer: **Yes**

(CloudKit stores display name, avatar, and shared check-ins linked to the CloudKit user identity. Even though most data is local, the Friend feature does collect data.)

### Step 2: Data Types — Complete Answers

For each data type below, follow the exact configuration:

---

**Health & Fitness → Other Health Data**

- Collected: **Yes**
- Usage: **App Functionality**
- Linked to Identity: **No** (for local check-ins; local SwiftData data is not linked to identity)
- Used for Tracking: **No**

Note: Emotion check-in data (body parts, sensations, emotion words, intensity) qualifies as "other health data" under Apple's definition. This data is stored locally and never linked to user identity unless the user explicitly shares it.

---

**User Content → Other User Content**

- Collected: **Yes**
- Usage: **App Functionality**
- Linked to Identity: **Yes** (display name and avatar emoji are stored in CloudKit linked to the user's CloudKit record ID)
- Used for Tracking: **No**

Covers: display name, avatar emoji, personal notes (when shared as "Full" tier), AI feedback text (when shared as "Full" tier).

---

**User Content → Other User Content (Shared Check-Ins)**

This may be combined with the above entry. When sharing check-ins, emotions/body data becomes linked to the CloudKit identity.

---

**Identifiers → User ID**

- Collected: **Yes**
- Usage: **App Functionality**
- Linked to Identity: **Yes**
- Used for Tracking: **No**

Covers: CloudKit User Record ID (the anonymous identifier assigned by Apple's CloudKit system, used to link friendship records and shared check-ins).

---

### Step 3: Data NOT Collected

Confirm you do NOT collect any of the following by selecting "No" or not adding them:

- Location
- Contacts
- Browsing History
- Search History
- Purchases
- Financial Info
- Sensitive Info (precise location, racial/ethnic, religious, political, sexual orientation, biometric)
- Device ID (IDFA or other cross-app identifiers)
- Diagnostics / Crash Data
- Advertising Data

---

### Step 4: Third-Party SDK Data Collection

You will be asked about data collected by third-party SDKs. Cathier has **no embedded third-party SDKs.** The Anthropic API is called over URLSession — this is a network call, not an SDK. Apple CloudKit is Apple's own framework. You can honestly answer that no third-party SDK collects data on your behalf.

---

### Step 5: Tracking

**"Does this app use data to track users?"** — Answer: **No**

Cathier does not use any data to track users across apps or websites owned by other companies, and does not share data with data brokers.

---

### Summary of Privacy Nutrition Label

Your completed label should show:

| Data Type | Linked to You | Used to Track You |
|---|---|---|
| Other Health Data | No | No |
| Other User Content | Yes | No |
| User ID | Yes | No |

---

## Section 6: CloudKit Setup

This must be completed before App Store submission, as CloudKit will fail without production schema deployment.

### Step 1: Create the Container (Developer Portal)

1. Go to https://developer.apple.com/account → **Certificates, Identifiers & Profiles → Identifiers**
2. Filter by **iCloud Containers**
3. Click **+** → **iCloud Containers**
4. Description: `Cathier`
5. Identifier: `iCloud.com.wangjianshuo.Cathier`
6. Click **Register**

### Step 2: Associate Container with App ID

1. In Identifiers, find your App ID (`com.wangjianshuo.Cathier`)
2. Click it → check **iCloud** → click **Configure**
3. Select `iCloud.com.wangjianshuo.Cathier` → click **Continue → Save**

### Step 3: Open CloudKit Dashboard

1. Go to https://icloud.developer.apple.com/dashboard
2. Select your container: `iCloud.com.wangjianshuo.Cathier`
3. You should see the Dashboard with Development and Production environments

### Step 4: Create Record Types in Development Environment

Make sure you are in the **Development** environment. Create the following record types:

---

**Record Type: `UserProfile`**

| Field Name | Type | Notes |
|---|---|---|
| `displayName` | String | User's chosen display name |
| `avatarEmoji` | String | Single emoji character |
| `createdAt` | Date/Time | Profile creation timestamp |

Queryable index: None required (looked up directly by record ID)

---

**Record Type: `InviteCode`**

| Field Name | Type | Notes |
|---|---|---|
| `inviteCode` | String | The 8-character invite code string |
| `fromProfileRef` | Reference | Reference to UserProfile of sender |
| `createdAt` | Date/Time | Creation timestamp |
| `expiresAt` | Date/Time | Expiry timestamp (suggested: 7 days from creation) |

Queryable index: `inviteCode` (String) — for direct record name lookup (record name = `invite_{code}`)

---

**Record Type: `Friendship`**

| Field Name | Type | Notes |
|---|---|---|
| `initiatorRef` | Reference | Reference to UserProfile of friend who sent invite |
| `accepterRef` | Reference | Reference to UserProfile of friend who accepted |
| `inviteCode` | String | The invite code used to establish this friendship |
| `createdAt` | Date/Time | When friendship was confirmed |

Queryable indexes: `initiatorRef` (Reference), `accepterRef` (Reference) — both required for the two-query pattern in `CloudKitService.fetchFriendships`

---

**Record Type: `SharedCheckIn`**

| Field Name | Type | Notes |
|---|---|---|
| `ownerRef` | Reference | Reference to UserProfile of check-in owner |
| `localID` | String | UUID string matching the local SwiftData CheckIn.id |
| `date` | Date/Time | Check-in date |
| `emotions` | List (String) | Array of emotion label strings |
| `bodyParts` | List (String) | Array of body part strings |
| `sensations` | List (String) | Array of sensation strings |
| `intensity` | Int(64) | Intensity score 1–10 |
| `aiFeedback` | String | AI feedback text (empty unless Full tier) |
| `note` | String | Personal note (empty unless Full tier) |
| `privacyTier` | String | One of: `category`, `emotions`, `full` |

Queryable index: `ownerRef` (Reference), `date` (Date/Time, Descending) — required for `fetchFriendCheckIns` query

---

### Step 5: Deploy Schema to Production

This is a required step before App Store submission. The Development schema is not used in production.

1. In CloudKit Dashboard, while in the **Development** environment
2. Click **Deploy Schema Changes to Production** (button in the top-right area of the Schema section)
3. Review the changes shown — confirm all four record types are listed
4. Click **Deploy**
5. Switch to the **Production** environment to verify the schema appears correctly

**Important:** If you add new fields to record types after deployment, you must re-deploy to Production. Plan your schema carefully before first deployment.

### Step 6: Verify in Xcode

In `CloudKitService.swift`, confirm line 8 uses the exact container identifier:

```swift
private let container = CKContainer(identifier: "iCloud.com.wangjianshuo.Cathier")
```

This must match exactly — case-sensitive — with the container registered in the Developer portal.

---

## Section 7: Privacy Policy Hosting

A publicly accessible privacy policy URL is **required** before you can submit your app for review.

### Hosting Options (Cheapest to Most Custom)

**Option A: GitHub Pages (Free, Recommended)**
1. Create a GitHub repository: `cathier-privacy`
2. Add your `PRIVACY_POLICY.md` file (or convert to HTML)
3. Enable GitHub Pages: Settings → Pages → Source: main branch
4. URL format: `https://[yourusername].github.io/cathier-privacy/`

**Option B: Notion Public Page (Free)**
1. Create a new Notion page and paste your privacy policy
2. Click Share → Publish to web
3. Copy the public URL

**Option C: Personal Website**
1. Upload `PRIVACY_POLICY.md` or an HTML version to any web host
2. Ensure the URL is publicly accessible without login

**Option D: GitHub Raw File**
1. Add `PRIVACY_POLICY.md` to your existing repo
2. URL format: `https://raw.githubusercontent.com/[user]/[repo]/main/PRIVACY_POLICY.md`
3. Note: Raw GitHub URLs are functional but not visually appealing for reviewers

### Add the URL to App Store Connect

1. App Store Connect → your app → **App Information**
2. **Privacy Policy URL:** Paste your hosted URL
3. This URL must resolve (return HTTP 200) when Apple's reviewer visits it

---

## Section 8: Submit for Review

### Upload the Build

1. In Xcode Organizer (Window → Organizer → Archives), select your archive
2. Click **Distribute App**
3. Select **App Store Connect** → **Next**
4. Select **Upload** → **Next**
5. Options:
   - Include bitcode: depends on your Xcode version (Xcode 14+ bitcode is disabled by default — leave as-is)
   - Strip Swift symbols: Yes (reduces binary size)
   - Include symbols: Yes (enables crash symbolication)
6. Click **Upload**
7. Wait for processing — App Store Connect will email you when the build is ready (usually 5–15 minutes)

### Prepare the Version in App Store Connect

1. App Store Connect → your app → **+** next to iOS App → **1.0** (or your version)
2. Under **Build**, click **+** and select your uploaded build
3. Fill in all required fields:
   - [ ] Version number
   - [ ] What's New text
   - [ ] Screenshots (all required sizes)
   - [ ] Description
   - [ ] Keywords
   - [ ] Support URL
   - [ ] Privacy Policy URL
   - [ ] App Privacy questionnaire (Section 5)
   - [ ] Age Rating
4. **Pricing and Availability:** Set to Free (or paid, per your business model)
5. **App Review Information:**
   - If the Friend feature requires setup to test: provide demo account instructions
   - Add a note: "AI feedback feature requires user's own Anthropic API key. For review purposes, this feature can be skipped — the app is fully functional without it."
   - Add your contact phone number for reviewer questions

### Submit

Click **Submit for Review**.

### Common Rejection Reasons to Avoid for Cathier

| Rejection Reason | How to Avoid |
|---|---|
| Guideline 5.1.1 — Privacy Policy missing or inaccessible | Host your privacy policy at a live URL and add it to App Store Connect before submitting |
| Guideline 5.1.2 — Data collected not accurately disclosed | Complete the App Privacy questionnaire accurately per Section 5 |
| Guideline 2.1 — App crashes or has bugs | Test on a real device, not just Simulator. Test the full check-in flow, including AI feedback error states. |
| Guideline 4.2 — Minimal functionality | Ensure the core loop (body scan → emotion → journal) works completely without the Friend or AI features |
| CloudKit entitlement issues | Ensure the iCloud capability is correctly configured and the provisioning profile includes CloudKit entitlement |
| Guideline 1.4 — Physical harms (for AI content) | The App Review Information note about AI not being medical advice helps. The in-app disclaimer in AIFeedbackView also helps. |
| Missing CloudKit schema in production | Deploy schema to Production before submitting (Section 6, Step 5) — otherwise reviewers testing the Friend feature will see errors |
| URL scheme not functioning | Verify `cathier://` URL type is registered in Info.plist / Xcode target settings |

---

## Section 9: Post-Submission

### Review Timeline

- **Standard review:** 24–48 hours for most apps (Apple's stated target is 50% reviewed within 24 hours, 90% within 48 hours)
- **First-time submissions:** May take slightly longer as reviewers examine the app more carefully
- **Holiday periods:** Can take 3–7 days — avoid submitting the week of major US holidays

### Responding to Reviewer Questions

If your app is flagged for review with questions, you will receive a message in App Store Connect's Resolution Center. Respond promptly (within 24 hours when possible).

---

**Sample Reviewer Question about AI Features:**

> *"Your app appears to use AI features. Please explain what data is sent to the AI service and how it is used."*

**Suggested Response:**

> Thank you for reviewing Cathier.
>
> The AI feedback feature in Cathier uses Anthropic's Claude API to generate short, empathetic responses after a user completes a body scan check-in.
>
> Data sent to Anthropic: selected body parts, selected sensation words, emotion intensity rating (numeric 1–10), and selected emotion labels. No personally identifiable information, no user account data, and no personal notes are sent.
>
> The user provides their own Anthropic API key, which is stored locally on their device in UserDefaults. Cathier does not have access to, store, or transmit the user's API key to any server we control.
>
> If the user has not entered an API key, no data is sent to Anthropic and the AI feedback step is skipped gracefully with an error message directing the user to Settings.
>
> This feature is entirely optional — the core app (body scan, emotion labeling, journal) functions completely without it.

---

**Sample Reviewer Question about CloudKit / Friend Feature:**

> *"Your app uses iCloud. What data is stored and who can access it?"*

**Suggested Response:**

> Cathier uses Apple CloudKit (Public Database) for the optional Friend feature only.
>
> Data stored in CloudKit:
> - User profiles: display name (chosen by user) and avatar emoji
> - Friendship records: linking two users who have confirmed a friend connection via invite code
> - Shared check-ins: emotion check-in data that users explicitly choose to share with confirmed friends
>
> All CloudKit data is stored in Apple's infrastructure. Shared check-ins are only visible to users who have established a confirmed friendship through the in-app invite system. Users control what they share and at what privacy level (emotion category only, emotion words, or full detail).
>
> The core check-in data (body scan, personal notes, AI feedback) is stored locally on the user's device using SwiftData and is never sent to CloudKit unless the user explicitly taps "Share with Friends" and selects a privacy tier.

---

**Sample Reviewer Question about Notification Permissions:**

> *"Your app requests notification permissions. What notifications does it send?"*

**Suggested Response:**

> Cathier requests notification permission solely to send the user their chosen check-in reminder notifications. These are local notifications (UNUserNotificationCenter) — not remote push notifications. The user configures the reminder times in the Settings tab, and Cathier schedules local notifications at those times with a gentle message encouraging a check-in. No notification is sent without the user explicitly setting a reminder time. Notification permission is entirely optional and the app is fully functional without it.

---

### After Approval

1. **Go Live:** Choose "Release this version" manually or set automatic release
2. **Monitor:** Check App Store Connect → App Analytics for early crash reports and user data
3. **Respond to Reviews:** Engage with early user reviews professionally
4. **CloudKit Dashboard:** Monitor record creation in the Production environment to verify the Friend feature is working
5. **Plan 1.0.1:** Address any issues found in the first week of production usage

---

*Last updated for Xcode 16 / iOS 18 App Store Connect workflow. App Store Connect UI may change slightly across Apple developer portal updates.*
