import SwiftUI

// MARK: - Language Enum

enum AppLanguage: String, CaseIterable, Identifiable {
    case zh = "zh"
    case en = "en"
    case ja = "ja"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .zh: return "中文"
        case .en: return "English"
        case .ja: return "日本語"
        }
    }
}

// MARK: - Language Manager

@Observable
final class LanguageManager {
    static let shared = LanguageManager()

    var currentLanguage: AppLanguage

    init() {
        let stored = UserDefaults.standard.string(forKey: "appLanguage") ?? "zh"
        currentLanguage = AppLanguage(rawValue: stored) ?? .zh
    }

    func set(_ lang: AppLanguage) {
        currentLanguage = lang
        UserDefaults.standard.set(lang.rawValue, forKey: "appLanguage")
    }

    // MARK: - Term Translation (zh → current language)

    func display(_ zhTerm: String) -> String {
        switch currentLanguage {
        case .zh: return zhTerm
        case .en: return enTerms[zhTerm] ?? zhTerm
        case .ja: return jaTerms[zhTerm] ?? zhTerm
        }
    }

    // MARK: - Body Parts & Sensations Translation Dictionaries

    private let enTerms: [String: String] = [
        // Body parts
        "呼吸": "Breath", "腹部": "Abdomen", "心脏": "Heart", "心轮": "Heart Chakra",
        "眉心": "Third Eye", "胃": "Stomach", "海底轮": "Root Chakra", "头部": "Head",
        "眼睛": "Eyes", "脸部": "Face", "喉咙": "Throat", "头皮": "Scalp",
        "肩膀": "Shoulders", "颈部": "Neck", "手臂": "Arms", "手掌": "Palms",
        "大腿": "Thighs", "整个身体": "Whole Body",
        // Sensations
        "紧绷": "Tense", "沉重": "Heavy", "发热": "Hot", "空洞": "Empty",
        "酸胀": "Aching", "轻盈": "Light", "颤抖": "Trembling", "麻木": "Numb",
        "刺痛": "Tingling", "收缩": "Contracting", "压迫": "Pressure", "温暖": "Warm",
        "冰冷": "Cold", "放松": "Relaxed", "震动": "Vibrating", "膨胀": "Expanding",
        // Emotion categories
        "激情": "Impassioned", "快乐": "Happy", "平静": "Calm", "爱与关怀": "Love & Care",
        "愤怒": "Anger", "恐惧": "Fear", "悲伤": "Disheartened", 
        "惊讶": "Surprise",
        // Emotions – Impassioned
        "热情": "Enthusiastic", "兴奋": "Excited", "激动": "Aroused", "狂喜": "Delirious",
        "充满激情": "Passionate", "欣喜若狂": "Euphoric", "激动万分": "Thrilled",
        "坚定": "Determined", "自信": "Confident", "乐观": "Optimistic", "期待": "Anticipating",
        // Emotions – Happy
        "喜悦": "Joyful", "幸福": "Blissful", "被逗乐": "Amused", "高兴": "Delighted",
        "幸运": "Lucky", "感恩": "Grateful", "充满希望": "Hopeful", "充满活力": "Alive",
        "愉悦": "Pleasant",
        // Emotions – Calm
        "平和": "Peaceful", "满足": "Contented", "宁静": "Serene",
        "舒适": "Comfortable", "专注": "Focused", "从容": "Composed", "淡然": "Detached",
        "安然": "At Ease",
        // Emotions – Love & Care
        "充满爱": "Loving", "充满柔情": "Affectionate", "钦佩": "Admiring",
        "同情": "Compassionate", "友好": "Friendly",
        // Emotions – Anger
        "狂怒": "Furious", "愤慨": "Outraged", "烦躁": "Irritated", "恼火": "Annoyed",
        "怨恨": "Resentful", "不满": "Discontent", "嫉妒": "Jealous", "挫败": "Frustrated",
        // Emotions – Fear
        "紧张": "Nervous", "担心": "Worried", "害怕": "Afraid", "焦虑": "Anxious",
        "压力大": "Stressed", "不安": "Uneasy", "慌乱": "Panicked", "惶恐": "Terrified",
        // Emotions – Disheartened
        "难过": "Sad", "孤独": "Lonely", "受伤": "Hurt", "抑郁": "Depressed",
        "精疲力尽": "Exhausted", "失落": "Lost", "委屈": "Aggrieved", "沮丧": "Dejected",
        "哀伤": "Sorrowful", "遗憾": "Regretful", "无助": "Helpless", "绝望": "Desperate",
        // Emotions – Shame
        "羞愧": "Ashamed", "尴尬": "Embarrassed", "内疚": "Guilty", "后悔": "Remorseful",
        "羞耻": "Shameful", "自责": "Self-blaming", "厌恶": "Disgusted", "反感": "Repulsed",
        // Emotions – Surprise
        "震惊": "Shocked", "受惊": "Startled", "惊叹": "Amazed", "震撼": "Astonished",
        "惊喜": "Pleasantly Surprised", "困惑": "Confused", "好奇": "Curious", "意外": "Unexpected",
    ]

    private let jaTerms: [String: String] = [
        // Body parts
        "呼吸": "呼吸", "腹部": "腹部", "心脏": "心臓", "心轮": "ハートチャクラ",
        "眉心": "眉間", "胃": "胃", "海底轮": "ルートチャクラ", "头部": "頭",
        "眼睛": "目", "脸部": "顔", "喉咙": "喉", "头皮": "頭皮",
        "肩膀": "肩", "颈部": "首", "手臂": "腕", "手掌": "手のひら",
        "大腿": "太もも", "整个身体": "全身",
        // Sensations
        "紧绷": "緊張", "沉重": "重い", "发热": "熱い", "空洞": "空虚",
        "酸胀": "疼き", "轻盈": "軽い", "颤抖": "震え", "麻木": "しびれ",
        "刺痛": "チクチク", "收缩": "収縮", "压迫": "圧迫", "温暖": "温かい",
        "冰冷": "冷たい", "放松": "リラックス", "震动": "振動", "膨胀": "膨張",
        // Emotion categories
        "激情": "情熱", "快乐": "幸福", "平静": "平静", "爱与关怀": "愛と思いやり",
        "愤怒": "怒り", "恐惧": "恐れ", "悲伤": "悲しみ", 
        "惊讶": "驚き",
        // Emotions – Impassioned
        "热情": "情熱的", "兴奋": "興奮", "激动": "激動", "狂喜": "狂喜",
        "充满激情": "情熱いっぱい", "欣喜若狂": "有頂天", "激动万分": "大興奮",
        "坚定": "確固", "自信": "自信", "乐观": "楽観的", "期待": "期待",
        // Emotions – Happy
        "喜悦": "喜び", "幸福": "幸福", "被逗乐": "楽しい", "高兴": "嬉しい",
        "幸运": "幸運", "感恩": "感謝", "充满希望": "希望いっぱい", "充满活力": "活気いっぱい",
        "愉悦": "愉快",
        // Emotions – Calm
        "平和": "平和", "满足": "満足", "宁静": "静寂",
        "舒适": "快適", "专注": "集中", "从容": "余裕", "淡然": "淡々",
        "安然": "安らか",
        // Emotions – Love & Care
        "充满爱": "愛いっぱい", "充满柔情": "優しさいっぱい", "钦佩": "尊敬",
        "同情": "同情", "友好": "友好的",
        // Emotions – Anger
        "狂怒": "激怒", "愤慨": "憤慨", "烦躁": "イライラ", "恼火": "腹立たしい",
        "怨恨": "恨み", "不满": "不満", "嫉妒": "嫉妬", "挫败": "挫折",
        // Emotions – Fear
        "紧张": "緊張", "担心": "心配", "害怕": "怖い", "焦虑": "不安",
        "压力大": "プレッシャー", "不安": "落ち着かない", "慌乱": "パニック", "惶恐": "恐怖",
        // Emotions – Disheartened
        "难过": "悲しい", "孤独": "孤独", "受伤": "傷ついた", "抑郁": "落ち込み",
        "精疲力尽": "疲弊", "失落": "失望", "委屈": "悔しい", "沮丧": "がっかり",
        "哀伤": "哀しみ", "遗憾": "残念", "无助": "無力感", "绝望": "絶望",
        // Emotions – Shame
        "羞愧": "恥ずかしい", "尴尬": "気まずい", "内疚": "申し訳ない", "后悔": "後悔",
        "羞耻": "恥辱", "自责": "自己嫌悪", "厌恶": "嫌悪", "反感": "反感",
        // Emotions – Surprise
        "震惊": "衝撃", "受惊": "びっくり", "惊叹": "感嘆", "震撼": "驚愕",
        "惊喜": "嬉しい驚き", "困惑": "困惑", "好奇": "好奇心", "意外": "予想外",
    ]
}

// MARK: - UI Strings

extension LanguageManager {

    // MARK: Tabs
    var tabToday: String    { s("此刻",      "Now",       "今") }
    var tabJournal: String  { s("日记",      "Journal",   "日記") }
    var tabFriends: String  { s("好友",      "Friends",   "友達") }
    var tabSettings: String { s("设置",      "Settings",  "設定") }

    // MARK: TodayView
    var todayNavTitle: String    { s("此刻",   "Now",     "今") }
    var todayRecords: String     { s("今日记录", "Today's Records", "今日の記録") }
    var todayStartScan: String   { s("开始身体扫描", "Start Body Scan", "ボディスキャン開始") }
    var todayBodySaying: String  { s("此刻，你的身体在说什么？", "What is your body saying right now?", "今、あなたの体は何を言っていますか？") }
    var greetingMorning: String  { s("早上好", "Good morning",   "おはようございます") }
    var greetingAfternoon: String { s("下午好", "Good afternoon", "こんにちは") }
    var greetingEvening: String  { s("晚上好", "Good evening",   "こんばんは") }
    func todayNoCheckIn() -> String {
        s("你今天还没有签到，花一分钟感受一下身体吧。",
          "You haven't checked in today. Take a minute to scan your body.",
          "今日はまだチェックインしていません。少し身体を感じてみましょう。")
    }
    func todayCheckedIn(_ count: Int) -> String {
        switch currentLanguage {
        case .zh: return "今天已签到 \(count) 次，继续保持。"
        case .en: return "Checked in \(count) time\(count == 1 ? "" : "s") today. Keep it up!"
        case .ja: return "今日は \(count) 回チェックイン済み。この調子で！"
        }
    }

    // MARK: JournalView
    var journalNavTitle: String  { s("日记",         "Journal",          "日記") }
    var journalDelete: String    { s("删除",          "Delete",           "削除") }
    var journalEmpty: String     { s("还没有记录",    "No Records Yet",   "記録がまだありません") }
    var journalEmptyHint: String { s("完成第一次签到后，记录会出现在这里。",
                                     "Your records will appear here after your first check-in.",
                                     "最初のチェックイン後、記録がここに表示されます。") }
    var journalToday: String     { s("今天",     "Today",     "今日") }
    var journalYesterday: String { s("昨天",     "Yesterday", "昨日") }
    var journalDateFormat: String { s("M月d日", "MMM d", "M月d日") }

    // MARK: CheckInFlow
    var checkInCancel: String         { s("取消",    "Cancel",          "キャンセル") }
    var checkInStepBodyScan: String   { s("身体扫描", "Body Scan",       "ボディスキャン") }
    var checkInStepEmotion: String    { s("情绪识别", "Emotion Label",   "感情の識別") }
    var checkInStepAI: String         { s("AI 陪伴", "AI Companion",    "AIコンパニオン") }

    // MARK: BodyScanView
    var bodyScanWhereTitle: String    { s("哪里有感受？",   "Where do you feel it?",    "どこに感じますか？") }
    var bodyScanMultiple: String      { s("可多选",        "Multiple allowed",          "複数選択可") }
    var bodyScanWhatTitle: String     { s("是什么样的感受？", "What does it feel like?", "どんな感覚ですか？") }
    var bodyScanIntensity: String     { s("感受的强度",     "Intensity",                "感覚の強度") }
    var bodyScanNext: String          { s("下一步：识别情绪", "Next: Identify Emotions", "次へ：感情の識別") }
    var bodyScanMild: String          { s("轻微", "Mild",   "軽度") }
    var bodyScanIntense: String       { s("强烈", "Intense", "強烈") }

    // MARK: EmotionLabelView
    var emotionQuestion: String      { s("这种感受，更接近哪种情绪？",
                                        "What emotion does this feeling resemble?",
                                        "この感覚はどの感情に近いですか？") }
    var emotionSpecific: String      { s("更具体是…",           "More specifically…",            "より具体的には…") }
    var emotionCustomPrompt: String  { s("或者，你想用自己的词描述",  "Or describe it in your own words", "または、自分の言葉で表現する") }
    var emotionCustomPlaceholder: String { s("输入情绪词…", "Type an emotion...", "感情を入力...") }
    var emotionGenAI: String         { s("生成 AI 反馈",   "Generate AI Feedback", "AIフィードバックを生成") }
    var emotionSkip: String          { s("跳过，直接保存", "Skip and save directly", "スキップして保存") }
    var emotionSelected: String      { s("已选择", "Selected", "選択済み") }

    // MARK: AIFeedbackView
    var aiFeelingsSummary: String    { s("此刻的感受",        "Current Feelings",         "現在の感覚") }
    var aiNoteLabel: String          { s("添加备注（可选）",   "Add a note (optional)",    "メモを追加（任意）") }
    var aiNotePlaceholder: String    { s("记录一些额外的想法…", "Record some extra thoughts...", "追加のメモ...") }
    var aiShareTitle: String         { s("分享给好友？",       "Share with friends?",      "友達とシェアする？") }
    var aiDontShare: String          { s("不分享",             "Don't share",              "シェアしない") }
    var aiOnlySelf: String           { s("仅自己可见",         "Only visible to me",       "自分のみ") }
    var aiCompanion: String          { s("AI 陪伴",            "AI Companion",             "AIコンパニオン") }
    var aiSave: String               { s("保存记录",           "Save Record",              "記録を保存") }
    var aiLoading: String            { s("正在感受你的感受…",   "Processing your feelings...", "あなたの気持ちを処理中...") }
    var aiRetry: String              { s("重试",               "Retry",                    "再試行") }
    func aiIntensityBadge(_ v: Int) -> String {
        s("强度 \(v)/10", "Intensity \(v)/10", "強度 \(v)/10")
    }

    // MARK: Privacy Tier (AIFeedbackView share section)
    var tierCategoryName: String    { s("只分享情绪大类",   "Share emotion category",   "感情カテゴリのみ") }
    var tierCategoryDesc: String    { s("好友只看到情绪大类和强度", "Friend sees only emotion category and intensity", "友達には感情カテゴリと強度のみ表示") }
    var tierEmotionsName: String    { s("分享情绪词",       "Share emotion words",       "感情の言葉をシェア") }
    var tierEmotionsDesc: String    { s("好友看到具体情绪词", "Friend sees specific emotion words", "友達には具体的な感情の言葉が表示") }
    var tierFullName: String        { s("完整分享",         "Full share",               "完全シェア") }
    var tierFullDesc: String        { s("好友看到全部内容含笔记", "Friend sees everything including notes", "友達にはメモを含む全内容が表示") }

    // MARK: FriendFeedView
    var friendNavTitle: String       { s("好友",            "Friends",                  "友達") }
    var friendNoFriends: String      { s("还没有好友",      "No Friends Yet",           "まだ友達がいません") }
    var friendInviteHint: String     { s("邀请朋友互相分享情绪吧", "Invite friends to share moods with each other", "友達を招待して感情をシェアしよう") }
    var friendInvite: String         { s("邀请好友",        "Invite Friends",           "友達を招待") }
    var friendEmptyFeed: String      { s("好友还没有分享任何情绪", "No friend has shared any mood yet", "友達はまだ感情をシェアしていません") }
    var friendDefaultName: String    { s("朋友",            "Friend",                   "友達") }

    // MARK: FriendSetupView
    var setupTitle: String           { s("设置你的好友档案", "Set Up Your Friend Profile", "友達プロフィールを設定") }
    var setupSubtitle: String        { s("好友看到的就是这个名字和头像", "Friends will see this name and avatar", "友達にはこの名前とアバターが表示されます") }
    var setupChooseEmoji: String     { s("选一个头像 emoji", "Choose an avatar emoji", "アバター絵文字を選択") }
    var setupNicknameLabel: String   { s("你的昵称",   "Your Nickname",       "ニックネーム") }
    var setupNicknamePlaceholder: String { s("输入昵称…", "Enter nickname...", "ニックネームを入力...") }
    var setupDone: String            { s("完成",       "Done",                "完了") }

    // MARK: FriendManageView
    var manageNavTitle: String       { s("好友管理",   "Friend Management",   "友達管理") }
    var manageInviteAction: String   { s("邀请好友 / 输入邀请码", "Invite / Enter Code", "招待/コードを入力") }
    func manageConnectedFriends(_ count: Int) -> String {
        s("已连接的好友 (\(count))", "Connected Friends (\(count))", "繋がっている友達 (\(count))")
    }
    var manageDisconnect: String     { s("断开连接",   "Disconnect",          "接続を解除") }
    var manageNoFriends: String      { s("还没有好友，发送邀请链接来连接吧",
                                        "No friends yet. Share an invite link to connect.",
                                        "まだ友達がいません。招待リンクをシェアして繋がりましょう。") }
    func manageConnectedOn(_ date: String) -> String {
        s("连接于 \(date)", "Connected on \(date)", "接続日: \(date)")
    }
    func manageDisconnectAlert(_ name: String) -> String {
        s("断开与「\(name)」的连接？", "Disconnect from \"\(name)\"?", "「\(name)」との接続を解除しますか？")
    }
    var manageDisconnectMessage: String { s("双方将不再能看到彼此分享的情绪记录",
                                            "You will no longer see each other's shared mood records.",
                                            "互いにシェアした感情記録は見られなくなります。") }
    var manageCancel: String         { s("取消", "Cancel", "キャンセル") }

    // MARK: InviteView
    var inviteNavTitle: String       { s("邀请 / 添加好友", "Invite / Add Friend", "招待/友達追加") }
    var inviteSendTitle: String      { s("邀请好友", "Invite Friends", "友達を招待") }
    var inviteSendHint: String       { s("生成一个邀请链接，发给对方。对方点击后即可互相添加。",
                                        "Generate an invite link and send it to your friend. They can tap it to connect.",
                                        "招待リンクを生成して友達に送りましょう。タップするだけで繋がれます。") }
    var inviteGenerate: String       { s("生成邀请链接", "Generate Invite Link", "招待リンクを生成") }
    var inviteRegenerate: String     { s("重新生成",    "Regenerate",           "再生成") }
    var inviteEnterTitle: String     { s("输入邀请码",  "Enter Invite Code",    "招待コードを入力") }
    var inviteEnterHint: String      { s("如果朋友把邀请码发给了你，在这里输入。",
                                        "If a friend sent you an invite code, enter it here.",
                                        "友達からの招待コードをここに入力してください。") }
    var inviteSuccess: String        { s("添加成功！",  "Added successfully!",  "追加成功！") }
    var invitePlaceholder: String    { s("输入8位邀请码…", "Enter 8-digit invite code...", "8桁の招待コードを入力...") }
    var inviteConfirm: String        { s("确认添加",   "Confirm",              "確認して追加") }

    // MARK: InviteAcceptSheet
    var acceptSuccess: String        { s("已成功添加好友！", "Friend added successfully!", "友達の追加に成功しました！") }
    var acceptTitle: String          { s("收到一个好友邀请", "Friend Invitation Received", "友達招待を受け取りました") }
    func acceptCode(_ code: String) -> String { s("邀请码：\(code)", "Invite code: \(code)", "招待コード：\(code)") }
    var acceptButton: String         { s("接受邀请",   "Accept Invitation",    "招待を受け入れる") }
    var acceptLater: String          { s("稍后再说",   "Maybe Later",          "後で") }
    var acceptNavTitle: String       { s("好友邀请",   "Friend Invitation",    "友達招待") }

    // MARK: SettingsView
    var settingsNavTitle: String     { s("设置",           "Settings",             "設定") }
    var settingsAISection: String    { s("AI 设置",         "AI Settings",          "AI設定") }
    var settingsSaved: String        { s("已保存",          "Saved",                "保存済み") }
    var settingsGetKey: String       { s("获取 API Key →",  "Get API Key →",        "API Keyを取得 →") }
    var settingsKeyFooter: String    { s("API Key 仅存储在本机，不会上传到任何服务器。",
                                        "API Key is stored locally only and never uploaded to any server.",
                                        "API Keyはローカルにのみ保存され、サーバーにアップロードされることはありません。") }
    var settingsRemindersSection: String { s("定时提醒",    "Reminders",            "リマインダー") }
    var settingsEnableReminder: String   { s("开启提醒",    "Enable Reminders",     "リマインダーを有効にする") }
    var settingsSaveReminder: String     { s("保存提醒设置", "Save Reminder Settings", "リマインダー設定を保存") }
    var settingsReminderFooterOn: String  { s("提醒会在设定时间以本地通知推送。",
                                             "Reminders will be sent as local notifications at the set times.",
                                             "設定した時刻にローカル通知でリマインダーが届きます。") }
    var settingsReminderFooterOff: String { s("请在系统设置中允许通知权限，以便接收提醒。",
                                              "Please allow notification permission in System Settings to receive reminders.",
                                              "リマインダーを受け取るには、システム設定で通知を許可してください。") }
    var settingsAboutSection: String     { s("关于",        "About",                "このアプリについて") }
    var settingsVersion: String          { s("版本",        "Version",              "バージョン") }
    var settingsDataStorage: String      { s("数据存储",    "Data Storage",         "データ保存") }
    var settingsLocalOnly: String        { s("仅限本机",    "Local only",           "ローカルのみ") }
    var settingsLanguageSection: String  { s("语言",        "Language",             "言語") }

    // MARK: CheckInDetailView
    var detailNavTitle: String       { s("记录详情",   "Record Detail",   "記録の詳細") }
    var detailDone: String           { s("完成",       "Done",            "完了") }
    var detailBodySection: String    { s("身体感受",   "Body Sensations", "身体の感覚") }
    var detailEmotionsSection: String { s("情绪",      "Emotions",        "感情") }
    var detailNoteSection: String    { s("备注",       "Note",            "メモ") }
    var detailDateFormat: String     { s("yyyy年M月d日", "MMM d, yyyy",   "yyyy年M月d日") }

    // MARK: ClaudeService (error messages)
    var claudeNoApiKey: String       { s("请先在设置中填写 Claude API Key",
                                        "Please enter your Claude API Key in Settings first.",
                                        "先に設定でClaude API Keyを入力してください。") }
    func claudeApiError(_ code: Int) -> String {
        s("API 请求失败（HTTP \(code)）", "API request failed (HTTP \(code))", "APIリクエストが失敗しました（HTTP \(code)）")
    }
    var claudeDecodeError: String    { s("解析 AI 响应失败", "Failed to parse AI response", "AI応答の解析に失敗しました") }

    // MARK: - Private helper
    private func s(_ zh: String, _ en: String, _ ja: String) -> String {
        switch currentLanguage {
        case .zh: return zh
        case .en: return en
        case .ja: return ja
        }
    }
}
