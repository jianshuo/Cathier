# Reddit 发布规则

> Reddit 跟 xhs / X 是不同的物种。把 X 的文案粘过来 = 必死。本文件是硬约束。

## 核心心智

Reddit **不是营销渠道**，是讨论场。你以"有想法的人"身份参与，而不是以品牌身份广播。Cathier 这个产品是你思考过程里的一个事实，不是帖子的目的。

## 频率

- **每周一次最多**。`marketing-weekly-reddit.yml` 只在周一跑。
- 如果当周已经有人手动发过 Reddit，跳过这次自动产出。

## 文案结构

| 段 | 内容 | 字数 |
|---|---|---|
| 1 钩子 | 真问题 / 真场景 / 反直觉观察。**不要**以 "I made X" 或 "Hi, I'm working on..." 开头 | 50–150 字 |
| 2 决策 | 我们做了什么具体的选择 | 80–200 字 |
| 3 理由 | 为什么——附具体证据、数字、参考 | 100–250 字 |
| 4 反邀 | 邀请社区分享他们的做法或反驳。**不要**结尾要下载 | 30–80 字 |

总长 400–1000 字。**不要**做 TL;DR——Reddit 用户讨厌假装精简的"我懒得读"。

## 自宣红线

- 产品名 "Cathier" 在全文出现 **≤2 次**
- 不出现 App Store / 下载 / 链接 / 二维码
- 不出现 "check out our app" / "if you're interested" / "feel free to..."
- 第一句**不是**关于 Cathier
- 整篇 ≥ 70% 内容是讨论本身，≤ 30% 是产品上下文

如有违反 → editor 直接拒。

## subreddit 选择

每条 angle 必须在 `angles.json` 里有 `reddit_subreddits` 字段。建议候选池：

| angle 类型 | 候选 subreddit |
|---|---|
| 设计 / 字体 / 视觉决策 | `r/userexperience`, `r/Design`, `r/typography` |
| iOS / SwiftUI 工程决策 | `r/SwiftUI`, `r/iOSProgramming` |
| 情绪练习 / 身心 / somatic | `r/somatics`, `r/EmotionalIntelligence`, `r/IFS` |
| 反 wellness / 工具哲学 | `r/productivity`, `r/digitalminimalism` |
| Indie hacking / 决策反思 | `r/SideProject`, `r/indiehackers` |

orchestrator 选 angle 后从其 `reddit_subreddits` 数组里随机挑一个，写在 frontmatter 的 `subreddit:` 字段。

## 标题规则

- ≤ 300 字符（Reddit 硬限制）
- **禁开头：** "I made", "Just launched", "Looking for feedback", "Hi everyone", "Thoughts on..."
- **可开头：** 具体问题、反直觉论断、决策结果（"We chose serif type for our AI feedback. Here's why."）
- 全大写禁用；emoji 禁用；末尾感叹号禁用

## 格式要求

- 纯文本 / Reddit Markdown（`**bold**`, `*italic*`, 列表, 引用）
- 不带 hashtag
- 不带表情
- **没有图**（如有图，单独发图帖；混合体不发）
- 段落之间空行；每段 ≤ 5 行

## 时间

- 周一 10:00 Asia/Shanghai cron
- 选择 subreddit 时考虑该 sub 的活跃时段（多数英语 sub 美东上午活跃 = 中国时间晚上）；orchestrator 把发布建议时间写入 issue body

## 反垃圾签名

Reddit 反 spam 算法会看：
- 帐号年龄（你的账号必须 ≥30 天，karma ≥50；不达标先去几个 sub 留正常评论攒）
- 历史发帖比（如果该账号几乎只发自己产品 → 标 spam 风险高；先去发几个无关讨论再发产品决策帖）
- 重复内容（不要一周双发同 angle 给两个 sub；要发也间隔至少 7 天）
