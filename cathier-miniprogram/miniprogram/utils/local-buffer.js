// local-buffer.js — Offline-first local storage buffer for check-ins

const BUFFER_KEY = 'cathier_pending_checkins'
const MAX_BUFFER_SIZE = 50

function addToBuffer(checkInData) {
  const buffer = getBuffer()
  const entry = {
    _tempId: `${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
    ...checkInData
  }
  buffer.push(entry)

  // Drop oldest entries if buffer exceeds max size
  while (buffer.length > MAX_BUFFER_SIZE) {
    buffer.shift()
  }

  wx.setStorageSync(BUFFER_KEY, buffer)
  return entry
}

function getBuffer() {
  try {
    return wx.getStorageSync(BUFFER_KEY) || []
  } catch (err) {
    return []
  }
}

function removeFromBuffer(ids) {
  const idSet = new Set(ids)
  const buffer = getBuffer().filter(entry => !idSet.has(entry._tempId))
  wx.setStorageSync(BUFFER_KEY, buffer)
}

function clearBuffer() {
  wx.removeStorageSync(BUFFER_KEY)
}

async function syncBuffer() {
  const cloudDb = require('./cloud-db')
  const buffer = getBuffer()
  if (buffer.length === 0) return { synced: 0, failed: 0 }

  let synced = 0
  let failed = 0
  const syncedIds = []

  for (const entry of buffer) {
    try {
      const { _tempId, ...data } = entry
      await cloudDb.saveCheckIn(data)
      syncedIds.push(entry._tempId)
      synced++
    } catch (err) {
      console.error('Buffer sync failed for entry:', err)
      failed++
    }
  }

  if (syncedIds.length > 0) {
    removeFromBuffer(syncedIds)
  }

  return { synced, failed }
}

function initSyncListeners() {
  wx.onNetworkStatusChange((res) => {
    if (res.isConnected) {
      syncBuffer().then(result => {
        if (result.synced > 0) {
          console.log(`Synced ${result.synced} buffered check-ins`)
        }
      })
    }
  })
}

module.exports = {
  addToBuffer,
  getBuffer,
  removeFromBuffer,
  clearBuffer,
  syncBuffer,
  initSyncListeners
}
