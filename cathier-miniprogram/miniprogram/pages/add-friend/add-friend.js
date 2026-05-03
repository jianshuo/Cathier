const { getDefaultTimelineData } = require('../../utils/share')

Page({
  data: {
    inviteCode: '',
    codeLoading: false,
    pendingCodes: []
  },

  onLoad() {
    this.generateCode()
    this.loadPendingCodes()
  },

  async generateCode() {
    this.setData({ codeLoading: true })
    try {
      const res = await wx.cloud.callFunction({
        name: 'friend-manage',
        data: { action: 'generateCode' }
      })
      const code = (res.result && res.result.code) || ''
      this.setData({ inviteCode: code, codeLoading: false })
    } catch (err) {
      console.error('Generate code failed:', err)
      this.setData({ codeLoading: false })
      wx.showToast({ title: '生成失败，请重试', icon: 'none' })
    }
  },

  onGenerateCode() {
    this.generateCode()
  },

  async loadPendingCodes() {
    try {
      const res = await wx.cloud.callFunction({
        name: 'friend-manage',
        data: { action: 'getMyPendingCodes' }
      })
      const codes = (res.result && res.result.codes) || []
      const now = new Date()
      const formatted = codes.map(c => {
        const expiry = new Date(c.expiresAt)
        const hoursLeft = Math.max(0, Math.round((expiry - now) / 3600000))
        return {
          code: c.code,
          expiryText: hoursLeft > 0 ? hoursLeft + '小时后过期' : '即将过期'
        }
      })
      this.setData({ pendingCodes: formatted })
    } catch (err) {
      console.error('Load pending codes failed:', err)
    }
  },

  onCopyCode() {
    if (!this.data.inviteCode) return
    wx.setClipboardData({
      data: this.data.inviteCode,
      success: () => wx.showToast({ title: '已复制', icon: 'success' })
    })
  },

  onShareAppMessage() {
    return {
      title: '我在「觉察」等你，一起来感受身体感受吧',
      path: '/pages/friends/friends?inviteCode=' + this.data.inviteCode
    }
  },

  onShareTimeline() {
    return getDefaultTimelineData({
      title: '我在「觉察」等你，一起来感受身体感受吧'
    })
  }
})
