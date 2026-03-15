# Privacy Policy / 隐私政策

**Cathier — 情绪感知训练**

---

## English

**Effective Date:** [EFFECTIVE_DATE]
**Last Updated:** [LAST_UPDATED]

### 1. Introduction

Cathier ("we," "our," or "the app") is a personal emotion check-in and awareness training application. We take your privacy seriously. This Privacy Policy explains what data Cathier collects, how it is used, where it is stored, and your rights regarding that data.

By using Cathier, you agree to the practices described in this policy.

### 2. Summary: Our Core Privacy Commitment

- **Most of your data never leaves your device.** Emotion check-ins, body scan data, and personal notes are stored locally on your iPhone using Apple's SwiftData framework.
- **We do not operate servers** that store your personal data.
- **We do not sell, rent, or share your data** with advertisers or data brokers.
- **We do not embed advertising SDKs, analytics SDKs, or tracking technologies.**
- **You control your AI API key.** If you choose to use the AI feedback feature, you provide and manage your own Anthropic API key.

### 3. Data We Collect and How It Is Used

#### 3.1 Local Data (Stored on Your Device Only)

The following data is stored exclusively on your device using Apple's SwiftData framework. It is **not** transmitted to Cathier's servers (we have none), and it is **not** synchronized to iCloud by default.

| Data Type | Description | Storage |
|---|---|---|
| Body scan selections | Body parts you tap during a check-in (e.g., chest, shoulders) | Local device (SwiftData) |
| Physical sensations | Sensation words you select (e.g., tight, warm, heavy) | Local device (SwiftData) |
| Emotion labels | Emotion words you select from the emotion wheel | Local device (SwiftData) |
| Emotion intensity | A numeric intensity rating (1–10) | Local device (SwiftData) |
| Personal notes | Free-text notes you write after a check-in | Local device (SwiftData) |
| AI feedback text | The AI-generated response saved with each check-in | Local device (SwiftData) |
| Reminder preferences | Your chosen notification times | Local device (UserDefaults) |
| Claude API key | Your personal Anthropic API key | Local device (UserDefaults) |

**Deleting the app removes all locally stored data permanently.**

#### 3.2 Data Sent to Anthropic (Claude AI) — AI Feedback Feature

The AI feedback feature is **optional**. To use it, you must obtain and enter your own API key from Anthropic (api.anthropic.com).

When you request AI feedback after a check-in, the following data is sent directly from your device to Anthropic's API endpoint (`api.anthropic.com`):

- Selected body parts
- Selected sensation words
- Emotion intensity rating
- Selected emotion labels

**What is NOT sent to Anthropic:**
- Your personal notes
- Your name or identity
- Any persistent user identifier
- Your device's location

Your API key is stored only on your device. Cathier does not transmit your API key to any server we control.

Anthropic processes this data according to its own privacy policy. We encourage you to review Anthropic's Privacy Policy at: https://www.anthropic.com/privacy

#### 3.3 Data Stored in Apple CloudKit — Friend Feature

The Friend feature is **optional**. It uses Apple's CloudKit public database (`iCloud.com.wangjianshuo.Cathier`) to enable friend connections and voluntary check-in sharing.

When you use the Friend feature, the following data is stored in Apple's CloudKit:

| Data Type | Description | Visibility |
|---|---|---|
| Display name | The name you choose for your friend profile | Visible to confirmed friends |
| Avatar emoji | The emoji you choose for your avatar | Visible to confirmed friends |
| CloudKit User Record ID | An anonymous identifier assigned by Apple's CloudKit system | Used internally for friendship linking; not a name or email |
| Invite codes | Time-limited codes used to establish friend connections | Temporary; deleted after use |
| Friendship records | Records indicating two users are connected | Visible only to both parties |
| Shared check-ins | Check-in data you explicitly choose to share, at a privacy tier you select | Visible to confirmed friends only |

**Privacy Tiers for Shared Check-Ins:**

You choose how much detail to share each time:
- **Category only:** Friends see only the emotion category and intensity level
- **Emotion words:** Friends see specific emotion labels
- **Full:** Friends see all check-in data including your personal note and AI feedback

Personal notes and AI feedback are **never** included in shared check-ins unless you explicitly select "Full" sharing.

Apple stores and processes CloudKit data according to Apple's Privacy Policy: https://www.apple.com/legal/privacy/

### 4. Data We Do NOT Collect

Cathier does not collect any of the following:

- Precise or approximate location data
- Contacts or address book data
- Device identifiers used for cross-app tracking (no IDFA, no fingerprinting)
- Financial or payment information
- Browsing history
- Health data from HealthKit
- Camera or microphone data
- Crash analytics or performance diagnostics via third-party SDKs
- Any data for advertising purposes

### 5. Third-Party Services

Cathier uses exactly two third-party services:

| Service | Purpose | Data Shared | Their Privacy Policy |
|---|---|---|---|
| Anthropic (Claude API) | Generate empathetic AI feedback after check-ins | Body parts, sensations, emotion words, intensity (no identity data) | https://www.anthropic.com/privacy |
| Apple CloudKit | Store friend profiles and voluntarily shared check-ins | Display name, avatar emoji, CloudKit user ID, shared check-in data | https://www.apple.com/legal/privacy/ |

There are no advertising networks, analytics platforms, or tracking SDKs integrated into Cathier.

### 6. Children's Privacy

Cathier is intended for users aged **13 and older**. We do not knowingly collect personal information from children under 13. If you are a parent or guardian and believe your child under 13 has used the Friend feature in Cathier and stored information in CloudKit, please contact us at [USER_EMAIL] and we will assist with data deletion.

### 7. Your Rights

Depending on your jurisdiction, you may have the following rights:

#### 7.1 Access
You can view all locally stored check-in data directly within the app (Journal tab). You can view your friend profile and shared check-ins within the Friend tab.

#### 7.2 Deletion

- **Local data:** Delete the app to remove all locally stored data. You may also delete individual check-ins from the Journal view.
- **CloudKit friend profile and shared check-ins:** You can remove friends and delete shared check-ins from within the app. To delete your entire friend profile and all associated CloudKit records, contact us at [USER_EMAIL] with the subject "CloudKit Data Deletion Request."
- **AI requests:** Individual API calls to Anthropic are stateless — no history is retained between sessions. Refer to Anthropic's data retention policies for API usage data.

#### 7.3 Portability
Your local check-in data is stored in SwiftData on your device. You may export or back it up using standard iOS device backup (iCloud Backup or iTunes/Finder backup).

#### 7.4 Correction
You can edit or delete individual check-ins within the app. You can update your display name and avatar emoji in the Friend settings.

#### 7.5 Opt-Out of AI Feature
You may stop using the AI feedback feature at any time by removing your API key from Settings. No data from Cathier is sent to Anthropic when no API key is present.

### 8. Data Retention

| Data | Retention Period |
|---|---|
| Local check-ins | Until you delete the check-in or uninstall the app |
| Reminder preferences | Until you change them or uninstall the app |
| Claude API key | Until you remove it from Settings or uninstall the app |
| CloudKit friend profile | Until you delete it through the app or request deletion |
| CloudKit invite codes | Automatically expire; typically deleted within 7 days of creation |
| CloudKit shared check-ins | Until you delete them from the app or request deletion |

### 9. Security

- Local data is protected by iOS's built-in file encryption when your device is locked.
- Your Claude API key is stored in UserDefaults, which is protected by the iOS sandbox. We recommend using a key with restricted permissions (e.g., limited to the Messages API only).
- CloudKit data is protected by Apple's security infrastructure.
- We do not transmit your data over any channel other than the two described in Section 5.

### 10. Changes to This Policy

We may update this Privacy Policy from time to time. Material changes will be communicated through an in-app notification or App Store update notes. The "Last Updated" date at the top of this document will always reflect the most recent revision. Continued use of the app after changes constitutes acceptance of the updated policy.

### 11. Contact

For privacy questions, data deletion requests, or concerns:

**Email:** [USER_EMAIL]

We aim to respond to all privacy-related inquiries within 30 days.

---

## 中文（Chinese）

**生效日期：** [EFFECTIVE_DATE]
**最后更新：** [LAST_UPDATED]

### 1. 简介

Cathier（"我们"或"本应用"）是一款个人情绪签到与感知训练应用。我们非常重视您的隐私。本隐私政策说明 Cathier 收集哪些数据、如何使用、存储在哪里，以及您对这些数据享有的权利。

使用 Cathier，即表示您同意本政策所述的做法。

### 2. 核心隐私承诺摘要

- **您的绝大多数数据从不离开您的设备。** 情绪签到、身体扫描数据和个人笔记均使用 Apple 的 SwiftData 框架存储在您的 iPhone 本地。
- **我们不运营任何存储您个人数据的服务器。**
- **我们不出售、出租或向广告商及数据中间商共享您的数据。**
- **我们不嵌入任何广告 SDK、数据分析 SDK 或追踪技术。**
- **您自行管理 AI API 密钥。** 如果您选择使用 AI 反馈功能，需自行提供并管理您的 Anthropic API 密钥。

### 3. 我们收集的数据及其用途

#### 3.1 本地数据（仅存储在您的设备上）

以下数据仅通过 Apple 的 SwiftData 框架存储在您的设备本地。这些数据**不会**传输至 Cathier 的服务器（我们没有服务器），默认情况下也**不会**同步至 iCloud。

| 数据类型 | 说明 | 存储位置 |
|---|---|---|
| 身体扫描选择 | 签到时您点选的身体部位（如：胸口、肩膀） | 设备本地（SwiftData） |
| 身体感受 | 您选择的感受词（如：紧绷、温热、沉重） | 设备本地（SwiftData） |
| 情绪标签 | 您从情绪轮盘中选择的情绪词 | 设备本地（SwiftData） |
| 情绪强度 | 数字强度评分（1–10） | 设备本地（SwiftData） |
| 个人笔记 | 签到后您撰写的自由文本笔记 | 设备本地（SwiftData） |
| AI 反馈文本 | 与每次签到一同保存的 AI 生成回应 | 设备本地（SwiftData） |
| 提醒偏好 | 您选择的通知时间 | 设备本地（UserDefaults） |
| Claude API 密钥 | 您个人的 Anthropic API 密钥 | 设备本地（UserDefaults） |

**删除应用将永久移除所有本地存储的数据。**

#### 3.2 发送至 Anthropic（Claude AI）的数据 —— AI 反馈功能

AI 反馈功能为**可选功能**。使用前，您需要从 Anthropic（api.anthropic.com）获取并填入您自己的 API 密钥。

当您在签到后请求 AI 反馈时，以下数据将直接从您的设备发送至 Anthropic 的 API 接口（`api.anthropic.com`）：

- 所选身体部位
- 所选感受词
- 情绪强度评分
- 所选情绪标签

**不会发送至 Anthropic 的内容：**
- 您的个人笔记
- 您的姓名或身份信息
- 任何持久性用户标识符
- 您的设备位置

您的 API 密钥仅存储在您的设备上。Cathier 不会将您的 API 密钥传输至任何我们控制的服务器。

Anthropic 依据其自身隐私政策处理相关数据。请参阅 Anthropic 隐私政策：https://www.anthropic.com/privacy

#### 3.3 存储在 Apple CloudKit 中的数据 —— 好友功能

好友功能为**可选功能**。它使用 Apple 的 CloudKit 公共数据库（`iCloud.com.wangjianshuo.Cathier`）来实现好友连接和自愿分享签到。

当您使用好友功能时，以下数据将存储在 Apple 的 CloudKit 中：

| 数据类型 | 说明 | 可见范围 |
|---|---|---|
| 显示名称 | 您为好友档案选择的名称 | 仅确认的好友可见 |
| 头像表情 | 您选择的表情符号头像 | 仅确认的好友可见 |
| CloudKit 用户记录 ID | Apple CloudKit 系统分配的匿名标识符 | 仅用于内部好友连接，非真实姓名或邮箱 |
| 邀请码 | 用于建立好友连接的限时邀请码 | 临时使用，使用后删除 |
| 好友关系记录 | 表示两个用户已建立连接的记录 | 仅双方可见 |
| 分享的签到 | 您主动选择分享的签到数据，按您选择的隐私等级分享 | 仅确认的好友可见 |

**分享签到的隐私等级：**

每次分享时，您可以选择分享的详细程度：
- **只分享情绪大类：** 好友只能看到情绪大类和强度
- **分享情绪词：** 好友可以看到具体的情绪标签
- **完整分享：** 好友可以看到所有签到内容，包括您的个人笔记和 AI 反馈

除非您明确选择"完整分享"，否则**个人笔记和 AI 反馈永远不会**包含在分享的签到中。

Apple 依据 Apple 隐私政策存储和处理 CloudKit 数据：https://www.apple.com/legal/privacy/

### 4. 我们不收集的数据

Cathier 不收集以下任何数据：

- 精确或大致位置信息
- 通讯录或地址簿数据
- 用于跨应用追踪的设备标识符（无 IDFA，无指纹识别）
- 财务或支付信息
- 浏览历史
- 来自 HealthKit 的健康数据
- 相机或麦克风数据
- 通过第三方 SDK 收集的崩溃分析或性能诊断数据
- 任何用于广告目的的数据

### 5. 第三方服务

Cathier 仅使用以下两项第三方服务：

| 服务 | 用途 | 共享数据 | 其隐私政策 |
|---|---|---|---|
| Anthropic（Claude API） | 在签到后生成共情 AI 反馈 | 身体部位、感受词、情绪词、强度（无身份数据） | https://www.anthropic.com/privacy |
| Apple CloudKit | 存储好友档案和自愿分享的签到 | 显示名称、头像表情、CloudKit 用户 ID、分享的签到数据 | https://www.apple.com/legal/privacy/ |

Cathier 中未集成任何广告网络、数据分析平台或追踪 SDK。

### 6. 儿童隐私

Cathier 面向 **13 岁及以上**用户。我们不会故意收集 13 岁以下儿童的个人信息。如果您是家长或监护人，并认为您 13 岁以下的孩子使用了 Cathier 的好友功能并在 CloudKit 中存储了信息，请通过 [USER_EMAIL] 联系我们，我们将协助处理数据删除。

### 7. 您的权利

根据您所在的司法管辖区，您可能享有以下权利：

#### 7.1 访问权
您可以直接在应用内查看所有本地存储的签到数据（日记标签页）。您可以在好友标签页查看您的好友档案和分享的签到。

#### 7.2 删除权

- **本地数据：** 删除应用即可移除所有本地存储的数据。您也可以在日记视图中删除单条签到记录。
- **CloudKit 好友档案和分享的签到：** 您可以在应用内移除好友并删除分享的签到。如需删除您的完整好友档案及所有相关 CloudKit 记录，请通过 [USER_EMAIL] 联系我们，邮件主题注明"CloudKit 数据删除申请"。
- **AI 请求：** 对 Anthropic 的单次 API 调用是无状态的——不同会话之间不保留历史记录。有关 API 使用数据的保留政策，请参阅 Anthropic 的数据保留政策。

#### 7.3 数据可携带性
您的本地签到数据存储在设备上的 SwiftData 中。您可以使用标准 iOS 设备备份（iCloud 备份或 iTunes/访达备份）导出或备份这些数据。

#### 7.4 更正权
您可以在应用内编辑或删除单条签到记录。您可以在好友设置中更新您的显示名称和头像表情。

#### 7.5 退出 AI 功能
您可以随时在设置中删除 API 密钥来停止使用 AI 反馈功能。当没有 API 密钥时，Cathier 不会向 Anthropic 发送任何数据。

### 8. 数据保留

| 数据 | 保留期限 |
|---|---|
| 本地签到记录 | 直到您删除该记录或卸载应用 |
| 提醒偏好 | 直到您更改设置或卸载应用 |
| Claude API 密钥 | 直到您在设置中删除或卸载应用 |
| CloudKit 好友档案 | 直到您通过应用删除或申请删除 |
| CloudKit 邀请码 | 自动过期；通常在创建后 7 天内删除 |
| CloudKit 分享签到 | 直到您在应用中删除或申请删除 |

### 9. 安全性

- 本地数据在设备锁屏时受 iOS 内置文件加密保护。
- 您的 Claude API 密钥存储在 UserDefaults 中，受 iOS 沙箱保护。我们建议使用权限受限的密钥（例如，仅限于 Messages API）。
- CloudKit 数据受 Apple 安全基础设施保护。
- 除第 5 节所述的两个渠道外，我们不通过任何其他渠道传输您的数据。

### 10. 政策变更

我们可能会不时更新本隐私政策。重大变更将通过应用内通知或 App Store 更新说明进行告知。本文档顶部的"最后更新"日期将始终反映最新修订。变更后继续使用应用即视为接受更新后的政策。

### 11. 联系方式

如有隐私问题、数据删除申请或其他疑虑：

**电子邮件：** [USER_EMAIL]

我们力争在 30 天内回复所有与隐私相关的询问。
