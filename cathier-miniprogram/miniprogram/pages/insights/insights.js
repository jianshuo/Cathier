const { getCheckIns, saveInsight, getInsights, getCheckInCount } = require('../../utils/cloud-db')

const FOCUS_MODES = [
  { key: 'stress', label: '压力触发', instruction: '关注什么情境、时间、人物反复触发负面情绪' },
  { key: 'growth', label: '成长', instruction: '关注积极变化、情绪调节进步、新的觉察' },
  { key: 'body', label: '身体信号', instruction: '关注身体感受与情绪的对应关系、身体部位的重复信号' },
  { key: 'random', label: '随机探索', instruction: '自由分析，找出最令你意外的模式' }
]

Page({
  data: {
    focusModes: FOCUS_MODES,
    selectedMode: 0,
    checkInCount: 0,
    unlocked: false,
    loading: false,
    analyzing: false,
    narrative: '',
    hasResult: false,
    history: [],
    historyLoading: true
  },

  onLoad() {
    this.loadCheckInCount()
    this.loadHistory()
  },

  onShow() {
    this.loadCheckInCount()
    this.loadHistory()
  },

  async loadCheckInCount() {
    try {
      const count = await getCheckInCount()
      this.setData({
        checkInCount: count,
        unlocked: count >= 7
      })
    } catch (err) {
      console.error('Failed to load check-in count:', err)
    }
  },

  async loadHistory() {
    this.setData({ historyLoading: true })
    try {
      const history = await getInsights()
      const formatted = history.map(item => {
        const d = item.date ? new Date(item.date) : (item.createdAt ? new Date(item.createdAt) : new Date())
        const dateStr = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
        const modeObj = FOCUS_MODES.find(m => m.key === item.focusMode)
        return {
          _id: item._id,
          dateStr,
          focusModeLabel: modeObj ? modeObj.label : item.focusMode,
          checkInCount: item.checkInCount || 0,
          narrative: item.narrative || '',
          narrativePreview: (item.narrative || '').substring(0, 80) + ((item.narrative || '').length > 80 ? '...' : ''),
          expanded: false
        }
      })
      this.setData({ history: formatted, historyLoading: false })
    } catch (err) {
      console.error('Failed to load insights history:', err)
      this.setData({ historyLoading: false })
    }
  },

  onSelectMode(e) {
    const idx = e.currentTarget.dataset.index
    this.setData({ selectedMode: idx })
  },

  async onStartAnalysis() {
    if (this.data.analyzing) return
    if (!this.data.unlocked) return

    this.setData({ analyzing: true, narrative: '', hasResult: false })

    try {
      // Load last 30 check-ins
      const res = await getCheckIns(0, 30)
      const checkIns = res.data || res || []

      if (checkIns.length < 7) {
        this.setData({ analyzing: false })
        wx.showToast({ title: '记录不足，请继续觉察', icon: 'none' })
        return
      }

      // Format check-ins for the prompt
      const formatted = checkIns.map(r => {
        const date = r.date ? new Date(r.date) : new Date()
        const dateStr = `${date.getMonth() + 1}/${date.getDate()}`

        const bodyParts = Object.keys(r.bodySensations || {}).map(part => {
          const sensations = (r.bodySensations[part] || []).join('、')
          return sensations ? `${part}(${sensations})` : part
        }).join('、')

        const emotions = (r.emotions || []).map(em => em.name || em).join('、')
        const trigger = r.triggerEvent || r.trigger || ''
        const intensity = r.intensity || 0

        return `[${dateStr}] 强度:${intensity} | 部位:${bodyParts || '无'} | 情绪:${emotions || '无'} | 触发:${trigger || '无'}`
      }).join('\n')

      const mode = FOCUS_MODES[this.data.selectedMode]

      const result = await wx.cloud.callFunction({
        name: 'ai-proxy',
        data: {
          type: 'pattern-insights',
          systemPrompt: `你是一名情绪模式分析师。请根据以下${mode.label}视角分析用户最近的情绪觉察记录，找出3-5个有意义的模式。每个模式用2-3句话描述。${mode.instruction}`,
          userPrompt: `以下是用户最近${checkIns.length}条情绪觉察记录：\n\n${formatted}\n\n请分析这些记录中的模式。`,
          checkInCount: checkIns.length
        },
        timeout: 60000
      })

      const narrative = (result.result && (result.result.feedback || result.result.narrative || result.result.content)) || '暂时无法生成分析，请稍后再试。'

      this.setData({
        analyzing: false,
        narrative,
        hasResult: true
      })

      // Save insight to DB
      await saveInsight({
        focusMode: mode.key,
        narrative,
        checkInCount: checkIns.length
      })

      // Refresh history
      this.loadHistory()
    } catch (err) {
      console.error('Pattern analysis failed:', err)
      this.setData({ analyzing: false })
      wx.showToast({ title: 'AI分析失败，请稍后重试', icon: 'none' })
    }
  },

  onToggleHistory(e) {
    const idx = e.currentTarget.dataset.index
    const key = `history[${idx}].expanded`
    this.setData({
      [key]: !this.data.history[idx].expanded
    })
  }
})
