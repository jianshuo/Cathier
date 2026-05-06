# Cathier 市场自动化设计

> 状态：设计中（待 user 审阅）
> 作者：Claude Code（与 Jianshuo 协作于 2026-05-06）
> 范围：用 Claude Code 自动化 Cathier 的日常市场内容生产与发布

## 1. 背景与目标

Cathier 现有一条"用户反馈 → @claude PR → CI 通过 → 自动 squash merge"的零接触工程闭环（详见 `.github/workflows/{claude.yml,build.yml,auto-merge-claude.yml}`）。产品功能已基本完整。**市场侧目前完全空缺**：没有日更内容、没有选题机制、没有图片产出、没有发布通道。

本设计的目标：搭建对应的零接触市场闭环，让 Cathier 每天能自动产出并发布一条小红书 + 一条 X 内容，要求文案与图片不偏离 Cathier 的品牌定位（"practitioners, not patients"，暖橙 #F2700A，Instrument Serif，反 wellness pastels）。

成功标准：
- 上线后 30 天内，每天 09:00 自动产出当日内容包（文案 + 图集），无人工介入。
- 90% 以上内容能直接发布而无需重写。
- 内容覆盖至少 20 个独立卖点，无明显同质化（编辑 pass 自评 + 用户人工抽查）。

## 2. 必须先讲的现实约束：小红书没有公开发布 API

**这一条决定整个设计的形状。** 真正的"零接触发布"在小红书侧只有三条路：
- (a) 浏览器自动化（Playwright/Puppeteer 模拟登录）—— 反爬高、UI 改版即坏、易封号
- (b) 第三方 SaaS（蒲公英、灰豚、新榜）—— 要付费 + 企业号，账号受 SaaS 控
- (c) 商家号 / MCN 合作平台官方接口 —— 需企业认证

X 不同：官方 API v2 可发，Free tier 每月限额内可用。

**决策：分阶段。** Phase 1 只跑内容引擎，发布走"GitHub Issue 通知 + 人工 10 秒粘贴"。Phase 2 视情况引入 (a)/(b)。理由是内容质量 >> 发布机制，先把发布做了反而会机械性放大平庸文案的损害。

## 3. 架构决策

### 评估过的三种架构

| 方案 | 描述 | 取舍 |
|---|---|---|
| A. 单脚本 + cron | 每天跑一次 Claude Code headless，让它自己想自己写自己发 | 简单；但选题易同质，无历史记忆，声音漂移 |
| **B. 仓库内"市场大脑"** | `marketing/` 承载 angles、voice、平台规则、历史；cron 跑 Claude 读大脑、挑角度、起草、编辑、出图、commit、通知 | 状态全在 git，可审计、可 revert；与现有 auto-merge 哲学一脉相承 |
| C. 多 agent 流水线 | 选题/起草/编辑/出图/发布各起独立 Claude 调用 | 质量上限更高；但启动复杂度大，第一版边际收益不明 |

**采用 B**。和现有 `@claude → PR → squash merge` 哲学一致：所有改动都在 git 里，所有产出都可 revert。

### 架构原则

- **状态在 git**：angles、voice、历史帖子、生成的图，全部 commit。`_index.jsonl` 作为追加日志。
- **文本驱动**：Cathier 的差异化在文字里。图片是文字的载体。
- **编辑 pass 是必须**：起草后另起一个 Claude 实例当编辑，按 voice.md 检查。无此 pass，agent 会在 30 天内收敛到自我同质。
- **不放 KPI 进系统提示**：不写"为了涨粉"，写"为了让对的人找到我们"。

## 4. 仓库结构

```
marketing/
├── brain/
│   ├── angles.json          # 卖点目录
│   ├── voice.md             # 声音规则（从 DESIGN.md 抽出）
│   ├── platforms/
│   │   ├── xiaohongshu.md   # 平台规则
│   │   └── x.md
│   └── reference/
│       ├── screenshots/     # 应用截图、视觉参考
│       └── image-prompts/   # 历史成功 image prompt 库（去重检查用）
├── posts/
│   ├── 2026-05-07/
│   │   ├── xiaohongshu.md   # 最终文案 + 图清单
│   │   ├── xiaohongshu-1.png ... xiaohongshu-5.png
│   │   ├── x.md
│   │   └── x.png
│   └── _index.jsonl         # 追加日志：日期、平台、angle_id、状态
├── prompts/
│   ├── daily-orchestrator.md  # 主控 prompt：调度 angle 选择 → 起草 → 编辑 → 出图 → 落盘
│   ├── angle-discovery.md     # 周更 angle 发现
│   ├── post-draft.md          # 起草
│   ├── editor-pass.md         # 编辑批评
│   └── image-spec.md          # 图片 prompt 生成规则
└── publish/
    ├── compose.py           # 后处理：底图 + 中文字叠加（Pillow + 思源宋体）
    ├── x_publish.py         # X API v2 发布（Phase 2）
    └── xhs_checklist.md     # 小红书人工粘贴 checklist（Phase 1）
```

新增 GitHub Action：`.github/workflows/marketing-daily.yml`。每天 09:00 Asia/Shanghai cron，跑 Claude Code headless。

## 5. 内容引擎

### 5.1 Angle 目录是核心资产

`marketing/brain/angles.json` 每条形如：

```json
{
  "id": "instrument-serif-rationale",
  "claim": "我们用衬线字体写 AI 反馈，不是为了好看，是为了让你像读一封给自己的信，不是聊天记录。",
  "evidence": [
    "DESIGN.md:Decisions Log:2026-03-27",
    "DESIGN.md:AI Reflection Visual Language"
  ],
  "audience": "design-conscious 同行；重度日记/手账用户",
  "platforms_fit": ["xhs", "x"],
  "status": "unused",
  "used_dates": []
}
```

**Angle 来源（每周一次 `angle-discovery` agent 跑）：**
- `DESIGN.md` 的 Decisions Log（每条决策背后都是一个差异化角度）
- README features list
- `git log --since=2.weeks`（新功能 = 新角度）
- 用户反馈 issues（真痛点 = 真共鸣）
- 已用 angle 的负空间（哪些情绪类别/身体部位/使用场景还没被讲过）

**冷启动要求：上线前手工 + agent 共建至少 20 个 angle**，保持"角度密度 ≥ 3 × 发帖密度"。

### 5.2 起草 prompt（`post-draft.md`）

输入：选定的 angle、目标平台、最近 14 天已发文案。
输出：平台特化文案 + 图集 brief。

关键约束写进 prompt：
- 不要"治愈""陪伴你""温柔""疗愈"等 Calm 系语言
- 不要心理咨询口吻（合规 + 品牌双重风险）
- 第一句必须是钩子，不是问候
- 同一 angle 在小红书和 X 上必须是各自重写，不是机翻

### 5.3 编辑 pass（`editor-pass.md`）

另起一个 Claude 实例，对起草输出做强制检查：
- 触犯禁词清单？
- 与最近 14 天的帖子在角度/句式上重复？
- 平台格式合规？（小红书：钩子在第 1 句、标题 ≤20 字、5–15 tags；X：≤280 字符）
- 触发任何医疗/治疗/咨询性表述？

未通过 → 退回起草，最多 2 轮重写。仍不通过 → 跳过当日发布，开 issue 标记，不静默吞掉错误。

## 6. 图片生成（用 OpenAI gpt-image-1，即 ChatGPT Image 2）

**模型选择：OpenAI 的 `gpt-image-1`**（ChatGPT 内 "Image 2" 对应的 API 模型）。

通过 OpenAI Images API 调用：
```
POST https://api.openai.com/v1/images/generations
{ "model": "gpt-image-1", "prompt": "...", "size": "1024x1536" or "1024x1024", "n": 1 }
```

API key 走 GitHub Secrets（`OPENAI_API_KEY`），与现有 Qwen/Claude 那套一致。

### 6.1 锁住品牌视觉

`gpt-image-1` 比上一代 DALL-E 3 更可控，但默认仍会向"wellness pastels"平均值漂。需要在 prompt 层强约束：

- **品牌前缀**（每张图必带）：
  > "Editorial illustration in the style of a Moleskine notebook page or a Japanese stationery brand. Warm off-white paper background (#F7F5F1), subtle paper texture. Sparing use of bright orange (#F2700A) as the only accent color. Restrained, grounded, quiet. Hand-drawn quality, not digital-perfect. NO pastel colors, NO baby/cute aesthetics, NO gradient backgrounds, NO generic wellness imagery, NO smiling faces, NO meditation poses, NO lotus/leaf motifs."
- **字体规则**：Instrument Serif 大字标题（如要在图上叠字，让 gpt-image-1 直出衬线字也可以；它对英文衬线还行，中文衬线交给后处理用 Pillow 叠字）。
- **尺寸**：小红书 `1024x1536`（约 2:3，9:16 上裁切），X `1024x1024` 或 `1536x1024`。
- **图集结构（小红书）**：3–5 张为一组——封面 + 钩子 + 1–3 张内容卡 + CTA。每张是一个 beat，不是一张图塞满。
- **prompt 池**：`marketing/brain/reference/image-prompts/` 存历史成功 prompt，编辑 pass 检查新 prompt 是否与最近 14 天图片在构图/主体上重复。

### 6.2 中文文字处理

`gpt-image-1` 出中文字仍不稳定。策略：
- 让 `gpt-image-1` **只负责出底图**（场景/情绪/构图），不强求图上有中文。
- 中文标题/卖点用 **后处理 Pillow + Instrument Serif（英文）+ 思源宋体（中文）** 叠字，保证排版品牌一致。
- 后处理脚本 `marketing/publish/compose.py`，输入：底图 + 标题 + 副文案 + 模板编号；输出：最终发布图。

### 6.3 退路

如果 30 天后发现 `gpt-image-1` 出图合格率 < 70%（编辑 pass 通过率），退路是引入 5 个 SwiftUI 模板（用 `xcrun simctl screenshot` 渲染真实应用截图），混合使用。这写在风险章节，不进 v1 范围。

## 7. 平台规则（`marketing/brain/platforms/`）

### `xiaohongshu.md`
- 标题 ≤ 20 字
- 正文：钩子在第 1 句，段落短，每段 ≤ 3 行
- Tags：5–15 个，混用大流量（`#情绪`、`#手账`）+ 长尾（`#情绪感知训练`、`#身体扫描`）
- 图集：3–5 张为一组，9:16
- 发布时间：09:00 ± 30 分钟随机（防机械性）
- 禁词：见 voice.md

### `x.md`
- 单条 ≤ 280 字符（中英混排注意字符数）
- 必带 1 张图（X 算法偏好）
- 角度可与小红书相同，但文案重写——X 受众更国际化、design/tech 倾向
- 发布时间：考虑欧美时区，22:00 Asia/Shanghai 附近为佳（待 Phase 2 验证）

## 8. 分阶段路线

| Phase | 周期 | 输出 |
|---|---|---|
| Phase 0：奠基 | 1–2 天 | `marketing/brain/` 初稿（voice.md、20 个 angle、平台规则、image-spec.md） |
| Phase 1：内容引擎跑通 | 3–5 天 | 每日 cron 自动出文案 + 图，commit 到 `posts/`，开 GitHub Issue 通知；人工 10 秒粘贴发布 |
| Phase 2：自动发布 | Phase 1 稳定 1–2 周后 | X API 接入（`x_publish.py`）；小红书继续手工或评估第三方 SaaS |
| Phase 3：闭环 | 一个月后 | 抓取发布后 24h 互动数据写回 `_index.jsonl`，影响 angle 选择权重 |

## 9. GitHub Action 设计

`.github/workflows/marketing-daily.yml`：

- 触发：`schedule: cron: '0 1 * * *'`（UTC 01:00 = Asia/Shanghai 09:00）+ `workflow_dispatch`（手动可触发）
- 步骤：
  1. checkout
  2. 安装 Claude Code CLI、Python（Pillow）
  3. 运行 Claude Code headless：`claude -p "$(cat marketing/prompts/daily-orchestrator.md)"`，让它读大脑、选 angle、起草、编辑、调 OpenAI 出图、跑 compose.py 叠字、commit 到 `posts/YYYY-MM-DD/`
  4. 编辑 pass 失败时：开 issue 标记 `marketing-failed`，不静默
  5. 成功时：开 issue 标记 `marketing-ready`，body 中嵌入文案预览 + 图片链接，方便手机上一秒粘贴

API keys 走 GitHub Secrets：`ANTHROPIC_API_KEY`、`OPENAI_API_KEY`。Phase 2 加 `X_API_BEARER_TOKEN`。

## 10. 已做判断（user 已确认）

1. 每天 1 篇够了，不追求多平台多频次。Cathier 用户不是刷信息流的人。
2. 小红书优先于 X（中文母体市场），同 angle 双发但各自重写。
3. **图片生成用 `gpt-image-1`（ChatGPT Image 2）**，中文字后处理叠加。
4. 系统提示中不写 KPI；voice.md 是品牌规则的唯一权威。
5. voice.md 硬规则禁止医疗/治疗/咨询表述。
6. API key 走 GitHub Secrets。

## 11. 风险与缓解

| 风险 | 缓解 |
|---|---|
| 同质化漂移 | 多 angle + 编辑 pass + 14 天历史窗口 + 季度人工刷新 voice.md |
| 小红书反垃圾限流 | 发布时间 ±30 分钟抖动 + 模板池 ≥ 5 + 句式池 + 不复用同一图集结构 |
| 合规风险（情绪感知 ≠ 心理治疗） | voice.md 硬规则 + 编辑 pass 强制检查 + 触发即跳过当日 |
| 冷启动 angle 枯竭 | 上线前手工 + agent 共建 ≥ 20 个 angle，密度 ≥ 3:1 |
| `gpt-image-1` 偏离品牌 | 强约束 prompt 前缀 + 中文字后处理 + 30 天合格率监测，<70% 引入 SwiftUI 模板退路 |
| 小红书账号被封 | Phase 1 不上自动发布；Phase 2 引入前先做账号热身/合规评估 |
| API 成本失控 | 每次跑设置成本上限（Claude tokens + OpenAI 图片数）；Action 中加日志 |

## 12. 不在范围内（YAGNI）

- 视频内容（小红书视频、X 视频）
- 多账号矩阵
- A/B 测试基础设施
- B2B / 投资人内容渠道
- 实时互动（评论自动回复）
- 数据分析仪表盘 UI（Phase 3 写 jsonl 即可，无需可视化）

## 13. 待 Phase 2 决定的开放问题

- **小红书发布通道选型**：浏览器自动化 vs 第三方 SaaS vs 永远手工。倾向手工，等内容引擎跑顺再评估。
- **X 发布时间**：欧美时区 vs 国内时区，需 Phase 2 数据验证。
- **是否引入应用真截图叠字**：`gpt-image-1` 合格率不达标时启用。
