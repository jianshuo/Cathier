const { getCheckIns, deleteCheckIn } = require('../../utils/cloud-db')

Page({
  data: {
    checkIns: [],
    loading: false,
    hasMore: true,
    page: 0,
    pageSize: 20
  },

  onLoad() {
  },

  onShow() {
    this.loadCheckIns(true)
  },

  onPullDownRefresh() {
    this.loadCheckIns(true)
  },

  onReachBottom() {
    if (this.data.hasMore && !this.data.loading) {
      this.loadCheckIns(false)
    }
  },

  loadCheckIns(refresh) {
    if (refresh) {
      this.setData({ page: 0, checkIns: [], hasMore: true })
    }
    this.setData({ loading: true })

    const page = this.data.page
    const pageSize = this.data.pageSize

    getCheckIns(page, pageSize).then(res => {
      const records = res.data || res || []

      // Format each record for display
      const formatted = records.map(r => {
        const date = r.date ? new Date(r.date) : (r.createdAt ? new Date(r.createdAt) : new Date())
        const dateFormatted = `${date.getMonth() + 1}月${date.getDate()}日 ${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`

        const emotionNames = (r.emotions || []).map(em => {
          if (typeof em === 'string') return em
          return em.emoji ? `${em.emoji} ${em.name}` : em.name
        })

        // Build body summary with sensations: "胸口(紧绷、沉重)、肩膀(僵硬)"
        const bs = r.bodySensations || {}
        const bodySummary = Object.keys(bs).map(part => {
          const sensations = bs[part]
          if (sensations && sensations.length > 0) {
            return `${part}(${sensations.join('、')})`
          }
          return part
        }).join('、')
        const feedbackPreview = (r.aiFeedback || '').substring(0, 50)

        return {
          _id: r._id,
          dateFormatted,
          emotions: emotionNames,
          bodySummary,
          intensity: r.intensity || 0,
          trigger: r.triggerEvent || r.trigger || '',
          feedbackPreview: feedbackPreview ? feedbackPreview + (r.aiFeedback && r.aiFeedback.length > 50 ? '...' : '') : '',
          category: emotionNames.length > 0 ? emotionNames[0] : ''
        }
      })

      const allCheckIns = refresh ? formatted : this.data.checkIns.concat(formatted)

      this.setData({
        checkIns: allCheckIns,
        loading: false,
        hasMore: records.length >= pageSize,
        page: page + 1
      })
      wx.stopPullDownRefresh()
    }).catch(err => {
      console.error('Failed to load check-ins:', err)
      this.setData({ loading: false })
      wx.stopPullDownRefresh()
    })
  },

  onCheckInTap(e) {
    const id = e.currentTarget.dataset.id
    // Could navigate to detail page in future
    console.log('Tapped check-in:', id)
  },

  onDeleteCheckIn(e) {
    const id = e.currentTarget.dataset.id
    wx.showModal({
      title: '确认删除',
      content: '删除后无法恢复，确定要删除这条记录吗？',
      confirmText: '删除',
      confirmColor: '#C75450',
      success: (res) => {
        if (res.confirm) {
          deleteCheckIn(id).then(() => {
            wx.showToast({ title: '已删除', icon: 'success' })
            this.loadCheckIns(true)
          }).catch(err => {
            console.error('Delete failed:', err)
            wx.showToast({ title: '删除失败', icon: 'none' })
          })
        }
      }
    })
  }
})
