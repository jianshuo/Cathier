import SwiftUI
import SwiftData

struct JournalView: View {
    @Query(sort: \CheckIn.date, order: .reverse) private var checkIns: [CheckIn]
    @Environment(\.modelContext) private var modelContext
    @Environment(LanguageManager.self) private var lm
    @Environment(FriendViewModel.self) private var friendVM
    @Query(sort: \DailyJournal.date, order: .reverse) private var journals: [DailyJournal]
    @State private var showInsights = false
    @State private var searchText = ""
    @State private var pendingDelete: CheckIn? = nil
    @State private var deleteTask: Task<Void, Never>? = nil
    @State private var selectedTab = 0
    @State private var journalToEdit: DailyJournal? = nil
    @State private var showingJournalEntry = false
    @State private var pendingJournalDelete: DailyJournal? = nil
    @State private var deleteJournalTask: Task<Void, Never>? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var filteredCheckIns: [CheckIn] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        var result = query.isEmpty ? checkIns : checkIns.filter { matches($0, query: query) }
        if let pending = pendingDelete {
            result = result.filter { $0.id != pending.id }
        }
        return result
    }

    private var filteredJournals: [DailyJournal] {
        guard let pending = pendingJournalDelete else { return journals }
        return journals.filter { $0.id != pending.id }
    }

    private func matches(_ c: CheckIn, query: String) -> Bool {
        if c.triggerEvent.lowercased().contains(query) { return true }
        if c.note.lowercased().contains(query) { return true }
        if c.aiFeedback.lowercased().contains(query) { return true }
        for e in c.emotions {
            if e.lowercased().contains(query) { return true }
            if lm.display(e).lowercased().contains(query) { return true }
        }
        for p in c.bodyParts {
            if p.lowercased().contains(query) { return true }
            if lm.display(p).lowercased().contains(query) { return true }
        }
        return false
    }

    private var groupedCheckIns: [(String, [CheckIn])] {
        let calendar = Calendar.current
        var groups: [String: [CheckIn]] = [:]
        for checkIn in filteredCheckIns {
            let key = sectionTitle(for: checkIn.date, calendar: calendar)
            groups[key, default: []].append(checkIn)
        }
        return groups.sorted { lhs, rhs in
            let lDate = groups[lhs.key]?.first?.date ?? .distantPast
            let rDate = groups[rhs.key]?.first?.date ?? .distantPast
            return lDate > rDate
        }
    }

    private var searchPrompt: String {
        switch lm.currentLanguage {
        case .zh: return "搜索情绪、事件、笔记…"
        case .ja: return "感情・出来事・メモを検索…"
        default:  return "Search emotions, events, notes…"
        }
    }

    private var noResultsTitle: String {
        switch lm.currentLanguage {
        case .zh: return "没有匹配的记录"
        case .ja: return "該当する記録なし"
        default:  return "No matches"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabPicker
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                if selectedTab == 0 {
                    Group {
                        if checkIns.isEmpty && pendingDelete == nil {
                            emptyState
                        } else {
                            journalContent
                                .searchable(text: $searchText, prompt: searchPrompt)
                        }
                    }
                } else {
                    journalHistoryView
                }
            }
            .navigationTitle(lm.journalNavTitle)
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
            .sheet(isPresented: $showInsights) {
                InsightsView()
                    .environment(lm)
            }
            .sheet(isPresented: $showingJournalEntry) {
                DailyJournalEntryView(existing: journalToEdit) {
                    journalToEdit = nil
                }
            }
            .overlay(alignment: .bottom) {
                if pendingDelete != nil {
                    undoToast
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                        .zIndex(1)
                } else if pendingJournalDelete != nil {
                    journalUndoToast
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                        .zIndex(1)
                }
            }
            .onDisappear {
                if let item = pendingDelete {
                    deleteTask?.cancel()
                    deleteTask = nil
                    commitDelete(item)
                    pendingDelete = nil
                }
                if let item = pendingJournalDelete {
                    deleteJournalTask?.cancel()
                    deleteJournalTask = nil
                    commitDeleteJournal(item)
                    pendingJournalDelete = nil
                }
            }
        }
    }

    @ViewBuilder
    private var journalContent: some View {
        if groupedCheckIns.isEmpty {
            if pendingDelete != nil && searchText.isEmpty {
                Color.clear
            } else {
                noResultsState
            }
        } else {
            List {
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

    // MARK: - Lifetime Stats Card

    @ViewBuilder
    private var lifetimeStatsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 0) {
                statCell(value: checkIns.count, label: statsTotalLabel)
                Spacer()
                statCell(value: uniquePracticeDays, label: statsDaysLabel)
                Spacer()
                statCell(value: distinctEmotionCount, label: statsEmotionsLabel)
            }

            if !topEmotionsAllTime.isEmpty {
                Text(statsFrequentLabel)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                FlowLayout(spacing: 6) {
                    ForEach(Array(topEmotionsAllTime.enumerated()), id: \.offset) { _, item in
                        let color = EmotionData.category(for: item.emotion)?.color ?? .cathierAccent
                        let emoji = EmotionData.emoji(for: item.emotion)
                        Text(emoji.isEmpty ? lm.display(item.emotion) : "\(emoji) \(lm.display(item.emotion))")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(color.opacity(0.12))
                            .foregroundColor(color)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cathierSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func statCell(value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.system(.title2, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var uniquePracticeDays: Int {
        Set(checkIns.map { Calendar.current.startOfDay(for: $0.date) }).count
    }

    private var distinctEmotionCount: Int {
        Set(checkIns.flatMap(\.emotions)).count
    }

    private var topEmotionsAllTime: [(emotion: String, count: Int)] {
        var counts: [String: Int] = [:]
        for ci in checkIns {
            for e in ci.emotions { counts[e, default: 0] += 1 }
        }
        return counts.sorted { $0.value > $1.value }.prefix(3).map { ($0.key, $0.value) }
    }

    private var statsTotalLabel: String {
        switch lm.currentLanguage {
        case .zh: return "次签到"
        case .ja: return "回の記録"
        default:  return "check-ins"
        }
    }

    private var statsDaysLabel: String {
        switch lm.currentLanguage {
        case .zh: return "练习天数"
        case .ja: return "練習日数"
        default:  return "days"
        }
    }

    private var statsEmotionsLabel: String {
        switch lm.currentLanguage {
        case .zh: return "情绪词汇"
        case .ja: return "感情の語彙"
        default:  return "emotions"
        }
    }

    private var statsFrequentLabel: String {
        switch lm.currentLanguage {
        case .zh: return "最常出现"
        case .ja: return "よく現れる"
        default:  return "most frequent"
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 52))
                .foregroundColor(.secondary.opacity(0.4))
            Text(lm.journalEmpty)
                .font(.cathierSerif(.headline))
                .foregroundColor(.secondary)
            Text(lm.journalEmptyHint)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var noResultsState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 52))
                .foregroundColor(.secondary.opacity(0.4))
            Text(noResultsTitle)
                .font(.headline)
                .foregroundColor(.secondary)
            Text("\u{201C}\(searchText.trimmingCharacters(in: .whitespaces))\u{201D}")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func beginSoftDelete(_ checkIn: CheckIn) {
        // Flush any existing pending delete before starting a new one
        if let prev = pendingDelete, prev.id != checkIn.id {
            commitDelete(prev)
        }
        deleteTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) {
            pendingDelete = checkIn
        }
        deleteTask = Task {
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            withAnimation(.easeOut(duration: 0.2)) {
                if pendingDelete?.id == checkIn.id {
                    pendingDelete = nil
                }
            }
            commitDelete(checkIn)
        }
    }

    private func undoDelete() {
        deleteTask?.cancel()
        deleteTask = nil
        withAnimation(.easeInOut(duration: 0.2)) {
            pendingDelete = nil
        }
    }

    private func commitDelete(_ checkIn: CheckIn) {
        if checkIn.shareLevel != nil {
            Task { try? await friendVM.unshareCheckIn(checkIn) }
        }
        modelContext.delete(checkIn)
        try? modelContext.save()
    }

    private var undoToast: some View {
        HStack(spacing: 0) {
            Text(undoDeletedLabel)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
            Button(action: undoDelete) {
                Text(undoActionLabel)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.cathierAccent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.cathierSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 12, y: 4)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    private var undoDeletedLabel: String {
        switch lm.currentLanguage {
        case .zh: return "记录已删除"
        case .ja: return "記録を削除しました"
        default:  return "Record deleted"
        }
    }

    private var undoActionLabel: String {
        switch lm.currentLanguage {
        case .zh: return "撤销"
        case .ja: return "元に戻す"
        default:  return "Undo"
        }
    }

    // MARK: - Journal Delete

    private func beginSoftDeleteJournal(_ journal: DailyJournal) {
        if let prev = pendingJournalDelete, prev.id != journal.id {
            commitDeleteJournal(prev)
        }
        deleteJournalTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) {
            pendingJournalDelete = journal
        }
        deleteJournalTask = Task {
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            withAnimation(.easeOut(duration: 0.2)) {
                if pendingJournalDelete?.id == journal.id {
                    pendingJournalDelete = nil
                }
            }
            commitDeleteJournal(journal)
        }
    }

    private func undoDeleteJournal() {
        deleteJournalTask?.cancel()
        deleteJournalTask = nil
        withAnimation(.easeInOut(duration: 0.2)) {
            pendingJournalDelete = nil
        }
    }

    private func commitDeleteJournal(_ journal: DailyJournal) {
        modelContext.delete(journal)
        try? modelContext.save()
    }

    private var journalUndoToast: some View {
        HStack(spacing: 0) {
            Text(journalUndoDeletedLabel)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
            Button(action: undoDeleteJournal) {
                Text(undoActionLabel)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.cathierAccent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.cathierSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 12, y: 4)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    private var journalUndoDeletedLabel: String {
        switch lm.currentLanguage {
        case .zh: return "日记已删除"
        case .ja: return "日記を削除しました"
        default:  return "Journal deleted"
        }
    }

    private func sectionTitle(for date: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(date) { return lm.journalToday }
        if calendar.isDateInYesterday(date) { return lm.journalYesterday }
        let formatter = DateFormatter()
        formatter.dateFormat = lm.journalDateFormat
        return formatter.string(from: date)
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        Picker("", selection: $selectedTab) {
            Text(checkInsTabLabel).tag(0)
            Text(dailyJournalTabLabel).tag(1)
        }
        .pickerStyle(.segmented)
    }

    private var checkInsTabLabel: String {
        switch lm.currentLanguage {
        case .zh: return "签到"
        case .ja: return "記録"
        default:  return "Check-ins"
        }
    }

    private var dailyJournalTabLabel: String {
        switch lm.currentLanguage {
        case .zh: return "日记"
        case .ja: return "日記"
        default:  return "Journal"
        }
    }

    // MARK: - Daily Journal History

    @ViewBuilder
    private var journalHistoryView: some View {
        if journals.isEmpty && pendingJournalDelete == nil {
            VStack(spacing: 16) {
                Image(systemName: "book.closed")
                    .font(.system(size: 52))
                    .foregroundColor(.secondary.opacity(0.4))
                Text(journalHistoryEmptyTitle)
                    .font(.cathierSerif(.headline))
                    .foregroundColor(.secondary)
                Text(journalHistoryEmptyHint)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if groupedJournals.isEmpty && pendingJournalDelete != nil {
            Color.clear
        } else {
            List {
                ForEach(groupedJournals, id: \.0) { section, entries in
                    Section(section) {
                        ForEach(entries) { journal in
                            journalEntryRow(journal)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .onTapGesture {
                                    journalToEdit = journal
                                    showingJournalEntry = true
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        beginSoftDeleteJournal(journal)
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

    private var groupedJournals: [(String, [DailyJournal])] {
        let calendar = Calendar.current
        var groups: [String: [DailyJournal]] = [:]
        for journal in filteredJournals {
            let key = sectionTitle(for: journal.date, calendar: calendar)
            groups[key, default: []].append(journal)
        }
        return groups.sorted { lhs, rhs in
            let lDate = groups[lhs.key]?.first?.date ?? .distantPast
            let rDate = groups[rhs.key]?.first?.date ?? .distantPast
            return lDate > rDate
        }
    }

    @ViewBuilder
    private func journalEntryRow(_ journal: DailyJournal) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if let mood = journal.dailyMood {
                    Circle()
                        .fill(mood.themeColor)
                        .frame(width: 20, height: 20)
                        .shadow(color: mood.themeColor.opacity(0.3), radius: 3, y: 1)
                    Text(mood.label(for: lm.currentLanguage))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(mood.themeColor)
                }
                Spacer()
                if journal.isShared {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                        .foregroundColor(.cathierAccent.opacity(0.7))
                }
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            if !journal.gains.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(journal.gains)
                    .font(.cathierSerif(.body))
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .lineSpacing(2)
            }
        }
        .padding(14)
        .background(Color.cathierSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var journalHistoryEmptyTitle: String {
        switch lm.currentLanguage {
        case .zh: return "还没有日记"
        case .ja: return "日記がありません"
        default:  return "No journal entries yet"
        }
    }

    private var journalHistoryEmptyHint: String {
        switch lm.currentLanguage {
        case .zh: return "在「此刻」页面记录今日收获"
        case .ja: return "「今」のページで今日の気づきを記録しよう"
        default:  return "Record today's gains from the Now tab"
        }
    }
}
