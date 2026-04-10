const { getCheckIn, deleteCheckIn } = require('../../utils/cloud-db')

// Emotion category color map (matches iOS)
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

function intensityColor(val) {
  if (val <= 3) return '#FFBF00'
  if (val <= 6) return '#F2700A'
  if (val <= 8) return '#D96308'
  return '#F54538'
}

function intensityLabel(val) {
  if (val <= 3) return '轻微'
  if (val <= 6) return '中等'
  if (val <= 8) return '较强'
  return '强烈'
}

function formatDate(date) {
  const d = new Date(date)
  const year = d.getFullYear()
  const month = d.getMonth() + 1
  const day = d.getDate()
  const hours = String(d.getHours()).padStart(2, '0')
  const minutes = String(d.getMinutes()).padStart(2, '0')

  const weekdays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六']
  const weekday = weekdays[d.getDay()]

  return `${year}年${month}月${day}日 ${weekday} ${hours}:${minutes}`
}

Page({
  data: {
    loading: true,
    checkIn: null,
    dateStr: '',
    intensityColor: '',
    intensityBg: '',
    intensityLabel: '',
    bodyParts: [],      // [{ name, sensations }]
    emotions: [],       // [{ name, emoji, color, bgColor }]
    triggerEvent: '',
    aiFeedback: '',
    note: ''
  },

  onLoad(options) {
    if (!options.id) {
      wx.showToast({ title: '记录不存在', icon: 'none' })
      setTimeout(() => wx.navigateBack(), 1500)
      return
    }
    this.checkInId = options.id
    this.loadDetail()
  },

  async loadDetail() {
    try {
      const record = await getCheckIn(this.checkInId)
      if (!record) {
        wx.showToast({ title: '记录不存在', icon: 'none' })
        setTimeout(() => wx.navigateBack(), 1500)
        return
      }

      const date = record.date ? new Date(record.date) : new Date(record.createdAt)
      const dateStr = formatDate(date)

      const color = intensityColor(record.intensity || 0)
      const label = intensityLabel(record.intensity || 0)
      // Light background: color at 15% opacity
      const bgColor = color + '26'

      // Format body parts
      const bs = record.bodySensations || {}
      const bodyParts = Object.keys(bs).map(part => ({
        name: part,
        sensations: bs[part] || []
      }))

      // Format emotions with category colors
      const emotions = (record.emotions || []).map(em => {
        const catColor = CATEGORY_COLORS[em.categoryName] || '#F2700A'
        return {
          name: em.name || '',
          emoji: em.emoji || '',
          color: catColor,
          bgColor: catColor + '1A'
        }
      })

      this.setData({
        loading: false,
        checkIn: record,
        dateStr,
        intensityColor: color,
        intensityBg: bgColor,
        intensityLabel: label,
        bodyParts,
        emotions,
        triggerEvent: record.triggerEvent || '',
        aiFeedback: record.aiFeedback || '',
        note: record.note || ''
      })
    } catch (err) {
      console.error('Failed to load check-in detail:', err)
      wx.showToast({ title: '加载失败', icon: 'none' })
      this.setData({ loading: false })
    }
  },

  onDelete() {
    wx.showModal({
      title: '删除记录',
      content: '确定要删除这条觉察记录吗？此操作不可撤销。',
      confirmText: '删除',
      confirmColor: '#C4614A',
      cancelText: '取消',
      success: async (res) => {
        if (res.confirm) {
          const result = await deleteCheckIn(this.checkInId)
          if (result.success) {
            wx.showToast({ title: '已删除', icon: 'success' })
            setTimeout(() => wx.navigateBack(), 800)
          } else {
            wx.showToast({ title: '删除失败', icon: 'none' })
          }
        }
      }
    })
  }
})
