const app = getApp()
const { getDefaultShareData, getDefaultTimelineData } = require('../../utils/share')

Page({
  data: {
    bodyParts: [],
    sensationsMap: {},       // { bodyPart: [sensation, ...] }
    selectedParts: [],       // array of selected body part names
    focusedPart: '',         // currently focused body part (shows its sensations)
    currentSensations: [],   // sensations for the focused body part
    bodySensations: {},      // { "胸口": ["紧绷","沉重"], "肩膀": ["僵硬"] }
    selectedPartsDetail: [], // [{ name: "胸口", sensations: ["紧绷","沉重"] }] for template rendering
    focusedPartSensations: [], // sensations selected for the focused body part
    intensity: 5
  },

  onLoad() {
    let emotions = app.globalData.emotions
    if (!emotions) {
      // Fallback: load directly if globalData not ready
      try {
        emotions = require('../../data/emotions.js')
        app.globalData.emotions = emotions
      } catch (e) {
        console.error('Failed to load emotions.json', e)
      }
    }
    if (emotions) {
      this.setData({
        bodyParts: emotions.bodyParts || [],
        sensationsMap: emotions.sensations || {}
      })
    }
    console.log('bodyParts loaded:', this.data.bodyParts.length)
  },

  onTogglePart(e) {
    const part = e.currentTarget.dataset.item
    const selected = this.data.selectedParts.slice()
    const bodySensations = Object.assign({}, this.data.bodySensations)
    const idx = selected.indexOf(part)

    if (idx >= 0) {
      // Deselect: remove from selected and clear its sensations
      selected.splice(idx, 1)
      delete bodySensations[part]
    } else {
      // Select: add to selected, init empty sensations
      selected.push(part)
      if (!bodySensations[part]) {
        bodySensations[part] = []
      }
    }

    // Focus on the tapped part (show its sensations)
    const focusedPart = selected.indexOf(part) >= 0 ? part : (selected.length > 0 ? selected[selected.length - 1] : '')
    const currentSensations = focusedPart ? (this.data.sensationsMap[focusedPart] || []) : []

    this.setData({
      selectedParts: selected,
      bodySensations,
      focusedPart,
      currentSensations
    })
    this._updateDetailArrays(selected, bodySensations, focusedPart)
  },

  onFocusPart(e) {
    const part = e.currentTarget.dataset.item
    if (this.data.selectedParts.indexOf(part) < 0) return
    const currentSensations = this.data.sensationsMap[part] || []
    this.setData({
      focusedPart: part,
      currentSensations,
      focusedPartSensations: this.data.bodySensations[part] || []
    })
  },

  onToggleSensation(e) {
    const sensation = e.currentTarget.dataset.item
    const part = this.data.focusedPart
    if (!part) return

    const bodySensations = Object.assign({}, this.data.bodySensations)
    const partSensations = (bodySensations[part] || []).slice()
    const idx = partSensations.indexOf(sensation)

    if (idx >= 0) {
      partSensations.splice(idx, 1)
    } else {
      partSensations.push(sensation)
    }
    bodySensations[part] = partSensations

    this.setData({ bodySensations, focusedPartSensations: partSensations })
    this._updateDetailArrays(this.data.selectedParts, bodySensations, part)
  },

  _updateDetailArrays(selectedParts, bodySensations, focusedPart) {
    const selectedPartsDetail = selectedParts.map(name => ({
      name,
      sensations: bodySensations[name] || [],
      isFocused: name === focusedPart
    }))
    this.setData({ selectedPartsDetail })
  },

  onIntensityChange(e) {
    this.setData({ intensity: e.detail.value })
  },

  onNext() {
    if (this.data.selectedParts.length === 0) {
      wx.showToast({ title: '请选择至少一个身体部位', icon: 'none' })
      return
    }
    const params = encodeURIComponent(JSON.stringify({
      bodySensations: this.data.bodySensations,
      intensity: this.data.intensity
    }))
    wx.navigateTo({
      url: '/pages/emotion-label/emotion-label?bodyScan=' + params
    })
  },

  onShareAppMessage() {
    return getDefaultShareData({
      title: '从身体感受开始，一次安静的情绪觉察'
    })
  },

  onShareTimeline() {
    return getDefaultTimelineData()
  }
})
