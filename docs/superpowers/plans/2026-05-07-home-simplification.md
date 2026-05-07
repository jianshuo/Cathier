# Home Simplification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Strip `TodayView` from 14 sections back to ~6, move analytics into `JournalView` top, and surface entertainment/utility (joke, AI frontier, BrainTrainer, Health) under Settings → 探索 — all while keeping the app working at every commit.

**Architecture:** Pure SwiftUI refactor. No new business logic. Three preparatory steps extract reusable view components. The detail-view trio (BrainTrainer / JokeHistory / HealthInsight) gets split into NavigationLink-friendly content + (transient) sheet wrapper, so both old (sheet) and new (push) callers work simultaneously through the transition. Today is slimmed last so functionality is reachable from a new home before being removed from the old.

**Tech Stack:** SwiftUI, SwiftData, iOS 26.2. Swift `Testing` framework for the one logic test (`WeeklySnapshot.compute`). All other tasks verify by building (`xcodebuild`) and visual inspection in the iOS simulator — there is no SwiftUI test infrastructure in this repo.

**Spec:** `docs/superpowers/specs/2026-05-07-home-simplification-design.md`

---

## Conventions used by this plan

- **File paths** are absolute under repo root, e.g. `Cathier/Views/Components/WeeklyPracticeRow.swift`.
- **Build command** used as the verification gate after each task:
  ```bash
  xcodebuild -project Cathier.xcodeproj -scheme Cathier -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -30
  ```
  Expected: `** BUILD SUCCEEDED **` on the last line. (Adjust simulator name if iPhone 16 is not installed; `xcodebuild -showdestinations -project Cathier.xcodeproj -scheme Cathier` lists options.)
- **Commit messages**: lower-case, conventional-commits style. Co-author footer same as repo's existing commits.
- **No new strings**: every user-facing string this plan moves around is already localized in `LanguageManager` or as inline `switch lm.currentLanguage` blocks. Don't invent new copy.
- **Don't reformat unrelated code** in any file you edit.

---

## Task 1: Extract `WeeklyPracticeRow` to its own file

**Files:**
- Create: `Cathier/Views/Components/WeeklyPracticeRow.swift`
- Modify: `Cathier/Views/TodayView.swift` (delete the `private struct WeeklyPracticeRow` at lines ~944–992)

This is a mechanical extraction. The view becomes module-internal (default access) so `JournalView` can use it later.

- [ ] **Step 1: Create the new component file**

Write `Cathier/Views/Components/WeeklyPracticeRow.swift`:

```swift
import SwiftUI

struct WeeklyPracticeRow: View {
    let checkIns: [CheckIn]
    @Environment(LanguageManager.self) private var lm

    private var days: [(date: Date, hasCheckIn: Bool)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let dates = Set(checkIns.map { cal.startOfDay(for: $0.date) })
        return (0..<7).reversed().map { offset in
            let d = cal.date(byAdding: .day, value: -offset, to: today)!
            return (date: d, hasCheckIn: dates.contains(d))
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                let isToday = Calendar.current.isDateInToday(day.date)
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .stroke(Color.cathierAccent.opacity(isToday ? 0.35 : 0), lineWidth: 1.5)
                            .frame(width: 18, height: 18)
                        Circle()
                            .fill(day.hasCheckIn ? Color.cathierAccent : Color.secondary.opacity(0.18))
                            .frame(width: 9, height: 9)
                    }
                    .frame(width: 18, height: 18)
                    Text(dayLabel(day.date))
                        .font(.caption2)
                        .foregroundColor(isToday ? .primary : .secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    private func dayLabel(_ date: Date) -> String {
        let weekday = Calendar.current.component(.weekday, from: date)
        switch lm.currentLanguage {
        case .zh: return ["日", "一", "二", "三", "四", "五", "六"][weekday - 1]
        case .ja: return ["日", "月", "火", "水", "木", "金", "土"][weekday - 1]
        default:  return ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"][weekday - 1]
        }
    }
}
```

- [ ] **Step 2: Add the new file to the Xcode project**

Open `Cathier.xcodeproj` in Xcode. Drag `Cathier/Views/Components/WeeklyPracticeRow.swift` into the `Cathier/Views/Components` group in the navigator. Make sure "Cathier" target is checked.

(If using `xcodegen` or similar, regenerate. This repo uses a hand-edited `.pbxproj` — Xcode's GUI is the path of least resistance.)

- [ ] **Step 3: Delete the inline `private struct WeeklyPracticeRow` from TodayView**

In `Cathier/Views/TodayView.swift`, locate the comment `// MARK: - Weekly Practice Row` and delete the entire `private struct WeeklyPracticeRow` block that follows (the struct definition plus its `private func dayLabel`). The MARK comment can stay or go; if you delete it, also remove the orphaned blank lines.

`TodayView.swift` still references `WeeklyPracticeRow(checkIns: ...)` in its body at one place — that reference now resolves to the new file's struct. No call-site changes.

- [ ] **Step 4: Build**

Run:
```bash
xcodebuild -project Cathier.xcodeproj -scheme Cathier -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -30
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add Cathier/Views/Components/WeeklyPracticeRow.swift Cathier/Views/TodayView.swift Cathier.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
refactor: extract WeeklyPracticeRow to Components/

Preparatory move so JournalView can render the 7-day practice dots.
No behavior change.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Extract `WeeklyEmotionSummary` to its own file

**Files:**
- Create: `Cathier/Views/Components/WeeklyEmotionSummary.swift`
- Modify: `Cathier/Views/TodayView.swift` (delete `private struct WeeklyEmotionSummary` at lines ~1042–1085)

- [ ] **Step 1: Create the new component file**

Write `Cathier/Views/Components/WeeklyEmotionSummary.swift`:

```swift
import SwiftUI

struct WeeklyEmotionSummary: View {
    let topEmotions: [(emotion: String, count: Int)]
    @Environment(LanguageManager.self) private var lm

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(sectionTitle)
                .font(.headline)
            FlowLayout(spacing: 8) {
                ForEach(Array(topEmotions.enumerated()), id: \.offset) { _, item in
                    let color = EmotionData.category(for: item.emotion)?.color ?? .cathierAccent
                    let emoji = EmotionData.emoji(for: item.emotion)
                    let name = lm.display(item.emotion)
                    HStack(spacing: 4) {
                        Text(emoji.isEmpty ? name : "\(emoji) \(name)")
                            .font(.caption)
                            .fontWeight(.medium)
                        if item.count > 1 {
                            Text("×\(item.count)")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(color.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.12))
                    .foregroundColor(color)
                    .clipShape(Capsule())
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var sectionTitle: String {
        switch lm.currentLanguage {
        case .zh: return "本周情绪"
        case .ja: return "今週の気持ち"
        default:  return "This Week"
        }
    }
}
```

- [ ] **Step 2: Add file to Xcode project** (same procedure as Task 1 Step 2)

- [ ] **Step 3: Delete inline struct from TodayView**

In `Cathier/Views/TodayView.swift`, locate `// MARK: - Weekly Emotion Summary` and delete the entire `private struct WeeklyEmotionSummary` block.

The call site `WeeklyEmotionSummary(topEmotions: weeklyTopEmotions)` in TodayView's body now resolves to the new file. No call-site changes.

- [ ] **Step 4: Build**

Same command as Task 1 Step 4. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add Cathier/Views/Components/WeeklyEmotionSummary.swift Cathier/Views/TodayView.swift Cathier.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
refactor: extract WeeklyEmotionSummary to Components/

Preparatory move so JournalView can render top-5 weekly emotions.
No behavior change.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Extract `WeeklySnapshotCard` (with snapshot struct + sparkline)

**Files:**
- Create: `Cathier/Views/Components/WeeklySnapshotCard.swift`
- Create: `CathierTests/WeeklySnapshotTests.swift`
- Modify: `Cathier/Views/TodayView.swift` (delete `WeeklySnapshot` struct, `weeklySnapshot` computed prop, `weeklySnapshotCard` func, `WeeklySparkline` struct)

The snapshot card has more complexity than the previous two: it bundles the data-shaping struct (`WeeklySnapshot`) with the sparkline subview and a tappable card. The card needs an `onTap` closure (Today's version uses `showingInsights = true`; Journal will pass an analogous closure).

- [ ] **Step 1: Write a failing test for `WeeklySnapshot.compute`**

Create `CathierTests/WeeklySnapshotTests.swift`:

```swift
import Testing
import Foundation
@testable import Cathier

struct WeeklySnapshotTests {
    @Test
    func returnsNilWhenFewerThanThreeRecentCheckIns() {
        let now = Date()
        let twoCheckIns = (0..<2).map { i -> CheckIn in
            CheckIn(date: now.addingTimeInterval(Double(-i) * 3600), bodyParts: [], sensations: [], intensity: 5, emotions: [])
        }
        let snap = WeeklySnapshot.compute(from: twoCheckIns)
        #expect(snap == nil)
    }

    @Test
    func computesAverageAndTrendAcrossTwoWeeks() {
        let now = Date()
        let cal = Calendar.current
        let dayAgo = cal.date(byAdding: .day, value: -1, to: now)!
        let tenDaysAgo = cal.date(byAdding: .day, value: -10, to: now)!

        let recent = [
            CheckIn(date: now, bodyParts: [], sensations: [], intensity: 8, emotions: []),
            CheckIn(date: dayAgo, bodyParts: [], sensations: [], intensity: 6, emotions: []),
            CheckIn(date: dayAgo, bodyParts: [], sensations: [], intensity: 4, emotions: []),
        ]
        let older = [
            CheckIn(date: tenDaysAgo, bodyParts: [], sensations: [], intensity: 4, emotions: []),
            CheckIn(date: tenDaysAgo, bodyParts: [], sensations: [], intensity: 4, emotions: []),
        ]

        let snap = WeeklySnapshot.compute(from: recent + older)
        #expect(snap != nil)
        #expect(snap?.checkInCount == 3)
        #expect(abs((snap?.avgIntensity ?? 0) - 6.0) < 0.001)
        #expect(abs((snap?.trend ?? 0) - 2.0) < 0.001)
    }
}
```

(`CheckIn` initializer: verify against `Cathier/Models/CheckIn.swift` — adjust the parameter list if the SwiftData model needs different defaults. The repo's existing model exposes a memberwise init by default for SwiftData `@Model` classes; if not, instantiate via `CheckIn()` and set fields.)

- [ ] **Step 2: Run the test — expect FAIL ("WeeklySnapshot not defined")**

```bash
xcodebuild -project Cathier.xcodeproj -scheme Cathier -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:CathierTests/WeeklySnapshotTests 2>&1 | tail -30
```

Expected: build error / test failure citing "WeeklySnapshot is not a member type" or similar.

- [ ] **Step 3: Create `WeeklySnapshotCard.swift` with struct + view + sparkline**

Write `Cathier/Views/Components/WeeklySnapshotCard.swift`:

```swift
import SwiftUI

struct WeeklySnapshot: Equatable {
    let avgIntensity: Double
    let trend: Double  // positive = higher than prev week, negative = lower
    let checkInCount: Int

    /// Returns a snapshot for the most recent 7 days vs the prior 7 days,
    /// or nil when there are fewer than 3 recent check-ins.
    static func compute(from checkIns: [CheckIn]) -> WeeklySnapshot? {
        let calendar = Calendar.current
        let now = Date()
        guard let sevenAgo = calendar.date(byAdding: .day, value: -7, to: now),
              let fourteenAgo = calendar.date(byAdding: .day, value: -14, to: now) else { return nil }

        let thisWeek = checkIns.filter { $0.date >= sevenAgo }
        guard thisWeek.count >= 3 else { return nil }

        let thisAvg = Double(thisWeek.map(\.intensity).reduce(0, +)) / Double(thisWeek.count)
        let lastWeek = checkIns.filter { $0.date >= fourteenAgo && $0.date < sevenAgo }
        let lastAvg = lastWeek.isEmpty ? thisAvg
            : Double(lastWeek.map(\.intensity).reduce(0, +)) / Double(lastWeek.count)

        return WeeklySnapshot(avgIntensity: thisAvg, trend: thisAvg - lastAvg, checkInCount: thisWeek.count)
    }
}

struct WeeklySnapshotCard: View {
    let snapshot: WeeklySnapshot
    let checkIns: [CheckIn]
    let onTap: () -> Void
    @Environment(LanguageManager.self) private var lm

    var body: some View {
        let trendIcon: String
        let trendColor: Color
        let trendText: String

        if snapshot.trend > 0.5 {
            trendIcon = "arrow.up.right"
            trendColor = .cathierAccent
            trendText = lm.currentLanguage == .zh ? "强度上升" : lm.currentLanguage == .ja ? "強度上昇" : "Rising"
        } else if snapshot.trend < -0.5 {
            trendIcon = "arrow.down.right"
            trendColor = .cathierAccent
            trendText = lm.currentLanguage == .zh ? "强度下降" : lm.currentLanguage == .ja ? "強度低下" : "Easing"
        } else {
            trendIcon = "arrow.right"
            trendColor = .secondary
            trendText = lm.currentLanguage == .zh ? "趋于平稳" : lm.currentLanguage == .ja ? "安定" : "Stable"
        }

        let avgText = String(format: "%.1f", snapshot.avgIntensity)
        let countLabel = lm.currentLanguage == .zh
            ? "近 7 天 · \(snapshot.checkInCount) 次记录"
            : lm.currentLanguage == .ja
                ? "過去7日 · \(snapshot.checkInCount)回"
                : "7-day · \(snapshot.checkInCount) entries"

        return Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(countLabel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(avgText)
                                .font(.system(.title2, design: .monospaced))
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Text("/10")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(lm.currentLanguage == .zh ? "平均强度" : lm.currentLanguage == .ja ? "平均強度" : "avg intensity")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: trendIcon)
                            .font(.subheadline)
                            .foregroundColor(trendColor)
                        Text(trendText)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(trendColor)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                WeeklySparkline(checkIns: checkIns)
            }
            .padding(14)
            .background(Color.cathierSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct WeeklySparkline: View {
    let checkIns: [CheckIn]

    private let barMaxHeight: CGFloat = 20
    private let barWidth: CGFloat = 10

    private var dayAverages: [Double?] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<7).reversed().map { offset in
            let dayStart = cal.date(byAdding: .day, value: -offset, to: today)!
            let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!
            let dayCheckIns = checkIns.filter { $0.date >= dayStart && $0.date < dayEnd }
            guard !dayCheckIns.isEmpty else { return nil }
            return Double(dayCheckIns.map(\.intensity).reduce(0, +)) / Double(dayCheckIns.count)
        }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(Array(dayAverages.enumerated()), id: \.offset) { _, avg in
                if let avg {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(barColor(avg))
                        .frame(width: barWidth, height: max(3, barMaxHeight * CGFloat(avg) / 10.0))
                } else {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(width: barWidth, height: 3)
                }
            }
            Spacer()
        }
        .frame(height: barMaxHeight)
        .accessibilityHidden(true)
    }

    private func barColor(_ intensity: Double) -> Color {
        switch intensity {
        case ..<4: return .yellow
        case ..<7: return .cathierAccent
        default:   return .red
        }
    }
}
```

- [ ] **Step 4: Add the new files to Xcode project**

In Xcode navigator:
- Drag `Cathier/Views/Components/WeeklySnapshotCard.swift` into `Cathier/Views/Components` (target: Cathier)
- Drag `CathierTests/WeeklySnapshotTests.swift` into `CathierTests` (target: CathierTests)

- [ ] **Step 5: Update TodayView to use the new types and remove the inline copies**

In `Cathier/Views/TodayView.swift`:

1. Find the `weeklySnapshot` computed property (around line 685). Replace its body:
   ```swift
   private var weeklySnapshot: WeeklySnapshot? {
       WeeklySnapshot.compute(from: Array(checkIns))
   }
   ```

2. Find the `weeklySnapshotCard(_ snapshot:)` function (around line 702). Delete the entire function.

3. Find the call site in `body` that uses `weeklySnapshotCard(snapshot)` (around line 77):
   ```swift
   if let snapshot = weeklySnapshot {
       weeklySnapshotCard(snapshot)
           .padding(.horizontal, 20)
   }
   ```
   Replace with:
   ```swift
   if let snapshot = weeklySnapshot {
       WeeklySnapshotCard(snapshot: snapshot, checkIns: Array(checkIns)) {
           showingInsights = true
       }
       .padding(.horizontal, 20)
   }
   ```

4. Find `// MARK: - Weekly Snapshot` section header. Delete the inline `struct WeeklySnapshot { ... }` block (around lines 679–683).

5. Find `// MARK: - Weekly Sparkline` section header (around line 994). Delete the entire `private struct WeeklySparkline` block.

- [ ] **Step 6: Run the test — expect PASS**

```bash
xcodebuild -project Cathier.xcodeproj -scheme Cathier -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:CathierTests/WeeklySnapshotTests 2>&1 | tail -30
```

Expected: `Test Suite 'WeeklySnapshotTests' passed`.

- [ ] **Step 7: Build the app target**

```bash
xcodebuild -project Cathier.xcodeproj -scheme Cathier -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -30
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 8: Commit**

```bash
git add Cathier/Views/Components/WeeklySnapshotCard.swift CathierTests/WeeklySnapshotTests.swift Cathier/Views/TodayView.swift Cathier.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
refactor: extract WeeklySnapshotCard with WeeklySnapshot.compute()

Snapshot computation becomes a static method with a unit test;
sparkline subview travels with it. Card takes an onTap closure
so JournalView can wire it differently from TodayView.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Create `AIFrontierView` (push-friendly destination)

**Files:**
- Create: `Cathier/Views/AIFrontierView.swift`

`AIFrontierService` only stores `todayNews` (no history) — this view shows today's news + regenerate button + loading/error states. It owns the `.task` that calls `generateTodayNewsIfNeeded()`.

- [ ] **Step 1: Create the file**

Write `Cathier/Views/AIFrontierView.swift`:

```swift
import SwiftUI

struct AIFrontierView: View {
    @Environment(LanguageManager.self) private var lm
    private var service: AIFrontierService { AIFrontierService.shared }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let news = service.todayNews {
                    AIFrontierCard(news: news) {
                        Task { await service.regenerate() }
                    }
                } else if service.isGenerating {
                    loadingCard
                } else {
                    retryCard
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(Color.cathierBackground)
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.large)
        .task { await service.generateTodayNewsIfNeeded() }
    }

    private var loadingCard: some View {
        HStack(spacing: 14) {
            ProgressView()
                .tint(Color.cathierAccent)
                .frame(width: 48, height: 48)
            Text(loadingHint)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(16)
        .background(Color.cathierSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var retryCard: some View {
        Button {
            Task { await service.generateTodayNewsIfNeeded() }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.cathierAccent.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "sparkles")
                        .font(.system(size: 20))
                        .foregroundColor(Color.cathierAccent)
                }
                Text(service.generateError != nil ? errorHint : loadingHint)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color.cathierSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var navTitle: String {
        switch lm.currentLanguage {
        case .zh: return "今日AI最前沿"
        case .ja: return "今日のAIフロンティア"
        default:  return "AI Frontier"
        }
    }

    private var loadingHint: String {
        switch lm.currentLanguage {
        case .zh: return "正在检索最前沿AI动态…"
        case .ja: return "最先端のAI動向を取得中…"
        default:  return "Fetching today's AI frontier…"
        }
    }

    private var errorHint: String {
        switch lm.currentLanguage {
        case .zh: return "获取失败，点击重试"
        case .ja: return "取得に失敗しました。再試行するにはタップ"
        default:  return "Failed to load — tap to retry"
        }
    }
}
```

- [ ] **Step 2: Add to Xcode project** (Xcode → drag into `Cathier/Views`, target Cathier)

- [ ] **Step 3: Build**

```bash
xcodebuild -project Cathier.xcodeproj -scheme Cathier -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -30
```

Expected: `** BUILD SUCCEEDED **`. (View is unused; warning is acceptable.)

- [ ] **Step 4: Commit**

```bash
git add Cathier/Views/AIFrontierView.swift Cathier.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat: add AIFrontierView for Settings → 探索

Push-friendly destination for the AI frontier feature. Owns its own
generate-on-appear .task, so the LLM call only fires when the user
actually opens the screen.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Refactor `JokeHistoryView` for push + add joke `.task`

**Files:**
- Modify: `Cathier/Views/JokeHistoryView.swift`
- Modify: `Cathier/Views/TodayView.swift` (the `showingJokeHistory` sheet wraps inline `NavigationStack`)

The plan: `JokeHistoryView` becomes a content view (no NavigationStack, no Done toolbar) and owns its own `.task` to generate today's joke. TodayView's existing sheet wraps it inline with NavigationStack until Today is slimmed in Task 11.

- [ ] **Step 1: Refactor `JokeHistoryView.swift`**

Replace the entire body of `Cathier/Views/JokeHistoryView.swift` with:

```swift
import SwiftUI

struct JokeHistoryView: View {
    @Environment(LanguageManager.self) private var lm

    private var jokeService: JokeService { JokeService.shared }

    var body: some View {
        Group {
            if jokeService.jokeHistory.isEmpty {
                emptyState
            } else {
                jokeList
            }
        }
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.large)
        .task { await jokeService.generateTodayJokeIfNeeded() }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "cpu.fill")
                .font(.system(size: 48))
                .foregroundColor(Color.cathierAccent.opacity(0.4))
            Text(emptyLabel)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cathierBackground)
    }

    private var jokeList: some View {
        List {
            ForEach(jokeService.jokeHistory) { joke in
                JokeHistoryRow(joke: joke)
                    .listRowBackground(Color.cathierSurface)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.cathierBackground)
    }

    private var navTitle: String {
        switch lm.currentLanguage {
        case .zh: return "AI 冷笑话"
        case .ja: return "AI コールドジョーク"
        default:  return "AI Cold Jokes"
        }
    }

    private var emptyLabel: String {
        switch lm.currentLanguage {
        case .zh: return "还没有笑话记录"
        case .ja: return "まだジョークがありません"
        default:  return "No jokes yet"
        }
    }
}

private struct JokeHistoryRow: View {
    let joke: DailyJoke

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(joke.date, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(joke.question)
                .font(.cathierSerif(.body))
                .foregroundColor(.primary)
            Text(joke.punchline)
                .font(.cathierSerif(.body, italic: true))
                .foregroundColor(Color.cathierAccent)
        }
        .padding(.vertical, 4)
    }
}
```

What changed: removed the outer `NavigationStack`, removed the `dismiss` environment, removed the Done toolbar. Added a `.task` that generates today's joke when the view appears. Title display mode changed to `.large` since pushed views look better with large titles.

- [ ] **Step 2: Wrap TodayView's existing sheet usage with inline NavigationStack**

In `Cathier/Views/TodayView.swift`, find:
```swift
.sheet(isPresented: $showingJokeHistory) {
    JokeHistoryView()
        .environment(lm)
}
```

Replace with:
```swift
.sheet(isPresented: $showingJokeHistory) {
    NavigationStack {
        JokeHistoryView()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(jokeSheetDoneLabel) { showingJokeHistory = false }
                }
            }
    }
    .environment(lm)
}
```

Add a small helper near the bottom of `TodayView` (just before the closing `}` of `TodayView`):
```swift
private var jokeSheetDoneLabel: String {
    switch lm.currentLanguage {
    case .zh: return "完成"
    case .ja: return "完了"
    default:  return "Done"
    }
}
```

(This helper goes away in Task 11 along with the sheet usage. Don't try to consolidate.)

- [ ] **Step 3: Build**

```bash
xcodebuild -project Cathier.xcodeproj -scheme Cathier -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -30
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add Cathier/Views/JokeHistoryView.swift Cathier/Views/TodayView.swift
git commit -m "$(cat <<'EOF'
refactor: make JokeHistoryView NavigationLink-friendly

Drop inner NavigationStack so it can be pushed from Settings →
探索. Move joke generation .task onto the view itself so the
LLM call fires only when the user opens it. TodayView's current
sheet wraps inline with NavigationStack until Today is slimmed.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Refactor `BrainTrainerSheet` — extract `BrainTrainerView`

**Files:**
- Modify: `Cathier/Views/CheckIn/BrainTrainerSheet.swift`
- Modify: `Cathier/Views/TodayView.swift` (sheet usage updated)

Same pattern as Task 5. Extract a content view; TodayView wraps inline.

- [ ] **Step 1: Refactor `BrainTrainerSheet.swift`**

Replace the entire body of `Cathier/Views/CheckIn/BrainTrainerSheet.swift` with:

```swift
import SwiftUI
import SwiftData

/// Content view (no NavigationStack), suitable for both NavigationLink push and sheet wrapping.
struct BrainTrainerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(LanguageManager.self) private var lm
    @State private var viewModel = CheckInViewModel()
    @State private var phase: Phase = .intro
    @FocusState private var triggerFocused: Bool

    private enum Phase { case intro, chat }

    var body: some View {
        Group {
            switch phase {
            case .intro:
                introView
            case .chat:
                BrainTrainerChatView(onSave: saveAction)
                    .environment(viewModel)
                    .environment(lm)
            }
        }
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.cathierBackground.ignoresSafeArea())
    }

    // MARK: - Intro

    private var introView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "gearshape.2.fill")
                            .font(.title2)
                            .foregroundColor(.cathierAccent)
                        Text(introHeadline)
                            .font(.cathierSerif(.title2))
                            .foregroundColor(.primary)
                    }
                    Text(introSubtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineSpacing(3)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(promptLabel)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    TextField(promptPlaceholder, text: $viewModel.triggerEvent, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(3...6)
                        .focused($triggerFocused)
                        .padding(14)
                        .background(Color.cathierSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                }

                Button(action: startChat) {
                    Text(continueLabel)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canContinue ? Color.cathierAccent : Color.cathierAccent.opacity(0.4))
                        .clipShape(Capsule())
                }
                .disabled(!canContinue)
                .padding(.top, 4)

                Spacer(minLength: 24)
            }
            .padding(20)
        }
        .onAppear { triggerFocused = true }
    }

    private var canContinue: Bool {
        !viewModel.triggerEvent.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func startChat() {
        triggerFocused = false
        phase = .chat
        viewModel.startBrainTrainerSession()
    }

    private func saveAction() {
        viewModel.aiFeedback = viewModel.brainTrainerTranscript
        _ = viewModel.save(context: modelContext)
        dismiss()
    }

    // MARK: - Localized strings

    private var navTitle: String {
        switch lm.currentLanguage {
        case .zh: return "吃一堑长一智"
        case .ja: return "失敗から学ぶ"
        default:  return "Lesson from Setback"
        }
    }

    private var introHeadline: String {
        switch lm.currentLanguage {
        case .zh: return "刚才踩了什么坑？"
        case .ja: return "今、何でつまずいた？"
        default:  return "What just tripped you up?"
        }
    }

    private var introSubtitle: String {
        switch lm.currentLanguage {
        case .zh: return "我们花几分钟做一次五步复盘——不复盘事件，而是复盘解释事件的旧模型，训练一个新版本。"
        case .ja: return "5ステップで振り返ります。出来事ではなく、出来事を解釈する古いモデルを更新します。"
        default:  return "We'll do a 5-step review — not of the event, but of the old model that interpreted it. Train a new version."
        }
    }

    private var promptLabel: String {
        switch lm.currentLanguage {
        case .zh: return "一句话描述这次的「堑」"
        case .ja: return "今回の「つまずき」を一言で"
        default:  return "Describe the setback in one line"
        }
    }

    private var promptPlaceholder: String {
        switch lm.currentLanguage {
        case .zh: return "比如：开会时被问到细节没答上来…"
        case .ja: return "例：会議で詳細を答えられなかった…"
        default:  return "e.g., Got asked a detail in a meeting and froze..."
        }
    }

    private var continueLabel: String {
        switch lm.currentLanguage {
        case .zh: return "开始复盘"
        case .ja: return "振り返りを始める"
        default:  return "Begin Review"
        }
    }
}
```

What changed: the file no longer defines `BrainTrainerSheet`. It now defines `BrainTrainerView` (renamed). Removed the inner `NavigationStack` and the `cancelLabel` toolbar; back/dismiss is controlled by the surrounding NavigationStack (push case) or the inline sheet wrapper (sheet case from Today).

- [ ] **Step 2: Update TodayView's sheet usage**

In `Cathier/Views/TodayView.swift`, find:
```swift
.sheet(isPresented: $showingBrainTrainer) {
    BrainTrainerSheet()
        .environment(lm)
}
```

Replace with:
```swift
.sheet(isPresented: $showingBrainTrainer) {
    NavigationStack {
        BrainTrainerView()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(brainTrainerSheetCancelLabel) { showingBrainTrainer = false }
                }
            }
    }
    .environment(lm)
}
```

Add helper near the bottom of `TodayView`:
```swift
private var brainTrainerSheetCancelLabel: String {
    switch lm.currentLanguage {
    case .zh: return "取消"
    case .ja: return "キャンセル"
    default:  return "Cancel"
    }
}
```

- [ ] **Step 3: Build**

```bash
xcodebuild -project Cathier.xcodeproj -scheme Cathier -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -30
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add Cathier/Views/CheckIn/BrainTrainerSheet.swift Cathier/Views/TodayView.swift
git commit -m "$(cat <<'EOF'
refactor: extract BrainTrainerView from BrainTrainerSheet

The content view drops its inner NavigationStack so it can be
pushed from Settings → 探索. TodayView's existing sheet wraps it
inline with NavigationStack + cancel toolbar until Today is slimmed.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Refactor `HealthInsightView` for push

**Files:**
- Modify: `Cathier/Views/HealthInsightView.swift`
- Modify: `Cathier/Views/TodayView.swift` (sheet usage updated)

- [ ] **Step 1: Remove inner NavigationStack and cancel toolbar**

In `Cathier/Views/HealthInsightView.swift`, the current `body` looks like:
```swift
var body: some View {
    NavigationStack {
        ScrollView {
            ...
        }
        .background(Color.cathierBackground)
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(lm.checkInCancel) { dismiss() }
                    .foregroundColor(.cathierAccent)
            }
        }
    }
    .task {
        if service.authStatus == .requested {
            await service.loadData()
        }
    }
}
```

Replace with:
```swift
var body: some View {
    ScrollView {
        VStack(spacing: 24) {
            if !service.isAvailable {
                unavailableView
            } else if service.authStatus == .notDetermined {
                requestAccessCard
            } else if service.isLoading {
                loadingView
            } else {
                metricsGrid
                if !service.summary.weeklySteps.isEmpty {
                    weeklyStepsChart
                }
                aiInsightSection
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 40)
    }
    .background(Color.cathierBackground)
    .navigationTitle(navTitle)
    .navigationBarTitleDisplayMode(.large)
    .task {
        if service.authStatus == .requested {
            await service.loadData()
        }
    }
}
```

(Removed: outer `NavigationStack`, the toolbar with cancel button. The `dismiss` env var is no longer used; remove the line `@Environment(\.dismiss) private var dismiss` near the top of the struct.)

- [ ] **Step 2: Update TodayView's sheet usage**

In `Cathier/Views/TodayView.swift`, find:
```swift
.sheet(isPresented: $showingHealth) {
    HealthInsightView()
        .environment(lm)
}
```

Replace with:
```swift
.sheet(isPresented: $showingHealth) {
    NavigationStack {
        HealthInsightView()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(healthSheetCancelLabel) { showingHealth = false }
                        .foregroundColor(.cathierAccent)
                }
            }
    }
    .environment(lm)
}
```

Add helper near the bottom of `TodayView`:
```swift
private var healthSheetCancelLabel: String {
    switch lm.currentLanguage {
    case .zh: return "取消"
    case .ja: return "キャンセル"
    default:  return "Cancel"
    }
}
```

- [ ] **Step 3: Build**

```bash
xcodebuild -project Cathier.xcodeproj -scheme Cathier -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -30
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add Cathier/Views/HealthInsightView.swift Cathier/Views/TodayView.swift
git commit -m "$(cat <<'EOF'
refactor: drop inner NavigationStack from HealthInsightView

Same pattern as Joke and BrainTrainer: content-only view, sheet
wrapped inline by Today until Today is slimmed.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Wire Settings → 探索 with 4 NavigationLinks

**Files:**
- Modify: `Cathier/Views/SettingsView.swift`

Add four rows to the existing 探索 section. Match the visual pattern of the existing 觉察词典 row.

- [ ] **Step 1: Replace the 探索 Section**

In `Cathier/Views/SettingsView.swift`, find:
```swift
// MARK: - Emotion Dictionary
Section {
    NavigationLink {
        EmotionExplorerView()
            .environment(ConfigService.shared)
    } label: {
        Label("觉察词典", systemImage: "book.closed")
            .foregroundColor(.primary)
    }
} header: {
    Text("探索")
}
```

Replace with:
```swift
// MARK: - 探索
Section {
    NavigationLink {
        EmotionExplorerView()
            .environment(ConfigService.shared)
    } label: {
        Label(exploreDictionaryLabel, systemImage: "book.closed")
            .foregroundColor(.primary)
    }

    NavigationLink {
        HealthInsightView()
    } label: {
        Label(exploreHealthLabel, systemImage: "heart.text.clipboard")
            .foregroundColor(.primary)
    }

    NavigationLink {
        BrainTrainerView()
    } label: {
        Label(exploreBrainTrainerLabel, systemImage: "gearshape.2")
            .foregroundColor(.primary)
    }

    NavigationLink {
        AIFrontierView()
    } label: {
        Label(exploreAIFrontierLabel, systemImage: "sparkles")
            .foregroundColor(.primary)
    }

    NavigationLink {
        JokeHistoryView()
    } label: {
        Label(exploreJokeLabel, systemImage: "cpu")
            .foregroundColor(.primary)
    }
} header: {
    Text(exploreSectionHeader)
}
```

- [ ] **Step 2: Add localized labels at the bottom of `SettingsView`**

Just before the final closing brace of `struct SettingsView`, add:

```swift
private var exploreSectionHeader: String {
    switch lm.currentLanguage {
    case .zh: return "探索"
    case .ja: return "探索"
    default:  return "Explore"
    }
}

private var exploreDictionaryLabel: String {
    switch lm.currentLanguage {
    case .zh: return "觉察词典"
    case .ja: return "気づき辞典"
    default:  return "Awareness Dictionary"
    }
}

private var exploreHealthLabel: String {
    switch lm.currentLanguage {
    case .zh: return "身体数据"
    case .ja: return "身体データ"
    default:  return "Health Data"
    }
}

private var exploreBrainTrainerLabel: String {
    switch lm.currentLanguage {
    case .zh: return "吃一堑长一智"
    case .ja: return "失敗から学ぶ"
    default:  return "Lesson from Setback"
    }
}

private var exploreAIFrontierLabel: String {
    switch lm.currentLanguage {
    case .zh: return "今日AI最前沿"
    case .ja: return "今日のAIフロンティア"
    default:  return "AI Frontier"
    }
}

private var exploreJokeLabel: String {
    switch lm.currentLanguage {
    case .zh: return "AI 冷笑话"
    case .ja: return "AI コールドジョーク"
    default:  return "AI Cold Jokes"
    }
}
```

- [ ] **Step 3: Build**

```bash
xcodebuild -project Cathier.xcodeproj -scheme Cathier -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -30
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Manual smoke check**

Launch the app in simulator. Tap the 设置 tab → scroll to 探索 section → confirm 5 rows visible (觉察词典, 身体数据, 吃一堑长一智, 今日AI最前沿, AI 冷笑话). Tap each:
- 觉察词典 → existing dictionary screen pushes (unchanged)
- 身体数据 → HealthKit screen pushes; back button works
- 吃一堑长一智 → BrainTrainer intro pushes
- 今日AI最前沿 → AIFrontier screen pushes; news loads via .task
- AI 冷笑话 → joke history pushes

If any of them shows a doubled nav bar, the refactor in Tasks 5/6/7 is incomplete; revisit.

- [ ] **Step 5: Commit**

```bash
git add Cathier/Views/SettingsView.swift
git commit -m "$(cat <<'EOF'
feat: wire 4 destinations into Settings → 探索

Surfaces Health, BrainTrainer, AI frontier, and joke archive as
push destinations alongside the existing 觉察词典 row. Reachable
before TodayView is slimmed in the next task.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Add 本周快照 header to JournalView

**Files:**
- Modify: `Cathier/Views/JournalView.swift`

The header sits ABOVE the existing search-aware list, INSIDE the check-in tab (`selectedTab == 0`), and is hidden when search is active or when there are no check-ins. The three components (`WeeklyPracticeRow`, `WeeklyEmotionSummary`, `WeeklySnapshotCard`) are already extracted in Tasks 1–3.

- [ ] **Step 1: Add helpers and the header section to `JournalView`**

In `Cathier/Views/JournalView.swift`, add these computed properties just before `var body: some View {` (around line 79):

```swift
private var weeklyTopEmotions: [(emotion: String, count: Int)] {
    let cal = Calendar.current
    let weekAgo = cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    let recent = checkIns.filter { $0.date >= weekAgo }
    var counts: [String: Int] = [:]
    for ci in recent {
        for emotion in ci.emotions { counts[emotion, default: 0] += 1 }
    }
    return counts.sorted { $0.value > $1.value }.prefix(5).map { ($0.key, $0.value) }
}

private var weeklySnapshot: WeeklySnapshot? {
    WeeklySnapshot.compute(from: Array(checkIns))
}

private var showsWeeklyHeader: Bool {
    searchText.isEmpty && !checkIns.isEmpty
}

@ViewBuilder
private var weeklyHeader: some View {
    if showsWeeklyHeader {
        VStack(alignment: .leading, spacing: 12) {
            WeeklyPracticeRow(checkIns: Array(checkIns))
            if !weeklyTopEmotions.isEmpty {
                WeeklyEmotionSummary(topEmotions: weeklyTopEmotions)
            }
            if let snapshot = weeklySnapshot {
                WeeklySnapshotCard(snapshot: snapshot, checkIns: Array(checkIns)) {
                    showInsights = true
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}
```

- [ ] **Step 2: Insert the header into `journalContent`**

In the same file, find the `journalContent` view (around line 148):
```swift
@ViewBuilder
private var journalContent: some View {
    if groupedCheckIns.isEmpty {
        ...
    } else {
        List {
            if searchText.isEmpty && checkIns.count >= 7 {
                Section {
                    lifetimeStatsCard
                        ...
                }
            }
            ForEach(groupedCheckIns, id: \.0) { ... }
        }
        .listStyle(.plain)
    }
}
```

Wrap it so the weekly header appears above the list when applicable. Replace the entire `journalContent` body with:

```swift
@ViewBuilder
private var journalContent: some View {
    if groupedCheckIns.isEmpty {
        if pendingDelete != nil && searchText.isEmpty {
            Color.clear
        } else {
            VStack(spacing: 0) {
                weeklyHeader
                noResultsState
            }
        }
    } else {
        List {
            if showsWeeklyHeader {
                Section {
                    weeklyHeader
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            if searchText.isEmpty && checkIns.count >= 7 {
                Section {
                    lifetimeStatsCard
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            ForEach(groupedCheckIns, id: \.0) { section, items in
                Section(section) {
                    ForEach(items) { checkIn in
                        CheckInCard(checkIn: checkIn)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    beginSoftDelete(checkIn)
                                } label: {
                                    Label(lm.journalDelete, systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}
```

- [ ] **Step 3: Build**

```bash
xcodebuild -project Cathier.xcodeproj -scheme Cathier -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -30
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Manual smoke check**

In simulator: 日记 tab → confirm the 本周 header appears at the top with the dots row, top-5 emotion chips (if any this week), and intensity card (if ≥3 check-ins this week). Pull-to-refresh / interact normally; type into search → header should disappear; clear search → header reappears.

- [ ] **Step 5: Commit**

```bash
git add Cathier/Views/JournalView.swift
git commit -m "$(cat <<'EOF'
feat: add 本周 header to JournalView

Renders the practice dots, top-5 emotions, and intensity snapshot
above the grouped check-in list. Hidden during active search and
when there are no check-ins. Reuses the components extracted from
TodayView.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Add `hasNewPatterns` red-dot badge to JournalView toolbar

**Files:**
- Modify: `Cathier/Views/JournalView.swift`

Replace the standalone insights nudge card (which gets removed from Today in Task 11) with a red dot on the existing toolbar Insights button. Logic mirrors TodayView's `hasNewPatterns` predicate.

- [ ] **Step 1: Add `hasNewPatterns` computed property**

Near the other computed properties in `JournalView`, add:

```swift
private var hasNewPatterns: Bool {
    let lastAnalyzed = UserDefaults.standard.integer(forKey: "lastInsightCheckInCount")
    return checkIns.count >= 7 && checkIns.count >= lastAnalyzed + 5
}
```

- [ ] **Step 2: Wrap the toolbar Insights button with a badge overlay**

In the same file, find the toolbar:
```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        Button {
            showInsights = true
        } label: {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .foregroundStyle(.cathierAccent)
        }
        .accessibilityLabel(lm.insightsNavTitle)
    }
}
```

Replace with:
```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        Button {
            showInsights = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.cathierAccent)
                if hasNewPatterns {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .offset(x: 4, y: -4)
                }
            }
        }
        .accessibilityLabel(lm.insightsNavTitle)
    }
}
```

- [ ] **Step 3: Build**

```bash
xcodebuild -project Cathier.xcodeproj -scheme Cathier -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -30
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Manual smoke check**

Open 日记 tab. With ≥7 check-ins and 5+ since last insight analysis, the toolbar Insights icon should show a red dot at top-right. Tap to open Insights — UserDefaults' `lastInsightCheckInCount` is updated by the existing Insights flow on analysis, which clears the dot.

- [ ] **Step 5: Commit**

```bash
git add Cathier/Views/JournalView.swift
git commit -m "$(cat <<'EOF'
feat: red-dot badge on Journal Insights toolbar when patterns are new

Replaces TodayView's standalone insightsNudgeCard. Same hasNewPatterns
predicate (≥7 check-ins and ≥5 new since last analysis), reads same
UserDefaults key.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Slim TodayView

**Files:**
- Modify: `Cathier/Views/TodayView.swift`

This task removes 8 sections from Today and the state/.task/sheet plumbing they require. After this commit, Today renders only: greeting+streak header, milestone banner (conditional), reminder nudge (conditional), main CTA, today's check-ins, today's journal.

The cleanest path is to rewrite the file. Below is the complete target file.

- [ ] **Step 1: Replace `Cathier/Views/TodayView.swift` with the slim version**

```swift
import SwiftUI
import SwiftData

struct TodayView: View {
    @Query(sort: \CheckIn.date, order: .reverse) private var checkIns: [CheckIn]
    @Query(sort: \DailyJournal.date, order: .reverse) private var journals: [DailyJournal]
    @State private var showingCheckIn = false
    @State private var showingJournalEntry = false
    @State private var journalToEdit: DailyJournal? = nil
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("lastCelebratedStreakMilestone") private var lastCelebratedStreakMilestone: Int = 0
    @AppStorage("personalBestStreak") private var personalBestStreak: Int = 0
    @State private var dismissedMilestone: Int = 0
    @Environment(LanguageManager.self) private var lm

    private let streakMilestones = [3, 7, 14, 30]

    private var milestoneToShow: Int? {
        let reached = streakMilestones.filter { $0 <= streakDays }.max()
        guard let milestone = reached,
              milestone > lastCelebratedStreakMilestone,
              milestone != dismissedMilestone else { return nil }
        return milestone
    }

    private var todayCheckIns: [CheckIn] {
        checkIns.filter { Calendar.current.isDateInToday($0.date) }
    }

    private var todayJournal: DailyJournal? {
        journals.first { Calendar.current.isDateInToday($0.date) }
    }

    var body: some View {
        let _ = t("TodayView.body evaluated — checkIns:\(checkIns.count) journals:\(journals.count)")
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerView
                        .padding(.horizontal, 20)

                    if let milestone = milestoneToShow {
                        streakMilestoneBanner(milestone)
                            .padding(.horizontal, 20)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    if !notificationsEnabled && todayCheckIns.isEmpty
                        && Calendar.current.component(.hour, from: Date()) >= 18 {
                        reminderNudgeCard
                            .padding(.horizontal, 20)
                    }

                    startButton
                        .padding(.horizontal, 20)

                    if !todayCheckIns.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(lm.todayRecords)
                                .font(.headline)
                                .padding(.horizontal, 20)

                            if todayCheckIns.count >= 2 {
                                TodayIntensityArc(checkIns: todayCheckIns)
                                    .padding(.horizontal, 20)
                            }

                            ForEach(todayCheckIns) { checkIn in
                                CheckInCard(checkIn: checkIn)
                                    .padding(.horizontal, 20)
                            }
                        }
                    }

                    dailyJournalSection
                        .padding(.horizontal, 20)

                    Spacer(minLength: 40)
                }
                .padding(.top, 8)
            }
            .navigationTitle(lm.todayNavTitle)
            .onAppear {
                if !todayCheckIns.isEmpty {
                    NotificationService.shared.clearBadge()
                }
                if streakDays > personalBestStreak {
                    personalBestStreak = streakDays
                }
            }
            .onChange(of: streakDays) { _, newValue in
                if newValue > personalBestStreak {
                    personalBestStreak = newValue
                }
            }
            .sheet(isPresented: $showingCheckIn) {
                CheckInFlowView()
            }
            .sheet(isPresented: $showingJournalEntry) {
                DailyJournalEntryView(existing: journalToEdit) {
                    journalToEdit = nil
                }
            }
        }
    }

    // MARK: - Daily Journal Section

    @ViewBuilder
    private var dailyJournalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(lm.journalEntryTodayTitle)
                .font(.headline)

            if let journal = todayJournal {
                DailyJournalCard(journal: journal) {
                    journalToEdit = journal
                    showingJournalEntry = true
                }
            } else {
                journalWritePrompt
            }
        }
    }

    private var journalWritePrompt: some View {
        Button(action: {
            journalToEdit = nil
            showingJournalEntry = true
        }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.cathierAccent.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "book.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color.cathierAccent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(lm.journalEntryWritePrompt)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text(lm.journalEntryWriteHint)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color.cathierSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingText)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(todayCheckIns.isEmpty
                     ? lm.todayNoCheckIn()
                     : lm.todayCheckedIn(todayCheckIns.count))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if streakDays >= 1 {
                streakBadge
            }
        }
    }

    private var streakBadge: some View {
        VStack(spacing: 2) {
            Text("\(streakDays)")
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundColor(.cathierAccent)
            Text(lm.streakLabel)
                .font(.caption2)
                .foregroundColor(.secondary)
            if personalBestStreak > streakDays {
                Text(personalBestText)
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.top, 1)
            }
        }
        .frame(width: 56)
        .padding(.vertical, 10)
        .background(Color.cathierAccentLight)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var personalBestText: String {
        switch lm.currentLanguage {
        case .zh: return "最佳\(personalBestStreak)"
        case .ja: return "最高\(personalBestStreak)"
        default:   return "Best\(personalBestStreak)"
        }
    }

    private var streakDays: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dates = Set(checkIns.map { calendar.startOfDay(for: $0.date) })

        var day = today
        if !dates.contains(day) {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: day) ?? day
            guard dates.contains(yesterday) else { return 0 }
            day = yesterday
        }

        var count = 0
        while dates.contains(day) {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }

    // MARK: - Start Button

    private var startButton: some View {
        Button(action: { showingCheckIn = true }) {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 64, height: 64)
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }
                Text(lm.todayStartScan)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(lm.todayBodySaying)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(
                LinearGradient(
                    colors: [Color.cathierAccent, Color.cathierAccent.opacity(0.75)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return lm.greetingMorning
        case 12..<18: return lm.greetingAfternoon
        default:      return lm.greetingEvening
        }
    }

    // MARK: - Streak Milestone Banner

    private func streakMilestoneBanner(_ days: Int) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(milestoneTitleText(days))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.cathierAccent)
                Text(milestoneBodyText(days))
                    .font(.cathierSerif(.footnote))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    dismissedMilestone = days
                }
                lastCelebratedStreakMilestone = days
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                lm.currentLanguage == .zh ? "关闭"
                    : lm.currentLanguage == .ja ? "閉じる"
                    : "Dismiss"
            )
        }
        .padding(14)
        .background(Color.cathierAccentLight)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func milestoneTitleText(_ days: Int) -> String {
        switch lm.currentLanguage {
        case .zh: return "连续练习 \(days) 天"
        case .ja: return "\(days)日間連続で練習中"
        default:  return "\(days)-Day Practice Streak"
        }
    }

    private func milestoneBodyText(_ days: Int) -> String {
        switch lm.currentLanguage {
        case .zh:
            switch days {
            case 3:  return "坚持三天，觉察正成为你的习惯。"
            case 7:  return "一周的坚持，你的情绪感知正在扩展。"
            case 14: return "两周的练习，变化正在悄然发生。"
            default: return "一个月，令人敬佩的坚持。"
            }
        case .ja:
            switch days {
            case 3:  return "3日間継続、気づきが習慣になっています。"
            case 7:  return "1週間、感情の気づきが広がっています。"
            case 14: return "2週間、静かな変化が起きています。"
            default: return "1ヶ月、素晴らしい継続です。"
            }
        default:
            switch days {
            case 3:  return "Three days in — awareness is becoming a habit."
            case 7:  return "A week of practice. Your emotional vocabulary is growing."
            case 14: return "Two weeks. Something is quietly shifting."
            default: return "A month of consistent practice. Remarkable."
            }
        }
    }

    // MARK: - Reminder Nudge

    private var reminderNudgeCard: some View {
        let title = lm.currentLanguage == .zh ? "开启每日提醒"
            : lm.currentLanguage == .ja ? "毎日リマインダーをオン"
            : "Enable Daily Reminders"
        let hint = lm.currentLanguage == .zh ? "坚持记录，才能看到自己的变化趋势"
            : lm.currentLanguage == .ja ? "継続的な記録で感情の変化を把握できます"
            : "Consistent tracking helps you see your emotional trends"

        return Button(action: {
            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: "bell.badge")
                    .font(.title3)
                    .foregroundColor(.cathierAccent)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text(hint)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(Color.cathierAccentLight)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Today Intensity Arc

private struct TodayIntensityArc: View {
    let checkIns: [CheckIn]

    private var sorted: [CheckIn] {
        checkIns.sorted { $0.date < $1.date }
    }

    var body: some View {
        let items = Array(sorted.prefix(10))
        VStack(alignment: .leading, spacing: 4) {
            ZStack {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 1)
                    .frame(maxWidth: .infinity)
                HStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.offset) { idx, ci in
                        if idx > 0 { Spacer() }
                        Circle()
                            .fill(dotColor(ci.intensity))
                            .frame(width: 10, height: 10)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: 10)
            HStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, ci in
                    if idx > 0 { Spacer() }
                    Text(timeLabel(ci.date))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityHidden(true)
    }

    private func dotColor(_ intensity: Int) -> Color {
        switch intensity {
        case ..<4: return .yellow
        case ..<7: return .cathierAccent
        default:   return .red
        }
    }

    private func timeLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
```

What was removed compared to the prior file:
- `@State` flags: `showingInsights`, `showingBrainTrainer`, `showingJokeHistory`, `showingHealth`
- `healthService` and the implicit `@State`-tracked `HealthKitService.shared`
- Service accessors: `jokeService`, `aiFrontierService`
- Computed prop: `hasNewPatterns`, `weeklyTopEmotions`, `weeklySnapshot`, `weeklySnapshotCard(_:)`, `WeeklySnapshot` struct
- View members: `dailyJokeSection`, `jokeLoadingCard`, `jokeRetryCard`, `aiFrontierSection`, `aiNewsLoadingCard`, `aiNewsRetryCard`, `brainTrainerSection`, `healthSection`, `insightsNudgeCard`
- View calls: `WeeklyPracticeRow`, `WeeklyEmotionSummary`, `weeklySnapshotCard`, `insightsNudgeCard` from `body`
- `.task(id: "joke")`, `.task(id: "aiFrontier")` on `body`
- `.sheet` for joke / brain-trainer / insights / health
- The bottom helper structs `WeeklyPracticeRow`, `WeeklySparkline`, `WeeklyEmotionSummary` (already gone after Tasks 1–3)
- Sheet helpers `jokeSheetDoneLabel`, `brainTrainerSheetCancelLabel`, `healthSheetCancelLabel` (introduced transiently in Tasks 5/6/7)

What remains: greeting, milestone banner, reminder nudge, main CTA, today's records, daily journal section, and the local `TodayIntensityArc`.

- [ ] **Step 2: Build**

```bash
xcodebuild -project Cathier.xcodeproj -scheme Cathier -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -30
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Manual smoke check**

Launch in simulator. Open 此刻 tab and verify the page now contains only:
1. Greeting + streak (top)
2. Milestone banner (only when a new milestone is reached)
3. Evening reminder nudge (only after 18:00 with notifications off and no check-in)
4. Big main CTA
5. Today's check-ins list (only if there's at least one)
6. Today's daily journal card or write prompt

Tap the main CTA → check-in flow opens (sheet). Tap "写下今日收获" → journal entry sheet opens. No other modals/sheets are reachable from Today.

Switch to 日记 tab → 本周 header still appears at top (from Task 9). 设置 tab → 探索 section still has all 5 entries (from Task 8).

- [ ] **Step 4: Commit**

```bash
git add Cathier/Views/TodayView.swift
git commit -m "$(cat <<'EOF'
refactor: slim TodayView to focused-practice essentials

Drops 8 sections (weekly analytics + joke + AI frontier + brain
trainer + health + insights nudge) and the state, .task, and sheet
plumbing that supported them. Realigns with DESIGN.md's "focused
practice space" thesis. All removed functionality is reachable from
JournalView (analytics) or Settings → 探索 (utilities/entertainment).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: Build verification & end-to-end smoke test

**Files:** none modified. Verification only.

- [ ] **Step 1: Run the full build**

```bash
xcodebuild -project Cathier.xcodeproj -scheme Cathier -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -30
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 2: Run all tests**

```bash
xcodebuild -project Cathier.xcodeproj -scheme Cathier -destination 'platform=iOS Simulator,name=iPhone 16' test 2>&1 | tail -30
```

Expected: all tests pass, including the new `WeeklySnapshotTests`.

- [ ] **Step 3: Smoke checklist (simulator, fresh launch)**

Walk through every relocation visually. Tick each:

- [ ] Today tab shows ≤6 sections (greeting, [milestone], [reminder], CTA, [today records], journal). Count by inspection: should be 4–6 visible sections.
- [ ] Tapping the main CTA opens check-in flow.
- [ ] Today's daily journal write prompt opens journal entry sheet.
- [ ] Journal tab shows 本周 header at top with practice dots, top-5 chips, intensity card.
- [ ] Searching in Journal hides the 本周 header.
- [ ] When ≥7 check-ins exist and ≥5 new since last analysis, the Journal toolbar Insights icon shows a red dot.
- [ ] Tapping the Insights icon opens InsightsView.
- [ ] Tapping the intensity snapshot card opens InsightsView.
- [ ] Settings → 探索 shows 5 rows.
- [ ] Tapping 身体数据 pushes HealthInsight (single nav bar, back button works).
- [ ] Tapping 吃一堑长一智 pushes BrainTrainer intro (single nav bar, back button works).
- [ ] Tapping 今日AI最前沿 pushes AIFrontierView (loads news on first appear via .task).
- [ ] Tapping AI 冷笑话 pushes JokeHistoryView (generates today's joke on first appear via .task).
- [ ] No more daily joke / AI frontier / BrainTrainer / Health entry on Today.
- [ ] No more weekly practice dots / top emotions / intensity card on Today.

If any item fails, identify the offending task and fix forward (no rebase).

- [ ] **Step 4: Verify trigger relocation by source-grep**

```bash
grep -n "generateTodayJokeIfNeeded\|generateTodayNewsIfNeeded" Cathier/Views/*.swift Cathier/Views/**/*.swift
```

Expected output:
```
Cathier/Views/AIFrontierView.swift:<line>:        .task { await service.generateTodayNewsIfNeeded() }
Cathier/Views/JokeHistoryView.swift:<line>:        .task { await jokeService.generateTodayJokeIfNeeded() }
```

Specifically: `TodayView.swift` should NOT appear in this output. If it does, Task 11 missed a `.task` removal.

- [ ] **Step 5: Verify TodayView shrunk significantly**

```bash
wc -l Cathier/Views/TodayView.swift
```

Expected: well under 600 lines (was 1086). If it's still over 700, some sections were missed.

- [ ] **Step 6: Final commit (if any verification fixes)**

If steps 1–5 surface issues, fix them and commit with message describing the fix. If everything passes on first run, no commit needed for this task.

---

## Self-Review (run before handing off)

**Spec coverage:**
- §3.1 Today new structure → Task 11 ✅
- §3.2 Journal 本周 header → Task 9 ✅
- §3.2 Insights nudge merged into toolbar red dot → Task 10 ✅
- §3.3 Settings → 探索 four new entries → Task 8 ✅
- §3.4 Trigger relocation (joke + AI frontier) → Tasks 5, 4 ✅
- §4 New components (WeeklyPracticeRow, WeeklyEmotionSummary, WeeklySnapshotCard, AIFrontierView) → Tasks 1, 2, 3, 4 ✅
- §4 Refactored detail views → Tasks 5, 6, 7 ✅
- §6 Success criterion "TodayView ≤6 sections" → Task 12 Step 3 ✅
- §6 Success criterion "LLM call only when visible" → Task 12 Step 4 ✅
- §6 Success criterion "TodayView line count down" → Task 12 Step 5 ✅

**Type/name consistency:**
- `WeeklySnapshot` struct: defined in Task 3, used in Task 9. ✅
- `WeeklySnapshot.compute(from:)` signature: takes `[CheckIn]`, returns `WeeklySnapshot?`. Used identically in TodayView (during Tasks 1–10) and JournalView (Task 9). ✅
- `WeeklySnapshotCard(snapshot:checkIns:onTap:)`: same call signature in TodayView (Task 3) and JournalView (Task 9). ✅
- `BrainTrainerView`: created in Task 6, referenced in Task 8 settings wiring and Task 6 today wrapper. ✅
- `JokeHistoryView`, `HealthInsightView`, `AIFrontierView`: same names throughout. ✅
- `hasNewPatterns`: identical formula in TodayView (deleted Task 11) and JournalView (added Task 10). Same UserDefaults key `"lastInsightCheckInCount"`. ✅

**Placeholder scan:**
No "TBD", "TODO", or "fill in" sentinels in any task. Each step has either exact code or exact commands.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-07-home-simplification.md`. Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration. Good for this plan since each task is well-bounded and the build gate gives a clean success signal.

**2. Inline Execution** — Execute tasks in this session using executing-plans. Good if you want to watch the progression live and intervene at checkpoints.

Which approach?
