const { saveDailyJournal, getTodayJournal } = require('../../utils/cloud-db')

Page({
  data: {
    moods: [
      { emoji: '\uD83D\uDE04', label: '很开心', value: 'veryHappy' },
      { emoji: '\uD83D\uDE0A', label: '不错', value: 'good' },
      { emoji: '\uD83D\uDE10', label: '还好', value: 'okay' },
      { emoji: '\uD83D\uDE14', label: '不太好', value: 'notGreat' },
      { emoji: '\uD83D\uDE22', label: '很难过', value: 'bad' }
    ],
    selectedMood: '',
    gains: '',
    saving: false,
    isEdit: false,
    existingId: null
  },

  onLoad() {
    this.loadTodayJournal()
  },

  async loadTodayJournal() {
    try {
      const journal = await getTodayJournal()
      if (journal) {
        this.setData({
          selectedMood: journal.mood || '',
          gains: journal.gains || '',
          isEdit: true,
          existingId: journal._id
        })
      }
    } catch (err) {
      console.error('Failed to load today journal:', err)
    }
  },

  onSelectMood(e) {
    const value = e.currentTarget.dataset.value
    this.setData({ selectedMood: value })
  },

  onGainsInput(e) {
    this.setData({ gains: e.detail.value })
  },

  async onSave() {
    const { selectedMood, gains } = this.data

    if (!selectedMood) {
      wx.showToast({ title: '请选择今天的心情', icon: 'none' })
      return
    }

    if (!gains.trim()) {
      wx.showToast({ title: '请写下今日收获', icon: 'none' })
      return
    }

    this.setData({ saving: true })

    try {
      await saveDailyJournal({
        mood: selectedMood,
        gains: gains.trim(),
        existingId: this.data.existingId
      })

      wx.showToast({ title: this.data.isEdit ? '已更新' : '已保存', icon: 'success' })

      setTimeout(() => {
        wx.navigateBack()
      }, 1000)
    } catch (err) {
      console.error('Save journal failed:', err)
      wx.showToast({ title: '保存失败，请重试', icon: 'none' })
    } finally {
      this.setData({ saving: false })
    }
  }
})
