import SwiftUI
import SwiftData

// MARK: - Main Explorer (3 sections)

struct EmotionExplorerView: View {
    @Environment(ConfigService.self) private var config
    @Environment(LanguageManager.self) private var lm
    @Environment(ThemeManager.self) private var themeManager
    @Query private var allCheckIns: [CheckIn]
    @State private var selectedTab = 0
    @State private var selectedItem: SelectedItem?

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("", selection: $selectedTab) {
                Text("情绪").tag(0)
                Text("身体感受").tag(1)
                Text("身体部位").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            // Content
            switch selectedTab {
            case 0: emotionList
            case 1: sensationList
            case 2: bodyPartList
            default: EmptyView()
            }
        }
        .background(Color.cathierBackground)
        .navigationTitle("觉察词典")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedItem) { item in
            switch item.kind {
            case .emotion:
                EmotionDictionarySheet(entry: item.entry, categoryColor: categoryColor(for: item.entry.category ?? ""))
            case .sensation:
                SensationDictionarySheet(entry: item.entry)
            case .bodyPart:
                BodyPartDictionarySheet(entry: item.entry)
            }
        }
    }

    // MARK: - Vocab banner

    private var usedEmotionNames: Set<String> {
        Set(allCheckIns.flatMap { $0.emotions })
    }

    @ViewBuilder
    private var vocabBanner: some View {
        let used = usedEmotionNames.count
        if used > 0 {
            let total = DictionaryService.emotionsByCategory.reduce(0) { $0 + $1.emotions.count }
            HStack(spacing: 8) {
                Image(systemName: "book.fill")
                    .font(.caption)
                    .foregroundStyle(themeManager.accentColor)
                Text(vocabBannerTitle)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                Spacer()
                HStack(spacing: 2) {
                    Text("\(used)")
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundStyle(themeManager.accentColor)
                    Text("/ \(total)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Color.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(themeManager.accentColorLight)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, 20)
        }
    }

    private var vocabBannerTitle: String {
        switch lm.currentLanguage {
        case .zh: return "已感知情绪词汇"
        case .ja: return "感知した感情の種類"
        default:  return "Emotions you've felt"
        }
    }

    // MARK: - Emotions

    private var emotionList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                vocabBanner
                ForEach(DictionaryService.emotionsByCategory, id: \.category) { group in
                    let cat = config.categories.first { $0.nameZh == group.category }
                    let color = cat?.color ?? themeManager.accentColor

                    VStack(alignment: .leading, spacing: 10) {
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

                        FlowLayout(spacing: 8) {
                            ForEach(group.emotions, id: \.id) { item in
                                Button {
                                    selectedItem = SelectedItem(id: item.id, entry: item.entry, kind: .emotion)
                                } label: {
                                    Text("\(item.entry.emoji ?? "") \(item.entry.nameZh)")
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
    }

    // MARK: - Sensations

    private var sensationList: some View {
        ScrollView {
            FlowLayout(spacing: 8) {
                ForEach(DictionaryService.sensationEntries, id: \.id) { item in
                    Button {
                        selectedItem = SelectedItem(id: item.id, entry: item.entry, kind: .sensation)
                    } label: {
                        Text(item.entry.nameZh)
                            .font(.subheadline)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.cathierSage.opacity(0.1))
                            .foregroundStyle(.cathierSage)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
    }

    // MARK: - Body Parts

    private var bodyPartList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(DictionaryService.bodyPartEntries, id: \.id) { item in
                    Button {
                        selectedItem = SelectedItem(id: item.id, entry: item.entry, kind: .bodyPart)
                    } label: {
                        HStack(spacing: 12) {
                            Text(item.entry.nameZh)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(item.entry.nameEn)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
    }

    private func categoryColor(for name: String) -> Color {
        config.categories.first { $0.nameZh == name }?.color ?? themeManager.accentColor
    }
}

// MARK: - Selected item wrapper

private enum ItemKind { case emotion, sensation, bodyPart }

private struct SelectedItem: Identifiable {
    let id: String
    let entry: DictionaryEntry
    let kind: ItemKind
}

// MARK: - Shared helpers

private struct SheetSection<Content: View>: View {
    let icon: String
    let title: String
    let color: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
            }
            content()
        }
    }
}

private func serifText(_ text: String) -> some View {
    Text(text)
        .font(.cathierSerif(.body))
        .foregroundStyle(.primary)
        .lineSpacing(6)
}

private func chipList(_ items: [String], color: Color) -> some View {
    FlowLayout(spacing: 6) {
        ForEach(items, id: \.self) { item in
            Text(item)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(color.opacity(0.1))
                .foregroundStyle(color)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Emotion Detail Sheet

struct EmotionDictionarySheet: View {
    let entry: DictionaryEntry
    let categoryColor: Color
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Hero
                    VStack(spacing: 12) {
                        Text(entry.emoji ?? "")
                            .font(.system(size: 56))
                            .padding(.top, 20)
                        Text(entry.nameZh)
                            .font(.cathierSerif(.title))
                        Text(entry.nameEn)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let intensity = entry.intensity {
                            HStack(spacing: 3) {
                                ForEach(1...5, id: \.self) { level in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(level <= intensity ? categoryColor : categoryColor.opacity(0.2))
                                        .frame(width: 18, height: 4)
                                }
                            }
                            .padding(.top, 2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 28)

                    VStack(alignment: .leading, spacing: 20) {
                        if let v = entry.description, !v.isEmpty { SheetSection(icon: "text.quote", title: "释义", color: categoryColor) { serifText(v) } }
                        if let v = entry.origin, !v.isEmpty { SheetSection(icon: "sparkle", title: "源起", color: categoryColor) { serifText(v) } }
                        if let v = entry.experience, !v.isEmpty { SheetSection(icon: "heart.text.clipboard", title: "体验", color: categoryColor) { serifText(v) } }
                        if let v = entry.embodiment, !v.isEmpty { SheetSection(icon: "figure.mind.and.body", title: "具身感受", color: categoryColor) { serifText(v) } }
                        if let v = entry.imagery, !v.isEmpty { SheetSection(icon: "eye", title: "意象", color: categoryColor) { serifText(v) } }
                        if let v = entry.developmentalStage, !v.isEmpty { SheetSection(icon: "figure.2.arms.open", title: "发展阶段", color: categoryColor) { serifText(v) } }
                        if let v = entry.formativeEvents, !v.isEmpty { SheetSection(icon: "clock.arrow.circlepath", title: "塑造事件", color: categoryColor) { serifText(v) } }
                        if let v = entry.personalityImpact, !v.isEmpty { SheetSection(icon: "person.fill.questionmark", title: "性格影响", color: categoryColor) { serifText(v) } }
                        if let v = entry.transformation, !v.isEmpty { SheetSection(icon: "arrow.triangle.2.circlepath", title: "转化", color: categoryColor) { serifText(v) } }
                        if let v = entry.literaryReference, !v.isEmpty {
                            SheetSection(icon: "book.closed", title: "文学", color: categoryColor) {
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
                            SheetSection(icon: "arrow.left.arrow.right", title: "相近情绪", color: categoryColor) {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(similar, id: \.self) { name in
                                        HStack(alignment: .top, spacing: 8) {
                                            let emoji = EmotionData.emoji(for: name)
                                            Text(emoji.isEmpty ? "·" : emoji).font(.body)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(name).font(.subheadline).fontWeight(.medium).foregroundStyle(categoryColor)
                                                if let diff = entry.differs?[name] {
                                                    Text(diff).font(.caption).foregroundStyle(.secondary).lineSpacing(3)
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
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(Color.cathierBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { dismissButton } }
        }
    }

    private var dismissButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary).font(.title3)
        }
    }
}

// MARK: - Sensation Detail Sheet

struct SensationDictionarySheet: View {
    let entry: DictionaryEntry
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    private let color: Color = .cathierSage

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Hero
                    VStack(spacing: 12) {
                        Image(systemName: "hand.point.up.braille")
                            .font(.system(size: 40))
                            .foregroundStyle(color)
                            .padding(.top, 24)
                        Text(entry.nameZh)
                            .font(.cathierSerif(.title))
                        Text(entry.nameEn)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 28)

                    VStack(alignment: .leading, spacing: 20) {
                        if let v = entry.description, !v.isEmpty { SheetSection(icon: "text.quote", title: "释义", color: color) { serifText(v) } }
                        if let v = entry.howItFeels, !v.isEmpty { SheetSection(icon: "hand.raised", title: "具体体验", color: color) { serifText(v) } }
                        if let locs = entry.commonLocations, !locs.isEmpty {
                            SheetSection(icon: "figure.stand", title: "常见部位", color: color) { chipList(locs, color: color) }
                        }
                        if let emo = entry.relatedEmotions, !emo.isEmpty {
                            SheetSection(icon: "heart", title: "常伴随情绪", color: color) { chipList(emo, color: themeManager.accentColor) }
                        }
                        if let v = entry.signalMeaning, !v.isEmpty { SheetSection(icon: "exclamationmark.bubble", title: "身体在说什么", color: color) { serifText(v) } }
                        if let v = entry.selfCare, !v.isEmpty { SheetSection(icon: "leaf", title: "可以做什么", color: color) { serifText(v) } }
                        if let v = entry.intensitySpectrum, !v.isEmpty {
                            SheetSection(icon: "chart.bar", title: "强度光谱", color: color) {
                                Text(v)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(color.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                        if let diffs = entry.differs, !diffs.isEmpty {
                            SheetSection(icon: "arrow.left.arrow.right", title: "区别", color: color) {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(Array(diffs.keys.sorted()), id: \.self) { key in
                                        HStack(alignment: .top, spacing: 6) {
                                            Text(key).font(.caption).fontWeight(.medium).foregroundStyle(color)
                                            Text(diffs[key] ?? "").font(.caption).foregroundStyle(.secondary)
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
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(Color.cathierBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary).font(.title3) }
            }}
        }
    }
}

// MARK: - Body Part Detail Sheet

struct BodyPartDictionarySheet: View {
    let entry: DictionaryEntry
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    private var color: Color { themeManager.accentColor }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Hero
                    VStack(spacing: 12) {
                        Image(systemName: "figure.mind.and.body")
                            .font(.system(size: 40))
                            .foregroundStyle(color)
                            .padding(.top, 24)
                        Text(entry.nameZh)
                            .font(.cathierSerif(.title))
                        Text(entry.nameEn)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 28)

                    VStack(alignment: .leading, spacing: 20) {
                        if let v = entry.description, !v.isEmpty { SheetSection(icon: "text.quote", title: "简介", color: color) { serifText(v) } }
                        if let v = entry.howToLocate, !v.isEmpty { SheetSection(icon: "location.magnifyingglass", title: "如何找到", color: color) { serifText(v) } }
                        if let sens = entry.commonSensations, !sens.isEmpty {
                            SheetSection(icon: "hand.point.up.braille", title: "常见感受", color: color) { chipList(sens, color: .cathierSage) }
                        }
                        if let v = entry.emotionalConnection, !v.isEmpty { SheetSection(icon: "heart", title: "情绪关联", color: color) { serifText(v) } }
                        if let v = entry.awarenessGuide, !v.isEmpty { SheetSection(icon: "eye", title: "觉察练习", color: color) { serifText(v) } }
                        if let v = entry.culturalNote, !v.isEmpty {
                            SheetSection(icon: "book.closed", title: "文化含义", color: color) {
                                Text(v)
                                    .font(.cathierSerif(.callout, italic: true))
                                    .foregroundStyle(.primary)
                                    .lineSpacing(5)
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(color.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(Color.cathierBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary).font(.title3) }
            }}
        }
    }
}
