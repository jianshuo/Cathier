import Foundation

// MARK: - UI Strings

extension LanguageManager {

    // MARK: Tabs
    var tabToday: String    { localized("tab.today") }
    var tabJournal: String  { localized("tab.journal") }
    var tabFriends: String  { localized("tab.friends") }
    var tabSettings: String { localized("tab.settings") }

    // MARK: TodayView
    var todayNavTitle: String     { localized("today.nav_title") }
    var todayRecords: String      { localized("today.records") }
    var todayStartScan: String    { localized("today.start_scan") }
    var todayBodySaying: String   { localized("today.body_saying") }
    var greetingMorning: String   { localized("greeting.morning") }
    var greetingAfternoon: String { localized("greeting.afternoon") }
    var greetingEvening: String   { localized("greeting.evening") }
    var streakLabel: String       { localized("today.streak_label") }
    func todayNoCheckIn() -> String { localized("today.no_check_in") }
    func todayCheckedIn(_ count: Int) -> String {
        String(format: localized("today.checked_in"), count)
    }

    // MARK: JournalView
    var journalNavTitle: String   { localized("journal.nav_title") }
    var journalDelete: String     { localized("journal.delete") }
    var journalEmpty: String      { localized("journal.empty") }
    var journalEmptyHint: String  { localized("journal.empty_hint") }
    var journalToday: String      { localized("journal.today") }
    var journalYesterday: String  { localized("journal.yesterday") }
    var journalDateFormat: String { localized("journal.date_format") }

    // MARK: CheckInFlow
    var checkInCancel: String       { localized("check_in.cancel") }
    var checkInStepBodyScan: String { localized("check_in.step_body_scan") }
    var checkInStepEmotion: String  { localized("check_in.step_emotion") }
    var checkInStepAI: String       { localized("check_in.step_ai") }

    // MARK: BodyScanView
    var bodyScanWhereTitle: String        { localized("body_scan.where_title") }
    var bodyScanMultiple: String          { localized("body_scan.multiple") }
    var bodyScanWhatTitle: String         { localized("body_scan.what_title") }
    var bodyScanTriggerTitle: String      { localized("body_scan.trigger_title") }
    var bodyScanTriggerSubtitle: String   { localized("body_scan.trigger_subtitle") }
    var bodyScanTriggerPlaceholder: String { localized("body_scan.trigger_placeholder") }
    var bodyScanIntensity: String         { localized("body_scan.intensity") }
    var bodyScanNext: String              { localized("body_scan.next") }
    var bodyScanMild: String              { localized("body_scan.mild") }
    var bodyScanIntense: String           { localized("body_scan.intense") }

    // MARK: EmotionLabelView
    var emotionQuestion: String          { localized("emotion.question") }
    var emotionSpecific: String          { localized("emotion.specific") }
    var emotionCustomPrompt: String      { localized("emotion.custom_prompt") }
    var emotionCustomPlaceholder: String { localized("emotion.custom_placeholder") }
    var emotionGenAI: String             { localized("emotion.gen_ai") }
    var emotionSkip: String              { localized("emotion.skip") }
    var emotionSelected: String          { localized("emotion.selected") }

    // MARK: AIFeedbackView
    var aiFeelingsSummary: String  { localized("ai.feelings_summary") }
    var aiNoteLabel: String        { localized("ai.note_label") }
    var aiNotePlaceholder: String  { localized("ai.note_placeholder") }
    var aiShareTitle: String       { localized("ai.share_title") }
    var aiDontShare: String        { localized("ai.dont_share") }
    var aiOnlySelf: String         { localized("ai.only_self") }
    var aiCompanion: String        { localized("ai.companion") }
    var aiSave: String             { localized("ai.save") }
    var aiLoading: String          { localized("ai.loading") }
    var aiRetry: String            { localized("ai.retry") }
    func aiIntensityBadge(_ v: Int) -> String {
        String(format: localized("ai.intensity_badge"), v)
    }

    // MARK: AI Companion Personas
    var personaPickerLabel: String { localized("persona.picker_label") }

    // MARK: MicroExerciseView
    var exerciseNavTitle: String  { localized("exercise.nav_title") }
    var exerciseLoading: String   { localized("exercise.loading") }
    var exerciseRetry: String     { localized("exercise.retry") }
    var exerciseStart: String     { localized("exercise.start") }
    var exerciseStop: String      { localized("exercise.stop") }
    var exerciseDone: String      { localized("exercise.done") }
    var exerciseClose: String     { localized("exercise.close") }
    var exerciseTryThis: String   { localized("exercise.try_this") }
    var exerciseTryHint: String   { localized("exercise.try_hint") }

    // MARK: Privacy Tier
    var tierCategoryName: String        { localized("tier.category_name") }
    var tierCategoryDesc: String        { localized("tier.category_desc") }
    var tierEmotionsName: String        { localized("tier.emotions_name") }
    var tierEmotionsDesc: String        { localized("tier.emotions_desc") }
    var tierFullName: String            { localized("tier.full_name") }
    var tierFullDesc: String            { localized("tier.full_desc") }
    var aiShareAIFeedbackToggle: String { localized("ai.share_ai_feedback_toggle") }
    var aiShareAIFeedbackDesc: String   { localized("ai.share_ai_feedback_desc") }

    // MARK: FriendFeedView
    var friendNavTitle: String    { localized("friend.nav_title") }
    var friendNoFriends: String   { localized("friend.no_friends") }
    var friendAddHint: String     { localized("friend.add_hint") }
    var friendAddFriend: String   { localized("friend.add_friend") }
    var friendEmptyFeed: String   { localized("friend.empty_feed") }
    var friendDefaultName: String { localized("friend.default_name") }
    var friendRetry: String       { localized("friend.retry") }
    var aiReadMore: String        { localized("ai.read_more") }
    var aiFullInterpretation: String { localized("ai.full_interpretation") }

    // MARK: FriendSetupView
    var setupTitle: String               { localized("setup.title") }
    var setupSubtitle: String            { localized("setup.subtitle") }
    var setupChooseEmoji: String         { localized("setup.choose_emoji") }
    var setupNicknameLabel: String       { localized("setup.nickname_label") }
    var setupNicknamePlaceholder: String { localized("setup.nickname_placeholder") }
    var setupDone: String                { localized("setup.done") }

    // MARK: FriendManageView
    var manageNavTitle: String      { localized("manage.nav_title") }
    var manageAddFriend: String     { localized("manage.add_friend") }
    func manageConnectedFriends(_ count: Int) -> String {
        String(format: localized("manage.connected_friends"), count)
    }
    var manageDisconnect: String        { localized("manage.disconnect") }
    var manageNoFriends: String         { localized("manage.no_friends") }
    func manageConnectedOn(_ date: String) -> String {
        String(format: localized("manage.connected_on"), date)
    }
    func manageDisconnectAlert(_ name: String) -> String {
        String(format: localized("manage.disconnect_alert"), name)
    }
    var manageDisconnectMessage: String { localized("manage.disconnect_message") }
    var manageCancel: String            { localized("manage.cancel") }

    // MARK: AddFriendView
    var searchNavTitle: String      { localized("search.nav_title") }
    var searchPlaceholder: String   { localized("search.placeholder") }
    var searchHint: String          { localized("search.hint") }
    var searchNoResults: String     { localized("search.no_results") }
    var searchAdd: String           { localized("search.add") }
    var searchRequested: String     { localized("search.requested") }
    var searchAlreadyFriends: String { localized("search.already_friends") }

    // MARK: FriendRequestsView
    var requestPendingSection: String { localized("request.pending_section") }
    var requestAccept: String         { localized("request.accept") }
    var requestDecline: String        { localized("request.decline") }
    var requestFrom: String           { localized("request.from") }

    // MARK: SettingsView
    var settingsNavTitle: String          { localized("settings.nav_title") }
    var settingsRemindersSection: String  { localized("settings.reminders_section") }
    var settingsEnableReminder: String    { localized("settings.enable_reminder") }
    var settingsSaveReminder: String      { localized("settings.save_reminder") }
    var settingsReminderFooterOn: String  { localized("settings.reminder_footer_on") }
    var settingsReminderFooterOff: String { localized("settings.reminder_footer_off") }
    var settingsAboutSection: String      { localized("settings.about_section") }
    var settingsAboutRow: String          { localized("settings.about_row") }
    var settingsVersion: String           { localized("settings.version") }
    var settingsBuild: String             { localized("settings.build") }
    var settingsDataStorage: String       { localized("settings.data_storage") }
    var settingsLocalOnly: String         { localized("settings.local_only") }
    var settingsLanguageSection: String   { localized("settings.language_section") }
    var settingsContextSection: String    { localized("settings.context_section") }
    var settingsContextPlaceholder: String { localized("settings.context_placeholder") }
    var settingsContextFooter: String     { localized("settings.context_footer") }

    // MARK: AboutView
    var aboutMadeBy: String        { localized("about.made_by") }
    var aboutCreatorName: String   { localized("about.creator_name") }
    var aboutAppDescription: String { localized("about.app_description") }
    var aboutPrivacyTitle: String  { localized("about.privacy_title") }
    var aboutPrivacyDetail: String { localized("about.privacy_detail") }
    var aboutCopyrightLabel: String { localized("about.copyright_label") }

    // MARK: DailyJournalEntryView
    var journalEntryNavTitle: String         { localized("journal_entry.nav_title") }
    var journalEntryMoodLabel: String        { localized("journal_entry.mood_label") }
    var journalEntryGainsLabel: String       { localized("journal_entry.gains_label") }
    var journalEntryGainsPlaceholder: String { localized("journal_entry.gains_placeholder") }
    var journalEntryShareLabel: String       { localized("journal_entry.share_label") }
    var journalEntryShareDesc: String        { localized("journal_entry.share_desc") }
    var journalEntrySave: String             { localized("journal_entry.save") }
    var journalEntryEdit: String             { localized("journal_entry.edit") }
    var journalEntryOnceADay: String         { localized("journal_entry.once_a_day") }
    var journalEntryTodayTitle: String       { localized("journal_entry.today_title") }
    var journalEntrySharedBadge: String      { localized("journal_entry.shared_badge") }
    var journalEntryPrivateBadge: String     { localized("journal_entry.private_badge") }
    var journalEntryWritePrompt: String      { localized("journal_entry.write_prompt") }
    var journalEntryWriteHint: String        { localized("journal_entry.write_hint") }

    // MARK: FeedbackView
    var feedbackNavTitle: String         { localized("feedback.nav_title") }
    var feedbackSectionTitle: String     { localized("feedback.section_title") }
    var feedbackButton: String           { localized("feedback.button") }
    var feedbackTitleLabel: String       { localized("feedback.title_label") }
    var feedbackTitlePlaceholder: String { localized("feedback.title_placeholder") }
    var feedbackBodyLabel: String        { localized("feedback.body_label") }
    var feedbackBodyFooter: String       { localized("feedback.body_footer") }
    var feedbackTokenSection: String     { localized("feedback.token_section") }
    var feedbackTokenFooter: String      { localized("feedback.token_footer") }
    var feedbackSubmit: String           { localized("feedback.submit") }
    var feedbackSuccess: String          { localized("feedback.success") }
    var feedbackViewIssue: String        { localized("feedback.view_issue") }

    // MARK: CheckInDetailView
    var detailNavTitle: String        { localized("detail.nav_title") }
    var detailDone: String            { localized("detail.done") }
    var detailBodySection: String     { localized("detail.body_section") }
    var detailEmotionsSection: String { localized("detail.emotions_section") }
    var detailTriggerSection: String  { localized("detail.trigger_section") }
    var detailNoteSection: String     { localized("detail.note_section") }
    var detailDateFormat: String      { localized("detail.date_format") }
    var detailCopyAI: String          { localized("detail.copy_ai") }

    // MARK: InsightsView
    var insightsNavTitle: String      { localized("insights.nav_title") }
    var insightsToolbarButton: String { localized("insights.toolbar_button") }
    var insightsFocusTitle: String    { localized("insights.focus_title") }
    var insightsFocusTriggers: String { localized("insights.focus_triggers") }
    var insightsFocusGrowth: String   { localized("insights.focus_growth") }
    var insightsFocusBody: String     { localized("insights.focus_body") }
    var insightsFocusSurprise: String { localized("insights.focus_surprise") }
    var insightsAnalyze: String       { localized("insights.analyze") }
    var insightsRefresh: String       { localized("insights.refresh") }
    var insightsLoading: String       { localized("insights.loading") }
    var insightsEmptyTitle: String    { localized("insights.empty_title") }
    var insightsEmptyHint: String     { localized("insights.empty_hint") }
    var insightsLoadError: String     { localized("insights.load_error") }
    var insightsHistoryTitle: String  { localized("insights.history_title") }
    var insightsHistoryEmpty: String  { localized("insights.history_empty") }
    var insightsAnalyzedAt: String    { localized("insights.analyzed_at") }
    func insightsNewCheckIns(_ n: Int) -> String {
        String(format: localized("insights.new_check_ins"), n)
    }
    var insightsChartTitle: String    { localized("insights.chart_title") }

    // MARK: Notifications
    var notifMilestoneTitle: String { localized("notif.milestone_title") }
    var notifMilestoneBody: String  { localized("notif.milestone_body") }

    // MARK: Error messages
    var claudeNoApiKey: String     { localized("error.no_api_key") }
    func claudeApiError(_ code: Int) -> String {
        String(format: localized("error.api_error"), code)
    }
    var claudeDecodeError: String  { localized("error.decode_error") }
}
