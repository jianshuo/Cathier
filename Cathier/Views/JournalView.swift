import SwiftUI
import SwiftData

struct JournalView: View {
    @Query(sort: \CheckIn.date, order: .reverse) private var checkIns: [CheckIn]
    @Environment(\.modelContext) private var modelContext
    @Environment(LanguageManager.self) private var lm
    @Environment(FriendViewModel.self) private var friendVM
    @State private var showInsights = false
    @State private var searchText = ""
    @State private var pendingDelete: CheckIn? = nil
    @State private var deleteTask: Task<Void, Never>? = nil

    private var filteredCheckIns: [CheckIn] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        var result = query.isEmpty ? checkIns : checkIns.filter { matches($0, query: query) }
        if let pending = pendingDelete {
            result = result.filter { $0.id != pending.id }
        }
        return result
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
            Group {
                if checkIns.isEmpty && pendingDelete == nil {
                    emptyState
                } else {
                    journalContent
                        .searchable(text: $searchText, prompt: searchPrompt)
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
            .overlay(alignment: .bottom) {
                if pendingDelete != nil {
                    undoToast
                        .transition(.move(edge: .bottom).combined(with: .opacity))
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

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 52))
                .foregroundColor(.secondary.opacity(0.4))
            Text(lm.journalEmpty)
                .font(.headline)
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

    private func sectionTitle(for date: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(date) { return lm.journalToday }
        if calendar.isDateInYesterday(date) { return lm.journalYesterday }
        let formatter = DateFormatter()
        formatter.dateFormat = lm.journalDateFormat
        return formatter.string(from: date)
    }
}
