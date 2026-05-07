import SwiftUI
import SwiftData

struct TodayView: View {
    @Query(sort: \CheckIn.date, order: .reverse) private var checkIns: [CheckIn]
    @Query(sort: \DailyJournal.date, order: .reverse) private var journals: [DailyJournal]
    @State private var showingCheckIn = false
    @State private var showingJournalEntry = false
    @State private var journalToEdit: DailyJournal? = nil
    @State private var showingInsights = false
    @State private var showingBrainTrainer = false
    @State private var showingJokeHistory = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("lastCelebratedStreakMilestone") private var lastCelebratedStreakMilestone: Int = 0
    @AppStorage("personalBestStreak") private var personalBestStreak: Int = 0
    @State private var showingHealth = false
    @State private var dismissedMilestone: Int = 0
    @Environment(LanguageManager.self) private var lm
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var healthService = HealthKitService.shared

    private let streakMilestones = [3, 7, 14, 30]

    private var milestoneToShow: Int? {
        let reached = streakMilestones.filter { $0 <= streakDays }.max()
        guard let milestone = reached,
              milestone > lastCelebratedStreakMilestone,
              milestone != dismissedMilestone else { return nil }
        return milestone
    }

    private var jokeService: JokeService { JokeService.shared }
    private var aiFrontierService: AIFrontierService { AIFrontierService.shared }

    private var hasNewPatterns: Bool {
        let lastAnalyzed = UserDefaults.standard.integer(forKey: "lastInsightCheckInCount")
        return checkIns.count >= 7 && checkIns.count >= lastAnalyzed + 5
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
                    // Greeting header
                    headerView
                        .padding(.horizontal, 20)

                    // Streak milestone celebration (one-time per milestone)
                    if let milestone = milestoneToShow {
                        streakMilestoneBanner(milestone)
                            .padding(.horizontal, 20)
                            .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                    }

                    // Weekly practice dots (shown once there's any history)
                    if !checkIns.isEmpty {
                        WeeklyPracticeRow(checkIns: Array(checkIns))
                            .padding(.horizontal, 20)
                    }

                    // Weekly emotion frequency (shown when emotions have been recorded this week)
                    if !weeklyTopEmotions.isEmpty {
                        WeeklyEmotionSummary(topEmotions: weeklyTopEmotions)
                            .padding(.horizontal, 20)
                    }

                    // 7-day trend snapshot
                    if let snapshot = weeklySnapshot {
                        WeeklySnapshotCard(snapshot: snapshot, checkIns: Array(checkIns)) {
                            showingInsights = true
                        }
                        .padding(.horizontal, 20)
                    }

                    // Reminder nudge (evening, no check-in, notifications off)
                    if !notificationsEnabled && todayCheckIns.isEmpty
                        && Calendar.current.component(.hour, from: Date()) >= 18 {
                        reminderNudgeCard
                            .padding(.horizontal, 20)
                    }

                    // Main CTA
                    startButton
                        .padding(.horizontal, 20)

                    // Today's check-ins
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

                    // Pattern nudge
                    if hasNewPatterns {
                        insightsNudgeCard
                            .padding(.horizontal, 20)
                    }

                    // Daily journal section
                    dailyJournalSection
                        .padding(.horizontal, 20)

                    // Daily joke section
                    dailyJokeSection
                        .padding(.horizontal, 20)

                    // AI Frontier news section
                    aiFrontierSection
                        .padding(.horizontal, 20)

                    // BrainTrainer entry
                    brainTrainerSection
                        .padding(.horizontal, 20)

                    // Health data entry
                    healthSection
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
            .task(id: "joke") {
                await jokeService.generateTodayJokeIfNeeded()
            }
            .task(id: "aiFrontier") {
                await aiFrontierService.generateTodayNewsIfNeeded()
            }
            .sheet(isPresented: $showingCheckIn) {
                CheckInFlowView()
            }
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
            .sheet(isPresented: $showingInsights) {
                InsightsView()
                    .environment(lm)
            }
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
            .sheet(isPresented: $showingJournalEntry) {
                DailyJournalEntryView(existing: journalToEdit) {
                    journalToEdit = nil
                }
            }
            .sheet(isPresented: $showingHealth) {
                HealthInsightView()
                    .environment(lm)
            }
        }
    }

    // MARK: - Daily Joke Section

    private var dailyJokeSection: some View {
        let title: String
        let loadingHint: String
        let errorHint: String
        switch lm.currentLanguage {
        case .zh:
            title = "AI 冷笑话"
            loadingHint = "正在生成今日笑话…"
            errorHint = "生成失败，点击重试"
        case .ja:
            title = "AI コールドジョーク"
            loadingHint = "今日のジョークを生成中…"
            errorHint = "生成に失敗しました。再試行するにはタップ"
        default:
            title = "AI Cold Joke"
            loadingHint = "Generating today's joke…"
            errorHint = "Generation failed — tap to retry"
        }

        return VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            if let joke = jokeService.todayJoke {
                DailyJokeCard(joke: joke) {
                    showingJokeHistory = true
                }
            } else if jokeService.isGenerating {
                jokeLoadingCard(hint: loadingHint)
            } else {
                jokeRetryCard(hint: jokeService.generateError != nil ? errorHint : loadingHint) {
                    Task { await jokeService.generateTodayJokeIfNeeded() }
                }
            }
        }
    }

    private func jokeLoadingCard(hint: String) -> some View {
        HStack(spacing: 14) {
            ProgressView()
                .tint(Color.cathierAccent)
                .frame(width: 48, height: 48)
            Text(hint)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(16)
        .background(Color.cathierSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func jokeRetryCard(hint: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.cathierAccent.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color.cathierAccent)
                }
                Text(hint)
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

    // MARK: - AI Frontier Section

    private var aiFrontierSection: some View {
        let title: String
        let loadingHint: String
        let errorHint: String
        switch lm.currentLanguage {
        case .zh:
            title = "今日AI最前沿"
            loadingHint = "正在检索最前沿AI动态…"
            errorHint = "获取失败，点击重试"
        case .ja:
            title = "今日のAIフロンティア"
            loadingHint = "最先端のAI動向を取得中…"
            errorHint = "取得に失敗しました。再試行するにはタップ"
        default:
            title = "AI Frontier"
            loadingHint = "Fetching today's AI frontier…"
            errorHint = "Failed to load — tap to retry"
        }

        return VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            if let news = aiFrontierService.todayNews {
                AIFrontierCard(news: news) {
                    Task { await aiFrontierService.regenerate() }
                }
            } else if aiFrontierService.isGenerating {
                aiNewsLoadingCard(hint: loadingHint)
            } else {
                aiNewsRetryCard(hint: aiFrontierService.generateError != nil ? errorHint : loadingHint) {
                    Task { await aiFrontierService.generateTodayNewsIfNeeded() }
                }
            }
        }
    }

    private func aiNewsLoadingCard(hint: String) -> some View {
        HStack(spacing: 14) {
            ProgressView()
                .tint(Color.cathierAccent)
                .frame(width: 48, height: 48)
            Text(hint)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(16)
        .background(Color.cathierSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func aiNewsRetryCard(hint: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.cathierAccent.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "sparkles")
                        .font(.system(size: 20))
                        .foregroundColor(Color.cathierAccent)
                }
                Text(hint)
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

    // MARK: - BrainTrainer Section

    private var brainTrainerSection: some View {
        let title: String
        let hint: String
        switch lm.currentLanguage {
        case .zh:
            title = "吃一堑长一智"
            hint = "踩了坑？花几分钟训练新模型"
        case .ja:
            title = "失敗から学ぶ"
            hint = "つまずいた？数分でモデルを更新"
        default:
            title = "Lesson from Setback"
            hint = "Just tripped up? A quick 5-step review"
        }

        return VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            Button(action: { showingBrainTrainer = true }) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.cathierAccent.opacity(0.15))
                            .frame(width: 48, height: 48)
                        Image(systemName: "gearshape.2.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color.cathierAccent)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(hint)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
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
    }

    // MARK: - Health Section

    private var healthSection: some View {
        let title: String
        let hint: String
        switch lm.currentLanguage {
        case .zh:
            title = "身体数据"
            hint = healthService.summary.hasAnyData
                ? "今日 \(healthService.summary.stepsToday.formatted()) 步 · AI健康洞察"
                : "连接步数、心率、睡眠，读懂身体信号"
        case .ja:
            title = "身体データ"
            hint = healthService.summary.hasAnyData
                ? "今日 \(healthService.summary.stepsToday.formatted()) 歩 · AI健康インサイト"
                : "歩数・心拍数・睡眠を連携して身体のシグナルを読み解く"
        default:
            title = "Health Data"
            hint = healthService.summary.hasAnyData
                ? "\(healthService.summary.stepsToday.formatted()) steps today · AI insights"
                : "Connect steps, heart rate & sleep for body-awareness insights"
        }

        return VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            Button(action: { showingHealth = true }) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.cathierAccent.opacity(0.15))
                            .frame(width: 48, height: 48)
                        Image(systemName: "heart.text.clipboard.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color.cathierAccent)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(hint)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
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
    }

    // MARK: - Insights Nudge

    private var insightsNudgeCard: some View {
        let title = lm.currentLanguage == .zh ? "新规律正在浮现" : lm.currentLanguage == .ja ? "新しいパターンが見えてきた" : "Patterns emerging"
        let hint = lm.currentLanguage == .zh
            ? "已记录 \(checkIns.count) 次，点击发现你的情绪模式"
            : lm.currentLanguage == .ja
                ? "\(checkIns.count) 件の記録から感情のパターンを発見"
                : "\(checkIns.count) check-ins — tap to discover your patterns"

        return Button(action: { showingInsights = true }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.cathierAccent.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 20))
                        .foregroundColor(Color.cathierAccent)
                }
                VStack(alignment: .leading, spacing: 3) {
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
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color.cathierSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
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
            if let next = nextMilestoneTarget {
                milestoneProgressBar(toward: next)
                    .padding(.top, 4)
                    .padding(.horizontal, 8)
            }
        }
        .frame(width: 56)
        .padding(.vertical, 10)
        .background(Color.cathierAccentLight)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var nextMilestoneTarget: Int? {
        streakMilestones.first { $0 > streakDays }
    }

    private func milestoneProgressBar(toward target: Int) -> some View {
        let from = streakMilestones.last { $0 < target } ?? 0
        let progress = CGFloat(streakDays - from) / CGFloat(target - from)
        return ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.cathierAccent.opacity(0.2))
                .frame(height: 3)
            Capsule()
                .fill(Color.cathierAccent)
                .frame(height: 3)
                .scaleEffect(x: max(0, min(1, progress)), y: 1, anchor: .leading)
                .animation(.easeOut(duration: 0.3), value: progress)
        }
        .accessibilityHidden(true)
    }

    private var personalBestText: String {
        switch lm.currentLanguage {
        case .zh: return "最佳\(personalBestStreak)"
        case .ja: return "最高\(personalBestStreak)"
        default:   return "Best\(personalBestStreak)"
        }
    }

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

    private var streakDays: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dates = Set(checkIns.map { calendar.startOfDay(for: $0.date) })

        // Start from today; if no check-in today, try yesterday (streak still alive)
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

    // MARK: - Weekly Snapshot

    private var weeklySnapshot: WeeklySnapshot? {
        WeeklySnapshot.compute(from: Array(checkIns))
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

    private var jokeSheetDoneLabel: String {
        switch lm.currentLanguage {
        case .zh: return "完成"
        case .ja: return "完了"
        default:  return "Done"
        }
    }

    private var brainTrainerSheetCancelLabel: String {
        switch lm.currentLanguage {
        case .zh: return "取消"
        case .ja: return "キャンセル"
        default:  return "Cancel"
        }
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
            // Dots row with connecting line
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
            // Time labels aligned to match dot positions
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

