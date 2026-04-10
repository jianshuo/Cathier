Page({
  data: {
    reminderEnabled: false,
    reminderTime: '21:00',
    contextBrief: '',
    version: '1.8',
    totalCheckIns: 0,
    showAbout: false
  },

  onLoad() {
    this.loadSettings()
  },

  onShow() {
  },

  loadSettings() {
    const reminderEnabled = wx.getStorageSync('reminderEnabled') || false
    const reminderTime = wx.getStorageSync('reminderTime') || '21:00'
    const contextBrief = wx.getStorageSync('contextBrief') || ''
    const totalCheckIns = wx.getStorageSync('totalCheckIns') || 0
    this.setData({ reminderEnabled, reminderTime, contextBrief, totalCheckIns })
  },

  onReminderToggle(e) {
    const enabled = e.detail.value
    this.setData({ reminderEnabled: enabled })
    wx.setStorageSync('reminderEnabled', enabled)
    if (enabled) {
      // TODO: request subscription message permission
    }
  },

  onReminderTimeChange(e) {
    const time = e.detail.value
    this.setData({ reminderTime: time })
    wx.setStorageSync('reminderTime', time)
  },

  onContextBriefInput(e) {
    const value = e.detail.value
    this.setData({ contextBrief: value })
    wx.setStorageSync('contextBrief', value)
  },

  onClearData() {
    wx.showModal({
      title: '清除数据',
      content: '确定要清除所有本地缓存数据吗？云端数据不受影响。',
      confirmText: '清除',
      confirmColor: '#C75450',
      success: (res) => {
        if (res.confirm) {
          wx.clearStorageSync()
          this.loadSettings()
          wx.showToast({ title: '已清除', icon: 'success' })
        }
      }
    })
  },

  onFeedback() {
    wx.navigateTo({ url: '/pages/feedback/feedback' })
  },

  onAbout() {
    this.setData({ showAbout: true })
  },

  onCloseAbout() {
    this.setData({ showAbout: false })
  },

  onPrivacyPolicy() {
    wx.navigateTo({ url: '/pages/webview/webview?url=' + encodeURIComponent('https://cathier.app/privacy') + '&title=隐私政策' })
  },

  onTerms() {
    wx.navigateTo({ url: '/pages/webview/webview?url=' + encodeURIComponent('https://cathier.app/terms') + '&title=用户协议' })
  }
})
