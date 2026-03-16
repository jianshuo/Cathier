import SwiftUI

struct DailyJournalCard: View {
    let journal: DailyJournal
    @Environment(LanguageManager.self) private var lm
    var onEdit: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row: mood emoji + privacy badge + edit button
            HStack(alignment: .center, spacing: 8) {
                if let mood = journal.dailyMood {
                    Text(mood.emoji)
                        .font(.system(size: 32))
                    Text(mood.label(for: lm.currentLanguage))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                Spacer()
                // Privacy badge
                Label(
                    journal.isShared ? lm.journalEntrySharedBadge : lm.journalEntryPrivateBadge,
                    systemImage: journal.isShared ? "person.2.fill" : "lock.fill"
                )
                .font(.caption)
                .foregroundColor(journal.isShared ? .orange : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    (journal.isShared ? Color.orange : Color.secondary)
                        .opacity(0.1)
                )
                .clipShape(Capsule())

                if let edit = onEdit {
                    Button(action: edit) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title3)
                            .foregroundColor(.orange.opacity(0.8))
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
