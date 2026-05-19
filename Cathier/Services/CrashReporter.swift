import Foundation
import MetricKit

/// Hooks MetricKit and auto-files a GitHub Issue for every crash, hang, or
/// CPU exception iOS reports for this app.
///
/// MetricKit delivers diagnostic payloads on the *next* app launch after the
/// incident — so the user has to relaunch Cathier for the issue to appear in
/// the repo. We dedupe by JSON-content hash in UserDefaults so a redelivered
/// payload doesn't spam GitHub.
///
/// The whole class is `nonisolated`: MetricKit calls the subscriber from a
/// background queue, and posting to GitHub doesn't touch any main-actor state.
nonisolated final class CrashReporter: NSObject, MXMetricManagerSubscriber {
    static let shared = CrashReporter()

    private static let processedKey = "metricKitProcessedSignatures"
    private static let maxRemembered = 50

    private var started = false

    private override init() {
        super.init()
    }

    /// Idempotent. Call once at app launch.
    func start() {
        guard !started else { return }
        started = true
        MXMetricManager.shared.add(self)
    }

    // MARK: - MXMetricManagerSubscriber

    /// Daily aggregate metrics (battery, network, etc.) — not crash data.
    /// We don't file issues for these. Implementation left as a no-op so the
    /// optional protocol method is explicit.
    func didReceive(_ payloads: [MXMetricPayload]) {}

    /// Diagnostic payloads — crashes, hangs (including watchdog kills like
    /// `0x8BADF00D`), CPU exceptions, disk-write exceptions.
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            payload.crashDiagnostics?.forEach            { post($0, kind: "Crash") }
            payload.hangDiagnostics?.forEach             { post($0, kind: "Hang") }
            payload.cpuExceptionDiagnostics?.forEach     { post($0, kind: "CPU Exception") }
            payload.diskWriteExceptionDiagnostics?.forEach { post($0, kind: "Disk Write Exception") }
        }
    }

    // MARK: - Posting

    private func post(_ diagnostic: MXDiagnostic, kind: String) {
        let json = diagnostic.jsonRepresentation()
        let signature = "\(kind):\(json.hashValue)"

        var processed = UserDefaults.standard.stringArray(forKey: Self.processedKey) ?? []
        if processed.contains(signature) { return }
        processed.append(signature)
        if processed.count > Self.maxRemembered {
            processed = Array(processed.suffix(Self.maxRemembered))
        }
        UserDefaults.standard.set(processed, forKey: Self.processedKey)

        let meta = diagnostic.metaData
        let title = "[\(kind)] build \(meta.applicationBuildVersion) · iOS \(meta.osVersion) · \(meta.deviceType)"
        let body  = formatBody(json: json, meta: meta, kind: kind)

        // Fire-and-forget. If the network call fails, the diagnostic is lost
        // for this delivery; MetricKit may redeliver on a future launch.
        Task {
            do {
                _ = try await GitHubService.createCrashIssue(title: title, body: body)
            } catch {
                print("[CrashReporter] Failed to post \(kind): \(error)")
            }
        }
    }

    private func formatBody(json: Data, meta: MXMetaData, kind: String) -> String {
        let pretty: String = {
            if let obj  = try? JSONSerialization.jsonObject(with: json),
               let data = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let str  = String(data: data, encoding: .utf8) {
                return str
            }
            return String(data: json, encoding: .utf8) ?? "(failed to decode)"
        }()

        return """
        Auto-reported via MetricKit.

        - **Kind**: \(kind)
        - **App build**: \(meta.applicationBuildVersion)
        - **iOS**: \(meta.osVersion)
        - **Device**: \(meta.deviceType)
        - **Reported at**: \(ISO8601DateFormatter().string(from: Date()))

        ## Full diagnostic JSON

        ```json
        \(pretty)
        ```
        """
    }
}
