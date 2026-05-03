const app = getApp()
const { getDefaultShareData, getDefaultTimelineData } = require('../../utils/share')

Page({
  data: {
    bodyScanData: null,
    categories: [],          // from emotions.json
    selectedCategoryId: '',
    selectedCategoryName: '',
    specificEmotions: [],    // emotions for selected category (with emoji, definition, etc.)
    selectedEmotions: [],    // array of { id, name, emoji, categoryName }
    selectedEmotionIds: [],  // flat array of ids for template indexOf checks
    trigger: '',
    note: '',
    showPopover: false,
    popoverEmotion: null,    // full emotion object
    popoverDiffers: []       // array of { name, diff } for similar emotions
  },

  onLoad(options) {
    // Parse body scan data from URL
    if (options.bodyScan) {
      try {
        const bodyScanData = JSON.parse(decodeURIComponent(options.bodyScan))
        this.setData({ bodyScanData })
      } catch (e) {
        console.error('Failed to parse body scan data', e)
      }
    }

    // Load categories from emotions.json
    const emotions = app.globalData.emotions
    if (emotions && emotions.categories) {
      this.setData({
        categories: emotions.categories
      })
    }
  },

  onSelectCategory(e) {
    const catId = e.currentTarget.dataset.id
    const cat = this.data.categories.find(c => c.id === catId)
    if (!cat) return

    this.setData({
      selectedCategoryId: catId,
      selectedCategoryName: cat.name,
      specificEmotions: cat.emotions || []
    })
  },

  onToggleEmotion(e) {
    const emotionId = e.currentTarget.dataset.id
    const emotionName = e.currentTarget.dataset.name
    const emotionEmoji = e.currentTarget.dataset.emoji
    const selected = this.data.selectedEmotions.slice()
    const idx = selected.findIndex(em => em.id === emotionId)

    if (idx >= 0) {
      selected.splice(idx, 1)
    } else {
      selected.push({
        id: emotionId,
        name: emotionName,
        emoji: emotionEmoji,
        categoryName: this.data.selectedCategoryName
      })
    }
    this.setData({
      selectedEmotions: selected,
      selectedEmotionIds: selected.map(em => em.id)
    })
  },

  isEmotionSelected(emotionId) {
    return this.data.selectedEmotions.some(em => em.id === emotionId)
  },

  onTriggerInput(e) {
    this.setData({ trigger: e.detail.value })
  },

  onNoteInput(e) {
    this.setData({ note: e.detail.value })
  },

  onEmotionLongPress(e) {
    const emotionId = e.currentTarget.dataset.id
    // Find the full emotion object from specificEmotions (current category)
    let emotion = this.data.specificEmotions.find(em => em.id === emotionId)
    if (!emotion) {
      // Also search all categories in case it was selected from a different category
      const categories = this.data.categories
      for (let i = 0; i < categories.length; i++) {
        emotion = (categories[i].emotions || []).find(em => em.id === emotionId)
        if (emotion) break
      }
    }
    if (!emotion) return

    // Build differs list from the differs object
    const differs = emotion.differs || {}
    const popoverDiffers = Object.keys(differs).map(name => ({
      name,
      diff: differs[name]
    }))

    this.setData({
      showPopover: true,
      popoverEmotion: emotion,
      popoverDiffers
    })
  },

  onClosePopover() {
    this.setData({ showPopover: false })
  },

  onGoToDictionary() {
    this.setData({ showPopover: false })
    wx.navigateTo({
      url: '/pages/dictionary/dictionary'
    })
  },

  onNext() {
    if (this.data.selectedEmotions.length === 0) {
      wx.showToast({ title: '请选择至少一个情绪', icon: 'none' })
      return
    }
    const params = encodeURIComponent(JSON.stringify({
      bodySensations: this.data.bodyScanData ? this.data.bodyScanData.bodySensations : {},
      intensity: this.data.bodyScanData ? this.data.bodyScanData.intensity : 5,
      emotions: this.data.selectedEmotions,
      trigger: this.data.trigger,
      note: this.data.note
    }))
    wx.navigateTo({
      url: '/pages/ai-feedback/ai-feedback?checkIn=' + params
    })
  },

  onShareAppMessage() {
    return getDefaultShareData({
      title: '为情绪命名，是觉察的开始'
    })
  },

  onShareTimeline() {
    return getDefaultTimelineData()
  }
})
