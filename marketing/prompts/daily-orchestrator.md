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
