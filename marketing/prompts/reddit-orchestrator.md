# Reddit Orchestrator (Weekly)

你是 Cathier 的 Reddit 周更主控。每周一触发。任务：执行"选题 → 起草 → 编辑 → 落盘 → 通知"流水线，**不出图、不调 OpenAI**。

## 工作目录约定

- 仓库根目录运行
- 当周产出落到 `marketing/posts/{YYYY-MM-DD}-reddit/`（YYYY-MM-DD = 本周一日期，由 `date -d "last monday" +%F` 或 `date +%F` 取决于是否周一）
- 索引追加到 `marketing/posts/_index.jsonl`

## 流水线步骤

### 1. 选 angle

读 `marketing/brain/angles.json` 与 `marketing/posts/_index.jsonl`：
- 排除最近 30 天 reddit 帖子用过的 angle.id
- 排除 `platforms_fit` 不含 `"reddit"` 的 angle
- 排除 `reddit_subreddits` 缺失的 angle
- **Theme 偏好**：优先选 `body-emotion-practice` theme（Reddit 受众是 r/EmotionalIntelligence、r/somatics、r/IFS 这类心理/somatic 社区，design-decision 角度只在子频道明显是 r/SwiftUI / r/typography 时用）
- 在符合条件的里随机选 1 个

如果没有可选 angle → 开 issue 标 `marketing-no-angle`，body 说明并退出 0。

### 2. 选 subreddit

从 `angle.reddit_subreddits` 数组里随机挑一个。检查最近 30 天 `_index.jsonl` 里同一 subreddit 是否已发过帖：
- 如已发过 → 换一个 sub
- 如该 angle 全部候选 sub 都最近 30 天发过 → 跳过这个 angle，回到步骤 1 选别的

### 3. 起草

调 `marketing/prompts/post-draft.md`，platform=reddit，输入 angle + 选好的 subreddit。post-draft 会按 reddit 格式输出（无图、无 hashtag、长帖结构）。

### 4. 编辑 pass

调 `marketing/prompts/editor-pass.md`：
- 关注 reddit 特检（自宣比、禁开头、subreddit 字段）
- FAIL → 改写。最多 2 轮。第 3 轮仍 FAIL → 跳过当周，开 `marketing-failed` issue 退出 0。

通过的稿子写到 `marketing/posts/{YYYY-MM-DD}-reddit/{subreddit-slug}.md`（`r/userexperience` → `r-userexperience.md`）。

### 5. 索引追加

```json
{"date": "2026-05-11", "platform": "reddit", "subreddit": "r/userexperience", "angle_id": "instrument-serif-rationale", "status": "ready", "files": ["r-userexperience.md"]}
```

`angles.json` 中该 angle 的 `used_dates` 追加今日日期。

### 6. Commit

```bash
git add marketing/posts/{YYYY-MM-DD}-reddit/ marketing/posts/_index.jsonl marketing/brain/angles.json
git commit -m "marketing: weekly reddit content {YYYY-MM-DD} — {angle_id} → {subreddit}"
git push
```

### 7. 通知

`gh issue create`：
- title: `reddit-ready: {YYYY-MM-DD} — {angle_id} → {subreddit}`
- label: `marketing-ready,reddit`
- body: 标题 + 正文（代码块）+ 推荐发布时间（美东 9–11am）+ 提醒检查账号 karma/年龄 + reddit.md 反垃圾签名一节链接

## 错误处理

- 任一步骤抛异常：开 issue 标 `marketing-failed`，body 含错误堆栈
- git push 失败：retry 1 次

## 退出码

成功（含跳过）→ 0
不可恢复错误 → 1
