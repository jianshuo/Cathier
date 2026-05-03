const { getMyProfile, saveProfile } = require('../../utils/cloud-db')
const { getDefaultShareData, getDefaultTimelineData } = require('../../utils/share')

const CATEGORY_COLORS = {
  '激情': '#FF5933',
  '快乐': '#FFBF00',
  '平静': '#33ADE6',
  '爱与关怀': '#F272A5',
  '愤怒': '#F54538',
  '恐惧': '#AD52DE',
  '悲伤': '#5C8ABF',
  '羞愧': '#8C6647',
  '惊讶': '#FF9400'
}

const CARD_TINTS = ['#E0EDE2', '#FEEBD8', '#EAE5F2', '#F5EDDA', '#E3EEF3']

const REACTION_EMOJIS = ['❤️', '🤗', '🌸', '🥺', '💪']

const AVATAR_EMOJIS = [
  '🙂', '😊', '😄', '🥰', '😎', '🤗', '🌟', '🌈', '🌸', '🍀',
  '🐱', '🐶', '🦊', '🐼', '🌻', '🎯', '💪', '✨', '🎵', '🌙'
]

function hashCode(str) {
  let hash = 0
  for (let i = 0; i < str.length; i++) {
    hash = ((hash << 5) - hash) + str.charCodeAt(i)
    hash |= 0
  }
  return Math.abs(hash)
}

function getIntensityInfo(intensity) {
  if (intensity <= 0) return { color: '', label: '' }
  if (intensity <= 3) return { color: '#FFBF00', label: '轻微' }
  if (intensity <= 6) return { color: '#F2700A', label: '中等' }
  if (intensity <= 8) return { color: '#D96308', label: '较强' }
  return { color: '#F54538', label: '强烈' }
}

function relativeTime(dateStr) {
  const now = new Date()
  const date = new Date(dateStr)
  const diffMs = now - date
  const diffMin = Math.floor(diffMs / 60000)
  if (diffMin < 1) return '刚刚'
  if (diffMin < 60) return diffMin + '分钟前'
  const diffHour = Math.floor(diffMin / 60)
  if (diffHour < 24) return diffHour + '小时前'
  const diffDay = Math.floor(diffHour / 24)
  if (diffDay < 7) return diffDay + '天前'
  const m = date.getMonth() + 1
  const d = date.getDate()
  return m + '月' + d + '日'
}

Page({
  data: {
    // State: 'loading' | 'no-profile' | 'no-friends' | 'has-friends'
    state: 'loading',
    // Profile setup
    profile: null,
    setupName: '',
    setupEmoji: '🙂',
    avatarEmojis: AVATAR_EMOJIS,
    // Friends
    friends: [],
    // Feed
    feedItems: [],
    feedPage: 0,
    feedHasMore: true,
    feedLoading: false,
    // AI modal
    showAiModal: false,
    aiModalContent: '',
    // Reaction emojis
    reactionEmojis: REACTION_EMOJIS
  },

  onLoad(options) {
    this._pendingInviteCode = options.inviteCode || null
    this.initPage()
  },

  onShow() {
    if (this.data.profile) {
      this.loadFriendFeed(true)
    }
  },

  onPullDownRefresh() {
    if (this.data.profile) {
      this.loadFriendFeed(true)
    } else {
      wx.stopPullDownRefresh()
    }
  },

  onReachBottom() {
    if (this.data.feedHasMore && !this.data.feedLoading && this.data.state === 'has-friends') {
      this.loadFriendFeed(false)
    }
  },

  async initPage() {
    this.setData({ state: 'loading' })
    try {
      const profile = await getMyProfile()
      if (!profile) {
        this.setData({ state: 'no-profile' })
        return
      }
      this.setData({ profile })

      // Handle invite code from share card
      if (this._pendingInviteCode) {
        await this._handleInviteCode(this._pendingInviteCode)
        this._pendingInviteCode = null
      }

      await this.loadFriendFeed(true)
    } catch (err) {
      console.error('Init friends page failed:', err)
      this.setData({ state: 'no-profile' })
    }
  },

  async _handleInviteCode(code) {
    try {
      // First validate
      const validateRes = await wx.cloud.callFunction({
        name: 'friend-manage',
        data: { action: 'validateCode', code }
      })
      const vResult = validateRes.result || {}
      if (!vResult.success) {
        wx.showToast({ title: vResult.message || '邀请码无效', icon: 'none' })
        return
      }

      // Show confirmation
      const inviterName = vResult.inviterName || '好友'
      const inviterEmoji = vResult.inviterEmoji || '🙂'
      const confirmed = await new Promise(resolve => {
        wx.showModal({
          title: '好友邀请',
          content: `${inviterEmoji} ${inviterName} 邀请你成为好友`,
          confirmText: '接受',
          cancelText: '拒绝',
          success: res => resolve(res.confirm)
        })
      })

      if (!confirmed) return

      // Accept
      const acceptRes = await wx.cloud.callFunction({
        name: 'friend-manage',
        data: { action: 'acceptInvite', code }
      })
      const aResult = acceptRes.result || {}
      if (aResult.success) {
        wx.showToast({ title: '添加成功！', icon: 'success' })
      } else {
        wx.showToast({ title: aResult.message || '添加失败', icon: 'none' })
      }
    } catch (err) {
      console.error('Handle invite code failed:', err)
      wx.showToast({ title: '操作失败', icon: 'none' })
    }
  },

  // --- Profile Setup ---
  onSetupNameInput(e) {
    this.setData({ setupName: e.detail.value })
  },

  onSelectEmoji(e) {
    this.setData({ setupEmoji: e.currentTarget.dataset.emoji })
  },

  async onCreateProfile() {
    const { setupName, setupEmoji } = this.data
    if (!setupName.trim()) {
      wx.showToast({ title: '请输入昵称', icon: 'none' })
      return
    }
    try {
      const profile = await saveProfile({
        displayName: setupName.trim(),
        avatarEmoji: setupEmoji
      })
      this.setData({ profile })

      // If there's a pending invite from share card, handle it now
      if (this._pendingInviteCode) {
        await this._handleInviteCode(this._pendingInviteCode)
        this._pendingInviteCode = null
      }

      await this.loadFriendFeed(true)
    } catch (err) {
      console.error('Create profile failed:', err)
      wx.showToast({ title: '创建失败，请重试', icon: 'none' })
    }
  },

  // --- Friend Feed ---
  async loadFriendFeed(refresh) {
    if (refresh) {
      this.setData({ feedPage: 0, feedItems: [], feedHasMore: true })
    }
    this.setData({ feedLoading: true })

    try {
      const res = await wx.cloud.callFunction({
        name: 'friend-manage',
        data: {
          action: 'getFriendFeed',
          page: refresh ? 0 : this.data.feedPage
        }
      })

      const result = res.result || {}
      const friends = result.friends || []
      const feedData = result.data || []
      const hasMore = result.hasMore || false

      if (friends.length === 0 && feedData.length === 0 && refresh) {
        this.setData({
          state: 'no-friends',
          friends: [],
          feedItems: [],
          feedLoading: false
        })
        wx.stopPullDownRefresh()
        return
      }

      // Format feed items
      const formatted = feedData.map(item => {
        const tintIndex = hashCode(item.ownerOpenId || '') % 5
        const tintColor = CARD_TINTS[tintIndex]
        const intensityInfo = getIntensityInfo(item.intensity || 0)
        const dateRelative = relativeTime(item.date || item.createdAt)

        // Build emotion chips
        let emotionChips = []
        if (item.shareLevel === 'category' && item.categories) {
          emotionChips = item.categories.map(cat => ({
            label: cat,
            color: CATEGORY_COLORS[cat] || '#8A837A'
          }))
        } else if (item.emotions) {
          emotionChips = (item.emotions || []).map(em => ({
            label: (em.emoji || '') + ' ' + (em.name || em.label || ''),
            color: CATEGORY_COLORS[em.categoryName] || '#8A837A'
          }))
        }

        // Build body groups
        let bodyGroups = []
        if (item.shareLevel !== 'category' && item.bodySensations) {
          const bs = item.bodySensations
          bodyGroups = Object.keys(bs).map(part => ({
            part,
            sensationsText: (bs[part] || []).join('、')
          }))
        }

        // AI snippet
        let aiSnippet = ''
        let aiFull = ''
        if (item.shareLevel === 'full' && item.aiFeedback) {
          aiFull = item.aiFeedback
          aiSnippet = item.aiFeedback.substring(0, 80)
          if (item.aiFeedback.length > 80) aiSnippet += '...'
        }

        // Reactions
        const reactions = (item.reactions || []).map(r => ({
          emoji: r.emoji,
          names: (r.reactors || []).map(x => x.name).join('、'),
          reacted: r.reacted || false,
          count: (r.reactors || []).length
        }))

        return {
          _id: item._id,
          ownerOpenId: item.ownerOpenId,
          ownerName: item.ownerName || '好友',
          ownerEmoji: item.ownerEmoji || '🙂',
          dateRelative,
          intensity: item.intensity || 0,
          intensityColor: intensityInfo.color,
          intensityLabel: intensityInfo.label,
          tintColor,
          shareLevel: item.shareLevel,
          emotionChips,
          bodyGroups,
          aiSnippet,
          aiFull,
          trigger: item.triggerEvent || '',
          note: item.note || '',
          reactions
        }
      })

      const allFeedItems = refresh ? formatted : this.data.feedItems.concat(formatted)

      this.setData({
        state: 'has-friends',
        friends,
        feedItems: allFeedItems,
        feedHasMore: hasMore,
        feedLoading: false,
        feedPage: (refresh ? 0 : this.data.feedPage) + 1
      })
    } catch (err) {
      console.error('Load friend feed failed:', err)
      this.setData({ feedLoading: false, state: this.data.friends.length > 0 ? 'has-friends' : 'no-friends' })
    }
    wx.stopPullDownRefresh()
  },

  // --- Navigation ---
  onAddFriend() {
    wx.navigateTo({ url: '/pages/add-friend/add-friend' })
  },

  onManageFriends() {
    wx.navigateTo({ url: '/pages/friend-manage/friend-manage' })
  },

  // --- Reactions ---
  async onReaction(e) {
    const { checkinId, emoji } = e.currentTarget.dataset
    try {
      await wx.cloud.callFunction({
        name: 'friend-manage',
        data: {
          action: 'react',
          checkinId,
          emoji
        }
      })
      // Reload feed to reflect updated reactions
      this.loadFriendFeed(true)
    } catch (err) {
      console.error('Reaction failed:', err)
      wx.showToast({ title: '操作失败', icon: 'none' })
    }
  },

  // --- AI Modal ---
  onShowAiModal(e) {
    const content = e.currentTarget.dataset.content
    this.setData({ showAiModal: true, aiModalContent: content })
  },

  onCloseAiModal() {
    this.setData({ showAiModal: false, aiModalContent: '' })
  },

  onShareAppMessage() {
    return getDefaultShareData({
      title: '一起在「觉察」里相互陪伴情绪'
    })
  },

  onShareTimeline() {
    return getDefaultTimelineData()
  }
})
