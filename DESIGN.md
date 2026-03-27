# Design System — Cathier

## Product Context
- **What this is:** An iOS app for daily emotion awareness practice — body scans, emotion labeling (80+ words), AI-assisted reflection, and optional friend sharing.
- **Who it's for:** People who want to go deeper with emotional self-awareness, not casual mood loggers. Practitioners, not patients.
- **Space/industry:** Wellness / emotion tracking. Peers: How We Feel, Daylio, Reflectly, Finch, Moodnotes.
- **Project type:** Native iOS app (SwiftUI / iOS 26.2)

## Aesthetic Direction
- **Direction:** Organic / Notebook — warm, grounded, quiet. Like a quality Japanese stationery brand or a Moleskine, not a wellness product.
- **Decoration level:** Intentional — subtle warm paper texture on key surfaces (check-in cards, AI feedback). Sparse use only.
- **Mood:** The app should feel like a focused practice space. Calm but present. Not therapeutic reassurance — not a comfort object. Something you open because you want to go deeper.
- **Design thesis:** Every wellness app uses pastels and rounded "baby" forms because they assume fragile users. Cathier's users are practitioners. The name 情绪感知训练 (emotion perception training) says it clearly. Design for active practice, not reassurance.
- **Reference:** Moleskine, Hobonichi Techo, Japanese stationery brands. Moodnotes by ustwo (for the "clinical precision + non-clinical look" balance).

## Typography

### Typefaces
- **Display / Reflection:** Instrument Serif (Google Fonts) — used for check-in prompts, AI feedback card text, Pattern Insights headlines, hero moments. Adds a journal/editorial personality no competitor uses.
- **UI / Body:** SF Pro Text / SF Pro Display (system) — all interface text, labels, body copy, navigation. iOS native, handles Dynamic Type automatically.
- **Data / Numbers:** SF Mono (system) — intensity scores, check-in counts, body scan percentages. Use `monospacedDigit` modifier for tabular-nums alignment.

### When to use Instrument Serif
Use it for moments that should feel like reading a journal entry — not for UI chrome:
- Check-in prompt questions ("Where in your body did you feel something shift today?")
- AI feedback body text
- Pattern Insights body text
- Empty state headlines with emotional resonance
- Do NOT use for tab labels, buttons, form labels, navigation titles

### Type Scale (Dynamic Type base)
| Level | iOS Style | Size (default) | Weight | Usage |
|-------|-----------|----------------|--------|-------|
| Large Title | largeTitle | 34pt | Regular | Screen titles (此刻, 日记) |
| Title 1 | title | 28pt | Regular | Section headers |
| Title 2 | title2 | 22pt | Semibold | Card titles, subheadings |
| Headline | headline | 17pt | Semibold | List row titles |
| Body | body | 17pt | Regular | All body copy |
| Callout | callout | 16pt | Regular | Secondary body |
| Subhead | subheadline | 15pt | Regular | Supporting text |
| Footnote | footnote | 13pt | Regular | Timestamps, captions |
| Caption | caption | 12pt | Medium | Labels, chips, metadata |
| Caption 2 | caption2 | 11pt | Semibold + uppercase + 0.08em tracking | Section labels |

All sizes use iOS Dynamic Type — never hardcode font sizes. Use `.font(.body)`, `.font(.caption)` etc.

## Color

### Approach
Restrained — one bright energetic accent (orange) + warm neutrals. Color is rare and meaningful. The warm off-white background is a deliberate departure from the pure-white iOS default — it makes the app feel analog, physical, present.

### Light Mode Palette
```
Background:      #F7F5F1  — warm off-white, like paper. Not pure white.
Surface:         #FFFFFF  — cards, sheets, inputs
Surface Alt:     #FAF9F7  — grouped table backgrounds
Border:          #E0DDD6  — warm gray borders
Text Primary:    #1A1613  — near-black, warm undertone
Text Secondary:  #5C5650  — secondary text
Text Muted:      #8A837A  — timestamps, captions, placeholders

Accent:          #F2700A  — bright orange. Primary brand color. Used sparingly.
Accent Light:    #FEEBD8  — orange tint. Chip backgrounds, AI card header.
Accent Hover:    #D96308  — pressed/hover state for orange elements.

Sage:            #6B8F71  — secondary accent. Positive states, friend features, growth.
Sage Light:      #E0EDE2  — sage tint. Shared check-ins, positive chips.

Semantic Success: #6B8F71 (sage)
Semantic Warning: #B45309
Semantic Error:   #C4614A (accent)
Semantic Info:    #1D4ED8
```

### Dark Mode Palette
```
Background:      #1C1714  — deep walnut. Not pure black.
Surface:         #2A2420
Surface Alt:     #231F1B
Border:          #3D3630
Text Primary:    #F0EDE8
Text Secondary:  #B5AFA9
Text Muted:      #7A736D

Accent:          #F5861A  — slightly lighter orange for dark backgrounds
Accent Light:    #3D2210
Sage:            #7DA384
Sage Light:      #1E2E20
```

### SwiftUI Color Tokens
Define these in an `Assets.xcassets` color set with light/dark variants:
```
cathierBackground, cathierSurface, cathierSurfaceAlt
cathierBorder
cathierTextPrimary, cathierTextSecondary, cathierTextMuted
cathierAccent, cathierAccentLight
cathierSage, cathierSageLight
```

## Spacing

- **Base unit:** 8pt
- **Density:** Comfortable — screens should feel like turning pages, not scrolling a feed.

| Token | Value | Usage |
|-------|-------|-------|
| 2xs | 2pt | Micro gaps within a component |
| xs | 4pt | Icon gaps, tight inline elements |
| sm | 8pt | Chip gaps, list row internal spacing |
| md | 16pt | Card padding, section internal gaps |
| lg | 20pt | Screen horizontal margins |
| xl | 24pt | Between sections on a screen |
| 2xl | 32pt | Between major content groups |
| 3xl | 48pt | Above primary CTAs, between hero elements |

**Screen margins:** 20pt horizontal (matches iOS standard). Never go below 16pt.

## Layout

- **Approach:** Grid-disciplined for navigation / data screens. Editorial moments for reflection / insights screens where Instrument Serif appears.
- **Safe area:** Always respect safeAreaInsets. Bottom content should never be cut off by home indicator.
- **Tab bar:** System UITabBar with custom tint = cathierAccent.
- **Sheet presentations:** Use `.presentationDetents` with `.medium` and `.large`. Sheet background = cathierSurface.
- **Max content width:** N/A for iOS full-screen, but limit text blocks to ~680pt on iPad.

## Border Radius

| Token | Value | Usage |
|-------|-------|-------|
| Tight | 4pt | Small inputs, segmented controls |
| Small | 8pt | List row separators, inline tags |
| Medium | 12pt | Cards, check-in cards, AI feedback |
| Large | 20pt | Bottom sheets, modal surfaces |
| Full | 9999pt | Buttons, pills, chips |

Use `.cornerRadius()` or `.clipShape(RoundedRectangle(cornerRadius:))`. Prefer continuous corners: `RoundedRectangle(cornerRadius: 12, style: .continuous)`.

## Motion

- **Approach:** Intentional — slow, deliberate transitions. Nothing bouncy or springy.
- **Guiding principle:** The check-in flow should feel like a quiet ritual, not a gamified app.

| Token | Curve | Duration | Usage |
|-------|-------|----------|-------|
| Micro | easeOut | 0.10s | Tap feedback, toggle state |
| Short | easeOut | 0.20s | Button press, chip select |
| Medium | easeInOut | 0.35s | Card appear, modal open |
| Long | easeInOut | 0.50s | Check-in flow step transitions |

**SwiftUI:**
- Use `withAnimation(.easeInOut(duration: 0.35))` for card appearances
- Use `transition(.opacity.combined(with: .move(edge: .bottom)))` for sheet content
- Avoid `.spring()` — it undermines the calm, deliberate feel
- For the check-in step transitions: `AnyTransition.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))` with `.easeInOut(duration: 0.5)`

## AI Reflection Visual Language

The AI feedback card is a key brand moment. It should feel like reading a thoughtful note, not a chatbot response.

- **Container:** `cathierSurface` background, `cathierBorder` stroke, `cornerRadius: 12, style: .continuous`
- **Header strip:** `cathierAccentLight` background, "Cathier AI" label in `caption2` style, terracotta dot indicator
- **Body text:** Instrument Serif, 17pt regular, `cathierTextPrimary`, 1.55 line height
- **Key words in body text:** can be emphasized with `cathierAccent` color (for emotion words user labeled)
- **Footer:** "Save" and "Share" in `caption` style, `cathierAccent` and `cathierTextMuted` respectively

## Check-in Flow Design

The 3-step flow (Body Scan → Emotion Labeling → AI Feedback) is the core product loop. Each step should feel discrete and focused.

### Progress indicator
Simple segmented bar at the bottom, not a progress ring. 3 segments, filled in `cathierAccent`. Height: 4pt. Bottom aligned above home indicator.

### Step transitions
`AnyTransition.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))` — moves forward like turning pages.

### Body area chips (Step 1)
- Unselected: `cathierBackground` fill, `cathierBorder` stroke, `cathierTextSecondary` text
- Selected: `cathierAccentLight` fill, `cathierAccent` stroke, `cathierAccent` text
- `cornerRadius: 9999` (full pill)

### Emotion chips (Step 2)
- Same chip style as body areas
- Positive/growth emotions: use sage variant (`cathierSageLight` / `cathierSage`) instead of terracotta

## Friend Feature Visual Language

Friend-related UI should feel warm but distinct from the core check-in flow.

- Shared check-in cards: `cathierSageLight` background tint with `cathierSage` accent
- "Shared with friends" indicators: sage color, not terracotta
- Privacy tier labels: clearly readable, `caption2` style, never ambiguous

## Accessibility

- All colors must pass WCAG AA contrast. Check especially: `cathierTextMuted` on `cathierBackground` (target ≥ 4.5:1)
- Support Dynamic Type — never hardcode font sizes
- All interactive elements minimum 44×44pt tap target
- VoiceOver labels on all icon-only buttons
- Reduce Motion: when `accessibilityReduceMotion` is true, use `.opacity` transitions only (no movement)

## Anti-patterns

Never do these in Cathier UI:
- Gradient backgrounds or gradient buttons
- Multiple accent colors on one screen (pick terracotta OR sage for a given component, not both)
- Bouncy spring animations
- Dense icon grids (3-column feature layouts)
- Pure white (#FFFFFF) as the screen background — use cathierBackground (#F7F5F1) for full-screen backgrounds
- SF Pro for moments that should feel like journal entries — that's what Instrument Serif is for
- Generic stock imagery or decorative blobs

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-03-27 | Initial design system created | /design-consultation based on competitive research + product context |
| 2026-03-27 | Terracotta (#C4614A) as primary accent | No emotion app in category uses warm earthy red. Distinctive in App Store screenshots. Evokes physical/body presence, appropriate for body scan feature. |
| 2026-03-27 | Updated accent to bright orange (#F2700A) | Terracotta read too dark and heavy in practice. Bright orange (#F2700A) is vivid and energetic — keeps the warm identity while actually reading as a strong accent color. Dark mode uses #F5861A. |
| 2026-03-27 | Instrument Serif for AI reflection text | Every competitor uses clean sans throughout. Serif for reflection moments creates "journal" personality that is genuinely different. |
| 2026-03-27 | Warm off-white (#F7F5F1) background | Makes the app feel analog and physical — reinforces body-awareness theme. Deliberate departure from default iOS pure white. |
| 2026-03-27 | No spring animations | The check-in flow should feel like a quiet ritual. Bouncy motion undermines the calm, deliberate feel of emotion awareness practice. |
| 2026-03-27 | Sage (#6B8F71) as secondary accent for friend/positive states | Keeps terracotta focused as the primary brand signal. Sage = growth, connection, calm. |
