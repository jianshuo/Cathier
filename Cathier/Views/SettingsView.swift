import SwiftUI

struct SettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("contextBrief") private var contextBrief = ""
    @State private var reminderTimes: [ReminderTime] = NotificationService.defaultTimes
    @State private var isAuthorized = false
    @State private var showFeedback = false
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
                    .pickerStyle(.menu)
                } header: {
                    Text(lm.settingsLanguageSection)
                }

                // MARK: - Notification Settings
                Section {
                    Toggle(lm.settingsEnableReminder, isOn: $notificationsEnabled)
                        .tint(.cathierAccent)
                        .onChange(of: notificationsEnabled) { _, enabled in
                            handleNotificationToggle(enabled)
                        }

                    if notificationsEnabled {
                        ForEach($reminderTimes) { $time in
                            HStack {
                                Toggle("", isOn: $time.isEnabled)
                                    .labelsHidden()
                                    .tint(.cathierAccent)
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
                        .foregroundColor(.cathierAccent)
                    }
                } header: {
                    Text(lm.settingsRemindersSection)
                } footer: {
                    Text(isAuthorized
                         ? lm.settingsReminderFooterOn
                         : lm.settingsReminderFooterOff)
                        .font(.caption)
                }

                // MARK: - Context Brief
                Section {
                    TextEditor(text: $contextBrief)
                        .frame(minHeight: 80)
                        .font(.subheadline)
                        .overlay(alignment: .topLeading) {
                            if contextBrief.isEmpty {
                                Text(lm.settingsContextPlaceholder)
                                    .font(.subheadline)
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                } header: {
                    Text(lm.settingsContextSection)
                } footer: {
                    Text(lm.settingsContextFooter)
                        .font(.caption)
                }

                // MARK: - Emotion Dictionary
                Section {
                    NavigationLink {
                        EmotionExplorerView()
                            .environment(ConfigService.shared)
                    } label: {
                        Label("情绪词典", systemImage: "book.closed")
                            .foregroundColor(.primary)
                    }
                } header: {
                    Text("探索")
                }

                // MARK: - Feedback
                Section(lm.feedbackSectionTitle) {
                    Button {
                        showFeedback = true
                    } label: {
                        Label(lm.feedbackButton, systemImage: "lightbulb")
                            .foregroundColor(.cathierAccent)
                    }
                }

                // MARK: - About
                Section(lm.settingsAboutSection) {
                    NavigationLink(lm.settingsAboutRow) {
                        AboutView()
                            .environment(lm)
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle(lm.settingsNavTitle)
            .sheet(isPresented: $showFeedback) {
                FeedbackView()
                    .environment(lm)
            }
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
