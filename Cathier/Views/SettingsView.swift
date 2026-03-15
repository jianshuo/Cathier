import SwiftUI

struct SettingsView: View {
    @AppStorage("claudeApiKey") private var apiKey = ""
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @State private var reminderTimes: [ReminderTime] = NotificationService.defaultTimes
    @State private var isAuthorized = false
    @State private var showApiKeySaved = false
    @Environment(LanguageManager.self) private var lm

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Language Settings
                Section {
                    Picker(lm.settingsLanguageSection, selection: Binding(
                        get: { lm.currentLanguage },
                        set: { lm.set($0) }
                    )) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                } header: {
                    Text(lm.settingsLanguageSection)
                }

                // MARK: - AI Settings
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Claude API Key")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        SecureField("sk-ant-…", text: $apiKey)
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        if showApiKeySaved {
                            Text(lm.settingsSaved)
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 4)

                    Link(lm.settingsGetKey, destination: URL(string: "https://console.anthropic.com")!)
                        .font(.caption)
                        .foregroundColor(.orange)
                } header: {
                    Text(lm.settingsAISection)
                } footer: {
                    Text(lm.settingsKeyFooter)
                        .font(.caption)
                }
                .onChange(of: apiKey) { _, _ in
                    showApiKeySaved = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showApiKeySaved = false
                    }
                }

                // MARK: - Notification Settings
                Section {
                    Toggle(lm.settingsEnableReminder, isOn: $notificationsEnabled)
                        .tint(.orange)
                        .onChange(of: notificationsEnabled) { _, enabled in
                            handleNotificationToggle(enabled)
                        }

                    if notificationsEnabled {
                        ForEach($reminderTimes) { $time in
                            HStack {
                                Toggle("", isOn: $time.isEnabled)
                                    .labelsHidden()
                                    .tint(.orange)
                                Spacer()
                                DatePicker(
                                    "",
                                    selection: Binding(
                                        get: { timeDate(hour: time.hour, minute: time.minute) },
                                        set: { date in
                                            let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
                                            time.hour = comps.hour ?? time.hour
                                            time.minute = comps.minute ?? time.minute
                                        }
                                    ),
                                    displayedComponents: .hourAndMinute
                                )
                                .labelsHidden()
                                .opacity(time.isEnabled ? 1 : 0.4)
                                .disabled(!time.isEnabled)
                            }
                        }

                        Button(lm.settingsSaveReminder) {
                            saveReminderSettings()
                        }
                        .foregroundColor(.orange)
                    }
                } header: {
                    Text(lm.settingsRemindersSection)
                } footer: {
                    Text(isAuthorized
                         ? lm.settingsReminderFooterOn
                         : lm.settingsReminderFooterOff)
                        .font(.caption)
                }

                // MARK: - About
                Section(lm.settingsAboutSection) {
                    HStack {
                        Text(lm.settingsVersion)
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text(lm.settingsDataStorage)
                        Spacer()
                        Text(lm.settingsLocalOnly)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(lm.settingsNavTitle)
            .task {
                reminderTimes = NotificationService.shared.loadTimes()
                isAuthorized = await NotificationService.shared.checkAuthorizationStatus()
            }
        }
    }

    private func handleNotificationToggle(_ enabled: Bool) {
        if enabled {
            Task {
                let granted = await NotificationService.shared.requestPermission()
                isAuthorized = granted
                if granted {
                    NotificationService.shared.scheduleReminders(reminderTimes)
                } else {
                    notificationsEnabled = false
                }
            }
        } else {
            NotificationService.shared.removeAllReminders()
        }
    }

    private func saveReminderSettings() {
        NotificationService.shared.saveTimes(reminderTimes)
        if notificationsEnabled {
            NotificationService.shared.scheduleReminders(reminderTimes)
        }
    }

    private func timeDate(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        var comps = calendar.dateComponents([.year, .month, .day], from: Date())
        comps.hour = hour
        comps.minute = minute
        return calendar.date(from: comps) ?? Date()
    }
}
