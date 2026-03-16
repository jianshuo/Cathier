import SwiftUI
import SwiftData

struct TodayView: View {
    @Query(sort: \CheckIn.date, order: .reverse) private var checkIns: [CheckIn]
    @Query(sort: \DailyJournal.date, order: .reverse) private var journals: [DailyJournal]
    @State private var showingCheckIn = false
    @State private var showingJournalEntry = false
    @State private var journalToEdit: DailyJournal? = nil
    @Environment(LanguageManager.self) private var lm

    private var todayCheckIns: [CheckIn] {
        checkIns.filter { Calendar.current.isDateInToday($0.date) }
    }

    private var todayJournal: DailyJournal? {
        journals.first { Calendar.current.isDateInToday($0.date) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Greeting header
                    headerView
                        .padding(.horizontal, 20)

                    // Main CTA
                    startButton
                        .padding(.horizontal, 20)

                    // Today's check-ins
                    if !todayCheckIns.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(lm.todayRecords)
                                .font(.headline)
                                .padding(.horizontal, 20)

                            ForEach(todayCheckIns) { checkIn in
                                CheckInCard(checkIn: checkIn)
                                    .padding(.horizontal, 20)
                            }
                        }
                    }

                    // Daily journal section
                    dailyJournalSection
                        .padding(.horizontal, 20)

                    Spacer(minLength: 40)
                }
                .padding(.top, 8)
            }
            .navigationTitle(lm.todayNavTitle)
            .sheet(isPresented: $showingCheckIn) {
                CheckInFlowView()
            }
            .sheet(isPresented: $showingJournalEntry) {
                DailyJournalEntryView(existing: journalToEdit) {
                    journalToEdit = nil
                }
            }
        }
    }

    // MARK: - Daily Journal Section

    @ViewBuilder
    private var dailyJournalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(lm.journalEntryTodayTitle)
                .font(.headline)

            if let journal = todayJournal {
                DailyJournalCard(journal: journal) {
                    journalToEdit = journal
                    showingJournalEntry = true
                }
            } else {
                journalWritePrompt
            }
        }
    }

    private var journalWritePrompt: some View {
        Button(action: {
            journalToEdit = nil
            showingJournalEntry = true
        }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.4, green: 0.6, blue: 1.0).opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "book.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color(red: 0.4, green: 0.6, blue: 1.0))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(lm.journalEntryWritePrompt)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text(lm.journalEntryWriteHint)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greetingText)
                .font(.title2)
                .fontWeight(.semibold)
            Text(todayCheckIns.isEmpty
                 ? lm.todayNoCheckIn()
                 : lm.todayCheckedIn(todayCheckIns.count))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Start Button

    private var startButton: some View {
        Button(action: { showingCheckIn = true }) {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 64, height: 64)
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }
                Text(lm.todayStartScan)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(lm.todayBodySaying)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(
                LinearGradient(
                    colors: [Color(red: 1.0, green: 0.6, blue: 0.1), Color(red: 0.95, green: 0.4, blue: 0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return lm.greetingMorning
        case 12..<18: return lm.greetingAfternoon
        default:      return lm.greetingEvening
        }
    }
}
