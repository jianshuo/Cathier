import SwiftUI
import StoreKit

struct SettingsView: View {
    @AppStorage("aiProvider") private var selectedProviderRaw: String = AIProvider.claude.rawValue
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("contextBrief") private var contextBrief = ""
    @State private var reminderTimes: [ReminderTime] = NotificationService.defaultTimes
    @State private var isAuthorized = false
    @State private var showApiKeySaved = false
    @State private var showFeedback = false
    @State private var apiKeyInput = ""
    @Environment(LanguageManager.self) private var lm

    private let subManager = SubscriptionManager.shared

    private var selectedProvider: AIProvider {
        AIProvider(rawValue: selectedProviderRaw) ?? .claude
    }

    /// Binding for the "has key / no key" segmented control.
    /// Switching to managed saves the current provider so it can be restored later.
    private var managedModeBinding: Binding<Bool> {
        Binding(
            get: { selectedProvider.isManaged },
            set: { useManaged in
                if useManaged {
                    if !selectedProvider.isManaged {
                        UserDefaults.standard.set(selectedProviderRaw, forKey: "lastNonManagedProvider")
                    }
                    selectedProviderRaw = AIProvider.managed.rawValue
                } else {
                    let last = UserDefaults.standard.string(forKey: "lastNonManagedProvider")
                        ?? AIProvider.claude.rawValue
                    selectedProviderRaw = last
                    apiKeyInput = UserDefaults.standard.string(forKey: selectedProvider.apiKeyStorageKey) ?? ""
                }
            }
        )
    }

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
                    // Top-level choice: has key vs no key
                    Picker("", selection: managedModeBinding) {
                        Text(lm.settingsHasKey).tag(false)
                        Text(lm.settingsNoKey).tag(true)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                    if selectedProvider.isManaged {
                        // No-key path: subscription panel
                        ManagedSubscriptionPanel(subManager: subManager, lm: lm)
                    } else {
                        // Has-key path: provider picker + key input
                        Picker(lm.settingsAIProvider, selection: $selectedProviderRaw) {
                            ForEach(AIProvider.allCases.filter { !$0.isManaged }) { provider in
                                Text(provider.displayName).tag(provider.rawValue)
                            }
                        }
                        .onChange(of: selectedProviderRaw) { _, _ in
                            apiKeyInput = UserDefaults.standard.string(forKey: selectedProvider.apiKeyStorageKey) ?? ""
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("API Key")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            SecureField(selectedProvider.keyPlaceholder, text: $apiKeyInput)
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
                        .onChange(of: apiKeyInput) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: selectedProvider.apiKeyStorageKey)
                            showApiKeySaved = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showApiKeySaved = false
                            }
                        }

                        if let url = selectedProvider.consoleURL {
                            Link(lm.settingsGetKey, destination: url)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                } header: {
                    Text(lm.settingsAISection)
                } footer: {
                    Text(selectedProvider.isManaged ? lm.settingsManagedFooter : lm.settingsKeyFooter)
                        .font(.caption)
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

                // MARK: - Feedback
                Section(lm.feedbackSectionTitle) {
                    Button {
                        showFeedback = true
                    } label: {
                        Label(lm.feedbackButton, systemImage: "lightbulb")
                            .foregroundColor(.orange)
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
                if !selectedProvider.isManaged {
                    apiKeyInput = UserDefaults.standard.string(forKey: selectedProvider.apiKeyStorageKey) ?? ""
                }
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

// MARK: - Managed Subscription Panel

private struct ManagedSubscriptionPanel: View {
    let subManager: SubscriptionManager
    let lm: LanguageManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if subManager.isSubscribed {
                subscribedView
            } else {
                unsubscribedView
            }
        }
        .padding(.vertical, 6)
    }

    private var subscribedView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(lm.settingsManagedActive)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                Link(lm.settingsManagedManage, destination: url)
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }

    private var unsubscribedView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(lm.settingsManagedDesc)
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                FeatureBullet(text: lm.settingsManagedFeature1)
                FeatureBullet(text: lm.settingsManagedFeature2)
                FeatureBullet(text: lm.settingsManagedFeature3)
            }

            Button {
                Task { await subManager.purchase() }
            } label: {
                HStack(spacing: 8) {
                    if subManager.isPurchasing {
                        ProgressView()
                            .scaleEffect(0.85)
                            .tint(.white)
                    }
                    Text("\(lm.settingsManagedSubscribe) · \(subManager.displayPrice) / \(lm.settingsManagedPerMonth)")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(subManager.isPurchasing)

            Button(lm.settingsManagedRestore) {
                Task { await subManager.restore() }
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)

            if let err = subManager.errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct FeatureBullet: View {
    let text: String
    var body: some View {
        Label(text, systemImage: "checkmark")
            .font(.caption)
            .foregroundColor(.secondary)
            .symbolRenderingMode(.palette)
            .foregroundStyle(Color.orange, Color.secondary)
    }
}
