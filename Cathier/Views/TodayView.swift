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
    @State private var showingHealth = false
    @State private var showingDictionary = false
    @Environment(LanguageManager.self) private var lm
    @State private var healthService = HealthKitService.shared

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

                    // Awareness dictionary entry
                    dictionarySection
                        .padding(.horizontal, 20)

                    // Pattern nudge
                    if hasNewPatterns {
                        insightsNudgeCard
                            .padding(.horizontal, 20)
                    }

                    // Daily journal section
                    dailyJournalSection
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
            .background(ColorfulBlackBackground())
            .navigationTitle(lm.todayNavTitle)
            .onAppear {
                if !todayCheckIns.isEmpty {
                    NotificationService.shared.clearBadge()
                }
            }
            .sheet(isPresented: $showingCheckIn) {
                CheckInFlowView()
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
            .sheet(isPresented: $showingDictionary) {
                EmotionExplorerView()
                    .environment(lm)
            }
        }
    }

    // MARK: - Dictionary Section

    private var dictionarySection: some View {
        let title: String
        let hint: String
        switch lm.currentLanguage {
        case .zh:
            title = "觉察词典"
            hint = "不知道怎么描述感受？查查词典"
        case .ja:
            title = "気づき辞典"
            hint = "気持ちをうまく表せないとき、辞典で調べてみて"
        default:
            title = "Awareness Dictionary"
            hint = "Can't find the right word for what you feel?"
        }

        return VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            Button(action: { showingDictionary = true }) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.cathierAccent.opacity(0.15))
                            .frame(width: 48, height: 48)
                        Image(systemName: "character.book.closed.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color.cathierAccent)
                    }
                    Text(hint)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
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

    private var brainTrainerSheetCancelLabel: String {
        switch lm.currentLanguage {
        case .zh: return "取消"
        case .ja: return "キャンセル"
        default:  return "Cancel"
        }
    }

    private var healthSheetCancelLabel: String {
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
