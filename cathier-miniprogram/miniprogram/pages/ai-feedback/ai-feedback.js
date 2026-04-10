const { saveCheckIn, incrementCheckInCount } = require('../../utils/cloud-db')
const { addToBuffer } = require('../../utils/local-buffer')
const { requestReminder } = require('../../utils/subscribe')

Page({
  data: {
    checkInData: null,
    loading: true,
    feedback: '',
    saved: false,
    error: false,
    errorMessage: ''
  },

  onLoad(options) {
    if (options.checkIn) {
      try {
        const checkInData = JSON.parse(decodeURIComponent(options.checkIn))
        // Convert bodySensations object to array for template rendering
        const bodySensationsList = Object.keys(checkInData.bodySensations || {}).map(part => ({
          part,
          sensations: checkInData.bodySensations[part] || []
        }))
        checkInData.bodySensationsList = bodySensationsList
        this.setData({ checkInData })
        this.requestAIFeedback(checkInData)
      } catch (e) {
        console.error('Failed to parse check-in data', e)
        this.setData({ loading: false, error: true, errorMessage: '数据解析失败' })
      }
    }
  },

  requestAIFeedback(data) {
    this.setData({ loading: true, error: false })

    const emotionNames = (data.emotions || []).map(em => em.name || em).join('、')
    const bodyDesc = Object.keys(data.bodySensations || {}).map(part => {
      const sensations = data.bodySensations[part]
      return sensations && sensations.length > 0 ? `${part}：${sensations.join('、')}` : part
    }).join('；')

    wx.cloud.callFunction({
      name: 'ai-proxy',
      data: {
        bodySensations: data.bodySensations || {},
        emotions: data.emotions || [],
        emotionNames,
        bodyDescription: bodyDesc,
        intensity: data.intensity || 5,
        triggerEvent: data.trigger || '',
        note: data.note || ''
      },
      timeout: 30000
    }).then(res => {
      console.log('AI proxy result:', JSON.stringify(res.result))
      const result = res.result || {}
      if (result.error) {
        console.error('AI proxy error:', result.error)
      }
      const feedback = result.feedback || '你注意到了身体的感觉，这本身就是一种觉察的练习。'
      this.setData({ loading: false, feedback })
    }).catch(err => {
      console.error('AI feedback error:', err)
      this.setData({
        loading: false,
        error: true,
        errorMessage: '本次AI连接超时，您的觉察已保存。可稍后重试。'
      })
    })
  },

  onSave() {
    if (this.data.saved) return
    const data = this.data.checkInData
    if (!data) return

    const record = {
      date: new Date(),
      bodySensations: data.bodySensations || {},
      emotions: data.emotions || [],
      intensity: data.intensity || 5,
      triggerEvent: data.trigger || '',
      note: data.note || '',
      aiFeedback: this.data.feedback || '',
      shareLevel: null
    }

    this.setData({ saved: true })

    // Request reminder FIRST (must be in user tap context)
    requestReminder()

    const navigateHome = () => {
      setTimeout(() => {
        wx.switchTab({ url: '/pages/today/today' })
      }, 500)
    }

    saveCheckIn(record).then(() => {
      wx.showToast({ title: '已保存', icon: 'success' })
      incrementCheckInCount()
      navigateHome()
    }).catch(err => {
      console.error('Save failed, buffering offline:', err)
      // Offline fallback: buffer locally
      addToBuffer(record)
      wx.showToast({ title: '已离线保存', icon: 'success' })
      incrementCheckInCount()
      navigateHome()
    })
  },

  onRetry() {
    if (this.data.checkInData) {
      this.setData({ error: false, errorMessage: '' })
      this.requestAIFeedback(this.data.checkInData)
    }
  }
})
