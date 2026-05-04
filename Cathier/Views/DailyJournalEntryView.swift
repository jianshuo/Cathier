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

    // MARK: - Mood Picker (4×4 color grid)

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(lm.journalEntryMoodLabel)
                .font(.headline)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                spacing: 10
            ) {
                ForEach(DailyMood.allCases) { mood in
                    colorMoodButton(mood)
                }
            }

            if let mood = selectedMood {
                HStack(spacing: 6) {
                    Circle()
                        .fill(mood.themeColor)
                        .frame(width: 10, height: 10)
                    Text(mood.label(for: lm.currentLanguage))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(mood.themeColor)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.easeInOut(duration: 0.2), value: selectedMood)
            }
        }
    }

    private func colorMoodButton(_ mood: DailyMood) -> some View {
        let isSelected = selectedMood == mood
        return Button {
            withAnimation(.easeOut(duration: 0.15)) {
                selectedMood = mood
            }
        } label: {
            ZStack {
                Circle()
                    .fill(mood.themeColor)
                    .shadow(
                        color: mood.themeColor.opacity(isSelected ? 0.45 : 0.15),
                        radius: isSelected ? 8 : 3,
                        y: isSelected ? 3 : 1
                    )
                    .scaleEffect(isSelected ? 1.15 : 1.0)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(isSelected ? 0.9 : 0), lineWidth: 2.5)
                    )

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(height: 52)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isSelected)
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
                    .foregroundColor(selectedMood?.themeColor ?? .cathierAccent)
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
        .tint(selectedMood?.themeColor ?? .cathierAccent)
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .animation(.easeInOut(duration: 0.2), value: selectedMood)
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
                ? selectedMood!.themeColor
                : Color.gray.opacity(0.4)
        )
        .cornerRadius(14)
        .disabled(selectedMood == nil)
        .animation(.easeInOut(duration: 0.2), value: selectedMood)
    }

    private func saveEntry() {
        guard let mood = selectedMood else { return }

        ThemeManager.shared.update(to: mood)

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
