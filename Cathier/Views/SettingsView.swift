import SwiftUI

struct SettingsView: View {
    @AppStorage("claudeApiKey") private var apiKey = ""
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @State private var reminderTimes: [ReminderTime] = NotificationService.defaultTimes
    @State private var isAuthorized = false
    @State private var showApiKeySaved = false

    var body: some View {
        NavigationStack {
            List {
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
                            Text("已保存")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 4)

                    Link("获取 API Key →", destination: URL(string: "https://console.anthropic.com")!)
                        .font(.caption)
                        .foregroundColor(.orange)
                } header: {
                    Text("AI 设置")
                } footer: {
                    Text("API Key 仅存储在本机，不会上传到任何服务器。")
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
                    Toggle("开启提醒", isOn: $notificationsEnabled)
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

                        Button("保存提醒设置") {
                            saveReminderSettings()
                        }
                        .foregroundColor(.orange)
                    }
                } header: {
                    Text("定时提醒")
                } footer: {
                    Text(isAuthorized
                         ? "提醒会在设定时间以本地通知推送。"
                         : "请在系统设置中允许通知权限，以便接收提醒。")
                        .font(.caption)
                }

                // MARK: - About
                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("数据存储")
                        Spacer()
                        Text("仅限本机")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
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
