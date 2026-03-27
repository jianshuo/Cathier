import SwiftUI
import SwiftData

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
                    .task { await ConfigService.shared.refreshFromGitHub() }
                    .task { checkMilestoneNudge() }
            } else {
                ProgressView()
                    .task(priority: .userInitiated) {
                        // Run on a background thread so the main thread stays free
                        // even during CloudKit schema initialisation (can take 1-2 min
                        // on first launch while NSPersistentCloudKitContainer negotiates
                        // the schema with iCloud).
                        container = try? await Task.detached(priority: .userInitiated) {
                            let config = ModelConfiguration(
                                cloudKitDatabase: .private("iCloud.com.wangjianshuo.Cathier")
                            )
                            return try ModelContainer(
                                for: CheckIn.self, DailyJournal.self,
                                configurations: config
                            )
                        }.value
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
