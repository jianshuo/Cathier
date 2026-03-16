import SwiftUI
import SwiftData

struct DailyJournalEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(LanguageManager.self) private var lm
    @Environment(FriendViewModel.self) private var friendVM

    /// Pass in an existing entry to edit it; nil to create a new one.
    var existing: DailyJournal? = nil

    let onSave: () -> Void

    @State private var selectedMood: DailyMood? = nil
    @State private var gains: String = ""
    @State private var isShared: Bool = false

    private var hasFriends: Bool {
        friendVM.currentProfile != nil && !friendVM.friends.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    moodSection
                    gainsSection
                    if hasFriends {
                        shareSection
                    }
                    saveButton
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle(lm.journalEntryNavTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lm.checkInCancel) { dismiss() }
                }
            }
        }
        .onAppear {
            if let entry = existing {
                selectedMood = entry.dailyMood
                gains = entry.gains
                isShared = entry.isShared
            }
        }
    }

    // MARK: - Mood Picker

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(lm.journalEntryMoodLabel)
                .font(.headline)

            HStack(spacing: 0) {
                ForEach(DailyMood.allCases) { mood in
                    moodButton(mood)
                }
            }
            .padding(4)
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
    }

    private func moodButton(_ mood: DailyMood) -> some View {
        let isSelected = selectedMood == mood
        return Button(action: { selectedMood = mood }) {
            VStack(spacing: 4) {
                Text(mood.emoji)
                    .font(.system(size: 30))
                Text(mood.label(for: lm.currentLanguage))
                    .font(.caption2)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                isSelected
                    ? Color.orange.opacity(0.15)
                    : Color.clear
            )
            .cornerRadius(12)
            .overlay(
                isSelected
                    ? RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.4), lineWidth: 1)
                    : nil
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: selectedMood)
    }

    // MARK: - Gains Input

    private var gainsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(lm.journalEntryGainsLabel)
                .font(.headline)

            TextField(lm.journalEntryGainsPlaceholder,
                      text: $gains,
                      axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(4...8)
                .padding(14)
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
    }

    // MARK: - Share Toggle

    private var shareSection: some View {
        Toggle(isOn: $isShared) {
            HStack(spacing: 10) {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.orange)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(lm.journalEntryShareLabel)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text(lm.journalEntryShareDesc)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .tint(.orange)
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Save

    private var saveButton: some View {
        Button(action: saveEntry) {
            Text(lm.journalEntrySave)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .background(
            selectedMood != nil
                ? Color.orange
                : Color.gray.opacity(0.4)
        )
        .cornerRadius(14)
        .disabled(selectedMood == nil)
        .animation(.easeInOut(duration: 0.2), value: selectedMood != nil)
    }

    private func saveEntry() {
        guard let mood = selectedMood else { return }

        if let entry = existing {
            entry.mood = mood.rawValue
            entry.gains = gains
            entry.isShared = isShared
        } else {
            let journal = DailyJournal(
                date: Date(),
                mood: mood.rawValue,
                gains: gains,
                isShared: isShared
            )
            modelContext.insert(journal)
        }

        try? modelContext.save()
        onSave()
        dismiss()
    }
}
