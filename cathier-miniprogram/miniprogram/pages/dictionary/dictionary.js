const app = getApp()
const { getEmotionShareData } = require('../../utils/share')
let dictionary = {}
try {
  dictionary = require('../../data/dictionary.js')
  console.log('Dictionary loaded, sections:', Object.keys(dictionary.sections || {}))
} catch (e) {
  console.error('Failed to load dictionary.js:', e)
}

function getRichEntries(section) {
  return (dictionary.sections && dictionary.sections[section] && dictionary.sections[section].entries) || {}
}

Page({
  data: {
    tabs: ['情绪', '身体感觉', '身体部位'],
    activeTab: 0,
    categories: [],          // tab 0: emotion categories with full details
    bodyPartSensations: [],  // tab 1: { name, sensations: [...] }
    bodyPartList: [],        // tab 2: body part names
    expandedCategory: '',
    expandedBodyPart: '',
    searchQuery: '',
    filteredCategories: [],
    filteredBodyPartSensations: [],
    filteredBodyPartList: [],
    detailVisible: false,
    detailType: '',
    detailData: null
  },

  onLoad() {
    this.loadDictionaryData()
  },

  loadDictionaryData() {
    const emotions = app.globalData.emotions
    if (!emotions) return

    // Rich dictionary lookup helpers
    const richEmotions = (dictionary.sections && dictionary.sections.emotions && dictionary.sections.emotions.entries) || {}
    const richBodyParts = (dictionary.sections && dictionary.sections.bodyParts && dictionary.sections.bodyParts.entries) || {}
    const richSensations = (dictionary.sections && dictionary.sections.sensations && dictionary.sections.sensations.entries) || {}

    // Build reverse lookup maps: nameZh -> entry
    const bodyPartByZh = {}
    Object.keys(richBodyParts).forEach(key => {
      const entry = richBodyParts[key]
      if (entry.nameZh) bodyPartByZh[entry.nameZh] = entry
    })
    const sensationByZh = {}
    Object.keys(richSensations).forEach(key => {
      const entry = richSensations[key]
      if (entry.nameZh) sensationByZh[entry.nameZh] = entry
    })

    // Build emotion categories (tab 0) — merge rich data by emotion id
    const categories = (emotions.categories || []).map(cat => ({
      id: cat.id,
      name: cat.name,
      nameEn: cat.nameEn || '',
      colorHex: cat.colorHex || '',
      valence: cat.valence,
      count: cat.emotions.length,
      emotions: cat.emotions.map(em => {
        const rich = richEmotions[em.id] || {}
        return {
          id: em.id,
          name: em.name,
          nameEn: rich.nameEn || em.nameEn || '',
          emoji: em.emoji,
          definition: em.definition || '',
          similarTo: em.similarTo || [],
          differs: em.differs || {},
          differsList: Object.keys(em.differs || {}).map(k => ({ key: k, value: em.differs[k] })),
          intensity: em.intensity || 0,
          origin: rich.origin || '',
          experience: rich.experience || '',
          embodiment: rich.embodiment || '',
          imagery: rich.imagery || '',
          developmentalStage: rich.developmentalStage || '',
          formativeEvents: rich.formativeEvents || '',
          personalityImpact: rich.personalityImpact || '',
          transformation: rich.transformation || '',
          literaryReference: rich.literaryReference || ''
        }
      })
    }))

    // Build body part sensations (tab 1)
    const sensationsMap = emotions.sensations || {}
    const bodyPartSensations = Object.keys(sensationsMap).map(part => ({
      name: part,
      sensations: sensationsMap[part] || []
    }))

    // Build body part list (tab 2)
    const bodyPartList = (emotions.bodyParts || []).map(name => ({ name }))

    this.setData({
      categories,
      bodyPartSensations,
      bodyPartList,
      filteredCategories: categories,
      filteredBodyPartSensations: bodyPartSensations,
      filteredBodyPartList: bodyPartList
    })
  },

  onTabChange(e) {
    const idx = parseInt(e.currentTarget.dataset.index)
    this.setData({ activeTab: idx, expandedCategory: '', expandedBodyPart: '' })
    this.applyFilter()
  },

  onToggleCategory(e) {
    const name = e.currentTarget.dataset.name
    this.setData({
      expandedCategory: this.data.expandedCategory === name ? '' : name
    })
  },

  onToggleBodyPart(e) {
    const name = e.currentTarget.dataset.name
    this.setData({
      expandedBodyPart: this.data.expandedBodyPart === name ? '' : name
    })
  },

  // Detail popup
  onShowEmotionDetail(e) {
    const id = e.currentTarget.dataset.id
    const catName = e.currentTarget.dataset.cat
    const cat = this.data.categories.find(c => c.name === catName)
    if (!cat) return
    const em = cat.emotions.find(x => x.id === id)
    if (!em) return
    // Build intensity dots array for visual display
    const intensityDots = []
    for (let i = 1; i <= 5; i++) {
      intensityDots.push({ filled: i <= (em.intensity || 0) })
    }
    this.setData({
      detailType: 'emotion',
      detailVisible: true,
      detailData: {
        ...em,
        categoryName: cat.name,
        categoryValence: cat.valence,
        categoryColor: cat.colorHex || '',
        nameEn: em.nameEn || '',
        intensityDots
      }
    })
  },

  onShowSensationDetail(e) {
    const name = e.currentTarget.dataset.name
    const bodyPart = e.currentTarget.dataset.part
    // Find ALL body parts that share this sensation
    const relatedParts = this.data.bodyPartSensations
      .filter(bp => bp.sensations.includes(name))
      .map(bp => bp.name)
    // Find other sensations in the same body part for context
    const siblingMap = app.globalData.emotions ? app.globalData.emotions.sensations : {}
    const siblings = (siblingMap[bodyPart] || []).filter(s => s !== name)
    // Look up rich sensation data — key is the Chinese name directly
    const richSensations = getRichEntries('sensations')
    const rich = richSensations[name] || {}
    console.log('Sensation lookup:', name, '-> found:', !!richSensations[name], 'keys:', Object.keys(rich))
    const differsList = Object.keys(rich.differs || {}).map(k => ({ key: k, value: rich.differs[k] }))
    this.setData({
      detailType: 'sensation',
      detailVisible: true,
      detailData: {
        name, bodyPart, relatedParts, siblings,
        description: rich.description || '',
        howItFeels: rich.howItFeels || '',
        commonLocations: rich.commonLocations || [],
        relatedEmotions: rich.relatedEmotions || [],
        signalMeaning: rich.signalMeaning || '',
        selfCare: rich.selfCare || '',
        differs: rich.differs || {},
        differsList: differsList,
        intensitySpectrum: rich.intensitySpectrum || ''
      }
    })
  },

  onShowBodyPartDetail(e) {
    const name = e.currentTarget.dataset.name
    const sensationsMap = app.globalData.emotions ? app.globalData.emotions.sensations : {}
    const sensations = sensationsMap[name] || []
    // Find which emotions commonly relate to this body part (by name matching)
    const relatedEmotions = []
    this.data.categories.forEach(cat => {
      cat.emotions.forEach(em => {
        if (em.definition && em.definition.includes(name)) {
          relatedEmotions.push({ name: em.name, emoji: em.emoji, categoryName: cat.name })
        }
      })
    })
    // Look up rich body part data — key is the Chinese name directly
    const richBodyParts = getRichEntries('bodyParts')
    const rich = richBodyParts[name] || {}
    console.log('BodyPart lookup:', name, '-> found:', !!richBodyParts[name], 'keys:', Object.keys(rich))
    this.setData({
      detailType: 'bodyPart',
      detailVisible: true,
      detailData: {
        name, sensations, relatedEmotions,
        description: rich.description || '',
        howToLocate: rich.howToLocate || '',
        commonSensations: rich.commonSensations || [],
        emotionalConnection: rich.emotionalConnection || '',
        awarenessGuide: rich.awarenessGuide || '',
        culturalNote: rich.culturalNote || ''
      }
    })
  },

  onCloseDetail() {
    this.setData({ detailVisible: false })
  },

  onSearchInput(e) {
    this.setData({ searchQuery: e.detail.value })
    this.applyFilter()
  },

  applyFilter() {
    const q = this.data.searchQuery.trim().toLowerCase()

    if (!q) {
      this.setData({
        filteredCategories: this.data.categories,
        filteredBodyPartSensations: this.data.bodyPartSensations,
        filteredBodyPartList: this.data.bodyPartList
      })
      return
    }

    // Filter emotion categories
    const filteredCategories = this.data.categories.map(cat => {
      const matchedEmotions = cat.emotions.filter(em =>
        em.name.includes(q) || em.definition.includes(q) ||
        (em.similarTo || []).some(s => s.includes(q))
      )
      if (cat.name.includes(q) || matchedEmotions.length > 0) {
        return {
          ...cat,
          emotions: matchedEmotions.length > 0 ? matchedEmotions : cat.emotions,
          count: matchedEmotions.length > 0 ? matchedEmotions.length : cat.count
        }
      }
      return null
    }).filter(Boolean)

    // Filter body part sensations
    const filteredBodyPartSensations = this.data.bodyPartSensations.filter(bp =>
      bp.name.includes(q) || bp.sensations.some(s => s.includes(q))
    )

    // Filter body part list
    const filteredBodyPartList = this.data.bodyPartList.filter(bp =>
      bp.name.includes(q)
    )

    this.setData({
      filteredCategories,
      filteredBodyPartSensations,
      filteredBodyPartList
    })
  },

  onShareAppMessage() {
    return getEmotionShareData()
  }
})
