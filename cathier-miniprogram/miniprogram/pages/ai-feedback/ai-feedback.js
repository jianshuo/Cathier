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
    errorMessage: '',
    showExercise: false,
    exerciseData: { title: '', steps: [] }
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

    // Load context brief from settings for personalized AI feedback
    const contextBrief = wx.getStorageSync('contextBrief') || ''

    wx.cloud.callFunction({
      name: 'ai-proxy',
      data: {
        bodySensations: data.bodySensations || {},
        emotions: data.emotions || [],
        emotionNames,
        bodyDescription: bodyDesc,
        intensity: data.intensity || 5,
        triggerEvent: data.trigger || '',
        note: data.note || '',
        contextBrief
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
  },

  onOpenExercise() {
    const data = this.data.checkInData
    const bodyParts = Object.keys(data.bodySensations || {}).join('、')
    const exercise = this._pickExercise(bodyParts)
    this.setData({ showExercise: true, exerciseData: exercise })
  },

  onCloseExercise() {
    this.setData({ showExercise: false })
  },

  _pickExercise(bodyParts) {
    if (/胸口|呼吸/.test(bodyParts)) {
      return {
        title: '4-7-8 呼吸练习',
        steps: [
          '找一个舒适的姿势，轻轻闭上眼睛',
          '用鼻子缓慢吸气，心里默数 4 秒',
          '屏住呼吸，心里默数 7 秒',
          '用嘴巴缓慢呼气，心里默数 8 秒',
          '重复以上步骤 3 次，感受身体的变化'
        ]
      }
    }
    if (/肩膀|颈部|背部/.test(bodyParts)) {
      return {
        title: '渐进性肌肉放松',
        steps: [
          '坐直或站立，双手自然下垂',
          '用力耸起双肩，尽量靠近耳朵，保持 5 秒',
          '突然完全松开肩膀，感受紧绷消散的感觉',
          '重复以上步骤 3 次',
          '最后轻轻转动脖子，感受放松后的轻盈'
        ]
      }
    }
    if (/双脚|大腿|整个身体/.test(bodyParts)) {
      return {
        title: '5-4-3-2-1 接地练习',
        steps: [
          '说出 5 样你现在看到的东西',
          '触摸 4 样你身边的物体，感受它们的质感',
          '闭上眼睛，说出 3 种你听到的声音',
          '深呼吸，说出 2 种你闻到的气味',
          '最后，说出 1 样你尝到的味道'
        ]
      }
    }
    return {
      title: '身体扫描',
      steps: [
        '找一个舒适的坐姿，轻轻闭上眼睛',
        '将注意力放在头顶，感受那里的温度和感觉',
        '缓慢地将注意力向下移动：额头、眼睛、脸颊、下巴',
        '继续向下：脖子、肩膀、双臂、双手',
        '再向下：胸口、腹部、腰背、双腿，直到脚趾',
        '不评判任何感觉，只是觉察和接纳'
      ]
    }
  }
})
