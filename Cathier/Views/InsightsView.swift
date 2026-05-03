import SwiftUI
import SwiftData
import Charts

struct InsightsView: View {
    @Environment(LanguageManager.self) private var lm
    @Query(sort: \CheckIn.date, order: .forward) private var checkIns: [CheckIn]
    @State private var vm = InsightsViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if checkIns.count < 7 {
                    emptyState
                } else {
                    mainContent
                }
            }
            .navigationTitle(lm.insightsNavTitle)
            .navigationBarTitleDisplayMode(.large)
        }
        .interactiveDismissDisabled(vm.isLoading)
    }

    // MARK: - Main content

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Focus picker
                VStack(alignment: .leading, spacing: 10) {
                    Text(lm.insightsFocusTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(InsightFocusMode.allCases, id: \.self) { mode in
                                FocusChip(mode: mode, isSelected: vm.selectedFocus == mode) {
                                    vm.setFocus(mode)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Analyze button
                analyzeButton

                // Current insight + chart
                switch vm.loadState {
                case .idle:
                    EmptyView()
                case .loading:
                    loadingView
                case .loaded(let text):
                    insightContent(text)
                case .error(let msg):
                    errorBanner(msg)
                }

                // History
                if !vm.insightHistory.isEmpty {
                    historySection
                }
            }
            .padding(.vertical)
        }
        .task {
            guard vm.insightHistory.isEmpty, checkIns.count >= 7, !vm.isLoading else { return }
            await vm.analyze(allCheckIns: checkIns)
        }
    }

    // MARK: - Analyze button

    private var analyzeButton: some View {
        let title = vm.isLoading
            ? lm.insightsLoading
            : (vm.insightHistory.isEmpty ? lm.insightsAnalyze : lm.insightsRefresh)

        return Button {
            Task { await vm.analyze(allCheckIns: checkIns) }
        } label: {
            HStack(spacing: 8) {
                if vm.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(0.85)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(vm.isLoading ? Color.cathierAccent.opacity(0.6) : Color.cathierAccent)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(vm.isLoading)
        .padding(.horizontal)
        .animation(.easeInOut(duration: 0.2), value: vm.isLoading)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.4)
            Text(lm.insightsLoading)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Insight content

    private func insightContent(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            intensityChart

            let topEmos = topEmotions
            if topEmos.count >= 3 {
                emotionFrequencyChart(topEmos)
            }

            let wdData = weekdayData
            if wdData.count >= 3 {
                weekdayChart(wdData)
            }

            Text(text)
                .font(.cathierSerif(.body))
                .lineSpacing(5)
                .padding()
                .background(Color.cathierAccentLight)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal)
        }
    }

    // MARK: - Emotion frequency chart

    private var topEmotions: [(emotion: String, count: Int)] {
        var freq: [String: Int] = [:]
        for c in checkIns {
            for e in c.emotions { freq[e, default: 0] += 1 }
        }
        return freq.sorted { $0.value > $1.value }.prefix(6).map { (emotion: $0.key, count: $0.value) }
    }

    private func emotionFrequencyChart(_ data: [(emotion: String, count: Int)]) -> some View {
        let title = lm.currentLanguage == .zh ? "高频情绪" : lm.currentLanguage == .ja ? "頻出感情" : "Top Emotions"
        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Chart(data, id: \.emotion) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("Emotion", item.emotion)
                )
                .foregroundStyle(Color.cathierAccent.gradient)
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    AxisValueLabel()
                }
            }
            .frame(height: CGFloat(data.count) * 34 + 16)
            .padding(.horizontal)
        }
    }

    // MARK: - Weekday pattern chart

    private var weekdayData: [(label: String, avg: Double)] {
        let calendar = Calendar.current
        var groups: [Int: [Int]] = [:]
        for c in checkIns {
            let wd = calendar.component(.weekday, from: c.date)
            groups[wd, default: []].append(c.intensity)
        }
        let isZh = lm.currentLanguage == .zh
        let isJa = lm.currentLanguage == .ja
        func label(_ wd: Int) -> String {
            switch wd {
            case 1: return isZh ? "周日" : isJa ? "日" : "Sun"
            case 2: return isZh ? "周一" : isJa ? "月" : "Mon"
            case 3: return isZh ? "周二" : isJa ? "火" : "Tue"
            case 4: return isZh ? "周三" : isJa ? "水" : "Wed"
            case 5: return isZh ? "周四" : isJa ? "木" : "Thu"
            case 6: return isZh ? "周五" : isJa ? "金" : "Fri"
            case 7: return isZh ? "周六" : isJa ? "土" : "Sat"
            default: return ""
            }
        }
        return [2, 3, 4, 5, 6, 7, 1].compactMap { wd in
            guard let vals = groups[wd], !vals.isEmpty else { return nil }
            let avg = Double(vals.reduce(0, +)) / Double(vals.count)
            return (label: label(wd), avg: avg)
        }
    }

    private func weekdayChart(_ data: [(label: String, avg: Double)]) -> some View {
        let title = lm.currentLanguage == .zh ? "各天情绪强度均值" : lm.currentLanguage == .ja ? "曜日別平均強度" : "Avg Intensity by Weekday"
        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Chart(data, id: \.label) { item in
                BarMark(
                    x: .value("Day", item.label),
                    y: .value("Avg", item.avg)
                )
                .foregroundStyle(Color.cathierAccent.opacity(0.75).gradient)
                .cornerRadius(4)
            }
            .chartYScale(domain: 0...10)
            .chartXAxis {
                AxisMarks { _ in AxisValueLabel() }
            }
            .frame(height: 120)
            .padding(.horizontal)
        }
    }

    // MARK: - Intensity chart

    private var intensityChart: some View {
        let data = Array(checkIns.suffix(30))
        return VStack(alignment: .leading, spacing: 8) {
            Text(lm.insightsChartTitle)
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Chart(data, id: \.id) { c in
                LineMark(
                    x: .value("Date", c.date),
                    y: .value("Intensity", c.intensity)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.cathierAccent.gradient)

                AreaMark(
                    x: .value("Date", c.date),
                    y: .value("Intensity", c.intensity)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.cathierAccent.opacity(0.15).gradient)
            }
            .chartYScale(domain: 0...10)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    AxisTick(stroke: StrokeStyle(lineWidth: 0))
                    AxisValueLabel(format: .dateTime.month(.defaultDigits).day())
                }
            }
            .frame(height: 140)
            .padding(.horizontal)
        }
    }

    // MARK: - Error banner

    private func errorBanner(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline)
            .foregroundStyle(.cathierAccent)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cathierAccent.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(lm.insightsHistoryTitle)
                .font(.headline)
                .padding(.horizontal)

            ForEach(vm.insightHistory.dropFirst()) { record in
                HistoryCard(record: record)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 52))
                .foregroundStyle(.secondary.opacity(0.4))
            Text(lm.insightsEmptyTitle)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(lm.insightsEmptyHint)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }


}

// MARK: - Focus chip

private struct FocusChip: View {
    let mode: InsightFocusMode
    let isSelected: Bool
    let action: () -> Void

    @Environment(LanguageManager.self) private var lm

    var label: String {
        switch mode {
        case .triggers: return lm.insightsFocusTriggers
        case .growth:   return lm.insightsFocusGrowth
        case .body:     return lm.insightsFocusBody
        case .surprise: return lm.insightsFocusSurprise
        }
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.cathierAccent : Color(.tertiarySystemBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(isSelected ? Color.clear : Color(.separator), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - History card

private struct HistoryCard: View {
    let record: InsightRecord
    @Environment(LanguageManager.self) private var lm
    @State private var isExpanded = false

    private var dateString: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: record.date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(lm.insightsAnalyzedAt) \(dateString)")
                            .font(.subheadline.bold())
                        Text("\(record.checkInCount) check-ins · \(record.focusMode.rawValue)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(record.insightText)
                    .font(.subheadline)
                    .lineSpacing(4)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
