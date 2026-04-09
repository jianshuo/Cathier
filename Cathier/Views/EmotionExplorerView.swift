import SwiftUI

struct EmotionExplorerView: View {
    @Environment(ConfigService.self) private var config
    @State private var selectedEntry: (id: String, entry: DictionaryEntry)?

    private var grouped: [(category: String, emotions: [(id: String, entry: DictionaryEntry)])] {
        DictionaryService.emotionsByCategory
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(grouped, id: \.category) { group in
                    let cat = config.categories.first { $0.nameZh == group.category }
                    let color = cat?.color ?? .cathierAccent

                    VStack(alignment: .leading, spacing: 10) {
                        // Category header
                        HStack(spacing: 8) {
                            if let icon = cat?.icon {
                                Image(systemName: icon)
                                    .font(.subheadline)
                                    .foregroundStyle(color)
                            }
                            Text(group.category)
                                .font(.headline)
                                .foregroundStyle(color)
                        }
                        .padding(.horizontal, 20)

                        // Emotion chips
                        FlowLayout(spacing: 8) {
                            ForEach(group.emotions, id: \.id) { item in
                                Button {
                                    selectedEntry = item
                                } label: {
                                    Text("\(item.entry.emoji) \(item.entry.nameZh)")
                                        .font(.subheadline)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(color.opacity(0.1))
                                        .foregroundStyle(color)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .background(Color.cathierBackground)
        .navigationTitle("情绪词典")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: Binding(
            get: { selectedEntry.map { IdentifiableEntry(id: $0.id, entry: $0.entry) } },
            set: { if $0 == nil { selectedEntry = nil } }
        )) { item in
            EmotionDictionarySheet(entry: item.entry, categoryColor: categoryColor(for: item.entry.category))
        }
    }

    private func categoryColor(for name: String) -> Color {
        config.categories.first { $0.nameZh == name }?.color ?? .cathierAccent
    }
}

// Wrapper to make the entry Identifiable for .sheet(item:)
private struct IdentifiableEntry: Identifiable {
    let id: String
    let entry: DictionaryEntry
}

// MARK: - Detail sheet

struct EmotionDictionarySheet: View {
    let entry: DictionaryEntry
    let categoryColor: Color
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    heroHeader
                        .padding(.bottom, 28)

                    VStack(alignment: .leading, spacing: 20) {
                        if let desc = entry.description, !desc.isEmpty {
                            section(icon: "text.quote", title: "释义") {
                                serifText(desc)
                            }
                        }
                        if let v = entry.origin, !v.isEmpty {
                            section(icon: "sparkle", title: "源起") { serifText(v) }
                        }
                        if let v = entry.experience, !v.isEmpty {
                            section(icon: "heart.text.clipboard", title: "体验") { serifText(v) }
                        }
                        if let v = entry.embodiment, !v.isEmpty {
                            section(icon: "figure.mind.and.body", title: "具身感受") { serifText(v) }
                        }
                        if let v = entry.imagery, !v.isEmpty {
                            section(icon: "eye", title: "意象") { serifText(v) }
                        }
                        if let v = entry.developmentalStage, !v.isEmpty {
                            section(icon: "figure.2.arms.open", title: "发展阶段") { serifText(v) }
                        }
                        if let v = entry.formativeEvents, !v.isEmpty {
                            section(icon: "clock.arrow.circlepath", title: "塑造事件") { serifText(v) }
                        }
                        if let v = entry.personalityImpact, !v.isEmpty {
                            section(icon: "person.fill.questionmark", title: "性格影响") { serifText(v) }
                        }
                        if let v = entry.transformation, !v.isEmpty {
                            section(icon: "arrow.triangle.2.circlepath", title: "转化") { serifText(v) }
                        }
                        if let v = entry.literaryReference, !v.isEmpty {
                            section(icon: "book.closed", title: "文学") {
                                Text(v)
                                    .font(.cathierSerif(.callout, italic: true))
                                    .foregroundStyle(.primary)
                                    .lineSpacing(5)
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(categoryColor.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                        if let similar = entry.similarTo, !similar.isEmpty {
                            similarSection(similar)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(Color.cathierBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                }
            }
        }
    }

    // MARK: - Hero

    private var heroHeader: some View {
        VStack(spacing: 12) {
            Text(entry.emoji)
                .font(.system(size: 56))
                .padding(.top, 20)
            Text(entry.nameZh)
                .font(.cathierSerif(.title))
            Text(entry.nameEn)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 3) {
                ForEach(1...5, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(level <= entry.intensity ? categoryColor : categoryColor.opacity(0.2))
                        .frame(width: 18, height: 4)
                }
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Section

    @ViewBuilder
    private func section<Content: View>(icon: String, title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(categoryColor)
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
            }
            content()
        }
    }

    private func serifText(_ text: String) -> some View {
        Text(text)
            .font(.cathierSerif(.body))
            .foregroundStyle(.primary)
            .lineSpacing(6)
    }

    // MARK: - Similar

    private func similarSection(_ similar: [String]) -> some View {
        section(icon: "arrow.left.arrow.right", title: "相近情绪") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(similar, id: \.self) { name in
                    HStack(alignment: .top, spacing: 8) {
                        let emoji = EmotionData.emoji(for: name)
                        Text(emoji.isEmpty ? "·" : emoji)
                            .font(.body)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(categoryColor)
                            if let diff = entry.differs?[name] {
                                Text(diff)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineSpacing(3)
                            }
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}
