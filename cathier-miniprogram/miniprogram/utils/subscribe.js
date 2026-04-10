// subscribe.js — Subscription message management

const REMINDER_TEMPLATE_ID = 'TEMPLATE_ID_PLACEHOLDER'

async function requestReminder() {
  return new Promise((resolve) => {
    wx.requestSubscribeMessage({
      tmplIds: [REMINDER_TEMPLATE_ID],
      success(res) {
        const accepted = res[REMINDER_TEMPLATE_ID] === 'accept'
        resolve({ accepted })
      },
      fail(err) {
        console.error('Subscribe message request failed:', err)
        resolve({ accepted: false })
      }
    })
  })
}

async function scheduleReminder(reminderTime) {
  try {
    const result = await wx.cloud.callFunction({
      name: 'subscribe-trigger',
      data: {
        templateId: REMINDER_TEMPLATE_ID,
        reminderTime: reminderTime
      }
    })
    return result.result
  } catch (err) {
    console.error('Schedule reminder failed:', err)
    return { success: false }
  }
}

module.exports = {
  REMINDER_TEMPLATE_ID,
  requestReminder,
  scheduleReminder
}
