# Cathier 市场自动化（Phase 0 + 1）实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 落地《市场自动化设计》中 Phase 0（奠基）和 Phase 1（内容引擎跑通）。每天 09:00 自动产出当日的小红书 + X 内容包（文案 + 图集），commit 到仓库，开 GitHub Issue 通知。Phase 2 自动发布另起计划。

**Architecture:** 仓库内 `marketing/` 作为"市场大脑"。GitHub Action 每日 cron 通过 `anthropics/claude-code-action@v1` 调起 Claude Code，让它读 brain → 选 angle → 起草 → 编辑 → 调 OpenAI gpt-image-1 出图 → 用 Pillow 后处理叠中文字 → commit → 开 Issue。

**Tech Stack:** Markdown prompts、JSON 角度目录、Python 3.11（Pillow + openai SDK）、pytest、GitHub Actions、`anthropics/claude-code-action@v1`、OpenAI Images API（`gpt-image-1`）。

**Spec 参照：** `docs/superpowers/specs/2026-05-06-marketing-automation-design.md`

**不在本计划范围（YAGNI）：**
- Phase 2 自动发布（X API 接入、小红书发布通道）
- Phase 3 数据回流闭环
- 视频内容、多账号矩阵、A/B、互动自动回复、可视化仪表盘

---

## 文件结构

```
marketing/
├── README.md                        # 入口文档（Task 14）
├── brain/
│   ├── voice.md                     # 声音规则（Task 2）
│   ├── angles.json                  # 卖点目录（Task 4 种子，Task 6 扩展）
│   ├── platforms/
│   │   ├── xiaohongshu.md           # 平台规则（Task 3）
│   │   └── x.md                     # 平台规则（Task 3）
│   └── reference/
│       ├── screenshots/.gitkeep     # 截图库（Task 1）
│       └── image-prompts/.gitkeep   # 历史 image prompt 库（Task 1）
├── posts/
│   └── _index.jsonl                 # 追加日志（Task 1，初始空文件）
├── prompts/
│   ├── angle-discovery.md           # Task 5
│   ├── post-draft.md                # Task 7
│   ├── editor-pass.md               # Task 8
│   ├── image-spec.md                # Task 9
│   └── daily-orchestrator.md        # Task 12
└── publish/
    ├── requirements.txt             # Task 10
    ├── image_gen.py                 # Task 10（TDD）
    ├── compose.py                   # Task 11（TDD）
    ├── tests/
    │   ├── __init__.py
    │   ├── test_image_gen.py        # Task 10
    │   ├── test_compose.py          # Task 11
    │   └── fixtures/
    │       └── sample_bg.png        # Task 11 测试用底图
    └── xhs_checklist.md             # Task 14（人工粘贴说明）

.github/workflows/marketing-daily.yml # Task 13
```

---

## Task 1: 创建目录骨架

**Files:**
- Create: `marketing/brain/reference/screenshots/.gitkeep`
- Create: `marketing/brain/reference/image-prompts/.gitkeep`
- Create: `marketing/brain/platforms/.gitkeep`
- Create: `marketing/posts/_index.jsonl`（空文件）
- Create: `marketing/prompts/.gitkeep`
- Create: `marketing/publish/tests/fixtures/.gitkeep`

- [ ] **Step 1: 创建目录与占位文件**

```bash
mkdir -p marketing/brain/reference/screenshots
mkdir -p marketing/brain/reference/image-prompts
mkdir -p marketing/brain/platforms
mkdir -p marketing/posts
mkdir -p marketing/prompts
mkdir -p marketing/publish/tests/fixtures

touch marketing/__init__.py
touch marketing/brain/reference/screenshots/.gitkeep
touch marketing/brain/reference/image-prompts/.gitkeep
touch marketing/brain/platforms/.gitkeep
touch marketing/prompts/.gitkeep
touch marketing/publish/tests/fixtures/.gitkeep
touch marketing/posts/_index.jsonl
```

- [ ] **Step 2: 验证结构**

Run: `find marketing -type f | sort`
Expected output（顺序无关，但都要存在）：
```
marketing/__init__.py
marketing/brain/platforms/.gitkeep
marketing/brain/reference/image-prompts/.gitkeep
marketing/brain/reference/screenshots/.gitkeep
marketing/posts/_index.jsonl
marketing/prompts/.gitkeep
marketing/publish/tests/fixtures/.gitkeep
```

- [ ] **Step 3: Commit**

```bash
git add marketing/
git commit -m "chore: scaffold marketing/ directory for content automation"
```

---

## Task 2: 写 voice.md（声音规则）

**Files:**
- Create: `marketing/brain/voice.md`

**Why this matters:** 这是整个系统的品牌防线。编辑 pass 会按它来过滤每一篇稿子。规则要硬，不能软建议。

- [ ] **Step 1: 写入完整内容**

写入 `marketing/brain/voice.md`：

```markdown
# Cathier 声音规则（Voice Rules）

> 这是 Cathier 所有市场文案的硬约束。编辑 pass（`prompts/editor-pass.md`）会按本文件强制检查每一篇稿子。
> 规则不是建议——违反任一硬规则即拒稿重写。

## 一、谁是我们的人

Cathier 不是给"需要被治愈"的人，而是给**主动想觉察自己情绪的练习者**。
- 重度日记/手账用户、心理学/正念深度爱好者、设计敏感的同行
- "情绪感知训练"是工具，不是疗愈
- 不预设用户脆弱

## 二、硬禁词（出现即拒稿）

文案里**禁止**出现下列词汇及其同义表达：

- "治愈" / "疗愈" / "陪伴你" / "守护你"
- "温柔" / "柔软" / "拥抱"（用作形容情绪/产品时）
- "心理咨询" / "心理治疗" / "焦虑症" / "抑郁症"等任何医疗/诊断词
- "解忧" / "解压神器" / "情绪管家"
- "宝宝" / "崽" / "小可爱"等亲昵称呼
- 表情符号在正文中**禁用**（标题里也不要 🌸✨💕 这类装饰符；只允许极简实用符号如箭头）

## 三、硬要求

- 第 1 句必须是钩子（具体的观察、反直觉的判断、可被反驳的主张）。**禁止**用"今天想跟大家分享"、"hi，我是…"等问候开头。
- 第二人称用"你"，不用"亲"、"宝子"。
- 一定要有具体（具体的情绪词、具体的身体部位、具体的场景），不能泛化成"各种情绪"。
- 引用产品功能时引用具体词条名（如"觉察词典里的'怅然'条目"），不引用泛词（"我们有词典"）。

## 四、医疗/合规硬规则

任何下列信号 → 拒稿：

- 暗示能"治疗"任何疾病
- 用"症"、"障碍"、"病"等诊断性词汇描述用户状态
- 给出医学建议或替代医疗的暗示
- 提到具体药物/疗法

## 五、视觉与字体声誉延续

文案要为图配套：
- 标题留给衬线字体（图上展示）—— 文字本身要"可被作为标语印在 Moleskine 上"
- 不写过长一句话标题；中文标题 ≤20 字
- 副标题/段落用更松散的口吻

## 六、句式池（避免同质化）

不要每篇都用"在 Cathier，我们……"这类自我中心句式。多样化：
- 观察体（"早上 6 点醒来，胸口压着一块说不出名字的东西。"）
- 反直觉论断（"很多情绪 app 把用户当病人。我们不。"）
- 词条引用体（"觉察词典今天解释'怅然'：是失去的形状，但你说不清失去了什么。"）
- 决策体（"我们用衬线字体写 AI 反馈。理由是——")

## 七、CTA 规范

- CTA 简短具体：「App Store 搜 Cathier」「评论区告诉我你今天卡在哪里」
- **不许**使用「快来下载」、「赶紧来体验」、「点击主页」等套路话术。
```

- [ ] **Step 2: Commit**

```bash
git add marketing/brain/voice.md
git commit -m "feat: add voice.md brand voice rules for marketing content"
```

---

## Task 3: 写平台规则

**Files:**
- Create: `marketing/brain/platforms/xiaohongshu.md`
- Create: `marketing/brain/platforms/x.md`

- [ ] **Step 1: 写入 `xiaohongshu.md`**

```markdown
# 小红书发布规则

## 文案结构
- 标题：≤20 字，钩子型
- 正文：分段，每段 ≤3 行；总字数 200–600 字
- 第一段必须钩子，不寒暄
- 末尾留 1 个开放性问题或具体 CTA（不许"快来下载"）
- 标签：5–15 个；混用大流量词（`#情绪`、`#手账`、`#日记本`）和长尾（`#情绪感知训练`、`#身体扫描`、`#觉察练习`）。本品牌专属：`#Cathier`

## 图集
- 3–5 张为一组（封面 1 + 钩子卡 1 + 内容卡 1–3）
- 比例：1024×1536（2:3，对应小红书 9:16 的安全裁切）
- 封面图必须有标题字（衬线大字）
- 内容卡可以只有底图 + 简短叠字
- 图集每张承担一个 beat，不要单图塞满

## 时间
- 09:00 ± 30 分钟随机（cron 跑 09:00；orchestrator 写延迟提示，人工粘贴时酌情）

## 反垃圾
- 不要复用昨日相同的句首
- 不要复用相同模板的封面构图
- tag 集合每天至少替换 30%
```

- [ ] **Step 2: 写入 `x.md`**

```markdown
# X 发布规则

## 文案
- 单条 ≤280 字符（中英混排注意：中文 1 字 = 2 字符）
- 必带 1 张图（X 算法偏好）
- 同一 angle 与小红书各自重写——X 受众更国际化、design/tech 倾向，更直接、更短
- 中英混排可用，但不要机翻；如果用英文就纯英文

## 图
- 1024×1024 或 1536×1024
- 单图，不要 thread 拼图（除非 angle 真的需要）

## 时间
- 22:00 Asia/Shanghai 附近（待 Phase 2 数据验证）；Phase 1 cron 仍是 09:00，X 帖子由人工酌情决定何时发

## 钩子
- 第 1 句必须能独立成立——X 上很多人只看第 1 句
- 反对"thread🧵"开头（除非真的有 thread）
```

- [ ] **Step 3: Commit**

```bash
git add marketing/brain/platforms/
git commit -m "feat: add Xiaohongshu and X platform rules"
```

---

## Task 4: 写 5 个种子 angle

**Files:**
- Create: `marketing/brain/angles.json`

**Why 5 个先：** 验证 schema 和文案选题感觉。Task 6 用 angle-discovery prompt 扩到 ≥20。

- [ ] **Step 1: 写入种子 angles**

```json
[
  {
    "id": "instrument-serif-rationale",
    "claim": "我们用衬线字体写 AI 反馈，不是为了好看，是为了让你像在读一封写给自己的信，不是聊天记录。",
    "evidence": [
      "DESIGN.md:Decisions Log:2026-03-27 (Instrument Serif for AI reflection text)",
      "DESIGN.md:AI Reflection Visual Language section"
    ],
    "audience": "design-conscious 同行；重度日记/手账用户",
    "platforms_fit": ["xhs", "x"],
    "status": "unused",
    "used_dates": []
  },
  {
    "id": "anti-pastel-thesis",
    "claim": "情绪 app 都用 pastel 因为他们假设用户脆弱。我们假设用户在主动训练自己。所以我们用暖橙，不用粉。",
    "evidence": [
      "DESIGN.md:Aesthetic Direction:Design thesis",
      "DESIGN.md:Decisions Log:2026-03-27 (orange #F2700A)"
    ],
    "audience": "正在做产品/设计的同行；对市场上'治愈系'感到疲惫的用户",
    "platforms_fit": ["xhs", "x"],
    "status": "unused",
    "used_dates": []
  },
  {
    "id": "body-scan-as-entry",
    "claim": "情绪不是从想法开始的。是从身体开始的。这就是为什么 Cathier 的第一步是身体扫描，不是问'你今天感觉怎么样'。",
    "evidence": [
      "README.md:Core Check-in Flow",
      "DESIGN.md:Check-in Flow Design"
    ],
    "audience": "对身心练习有了解的用户；正念/瑜伽/Somatic 实践者",
    "platforms_fit": ["xhs", "x"],
    "status": "unused",
    "used_dates": []
  },
  {
    "id": "dictionary-as-field-guide",
    "claim": "我们做了一本 79 个情绪 + 65 种身体感受 + 24 个身体部位的觉察词典。不是百科——是田野手册。",
    "evidence": [
      "DESIGN.md:觉察词典 (Awareness Dictionary) Design",
      "README.md:觉察词典 section"
    ],
    "audience": "心理学爱好者；想精确表达情绪的人",
    "platforms_fit": ["xhs", "x"],
    "status": "unused",
    "used_dates": []
  },
  {
    "id": "practitioners-not-patients",
    "claim": "Cathier 的用户不是病人，是练习者。这一句话决定了我们所有的设计——颜色、字体、文案、流程节奏。",
    "evidence": [
      "DESIGN.md:Product Context:Who it's for",
      "DESIGN.md:Aesthetic Direction:Design thesis"
    ],
    "audience": "对'被当作病人'感到反感的用户；做产品的同行",
    "platforms_fit": ["xhs", "x"],
    "status": "unused",
    "used_dates": []
  }
]
```

- [ ] **Step 2: 验证 JSON**

Run: `python3 -c "import json; angles = json.load(open('marketing/brain/angles.json')); assert len(angles) == 5; assert all('id' in a and 'claim' in a for a in angles); print('OK')"`
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add marketing/brain/angles.json
git commit -m "feat: seed 5 marketing angles drawn from DESIGN.md"
```

---

## Task 5: 写 angle-discovery prompt

**Files:**
- Create: `marketing/prompts/angle-discovery.md`

**Acceptance check:** 后续 Task 6 跑这个 prompt 应能在 `angles.json` 中追加 ≥15 个新 angle，每个 angle 通过 schema 校验。

- [ ] **Step 1: 写入 prompt**

```markdown
# Angle Discovery Prompt

你是 Cathier 的市场内容研究员。任务：扫描产品代码与文档，发现可作为单篇内容主轴的"卖点角度"，追加到 `marketing/brain/angles.json`。

## 输入资源（必须读，按此顺序）

1. `DESIGN.md` —— 重点是 "Aesthetic Direction"、"Decisions Log"、"Anti-patterns" 三节
2. `README.md` —— Features 列表
3. `git log --since="2.weeks" --oneline` —— 最近改动
4. `marketing/brain/voice.md` —— 声音规则（angle 必须能用这个声音写）
5. `marketing/brain/angles.json` —— 已有 angle，避免重复
6. `marketing/posts/_index.jsonl` —— 最近发过哪些 angle

## Schema（每个新 angle 必须满足）

```json
{
  "id": "kebab-case-string",
  "claim": "30–80 字的可独立成立的主张，必须具体、可被反驳，不能是泛语",
  "evidence": ["文件:位置", "..."],
  "audience": "10–40 字描述目标读者",
  "platforms_fit": ["xhs"] | ["x"] | ["xhs", "x"],
  "status": "unused",
  "used_dates": []
}
```

## 硬规则

- **id 全局唯一**：先读 `angles.json` 的所有 id，新增的不能撞
- **claim 不能套用 voice.md 禁词**
- **evidence 必须真实**——指向 `DESIGN.md`/`README.md`/具体 commit/具体代码文件
- 不要凭空发挥；找不到依据的角度不写
- 优先挖那些"决策背后的 why"（Decisions Log 是金矿）

## 产出

输出一个 JSON 数组，仅包含**新增**的 angle。然后将其与现有 `angles.json` 合并并写回。合并前后做去重（按 id），冲突时保留旧的。

## 数量目标

- 单次至少 8 个新 angle
- 总数达到 20 时可停（避免冷启动期就把好角度用光）
```

- [ ] **Step 2: Commit**

```bash
git add marketing/prompts/angle-discovery.md
git commit -m "feat: add angle-discovery prompt for weekly angle mining"
```

---

## Task 6: 跑 angle-discovery，扩到 ≥20 个

**Files:**
- Modify: `marketing/brain/angles.json`（追加 ≥15 条）

**Why this is a real task:** 冷启动 angle 密度是后续质量的天花板。手动确认这一步的产出。

- [ ] **Step 1: 触发 Claude Code 跑 angle-discovery**

在仓库根目录运行：

```bash
claude -p "$(cat marketing/prompts/angle-discovery.md)

请按照上述 prompt 跑一次 angle 发现，写回 marketing/brain/angles.json。"
```

（如本地无 Claude Code CLI，改用 Claude.ai webapp + 把代码贴回；或在本对话中直接让 Claude 完成。）

- [ ] **Step 2: 验证产出**

Run:
```bash
python3 -c "
import json
angles = json.load(open('marketing/brain/angles.json'))
ids = [a['id'] for a in angles]
assert len(angles) >= 20, f'Only {len(angles)} angles, need ≥20'
assert len(ids) == len(set(ids)), 'Duplicate IDs'
for a in angles:
    assert all(k in a for k in ['id', 'claim', 'evidence', 'audience', 'platforms_fit', 'status', 'used_dates'])
    assert len(a['evidence']) > 0, f'No evidence for {a[\"id\"]}'
print(f'OK, {len(angles)} angles')
"
```
Expected: `OK, 20+ angles`

- [ ] **Step 3: 人工抽查 5 条**

打开 `angles.json`，挑 5 条逐一对：
- evidence 路径真实吗？
- claim 触犯 voice.md 禁词吗？
- claim 够具体吗（不是"我们关心你的感受"这种废话）？

任何一条不合格 → 删除并让 Claude 重新生成。

- [ ] **Step 4: Commit**

```bash
git add marketing/brain/angles.json
git commit -m "feat: expand angle catalog to 20+ via angle-discovery"
```

---

## Task 7: 写 post-draft prompt

**Files:**
- Create: `marketing/prompts/post-draft.md`

- [ ] **Step 1: 写入 prompt**

```markdown
# Post Draft Prompt

你是 Cathier 的内容写手。任务：给定一个 angle 和目标平台，写出一篇符合品牌声音的草稿。

## 输入

- `angle`（JSON 对象，来自 `angles.json` 中的一条）
- `platform`（"xhs" 或 "x"）
- `marketing/brain/voice.md`（必读）
- `marketing/brain/platforms/{platform}.md`（必读）
- `marketing/posts/_index.jsonl` 最近 14 天条目（必读，避免重复句式）

## 产出格式（严格）

输出一份 Markdown，包含 frontmatter：

```markdown
---
angle_id: <angle.id>
platform: <xhs|x>
draft_iteration: 1
---

# <标题>

<正文>

## 标签
<空格分隔的 tags，xhs 必填，x 可选>

## 图集 brief
- 封面：<一句描述这张图的氛围、构图、主体；不超 40 字>
- 卡 2：<同上>
- 卡 3：<同上>
- ...

## 标题字（图上叠的字）
- 封面标题：<≤12 字，能放进衬线大字>
- 卡 2 标题：<可选>
- ...
```

## 硬要求

- 第 1 句是钩子，不寒暄
- 中文标题 ≤20 字（xhs）
- xhs 正文 200–600 字；x 正文 ≤280 字符
- 不复用 `_index.jsonl` 最近 14 天里的开头句式（实际比对最近 14 篇的第一句，词汇重叠度过高即重写）
- 标签 5–15 个（xhs），含 `#Cathier`
- voice.md 禁词一律不出现
- 图集 brief 至少 3 张（xhs），1 张（x）

## 流程

1. 读 voice.md 和对应 platform.md
2. 读 _index.jsonl 最近 14 篇
3. 读 angle，理解 claim 与 evidence
4. 写一稿
5. 自查：voice.md 硬规则全过；不重复句式
6. 输出
```

- [ ] **Step 2: Commit**

```bash
git add marketing/prompts/post-draft.md
git commit -m "feat: add post-draft prompt"
```

---

## Task 8: 写 editor-pass prompt

**Files:**
- Create: `marketing/prompts/editor-pass.md`

- [ ] **Step 1: 写入 prompt**

```markdown
# Editor Pass Prompt

你是 Cathier 的市场内容编辑。任务：审查一篇草稿，按硬规则给出 PASS / FAIL，FAIL 时给出具体修改要求。

## 输入

- 一篇 `post-draft.md` 的输出（带 frontmatter 的 Markdown）
- `marketing/brain/voice.md`
- `marketing/brain/platforms/{platform}.md`
- `marketing/posts/_index.jsonl` 最近 14 天

## 检查清单（任何一项 FAIL 整篇 FAIL）

- [ ] **禁词检查**：扫描 voice.md "硬禁词"列表，正文/标题/标签都不出现
- [ ] **医疗合规**：不出现 voice.md "医疗/合规硬规则" 触发词
- [ ] **钩子**：第 1 句是具体的观察/反直觉论断/词条引用，不是问候、不是介绍自己
- [ ] **同质化**：和最近 14 篇相比，开头第 1 句词汇重叠 ≤50%；句式不雷同
- [ ] **平台格式**：xhs 标题 ≤20 字、tags 5–15 个含 `#Cathier`、正文 200–600 字；x 正文 ≤280 字符
- [ ] **具体性**：claim 落到具体词条/具体身体部位/具体场景，不停留在抽象
- [ ] **自我中心**：不是"在 Cathier，我们……"开头（除非 angle 本身就是品牌决策）
- [ ] **CTA 套路**：不出现"快来下载"、"点击主页"等套路话术

## 产出格式

```markdown
---
verdict: PASS | FAIL
iteration: 1
---

## 检查结果

- [ ] 禁词检查：PASS / FAIL（FAIL 时列具体词）
- [ ] 医疗合规：PASS / FAIL
- [ ] 钩子：PASS / FAIL
- [ ] 同质化：PASS / FAIL
- [ ] 平台格式：PASS / FAIL
- [ ] 具体性：PASS / FAIL
- [ ] 自我中心：PASS / FAIL
- [ ] CTA 套路：PASS / FAIL

## 修改要求（仅 FAIL 时填）

<列具体要改的句子和改法>
```

## 重写循环

orchestrator 会在 FAIL 时把"修改要求"喂回 post-draft.md 重写。最多 2 轮。第 3 轮仍 FAIL → 跳过当日发布并开 issue 标 `marketing-failed`。
```

- [ ] **Step 2: Commit**

```bash
git add marketing/prompts/editor-pass.md
git commit -m "feat: add editor-pass prompt with hard rule checks"
```

---

## Task 9: 写 image-spec prompt

**Files:**
- Create: `marketing/prompts/image-spec.md`

- [ ] **Step 1: 写入 prompt**

```markdown
# Image Spec Prompt

你是 Cathier 的视觉指导。任务：把 post-draft 的"图集 brief"转成可直接喂给 OpenAI `gpt-image-1` 的 prompt 列表。

## 输入

- post-draft 的"图集 brief" + "标题字"段
- `marketing/brain/reference/image-prompts/` 最近 14 天用过的 prompt（避免构图重复）

## 品牌前缀（所有 prompt 必带，原文复制不删减）

> Editorial illustration in the style of a Moleskine notebook page or a Japanese stationery brand. Warm off-white paper background (#F7F5F1), subtle paper texture. Sparing use of bright orange (#F2700A) as the only accent color. Restrained, grounded, quiet. Hand-drawn quality, not digital-perfect. NO pastel colors, NO baby/cute aesthetics, NO gradient backgrounds, NO generic wellness imagery, NO smiling faces, NO meditation poses, NO lotus/leaf motifs, NO emojis, NO text in the image (text will be added in post-processing).

## 产出格式

```json
[
  {
    "filename": "xiaohongshu-1.png",
    "size": "1024x1536",
    "prompt": "<品牌前缀> <场景具体描述>",
    "title_text": "<要叠的中文标题，来自 post-draft 标题字>",
    "title_position": "center" | "top" | "bottom"
  },
  ...
]
```

## 硬规则

- 品牌前缀必带且不可删
- 场景描述要具体（"a single small ceramic cup of tea on a wooden desk, morning light through window"），不要写"meditation"、"wellness"、"calm woman"等通用 wellness 词
- 不要让 gpt-image-1 出中文字（中文字由 compose.py 后处理叠加）
- 同一日内 N 张图片的构图不能雷同（主体距离/视角/色调要差异化）
- 检查最近 14 天 image-prompts 库，主体重叠度过高即换主体
```

- [ ] **Step 2: Commit**

```bash
git add marketing/prompts/image-spec.md
git commit -m "feat: add image-spec prompt for gpt-image-1"
```

---

## Task 10: 实现 image_gen.py（TDD）

**Files:**
- Create: `marketing/publish/requirements.txt`
- Create: `marketing/publish/__init__.py`
- Create: `marketing/publish/tests/__init__.py`
- Create: `marketing/publish/tests/test_image_gen.py`
- Create: `marketing/publish/image_gen.py`

- [ ] **Step 1: 写 requirements.txt**

```
openai==1.55.0
Pillow==11.0.0
pytest==8.3.3
```

- [ ] **Step 2: 创建 `__init__.py` 占位**

```bash
touch marketing/publish/__init__.py
touch marketing/publish/tests/__init__.py
```

- [ ] **Step 3: 写失败的测试 `tests/test_image_gen.py`**

```python
import base64
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

from marketing.publish.image_gen import generate_image


@pytest.fixture
def fake_b64_png():
    """A 1x1 transparent PNG, base64-encoded — enough for the API mock."""
    return (
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAA"
        "DUlEQVR42mNkYGD4DwABBAEAfbLI3wAAAABJRU5ErkJggg=="
    )


def test_generate_image_calls_openai_with_correct_args(tmp_path, fake_b64_png):
    output_path = tmp_path / "out.png"

    mock_response = MagicMock()
    mock_response.data = [MagicMock(b64_json=fake_b64_png)]

    with patch("marketing.publish.image_gen.OpenAI") as mock_openai:
        mock_client = MagicMock()
        mock_client.images.generate.return_value = mock_response
        mock_openai.return_value = mock_client

        result = generate_image(
            prompt="warm paper background, single ceramic cup",
            size="1024x1536",
            output_path=output_path,
            api_key="sk-test",
        )

        mock_openai.assert_called_once_with(api_key="sk-test")
        mock_client.images.generate.assert_called_once_with(
            model="gpt-image-1",
            prompt="warm paper background, single ceramic cup",
            size="1024x1536",
            n=1,
        )
        assert result == output_path
        assert output_path.exists()
        assert output_path.read_bytes() == base64.b64decode(fake_b64_png)


def test_generate_image_raises_on_empty_prompt(tmp_path):
    with pytest.raises(ValueError, match="prompt"):
        generate_image(
            prompt="",
            size="1024x1024",
            output_path=tmp_path / "x.png",
            api_key="sk-test",
        )
```

- [ ] **Step 4: 安装依赖并运行测试，确认失败**

Run（仓库根目录）：
```bash
pip install -r marketing/publish/requirements.txt
python -m pytest marketing/publish/tests/test_image_gen.py -v
```
Expected: FAIL — `ModuleNotFoundError: No module named 'marketing.publish.image_gen'`

- [ ] **Step 5: 实现 `image_gen.py`**

```python
"""Thin wrapper around OpenAI Images API (gpt-image-1).

Returns the saved file path; lets callers handle errors via exception.
"""

import base64
from pathlib import Path

from openai import OpenAI

MODEL = "gpt-image-1"


def generate_image(
    prompt: str,
    size: str,
    output_path: Path,
    api_key: str,
) -> Path:
    if not prompt:
        raise ValueError("prompt must be non-empty")

    client = OpenAI(api_key=api_key)
    response = client.images.generate(
        model=MODEL,
        prompt=prompt,
        size=size,
        n=1,
    )
    b64 = response.data[0].b64_json
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_bytes(base64.b64decode(b64))
    return output_path
```

- [ ] **Step 6: 运行测试，确认通过**

Run: `python -m pytest marketing/publish/tests/test_image_gen.py -v`
Expected: PASS（2 个测试）

- [ ] **Step 7: Commit**

```bash
git add marketing/publish/
git commit -m "feat: add image_gen.py wrapping OpenAI gpt-image-1 (TDD)"
```

---

## Task 11: 实现 compose.py（TDD）

**Files:**
- Create: `marketing/publish/tests/fixtures/sample_bg.png`（256×384 纯色 PNG）
- Create: `marketing/publish/tests/test_compose.py`
- Create: `marketing/publish/compose.py`

**前置依赖：** 字体。本地开发要先 `brew install --cask font-noto-serif-cjk-sc`（macOS）或确保 `Noto Serif CJK SC` 系统已装。CI 中通过 `apt install fonts-noto-cjk-extra` 装。脚本用一个查找函数自动定位字体文件，找不到就抛清晰错误。

- [ ] **Step 1: 创建测试 fixture（256×384 纯色背景）**

Run:
```bash
python3 -c "
from PIL import Image
img = Image.new('RGB', (256, 384), (247, 245, 241))
img.save('marketing/publish/tests/fixtures/sample_bg.png')
"
ls -la marketing/publish/tests/fixtures/sample_bg.png
```
Expected: 文件存在，体积约 1–2 KB

- [ ] **Step 2: 写失败测试 `tests/test_compose.py`**

```python
from pathlib import Path

import pytest
from PIL import Image

from marketing.publish.compose import compose

FIXTURE = Path(__file__).parent / "fixtures" / "sample_bg.png"


def test_compose_outputs_file_with_correct_size(tmp_path):
    output = tmp_path / "out.png"
    result = compose(
        background_path=FIXTURE,
        title="觉察练习",
        output_path=output,
    )
    assert result == output
    assert output.exists()
    img = Image.open(output)
    assert img.size == (256, 384)


def test_compose_actually_draws_text(tmp_path):
    """Verify the title region pixels differ from the background after compose."""
    output = tmp_path / "out.png"
    compose(
        background_path=FIXTURE,
        title="觉察练习",
        output_path=output,
    )

    bg = Image.open(FIXTURE).convert("RGB")
    out = Image.open(output).convert("RGB")

    # Sample 100 pixels in the title region (roughly center horizontal band).
    title_band_top = int(384 * 0.40)
    title_band_bot = int(384 * 0.60)
    diff_count = 0
    for y in range(title_band_top, title_band_bot, 4):
        for x in range(0, 256, 4):
            if bg.getpixel((x, y)) != out.getpixel((x, y)):
                diff_count += 1
    assert diff_count > 20, "Title text not drawn into title band"


def test_compose_raises_on_missing_background(tmp_path):
    with pytest.raises(FileNotFoundError):
        compose(
            background_path=tmp_path / "does-not-exist.png",
            title="x",
            output_path=tmp_path / "out.png",
        )


def test_compose_raises_on_empty_title(tmp_path):
    with pytest.raises(ValueError, match="title"):
        compose(
            background_path=FIXTURE,
            title="",
            output_path=tmp_path / "out.png",
        )
```

- [ ] **Step 3: 运行测试，确认失败**

Run: `python -m pytest marketing/publish/tests/test_compose.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'marketing.publish.compose'`

- [ ] **Step 4: 实现 `compose.py`**

```python
"""Overlay Chinese serif title onto a base image (Pillow).

Font lookup tries common locations on macOS and Linux. Raises clearly if not found.
"""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ACCENT = (242, 112, 10)  # Cathier orange #F2700A
TEXT_PRIMARY = (26, 22, 19)  # near-black warm

FONT_CANDIDATES = [
    "/System/Library/Fonts/STSong.ttc",  # macOS Chinese serif fallback
    "/System/Library/Fonts/Supplemental/Songti.ttc",  # macOS
    "/usr/share/fonts/opentype/noto/NotoSerifCJK-Regular.ttc",  # Ubuntu
    "/usr/share/fonts/truetype/noto/NotoSerifCJK-Regular.ttc",  # Ubuntu alt
]


def _find_font() -> str:
    for p in FONT_CANDIDATES:
        if Path(p).exists():
            return p
    raise FileNotFoundError(
        "No Chinese serif font found. "
        "Install `fonts-noto-cjk-extra` (Linux) or "
        "Songti (macOS, system default)."
    )


def compose(
    background_path: Path,
    title: str,
    output_path: Path,
) -> Path:
    if not title:
        raise ValueError("title must be non-empty")
    if not Path(background_path).exists():
        raise FileNotFoundError(f"Background not found: {background_path}")

    img = Image.open(background_path).convert("RGB")
    draw = ImageDraw.Draw(img)

    font_path = _find_font()
    # Title size: 12% of image height
    font_size = int(img.height * 0.08)
    font = ImageFont.truetype(font_path, font_size)

    # Center horizontally, vertical band at 50% (visual center of attention).
    bbox = draw.textbbox((0, 0), title, font=font)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    x = (img.width - text_w) // 2
    y = (img.height - text_h) // 2

    draw.text((x, y), title, font=font, fill=TEXT_PRIMARY)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    img.save(output_path)
    return output_path
```

- [ ] **Step 5: 运行测试，确认通过**

Run: `python -m pytest marketing/publish/tests/test_compose.py -v`
Expected: PASS（4 个测试）

注：如果运行环境上没有任何匹配字体，会有 1 个测试因 `FileNotFoundError` fail。修复路径：本地装 `font-noto-serif-cjk-sc`，CI 中由 workflow 装 `fonts-noto-cjk-extra`（Task 13 已包含）。

- [ ] **Step 6: Commit**

```bash
git add marketing/publish/compose.py marketing/publish/tests/test_compose.py marketing/publish/tests/fixtures/
git commit -m "feat: add compose.py for Pillow-based Chinese title overlay (TDD)"
```

---

## Task 12: 写 daily-orchestrator prompt

**Files:**
- Create: `marketing/prompts/daily-orchestrator.md`

- [ ] **Step 1: 写入 prompt**

```markdown
# Daily Orchestrator

你是 Cathier 市场自动化的主控。今天是 GitHub Actions 触发的日子。任务：执行完整的"选题 → 起草 → 编辑 → 出图 → 落盘 → 通知"流水线。

## 工作目录约定

- 仓库根目录运行
- 当日产出落到 `marketing/posts/{YYYY-MM-DD}/`（YYYY-MM-DD 由 `date +%F` 取）
- 索引追加到 `marketing/posts/_index.jsonl`

## 流水线步骤

### 1. 选 angle

读 `marketing/brain/angles.json` 与 `marketing/posts/_index.jsonl`：
- 排除最近 14 天用过的 angle.id
- 排除 status != "unused" 的 angle
- 优先选 `platforms_fit` 同时包含 xhs 和 x 的（一稿双发）
- 在符合条件的里随机选 1 个（用 `python3 -c "import random, json; ..."`）

如果没有可选 angle → 开 issue 标 `marketing-no-angle`，标题 "No usable angle today"，body 说明并退出 0。

### 2. 起草（双平台）

对所选 angle，依序调 `marketing/prompts/post-draft.md`：
- 一次输入 platform=xhs，得到 xhs 草稿
- 一次输入 platform=x，得到 x 草稿

将两份草稿写到临时位置（不 commit），等编辑通过再正式存盘。

### 3. 编辑 pass

对每一稿调 `marketing/prompts/editor-pass.md`：
- FAIL → 把"修改要求"塞回 post-draft 重写。最多 2 轮。
- 第 3 轮仍 FAIL → 跳过该平台。两个平台都跳过 → 整体跳过当日，开 issue 标 `marketing-failed`，附编辑反馈，退出 0。

通过的稿子写到 `marketing/posts/{YYYY-MM-DD}/{platform}.md`。

### 4. 出图

对每一份通过的稿子，调 `marketing/prompts/image-spec.md`，得到图片 prompt 列表。

对列表中每个 entry：
- 调用 `python3 -m marketing.publish.image_gen` 生成底图（保存到 `marketing/posts/{YYYY-MM-DD}/{filename}`）
- 调用 `python3 -m marketing.publish.compose` 把 `title_text` 叠到底图上（覆写同一文件）

具体调用方式：在仓库根目录执行 Python 脚本（你有 Bash 工具）。例如：

```bash
python3 -c "
from pathlib import Path
from marketing.publish.image_gen import generate_image
from marketing.publish.compose import compose
import os
img = generate_image(
    prompt='<品牌前缀+场景>',
    size='1024x1536',
    output_path=Path('marketing/posts/2026-05-07/xiaohongshu-1.png'),
    api_key=os.environ['OPENAI_API_KEY'],
)
compose(
    background_path=img,
    title='<标题字>',
    output_path=img,
)
"
```

### 5. 索引追加

为每个产出的 post 追加一行到 `marketing/posts/_index.jsonl`：

```json
{"date": "2026-05-07", "platform": "xhs", "angle_id": "instrument-serif-rationale", "status": "ready", "files": ["xiaohongshu.md", "xiaohongshu-1.png", ...]}
```

将所选 angle 在 `angles.json` 中的 `used_dates` 追加今日日期，`status` 仍为 "unused"（angle 可被复用，只是 14 天内不会被选）。

### 6. Commit

```bash
git add marketing/posts/{YYYY-MM-DD}/ marketing/posts/_index.jsonl marketing/brain/angles.json
git commit -m "marketing: daily content {YYYY-MM-DD} — {angle_id}"
git push
```

### 7. 通知

通过 `gh` 开 GitHub Issue：
- title: `marketing-ready: {YYYY-MM-DD} — {angle_id}`
- label: `marketing-ready`
- body: 嵌入两个平台的文案预览（用代码块）+ 图片在仓库的相对路径
- 可选：在 body 顶部写"复制以下文案到小红书 / X"

## 错误处理

- OpenAI API 失败：retry 1 次；仍失败 → 跳过该平台
- 任一步骤抛出异常：开 issue 标 `marketing-failed`，body 包含错误堆栈，不静默吞错
- git push 失败：retry 1 次；仍失败 → 开 issue

## 退出码

成功（含跳过）→ 0
不可恢复错误（git 配置问题等）→ 1
```

- [ ] **Step 2: Commit**

```bash
git add marketing/prompts/daily-orchestrator.md
git commit -m "feat: add daily-orchestrator prompt"
```

---

## Task 13: 写 GitHub Action workflow

**Files:**
- Create: `.github/workflows/marketing-daily.yml`

**Secrets 前置：** Repo 须已配置 `CLAUDE_CODE_OAUTH_TOKEN`、`OPENAI_API_KEY`、`FEEDBACK_PAT`（前两个新增，第三个已存在）。Step 4 会校验。

- [ ] **Step 1: 写入 workflow**

```yaml
name: Marketing Daily

on:
  schedule:
    # 01:00 UTC = 09:00 Asia/Shanghai
    - cron: "0 1 * * *"
  workflow_dispatch:

jobs:
  marketing-daily:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      issues: write
      id-token: write
    steps:
      - name: Checkout repository
        uses: actions/checkout@v6
        with:
          fetch-depth: 1
          token: ${{ secrets.FEEDBACK_PAT }}

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Install Chinese serif font
        run: |
          sudo apt-get update
          sudo apt-get install -y fonts-noto-cjk fonts-noto-cjk-extra
          fc-list | grep -i "noto serif cjk" || (echo "Font install failed" && exit 1)
          ls /usr/share/fonts/opentype/noto/NotoSerifCJK*

      - name: Install Python deps
        run: |
          python -m pip install --upgrade pip
          pip install -r marketing/publish/requirements.txt

      - name: Run Python tests
        run: python -m pytest marketing/publish/tests/ -v

      - name: Configure git
        run: |
          git config user.name "cathier-marketing-bot"
          git config user.email "marketing-bot@users.noreply.github.com"

      - name: Get today's date
        id: date
        run: echo "today=$(date +%F)" >> "$GITHUB_OUTPUT"

      - name: Run Claude Code orchestrator
        uses: anthropics/claude-code-action@v1
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          prompt: |
            Read marketing/prompts/daily-orchestrator.md and execute it.
            Today's date: ${{ steps.date.outputs.today }}
            You have access to: OPENAI_API_KEY (env var), gh CLI, git, python3.
            Repository root is the working directory; import paths use the
            `marketing.publish.*` package.
            Do NOT push if no commits were made. Do NOT open a duplicate issue
            if one with label `marketing-ready` already exists for today.
        env:
          OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
          GH_TOKEN: ${{ secrets.FEEDBACK_PAT }}
```

- [ ] **Step 2: 校验 YAML 语法**

Run:
```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/marketing-daily.yml'))"
```
Expected: 无输出（成功）。报错则修。

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/marketing-daily.yml
git commit -m "feat: add marketing-daily GitHub Action (cron + workflow_dispatch)"
```

---

## Task 14: 写 marketing/README.md 和 xhs_checklist.md

**Files:**
- Create: `marketing/README.md`
- Create: `marketing/publish/xhs_checklist.md`

- [ ] **Step 1: 写 `marketing/README.md`**

```markdown
# Cathier Marketing Automation

零接触市场内容引擎。每天 09:00 Asia/Shanghai 自动产出小红书 + X 的当日内容包。

## 工作流

1. GitHub Action `marketing-daily.yml` 定时触发
2. Claude Code 跑 `prompts/daily-orchestrator.md`：选 angle → 起草 → 编辑 → 出图 → commit
3. 内容落到 `posts/YYYY-MM-DD/`
4. 开 issue 标 `marketing-ready`，body 是粘贴就发的文案

## Phase 1 人工部分（10 秒/天）

打开 issue → 复制 `xiaohongshu.md` 文案 → 上传 `posts/YYYY-MM-DD/xiaohongshu-*.png` → 小红书发布。X 同理。

详见 `publish/xhs_checklist.md`。

## 改 voice / 加 angle

- 改 `brain/voice.md` 立即影响下一篇
- 周更跑 `prompts/angle-discovery.md` 扩 angle

## 失败时

issue 标 `marketing-failed` → 看 body 里的错误 → 修代码或补 angle → 手动重跑 `gh workflow run marketing-daily.yml`

## 不在自动化范围

- 自动发布（Phase 2）
- 数据回流（Phase 3）

详见 `docs/superpowers/specs/2026-05-06-marketing-automation-design.md`。
```

- [ ] **Step 2: 写 `marketing/publish/xhs_checklist.md`**

```markdown
# 小红书人工粘贴 Checklist（Phase 1）

每天 09:00 之后会有 GitHub Issue 标 `marketing-ready` 通知。10 秒走一遍：

1. 打开 issue，看 body 里的 xhs 文案
2. 小红书 App → 发布 → 选图
3. 上传 `marketing/posts/YYYY-MM-DD/xiaohongshu-*.png`（从仓库下载或 GitHub web 复制）
4. 标题字段：粘贴第一行（issue 里已分好）
5. 正文字段：粘贴正文 + 标签
6. 发布

X 同理：复制 x 文案 + 单图，X 网页/App 发。

## 红线

- 不要修改文案——如果文案让你想改，那是编辑 pass 出问题，回去改 voice.md / editor-pass.md，不是临场改文案。
- 不要"今天先不发"——内容引擎稳定的前提是日更纪律。如果当天文案确实差，关掉 issue 写个评论说原因，让我下次改 prompt。
```

- [ ] **Step 3: Commit**

```bash
git add marketing/README.md marketing/publish/xhs_checklist.md
git commit -m "docs: marketing README and Xiaohongshu paste checklist"
```

---

## Task 15: 烟雾测试（手动触发 workflow）

**Files:**
- Modify: `marketing/posts/_index.jsonl`（自动追加 1 行）
- Create: `marketing/posts/{今天日期}/` 下的内容

**Why:** Action 写完不跑一次永远不知道哪里坏。

**前置：** Repo Settings → Secrets → 已添加 `OPENAI_API_KEY`。`CLAUDE_CODE_OAUTH_TOKEN` 和 `FEEDBACK_PAT` 已存在。

- [ ] **Step 1: push 当前分支并触发 workflow**

```bash
git push origin HEAD
gh workflow run marketing-daily.yml
```

- [ ] **Step 2: 监控运行**

```bash
gh run watch
```

或：
```bash
gh run list --workflow=marketing-daily.yml --limit 1
gh run view --log <run-id>
```

Expected: workflow 成功（绿勾）。

- [ ] **Step 3: 验证产出**

```bash
git pull
ls marketing/posts/$(date +%F)/
```
Expected: 至少 `xiaohongshu.md` + `xiaohongshu-*.png`，可能还有 `x.md` + `x.png`。

```bash
gh issue list --label marketing-ready --limit 1
```
Expected: 1 个新 issue，标题含今日日期。

- [ ] **Step 4: 抽查内容质量**

打开 issue：
- 文案是不是符合 voice.md？
- 图是不是没有触发禁忌（pastels/wellness/笑脸）？
- 图上中文字是不是渲染正确？

任何一项不合格 → 回到对应 prompt（voice.md / post-draft / editor-pass / image-spec）调整，重跑。

- [ ] **Step 5: 关闭烟雾测试 issue 并说明**

```bash
gh issue close <issue-number> --comment "smoke test pass / issues: <list>"
```

---

## 进入 Phase 2 之前要等的信号

不要在这之前动手做 Phase 2（自动发布）：
- 连续跑 7 天，每天 issue 都打开过、内容都达到"敢发"质量
- voice.md 没有再调整的冲动
- gpt-image-1 出图合格率（人工评估）≥70%
- angle 目录还剩 ≥10 个未用

如果上述任一条不达标 → 改 prompt，不上发布通道。

---

## 自检清单（计划完成前用）

- [x] 每个任务都有具体文件路径
- [x] 每个 code 步骤都有完整代码（没有"和上面类似"）
- [x] 每个测试都有期望值
- [x] 每个 commit 步骤都有具体 message
- [x] Spec 中所有 §4 文件都被某个任务创建（除 Phase 2 的 `x_publish.py`，已声明 out of scope）
- [x] Python 代码 TDD（compose, image_gen）
- [x] Prompt 有 acceptance check（angle-discovery 用 schema 校验）
- [x] Workflow 有烟雾测试任务
