import SwiftUI
import UIKit

// MARK: - Cathier Design Tokens
// Defined in DESIGN.md. Update both files if tokens change.

extension Color {

    // MARK: Accent — Terracotta
    /// #C4614A light / #D4745E dark
    static let cathierAccent = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.831, green: 0.455, blue: 0.369, alpha: 1) // #D4745E
            : UIColor(red: 0.769, green: 0.380, blue: 0.290, alpha: 1) // #C4614A
    })

    /// Terracotta tint: #F2E3DF light / #3A2420 dark
    static let cathierAccentLight = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.227, green: 0.141, blue: 0.125, alpha: 1) // #3A2420
            : UIColor(red: 0.949, green: 0.890, blue: 0.875, alpha: 1) // #F2E3DF
    })

    // MARK: Sage — Friend & Growth
    /// #6B8F71 light / #7DA384 dark
    static let cathierSage = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.490, green: 0.639, blue: 0.518, alpha: 1) // #7DA384
            : UIColor(red: 0.420, green: 0.561, blue: 0.443, alpha: 1) // #6B8F71
    })

    /// Sage tint: #E0EDE2 light / #1E2E20 dark
    static let cathierSageLight = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.118, green: 0.180, blue: 0.125, alpha: 1) // #1E2E20
            : UIColor(red: 0.878, green: 0.929, blue: 0.886, alpha: 1) // #E0EDE2
    })

    // MARK: Background
    /// Warm paper: #F7F5F1 light / #1C1714 dark
    static let cathierBackground = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.110, green: 0.090, blue: 0.078, alpha: 1) // #1C1714
            : UIColor(red: 0.969, green: 0.961, blue: 0.945, alpha: 1) // #F7F5F1
    })

    /// Card surface: #FFFFFF light / #2A2420 dark
    static let cathierSurface = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.165, green: 0.141, blue: 0.125, alpha: 1) // #2A2420
            : UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1)        // #FFFFFF
    })
}

// MARK: - Typography

extension Font {
    /// Instrument Serif for reflection moments — check-in prompts, AI feedback, insights.
    /// NOTE: Add InstrumentSerif-Regular.ttf and InstrumentSerif-Italic.ttf to the Xcode
    /// project target and register under UIAppFonts in Info.plist. Until then, falls back
    /// to the system serif (Georgia on iOS).
    static func cathierSerif(_ textStyle: Font.TextStyle, italic: Bool = false) -> Font {
        let name = italic ? "InstrumentSerif-Italic" : "InstrumentSerif-Regular"
        return Font.custom(name, size: textStyleSize(textStyle), relativeTo: textStyle)
    }

    static func cathierSerif(size: CGFloat, italic: Bool = false) -> Font {
        let name = italic ? "InstrumentSerif-Italic" : "InstrumentSerif-Regular"
        return Font.custom(name, size: size)
    }

    private static func textStyleSize(_ style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle:    return 34
        case .title:         return 28
        case .title2:        return 22
        case .title3:        return 20
        case .headline:      return 17
        case .body:          return 17
        case .callout:       return 16
        case .subheadline:   return 15
        case .footnote:      return 13
        case .caption:       return 12
        case .caption2:      return 11
        @unknown default:    return 17
        }
    }
}
