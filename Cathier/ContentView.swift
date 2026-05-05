import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var friendVM = FriendViewModel()
    @State private var plazaVM = PlazaViewModel()
    @State private var selectedTab = 0
    @Environment(LanguageManager.self) private var lm
    @Environment(ThemeManager.self) private var themeManager

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
            Tab(lm.tabPlaza, systemImage: "person.3.fill", value: 3) {
                PlazaView()
                    .onAppear { t("📱 PlazaView appeared") }
            }
            Tab(lm.tabSettings, systemImage: "gearshape.fill", value: 4) {
                SettingsView()
                    .onAppear { t("📱 SettingsView appeared") }
            }
        }
        .tint(themeManager.accentColor)
        .environment(friendVM)
        .environment(plazaVM)
        .task { await friendVM.initialize() }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [CheckIn.self, DailyJournal.self], inMemory: true)
        .environment(LanguageManager.shared)
}
