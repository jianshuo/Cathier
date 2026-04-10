const cloud = require('wx-server-sdk')

cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV })

/**
 * Send a one-time subscribe message reminder to a user.
 *
 * event.openId      - target user's openId
 * event.templateId  - subscribe message template ID
 * event.reminderTime - display time string for the message
 */
exports.main = async (event, context) => {
  const { openId, templateId, reminderTime } = event

  if (!openId || !templateId) {
    console.log('Missing required fields: openId or templateId')
    return { success: false, error: '缺少必要参数' }
  }

  try {
    console.log(`Sending subscribe message to ${openId}, template=${templateId}`)

    const result = await cloud.openapi.subscribeMessage.send({
      touser: openId,
      templateId: templateId,
      page: 'pages/today/today',
      data: {
        thing1: {
          value: '该做一次情绪觉察了，花一分钟感受此刻的自己'
        },
        time2: {
          value: reminderTime || '每日提醒'
        }
      }
    })

    console.log('Subscribe message sent successfully:', JSON.stringify(result))
    return { success: true }
  } catch (err) {
    // Failed reminders are not critical — log but don't throw
    console.log('Failed to send subscribe message:', err.message || JSON.stringify(err))
    return { success: false, error: err.message || '发送提醒失败' }
  }
}
