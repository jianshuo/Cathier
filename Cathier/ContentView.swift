import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var friendVM = FriendViewModel()
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
        .task { await friendVM.initialize() }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [CheckIn.self, DailyJournal.self], inMemory: true)
        .environment(LanguageManager.shared)
}
