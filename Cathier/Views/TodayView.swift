import SwiftUI
import SwiftData

struct TodayView: View {
    @Query(sort: \CheckIn.date, order: .reverse) private var checkIns: [CheckIn]
    @State private var showingCheckIn = false

    private var todayCheckIns: [CheckIn] {
        checkIns.filter { Calendar.current.isDateInToday($0.date) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Greeting header
                    headerView
                        .padding(.horizontal, 20)

                    // Main CTA
                    startButton
                        .padding(.horizontal, 20)

                    // Today's check-ins
                    if !todayCheckIns.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("今日记录")
                                .font(.headline)
                                .padding(.horizontal, 20)

                            ForEach(todayCheckIns) { checkIn in
                                CheckInCard(checkIn: checkIn)
                                    .padding(.horizontal, 20)
                            }
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top, 8)
            }
            .navigationTitle("此刻")
            .sheet(isPresented: $showingCheckIn) {
                CheckInFlowView()
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greetingText)
                .font(.title2)
                .fontWeight(.semibold)
            Text(todayCheckIns.isEmpty
                 ? "你今天还没有签到，花一分钟感受一下身体吧。"
                 : "今天已签到 \(todayCheckIns.count) 次，继续保持。")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                Text("开始身体扫描")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("此刻，你的身体在说什么？")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(
                LinearGradient(
                    colors: [Color(red: 1.0, green: 0.6, blue: 0.1), Color(red: 0.95, green: 0.4, blue: 0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "早上好"
        case 12..<18: return "下午好"
        default:      return "晚上好"
        }
    }
}
