import SwiftUI

/// Renders a multi-line Markdown string with proper bold, italic, and newline support.
/// Uses AttributedString for dynamic string markdown parsing (LocalizedStringKey only
/// works for static strings at compile time).
struct MarkdownText: View {
    let raw: String
    var font: Font = .body
    var paragraphSpacing: CGFloat = 6
    var lineSpacing: CGFloat = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                if paragraph.isEmpty {
                    Spacer().frame(height: paragraphSpacing)
                } else {
                    if let attributedString = try? AttributedString(
                        markdown: paragraph,
                        options: AttributedString.MarkdownParsingOptions(
                            interpretedSyntax: .inlineOnlyPreservingWhitespace
                        )
                    ) {
                        Text(attributedString)
                            .font(font)
                            .lineSpacing(lineSpacing)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(paragraph)
                            .font(font)
                            .lineSpacing(lineSpacing)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Split by double newlines for paragraph-aware rendering
    private var paragraphs: [String] {
        raw.components(separatedBy: "\n\n")
            .flatMap { $0.components(separatedBy: "\n") }
    }
}
