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
