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
  getCheckInCount
}
