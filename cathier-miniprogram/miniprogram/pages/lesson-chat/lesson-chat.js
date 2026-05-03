const { saveLessonSummary } = require('../../utils/cloud-db')
const { getDefaultShareData, getDefaultTimelineData } = require('../../utils/share')

const INITIAL_MESSAGE = '最近有什么让你感触深刻的经历、挫折或遗憾吗？不妨从那里开始聊聊。'

Page({
  data: {
    messages: [],
    inputText: '',
    loading: false,
    canSummarize: false,
    showSummary: false,
    summaryItems: [],
    saved: false,
    sendable: false,
    scrollToMsg: ''
  },

  onLoad() {
    this.setData({
      messages: [
        { role: 'ai', content: INITIAL_MESSAGE, id: 'init' }
      ]
    })
  },

  onInput(e) {
    const val = e.detail.value || ''
    this.setData({ inputText: val, sendable: val.trim().length > 0 })
  },

  async onSend() {
    const text = this.data.inputText.trim()
    if (!text || this.data.loading) return

    const userMsg = { role: 'user', content: text, id: 'u' + Date.now() }
    const newMessages = [...this.data.messages, userMsg]
    const userTurnCount = newMessages.filter(m => m.role === 'user').length

    this.setData({
      messages: newMessages,
      inputText: '',
      sendable: false,
      loading: true,
      scrollToMsg: userMsg.id
    })

    try {
      const history = newMessages.map(m => ({
        role: m.role === 'ai' ? 'assistant' : 'user',
        content: m.content
      }))

      const result = await wx.cloud.callFunction({
        name: 'ai-proxy',
        data: { type: 'lesson-chat', history, turnCount: userTurnCount },
        timeout: 30000
      })

      const reply = (result.result && result.result.feedback) || '我在听，请继续分享。'
      const aiMsg = { role: 'ai', content: reply, id: 'a' + Date.now() }

      this.setData({
        messages: [...this.data.messages, aiMsg],
        loading: false,
        canSummarize: userTurnCount >= 3,
        scrollToMsg: aiMsg.id
      })
    } catch (err) {
      console.error('Lesson chat error:', err)
      const errMsg = { role: 'ai', content: '连接失败，请稍后重试。', id: 'a' + Date.now() }
      this.setData({ messages: [...this.data.messages, errMsg], loading: false })
    }
  },

  async onSummarize() {
    if (this.data.loading) return
    this.setData({ loading: true })

    const history = this.data.messages.map(m => ({
      role: m.role === 'ai' ? 'assistant' : 'user',
      content: m.content
    }))

    try {
      const result = await wx.cloud.callFunction({
        name: 'ai-proxy',
        data: { type: 'lesson-summary', history },
        timeout: 30000
      })

      const raw = (result.result && result.result.feedback) || ''
      const items = this._parseSummaryItems(raw)

      this.setData({ loading: false, showSummary: true, summaryItems: items })
    } catch (err) {
      console.error('Lesson summary error:', err)
      this.setData({ loading: false })
      wx.showToast({ title: '生成失败，请重试', icon: 'none' })
    }
  },

  _parseSummaryItems(text) {
    const lines = text.split('\n').filter(l => l.trim())
    const items = []
    for (const line of lines) {
      const cleaned = line.replace(/^[\d]+[.、。\)\s]+/, '').trim()
      if (cleaned.length > 5) items.push(cleaned)
    }
    return items.slice(0, 7)
  },

  async onSave() {
    if (this.data.saved) return

    try {
      await saveLessonSummary({
        items: this.data.summaryItems,
        conversationLength: this.data.messages.filter(m => m.role === 'user').length,
        date: new Date()
      })
      this.setData({ saved: true })
      wx.showToast({ title: '已记录', icon: 'success' })
      setTimeout(() => wx.navigateBack(), 1200)
    } catch (err) {
      console.error('Save lesson summary error:', err)
      wx.showToast({ title: '保存失败，请重试', icon: 'none' })
    }
  },

  onBack() {
    wx.navigateBack()
  },

  onShareAppMessage() {
    return getDefaultShareData({
      title: '吃一堑，长一智 — 把经历变成智慧'
    })
  },

  onShareTimeline() {
    return getDefaultTimelineData({
      title: '吃一堑，长一智 — 把经历变成智慧'
    })
  }
})
