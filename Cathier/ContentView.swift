import SwiftUI
import SwiftData

// Shared deep-link state — injected via environment so TodayView can react.
@Observable final class DeepLinkRouter {
    var triggerCheckIn = false
}

struct ContentView: View {
    @State private var friendVM = FriendViewModel()
    @State private var router = DeepLinkRouter()
    @State private var selectedTab = 0
    @Environment(LanguageManager.self) private var lm

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(lm.tabToday, systemImage: "heart.fill", value: 0) {
                TodayView()
                    .onAppear { t("📱 TodayView appeared") }
            }
            Tab(lm.tabJournal, systemImage: "calendar", value: 1) {
                JournalView()
                    .onAppear { t("📱 JournalView appeared") }
            }
            Tab(lm.tabFriends, systemImage: "person.2.fill", value: 2) {
                FriendFeedView()
                    .onAppear { t("📱 FriendFeedView appeared") }
            }
            Tab(lm.tabSettings, systemImage: "gearshape.fill", value: 3) {
                SettingsView()
                    .onAppear { t("📱 SettingsView appeared") }
            }
        }
        .tint(.cathierAccent)
        .environment(friendVM)
        .environment(router)
        .onOpenURL { url in
            // cathier://checkin — from widget or other deep links
            if url.scheme == "cathier", url.host == "checkin" {
                selectedTab = 0
                router.triggerCheckIn = true
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [CheckIn.self, DailyJournal.self], inMemory: true)
        .environment(LanguageManager.shared)
}
