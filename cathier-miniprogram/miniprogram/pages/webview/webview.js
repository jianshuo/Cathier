const { getDefaultShareData, getDefaultTimelineData } = require('../../utils/share')

Page({
  data: {
    url: ''
  },

  onLoad(options) {
    if (options.url) {
      this.setData({ url: decodeURIComponent(options.url) })
    }
    if (options.title) {
      wx.setNavigationBarTitle({ title: decodeURIComponent(options.title) })
    }
  },

  onShareAppMessage() {
    return getDefaultShareData()
  },

  onShareTimeline() {
    return getDefaultTimelineData()
  }
})
