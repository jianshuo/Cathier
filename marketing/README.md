# Cathier Marketing Automation

零接触市场内容引擎，跑 5 个平台。

## 节奏

| 平台 | 频率 | 母语 | 工作流 |
|---|---|---|---|
| 小红书 | 每天 06:00 Asia/Shanghai | 中文 | `marketing-daily.yml` |
| X | 每天 06:00 | 英文 | `marketing-daily.yml` |
| Instagram | 每天 06:00 | 英文 | `marketing-daily.yml` |
| Facebook | 每天 06:00 | 英文 | `marketing-daily.yml` |
| Reddit | 每周一 10:00 | 英文 | `marketing-weekly-reddit.yml` |

同日多次运行（cron + 手动 dispatch，或多次 dispatch）允许并存：首跑落到 `posts/YYYY-MM-DD/`，再跑落到 `posts/YYYY-MM-DD-HHMM/`（北京时间），互不覆盖，每次都开独立 issue。

## 工作流

1. cron 触发 GitHub Action
2. Claude Code 跑对应 orchestrator（`prompts/daily-orchestrator.md` 或 `prompts/reddit-orchestrator.md`）
3. 选 angle → 起草（每个适配平台一份）→ 编辑 pass → 出图（reddit 跳过）→ commit
4. 内容落到 `posts/YYYY-MM-DD/`（reddit 落到 `posts/YYYY-MM-DD-reddit/`）
5. 开 issue 标 `marketing-ready`（reddit 加 `reddit` label）

## Phase 1 人工部分

打开 issue → body 是按平台分段的文案 + 图片相对路径 → 复制粘贴到对应 App 发。
推荐发布顺序：xhs 立即（北京 6 点）→ instagram/facebook 中午（美东 9 点）→ x 晚上（美东 11 点）→ reddit 美东上午（周一）。

详见 `publish/xhs_checklist.md`。

## 改 voice / 加 angle / 改平台规则

- 改 `brain/voice.md` 立即影响下一篇
- 改 `brain/platforms/{platform}.md` 同理
- 周更跑 `prompts/angle-discovery.md` 扩 angle

## 失败时

issue 标 `marketing-failed` → 看 body 里的错误 → 修代码或补 angle → 手动重跑：
```bash
gh workflow run marketing-daily.yml             # daily 4 platforms
gh workflow run marketing-weekly-reddit.yml     # reddit
```

## 不在自动化范围

- 自动发布（Phase 2）—— 当前所有平台都是人工 10 秒粘贴
- 数据回流（Phase 3）

详见 `docs/superpowers/specs/2026-05-06-marketing-automation-design.md`。
