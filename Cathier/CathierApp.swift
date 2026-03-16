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
        }
        .modelContainer(container)
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
