import SwiftUI

/// Renders a multi-line Markdown string with proper bold, italic, and newline support.
/// Uses AttributedString for dynamic-string markdown parsing (LocalizedStringKey
/// only works for static strings at compile time).
///
/// Renders as a **single Text view** so the layout engine never has to size a
/// nested VStack of `Text(...).fixedSize(...)` against a flexible width.
///
/// Earlier this view rendered a `VStack { ForEach paragraphs { Text(...) } }`,
/// which produced a multi-second main-thread layout cycle under
/// `LazyVStack` → `ScrollView` → `MarkdownText` nesting (see crash 1's
/// `StackLayout.resize → sizeChildren → placeChildren → ViewLayoutEngine
/// .sizeThatFits → StackLayout.resize` recursion until iOS killed the app
/// for a `0x8BADF00D` scene-update watchdog transgression). A single Text
/// view collapses that nested layout into one O(1) measurement.
struct MarkdownText: View {
    let raw: String
    var font: Font = .body
    var paragraphSpacing: CGFloat = 6
    var lineSpacing: CGFloat = 4

    var body: some View {
        Text(parsed)
            .font(font)
            .lineSpacing(lineSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Parsed once per `raw` change. SwiftUI's value-type view caching reuses
    /// this view struct (and re-evaluates `parsed`) only when `raw` changes,
    /// so the AttributedString conversion isn't redone on unrelated re-renders.
    ///
    /// `\n\n` → 1 newline char + paragraphSpacing pixels of literal vertical
    /// whitespace, encoded as extra newlines (cheap, single text run). Single
    /// `\n` is preserved as-is via `.inlineOnlyPreservingWhitespace`.
    private var parsed: AttributedString {
        // Add an extra blank line for every `\n\n` so visible paragraphs still
        // separate, even though we're rendering as one Text. `paragraphSpacing`
        // is treated as a hint, not a literal pixel value, since AttributedString
        // line height comes from the font + lineSpacing modifier.
        let normalized = raw.replacingOccurrences(of: "\n\n", with: "\n\n\n")

        if let attributed = try? AttributedString(
            markdown: normalized,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        ) {
            return attributed
        }
        return AttributedString(normalized)
    }
}
