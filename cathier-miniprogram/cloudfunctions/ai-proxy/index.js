const cloud = require('wx-server-sdk')
const fetch = require('node-fetch')

cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV })

const HUNYUAN_API_URL = 'https://api.hunyuan.cloud.tencent.com/v1/chat/completions'
const HUNYUAN_MODEL = 'hunyuan-turbo'
const REQUEST_TIMEOUT_MS = 30000

const SYSTEM_PROMPT = `你是「觉察」小程序的AI觉察伙伴。这是一款情绪感知训练工具，用户通过「身体扫描→躯体感受标注→情绪命名」三步流程练习觉察。用户是主动练习的"练习者"，不是"患者"。

核心信念：身体不会说谎。肩膀的紧绷、胸口的闷压、胃部的翻搅——每个躯体感受背后都藏着等待被看见的情绪信号。你的工作是帮用户读懂这些信号，建立「身体感受↔情绪↔触发情境」的连接。

回复200-300字，灵活运用以下层次（不必每次写满）：

1）温暖的看见：具体回应用户描述的身体和情绪，不用"我理解你的感受"这种套话。

2）身体-情绪连接（核心价值）：
- 这个部位的感受在传递什么信号？（如：喉咙发紧往往和"想说却没说出口的话"有关）
- 帮用户更精准地命名情绪——"焦虑"可能是担忧、不安、对失控的恐惧、或对未知的期待
- 触发点vs深层原因——"堵车迟到很烦"背后可能是"我不允许自己不完美"

3）轻轻一推：一个觉察练习、新视角、或温和的提问。

风格：像练习过正念的朋友轻声说话。不评判，不说"你应该"。可以肯定觉察能力本身。每次变换结构和切入角度。不使用医疗术语。本小程序不提供医疗建议，AI反馈仅供参考。`

/**
 * Format body sensations object into readable text.
 * Input: { "胸口": ["紧绷","沉重"], "肩膀": ["酸痛"] }
 * Output: "胸口：紧绷、沉重\n肩膀：酸痛"
 */
function formatBodySensations(bodySensations) {
  if (!bodySensations || typeof bodySensations !== 'object') {
    return '无'
  }
  const parts = []
  for (const [bodyPart, sensations] of Object.entries(bodySensations)) {
    if (Array.isArray(sensations) && sensations.length > 0) {
      parts.push(`${bodyPart}：${sensations.join('、')}`)
    }
  }
  return parts.length > 0 ? parts.join('\n') : '无'
}

/**
 * Build user message from check-in data.
 */
function buildUserMessage(event) {
  const lines = ['我的觉察记录：']
  if (event.contextBrief) {
    lines.push(`关于我：${event.contextBrief}`)
  }
  lines.push(`身体感受：${formatBodySensations(event.bodySensations)}`)
  lines.push(`情绪：${Array.isArray(event.emotions) ? event.emotions.join('、') : '无'}`)
  lines.push(`强度：${event.intensity || '?'}/10`)
  if (event.triggerEvent) {
    lines.push(`触发事件：${event.triggerEvent}`)
  }
  if (event.note) {
    lines.push(`备注：${event.note}`)
  }
  return lines.join('\n')
}

/**
 * Call Qwen API with timeout and abort support.
 */
async function callHunyuan(userMessage) {
  const apiKey = process.env.HUNYUAN_API_KEY
  if (!apiKey) {
    console.log('HUNYUAN_API_KEY not configured. Available env keys:', Object.keys(process.env).filter(k => k.includes('HUNYUAN') || k.includes('API')).join(', '))
    return { success: false, error: 'AI服务配置错误，请联系开发者' }
  }
  console.log('API key loaded, length:', apiKey.length, 'prefix:', apiKey.substring(0, 6) + '...')

  const controller = new AbortController()
  const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS)

  try {
    const response = await fetch(HUNYUAN_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`
      },
      body: JSON.stringify({
        model: HUNYUAN_MODEL,
        messages: [
          { role: 'system', content: SYSTEM_PROMPT },
          { role: 'user', content: userMessage }
        ],
        temperature: 0.7,
        max_tokens: 600
      }),
      signal: controller.signal
    })

    clearTimeout(timeout)

    if (response.status === 401) {
      console.log('Hunyuan API auth failed: 401')
      return { success: false, error: 'AI服务配置错误，请联系开发者' }
    }

    if (response.status === 429) {
      return { success: false, rateLimited: true }
    }

    if (!response.ok) {
      const errorBody = await response.text().catch(() => 'unknown')
      console.log(`Hunyuan API error: status=${response.status}, body=${errorBody}`)
      return { success: false, fallback: true, feedback: '本次AI反馈生成失败，您的觉察已保存。可稍后重试。' }
    }

    const data = await response.json()
    const feedbackText = data.choices && data.choices[0] && data.choices[0].message && data.choices[0].message.content
    if (!feedbackText) {
      console.log('Hunyuan API returned empty content:', JSON.stringify(data))
      return { success: false, fallback: true, feedback: '本次AI反馈生成失败，您的觉察已保存。可稍后重试。' }
    }

    return { success: true, feedback: feedbackText.trim() }
  } catch (err) {
    clearTimeout(timeout)
    if (err.name === 'AbortError') {
      console.log('Hunyuan API request timed out')
      return { success: false, fallback: true, feedback: '本次AI连接超时，您的觉察已保存。可稍后重试。' }
    }
    console.log('Hunyuan API unexpected error:', err.message)
    return { success: false, fallback: true, feedback: '本次AI反馈生成失败，您的觉察已保存。可稍后重试。' }
  }
}

/**
 * Sleep helper for retry delay.
 */
function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms))
}

/**
 * Main cloud function entry point.
 */
exports.main = async (event, context) => {
  // Warm ping: return immediately without calling Qwen
  if (event.ping === true) {
    console.log('Warm ping received')
    return { success: true, ping: true }
  }

  // Validate required fields
  if (!event.emotions || !event.bodySensations) {
    console.log('Missing required fields: emotions or bodySensations')
    return { success: false, error: '缺少必要的觉察数据' }
  }

  const userMessage = buildUserMessage(event)
  console.log('Calling Hunyuan API with user message length:', userMessage.length)

  // First attempt
  let result = await callHunyuan(userMessage)

  // Retry once on rate limit
  if (result.rateLimited) {
    console.log('Rate limited, retrying after 1 second...')
    await sleep(1000)
    result = await callHunyuan(userMessage)
    if (result.rateLimited) {
      console.log('Rate limited again on retry')
      return { success: false, fallback: true, feedback: 'AI服务繁忙，您的觉察已保存。请稍后重试获取反馈。' }
    }
  }

  return result
}
