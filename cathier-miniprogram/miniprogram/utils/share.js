// share.js — WeChat share and social features

const DEFAULT_TITLE = '觉察 — 用身体感受认识情绪'
const DEFAULT_PATH = '/pages/today/today'

function getDefaultShareData(overrides) {
  overrides = overrides || {}
  return {
    title: overrides.title || DEFAULT_TITLE,
    path: overrides.path || DEFAULT_PATH
  }
}

function getDefaultTimelineData(overrides) {
  overrides = overrides || {}
  return {
    title: overrides.title || DEFAULT_TITLE,
    query: overrides.query || ''
  }
}

function getCheckInShareData(checkIn) {
  const emotionText = (checkIn.emotions || []).slice(0, 3).join('、')
  return {
    title: emotionText
      ? '我刚完成了一次情绪觉察：' + emotionText
      : '我刚完成了一次情绪觉察',
    path: DEFAULT_PATH
  }
}

function getEmotionShareData(emotion) {
  if (!emotion || !emotion.name) {
    return {
      title: '觉察词典 — 探索情绪与身体感受',
      path: '/pages/dictionary/dictionary'
    }
  }
  const definition = emotion.definition ? ' — ' + emotion.definition : ''
  const title = '觉察词典：' + emotion.name + definition
  return {
    title: title.slice(0, 60),
    path: '/pages/dictionary/dictionary?emotion=' + encodeURIComponent(emotion.name)
  }
}

module.exports = {
  DEFAULT_TITLE,
  DEFAULT_PATH,
  getDefaultShareData,
  getDefaultTimelineData,
  getCheckInShareData,
  getEmotionShareData
}
