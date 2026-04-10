const { getUserPrefs, getCheckIns, getTodayJournal } = require('../../utils/cloud-db')

const CATEGORY_COLORS = {
  '激情': '#FF5933',
  '快乐': '#FFBF00',
  '平静': '#33ADE6',
  '爱与关怀': '#F272A5',
  '愤怒': '#F54538',
  '恐惧': '#AD52DE',
  '悲伤': '#5C8ABF',
  '羞愧': '#8C6647',
  '惊讶': '#FF9400'
}

function getIntensityInfo(intensity) {
  if (intensity <= 0) return { color: '', label: '' }
  if (intensity <= 3) return { color: '#FFBF00', label: '轻微' }
  if (intensity <= 6) return { color: '#F2700A', label: '中等' }
  if (intensity <= 8) return { color: '#D96308', label: '较强' }
  return { color: '#F54538', label: '强烈' }
}

Page({
  data: {
    greeting: '',
    totalCheckInCount: 0,
    todayCheckIns: [],
    todayCheckInCount: 0,
    todayJournal: null
  },

  onLoad() {
    this.updateGreeting()
  },

  onShow() {
    this.updateGreeting()
    this.loadTodayData()
  },

  updateGreeting() {
    const hour = new Date().getHours()
    let greeting = '晚上好'
    if (hour < 6) greeting = '夜深了'
    else if (hour < 12) greeting = '早上好'
    else if (hour < 14) greeting = '中午好'
    else if (hour < 18) greeting = '下午好'
    this.setData({ greeting })
  },

  loadTodayData() {
    // Load user prefs for total count
    getUserPrefs().then(prefs => {
      if (prefs) {
        this.setData({
          totalCheckInCount: prefs.totalCheckInCount || 0
        })
      }
    }).catch(err => {
      console.error('Failed to load user prefs:', err)
    })

    // Load recent check-ins and filter to today
    getCheckIns(0, 50).then(res => {
      const records = res.data || res || []
      const today = new Date()
      today.setHours(0, 0, 0, 0)

      const todayRecords = records
        .filter(r => {
          const d = r.date ? new Date(r.date) : (r.createdAt ? new Date(r.createdAt) : null)
          return d && d >= today
        })
        .map(r => this.formatCheckIn(r))

      this.setData({
        todayCheckIns: todayRecords,
        todayCheckInCount: todayRecords.length
      })
    }).catch(err => {
      console.error('Failed to load check-ins:', err)
    })

    // Load today's journal
    const MOOD_MAP = {
      veryHappy: { emoji: '\uD83D\uDE04', label: '很开心' },
      good: { emoji: '\uD83D\uDE0A', label: '不错' },
      okay: { emoji: '\uD83D\uDE10', label: '还好' },
      notGreat: { emoji: '\uD83D\uDE14', label: '不太好' },
      bad: { emoji: '\uD83D\uDE22', label: '很难过' }
    }

    getTodayJournal().then(journal => {
      if (journal) {
        const moodInfo = MOOD_MAP[journal.mood] || { emoji: '', label: '' }
        const gainsPreview = journal.gains && journal.gains.length > 60
          ? journal.gains.substring(0, 60) + '...'
          : (journal.gains || '')
        this.setData({
          todayJournal: {
            moodEmoji: moodInfo.emoji,
            moodLabel: moodInfo.label,
            gainsPreview: gainsPreview
          }
        })
      } else {
        this.setData({ todayJournal: null })
      }
    }).catch(err => {
      console.error('Failed to load today journal:', err)
    })
  },

  formatCheckIn(record) {
    // Format time
    const d = record.date ? new Date(record.date) : new Date(record.createdAt)
    const hours = String(d.getHours()).padStart(2, '0')
    const minutes = String(d.getMinutes()).padStart(2, '0')
    const timeStr = `${hours}:${minutes}`

    // Format emotions with emoji and category color
    const emotions = (record.emotions || []).map(em => {
      if (typeof em === 'string') return { label: em, emoji: '', categoryColor: '' }
      const catColor = CATEGORY_COLORS[em.categoryName] || ''
      return {
        label: em.name || em.label || '',
        emoji: em.emoji || '',
        categoryColor: catColor
      }
    })

    // Format body parts + sensations as grouped array
    const bs = record.bodySensations || {}
    const bodyGroups = Object.keys(bs).map(part => {
      const sns = bs[part] || []
      return { part, sensations: sns, sensationsText: sns.join('、') }
    })
    const bodySummary = bodyGroups.length > 0 ? 'has_body' : ''

    // Intensity color coding
    const intensityInfo = getIntensityInfo(record.intensity || 0)

    // AI feedback preview (first ~80 chars)
    let feedbackPreview = ''
    if (record.aiFeedback) {
      feedbackPreview = record.aiFeedback.length > 80
        ? record.aiFeedback.substring(0, 80) + '...'
        : record.aiFeedback
    }

    return {
      _id: record._id,
      time: timeStr,
      emotions: emotions,
      bodyGroups: bodyGroups,
      bodySummary: bodySummary,
      intensity: record.intensity || 0,
      intensityColor: intensityInfo.color,
      intensityLabel: intensityInfo.label,
      feedbackPreview: feedbackPreview,
      triggerEvent: record.triggerEvent || '',
      note: record.note || ''
    }
  },

  onStartCheckIn() {
    wx.navigateTo({
      url: '/pages/body-scan/body-scan'
    })
  },

  onCheckInTap(e) {
    const id = e.currentTarget.dataset.id
    if (id) {
      wx.navigateTo({
        url: '/pages/checkin-detail/checkin-detail?id=' + id
      })
    }
  },

  onWriteJournal() {
    wx.navigateTo({
      url: '/pages/journal-entry/journal-entry'
    })
  },

  onOpenSettings() {
    wx.navigateTo({
      url: '/pages/settings/settings'
    })
  }
})
