Page({
  data: {
    loading: true,
    friends: [],
    pendingInvites: []
  },

  onLoad() {
    this.loadData()
  },

  onShow() {
    this.loadData()
  },

  async loadData() {
    this.setData({ loading: true })
    try {
      const res = await wx.cloud.callFunction({
        name: 'friend-manage',
        data: { action: 'getFriendList' }
      })
      const result = res.result || {}
      const friends = (result.friends || []).map(f => {
        const date = f.createdAt ? new Date(f.createdAt) : new Date()
        return {
          ...f,
          dateFormatted: (date.getMonth() + 1) + '月' + date.getDate() + '日添加'
        }
      })
      const pendingInvites = (result.pendingInvites || []).map(inv => {
        const expires = inv.expiresAt ? new Date(inv.expiresAt) : null
        let expiryText = ''
        if (expires) {
          const now = new Date()
          const diffHours = Math.max(0, Math.floor((expires - now) / 3600000))
          expiryText = diffHours > 0 ? diffHours + '小时后过期' : '已过期'
        }
        return { ...inv, expiryText }
      })
      this.setData({ friends, pendingInvites, loading: false })
    } catch (err) {
      console.error('Load friend list failed:', err)
      this.setData({ loading: false })
      wx.showToast({ title: '加载失败', icon: 'none' })
    }
  },

  onRemoveFriend(e) {
    const { friendshipId, name } = e.currentTarget.dataset
    wx.showModal({
      title: '移除好友',
      content: '确定要移除 ' + name + ' 吗？移除后将无法看到对方的觉察记录。',
      confirmText: '移除',
      confirmColor: '#C75450',
      success: async (res) => {
        if (res.confirm) {
          try {
            await wx.cloud.callFunction({
              name: 'friend-manage',
              data: { action: 'removeFriend', friendshipId }
            })
            wx.showToast({ title: '已移除', icon: 'success' })
            this.loadData()
          } catch (err) {
            console.error('Remove friend failed:', err)
            wx.showToast({ title: '操作失败', icon: 'none' })
          }
        }
      }
    })
  },

  onAddFriend() {
    wx.navigateTo({ url: '/pages/add-friend/add-friend' })
  }
})
