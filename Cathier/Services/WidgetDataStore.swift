import Foundation
import WidgetKit

/// Shared data layer between the main app and the widget.
/// Writes today's check-in summary to an App Group UserDefaults bucket
/// so the widget can read it without accessing SwiftData.
///
/// App Group ID must be registered in both targets' entitlements:
///   Cathier.entitlements + CathierWidget.entitlements
///   → com.apple.security.application-groups → group.com.wangjianshuo.cathier
enum WidgetDataStore {
    static let appGroupID = "group.com.wangjianshuo.cathier"

    private enum Key {
        static let todayCount    = "widget.todayCheckInCount"
        static let todayEmotions = "widget.todayLatestEmotions"
        static let lastUpdated   = "widget.lastUpdated"
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    // MARK: - Write (called from main app after each save)

    static func writeTodaySummary(count: Int, latestEmotions: [String]) {
        guard let d = defaults else { return }
        d.set(count, forKey: Key.todayCount)
        d.set(latestEmotions, forKey: Key.todayEmotions)
        d.set(Date(), forKey: Key.lastUpdated)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Read (called from widget extension)

    static var todayCount: Int {
        defaults?.integer(forKey: Key.todayCount) ?? 0
    }

    static var todayLatestEmotions: [String] {
        defaults?.stringArray(forKey: Key.todayEmotions) ?? []
    }

    static var lastUpdated: Date? {
        defaults?.object(forKey: Key.lastUpdated) as? Date
    }
}
