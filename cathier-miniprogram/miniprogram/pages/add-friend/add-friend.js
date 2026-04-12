Page({
  data: {
    activeTab: 'my-code',  // 'my-code' | 'enter-code'
    myCode: '',
    myCodeLoading: false,
    inputCode: '',
    accepting: false
  },

  onLoad() {
    this.generateCode()
  },

  // --- Tab Toggle ---
  onSwitchTab(e) {
    const tab = e.currentTarget.dataset.tab
    this.setData({ activeTab: tab })
    if (tab === 'my-code' && !this.data.myCode) {
      this.generateCode()
    }
  },

  // --- Generate Code ---
  async generateCode() {
    this.setData({ myCodeLoading: true })
    try {
      const res = await wx.cloud.callFunction({
        name: 'friend-manage',
        data: { action: 'generateCode' }
      })
      const code = (res.result && res.result.code) || ''
      this.setData({ myCode: code, myCodeLoading: false })
    } catch (err) {
      console.error('Generate code failed:', err)
      this.setData({ myCodeLoading: false })
      wx.showToast({ title: '生成失败，请重试', icon: 'none' })
    }
  },

  // --- Copy Code ---
  onCopyCode() {
    if (!this.data.myCode) return
    wx.setClipboardData({
      data: this.data.myCode,
      success: () => {
        wx.showToast({ title: '已复制', icon: 'success' })
      }
    })
  },

  // --- Share via WeChat ---
  onShareCode() {
    // WeChat forward sharing is handled by onShareAppMessage
  },

  onShareAppMessage() {
    return {
      title: '我在觉察等你，一起来感受身体吧',
      path: '/pages/friends/friends?inviteCode=' + this.data.myCode
    }
  },

  // --- Enter Code ---
  onCodeInput(e) {
    const value = e.detail.value.toUpperCase().replace(/[^A-Z0-9]/g, '')
    this.setData({ inputCode: value })
  },

  async onAcceptInvite() {
    const code = this.data.inputCode.trim()
    if (code.length !== 6) {
      wx.showToast({ title: '请输入6位邀请码', icon: 'none' })
      return
    }

    this.setData({ accepting: true })
    try {
      const res = await wx.cloud.callFunction({
        name: 'friend-manage',
        data: { action: 'acceptInvite', code }
      })

      const result = res.result || {}
      if (result.success) {
        wx.showToast({ title: '添加成功', icon: 'success' })
        setTimeout(() => {
          wx.navigateBack()
        }, 1500)
      } else {
        wx.showToast({ title: result.message || '邀请码无效', icon: 'none' })
      }
    } catch (err) {
      console.error('Accept invite failed:', err)
      wx.showToast({ title: '操作失败，请重试', icon: 'none' })
    }
    this.setData({ accepting: false })
  }
})
