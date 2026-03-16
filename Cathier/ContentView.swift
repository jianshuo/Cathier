import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var friendVM = FriendViewModel()
    @Environment(LanguageManager.self) private var lm

    var body: some View {
        TabView {
            Tab(lm.tabToday, systemImage: "heart.fill") {
                TodayView()
            }
            Tab(lm.tabJournal, systemImage: "calendar") {
                JournalView()
            }
            Tab(lm.tabFriends, systemImage: "person.2.fill") {
                FriendFeedView()
            }
            Tab(lm.tabSettings, systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
        .tint(.orange)
        .environment(friendVM)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [CheckIn.self, DailyJournal.self], inMemory: true)
        .environment(LanguageManager.shared)
}
