const cloud = require('wx-server-sdk')

cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV })

const db = cloud.database()
const _ = db.command

const PAGE_SIZE = 20
const CODE_LENGTH = 6
const CODE_EXPIRY_MS = 24 * 60 * 60 * 1000 // 24 hours
const MAX_CODE_RETRIES = 3
const BATCH_SIZE = 10 // WeChat db.command.in() limit

// ── Helpers ──────────────────────────────────────────────────────────

function generateRandomCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789' // no 0/O/1/I to avoid confusion
  let code = ''
  for (let i = 0; i < CODE_LENGTH; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length))
  }
  return code
}

/**
 * Batch-fetch documents using db.command.in() with groups of BATCH_SIZE.
 * Returns flat array of all matching documents.
 */
async function batchQuery(collection, field, values, extraWhere = {}) {
  const results = []
  for (let i = 0; i < values.length; i += BATCH_SIZE) {
    const batch = values.slice(i, i + BATCH_SIZE)
    let query = db.collection(collection).where({
      [field]: _.in(batch),
      ...extraWhere
    })
    const res = await query.get()
    results.push(...res.data)
  }
  return results
}

/**
 * Get the caller's profile from user_profiles.
 */
async function getCallerProfile(openId) {
  const res = await db.collection('user_profiles')
    .where({ _openid: openId })
    .limit(1)
    .get()
  return res.data[0] || null
}

/**
 * Extract the friend's openId from a friendship record,
 * given the caller's openId.
 */
function friendOpenIdFrom(friendship, callerOpenId) {
  return friendship.initiatorOpenId === callerOpenId
    ? friendship.accepterOpenId
    : friendship.initiatorOpenId
}

function friendProfileIdFrom(friendship, callerOpenId) {
  return friendship.initiatorOpenId === callerOpenId
    ? friendship.accepterProfileId
    : friendship.initiatorProfileId
}

/**
 * Filter checkin fields based on shareLevel for the friend feed.
 */
function filterByShareLevel(checkin, profile) {
  const base = {
    _id: checkin._id,
    ownerOpenId: checkin._openid,
    ownerName: (profile && profile.displayName) || '好友',
    ownerEmoji: (profile && profile.avatarEmoji) || '🙂',
    date: checkin.date,
    intensity: checkin.intensity,
    shareLevel: checkin.shareLevel,
    createdAt: checkin.createdAt
  }

  if (checkin.shareLevel === 'category') {
    const categories = [
      ...new Set((checkin.emotions || []).map(e => e.categoryName))
    ]
    return { ...base, categories }
  }

  if (checkin.shareLevel === 'emotions') {
    return {
      ...base,
      emotions: checkin.emotions,
      bodySensations: checkin.bodySensations
    }
  }

  // 'full' — everything
  return {
    ...base,
    emotions: checkin.emotions,
    bodySensations: checkin.bodySensations,
    triggerEvent: checkin.triggerEvent,
    note: checkin.note,
    aiFeedback: checkin.aiFeedback
  }
}

// ── Actions ──────────────────────────────────────────────────────────

/**
 * Generate a 6-char invite code with collision check (up to 3 retries).
 * Stores in invite_codes with 24h expiry.
 */
async function generateCode(openId) {
  const profile = await getCallerProfile(openId)
  if (!profile) {
    return { success: false, error: '请先创建个人档案' }
  }

  let code = null
  for (let attempt = 0; attempt < MAX_CODE_RETRIES; attempt++) {
    const candidate = generateRandomCode()
    // Check collision: any unused, non-expired code with same value
    const existing = await db.collection('invite_codes')
      .where({
        code: candidate,
        used: false,
        expiresAt: _.gte(new Date())
      })
      .limit(1)
      .get()

    if (existing.data.length === 0) {
      code = candidate
      break
    }
  }

  if (!code) {
    return { success: false, error: '生成邀请码失败，请重试' }
  }

  const now = new Date()
  await db.collection('invite_codes').add({
    data: {
      code,
      fromProfileId: profile._id,
      expiresAt: new Date(now.getTime() + CODE_EXPIRY_MS),
      used: false,
      usedBy: null,
      createdAt: db.serverDate()
    }
  })

  return { success: true, code, expiresAt: new Date(now.getTime() + CODE_EXPIRY_MS) }
}

/**
 * Validate an invite code: exists, not expired, not used, not self-invite.
 */
async function validateCode(openId, code) {
  if (!code || typeof code !== 'string' || code.length !== CODE_LENGTH) {
    return { success: false, error: '邀请码格式无效' }
  }

  const res = await db.collection('invite_codes')
    .where({ code: code.toUpperCase() })
    .orderBy('createdAt', 'desc')
    .limit(1)
    .get()

  if (res.data.length === 0) {
    return { success: false, error: '邀请码不存在' }
  }

  const invite = res.data[0]

  if (invite.used) {
    return { success: false, error: '该邀请码已被使用' }
  }

  if (new Date(invite.expiresAt) < new Date()) {
    return { success: false, error: '邀请码已过期' }
  }

  if (invite._openid === openId) {
    return { success: false, error: '不能使用自己的邀请码' }
  }

  // Check if already friends
  const existingFriendship = await db.collection('friendships')
    .where({
      _openid: openId,
      [_.or([
        { initiatorOpenId: invite._openid, accepterOpenId: openId },
        { initiatorOpenId: openId, accepterOpenId: invite._openid }
      ])]: true
    })
    .limit(1)
    .get()

  // Simpler duplicate check: query friendships owned by caller involving the inviter
  const dupCheck = await db.collection('friendships')
    .where({ _openid: openId })
    .get()

  const alreadyFriends = dupCheck.data.some(f =>
    friendOpenIdFrom(f, openId) === invite._openid
  )

  if (alreadyFriends) {
    return { success: false, error: '你们已经是好友了' }
  }

  // Fetch inviter profile for display
  const inviterProfile = await getCallerProfile(invite._openid)

  return {
    success: true,
    invite: {
      _id: invite._id,
      code: invite.code,
      inviterOpenId: invite._openid,
      inviterName: inviterProfile ? inviterProfile.displayName : '好友',
      inviterEmoji: inviterProfile ? inviterProfile.avatarEmoji : '🙂'
    }
  }
}

/**
 * Accept an invite: mark code as used, create 2 friendship records
 * (one per user so both can query their own friendships).
 */
async function acceptInvite(openId, inviteId) {
  // Fetch the invite
  const inviteRes = await db.collection('invite_codes').doc(inviteId).get()
  const invite = inviteRes.data

  if (!invite || invite.used) {
    return { success: false, error: '邀请码无效或已被使用' }
  }

  if (new Date(invite.expiresAt) < new Date()) {
    return { success: false, error: '邀请码已过期' }
  }

  if (invite._openid === openId) {
    return { success: false, error: '不能使用自己的邀请码' }
  }

  const initiatorOpenId = invite._openid
  const accepterOpenId = openId

  // Get both profiles
  const initiatorProfile = await getCallerProfile(initiatorOpenId)
  const accepterProfile = await getCallerProfile(accepterOpenId)

  if (!accepterProfile) {
    return { success: false, error: '请先创建个人档案' }
  }

  const initiatorProfileId = initiatorProfile ? initiatorProfile._id : ''
  const accepterProfileId = accepterProfile._id

  // Mark invite as used
  await db.collection('invite_codes').doc(inviteId).update({
    data: {
      used: true,
      usedBy: accepterOpenId
    }
  })

  // Create friendship record owned by initiator
  // Using admin add to set _openid explicitly
  const friendshipData = {
    initiatorOpenId,
    accepterOpenId,
    initiatorProfileId,
    accepterProfileId,
    createdAt: db.serverDate()
  }

  // Record 1: owned by initiator (so initiator can query their friendships)
  await db.collection('friendships').add({
    data: { ...friendshipData, _openid: initiatorOpenId }
  })

  // Record 2: owned by accepter (so accepter can query their friendships)
  await db.collection('friendships').add({
    data: { ...friendshipData, _openid: accepterOpenId }
  })

  return {
    success: true,
    friend: {
      openId: initiatorOpenId,
      displayName: initiatorProfile ? initiatorProfile.displayName : '好友',
      avatarEmoji: initiatorProfile ? initiatorProfile.avatarEmoji : '🙂'
    }
  }
}

/**
 * Remove a friend: delete both friendship records.
 */
async function removeFriend(openId, friendOpenId) {
  if (!friendOpenId) {
    return { success: false, error: '缺少好友信息' }
  }

  // Delete record owned by caller
  const myRecords = await db.collection('friendships')
    .where({ _openid: openId })
    .get()

  const myFriendshipIds = myRecords.data
    .filter(f => friendOpenIdFrom(f, openId) === friendOpenId)
    .map(f => f._id)

  for (const id of myFriendshipIds) {
    await db.collection('friendships').doc(id).remove()
  }

  // Delete record owned by the friend
  const friendRecords = await db.collection('friendships')
    .where({ _openid: friendOpenId })
    .get()

  const friendFriendshipIds = friendRecords.data
    .filter(f => friendOpenIdFrom(f, friendOpenId) === openId)
    .map(f => f._id)

  for (const id of friendFriendshipIds) {
    await db.collection('friendships').doc(id).remove()
  }

  return { success: true }
}

/**
 * Get friend feed: shared checkins from all friends, filtered by shareLevel,
 * paginated, with profile info attached.
 */
async function getFriendFeed(openId, page) {
  page = page || 0

  // 1. Get caller's friendships
  const friendships = await db.collection('friendships')
    .where({ _openid: openId })
    .get()

  if (friendships.data.length === 0) {
    return { success: true, data: [], hasMore: false }
  }

  // 2. Extract friend openIds and profileIds
  const friends = friendships.data.map(f => ({
    openId: friendOpenIdFrom(f, openId),
    profileId: friendProfileIdFrom(f, openId)
  }))

  const friendOpenIds = [...new Set(friends.map(f => f.openId))]
  const profileIds = [...new Set(friends.map(f => f.profileId).filter(Boolean))]

  // 3. Fetch friend profiles (batch in groups of 10)
  const profiles = {}
  const profileDocs = await batchQuery('user_profiles', '_id', profileIds)
  profileDocs.forEach(p => { profiles[p._openid] = p })

  // 4. Get shared checkins from friends (batch in groups of 10)
  let allFeedItems = []
  for (let i = 0; i < friendOpenIds.length; i += BATCH_SIZE) {
    const batch = friendOpenIds.slice(i, i + BATCH_SIZE)
    const res = await db.collection('checkins')
      .where({
        _openid: _.in(batch),
        shareLevel: _.neq(null)
      })
      .orderBy('date', 'desc')
      .limit(50) // over-fetch per batch, then merge-sort + paginate
      .get()
    allFeedItems.push(...res.data)
  }

  // 5. Merge-sort by date descending
  allFeedItems.sort((a, b) => {
    const dateA = a.date ? new Date(a.date) : new Date(0)
    const dateB = b.date ? new Date(b.date) : new Date(0)
    return dateB - dateA
  })

  // 6. Paginate
  const start = page * PAGE_SIZE
  const pageItems = allFeedItems.slice(start, start + PAGE_SIZE + 1)
  const hasMore = pageItems.length > PAGE_SIZE
  const feedPage = hasMore ? pageItems.slice(0, PAGE_SIZE) : pageItems

  // 7. Filter fields by shareLevel + attach profile info
  const filtered = feedPage.map(checkin => {
    const profile = profiles[checkin._openid] || {}
    return filterByShareLevel(checkin, profile)
  })

  return { success: true, data: filtered, hasMore }
}

/**
 * Get caller's friend list with profile info.
 */
async function getMyFriends(openId) {
  const friendships = await db.collection('friendships')
    .where({ _openid: openId })
    .get()

  if (friendships.data.length === 0) {
    return { success: true, friends: [] }
  }

  // Deduplicate friend info
  const friendMap = new Map()
  friendships.data.forEach(f => {
    const fOpenId = friendOpenIdFrom(f, openId)
    const fProfileId = friendProfileIdFrom(f, openId)
    if (!friendMap.has(fOpenId)) {
      friendMap.set(fOpenId, { openId: fOpenId, profileId: fProfileId })
    }
  })

  const profileIds = [...friendMap.values()]
    .map(f => f.profileId)
    .filter(Boolean)

  // Fetch profiles
  const profiles = {}
  if (profileIds.length > 0) {
    const profileDocs = await batchQuery('user_profiles', '_id', profileIds)
    profileDocs.forEach(p => { profiles[p._openid] = p })
  }

  const friends = [...friendMap.values()].map(f => {
    const profile = profiles[f.openId] || {}
    return {
      openId: f.openId,
      displayName: profile.displayName || '好友',
      avatarEmoji: profile.avatarEmoji || '🙂',
      profileId: f.profileId
    }
  })

  return { success: true, friends }
}

/**
 * Get caller's pending (unused, non-expired) invite codes.
 */
async function getMyPendingCodes(openId) {
  const res = await db.collection('invite_codes')
    .where({
      _openid: openId,
      used: false,
      expiresAt: _.gte(new Date())
    })
    .orderBy('createdAt', 'desc')
    .get()

  const codes = res.data.map(c => ({
    _id: c._id,
    code: c.code,
    expiresAt: c.expiresAt,
    createdAt: c.createdAt
  }))

  return { success: true, codes }
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
      case 'generateCode':
        return await generateCode(openId)

      case 'validateCode':
        return await validateCode(openId, event.code)

      case 'acceptInvite':
        return await acceptInvite(openId, event.inviteId)

      case 'removeFriend':
        return await removeFriend(openId, event.friendOpenId)

      case 'getFriendFeed':
        return await getFriendFeed(openId, event.page)

      case 'getMyFriends':
        return await getMyFriends(openId)

      case 'getMyPendingCodes':
        return await getMyPendingCodes(openId)

      default:
        return { success: false, error: `未知操作: ${action}` }
    }
  } catch (err) {
    console.error(`[friend-manage] action=${action} error:`, err)
    return { success: false, error: err.message || '服务器内部错误' }
  }
}
