import SwiftUI

struct DailyJokeCard: View {
    let joke: DailyJoke
    var onShowHistory: () -> Void

    @State private var showPunchline: Bool
    @Environment(LanguageManager.self) private var lm

    init(joke: DailyJoke, onShowHistory: @escaping () -> Void) {
        self.joke = joke
        self.onShowHistory = onShowHistory
        _showPunchline = State(initialValue: joke.isRead)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            content
        }
        .background(Color.cathierSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.cathierSage.opacity(0.25), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.cathierSage)
                    .frame(width: 6, height: 6)
                Text(headerTitle)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.cathierSage)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            Spacer()
            Button(action: onShowHistory) {
                Text(historyLabel)
                    .font(.caption)
                    .foregroundColor(Color.cathierSage)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.cathierSageLight)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(joke.question)
                .font(.cathierSerif(.body))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if showPunchline {
                Text(joke.punchline)
                    .font(.cathierSerif(.body, italic: true))
                    .foregroundColor(Color.cathierSage)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                Button(action: revealPunchline) {
                    Text(revealLabel)
                        .font(.caption)
                        .foregroundColor(Color.cathierSage)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.cathierSageLight)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
    }

    private func revealPunchline() {
        withAnimation(.easeInOut(duration: 0.35)) {
            showPunchline = true
        }
        JokeService.shared.markRead(id: joke.id)
    }

    private var headerTitle: String {
        switch lm.currentLanguage {
        case .zh: return "AI 冷笑话"
        case .ja: return "AI コールドジョーク"
        default:  return "AI Cold Joke"
        }
    }

    private var historyLabel: String {
        switch lm.currentLanguage {
        case .zh: return "历史"
        case .ja: return "履歴"
        default:  return "History"
        }
    }

    private var revealLabel: String {
        switch lm.currentLanguage {
        case .zh: return "点击揭晓答案 →"
        case .ja: return "答えを見る →"
        default:  return "Reveal punchline →"
        }
    }
}
