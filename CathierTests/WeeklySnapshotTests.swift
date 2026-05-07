import Testing
import Foundation
@testable import Cathier

struct WeeklySnapshotTests {
    @Test
    func returnsNilWhenFewerThanThreeRecentCheckIns() {
        let now = Date()
        let twoCheckIns = (0..<2).map { i -> CheckIn in
            CheckIn(date: now.addingTimeInterval(Double(-i) * 3600), bodyParts: [], sensations: [], intensity: 5, emotions: [])
        }
        let snap = WeeklySnapshot.compute(from: twoCheckIns)
        #expect(snap == nil)
    }

    @Test
    func computesAverageAndTrendAcrossTwoWeeks() {
        let now = Date()
        let cal = Calendar.current
        let dayAgo = cal.date(byAdding: .day, value: -1, to: now)!
        let tenDaysAgo = cal.date(byAdding: .day, value: -10, to: now)!

        let recent = [
            CheckIn(date: now, bodyParts: [], sensations: [], intensity: 8, emotions: []),
            CheckIn(date: dayAgo, bodyParts: [], sensations: [], intensity: 6, emotions: []),
            CheckIn(date: dayAgo, bodyParts: [], sensations: [], intensity: 4, emotions: []),
        ]
        let older = [
            CheckIn(date: tenDaysAgo, bodyParts: [], sensations: [], intensity: 4, emotions: []),
            CheckIn(date: tenDaysAgo, bodyParts: [], sensations: [], intensity: 4, emotions: []),
        ]

        let snap = WeeklySnapshot.compute(from: recent + older)
        #expect(snap != nil)
        #expect(snap?.checkInCount == 3)
        #expect(abs((snap?.avgIntensity ?? 0) - 6.0) < 0.001)
        #expect(abs((snap?.trend ?? 0) - 2.0) < 0.001)
    }
}
