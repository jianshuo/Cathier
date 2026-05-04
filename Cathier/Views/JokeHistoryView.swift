import SwiftUI

struct JokeHistoryView: View {
    @Environment(LanguageManager.self) private var lm
    @Environment(\.dismiss) private var dismiss

    private var jokeService: JokeService { JokeService.shared }

    var body: some View {
        NavigationStack {
            Group {
                if jokeService.jokeHistory.isEmpty {
                    emptyState
                } else {
                    jokeList
                }
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(doneLabel) { dismiss() }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "cpu.fill")
                .font(.system(size: 48))
                .foregroundColor(Color.cathierSage.opacity(0.4))
            Text(emptyLabel)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cathierBackground)
    }

    private var jokeList: some View {
        List {
            ForEach(jokeService.jokeHistory) { joke in
                JokeHistoryRow(joke: joke)
                    .listRowBackground(Color.cathierSurface)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.cathierBackground)
    }

    private var navTitle: String {
        switch lm.currentLanguage {
        case .zh: return "AI 冷笑话"
        case .ja: return "AI コールドジョーク"
        default:  return "AI Cold Jokes"
        }
    }

    private var doneLabel: String {
        switch lm.currentLanguage {
        case .zh: return "完成"
        case .ja: return "完了"
        default:  return "Done"
        }
    }

    private var emptyLabel: String {
        switch lm.currentLanguage {
        case .zh: return "还没有笑话记录"
        case .ja: return "まだジョークがありません"
        default:  return "No jokes yet"
        }
    }
}

private struct JokeHistoryRow: View {
    let joke: DailyJoke

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(joke.date, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(joke.question)
                .font(.cathierSerif(.body))
                .foregroundColor(.primary)
            Text(joke.punchline)
                .font(.cathierSerif(.body, italic: true))
                .foregroundColor(Color.cathierSage)
        }
        .padding(.vertical, 4)
    }
}
