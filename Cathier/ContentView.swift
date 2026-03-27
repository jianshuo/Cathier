import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var friendVM = FriendViewModel()
    @Environment(LanguageManager.self) private var lm

    var body: some View {
        TabView {
            Tab(lm.tabToday, systemImage: "heart.fill") {
                TodayView()
                    .onAppear { t("📱 TodayView appeared") }
            }
            Tab(lm.tabJournal, systemImage: "calendar") {
                JournalView()
                    .onAppear { t("📱 JournalView appeared") }
            }
            Tab(lm.tabFriends, systemImage: "person.2.fill") {
                FriendFeedView()
                    .onAppear { t("📱 FriendFeedView appeared") }
            }
            Tab(lm.tabSettings, systemImage: "gearshape.fill") {
                SettingsView()
                    .onAppear { t("📱 SettingsView appeared") }
            }
        }
        .tint(.cathierAccent)
        .environment(friendVM)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [CheckIn.self, DailyJournal.self], inMemory: true)
        .environment(LanguageManager.shared)
}
