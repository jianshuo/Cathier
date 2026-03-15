import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var friendVM = FriendViewModel()

    var body: some View {
        TabView {
            Tab("此刻", systemImage: "heart.fill") {
                TodayView()
            }
            Tab("日记", systemImage: "calendar") {
                JournalView()
            }
            Tab("好友", systemImage: "person.2.fill") {
                FriendFeedView()
            }
            Tab("设置", systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
        .tint(.orange)
        .environment(friendVM)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: CheckIn.self, inMemory: true)
}
