# WeChat Mini Program — Friend Interaction System

**Date:** 2026-04-12
**Platform:** WeChat-only (no iOS interop)
**Social model:** iOS-style friend list (invite codes, persistent friends, shared feed)
**Privacy:** 3 tiers matching iOS (category / emotions / full)

## Decision Log

| Decision | Choice | Reasoning |
|----------|--------|-----------|
| Cross-platform? | WeChat-only | iOS=CloudKit, WeChat=Tencent Cloud. Different user bases (China vs global). Build WeChat-native first, bridge later if demand. |
| Social model? | iOS-style friend list | User preference. Invite codes, persistent friends, feed with reactions. |
| Privacy tiers? | 3 tiers (match iOS) | Full parity: category-only / emotions+body / full. |

---

## Architecture

### Data Model (WeChat Cloud DB)

**Collection: `user_profiles`**
```
{
  _id: auto,
  _openid: auto (WeChat user ID),
  displayName: String,
  avatarEmoji: String,
  createdAt: serverDate()
}
```

**Collection: `invite_codes`**
```
{
  _id: auto,
  _openid: auto (creator),
  code: String (6-char alphanumeric, unique),
  fromProfileId: String (user_profiles._id),
  expiresAt: Date (24 hours from creation),
  used: Boolean (default false),
  usedBy: String? (accepter's _openid),
  createdAt: serverDate()
}
```

**Collection: `friendships`**
```
{
  _id: auto,
  _openid: auto (creator of the record),
  initiatorOpenId: String,
  accepterOpenId: String,
  initiatorProfileId: String,
  accepterProfileId: String,
  createdAt: serverDate()
}
```
Note: Each friendship creates 2 records (one per user's `_openid`) so both users can query their friendships. WeChat Cloud DB security rules require `_openid` match for reads.

**Collection: `checkins` (existing — add 2 fields)**
```
{
  // ... existing fields unchanged ...
  date, bodySensations, intensity, emotions, note, aiFeedback, triggerEvent, createdAt,

  // NEW: sharing control (no separate shared_checkins table)
  shareLevel: String (null | "category" | "emotions" | "full"),
    // null = private (default, not visible to friends)
    // "category" = only emotion category names + intensity visible
    // "emotions" = emotions + body parts visible
    // "full" = everything visible including trigger, note, AI feedback
  sharedAt: Date? (when sharing was enabled, null if private)
}
```

**No `shared_checkins` collection.** One table, one record per check-in. The `shareLevel` field controls visibility. The friend feed cloud function queries checkins where `shareLevel != null` and filters returned fields based on the tier.

**Why this works:** WeChat Cloud DB requires `_openid` match for direct reads, so friends can't read each other's checkins directly. The `getFriendFeed` cloud function runs with admin privileges and does the cross-user query + field filtering server-side. The client never sees fields above its tier.

**Benefits over copy approach:**
- Single source of truth (no data sync issues)
- User can change sharing level or unshare without deleting a copy
- Check-in edits (if added later) don't need dual updates
- Simpler data model, fewer collections to maintain

**Collection: `reactions`**
```
{
  _id: auto,
  _openid: auto (reactor),
  checkinId: String (references checkins._id),
  checkinOwnerOpenId: String (for querying),
  emoji: String (one of: ❤️ 🤗 🌸 🥺 💪),
  reactorProfileId: String,
  reactorName: String,
  createdAt: serverDate()
}
```

### Data Flow Diagram
```
USER A (sharer)                          USER B (friend)
    │                                        │
    ├─ Creates check-in                      │
    ├─ Selects shareLevel (tier picker)      │
    ├─ Saves to `checkins` with shareLevel   │
    │   (single record, no copy)             │
    │                                        │
    │              CLOUD FUNCTION            │
    │              getFriendFeed              │
    │                    │                   │
    │                    ├─ Query B's friendships
    │                    ├─ Get friend openIds (includes A)
    │                    ├─ Query `checkins`
    │                    │   WHERE _openid IN friendOpenIds
    │                    │   AND shareLevel != null
    │                    ├─ Filter fields by shareLevel:
    │                    │   category → only categories + intensity
    │                    │   emotions → + emotions + body parts
    │                    │   full     → everything
    │                    └──────────────────►├─ Renders feed
    │                                        │
    │         INVITE FLOW:                   │
    ├─ Generates invite_code ──────────────►├─ Enters code
    │                                        ├─ Validates (cloud function)
    │                                        ├─ Creates 2 friendship records
    │                                        └─ Both see each other's shared checkins
    │                                        │
    │         CHANGE SHARING:                │
    ├─ Update shareLevel on existing checkin │
    │   (immediate, no copy/delete needed)   │
```

### Security Rules
- `user_profiles`: read by anyone (for displaying friend names), write only by owner (`_openid` match)
- `invite_codes`: create by anyone, read by anyone (to validate), update only by cloud function
- `friendships`: read only by own records (`_openid` match), create via cloud function only
- `shared_checkins`: read by friends (enforced via cloud function aggregation), write only by owner
- `reactions`: read by shared_checkin owner and friends, write by anyone with a friendship

Note: WeChat Cloud DB auto-injects `_openid` on create and enforces `_openid` match on read by default. For cross-user reads (friend feed), use **cloud functions** which run with admin privileges and can read any user's data.

---

## Pages to Create

### 1. `pages/friends/friends.js|wxml|wxss|json`
**Main friend page** — accessible from settings or a dedicated tab.

**States:**
1. **No profile** → show profile setup (displayName + emoji picker)
2. **No friends** → empty state with "添加好友" button
3. **Has friends** → friend feed

**Layout:**
- Top: friend avatar row (horizontal scroll) + "添加好友" button
- Feed: merged list of shared_checkins from all friends, sorted newest first
- Each card: FriendCheckInCard (see component below)

### 2. `pages/add-friend/add-friend.js|wxml|wxss|json`
**Add friend flow:**
- Tab 1: "我的邀请码" — generate/show code, copy button, share via WeChat button
- Tab 2: "输入好友码" — 6-digit input field, confirm button
- Code validation via cloud function (checks expiry, prevents self-add, prevents duplicate)

### 3. `pages/friend-manage/friend-manage.js|wxml|wxss|json`
**Friend management:**
- List of current friends (emoji + name)
- Swipe-to-delete or long-press to remove friend
- Pending invites (codes you've generated that haven't been used)

---

## Components (inline, not separate pages)

### FriendCheckInCard
Displayed in friend feed. Matches iOS `FriendCheckInCard` layout:
- **Header:** avatar emoji (40rpx circle) + name + relative date + intensity badge
- **Emotions:** chips in per-category colors; category-tier shows deduplicated category names
- **Body:** grouped per-part (part name bold sage + sensations secondary); hidden at category tier
- **AI snippet:** first sentence, "查看完整解读" button opens full AI in a modal; hidden at category/emotions tier
- **Reactions:** horizontal emoji row, tappable, shows reactor names

### Privacy Tier Picker
Used in ai-feedback page when saving. 4 options:
- 🔒 不分享 (private, default)
- 📂 仅类别 (category names only)
- 💬 情绪 (full emotions + body parts)
- 📖 完整 (everything including notes and AI)

### Profile Setup
Inline in friends page (not a separate page):
- Display name text input
- Emoji avatar picker (grid of ~20 common emoji)
- "创建档案" button

---

## Cloud Functions to Create

### `friend-manage` (new cloud function)
Handles all friend operations that need admin privileges:

**Actions (via `action` parameter):**

1. `generateCode` — create a 6-char code in `invite_codes`, return code
2. `validateCode` — check code exists, not expired, not used, not self-invite
3. `acceptInvite` — mark code as used, create 2 friendship records
4. `removeFriend` — delete both friendship records
5. `getFriendFeed` — query friendships, then query shared_checkins for all friend openIds, sort by date desc, paginate

The feed query reads from the single `checkins` collection:
```javascript
// 1. Get my friendships
const friendships = await db.collection('friendships')
  .where({ _openid: event.userInfo.openId })
  .get()

// 2. Extract friend openIds
const friendOpenIds = friendships.data.map(f =>
  f.initiatorOpenId === event.userInfo.openId
    ? f.accepterOpenId
    : f.initiatorOpenId
)

// 3. Get shared check-ins from friends (single table, no copy)
const feed = await db.collection('checkins')
  .where({
    _openid: db.command.in(friendOpenIds),
    shareLevel: db.command.neq(null)  // only shared ones
  })
  .orderBy('date', 'desc')
  .skip(page * 20)
  .limit(21)
  .get()

// 4. Filter fields server-side by shareLevel
const filtered = feed.data.map(checkin => {
  const base = { _id: checkin._id, _openid: checkin._openid,
    date: checkin.date, intensity: checkin.intensity,
    shareLevel: checkin.shareLevel, createdAt: checkin.createdAt }
  if (checkin.shareLevel === 'category') {
    // Deduplicate to category names only
    const categories = [...new Set(checkin.emotions.map(e => e.categoryName))]
    return { ...base, categories }
  }
  if (checkin.shareLevel === 'emotions') {
    return { ...base, emotions: checkin.emotions, bodySensations: checkin.bodySensations }
  }
  // 'full' — everything
  return { ...base, emotions: checkin.emotions, bodySensations: checkin.bodySensations,
    triggerEvent: checkin.triggerEvent, note: checkin.note, aiFeedback: checkin.aiFeedback }
})
```

### `react` (new cloud function)
Toggle a reaction on a shared check-in:
- Check reactor has friendship with check-in owner
- Upsert reaction (same user + same checkin + same emoji = toggle off)

---

## Files to Modify

### `pages/ai-feedback/ai-feedback.wxml` + `.js`
Add privacy tier picker before the save button:
- Show only if user has a profile (check `user_profiles`)
- Default: 不分享
- On save: set `shareLevel` field on the checkin record (no copy needed)
- Changing tier later: update `shareLevel` on the existing record

### `pages/settings/settings.wxml` + `.js`
Add "好友" entry in settings that navigates to `/pages/friends/friends`

### `app.json`
Add new pages:
- `pages/friends/friends`
- `pages/add-friend/add-friend`
- `pages/friend-manage/friend-manage`

### `utils/cloud-db.js`
Add functions:
- `saveProfile(data)` — create/update user_profiles
- `getMyProfile()` — get current user's profile
- `updateShareLevel(checkinId, shareLevel)` — update shareLevel on existing checkin (no copy)
- `toggleReaction(checkinId, emoji)` — call react cloud function

---

## Implementation Order

| Phase | What | Effort | Depends on |
|-------|------|--------|------------|
| 1 | User profile (setup + storage) | S | Nothing |
| 2 | Invite code flow (generate + validate + accept) | M | Phase 1 |
| 3 | Privacy tier picker in ai-feedback (set shareLevel on save) | S | Phase 1 |
| 4 | Friend feed cloud function (query + field filter) | M | Phase 2 |
| 5 | Friend feed page + FriendCheckInCard | M | Phase 4 |
| 6 | Emoji reactions | S | Phase 5 |
| 7 | Friend management (list + remove) | S | Phase 2 |

**Total estimated effort:** M (human: ~2.5 days / CC: ~1.5 hours)
Note: One fewer phase than the copy approach — no "shared check-in write" step needed.

---

## Privacy Tier Display Rules

| Field | category | emotions | full |
|-------|----------|----------|------|
| Intensity badge | ✅ | ✅ | ✅ |
| Emotion categories (deduplicated) | ✅ | — | — |
| Emotion names + emoji | — | ✅ | ✅ |
| Body parts + sensations | — | ✅ | ✅ |
| Trigger event | — | — | ✅ |
| Note | — | — | ✅ |
| AI feedback | — | — | ✅ |

---

## Per-Person Card Tint (matching iOS)

Each friend's cards get a consistent warm tint, deterministically assigned:

| Index | Color | Hex |
|-------|-------|-----|
| 0 | sage | #E0EDE2 |
| 1 | peach | #FEEBD8 |
| 2 | lavender | #EAE5F2 |
| 3 | wheat | #F5EDDA |
| 4 | sky | #E3EEF3 |

Assignment: `tintIndex = hashCode(friendOpenId) % 5`

---

## Reaction Emoji Set (matching iOS)

5 reaction emoji (same as iOS `ReactionRecord.allEmojis`):
❤️ 🤗 🌸 🥺 💪

---

## NOT in Scope

- Cross-platform iOS ↔ WeChat interop (separate backends)
- Moments sharing (requires WeChat platform approval)
- Group sharing (share to WeChat group chat as a social unit)
- Friend request approval flow (accepting an invite is immediate)
- Block/mute friend
- Friend count limit
- Shared daily journals (iOS supports this but it's secondary)

---

## Open Questions

1. **Tab bar:** Should "好友" become a 4th tab (matching iOS), or stay accessible from settings? If 4th tab, WeChat tab bar supports max 5 items. Currently using 3 (此刻/日记/觉察词典). Adding 好友 = 4 tabs, which matches iOS exactly.

2. **Invite code length:** iOS uses 6-char. Should WeChat match? 6 chars is easy to type and share in chat.

3. **Code expiry:** iOS uses 24 hours. Keep the same?

4. **Feed pagination:** How many items per page? iOS loads all. WeChat should paginate (20 per page suggested).
