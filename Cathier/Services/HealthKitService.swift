import Foundation
import HealthKit
import Observation

struct HealthSummary {
    var stepsToday: Int = 0
    var weeklySteps: [(date: Date, steps: Int)] = []
    var avgRestingHeartRate: Double? = nil
    var avgSleepHours: Double? = nil
    var activeEnergyToday: Double = 0

    var hasAnyData: Bool {
        stepsToday > 0 || avgRestingHeartRate != nil || avgSleepHours != nil || activeEnergyToday > 0
    }
}

@Observable
final class HealthKitService {
    static let shared = HealthKitService()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }
    var authStatus: AuthStatus = .notDetermined
    var summary = HealthSummary()
    var isLoading = false

    enum AuthStatus {
        case notDetermined, requested, denied
    }

    private let store = HKHealthStore()

    private static var readTypes: Set<HKObjectType> {
        [
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.restingHeartRate),
            HKCategoryType(.sleepAnalysis),
        ]
    }

    private init() {}

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        do {
            try await store.requestAuthorization(toShare: [], read: Self.readTypes)
            authStatus = .requested
            await loadData()
        } catch {
            authStatus = .denied
            print("[HealthKit] Authorization error: \(error)")
        }
    }

    func loadData() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        isLoading = true
        defer { isLoading = false }

        async let stepsToday = fetchStepsToday()
        async let weeklySteps = fetchWeeklySteps()
        async let heartRate = fetchAvgRestingHeartRate()
        async let sleep = fetchAvgSleepHours()
        async let energy = fetchActiveEnergyToday()

        let (st, ws, hr, sl, ae) = await (stepsToday, weeklySteps, heartRate, sleep, energy)
        summary = HealthSummary(
            stepsToday: st,
            weeklySteps: ws,
            avgRestingHeartRate: hr,
            avgSleepHours: sl,
            activeEnergyToday: ae
        )
    }

    // MARK: - Steps

    private func fetchStepsToday() async -> Int {
        let type = HKQuantityType(.stepCount)
        let start = Calendar.current.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
        return Int(await fetchCumulativeSum(type: type, unit: .count(), predicate: predicate))
    }

    private func fetchWeeklySteps() async -> [(date: Date, steps: Int)] {
        let type = HKQuantityType(.stepCount)
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)

        return await withTaskGroup(of: (Date, Int).self) { group in
            for offset in 0..<7 {
                guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
                let dayEnd = offset == 0 ? Date.now : (cal.date(byAdding: .day, value: 1, to: day) ?? day)
                group.addTask { [self] in
                    let pred = HKQuery.predicateForSamples(withStart: day, end: dayEnd)
                    let steps = Int(await self.fetchCumulativeSum(type: type, unit: .count(), predicate: pred))
                    return (day, steps)
                }
            }
            var result: [(Date, Int)] = []
            for await pair in group { result.append(pair) }
            return result.sorted { $0.0 < $1.0 }
        }
    }

    // MARK: - Heart Rate

    private func fetchAvgRestingHeartRate() async -> Double? {
        let type = HKQuantityType(.restingHeartRate)
        let start = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
        let unit = HKUnit(from: "count/min")
        return await fetchDiscreteAverage(type: type, unit: unit, predicate: predicate)
    }

    // MARK: - Sleep

    private func fetchAvgSleepHours() async -> Double? {
        let type = HKCategoryType(.sleepAnalysis)
        let start = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample], !samples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                let asleepValues = Set(HKCategoryValueSleepAnalysis.allAsleepValues.map(\.rawValue))
                let asleepSamples = samples.filter { asleepValues.contains($0.value) }
                guard !asleepSamples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                let totalSeconds = asleepSamples.reduce(0.0) {
                    $0 + $1.endDate.timeIntervalSince($1.startDate)
                }
                let nights = Set(asleepSamples.map { Calendar.current.startOfDay(for: $0.startDate) }).count
                continuation.resume(returning: totalSeconds / Double(nights) / 3600)
            }
            self.store.execute(query)
        }
    }

    // MARK: - Active Energy

    private func fetchActiveEnergyToday() async -> Double {
        let type = HKQuantityType(.activeEnergyBurned)
        let start = Calendar.current.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
        return await fetchCumulativeSum(type: type, unit: .kilocalorie(), predicate: predicate)
    }

    // MARK: - Query Helpers

    private func fetchCumulativeSum(type: HKQuantityType, unit: HKUnit, predicate: NSPredicate) async -> Double {
        await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, _ in
                continuation.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            store.execute(query)
        }
    }

    private func fetchDiscreteAverage(type: HKQuantityType, unit: HKUnit, predicate: NSPredicate) async -> Double? {
        await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, stats, _ in
                continuation.resume(returning: stats?.averageQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }
}
