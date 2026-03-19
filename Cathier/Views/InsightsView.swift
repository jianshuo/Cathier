import SwiftUI
import SwiftData
import Charts

struct InsightsView: View {
    @Environment(LanguageManager.self) private var lm
    @Query(sort: \CheckIn.date, order: .forward) private var checkIns: [CheckIn]
    @State private var vm = InsightsViewModel()
    @State private var fetchError: String?

    var body: some View {
        NavigationStack {
            Group {
                if let err = fetchError {
                    fetchErrorState(err)
                } else if checkIns.count < 7 {
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
            .background(vm.isLoading ? Color.orange.opacity(0.6) : Color.orange)
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
            // Intensity chart
            intensityChart

            // Narrative
            Text(text)
                .font(.body)
                .lineSpacing(5)
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
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
                .foregroundStyle(Color.orange.gradient)

                AreaMark(
                    x: .value("Date", c.date),
                    y: .value("Intensity", c.intensity)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.orange.opacity(0.15).gradient)
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
            .foregroundStyle(.orange)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.1))
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

    // MARK: - Fetch error state

    private func fetchErrorState(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.icloud")
                .font(.system(size: 52))
                .foregroundStyle(.orange.opacity(0.7))
            Text(lm.insightsLoadError)
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
                .background(isSelected ? Color.orange : Color(.tertiarySystemBackground))
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
