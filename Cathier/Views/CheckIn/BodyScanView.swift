import SwiftUI

struct BodyScanView: View {
    @Environment(CheckInViewModel.self) private var viewModel
    @Environment(ConfigService.self) private var config
    @Environment(LanguageManager.self) private var lm

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
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            FlowLayout(spacing: 10) {
                                ForEach(config.sensations, id: \.self) { sensation in
                                    ChipView(
                                        label: lm.display(sensation),
                                        isSelected: viewModel.bodySensations[part]?.contains(sensation) ?? false
                                    ) {
                                        toggleSensation(sensation, for: part)
                                    }
                                }
                            }
                        }
                    }
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
                        .background(viewModel.canProceedFromBodyScan ? Color.orange : Color(.systemGray3))
                        .cornerRadius(14)
                }
                .disabled(!viewModel.canProceedFromBodyScan)
                .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
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
        colors: [.green, .yellow, .orange, .red],
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
        case ..<4: return .green
        case ..<7: return .orange
        default:   return .red
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        return rows.reduce(CGSize.zero) { result, row in
            CGSize(
                width: max(result.width, row.reduce(0) { $0 + $1.sizeThatFits(.unspecified).width } + spacing * CGFloat(row.count - 1)),
                height: result.height + (row.first?.sizeThatFits(.unspecified).height ?? 0) + (result.height > 0 ? spacing : 0)
            )
        }
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubview]] {
        var rows: [[LayoutSubview]] = [[]]
        var currentRowWidth: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
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
