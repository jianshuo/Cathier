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
