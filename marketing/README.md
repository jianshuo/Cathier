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
