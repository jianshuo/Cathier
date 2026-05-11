import SwiftUI

private struct SheetItem: Identifiable {
    let id = UUID()
    let entry: DictionaryEntry
    enum Kind { case sensation, bodyPart }
    let kind: Kind
}

// MARK: - Figure dot model

private struct FigureDot: Identifiable {
    let id: String          // body part key (e.g. "头部")
    let relX: Double        // 0..1 relative to canvas width (280pt)
    let relY: Double        // 0..1 relative to canvas height (420pt)
    enum Side { case left, right }
    let labelSide: Side
    var part: String { id }
}

// MARK: - BodyScanView

struct BodyScanView: View {
    @Environment(CheckInViewModel.self) private var viewModel
    @Environment(ConfigService.self) private var config
    @Environment(LanguageManager.self) private var lm

    @State private var sheetItem: SheetItem?

    // Parts drawn as dots on the figure (front-view anatomical)
    private static let figureParts: Set<String> = [
        "头部", "颈部", "喉咙", "肩膀", "胸口", "呼吸",
        "手臂", "背部", "腹部", "腰部", "手掌", "骨盆", "大腿", "双脚"
    ]

    // Dot positions relative to the 280×420 canvas
    private static let figureDots: [FigureDot] = [
        FigureDot(id: "头部", relX: 0.50, relY: 0.065, labelSide: .right),
        FigureDot(id: "颈部", relX: 0.50, relY: 0.178, labelSide: .right),
        FigureDot(id: "喉咙", relX: 0.50, relY: 0.215, labelSide: .left),
        FigureDot(id: "肩膀", relX: 0.27, relY: 0.250, labelSide: .left),
        FigureDot(id: "胸口", relX: 0.50, relY: 0.315, labelSide: .right),
        FigureDot(id: "背部", relX: 0.72, relY: 0.340, labelSide: .right),
        FigureDot(id: "呼吸", relX: 0.50, relY: 0.368, labelSide: .left),
        FigureDot(id: "手臂", relX: 0.16, relY: 0.395, labelSide: .right),
        FigureDot(id: "腹部", relX: 0.50, relY: 0.422, labelSide: .right),
        FigureDot(id: "腰部", relX: 0.50, relY: 0.462, labelSide: .left),
        FigureDot(id: "骨盆", relX: 0.50, relY: 0.518, labelSide: .right),
        FigureDot(id: "手掌", relX: 0.07, relY: 0.562, labelSide: .right),
        FigureDot(id: "大腿", relX: 0.50, relY: 0.638, labelSide: .right),
        FigureDot(id: "双脚", relX: 0.50, relY: 0.940, labelSide: .right),
    ]

    var body: some View {
        @Bindable var vm = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Section header
                sectionHeader(title: lm.bodyScanWhereTitle, subtitle: lm.bodyScanMultiple)

                // Human figure with labeled tappable dots (centered)
                HStack {
                    Spacer(minLength: 0)
                    HumanFigureView(
                        dots: Self.figureDots,
                        selectedParts: viewModel.selectedBodyParts,
                        onToggle: { part in
                            UIImpactFeedbackGenerator(style: viewModel.selectedBodyParts.contains(part) ? .light : .medium).impactOccurred()
                            toggleBodyPart(part)
                        },
                        label: { lm.display($0) }
                    )
                    Spacer(minLength: 0)
                }

                // Supplementary chips: face sub-parts, chakras, 整个身体
                let supplementary = config.bodyParts.filter { !Self.figureParts.contains($0) }
                if !supplementary.isEmpty {
                    FlowLayout(spacing: 10) {
                        ForEach(supplementary, id: \.self) { part in
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
                }

                // Per-body-part sensations (shown when body parts are selected)
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

// MARK: - Human Figure View

private struct HumanFigureView: View {
    let dots: [FigureDot]
    let selectedParts: Set<String>
    let onToggle: (String) -> Void
    let label: (String) -> String

    private static let canvasWidth: CGFloat = 280
    private static let canvasHeight: CGFloat = 420

    var body: some View {
        ZStack {
            Canvas { ctx, size in
                drawFigure(&ctx, size)
            }

            ForEach(dots) { dot in
                BodyDotLabel(
                    text: label(dot.part),
                    isSelected: selectedParts.contains(dot.part),
                    side: dot.labelSide
                ) {
                    onToggle(dot.part)
                }
                .position(
                    x: Self.canvasWidth * dot.relX,
                    y: Self.canvasHeight * dot.relY
                )
            }
        }
        .frame(width: Self.canvasWidth, height: Self.canvasHeight)
    }

    private func drawFigure(_ context: inout GraphicsContext, _ size: CGSize) {
        let w = size.width
        let h = size.height
        let headCy = h * 0.065
        let headR = w * 0.085

        var figure = Path()

        // Head circle
        figure.addEllipse(in: CGRect(
            x: w * 0.50 - headR, y: headCy - headR,
            width: headR * 2, height: headR * 2
        ))

        // Neck
        figure.move(to: CGPoint(x: w * 0.50, y: headCy + headR))
        figure.addLine(to: CGPoint(x: w * 0.50, y: h * 0.235))

        // Left shoulder
        figure.move(to: CGPoint(x: w * 0.50, y: h * 0.235))
        figure.addLine(to: CGPoint(x: w * 0.22, y: h * 0.255))

        // Right shoulder
        figure.move(to: CGPoint(x: w * 0.50, y: h * 0.235))
        figure.addLine(to: CGPoint(x: w * 0.78, y: h * 0.255))

        // Left arm: shoulder → elbow → wrist
        figure.move(to: CGPoint(x: w * 0.22, y: h * 0.255))
        figure.addLine(to: CGPoint(x: w * 0.11, y: h * 0.420))
        figure.addLine(to: CGPoint(x: w * 0.07, y: h * 0.565))

        // Right arm (symmetric)
        figure.move(to: CGPoint(x: w * 0.78, y: h * 0.255))
        figure.addLine(to: CGPoint(x: w * 0.89, y: h * 0.420))
        figure.addLine(to: CGPoint(x: w * 0.93, y: h * 0.565))

        // Torso: left side, right side, bottom
        figure.move(to: CGPoint(x: w * 0.22, y: h * 0.255))
        figure.addLine(to: CGPoint(x: w * 0.25, y: h * 0.520))
        figure.move(to: CGPoint(x: w * 0.78, y: h * 0.255))
        figure.addLine(to: CGPoint(x: w * 0.75, y: h * 0.520))
        figure.move(to: CGPoint(x: w * 0.25, y: h * 0.520))
        figure.addLine(to: CGPoint(x: w * 0.75, y: h * 0.520))

        // Left leg
        figure.move(to: CGPoint(x: w * 0.38, y: h * 0.520))
        figure.addLine(to: CGPoint(x: w * 0.35, y: h * 0.730))
        figure.addLine(to: CGPoint(x: w * 0.33, y: h * 0.935))

        // Right leg
        figure.move(to: CGPoint(x: w * 0.62, y: h * 0.520))
        figure.addLine(to: CGPoint(x: w * 0.65, y: h * 0.730))
        figure.addLine(to: CGPoint(x: w * 0.67, y: h * 0.935))

        // Feet
        figure.move(to: CGPoint(x: w * 0.33, y: h * 0.935))
        figure.addLine(to: CGPoint(x: w * 0.20, y: h * 0.950))
        figure.move(to: CGPoint(x: w * 0.67, y: h * 0.935))
        figure.addLine(to: CGPoint(x: w * 0.80, y: h * 0.950))

        context.stroke(figure, with: .color(Color(uiColor: .systemGray3)), lineWidth: 2.0)
    }
}

// MARK: - Body Dot Label

private struct BodyDotLabel: View {
    let text: String
    let isSelected: Bool
    let side: FigureDot.Side
    let action: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            if side == .right {
                dotCircle
                labelText
            } else {
                labelText
                dotCircle
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }

    private var dotCircle: some View {
        Circle()
            .fill(isSelected ? Color.cathierAccent : Color(uiColor: .systemGray3))
            .frame(width: isSelected ? 12 : 9, height: isSelected ? 12 : 9)
            .shadow(
                color: isSelected ? Color.cathierAccent.opacity(0.45) : .clear,
                radius: 5
            )
    }

    private var labelText: some View {
        Text(text)
            .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
            .foregroundColor(isSelected ? Color.cathierAccent : Color(uiColor: .secondaryLabel))
    }
}

// MARK: - Intensity Slider

private struct IntensitySlider: View {
    @Binding var value: Double
    let mildLabel: String
    let intenseLabel: String
    @State private var haptic = UISelectionFeedbackGenerator()

    var body: some View {
        VStack(spacing: 8) {
            Slider(value: $value, in: 1...10, step: 1)
                .tint(intensityColor)
                .onChange(of: value) { haptic.selectionChanged() }
            HStack(spacing: 4) {
                ForEach(1...10, id: \.self) { tick in
                    Capsule()
                        .fill(tick <= Int(value) ? intensityColor : Color.secondary.opacity(0.18))
                        .frame(maxWidth: .infinity)
                        .frame(height: 3)
                        .animation(.easeOut(duration: 0.1), value: value)
                }
            }
            HStack {
                Text(mildLabel).font(.caption2).foregroundColor(.secondary)
                Spacer()
                Text(intenseLabel).font(.caption2).foregroundColor(.secondary)
            }
        }
        .onAppear { haptic.prepare() }
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

    private func clampedSize(of subview: LayoutSubview, maxWidth: CGFloat) -> CGSize {
        let natural = subview.sizeThatFits(.unspecified)
        if natural.width <= maxWidth {
            return natural
        }
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
