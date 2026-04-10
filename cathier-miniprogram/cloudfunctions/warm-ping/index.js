const cloud = require('wx-server-sdk')

cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV })

/**
 * Keep the ai-proxy cloud function warm to prevent cold starts.
 * Called by a scheduled trigger every 5 minutes.
 */
exports.main = async (event, context) => {
  try {
    console.log('Sending warm ping to ai-proxy')

    const result = await cloud.callFunction({
      name: 'ai-proxy',
      data: { ping: true }
    })

    console.log('Warm ping successful:', JSON.stringify(result.result))
    return { success: true, timestamp: new Date().toISOString() }
  } catch (err) {
    console.log('Warm ping failed:', err.message || JSON.stringify(err))
    return { success: false, error: err.message, timestamp: new Date().toISOString() }
  }
}
