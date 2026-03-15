import SwiftUI

/// Renders a multi-line Markdown string with proper bold, italic, and newline support.
/// SwiftUI's Text only renders Markdown when given a LocalizedStringKey — this view
/// splits the raw string by newlines and feeds each line as LocalizedStringKey.
struct MarkdownText: View {
    let raw: String
    var font: Font = .body
    var paragraphSpacing: CGFloat = 6
    var lineSpacing: CGFloat = 4

    private var lines: [String] { raw.components(separatedBy: "\n") }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                if line.trimmingCharacters(in: .whitespaces).isEmpty {
                    // Empty line = paragraph break
                    Spacer().frame(height: paragraphSpacing)
                } else {
                    Text(LocalizedStringKey(line))
                        .font(font)
                        .lineSpacing(lineSpacing)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
