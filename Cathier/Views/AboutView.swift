import SwiftUI
import SwiftData

struct AboutView: View {
    @Environment(LanguageManager.self) private var lm
    @Query(sort: \CheckIn.date, order: .forward) private var checkIns: [CheckIn]
    @Query(sort: \DailyJournal.date, order: .forward) private var journals: [DailyJournal]

    @State private var isExporting = false
    @State private var exportURL: URL? = nil
    @State private var exportError: String? = nil

    private let testFlightPublicLink = "https://testflight.apple.com/join/TwF61E49"

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
    }

    private var copyrightYear: String {
        let year = Calendar.current.component(.year, from: Date())
        return "© \(year) \(lm.aboutCreatorName)"
    }

    var body: some View {
        List {
            // MARK: - App Identity
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "heart.text.clipboard")
                        .font(.system(size: 52))
                        .foregroundStyle(.cathierAccent)
                    Text("Cathier")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(lm.aboutAppDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .listRowBackground(Color.clear)

            // MARK: - Creator
            Section {
                HStack {
                    Text(lm.aboutMadeBy)
                    Spacer()
                    Text(lm.aboutCreatorName)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(lm.aboutMadeBy)
            }

            // MARK: - Version Info
            Section {
                HStack {
                    Text(lm.settingsVersion)
                    Spacer()
                    Text(version)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(lm.settingsBuild)
                    Spacer()
                    Text(build)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(lm.settingsDataStorage)
                    Spacer()
                    Text(lm.settingsLocalOnly)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(lm.settingsAboutSection)
            }

            // MARK: - TestFlight Beta
            if let url = URL(string: testFlightPublicLink), !testFlightPublicLink.isEmpty {
                Section {
                    Link(destination: url) {
                        HStack(spacing: 12) {
                            Image(systemName: "airplane.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.cathierAccent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(lm.aboutTestFlightTitle)
                                    .foregroundStyle(.primary)
                                Text(lm.aboutTestFlightSubtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            // MARK: - Data Export
            Section {
                Button {
                    startExport()
                } label: {
                    HStack(spacing: 12) {
                        if isExporting {
                            ProgressView()
                                .frame(width: 28, height: 28)
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.cathierAccent)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isExporting ? lm.aboutExportPreparing : lm.aboutExportTitle)
                                .foregroundStyle(.primary)
                            if !isExporting {
                                Text(lm.aboutExportSubtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                }
                .disabled(isExporting)

                if let err = exportError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } header: {
                Text(lm.aboutExportSection)
            }

            // MARK: - Privacy
            Section {
                Text(lm.aboutPrivacyDetail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } header: {
                Text(lm.aboutPrivacyTitle)
            }

            // MARK: - Copyright
            Section {
                HStack {
                    Spacer()
                    Text(copyrightYear)
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
            }
            .listRowBackground(Color.clear)
        }
        .navigationTitle(lm.settingsAboutRow)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $exportURL) { url in
            ActivityView(items: [url])
        }
    }

    // MARK: - Export

    private func startExport() {
        isExporting = true
        exportError = nil
        let snapCheckIns = checkIns
        let snapJournals = journals
        Task.detached(priority: .userInitiated) {
            do {
                let url = try DataExportService.exportAllData(
                    checkIns: snapCheckIns,
                    journals: snapJournals
                )
                await MainActor.run {
                    isExporting = false
                    exportURL = url
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    exportError = error.localizedDescription
                }
            }
        }
    }
}

// URL needs to be Identifiable to use .sheet(item:)
extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
