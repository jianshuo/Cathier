Page({
  data: {
    reminderEnabled: false,
    reminderTime: '21:00',
    contextBrief: '',
    version: '1.0.0',
    totalCheckIns: 0
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
    // TODO: open feedback channel
  },

  onAbout() {
    // TODO: navigate to about page or show modal
    wx.showModal({
      title: '关于觉察',
      content: '觉察是一款帮助你感知和理解自身情绪的小程序。通过身体扫描和情绪命名，培养内在觉察力。\n\n版本：' + this.data.version,
      showCancel: false,
      confirmText: '好的'
    })
  }
})
