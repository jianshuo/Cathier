import SwiftUI

private struct SheetItem: Identifiable {
    let id = UUID()
    let entry: DictionaryEntry
    enum Kind { case sensation, bodyPart }
    let kind: Kind
}

struct BodyScanView: View {
    @Environment(CheckInViewModel.self) private var viewModel
    @Environment(ConfigService.self) private var config
    @Environment(LanguageManager.self) private var lm

    @State private var sheetItem: SheetItem?

    var body: some View {
        @Bindable var vm = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Body Parts
                sectionHeader(title: lm.bodyScanWhereTitle, subtitle: lm.bodyScanMultiple)
                FlowLayout(spacing: 10) {
                    ForEach(config.bodyParts, id: \.self) { part in
                        ChipView(
                            label: lm.display(part),
                            isSelected: viewModel.selectedBodyParts.contains(part)
                        ) {
                            toggleBodyPart(part)
                        }
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.5)
                                .onEnded { _ in
                                    if let entry = DictionaryService.bodyPart(for: part) {
                                        sheetItem = SheetItem(entry: entry, kind: .bodyPart)
                                    }
                                }
                        )
                    }
                }

                // Per-body-part sensations (shown only when body parts are selected)
                if !viewModel.selectedBodyParts.isEmpty {
                    Divider()

                    sectionHeader(title: lm.bodyScanWhatTitle, subtitle: lm.bodyScanMultiple)
                    ForEach(config.bodyParts.filter { viewModel.selectedBodyParts.contains($0) }, id: \.self) { part in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(lm.display(part))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            FlowLayout(spacing: 10) {
                                ForEach(config.sensations(for: part), id: \.self) { sensation in
                                    ChipView(
                                        label: lm.display(sensation),
                                        isSelected: viewModel.bodySensations[part]?.contains(sensation) ?? false
                                    ) {
                                        toggleSensation(sensation, for: part)
                                    }
                                    .simultaneousGesture(
                                        LongPressGesture(minimumDuration: 0.5)
                                            .onEnded { _ in
                                                if let entry = DictionaryService.sensation(for: sensation) {
                                                    sheetItem = SheetItem(entry: entry, kind: .sensation)
                                                }
                                            }
                                    )
                                }
                            }
                        }
                    }
                }

                Divider()

                // Trigger Event
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader(title: lm.bodyScanTriggerTitle, subtitle: lm.bodyScanTriggerSubtitle)
                    TextField(lm.bodyScanTriggerPlaceholder, text: $vm.triggerEvent, axis: .vertical)
                        .lineLimit(3...5)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }

                Divider()

                // Intensity Slider
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader(
                        title: lm.bodyScanIntensity,
                        subtitle: "\(Int(viewModel.intensity)) / 10"
                    )
                    IntensitySlider(value: $vm.intensity, mildLabel: lm.bodyScanMild, intenseLabel: lm.bodyScanIntense)
                }

                // Next Button
                Button(action: {
                    withAnimation { viewModel.currentStep = .emotionLabel }
                }) {
                    Text(lm.bodyScanNext)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(viewModel.canProceedFromBodyScan ? Color.cathierAccent : Color(.systemGray3))
                        .clipShape(Capsule())
                }
                .disabled(!viewModel.canProceedFromBodyScan)
                .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .sheet(item: $sheetItem) { item in
            switch item.kind {
            case .sensation:
                SensationDictionarySheet(entry: item.entry)
            case .bodyPart:
                BodyPartDictionarySheet(entry: item.entry)
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(title: String, subtitle: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func toggleBodyPart(_ part: String) {
        if viewModel.selectedBodyParts.contains(part) {
            viewModel.selectedBodyParts.remove(part)
            viewModel.bodySensations.removeValue(forKey: part)
        } else {
            viewModel.selectedBodyParts.insert(part)
        }
    }

    private func toggleSensation(_ sensation: String, for part: String) {
        if viewModel.bodySensations[part]?.contains(sensation) == true {
            viewModel.bodySensations[part]?.remove(sensation)
            if viewModel.bodySensations[part]?.isEmpty == true {
                viewModel.bodySensations.removeValue(forKey: part)
            }
        } else {
            if viewModel.bodySensations[part] == nil {
                viewModel.bodySensations[part] = []
            }
            viewModel.bodySensations[part]?.insert(sensation)
        }
    }
}

// MARK: - Intensity Slider

private struct IntensitySlider: View {
    @Binding var value: Double
    let mildLabel: String
    let intenseLabel: String

    private let gradient = LinearGradient(
        colors: [.yellow, .orange, .cathierAccent, .red],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        VStack(spacing: 6) {
            Slider(value: $value, in: 1...10, step: 1)
                .tint(intensityColor)
            HStack {
                Text(mildLabel).font(.caption2).foregroundColor(.secondary)
                Spacer()
                Text(intenseLabel).font(.caption2).foregroundColor(.secondary)
            }
        }
    }

    private var intensityColor: Color {
        switch value {
        case ..<4: return .yellow
        case ..<7: return .orange
        default:   return .red
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        for row in rows {
            let rowWidth = row.reduce(CGFloat(0)) { $0 + clampedSize(of: $1, maxWidth: maxWidth).width } + spacing * CGFloat(max(row.count - 1, 0))
            let rowHeight = row.map { clampedSize(of: $0, maxWidth: maxWidth).height }.max() ?? 0
            totalWidth = max(totalWidth, rowWidth)
            totalHeight += rowHeight + (totalHeight > 0 ? spacing : 0)
        }
        return CGSize(width: min(totalWidth, maxWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            let rowHeight = row.map { clampedSize(of: $0, maxWidth: maxWidth).height }.max() ?? 0
            for subview in row {
                let size = clampedSize(of: subview, maxWidth: maxWidth)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    /// Returns the subview's natural size, but clamped to maxWidth.
    private func clampedSize(of subview: LayoutSubview, maxWidth: CGFloat) -> CGSize {
        let natural = subview.sizeThatFits(.unspecified)
        if natural.width <= maxWidth {
            return natural
        }
        // Re-measure with constrained width so text wraps
        return subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubview]] {
        var rows: [[LayoutSubview]] = [[]]
        var currentRowWidth: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity

        for subview in subviews {
            let size = clampedSize(of: subview, maxWidth: maxWidth)
            if currentRowWidth + size.width + (rows.last?.isEmpty == false ? spacing : 0) > maxWidth,
               rows.last?.isEmpty == false {
                rows.append([subview])
                currentRowWidth = size.width
            } else {
                rows[rows.count - 1].append(subview)
                currentRowWidth += size.width + (rows.last?.count == 1 ? 0 : spacing)
            }
        }
        return rows.filter { !$0.isEmpty }
    }
}
