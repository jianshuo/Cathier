const cloud = require('wx-server-sdk')

cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV })

const db = cloud.database()
const _ = db.command

const ALLOWED_EMOJIS = ['❤️', '🤗', '🌸', '🥺', '💪']

// ── Helpers ──────────────────────────────────────────────────────────

/**
 * Verify that the caller is friends with the checkin owner.
 */
async function verifyFriendship(callerOpenId, ownerOpenId) {
  if (callerOpenId === ownerOpenId) {
    // Allow reacting to your own checkins (edge case, harmless)
    return true
  }

  const friendships = await db.collection('friendships')
    .where({ _openid: callerOpenId })
    .get()

  return friendships.data.some(f => {
    const friendId = f.initiatorOpenId === callerOpenId
      ? f.accepterOpenId
      : f.initiatorOpenId
    return friendId === ownerOpenId
  })
}

/**
 * Get the caller's profile for reactor display info.
 */
async function getCallerProfile(openId) {
  const res = await db.collection('user_profiles')
    .where({ _openid: openId })
    .limit(1)
    .get()
  return res.data[0] || null
}

// ── Actions ──────────────────────────────────────────────────────────

/**
 * Toggle a reaction: if the same user+checkin+emoji exists, remove it.
 * Otherwise create it. Validates friendship first.
 */
async function toggle(openId, checkinId, emoji, checkinOwnerOpenId) {
  if (!checkinId) {
    return { success: false, error: '缺少签到ID' }
  }

  if (!emoji || !ALLOWED_EMOJIS.includes(emoji)) {
    return { success: false, error: '无效的表情' }
  }

  if (!checkinOwnerOpenId) {
    return { success: false, error: '缺少签到所有者信息' }
  }

  // Verify friendship
  const isFriend = await verifyFriendship(openId, checkinOwnerOpenId)
  if (!isFriend) {
    return { success: false, error: '你们还不是好友' }
  }

  // Check if reaction already exists
  const existing = await db.collection('reactions')
    .where({
      _openid: openId,
      checkinId: checkinId,
      emoji: emoji
    })
    .limit(1)
    .get()

  if (existing.data.length > 0) {
    // Remove existing reaction (toggle off)
    await db.collection('reactions').doc(existing.data[0]._id).remove()
    return { success: true, action: 'removed' }
  }

  // Create new reaction
  const profile = await getCallerProfile(openId)

  await db.collection('reactions').add({
    data: {
      checkinId,
      checkinOwnerOpenId,
      emoji,
      reactorProfileId: profile ? profile._id : '',
      reactorName: profile ? profile.displayName : '好友',
      createdAt: db.serverDate()
    }
  })

  return { success: true, action: 'added' }
}

/**
 * Get all reactions for a given checkin.
 */
async function getReactions(checkinId) {
  if (!checkinId) {
    return { success: false, error: '缺少签到ID' }
  }

  const res = await db.collection('reactions')
    .where({ checkinId })
    .orderBy('createdAt', 'asc')
    .get()

  // Group reactions by emoji
  const grouped = {}
  ALLOWED_EMOJIS.forEach(e => { grouped[e] = [] })

  res.data.forEach(r => {
    if (!grouped[r.emoji]) grouped[r.emoji] = []
    grouped[r.emoji].push({
      _id: r._id,
      reactorOpenId: r._openid,
      reactorName: r.reactorName,
      reactorProfileId: r.reactorProfileId
    })
  })

  return { success: true, reactions: grouped, total: res.data.length }
}

// ── Main Entry Point ─────────────────────────────────────────────────

exports.main = async (event, context) => {
  const { OPENID } = cloud.getWXContext()
  const openId = OPENID

  if (!openId) {
    return { success: false, error: '无法获取用户身份' }
  }

  const { action } = event

  try {
    switch (action) {
      case 'toggle':
        return await toggle(
          openId,
          event.checkinId,
          event.emoji,
          event.checkinOwnerOpenId
        )

      case 'getReactions':
        return await getReactions(event.checkinId)

      default:
        return { success: false, error: `未知操作: ${action}` }
    }
  } catch (err) {
    console.error(`[react] action=${action} error:`, err)
    return { success: false, error: err.message || '服务器内部错误' }
  }
}
