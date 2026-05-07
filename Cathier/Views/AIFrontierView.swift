import SwiftUI

struct AIFrontierView: View {
    @Environment(LanguageManager.self) private var lm
    private var service: AIFrontierService { AIFrontierService.shared }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let news = service.todayNews {
                    AIFrontierCard(news: news) {
                        Task { await service.regenerate() }
                    }
                } else if service.isGenerating {
                    loadingCard
                } else {
                    retryCard
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(Color.cathierBackground)
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.large)
        .task { await service.generateTodayNewsIfNeeded() }
    }

    private var loadingCard: some View {
        HStack(spacing: 14) {
            ProgressView()
                .tint(Color.cathierAccent)
                .frame(width: 48, height: 48)
            Text(loadingHint)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(16)
        .background(Color.cathierSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var retryCard: some View {
        Button {
            Task { await service.generateTodayNewsIfNeeded() }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.cathierAccent.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "sparkles")
                        .font(.system(size: 20))
                        .foregroundColor(Color.cathierAccent)
                }
                Text(service.generateError != nil ? errorHint : loadingHint)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color.cathierSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var navTitle: String {
        switch lm.currentLanguage {
        case .zh: return "今日AI最前沿"
        case .ja: return "今日のAIフロンティア"
        default:  return "AI Frontier"
        }
    }

    private var loadingHint: String {
        switch lm.currentLanguage {
        case .zh: return "正在检索最前沿AI动态…"
        case .ja: return "最先端のAI動向を取得中…"
        default:  return "Fetching today's AI frontier…"
        }
    }

    private var errorHint: String {
        switch lm.currentLanguage {
        case .zh: return "获取失败，点击重试"
        case .ja: return "取得に失敗しました。再試行するにはタップ"
        default:  return "Failed to load — tap to retry"
        }
    }
}
