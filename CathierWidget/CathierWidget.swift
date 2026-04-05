import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct CathierEntry: TimelineEntry {
    let date: Date
    let todayCount: Int
    let latestEmotions: [String]
}

// MARK: - Timeline Provider

struct CathierWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> CathierEntry {
        CathierEntry(date: .now, todayCount: 2, latestEmotions: ["平静", "期待"])
    }

    func getSnapshot(in context: Context, completion: @escaping (CathierEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CathierEntry>) -> Void) {
        // Refresh at next midnight so the count resets for a new day
        let midnight = Calendar.current.startOfDay(for: .now).addingTimeInterval(86400)
        completion(Timeline(entries: [entry()], policy: .after(midnight)))
    }

    private func entry() -> CathierEntry {
        CathierEntry(
            date: .now,
            todayCount: WidgetDataStore.todayCount,
            latestEmotions: WidgetDataStore.todayLatestEmotions
        )
    }
}

// MARK: - Widget Definition

struct CathierWidget: Widget {
    let kind = "CathierWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CathierWidgetProvider()) { entry in
            CathierWidgetView(entry: entry)
                .containerBackground(Color(red: 0.969, green: 0.961, blue: 0.945), for: .widget)
        }
        .configurationDisplayName("情绪感知")
        .description("快速记录今日情绪，查看当日进度")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget View

struct CathierWidgetView: View {
    let entry: CathierEntry
    @Environment(\.widgetFamily) private var family

    private var accentColor: Color { Color(red: 0.949, green: 0.439, blue: 0.039) } // #F2700A
    private var textPrimary: Color { Color(red: 0.102, green: 0.086, blue: 0.075) } // #1A1613
    private var textSecondary: Color { Color(red: 0.361, green: 0.337, blue: 0.314) } // #5C5650

    var body: some View {
        switch family {
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    // MARK: Small (2×2)

    private var smallView: some View {
        Link(destination: URL(string: "cathier://checkin")!) {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text("情绪感知")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(textSecondary)
                    Spacer()
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundColor(accentColor)
                }

                Spacer()

                // Count
                if entry.todayCount == 0 {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("还没有")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(textPrimary)
                        Text("今日记录")
                            .font(.caption)
                            .foregroundColor(textSecondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(entry.todayCount)")
                            .font(.system(size: 36, weight: .semibold, design: .monospaced))
                            .foregroundColor(accentColor)
                        Text("今日记录")
                            .font(.caption)
                            .foregroundColor(textSecondary)
                    }
                }

                Spacer()

                // CTA pill
                Text("记录情绪 →")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(accentColor)
                    .clipShape(Capsule())
            }
            .padding(14)
        }
    }

    // MARK: Medium (2×4)

    private var mediumView: some View {
        Link(destination: URL(string: "cathier://checkin")!) {
            HStack(spacing: 16) {
                // Left: count block
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundColor(accentColor)
                        Text("情绪感知")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(textSecondary)
                    }

                    Spacer()

                    if entry.todayCount == 0 {
                        Text("今日\n待记录")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(textPrimary)
                            .lineSpacing(2)
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(entry.todayCount)")
                                .font(.system(size: 40, weight: .semibold, design: .monospaced))
                                .foregroundColor(accentColor)
                            Text("次")
                                .font(.subheadline)
                                .foregroundColor(textSecondary)
                        }
                    }

                    Text("今日记录")
                        .font(.caption2)
                        .foregroundColor(textSecondary)

                    Spacer()

                    Text("记录情绪 →")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(accentColor)
                        .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()
                    .background(Color(red: 0.878, green: 0.867, blue: 0.851)) // #E0DDD6

                // Right: latest emotions
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.todayCount == 0 ? "今日情绪" : "最近情绪")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(textSecondary)

                    if entry.latestEmotions.isEmpty {
                        Spacer()
                        Text("开始第一次\n情绪感知")
                            .font(.caption)
                            .foregroundColor(textSecondary)
                            .lineSpacing(2)
                        Spacer()
                    } else {
                        FlowLayout(spacing: 4) {
                            ForEach(entry.latestEmotions.prefix(6), id: \.self) { emotion in
                                Text(emotion)
                                    .font(.caption2)
                                    .foregroundColor(accentColor)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Color(red: 0.996, green: 0.922, blue: 0.847)) // accentLight
                                    .clipShape(Capsule())
                            }
                        }
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
        }
    }
}

// MARK: - FlowLayout (reused from main app)

/// Simple wrapping horizontal layout for emotion chips.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: ProposedViewSize(bounds.size), subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].origin.x,
                                     y: bounds.minY + result.frames[index].origin.y),
                          proposal: .unspecified)
        }
    }

    private struct ArrangeResult {
        var frames: [CGRect]
        var size: CGSize
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> ArrangeResult {
        var frames = [CGRect]()
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return ArrangeResult(
            frames: frames,
            size: CGSize(width: maxWidth, height: y + rowHeight)
        )
    }
}

// MARK: - Widget Bundle

@main
struct CathierWidgetBundle: WidgetBundle {
    var body: some Widget {
        CathierWidget()
    }
}
