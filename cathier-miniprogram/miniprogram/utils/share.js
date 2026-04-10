// share.js — WeChat share and social features

function getCheckInShareData(checkIn) {
  const emotionText = (checkIn.emotions || []).slice(0, 3).join('\u3001')
  return {
    title: `\u6211\u521a\u5b8c\u6210\u4e86\u4e00\u6b21\u60c5\u7eea\u89c9\u5bdf\uff1a${emotionText}`,
    path: '/pages/today/today'
  }
}

function getEmotionShareData(emotion) {
  const title = `\u89c9\u5bdf\u8bcd\u5178\uff1a${emotion.name} \u2014 ${emotion.definition || ''}`
  return {
    title: title.slice(0, 60),
    path: `/pages/dictionary/dictionary?emotion=${encodeURIComponent(emotion.name)}`
  }
}

module.exports = {
  getCheckInShareData,
  getEmotionShareData
}
