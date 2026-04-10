const { getCheckIns, deleteCheckIn } = require('../../utils/cloud-db')

const CATEGORY_COLORS = {
  '激情': '#FF5933',
  '快乐': '#FFBF00',
  '平静': '#33ADE6',
  '爱与关怀': '#F272A5',
  '愤怒': '#F54538',
  '恐惧': '#AD52DE',
  '悲伤': '#5C8ABF',
  '羞愧': '#8C6647',
  '惊讶': '#FF9400'
}

function getIntensityInfo(intensity) {
  if (intensity <= 0) return { color: '', label: '' }
  if (intensity <= 3) return { color: '#FFBF00', label: '轻微' }
  if (intensity <= 6) return { color: '#F2700A', label: '中等' }
  if (intensity <= 8) return { color: '#D96308', label: '较强' }
  return { color: '#F54538', label: '强烈' }
}

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

        const emotions = (r.emotions || []).map(em => {
          if (typeof em === 'string') return { label: em, emoji: '', categoryColor: '' }
          const catColor = CATEGORY_COLORS[em.categoryName] || ''
          return {
            label: em.name || em.label || '',
            emoji: em.emoji || '',
            categoryColor: catColor
          }
        })

        // Build body groups for per-line display
        const bs = r.bodySensations || {}
        const bodyGroups = Object.keys(bs).map(part => {
          const sns = bs[part] || []
          return { part, sensations: sns, sensationsText: sns.join('、') }
        })
        const bodySummary = bodyGroups.length > 0 ? 'has_body' : ''

        // Intensity color coding
        const intensityInfo = getIntensityInfo(r.intensity || 0)

        const feedbackPreview = (r.aiFeedback || '').substring(0, 50)

        return {
          _id: r._id,
          dateFormatted,
          emotions,
          bodyGroups,
          bodySummary,
          intensity: r.intensity || 0,
          intensityColor: intensityInfo.color,
          intensityLabel: intensityInfo.label,
          trigger: r.triggerEvent || r.trigger || '',
          feedbackPreview: feedbackPreview ? feedbackPreview + (r.aiFeedback && r.aiFeedback.length > 50 ? '...' : '') : ''
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

  onOpenInsights() {
    wx.navigateTo({ url: '/pages/insights/insights' })
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
