// cloud-db.js — Cloud database operations for check-ins

const db = wx.cloud.database()
const _ = db.command

async function saveCheckIn(checkInData) {
  const result = await db.collection('checkins').add({
    data: {
      date: checkInData.date || db.serverDate(),
      bodySensations: checkInData.bodySensations,
      intensity: checkInData.intensity,
      emotions: checkInData.emotions,
      note: checkInData.note,
      aiFeedback: checkInData.aiFeedback,
      triggerEvent: checkInData.triggerEvent,
      shareLevel: checkInData.shareLevel,
      createdAt: db.serverDate()
    }
  })
  return { _id: result._id, ...checkInData }
}

async function getCheckIns(page = 0, pageSize = 20) {
  const result = await db.collection('checkins')
    .orderBy('date', 'desc')
    .skip(page * pageSize)
    .limit(pageSize + 1)
    .get()

  const hasMore = result.data.length > pageSize
  const data = hasMore ? result.data.slice(0, pageSize) : result.data

  return { data, hasMore }
}

async function getCheckIn(id) {
  const result = await db.collection('checkins').doc(id).get()
  return result.data
}

async function deleteCheckIn(id) {
  try {
    await db.collection('checkins').doc(id).remove()
    return { success: true }
  } catch (err) {
    console.error('Delete check-in failed:', err)
    return { success: false }
  }
}

async function getUserPrefs() {
  const result = await db.collection('user_prefs')
    .limit(1)
    .get()

  if (result.data.length > 0) {
    return result.data[0]
  }

  const defaultPrefs = {
    reminderTime: null,
    totalCheckInCount: 0,
    lastSeenVersion: '1.0'
  }

  const addResult = await db.collection('user_prefs').add({
    data: defaultPrefs
  })

  return { _id: addResult._id, ...defaultPrefs }
}

async function updateUserPrefs(updates) {
  const prefs = await getUserPrefs()
  await db.collection('user_prefs').doc(prefs._id).update({
    data: updates
  })
}

async function incrementCheckInCount() {
  const prefs = await getUserPrefs()
  await db.collection('user_prefs').doc(prefs._id).update({
    data: {
      totalCheckInCount: _.inc(1)
    }
  })
}

// --- Daily Journal ---

async function saveDailyJournal({ mood, gains, existingId }) {
  if (existingId) {
    // Update existing journal entry
    await db.collection('daily_journals').doc(existingId).update({
      data: {
        mood,
        gains,
        updatedAt: db.serverDate()
      }
    })
    return { _id: existingId, mood, gains }
  }

  // Create new journal entry
  const result = await db.collection('daily_journals').add({
    data: {
      date: db.serverDate(),
      mood,
      gains,
      isShared: false,
      createdAt: db.serverDate()
    }
  })
  return { _id: result._id, mood, gains }
}

async function getTodayJournal() {
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  const tomorrow = new Date(today)
  tomorrow.setDate(tomorrow.getDate() + 1)

  const result = await db.collection('daily_journals')
    .where({
      createdAt: _.gte(today).and(_.lt(tomorrow))
    })
    .orderBy('createdAt', 'desc')
    .limit(1)
    .get()

  return result.data.length > 0 ? result.data[0] : null
}

async function getDailyJournals(page = 0, pageSize = 20) {
  const result = await db.collection('daily_journals')
    .orderBy('createdAt', 'desc')
    .skip(page * pageSize)
    .limit(pageSize + 1)
    .get()

  const hasMore = result.data.length > pageSize
  const data = hasMore ? result.data.slice(0, pageSize) : result.data

  return { data, hasMore }
}

// --- Pattern Insights ---

async function saveInsight(insightData) {
  const result = await db.collection('insights').add({
    data: {
      date: db.serverDate(),
      focusMode: insightData.focusMode,
      narrative: insightData.narrative,
      checkInCount: insightData.checkInCount || 0,
      createdAt: db.serverDate()
    }
  })
  return { _id: result._id, ...insightData }
}

async function getInsights(limit = 20) {
  const result = await db.collection('insights')
    .orderBy('createdAt', 'desc')
    .limit(limit)
    .get()
  return result.data || []
}

async function getCheckInCount() {
  const result = await db.collection('checkins').count()
  return result.total || 0
}

// --- User Profile (Friend System) ---

async function saveProfile({ displayName, avatarEmoji }) {
  const existing = await db.collection('user_profiles').where({}).limit(1).get()
  if (existing.data.length > 0) {
    await db.collection('user_profiles').doc(existing.data[0]._id).update({
      data: { displayName, avatarEmoji }
    })
    return { _id: existing.data[0]._id, displayName, avatarEmoji }
  }
  const result = await db.collection('user_profiles').add({
    data: { displayName, avatarEmoji, createdAt: db.serverDate() }
  })
  return { _id: result._id, displayName, avatarEmoji }
}

async function getMyProfile() {
  const result = await db.collection('user_profiles').where({}).limit(1).get()
  return result.data.length > 0 ? result.data[0] : null
}

async function updateShareLevel(checkinId, shareLevel) {
  await db.collection('checkins').doc(checkinId).update({
    data: { shareLevel, sharedAt: shareLevel ? db.serverDate() : null }
  })
}

// --- Lesson Summaries (吃一堑长一智) ---

async function saveLessonSummary({ items, conversationLength, date }) {
  const result = await db.collection('lesson_summaries').add({
    data: {
      items: items || [],
      summary: (items || []).join('\n'),
      conversationLength: conversationLength || 0,
      date: date || db.serverDate(),
      createdAt: db.serverDate()
    }
  })
  return { _id: result._id, items }
}

async function getLessonSummaries(limit = 20) {
  const result = await db.collection('lesson_summaries')
    .orderBy('createdAt', 'desc')
    .limit(limit)
    .get()
  return result.data || []
}

module.exports = {
  saveCheckIn,
  getCheckIns,
  getCheckIn,
  deleteCheckIn,
  getUserPrefs,
  updateUserPrefs,
  incrementCheckInCount,
  saveDailyJournal,
  getTodayJournal,
  getDailyJournals,
  saveInsight,
  getInsights,
  getCheckInCount,
  saveProfile,
  getMyProfile,
  updateShareLevel,
  saveLessonSummary,
  getLessonSummaries
}
