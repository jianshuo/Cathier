import SwiftUI

// MARK: - Models

enum EmotionValence {
    case positive, negative, neutral
}

struct Emotion: Identifiable {
    let id: String
    let nameZh: String
    let nameEn: String
    let emoji: String
    let intensity: Int  // 1–5
}

struct EmotionCategory: Identifiable {
    let id: String
    let nameZh: String
    let nameEn: String
    let color: Color
    let icon: String
    let valence: EmotionValence
    let emotions: [Emotion]

    // Backward-compat accessors used by existing views
    var name: String { nameZh }
    var children: [String] { emotions.map(\.nameZh) }
}

// MARK: - Static data

enum EmotionData {
    static let bodyParts = ["头部", "胸口", "腹部", "肩颈", "手脚", "全身"]

    static let sensations = [
        "紧绷", "沉重", "发热", "空洞",
        "酸胀", "轻盈", "颤抖", "麻木",
        "刺痛", "收缩", "压迫", "温暖",
        "冰冷", "放松", "震动", "膨胀",
    ]

    static let categories: [EmotionCategory] = [

        // ── 激情 Impassioned ──────────────────────────────────────────────
        .init(
            id: "impassioned",
            nameZh: "激情", nameEn: "Impassioned",
            color: Color(red: 1.0, green: 0.35, blue: 0.20),
            icon: "bolt.fill",
            valence: .positive,
            emotions: [
                .init(id: "enthusiastic",  nameZh: "热情",     nameEn: "Enthusiastic", emoji: "🔥", intensity: 4),
                .init(id: "excited",       nameZh: "兴奋",     nameEn: "Excited",      emoji: "⚡", intensity: 4),
                .init(id: "aroused",       nameZh: "激动",     nameEn: "Aroused",      emoji: "💥", intensity: 4),
                .init(id: "delirious",     nameZh: "狂喜",     nameEn: "Delirious",    emoji: "🤯", intensity: 5),
                .init(id: "passionate",    nameZh: "充满激情", nameEn: "Passionate",   emoji: "❤️‍🔥", intensity: 4),
                .init(id: "euphoric",      nameZh: "欣喜若狂", nameEn: "Euphoric",     emoji: "🌟", intensity: 5),
                .init(id: "thrilled",      nameZh: "激动万分", nameEn: "Thrilled",     emoji: "🎉", intensity: 4),
                .init(id: "determined",    nameZh: "坚定",     nameEn: "Determined",   emoji: "💪", intensity: 3),
                .init(id: "confident",     nameZh: "自信",     nameEn: "Confident",    emoji: "😎", intensity: 3),
                .init(id: "optimistic",    nameZh: "乐观",     nameEn: "Optimistic",   emoji: "🌞", intensity: 3),
                .init(id: "anticipating",  nameZh: "期待",     nameEn: "Anticipating", emoji: "🤩", intensity: 3),
            ]
        ),

        // ── 快乐 Happy ────────────────────────────────────────────────────
        .init(
            id: "happy",
            nameZh: "快乐", nameEn: "Happy",
            color: Color(red: 1.0, green: 0.75, blue: 0.0),
            icon: "sun.max.fill",
            valence: .positive,
            emotions: [
                .init(id: "joyful",    nameZh: "喜悦",     nameEn: "Joyful",    emoji: "😄", intensity: 4),
                .init(id: "blissful",  nameZh: "幸福",     nameEn: "Blissful",  emoji: "😊", intensity: 4),
                .init(id: "amused",    nameZh: "被逗乐",   nameEn: "Amused",    emoji: "😆", intensity: 3),
                .init(id: "delighted", nameZh: "高兴",     nameEn: "Delighted", emoji: "🥰", intensity: 4),
                .init(id: "lucky",     nameZh: "幸运",     nameEn: "Lucky",     emoji: "🍀", intensity: 3),
                .init(id: "grateful",  nameZh: "感恩",     nameEn: "Grateful",  emoji: "🙏", intensity: 3),
                .init(id: "hopeful",   nameZh: "充满希望", nameEn: "Hopeful",   emoji: "🌈", intensity: 3),
                .init(id: "alive",     nameZh: "充满活力", nameEn: "Alive",     emoji: "✨", intensity: 3),
                .init(id: "pleasant",  nameZh: "愉悦",     nameEn: "Pleasant",  emoji: "😁", intensity: 3),
                .init(id: "warm",      nameZh: "温暖",     nameEn: "Warm",      emoji: "🌤", intensity: 2),
            ]
        ),

        // ── 平静 Calm ─────────────────────────────────────────────────────
        .init(
            id: "calm",
            nameZh: "平静", nameEn: "Calm",
            color: Color(red: 0.20, green: 0.68, blue: 0.90),
            icon: "leaf.fill",
            valence: .positive,
            emotions: [
                .init(id: "peaceful",    nameZh: "平和", nameEn: "Peaceful",    emoji: "🕊",  intensity: 2),
                .init(id: "relaxed",     nameZh: "放松", nameEn: "Relaxed",     emoji: "😌", intensity: 2),
                .init(id: "contented",   nameZh: "满足", nameEn: "Contented",   emoji: "🙂",  intensity: 2),
                .init(id: "serene",      nameZh: "宁静", nameEn: "Serene",      emoji: "🌿", intensity: 2),
                .init(id: "comfortable", nameZh: "舒适", nameEn: "Comfortable", emoji: "🛋",  intensity: 2),
                .init(id: "focused",     nameZh: "专注", nameEn: "Focused",     emoji: "🎯", intensity: 2),
                .init(id: "composed",    nameZh: "从容", nameEn: "Composed",    emoji: "🌅", intensity: 2),
                .init(id: "detached",    nameZh: "淡然", nameEn: "Detached",    emoji: "🌫",  intensity: 1),
                .init(id: "at_ease",     nameZh: "安然", nameEn: "At Ease",     emoji: "🌙", intensity: 1),
            ]
        ),

        // ── 爱与关怀 Love / Regard ────────────────────────────────────────
        .init(
            id: "regard",
            nameZh: "爱与关怀", nameEn: "Love / Regard",
            color: Color(red: 0.95, green: 0.45, blue: 0.65),
            icon: "heart.fill",
            valence: .positive,
            emotions: [
                .init(id: "loving",       nameZh: "充满爱",   nameEn: "Loving",      emoji: "❤️",  intensity: 4),
                .init(id: "affectionate", nameZh: "充满柔情", nameEn: "Affectionate",emoji: "💕", intensity: 4),
                .init(id: "admiration",   nameZh: "钦佩",     nameEn: "Admiration",  emoji: "👏", intensity: 3),
                .init(id: "compassion",   nameZh: "同情",     nameEn: "Compassion",  emoji: "🤲", intensity: 3),
                .init(id: "friendly",     nameZh: "友好",     nameEn: "Friendly",    emoji: "🙂",  intensity: 2),
            ]
        ),

        // ── 愤怒 Anger ────────────────────────────────────────────────────
        .init(
            id: "anger",
            nameZh: "愤怒", nameEn: "Anger",
            color: Color(red: 0.96, green: 0.27, blue: 0.22),
            icon: "flame.fill",
            valence: .negative,
            emotions: [
                .init(id: "fury",       nameZh: "狂怒", nameEn: "Fury",       emoji: "😡", intensity: 5),
                .init(id: "outrage",    nameZh: "愤慨", nameEn: "Outrage",    emoji: "🤬", intensity: 5),
                .init(id: "irritated",  nameZh: "烦躁", nameEn: "Irritated",  emoji: "😤", intensity: 3),
                .init(id: "annoyed",    nameZh: "恼火", nameEn: "Annoyed",    emoji: "😠", intensity: 3),
                .init(id: "resentful",  nameZh: "怨恨", nameEn: "Resentful",  emoji: "😒", intensity: 4),
                .init(id: "discontent", nameZh: "不满", nameEn: "Discontent", emoji: "😑", intensity: 2),
                .init(id: "jealous",    nameZh: "嫉妒", nameEn: "Jealous",    emoji: "💢", intensity: 3),
                .init(id: "frustrated", nameZh: "挫败", nameEn: "Frustrated", emoji: "🤦", intensity: 3),
            ]
        ),

        // ── 恐惧 Fear ─────────────────────────────────────────────────────
        .init(
            id: "fear",
            nameZh: "恐惧", nameEn: "Fear",
            color: Color(red: 0.68, green: 0.32, blue: 0.87),
            icon: "exclamationmark.triangle.fill",
            valence: .negative,
            emotions: [
                .init(id: "nervous",  nameZh: "紧张",   nameEn: "Nervous",  emoji: "😬", intensity: 3),
                .init(id: "worried",  nameZh: "担心",   nameEn: "Worried",  emoji: "😟", intensity: 3),
                .init(id: "afraid",   nameZh: "害怕",   nameEn: "Afraid",   emoji: "😨", intensity: 4),
                .init(id: "anxious",  nameZh: "焦虑",   nameEn: "Anxious",  emoji: "😰", intensity: 4),
                .init(id: "stressed", nameZh: "压力大", nameEn: "Stressed", emoji: "😫", intensity: 4),
                .init(id: "uneasy",   nameZh: "不安",   nameEn: "Uneasy",   emoji: "😧", intensity: 3),
                .init(id: "panicked", nameZh: "慌乱",   nameEn: "Panicked", emoji: "😱", intensity: 5),
                .init(id: "terrified",nameZh: "惶恐",   nameEn: "Terrified",emoji: "🫨", intensity: 5),
            ]
        ),

        // ── 悲伤 Disheartened ─────────────────────────────────────────────
        .init(
            id: "sad",
            nameZh: "悲伤", nameEn: "Disheartened",
            color: Color(red: 0.36, green: 0.54, blue: 0.75),
            icon: "cloud.drizzle.fill",
            valence: .negative,
            emotions: [
                .init(id: "sad",        nameZh: "难过",     nameEn: "Sad",        emoji: "😢", intensity: 3),
                .init(id: "lonely",     nameZh: "孤独",     nameEn: "Lonely",     emoji: "🥀", intensity: 4),
                .init(id: "hurt",       nameZh: "受伤",     nameEn: "Hurt",       emoji: "💔", intensity: 4),
                .init(id: "depressed",  nameZh: "抑郁",     nameEn: "Depressed",  emoji: "😞", intensity: 5),
                .init(id: "exhausted",  nameZh: "精疲力尽", nameEn: "Exhausted",  emoji: "😩", intensity: 4),
                .init(id: "lost",       nameZh: "失落",     nameEn: "Lost",       emoji: "🌧",  intensity: 3),
                .init(id: "aggrieved",  nameZh: "委屈",     nameEn: "Aggrieved",  emoji: "😿", intensity: 3),
                .init(id: "dejected",   nameZh: "沮丧",     nameEn: "Dejected",   emoji: "😔", intensity: 4),
                .init(id: "sorrowful",  nameZh: "哀伤",     nameEn: "Sorrowful",  emoji: "😭", intensity: 4),
                .init(id: "regret",     nameZh: "遗憾",     nameEn: "Regretful",  emoji: "🫤", intensity: 3),
                .init(id: "helpless",   nameZh: "无助",     nameEn: "Helpless",   emoji: "🤷", intensity: 4),
                .init(id: "desperate",  nameZh: "绝望",     nameEn: "Desperate",  emoji: "🖤", intensity: 5),
            ]
        ),

        // ── 羞愧 Shame ────────────────────────────────────────────────────
        .init(
            id: "shame",
            nameZh: "羞愧", nameEn: "Shame",
            color: Color(red: 0.55, green: 0.40, blue: 0.28),
            icon: "eye.slash.fill",
            valence: .negative,
            emotions: [
                .init(id: "ashamed",      nameZh: "羞愧", nameEn: "Ashamed",      emoji: "😳", intensity: 4),
                .init(id: "embarrassed",  nameZh: "尴尬", nameEn: "Embarrassed",  emoji: "😳", intensity: 3),
                .init(id: "guilty",       nameZh: "内疚", nameEn: "Guilty",       emoji: "😔", intensity: 4),
                .init(id: "remorseful",   nameZh: "后悔", nameEn: "Remorseful",   emoji: "😞", intensity: 3),
                .init(id: "shameful",     nameZh: "羞耻", nameEn: "Shameful",     emoji: "🙈", intensity: 4),
                .init(id: "self_blaming", nameZh: "自责", nameEn: "Self-blaming", emoji: "😣", intensity: 4),
                .init(id: "disgusted",    nameZh: "厌恶", nameEn: "Disgusted",    emoji: "🤢", intensity: 3),
                .init(id: "repulsed",     nameZh: "反感", nameEn: "Repulsed",     emoji: "😖", intensity: 3),
            ]
        ),

        // ── 惊讶 Surprise ─────────────────────────────────────────────────
        .init(
            id: "surprise",
            nameZh: "惊讶", nameEn: "Surprise",
            color: Color(red: 1.0, green: 0.58, blue: 0.0),
            icon: "sparkles",
            valence: .neutral,
            emotions: [
                .init(id: "shocked",     nameZh: "震惊", nameEn: "Shocked",     emoji: "😲", intensity: 4),
                .init(id: "startled",    nameZh: "受惊", nameEn: "Startled",    emoji: "😯", intensity: 3),
                .init(id: "amazed",      nameZh: "惊叹", nameEn: "Amazed",      emoji: "🤩", intensity: 4),
                .init(id: "astonished",  nameZh: "震撼", nameEn: "Astonished",  emoji: "😲", intensity: 4),
                .init(id: "pleasantly_surprised", nameZh: "惊喜", nameEn: "Pleasantly Surprised", emoji: "🎊", intensity: 4),
                .init(id: "confused",    nameZh: "困惑", nameEn: "Confused",    emoji: "🤔", intensity: 2),
                .init(id: "curious",     nameZh: "好奇", nameEn: "Curious",     emoji: "🧐", intensity: 2),
                .init(id: "unexpected",  nameZh: "意外", nameEn: "Unexpected",  emoji: "😮", intensity: 3),
            ]
        ),
    ]

    static func category(for emotion: String) -> EmotionCategory? {
        categories.first { $0.nameZh == emotion || $0.children.contains(emotion) }
    }
}
