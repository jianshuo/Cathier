const { initSyncListeners } = require('./utils/local-buffer')

App({
  onLaunch() {
    // Load emotion data first (no cloud dependency)
    try {
      this.globalData.emotions = require('./data/emotions.js')
    } catch (e) {
      console.error('Failed to load emotions.json', e)
    }

    if (!wx.cloud) {
      console.error('请使用 2.2.3 以上的基础库')
      return
    }
    wx.cloud.init({
      traceUser: true
    })

    // Initialize offline buffer sync listeners
    initSyncListeners()
  },
  globalData: {
    userOpenId: null,
    emotions: null
  }
})
