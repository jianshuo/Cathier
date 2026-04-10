Page({
  data: {
    feedbackText: '',
    submitting: false
  },

  onInput(e) {
    this.setData({ feedbackText: e.detail.value })
  },

  onSubmit() {
    const text = this.data.feedbackText.trim()
    if (!text) return

    this.setData({ submitting: true })

    wx.cloud.callFunction({
      name: 'ai-proxy',
      data: { ping: true }
    }).catch(() => {})

    // Save feedback to cloud database
    const db = wx.cloud.database()
    db.collection('feedback').add({
      data: {
        content: text,
        createdAt: new Date(),
        platform: 'miniprogram',
        version: '1.8'
      }
    }).then(() => {
      wx.showToast({ title: '感谢反馈', icon: 'success' })
      setTimeout(() => wx.navigateBack(), 1200)
    }).catch(() => {
      // Fallback: still thank the user
      wx.showToast({ title: '感谢反馈', icon: 'success' })
      setTimeout(() => wx.navigateBack(), 1200)
    }).finally(() => {
      this.setData({ submitting: false })
    })
  }
})
