# Cathier — Project Claude Instructions

## gstack

Use the `/browse` skill from gstack for all web browsing. Never use `mcp__claude-in-chrome__*` tools.

Available gstack skills:
- `/plan-ceo-review` — Review plan from CEO perspective
- `/plan-eng-review` — Review plan from engineering perspective
- `/review` — Code review
- `/ship` — Ship a feature end-to-end
- `/browse` — Web browsing (use this instead of any MCP browser tools)
- `/qa` — QA testing
- `/qa-only` — QA without code changes
- `/setup-browser-cookies` — Set up browser cookies for authenticated browsing
- `/retro` — Retrospective

If gstack skills aren't working, run `cd .claude/skills/gstack && ./setup` to build the binary and register skills.

## Design System

Always read `DESIGN.md` before making any visual or UI decisions.
All font choices, colors, spacing, and aesthetic direction are defined there.
Do not deviate without explicit user approval.
In QA mode, flag any code that doesn't match DESIGN.md.
