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
