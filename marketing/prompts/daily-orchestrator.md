# Daily Orchestrator

你是 Cathier 市场自动化的主控。今天是 GitHub Actions 触发的日子。任务：执行完整的"选题 → 起草 → 编辑 → 出图 → 落盘 → 通知"流水线。

## 工作目录约定

- 仓库根目录运行
- 当日产出落到 `marketing/posts/{YYYY-MM-DD}/`（YYYY-MM-DD 由 `date +%F` 取）
- 索引追加到 `marketing/posts/_index.jsonl`

## 流水线步骤

## 平台范围

本编排负责的是 **4 个带图日更平台**：
- xhs（中文母体）
- x（英文短刺）
- instagram（英文视觉）
- facebook（英文老年友好）

reddit 是另一条流水线（`reddit-orchestrator.md` + `marketing-weekly-reddit.yml`），周一才跑，本编排不管。

### 1. 选 angle

读 `marketing/brain/angles.json` 与 `marketing/posts/_index.jsonl`：
- 排除最近 14 天用过的 angle.id
- 排除 status != "unused" 的 angle
- 优先选 `platforms_fit` 同时包含 ≥3 个本编排平台（xhs/x/instagram/facebook）的（一稿四发）
- 退而求其次：≥2 个本编排平台

**Theme 平衡：**
每条 angle 有 `theme` 字段（`body-emotion-practice` / `product-feature` / `design-decision`）。期望发文比例约 70/20/10。

读最近 14 天 `_index.jsonl`，统计各 theme 已发数量：
- 如 `body-emotion-practice` 占比 < 60%，本次必选该 theme
- 如 `design-decision` 占比 > 15%，本次跳过该 theme
- 否则随机加权（70/20/10）

在符合上述条件的池子里随机选 1 个。

如果没有可选 angle → 开 issue 标 `marketing-no-angle`，body 说明并退出 0。

### 2. 起草（多平台并行）

对所选 angle，依次调 `marketing/prompts/post-draft.md`，目标平台 = `angle.platforms_fit ∩ {xhs, x, instagram, facebook}`：
- 一次 platform=xhs（如 angle 支持）
- 一次 platform=x（如 angle 支持）
- 一次 platform=instagram（如 angle 支持）
- 一次 platform=facebook（如 angle 支持）

将草稿写到临时位置（不 commit），等编辑通过再正式存盘。

### 3. 编辑 pass

对每一稿调 `marketing/prompts/editor-pass.md`：
- FAIL → 把"修改要求"塞回 post-draft 重写。最多 2 轮。
- 第 3 轮仍 FAIL → 跳过该平台。所有平台都跳过 → 整体跳过当日，开 issue 标 `marketing-failed`，附编辑反馈，退出 0。

通过的稿子写到 `marketing/posts/{YYYY-MM-DD}/{platform}.md`。

### 4. 出图

对每一份通过的稿子，调 `marketing/prompts/image-spec.md`，得到图片 prompt 列表。

**省钱合并：** 如果 x / instagram / facebook 同时通过 + 同 size + image-spec 的场景描述能合并，把它们合成一次底图调用，三份输出。每份再各自 compose（标题字可能不同）。

对列表中每个 entry，在仓库根目录用 `python3 -c` 执行（你有 Bash 工具）。两个模块没有 CLI 入口，必须通过 import 调用。例如：

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
    title_position='center',  # 也可 'top' / 'bottom'，由 image-spec 输出决定
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
- body: 按平台分段（xhs / x / instagram / facebook 各一节），每节嵌入文案（代码块）+ 图片相对路径
- body 顶部写一个"粘贴顺序"清单：先发哪个、后发哪个，例如：
  - 立刻：xhs（北京时间 9 点）
  - 早 12 点（美东 9 点）：instagram、facebook
  - 晚 22 点（美东 11 点）：x

## 错误处理

- OpenAI API 失败：retry 1 次；仍失败 → 跳过该平台
- 任一步骤抛出异常：开 issue 标 `marketing-failed`，body 包含错误堆栈，不静默吞错
- git push 失败：retry 1 次；仍失败 → 开 issue

## 退出码

成功（含跳过）→ 0
不可恢复错误（git 配置问题等）→ 1
