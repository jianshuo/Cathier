# TODOS

## Insights Feature

### Living Pattern Engine (Approach C)
**Priority:** P3
**What:** Compute emotion×trigger correlations and intensity×weekday patterns in pure Swift; feed computed results to Claude for narration. Updates after each new check-in rather than re-sending full history.
**Why:** Once the app has 30+ check-ins, native math finds patterns faster and cheaper than sending all history to Claude on every analysis tap.
**Pros:** Free computation, instant results, cheaper API calls, updates passively.
**Cons:** Significant complexity; needs enough data to produce meaningful correlations; risk of over-engineering before validating what patterns users care about.
**Context:** Depends on On-Demand Pattern Analysis (Approach B) shipping first. Don't start until real usage data shows which correlations feel most meaningful to the user.
**Depends on:** Approach B (pattern analysis via full history send) shipped and validated.

---

### Insights Sharing with Friends
**Priority:** P4
**What:** Decide if and how pattern insight narratives can be shared with friends via CloudKit, analogous to per-check-in AI feedback sharing.
**Why:** Shared long-term patterns could deepen the social layer — friends seeing each other's emotional trajectories over weeks.
**Pros:** Stronger social connection; differentiating feature.
**Cons:** Long-term patterns are more sensitive than single check-ins; new privacy model needed (pattern insights shouldn't be shared at "category" tier — they reveal too much). Requires careful UX design.
**Context:** Only worth exploring after Approach B ships. The privacy framework for insights needs design before any implementation starts.
**Depends on:** Approach B shipped; privacy model designed.

---

## Completed

---

### Context Brief for Claude
**Priority:** P2
**What:** Add a "About me" field in Settings (2-3 sentences about life situation, job, current challenges). Injected into pattern analysis system prompt.
**Why:** Claude currently knows nothing about you beyond raw emotional data. Personal context transforms generic patterns into personally relevant insights (e.g., "chest tightness on Sunday evenings" → "work-related anxiety before the week").
**Pros:** Dramatically improves insight quality; S-effort; reuses existing SettingsView + UserDefaults pattern.
**Cons:** Requires user to write something; blank field = no improvement.
**Context:** Decided in /plan-ceo-review session on 2026-03-20. Moved from deferred → in-scope after review.
**Effort:** S (human: ~2h / CC: ~10min)
**Depends on:** On-Demand Pattern Analysis (Approach B) being implemented first.

---

### Insight History Storage Migration
**Priority:** P3
**What:** Migrate insight history from UserDefaults JSON array to a SwiftData entity when entry count exceeds ~50.
**Why:** UserDefaults loads entirely into memory at app launch. Large JSON arrays (500+ analyses) are an iOS anti-pattern. 50 analyses ≈ 2+ years of weekly use, so this is not urgent.
**Pros:** Proper data model; enables future querying; aligns with existing SwiftData usage.
**Cons:** Requires migration logic; adds a new SwiftData schema change.
**Context:** Decided in /plan-ceo-review on 2026-03-20. UserDefaults cap was explicitly declined — this TODO captures the future migration path.
**Effort:** M (human: ~1 day / CC: ~20min)
**Depends on:** Using Insights feature long enough to accumulate 50+ analyses.
