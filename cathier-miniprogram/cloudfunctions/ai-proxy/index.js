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

const LESSON_CHAT_PROMPT = `你是一个既精通心理学，也对大语言模型训练很熟悉的专家。帮助用户在每次踩坑后，不只复盘事情，而是复盘"模型"——找到根深蒂固的旧算法并更新它。

## 严格的步骤推进规则

对话中用户的消息分两种：
- 第 0 条：系统上下文（包含触发事件等），这是背景信息，不算"用户回答"。
- 第 1～5 条：用户对每一步的回答。

你必须按以下规则推进，绝对不能重复同一步的问题：
- 收到第 0 条（上下文）→ 问第 1 步
- 收到第 1 条用户回答 → 问第 2 步
- 收到第 2 条用户回答 → 问第 3 步
- 收到第 3 条用户回答 → 问第 4 步
- 收到第 4 条用户回答 → 问第 5 步
- 收到第 5 条用户回答 → 给出简短收尾语，末尾加 <complete/>

用户发来的任何内容（无论长短、无论是否"完整"）都算作当前步骤的回答，立即进入下一步。

## 五步内容

**第 1 步：这次"堑"是什么？**
一句话说清楚发生了什么。

**第 2 步：我当时的自动输出是什么？**
不是事后解释，而是第一反应——脑子里冒出的第一句话或第一个动作冲动。

**第 3 步：这个输出背后的旧权重是什么？**
你为什么总往这个方向解释？这是关键步骤——真正该更新的不是事件，而是解释事件的旧模式。

**第 4 步：这次我想训练哪个新参数？**
要具体，不要空泛。不是"情绪稳定"，而是"遇到 X 时，不立刻解读成 Y"。

**第 5 步：下次再来时，我的替代动作是什么？**
小到能立刻执行的一个动作。

## 选项格式规范

每步提问后，根据用户的具体情境，给出 3～7 个有针对性的可能回答供选择（不要泛泛而谈，宁少勿多）。
所有选项必须用以下 XML 格式包裹，不要用数字列表或 bullet：

<options>
<option>选项内容</option>
<option>选项内容</option>
</options>

选项之外的引导文字正常书写。用户可点击选项直接回复，也可自己输入。

## 完成标记

第 5 步用户回答后，给出一句简短收尾（如"记下来了，这次长一智。"），然后在末尾加 <complete/>，不加任何其他内容。`

const LESSON_SUMMARY_PROMPT = `你是复盘总结专家。用户刚完成了「吃一堑长一智」五步复盘对话。
根据对话内容，生成一张简洁的训练卡片，格式如下（用 Markdown 加粗标签）：

**这次"堑"：** 一句话描述事件
**自动输出：** 当时的第一反应
**旧权重：** 背后的底层模式
**新参数：** 想要训练的新模式
**替代动作：** 下次的具体执行动作

语气简洁，像在记录一张训练卡片。不加鼓励语，不加废话，直接给内容。`

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
 * Call Hunyuan with a full messages array (system + history).
 * `maxTokens` defaults to 600 for short chat replies; pass a larger value for
 * structured output (e.g. brainTrainer steps with <options> XML).
 */
async function callHunyuanMessages(messages, maxTokens) {
  const apiKey = process.env.HUNYUAN_API_KEY
  if (!apiKey) {
    return { success: false, error: 'AI服务配置错误，请联系开发者' }
  }

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
        messages,
        temperature: 0.7,
        max_tokens: maxTokens || 600
      }),
      signal: controller.signal
    })

    clearTimeout(timeout)

    if (response.status === 401) return { success: false, error: 'AI服务配置错误，请联系开发者' }
    if (response.status === 429) return { success: false, rateLimited: true }
    if (!response.ok) {
      return { success: false, fallback: true, feedback: 'AI反馈生成失败，请稍后重试。' }
    }

    const data = await response.json()
    const feedbackText = data.choices && data.choices[0] && data.choices[0].message && data.choices[0].message.content
    if (!feedbackText) return { success: false, fallback: true, feedback: 'AI反馈生成失败，请稍后重试。' }

    return { success: true, feedback: feedbackText.trim() }
  } catch (err) {
    clearTimeout(timeout)
    if (err.name === 'AbortError') {
      return { success: false, fallback: true, feedback: 'AI连接超时，请稍后重试。' }
    }
    return { success: false, fallback: true, feedback: 'AI反馈生成失败，请稍后重试。' }
  }
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

  // Pattern insights: custom system prompt + user prompt
  if (event.type === 'pattern-insights') {
    const messages = [
      { role: 'system', content: event.systemPrompt || '' },
      { role: 'user', content: event.userPrompt || '' }
    ]
    let result = await callHunyuanMessages(messages)
    if (result.rateLimited) {
      await sleep(1000)
      result = await callHunyuanMessages(messages)
    }
    return result
  }

  // Lesson chat: multi-turn reflection conversation. Needs more tokens because
  // each AI turn returns prose + 3-7 <option> XML chips.
  if (event.type === 'lesson-chat') {
    const history = event.history || []
    const messages = [
      { role: 'system', content: LESSON_CHAT_PROMPT },
      ...history
    ]
    let result = await callHunyuanMessages(messages, 2000)
    if (result.rateLimited) {
      await sleep(1000)
      result = await callHunyuanMessages(messages, 2000)
    }
    return result
  }

  // Lesson summary: generate the 5-step training card from the conversation
  if (event.type === 'lesson-summary') {
    const history = event.history || []
    // Strip <options>...</options> blocks and <complete/> markers from each message
    const cleaned = history.map(m => ({
      role: m.role,
      content: String(m.content || '')
        .replace(/<options>[\s\S]*?<\/options>/g, '')
        .replace(/<complete\/>/g, '')
        .trim()
    }))
    const messages = [
      { role: 'system', content: LESSON_SUMMARY_PROMPT },
      ...cleaned,
      { role: 'user', content: '请生成五步复盘总结卡片。' }
    ]
    let result = await callHunyuanMessages(messages, 1500)
    if (result.rateLimited) {
      await sleep(1000)
      result = await callHunyuanMessages(messages, 1500)
    }
    return result
  }

  // Default: check-in feedback (original flow)
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
