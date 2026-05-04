import SwiftUI
import Observation

@Observable
final class ThemeManager {
    static let shared = ThemeManager()

    private static let hexKey = "cathierMoodThemeHex"

    var accentColor: Color

    private init() {
        let hex = UserDefaults.standard.string(forKey: Self.hexKey) ?? "#F2700A"
        accentColor = Color(hex: hex) ?? Color(red: 242/255, green: 112/255, blue: 10/255)
    }

    func update(to mood: DailyMood) {
        accentColor = mood.themeColor
        UserDefaults.standard.set(mood.colorHex, forKey: Self.hexKey)
    }
}
