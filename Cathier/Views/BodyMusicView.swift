import SwiftUI

struct BodyMusicView: View {
    let bodyParts: [String]
    let sensations: [String]
    let intensity: Int
    let emotions: [String]

    @Environment(\.dismiss) private var dismiss
    @Environment(LanguageManager.self) private var lm

    @State private var recommendation: MusicRecommendation?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if isLoading {
                        loadingView
                    } else if let error = errorMessage {
                        errorView(error)
                    } else if let rec = recommendation {
                        recommendationContent(rec)
                    }
                }
                .padding(20)
            }
            .background(Color.cathierBackground)
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .task { await loadRecommendation() }
    }

    // MARK: - Nav title

    private var navTitle: String {
        switch lm.currentLanguage {
        case .zh: return "来自身体的音乐"
        case .ja: return "身体からの音楽"
        default:  return "Music from the Body"
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.4)
                .tint(.cathierAccent)
            Text(loadingHint)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var loadingHint: String {
        switch lm.currentLanguage {
        case .zh: return "正在感知你的身体，寻找适合的音乐…"
        case .ja: return "あなたの身体を感じて、音楽を探しています…"
        default:  return "Sensing your body state, finding the right music…"
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundColor(.cathierAccent)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button(retryLabel) {
                Task { await loadRecommendation() }
            }
            .foregroundColor(.cathierAccent)
        }
        .padding(.vertical, 40)
    }

    private var retryLabel: String {
        switch lm.currentLanguage {
        case .zh: return "重试"
        case .ja: return "再試行"
        default:  return "Retry"
        }
    }

    // MARK: - Recommendation content

    private func recommendationContent(_ rec: MusicRecommendation) -> some View {
        VStack(spacing: 20) {
            // Body state summary
            bodyStateSummaryCard

            // Mood header
            moodHeader(rec.mood)

            // AI description card (Instrument Serif — journal moment)
            descriptionCard(rec.description)

            // Genre chips
            if !rec.genres.isEmpty {
                genreChips(rec.genres)
            }

            // Open in music app
            if !rec.searchQuery.isEmpty {
                musicSearchButton(rec.searchQuery)
            }
        }
    }

    private var bodyStateSummaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            let summaryLabel: String
            switch lm.currentLanguage {
            case .zh: summaryLabel = "当前身体状态"
            case .ja: summaryLabel = "現在の身体状態"
            default:  summaryLabel = "Current Body State"
            }
            Text(summaryLabel)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.cathierAccent)
                .tracking(0.5)
                .textCase(.uppercase)

            let parts = bodyParts.prefix(4).joined(separator: lm.currentLanguage == .en ? ", " : "、")
            let emos  = emotions.prefix(3).joined(separator: lm.currentLanguage == .en ? ", " : "、")

            if !parts.isEmpty {
                Label(parts, systemImage: "figure.stand")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            if !emos.isEmpty {
                Label(emos, systemImage: "heart")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            let intensityLabel: String
            switch lm.currentLanguage {
            case .zh: intensityLabel = "强度 \(intensity)/10"
            case .ja: intensityLabel = "強度 \(intensity)/10"
            default:  intensityLabel = "Intensity \(intensity)/10"
            }
            Label(intensityLabel, systemImage: "waveform.path.ecg")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cathierSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.cathierAccent.opacity(0.25), lineWidth: 1)
        )
    }

    private func moodHeader(_ mood: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "music.note")
                .font(.title3)
                .foregroundColor(.cathierAccent)
            Text(mood)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private func descriptionCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.cathierAccent)
                    .frame(width: 6, height: 6)
                Text("Cathier")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.cathierAccent)
                    .tracking(0.08)
                    .textCase(.uppercase)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.cathierAccentLight)

            Text(text)
                .font(.cathierSerif(.body))
                .lineSpacing(6)
                .foregroundColor(.primary)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.cathierAccent.opacity(0.25), lineWidth: 1)
        )
    }

    private func genreChips(_ genres: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            let genreLabel: String
            switch lm.currentLanguage {
            case .zh: genreLabel = "推荐风格"
            case .ja: genreLabel = "推薦ジャンル"
            default:  genreLabel = "Recommended Genres"
            }
            Text(genreLabel)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .tracking(0.5)
                .textCase(.uppercase)

            FlowLayout(spacing: 8) {
                ForEach(genres, id: \.self) { genre in
                    Text(genre)
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.cathierAccentLight)
                        .foregroundColor(.cathierAccent)
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func musicSearchButton(_ query: String) -> some View {
        VStack(spacing: 10) {
            Button(action: { openAppleMusic(query: query) }) {
                HStack(spacing: 10) {
                    Image(systemName: "music.note.list")
                        .font(.body)
                    Text(appleMusicLabel)
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.cathierAccent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Text(searchQueryHint(query))
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var appleMusicLabel: String {
        switch lm.currentLanguage {
        case .zh: return "在 Apple Music 中搜索"
        case .ja: return "Apple Musicで検索"
        default:  return "Search on Apple Music"
        }
    }

    private func searchQueryHint(_ query: String) -> String {
        switch lm.currentLanguage {
        case .zh: return "搜索词：\(query)"
        case .ja: return "検索ワード：\(query)"
        default:  return "Search: \(query)"
        }
    }

    private func openAppleMusic(query: String) {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
        let urlString = "music://music.apple.com/search?term=\(encoded)"
        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let webURL = URL(string: "https://music.apple.com/us/search?term=\(encoded)") {
            UIApplication.shared.open(webURL)
        }
    }

    // MARK: - Load

    private func loadRecommendation() async {
        isLoading = true
        errorMessage = nil
        do {
            recommendation = try await ClaudeService.generateMusicRecommendation(
                bodyParts: bodyParts,
                sensations: sensations,
                intensity: intensity,
                emotions: emotions,
                language: lm.currentLanguage
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
