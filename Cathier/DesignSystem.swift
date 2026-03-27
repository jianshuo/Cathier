import SwiftUI

// MARK: - Cathier Design Tokens
// Defined in DESIGN.md. Color values live in Assets.xcassets color sets.
// Update both DESIGN.md and the .colorset JSON files if tokens change.

extension Color {

    // MARK: Accent — Terracotta (#C4614A light / #D4745E dark)
    static let cathierAccent      = Color("cathierAccent")
    static let cathierAccentLight = Color("cathierAccentLight")

    // MARK: Sage — Friend & Growth (#6B8F71 light / #7DA384 dark)
    static let cathierSage      = Color("cathierSage")
    static let cathierSageLight = Color("cathierSageLight")

    // MARK: Background
    /// Warm paper: #F7F5F1 light / #1C1714 dark
    static let cathierBackground = Color("cathierBackground")
    /// Card surface: #FFFFFF light / #2A2420 dark
    static let cathierSurface    = Color("cathierSurface")
}

// MARK: - Typography

extension Font {
    /// Instrument Serif for reflection moments: check-in prompts, AI feedback, pattern insights.
    ///
    /// To activate: add InstrumentSerif-Regular.ttf and InstrumentSerif-Italic.ttf to the
    /// Xcode project target, then add both file names under UIAppFonts in Info.plist.
    /// Until then, iOS falls back to the system serif (Georgia).
    static func cathierSerif(_ textStyle: Font.TextStyle = .body, italic: Bool = false) -> Font {
        let name = italic ? "InstrumentSerif-Italic" : "InstrumentSerif-Regular"
        return Font.custom(name, size: textStylePointSize(textStyle), relativeTo: textStyle)
    }

    private static func textStylePointSize(_ style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle:  return 34
        case .title:       return 28
        case .title2:      return 22
        case .title3:      return 20
        case .headline:    return 17
        case .body:        return 17
        case .callout:     return 16
        case .subheadline: return 15
        case .footnote:    return 13
        case .caption:     return 12
        case .caption2:    return 11
        @unknown default:  return 17
        }
    }
}
