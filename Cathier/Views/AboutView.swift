import SwiftUI

struct AboutView: View {
    @Environment(LanguageManager.self) private var lm

    /// Public TestFlight join link. Generate it in App Store Connect →
    /// TestFlight → External Testing group → "Enable Public Link", then
    /// paste the URL here. Empty string hides the section.
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
    }

}
