import SwiftUI
import SwiftData

// Global launch clock — set as early as possible so all timers share one origin.
let appLaunchTime = Date()
func t(_ label: String) {
    let ms = Int(Date().timeIntervalSince(appLaunchTime) * 1000)
    print("[LAUNCH +\(ms)ms] \(label)")
}

@main
struct CathierApp: App {
    @State private var container: ModelContainer?

    var body: some Scene {
        WindowGroup {
            if let container {
                ContentView()
                    .modelContainer(container)
                    .environment(ConfigService.shared)
                    .environment(LanguageManager.shared)
                    .environment(ThemeManager.shared)
                    .task { checkMilestoneNudge() }
            } else {
                ProgressView()
                    .task(priority: .userInitiated) {
                        t("Task.detached for ModelContainer — START")
                        container = try? await Task.detached(priority: .userInitiated) {
                            t("ModelConfiguration init — START")
                            let config = ModelConfiguration(
                                cloudKitDatabase: .private("iCloud.com.wangjianshuo.Cathier")
                            )
                            t("ModelConfiguration init — END")
                            t("ModelContainer init — START")
                            let c = try ModelContainer(
                                for: CheckIn.self, DailyJournal.self,
                                configurations: config
                            )
                            t("ModelContainer init — END ✅")
                            return c
                        }.value
                        if container != nil {
                            t("container ready, switching to ContentView")
                        } else {
                            t("⚠️ ModelContainer init FAILED — container is nil")
                        }
                    }
            }
        }
    }

    /// Fires the insight milestone nudge if the user has ≥30 check-ins and hasn't been nudged yet.
    private func checkMilestoneNudge() {
        let count = UserDefaults.standard.integer(forKey: "totalCheckInCount")
        guard count >= 30 else { return }
        NotificationService.shared.scheduleInsightNudge()
    }
}
