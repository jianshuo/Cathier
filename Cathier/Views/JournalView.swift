import SwiftUI
import SwiftData

struct JournalView: View {
    @Query(sort: \CheckIn.date, order: .reverse) private var checkIns: [CheckIn]
    @Environment(\.modelContext) private var modelContext

    private var groupedCheckIns: [(String, [CheckIn])] {
        let calendar = Calendar.current
        var groups: [String: [CheckIn]] = [:]
        for checkIn in checkIns {
            let key = sectionTitle(for: checkIn.date, calendar: calendar)
            groups[key, default: []].append(checkIn)
        }
        return groups.sorted { lhs, rhs in
            let lDate = groups[lhs.key]?.first?.date ?? .distantPast
            let rDate = groups[rhs.key]?.first?.date ?? .distantPast
            return lDate > rDate
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if checkIns.isEmpty {
                    emptyState
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
                                                delete(checkIn)
                                            } label: {
                                                Label("删除", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("日记")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 52))
                .foregroundColor(.secondary.opacity(0.4))
            Text("还没有记录")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("完成第一次签到后，记录会出现在这里。")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private func delete(_ checkIn: CheckIn) {
        modelContext.delete(checkIn)
        try? modelContext.save()
    }

    private func sectionTitle(for date: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(date) { return "今天" }
        if calendar.isDateInYesterday(date) { return "昨天" }
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }
}
