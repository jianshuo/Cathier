import SwiftUI
import Charts
import SwiftData

struct HealthInsightView: View {
    @Query(sort: \CheckIn.date, order: .reverse) private var checkIns: [CheckIn]
    @Environment(LanguageManager.self) private var lm
    @State private var service = HealthKitService.shared
    @State private var aiInsight: String? = nil
    @State private var isAnalyzing = false
    @State private var analysisError: String? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if !service.isAvailable {
                        unavailableView
                    } else if service.authStatus == .notDetermined {
                        requestAccessCard
                    } else if service.isLoading {
                        loadingView
                    } else {
                        metricsGrid
                        if !service.summary.weeklySteps.isEmpty {
                            weeklyStepsChart
                        }
                        aiInsightSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color.cathierBackground)
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lm.checkInCancel) { dismiss() }
                        .foregroundColor(themeManager.accentColor)
                }
            }
        }
        .task {
            if service.authStatus == .requested {
                await service.loadData()
            }
        }
    }

    // MARK: - Navigation Title

    private var navTitle: String {
        switch lm.currentLanguage {
        case .zh: return "身体数据"
        case .ja: return "身体データ"
        default:  return "Health Data"
        }
    }

    // MARK: - Not Available

    private var unavailableView: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.slash")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text(lm.currentLanguage == .zh ? "此设备不支持健康数据" : lm.currentLanguage == .ja ? "このデバイスはヘルスデータに対応していません" : "Health data is not available on this device")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    // MARK: - Request Access Card

    private var requestAccessCard: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(themeManager.accentColor.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "heart.text.clipboard.fill")
                    .font(.system(size: 32))
                    .foregroundColor(themeManager.accentColor)
            }

            VStack(spacing: 8) {
                Text(lm.currentLanguage == .zh ? "连接健康数据" : lm.currentLanguage == .ja ? "ヘルスデータを連携" : "Connect Health Data")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(lm.currentLanguage == .zh
                     ? "读取步数、心率、睡眠等数据，结合你的情绪记录，获取身心连接的洞察"
                     : lm.currentLanguage == .ja
                        ? "歩数、心拍数、睡眠などのデータを読み取り、感情記録と組み合わせて心身つながりの洞察を提供します"
                        : "Read steps, heart rate, sleep, and more — combined with your emotion records for body-mind insights")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await service.requestAuthorization() }
            } label: {
                Text(lm.currentLanguage == .zh ? "开启访问权限" : lm.currentLanguage == .ja ? "アクセスを許可" : "Allow Access")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(themeManager.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 9999, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(Color.cathierSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(themeManager.accentColor)
            Text(lm.currentLanguage == .zh ? "正在读取健康数据…" : lm.currentLanguage == .ja ? "ヘルスデータを読み込み中…" : "Reading health data…")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    // MARK: - Metrics Grid

    private var metricsGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                metricCard(
                    icon: "figure.walk",
                    color: themeManager.accentColor,
                    title: lm.currentLanguage == .zh ? "今日步数" : lm.currentLanguage == .ja ? "今日の歩数" : "Steps Today",
                    value: service.summary.stepsToday > 0
                        ? "\(service.summary.stepsToday.formatted())"
                        : "—",
                    unit: lm.currentLanguage == .zh ? "步" : lm.currentLanguage == .ja ? "歩" : "steps"
                )
                metricCard(
                    icon: "flame.fill",
                    color: themeManager.accentColor,
                    title: lm.currentLanguage == .zh ? "活动能量" : lm.currentLanguage == .ja ? "活動エネルギー" : "Active Energy",
                    value: service.summary.activeEnergyToday > 0
                        ? "\(Int(service.summary.activeEnergyToday))"
                        : "—",
                    unit: "kcal"
                )
            }
            HStack(spacing: 12) {
                metricCard(
                    icon: "heart.fill",
                    color: .cathierSage,
                    title: lm.currentLanguage == .zh ? "静息心率" : lm.currentLanguage == .ja ? "安静時心拍数" : "Resting HR",
                    value: service.summary.avgRestingHeartRate.map { "\(Int($0.rounded()))" } ?? "—",
                    unit: "bpm"
                )
                metricCard(
                    icon: "moon.fill",
                    color: .cathierSage,
                    title: lm.currentLanguage == .zh ? "平均睡眠" : lm.currentLanguage == .ja ? "平均睡眠" : "Avg Sleep",
                    value: service.summary.avgSleepHours.map { String(format: "%.1f", $0) } ?? "—",
                    unit: lm.currentLanguage == .ja ? "時間" : lm.currentLanguage == .zh ? "小时" : "hrs"
                )
            }
        }
    }

    private func metricCard(icon: String, color: Color, title: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(.title2, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                if value != "—" {
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.cathierSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Weekly Steps Chart

    private var weeklyStepsChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(lm.currentLanguage == .zh ? "近7日步数" : lm.currentLanguage == .ja ? "過去7日間の歩数" : "Steps — Last 7 Days")
                .font(.caption)
                .foregroundColor(.secondary)

            Chart(service.summary.weeklySteps, id: \.date) { item in
                BarMark(
                    x: .value("Day", item.date, unit: .day),
                    y: .value("Steps", item.steps)
                )
                .foregroundStyle(themeManager.accentColor.opacity(0.8))
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        .font(.caption2)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisValueLabel()
                        .font(.system(.caption2, design: .monospaced))
                }
            }
            .frame(height: 100)
        }
        .padding(16)
        .background(Color.cathierSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - AI Insight Section

    @ViewBuilder
    private var aiInsightSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header strip
            HStack(spacing: 8) {
                Circle()
                    .fill(themeManager.accentColor)
                    .frame(width: 6, height: 6)
                Text("Cathier AI")
                    .font(.system(.caption2, design: .default).weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(0.08 * 12)
                    .foregroundColor(themeManager.accentColor)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(themeManager.accentColorLight)
            .clipShape(UnevenRoundedRectangle(
                cornerRadii: RectangleCornerRadii(topLeading: 12, bottomLeading: 0, bottomTrailing: 0, topTrailing: 12),
                style: .continuous
            ))

            VStack(alignment: .leading, spacing: 16) {
                if let insight = aiInsight {
                    Text(insight)
                        .font(.custom("InstrumentSerif-Regular", size: 17))
                        .lineSpacing(17 * 0.55)
                        .foregroundColor(.primary)
                } else if isAnalyzing {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(themeManager.accentColor)
                            .scaleEffect(0.8)
                        Text(lm.currentLanguage == .zh ? "正在分析…" : lm.currentLanguage == .ja ? "分析中…" : "Analyzing…")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else if let error = analysisError {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(themeManager.accentColor)
                        Button(lm.aiRetry) {
                            runAnalysis()
                        }
                        .font(.caption)
                        .foregroundColor(themeManager.accentColor)
                    }
                } else {
                    Button {
                        runAnalysis()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.subheadline)
                            Text(lm.currentLanguage == .zh ? "用AI分析我的身体数据" : lm.currentLanguage == .ja ? "AIで身体データを分析" : "Analyze with AI")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(themeManager.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 9999, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!service.summary.hasAnyData)
                }
            }
            .padding(16)
            .background(Color.cathierSurface)
            .clipShape(UnevenRoundedRectangle(
                cornerRadii: RectangleCornerRadii(topLeading: 0, bottomLeading: 12, bottomTrailing: 12, topTrailing: 0),
                style: .continuous
            ))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(themeManager.accentColor.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Actions

    private func runAnalysis() {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        analysisError = nil
        aiInsight = nil
        Task {
            do {
                let result = try await ClaudeService.generateHealthInsights(
                    summary: service.summary,
                    recentCheckIns: Array(checkIns.prefix(10)),
                    language: lm.currentLanguage
                )
                aiInsight = result
            } catch {
                analysisError = error.localizedDescription
            }
            isAnalyzing = false
        }
    }
}

