import SwiftUI

/// Entry point for the Plaza tab. Switches on account state.
struct PlazaView: View {
    @Environment(FriendViewModel.self) private var friendVM
    @Environment(PlazaViewModel.self) private var plazaVM
    @Environment(LanguageManager.self) private var lm

    var body: some View {
        NavigationStack {
            Group {
                switch friendVM.accountState {
                case .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .unavailable(let message):
                    unavailableView(message)

                case .needsProfile:
                    FriendSetupView()

                case .ready:
                    PlazaFeedView()
                }
            }
            .navigationTitle(lm.plazaNavTitle)
            .navigationBarTitleDisplayMode(.large)
        }
    }

    @ViewBuilder
    private func unavailableView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "icloud.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                Task { await friendVM.retry() }
            } label: {
                Text(lm.friendRetry)
                    .font(.subheadline)
                    .foregroundColor(.cathierAccent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Feed (after profile setup)

private struct PlazaFeedView: View {
    @Environment(PlazaViewModel.self) private var plazaVM
    @Environment(LanguageManager.self) private var lm
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if plazaVM.isLoading && plazaVM.posts.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if plazaVM.posts.isEmpty {
                emptyView
            } else {
                feedList
            }
        }
        .task { await plazaVM.load() }
        .refreshable { await plazaVM.load(force: true) }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await plazaVM.load() }
            }
        }
    }

    private var feedList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(plazaVM.posts) { post in
                    PlazaPostCard(post: post)
                }
                Spacer(minLength: 24)
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Text("🌏")
                .font(.system(size: 56))
            Text(lm.plazaEmpty)
                .font(.headline)
            Text(lm.plazaEmptyHint)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Plaza Post Card

private struct PlazaPostCard: View {
    let post: PlazaPost
    @Environment(LanguageManager.self) private var lm
    @State private var showFullAI = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerRow
            emotionRow
            if post.privacyTier != .category, !post.bodyParts.isEmpty {
                bodyRow
            }
            if !post.aiFeedback.isEmpty {
                aiSnippet
            }
        }
        .padding(14)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 20)
        .padding(.vertical, 5)
        .sheet(isPresented: $showFullAI) {
            PlazaAIDetailView(post: post)
        }
    }

    private var cardBackground: Color {
        if let firstEmotion = post.emotions.first,
           let category = EmotionData.category(for: firstEmotion) {
            return category.color.opacity(0.08)
        }
        return Color(red: 0.878, green: 0.929, blue: 0.886)
    }

    private var headerRow: some View {
        HStack(spacing: 10) {
            Text(post.avatarEmoji)
                .font(.system(size: 28))
                .frame(width: 40, height: 40)
                .background(Color(.systemGray5))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(post.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(post.date.plazaRelativeString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            IntensityBadge(intensity: post.intensity, label: lm.aiIntensityBadge(post.intensity))
        }
    }

    private var emotionRow: some View {
        FlowLayout(spacing: 6) {
            ForEach(visibleEmotions, id: \.self) { label in
                let color: Color = (post.privacyTier == .category)
                    ? .cathierSage
                    : EmotionData.category(for: label)?.color ?? .cathierSage
                Text(lm.display(label))
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.18))
                    .foregroundColor(color)
                    .clipShape(Capsule())
            }
        }
    }

    private var visibleEmotions: [String] {
        switch post.privacyTier {
        case .category:
            var seen = Set<String>()
            return post.emotions.compactMap { EmotionData.category(for: $0)?.nameZh }
                .filter { seen.insert($0).inserted }
        case .emotions, .full:
            return post.emotions
        }
    }

    private var bodyRow: some View {
        let grouped = groupedSensations(post.sensations)
        return VStack(alignment: .leading, spacing: 3) {
            ForEach(post.bodyParts, id: \.self) { part in
                HStack(alignment: .top, spacing: 5) {
                    if part == post.bodyParts.first {
                        Image(systemName: "figure.stand")
                            .font(.caption2)
                            .foregroundColor(.cathierSage)
                            .frame(width: 12)
                    } else {
                        Spacer().frame(width: 12)
                    }
                    let sensations = grouped[part] ?? []
                    let partName = lm.display(part)
                    if sensations.isEmpty {
                        Text(partName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.cathierSage)
                    } else {
                        (Text(partName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.cathierSage)
                        + Text("  " + sensations.map { lm.display($0) }.joined(separator: " · "))
                            .font(.caption)
                            .foregroundColor(.secondary))
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func groupedSensations(_ sensations: [String]) -> [String: [String]] {
        var result: [String: [String]] = [:]
        for s in sensations {
            let parts = s.split(separator: ":", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                result[parts[0], default: []].append(parts[1])
            }
        }
        return result
    }

    private var aiSnippet: some View {
        Button(action: { showFullAI = true }) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.caption2)
                    .foregroundColor(.cathierAccent)
                    .padding(.top, 3)
                VStack(alignment: .leading, spacing: 4) {
                    Text(StructuredFeedback.parse(post.aiFeedback)?.previewText ?? post.aiFeedback.plazaFirstSentence)
                        .font(.cathierSerif(.subheadline))
                        .foregroundColor(.primary)
                        .lineSpacing(2)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(lm.aiReadMore)
                        .font(.caption2)
                        .foregroundColor(.cathierAccent)
                }
            }
            .padding(10)
            .background(Color.cathierAccentLight)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.cathierAccent.opacity(0.15), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Plaza AI Detail Sheet

struct PlazaAIDetailView: View {
    let post: PlazaPost
    @Environment(LanguageManager.self) private var lm
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 10) {
                        Text(post.avatarEmoji)
                            .font(.system(size: 28))
                            .frame(width: 40, height: 40)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(post.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(post.date.plazaRelativeString)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Group {
                        if let structured = StructuredFeedback.parse(post.aiFeedback) {
                            StructuredFeedbackView(feedback: structured)
                        } else {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.subheadline)
                                    .foregroundColor(.cathierAccent)
                                    .padding(.top, 2)
                                Text(post.aiFeedback)
                                    .font(.cathierSerif(.body))
                                    .foregroundColor(.primary)
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(14)
                    .background(Color.cathierAccentLight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.cathierAccent.opacity(0.15), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .padding(20)
            }
            .navigationTitle(lm.aiFullInterpretation)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Helpers

private extension Date {
    var plazaRelativeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter.string(from: self)
    }
}

private extension String {
    var plazaFirstSentence: String {
        let terminators = CharacterSet(charactersIn: ".。!！?？\n")
        if let range = unicodeScalars.indices.first(where: { terminators.contains(unicodeScalars[$0]) }) {
            let endIndex = unicodeScalars.index(after: range)
            return String(self[..<endIndex]).trimmingCharacters(in: .whitespaces)
        }
        return count > 120 ? String(prefix(120)) + "…" : self
    }
}
