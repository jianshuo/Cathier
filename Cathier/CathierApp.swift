import SwiftUI
import SwiftData

@main
struct CathierApp: App {
    let container: ModelContainer = {
        let config = ModelConfiguration(cloudKitDatabase: .private("iCloud.com.wangjianshuo.Cathier"))
        return try! ModelContainer(for: CheckIn.self, DailyJournal.self, configurations: config)
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL(perform: handleDeepLink)
                .environment(ConfigService.shared)
                .environment(LanguageManager.shared)
                .task { await ConfigService.shared.refreshFromGitHub() }
                .task { checkMilestoneNudge() }
        }
        .modelContainer(container)
    }

    /// Fires the insight milestone nudge if the user has ≥30 check-ins and hasn't been nudged yet.
    private func checkMilestoneNudge() {
        let count = UserDefaults.standard.integer(forKey: "totalCheckInCount")
        guard count >= 30 else { return }
        NotificationService.shared.scheduleInsightNudge()
    }

    /// Handles cathier://invite?code=XXXXXXXX
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "cathier",
              url.host == "invite",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value
        else { return }

        NotificationCenter.default.post(
            name: .cathierInviteReceived,
            object: nil,
            userInfo: ["code": code]
        )
    }
}

extension Notification.Name {
    static let cathierInviteReceived = Notification.Name("cathierInviteReceived")
}
