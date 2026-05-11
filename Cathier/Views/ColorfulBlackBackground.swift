import SwiftUI

/// Animated 3×3 MeshGradient background using near-black colors tinted with each of
/// Cathier's 9 emotion-category hues — 五彩斑斓的黑 (colorful black).
///
/// Dark mode only. Light mode falls back to cathierBackground.
/// Reduce Motion: static gradient (no drifting center).
struct ColorfulBlackBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // 3×3 grid — all < 11% lightness so the surface reads as black.
    private let meshColors: [Color] = [
        Color(hex: "#1C1714")!, // top-left:    warm walnut      (design-system base)
        Color(hex: "#09101C")!, // top-center:  dark sapphire    (平静 / 悲伤)
        Color(hex: "#140B18")!, // top-right:   dark amethyst    (恐惧)
        Color(hex: "#091510")!, // mid-left:    dark sage        (平静)
        Color(hex: "#2A1A08")!, // center:      dark amber       (快乐 / 激情) — drifts
        Color(hex: "#1C0B0A")!, // mid-right:   dark crimson     (愤怒)
        Color(hex: "#0D1020")!, // bot-left:    dark indigo      (悲伤)
        Color(hex: "#1C0B10")!, // bot-center:  dark rose        (爱与关怀)
        Color(hex: "#0F1408")!, // bot-right:   dark olive       (惊讶)
    ]

    var body: some View {
        if colorScheme == .dark {
            if reduceMotion {
                MeshGradient(
                    width: 3, height: 3,
                    points: basePoints,
                    colors: meshColors
                )
                .ignoresSafeArea()
            } else {
                TimelineView(.animation) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    MeshGradient(
                        width: 3, height: 3,
                        points: driftedPoints(t: t),
                        colors: meshColors
                    )
                }
                .ignoresSafeArea()
            }
        } else {
            Color.cathierBackground
                .ignoresSafeArea()
        }
    }

    // Static 3×3 grid of evenly-spaced SIMD2<Float> control points.
    private var basePoints: [SIMD2<Float>] {
        [
            [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
            [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
            [0.0, 1.0], [0.5, 1.0], [1.0, 1.0],
        ]
    }

    // Center point drifts in a slow Lissajous loop.
    // x-period ≈ 113 s, y-period ≈ 179 s → ~3-minute visual cycle, never repeating exactly.
    private func driftedPoints(t: Double) -> [SIMD2<Float>] {
        let cx = Float(0.5 + 0.06 * sin(t * 2 * .pi / 113))
        let cy = Float(0.5 + 0.06 * cos(t * 2 * .pi / 179))
        return [
            [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
            [0.0, 0.5], [cx,  cy ], [1.0, 0.5],
            [0.0, 1.0], [0.5, 1.0], [1.0, 1.0],
        ]
    }
}
