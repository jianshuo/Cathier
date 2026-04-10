const { getUserPrefs, getCheckIns } = require('../../utils/cloud-db')

Page({
  data: {
    greeting: '',
    totalCheckInCount: 0,
    todayCheckIns: [],
    todayCheckInCount: 0
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
  },

  formatCheckIn(record) {
    // Format time
    const d = record.date ? new Date(record.date) : new Date(record.createdAt)
    const hours = String(d.getHours()).padStart(2, '0')
    const minutes = String(d.getMinutes()).padStart(2, '0')
    const timeStr = `${hours}:${minutes}`

    // Format emotions with emoji
    const emotions = (record.emotions || []).map(em => {
      if (typeof em === 'string') return { label: em, emoji: '' }
      return { label: em.name || em.label || '', emoji: em.emoji || '' }
    })

    // Format body parts + sensations from bodySensations map
    const bs = record.bodySensations || {}
    const bodySummary = Object.keys(bs).map(part => {
      const sns = bs[part]
      if (sns && sns.length > 0) {
        return `${part}(${sns.join('、')})`
      }
      return part
    }).join('、')

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
      bodySummary: bodySummary,
      intensity: record.intensity || 0,
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

  onOpenSettings() {
    wx.navigateTo({
      url: '/pages/settings/settings'
    })
  }
})
