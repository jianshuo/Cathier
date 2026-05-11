# Cathier 首页简化设计

> 状态：设计中（待 user 审阅）
> 作者：Claude Code（与 Jianshuo 协作于 2026-05-07）
> 范围：精简 `TodayView` 让"此刻"Tab 重新成为聚焦的觉察练习入口

## 1. 背景与问题

`Cathier/Views/TodayView.swift` 当前最多渲染 **14 个区块**：

1. 问候 + streak 徽章
2. 连续打卡里程碑横幅（3 / 7 / 14 / 30 天）
3. WeeklyPracticeRow（7 日圆点）
4. 本周 Top 5 情绪 chips（`WeeklyEmotionSummary`）
5. 7 日平均强度卡 + sparkline（`weeklySnapshotCard` + `WeeklySparkline`）
6. 晚间提醒 nudge
7. ★ 主 CTA「开始觉察检查」
8. 今日记录列表 + `TodayIntensityArc`
9. 模式洞察 nudge（`insightsNudgeCard`）
10. 今日日记
11. AI 冷笑话（`dailyJokeSection`）
12. 今日 AI 最前沿（`aiFrontierSection`）
13. 吃一堑长一智 / BrainTrainer（`brainTrainerSection`）
14. 身体数据 / HealthKit（`healthSection`）

**`DESIGN.md` 里写的原始结构只有 4 块**：问候 → 主按钮 → 今日记录 → 日记。

**违反的设计哲学**（来自 `DESIGN.md`）：
- *"focused practice space"*
- *"Calm but present. Not therapeutic reassurance — not a comfort object."*
- *"Design for active practice, not reassurance."*
- *"The check-in flow should feel like a quiet ritual, not a gamified app."*

11–14（笑话、AI 新闻、BrainTrainer、健康）把首页变成了 feed，与"安静的练习仪式"相悖。3、4、5、9 是回顾分析类，更适合在「日记」Tab 里出现。

## 2. 目标

- Today Tab 从 14 块降到约 6 块（其中 2 块是条件性的）。
- 打开 Today，3 屏内必现主 CTA；最理想的是首屏。
- 不删除任何已上线功能（只搬家）；功能可达性保留。
- 不动 Tab 结构（已经有 5 个 Tab：此刻 / 日记 / 好友 / 广场 / 设置）。
- 不动 `DESIGN.md` 中关于 Today 的描述（这次反而让它和原文一致）。

非目标：
- 不重构 `TodayView` 内的子组件（`WeeklyPracticeRow` / `WeeklySnapshot` 等整体搬过去即可）。
- 不重新设计任何被搬走的功能本身。
- 不动 i18n 字符串（被搬到新位置的 section 复用现有字符串和 switch 分支）。

## 3. 新结构

### 3.1 Today（此刻）

只保留与"觉察练习"直接相关的内容，按从上到下顺序：

| # | 区块 | 来源 | 显示条件 |
|---|---|---|---|
| 1 | 问候 + streak 徽章 | 保留原 `headerView` | 总是 |
| 2 | 连续打卡里程碑横幅 | 保留原 `streakMilestoneBanner` | `milestoneToShow != nil` |
| 3 | 晚间提醒 nudge | 保留原 `reminderNudgeCard` | `!notificationsEnabled && todayCheckIns.isEmpty && hour >= 18` |
| 4 | ★ 主 CTA | 保留原 `startButton` | 总是 |
| 5 | 今日记录列表（含 `TodayIntensityArc`） | 保留 | `!todayCheckIns.isEmpty` |
| 6 | 今日日记 / 写日记入口 | 保留原 `dailyJournalSection` | 总是 |

文件：`Cathier/Views/TodayView.swift`。删掉 11–14 的 section、删掉 3/4/5/9 的 section。其它逻辑不动（streak 计算、`onAppear`、sheets 中的 `showingCheckIn` / `showingJournalEntry` 保留；其它 sheets 在 4 节列出的搬迁中处理）。

### 3.2 Journal（日记）— 顶部新增「本周快照」区

`Cathier/Views/JournalView.swift` 在现有 grouped check-in list 之上加一个固定的「本周」头区（仅当 `checkIns.count > 0` 时显示）：

| # | 区块 | 来源 |
|---|---|---|
| 1 | WeeklyPracticeRow（7 日圆点） | 从 `TodayView.swift` 内的 `private struct WeeklyPracticeRow` 移出到 `Cathier/Views/Components/WeeklyPracticeRow.swift` |
| 2 | WeeklyEmotionSummary（本周 Top 5 情绪） | 从 `TodayView.swift` 内的 `private struct WeeklyEmotionSummary` 移出到 `Cathier/Views/Components/WeeklyEmotionSummary.swift` |
| 3 | weeklySnapshotCard（强度 + sparkline） | 从 `TodayView` 移到 `JournalView`，连带 `WeeklySnapshot` struct 与 `WeeklySparkline` 子 view 一起搬；点击仍打开 Insights sheet |

**模式洞察 nudge（#9）合并而非搬运**：JournalView 已经有一个 toolbar 入口指向 `InsightsView`。把 `hasNewPatterns` 的计算挪到 JournalView，并在 toolbar 按钮上加一个红点 badge（同 Friend 的 pending request 红点风格），无需独立卡片占位。

实现说明：
- 移出来的三个子 view 改为 `internal`（默认）级别，便于跨文件复用。
- `JournalView` 已有 `@Query checkIns`，直接复用即可，不引入新的 `@Query`。
- 「本周」头区放在搜索框下方、grouped list 上方；如果搜索激活（`!searchText.isEmpty`）则隐藏头区，不打扰搜索结果。

### 3.3 Settings → 探索（扩展现有 section）

`SettingsView` 已经有「探索」section，目前只链接到觉察词典。把以下四项作为 NavigationLink 加到该 section：

| 入口 | 打开 | 来源 sheet |
|---|---|---|
| 觉察词典（已存在，不动） | `EmotionExplorerView` | — |
| 身体数据 | `HealthInsightView` | 从 Today 的 `showingHealth` sheet 改为 push |
| 吃一堑长一智 | `BrainTrainerSheet` 内容（包成 NavigationLink 友好的 wrapper view） | 从 Today 的 `showingBrainTrainer` |
| AI 冷笑话 | 直接打开 `JokeHistoryView`（实现阶段确认其在打开时是否已包含当日笑话；如不包含则在 list 顶部加一个"今日"区块）| 从 Today 的 `showingJokeHistory` |
| 今日 AI 最前沿 | 新建一个简单 list view，展示当日 + 历史，复用 `AIFrontierCard` | 从 Today 的 `aiFrontierSection` |

行样式与现有「觉察词典」一致：左 icon + 标题 + 右 chevron，遵循 SettingsView 现有 list section 的视觉。

### 3.4 触发点（重要：成本与可见性对齐）

当前 `TodayView` 用 `.task(id: "joke")` 和 `.task(id: "aiFrontier")` 在每次出现时检查并生成内容。生成涉及 LLM API 调用，有成本。

搬走后必须做到：**生成只在用户实际看得到的位置触发**。

- `JokeService.generateTodayJokeIfNeeded()` 的触发点 → 移到「AI 冷笑话」入口对应的 view（`JokeHistoryView`）的 `.task`。
- `AIFrontierService.generateTodayNewsIfNeeded()` 的触发点 → 移到「今日 AI 最前沿」对应的新 list view 的 `.task`。
- BrainTrainer 没有 task 触发逻辑（只是 sheet），不变。
- HealthKit 数据已经是 `HealthKitService.shared` 自维护，不变。

副作用：用户不进入 Settings → 探索就不会生成笑话/AI 新闻。这是想要的——降低成本 + 这两个功能本来就不在产品核心路径上。

## 4. 改动文件清单

新增：
- `Cathier/Views/Components/WeeklyPracticeRow.swift`（从 TodayView 抽出）
- `Cathier/Views/Components/WeeklyEmotionSummary.swift`（从 TodayView 抽出）
- `Cathier/Views/Components/WeeklySnapshotCard.swift`（包含 `WeeklySnapshot` struct + `weeklySnapshotCard` view + `WeeklySparkline` 子 view）
- `Cathier/Views/AIFrontierListView.swift`（新建一个简单的 list view 给设置入口用）

修改：
- `Cathier/Views/TodayView.swift` — 删 11–14 的 section、删 3/4/5/9 的 section、删被搬走的 `private struct`、删对应 sheets 和 `@State`、删对应 `.task`
- `Cathier/Views/JournalView.swift` — 顶部加「本周快照」头区；toolbar Insights 按钮加 `hasNewPatterns` 红点 badge
- `Cathier/Views/SettingsView.swift` — 「探索」section 加 4 个 NavigationLink
- `Cathier/Views/JokeHistoryView.swift` — 加 `.task` 调用 `JokeService.generateTodayJokeIfNeeded()`
- `Cathier/Views/HealthInsightView.swift` — 确保能作为 NavigationLink 的目的地（如有依赖 sheet 关闭等行为则调整）
- `Cathier/Views/CheckIn/BrainTrainerSheet.swift` — 设置入口走 NavigationLink。若 `BrainTrainerSheet` 当前强依赖 sheet presentation（如有 dismiss 钩子），则在实现阶段抽出内容 view 作为 NavigationLink 目的地，sheet 版本保留供 check-in flow 使用。

不改：
- `DESIGN.md`（这次改动反而让 Today 的实现回到与 DESIGN.md 描述一致的状态）
- 任何 i18n 字符串
- Tab 结构（`ContentView.swift` 不动）
- 任何业务逻辑、数据模型、CloudKit、AI provider 调用细节

## 5. 风险与权衡

- **可发现性下降**：笑话、AI 最前沿原本一打开 app 就在；移到设置后用户可能找不到。**对策**：第一次发版后看数据；如果留存断崖式下跌，说明用户喜欢；否则证明这些是噪音、不该在首页。这正是产品哲学要求的取舍。
- **BrainTrainer 是不是该留在 Today**：它的文案"踩了坑？花几分钟训练新模型"和情绪练习相关性比笑话强。但触发场景（"踩了坑"）通常发生在 check-in 之后，已经在 check-in flow 内部有合适的入口（`BrainTrainerChatView` 在 CheckIn/ 目录下）。Today 上的 BrainTrainer 入口是冗余。挪到设置可接受。
- **Journal Tab 顶部头区会不会打架**：现有 Journal 有搜索框 + grouped list，顶部加一个固定的「本周快照」头区会让首屏被分析占据。**对策**：搜索激活时隐藏头区；头区高度控制在 ~120pt 以内。
- **`hasNewPatterns` 红点逻辑迁移**：当前在 TodayView 通过 `UserDefaults.standard.integer(forKey: "lastInsightCheckInCount")` 计算；搬到 JournalView 是同一个 key，无数据迁移。
- **`personalBestStreak` 维护**：当前在 TodayView 的 `onAppear` 和 `onChange(of: streakDays)` 里更新。搬迁后保持在 TodayView 即可（streak 仍显示在 Today 顶部）。

## 6. 成功标准

- TodayView 的 `body` 顶层 VStack 里的 section 数从 14 降到 ≤6（含条件 section）。
- TodayView.swift 文件总行数减少（粗估：从 ~1086 行降到 ~500 行以内）。
- 所有原有功能依然可达（笑话、AI 新闻、BrainTrainer、Health 通过 Settings → 探索 抵达；本周分析在 Journal Tab 顶部抵达）。
- 笑话和 AI 新闻的 LLM 调用只在用户进入对应入口时发生（用 instrumentation 或日志验证一次）。
- 重新读 `DESIGN.md` § "Tab 1: 此刻 (Today)"，新实现与那段描述一致或更接近。

## 7. 里程碑

- M0（本 spec）：设计达成。
- M1：实现计划（由 `superpowers:writing-plans` 产出）。
- M2：实现 + 自测 + PR。
- M3：发版后观察一周，决定是否进一步删除（而非搬家）笑话 / AI 最前沿。
