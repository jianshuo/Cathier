import SwiftUI

struct DailyJournalCard: View {
    let journal: DailyJournal
    @Environment(LanguageManager.self) private var lm
    @Environment(ThemeManager.self) private var themeManager
    var onEdit: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row: mood emoji + privacy badge + edit button
            HStack(alignment: .center, spacing: 8) {
                if let mood = journal.dailyMood {
                    Circle()
                        .fill(mood.themeColor)
                        .frame(width: 24, height: 24)
                        .shadow(color: mood.themeColor.opacity(0.3), radius: 4, y: 2)
                    Text(mood.label(for: lm.currentLanguage))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(mood.themeColor)
                }
                Spacer()
                // Privacy badge
                Label(
                    journal.isShared ? lm.journalEntrySharedBadge : lm.journalEntryPrivateBadge,
                    systemImage: journal.isShared ? "person.2.fill" : "lock.fill"
                )
                .font(.caption)
                .foregroundColor(journal.isShared ? themeManager.accentColor : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    (journal.isShared ? themeManager.accentColor : Color.secondary)
                        .opacity(0.1)
                )
                .clipShape(Capsule())

                if let edit = onEdit {
                    Button(action: edit) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title3)
                            .foregroundColor(themeManager.accentColor.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Gains text
            if !journal.gains.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(journal.gains)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(4)
                    .lineSpacing(2)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}
