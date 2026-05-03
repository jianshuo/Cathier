const { saveLessonSummary } = require('../../utils/cloud-db')
const { getDefaultShareData, getDefaultTimelineData } = require('../../utils/share')

// Strip <options>...</options> and <complete/> from a string for display.
function stripDisplayMarkers(text) {
  return String(text || '')
    .replace(/<options>[\s\S]*?<\/options>/g, '')
    .replace(/<complete\/>/g, '')
    .trim()
}

// Parse <options><option>...</option></options> from an AI reply.
// Returns { mainText, options[] }.
function parseOptions(text) {
  const raw = String(text || '')
  const blockMatch = raw.match(/<options>([\s\S]*?)<\/options>/)
  if (!blockMatch) {
    return { mainText: raw.replace(/<complete\/>/g, '').trim(), options: [] }
  }
  const before = raw.slice(0, blockMatch.index)
  const after = raw.slice(blockMatch.index + blockMatch[0].length)
  const mainText = (before + '\n\n' + after).replace(/<complete\/>/g, '').trim()

  const options = []
  const optRegex = /<option>([\s\S]*?)<\/option>/g
  let m
  while ((m = optRegex.exec(blockMatch[1])) !== null) {
    const opt = m[1].trim()
    if (opt) options.push(opt)
  }
  return { mainText, options }
}

// Parse the 5-section training card. Returns array of { label, content }.
// Card format: "**Label：** content" lines.
function parseTrainingCard(raw) {
  const text = String(raw || '').trim()
  if (!text) return []
  const lines = text.split('\n').map(l => l.trim()).filter(Boolean)
  const items = []
  for (const line of lines) {
    const m = line.match(/^\*\*(.+?)[：:]\*\*\s*(.*)$/) || line.match(/^\*\*(.+?)\*\*[：:]\s*(.*)$/)
    if (m) {
      const label = m[1].replace(/[：:]$/, '').trim()
      const content = m[2].trim()
      if (label) items.push({ label, content })
    }
  }
  return items
}

Page({
  data: {
    // 'intro' → enter "the setback" → 'chat' (5 steps) → 'summary'
    phase: 'intro',
    triggerEvent: '',
    introError: '',

    // Chat state. Each visible message: { role, displayContent, options[], id }
    messages: [],
    inputText: '',
    sendable: false,
    loading: false,
    scrollToMsg: '',

    // Step counter — number of user answers (excluding initial context).
    userStep: 0,

    // Summary state
    isGeneratingSummary: false,
    summaryItems: [],
    summaryRaw: '',
    summaryError: '',
    saved: false
  },

  onLoad() {
  },

  // --- Intro phase ---

  onTriggerInput(e) {
    this.setData({ triggerEvent: e.detail.value, introError: '' })
  },

  onStartChat() {
    const trigger = (this.data.triggerEvent || '').trim()
    if (!trigger) {
      this.setData({ introError: '请用一句话描述这次的「堑」' })
      return
    }
    this.setData({ phase: 'chat' })
    this._sendInitialContext(trigger)
  },

  // --- Chat phase ---

  onInput(e) {
    const val = e.detail.value || ''
    this.setData({ inputText: val, sendable: val.trim().length > 0 })
  },

  onSend() {
    const text = this.data.inputText.trim()
    if (!text || this.data.loading) return
    this.setData({ inputText: '', sendable: false })
    this._sendUserMessage(text)
  },

  onTapOption(e) {
    if (this.data.loading) return
    const option = e.currentTarget.dataset.option
    if (!option) return
    this._sendUserMessage(option)
  },

  // Build initial hidden context message and request first AI question.
  async _sendInitialContext(trigger) {
    const initId = 'init-' + Date.now()
    // Hidden context message: not displayed but sent as user message #0.
    this._initialContext = `触发事件：${trigger}`

    this.setData({ loading: true, scrollToMsg: initId })
    try {
      const apiHistory = [
        { role: 'user', content: this._initialContext }
      ]
      const result = await wx.cloud.callFunction({
        name: 'ai-proxy',
        data: { type: 'lesson-chat', history: apiHistory },
        timeout: 30000
      })
      const reply = (result.result && result.result.feedback) || ''
      this._appendAIMessage(reply)
    } catch (err) {
      console.error('Lesson chat init error:', err)
      this._appendAIMessage('连接失败，请稍后重试。')
    }
    this.setData({ loading: false })
  },

  async _sendUserMessage(text) {
    const userStep = this.data.userStep + 1
    const userMsg = {
      id: 'u' + Date.now(),
      role: 'user',
      displayContent: text,
      // API content prepends step annotation so the AI can enforce step progression.
      apiContent: `（第 ${userStep} 步回答）${text}`,
      options: []
    }

    const newMessages = this.data.messages.concat([userMsg])
    this.setData({
      messages: newMessages,
      userStep,
      loading: true,
      scrollToMsg: userMsg.id
    })

    // Build API history: initial hidden context + visible messages (using apiContent for users).
    const apiHistory = [{ role: 'user', content: this._initialContext || '' }]
    for (const m of newMessages) {
      apiHistory.push({
        role: m.role === 'user' ? 'user' : 'assistant',
        // For assistant messages we send the original content (with <options>/<complete/>) so the AI sees its own state.
        content: m.role === 'user' ? m.apiContent : m.rawContent
      })
    }

    try {
      const result = await wx.cloud.callFunction({
        name: 'ai-proxy',
        data: { type: 'lesson-chat', history: apiHistory },
        timeout: 30000
      })
      const reply = (result.result && result.result.feedback) || '我在听，请继续。'
      const isComplete = reply.indexOf('<complete/>') !== -1
      this._appendAIMessage(reply)
      if (isComplete) {
        this._enterSummary()
      }
    } catch (err) {
      console.error('Lesson chat error:', err)
      this._appendAIMessage('连接失败，请稍后重试。')
    }
    this.setData({ loading: false })
  },

  _appendAIMessage(reply) {
    const parsed = parseOptions(reply)
    const aiMsg = {
      id: 'a' + Date.now(),
      role: 'ai',
      displayContent: parsed.mainText,
      rawContent: reply,
      options: parsed.options
    }
    this.setData({
      messages: this.data.messages.concat([aiMsg]),
      scrollToMsg: aiMsg.id
    })
  },

  // --- Summary phase ---

  _enterSummary() {
    this.setData({ phase: 'summary', isGeneratingSummary: true, summaryError: '' })
    this._generateSummary()
  },

  async _generateSummary() {
    // Build clean history: initial context + user displayContent + assistant rawContent (cleaned in cloud).
    const history = [{ role: 'user', content: this._initialContext || '' }]
    for (const m of this.data.messages) {
      history.push({
        role: m.role === 'user' ? 'user' : 'assistant',
        content: m.role === 'user' ? m.displayContent : m.rawContent
      })
    }

    try {
      const result = await wx.cloud.callFunction({
        name: 'ai-proxy',
        data: { type: 'lesson-summary', history },
        timeout: 30000
      })
      const raw = (result.result && result.result.feedback) || ''
      const items = parseTrainingCard(raw)
      this.setData({
        isGeneratingSummary: false,
        summaryRaw: raw,
        summaryItems: items
      })
    } catch (err) {
      console.error('Lesson summary error:', err)
      this.setData({
        isGeneratingSummary: false,
        summaryError: '生成失败，请重试'
      })
    }
  },

  onRetrySummary() {
    if (this.data.isGeneratingSummary) return
    this.setData({ isGeneratingSummary: true, summaryError: '' })
    this._generateSummary()
  },

  async onSave() {
    if (this.data.saved) return
    const items = this.data.summaryItems
    if (!items || items.length === 0) {
      wx.showToast({ title: '总结尚未生成', icon: 'none' })
      return
    }
    // Persist in the same shape the existing storage expects: array of strings.
    const stringItems = items.map(it => it.label + '：' + it.content)
    try {
      await saveLessonSummary({
        items: stringItems,
        conversationLength: this.data.userStep,
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
