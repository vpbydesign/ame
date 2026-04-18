import SwiftUI
import Charts

/// Recursive SwiftUI View that renders any AmeNode tree as native iOS UI.
///
/// This is the main entry point for the AME SwiftUI renderer. It dispatches
/// to type-specific private views via an exhaustive `switch` over all 24
/// AmeNode cases. The Swift compiler enforces exhaustiveness — adding a new
/// case to AmeNode will cause a compile error here until a rendering branch
/// is added.
public struct AmeRenderer: View {

    public let node: AmeNode
    @ObservedObject public var formState: AmeFormState
    public let onAction: (AmeAction) -> Void
    public var depth: Int

    private let maxDepth = 12

    public init(
        node: AmeNode,
        formState: AmeFormState,
        onAction: @escaping (AmeAction) -> Void,
        depth: Int = 0
    ) {
        self.node = node
        self.formState = formState
        self.onAction = onAction
        self.depth = depth
    }

    public var body: some View {
        if depth > maxDepth {
            Text("\u{26A0} Max nesting depth exceeded")
                .font(.caption)
                .foregroundColor(Color(.systemRed))
        } else {
            renderNode(node)
        }
    }

    // MARK: - Node Dispatch

    @ViewBuilder
    private func renderNode(_ node: AmeNode) -> some View {
        switch node {
        case .col(let children, let align):
            renderCol(children, align: align)
        case .row(let children, let align, let gap):
            renderRow(children, align: align, gap: gap)
        case .txt(let text, let style, let maxLines, let color):
            renderTxt(text, style: style, maxLines: maxLines, color: color)
        case .img(let url, let height):
            renderImg(url, height: height)
        case .icon(let name, let size):
            renderIcon(name, size: size)
        case .divider:
            Divider()
        case .spacer(let height):
            Spacer().frame(height: CGFloat(height))
        case .card(let children, let elevation):
            renderCard(children, elevation: elevation)
        case .badge(let label, let variant, let color):
            renderBadge(label, variant: variant, color: color)
        case .progress(let value, let label):
            renderProgress(value, label: label)
        case .btn(let label, let action, let style, let icon):
            renderBtn(label, action: action, style: style, icon: icon)
        case .input(let id, let label, let type, let options):
            renderInput(id, label: label, type: type, options: options)
        case .toggle(let id, let label, let defaultValue):
            renderToggle(id, label: label, defaultValue: defaultValue)
        case .dataList(let children, let dividers):
            renderDataList(children, dividers: dividers)
        case .table(let headers, let rows):
            renderTable(headers, rows: rows)
        case .chart(let type, let values, let labels, let series, let height, let color, _, _, _, _):
            renderChart(type: type, values: values, labels: labels, series: series, height: height, color: color)
        case .code(let language, let content, let title):
            renderCode(language: language, content: content, title: title)
        case .accordion(let title, let children, let expanded):
            renderAccordion(title: title, children: children, expanded: expanded)
        case .carousel(let children, let peek):
            renderCarousel(children: children, peek: peek)
        case .callout(let type, let content, let title, _):
            renderCallout(type: type, content: content, title: title)
        case .timeline(let children):
            renderTimeline(children: children)
        case .timelineItem(let title, let subtitle, let status):
            renderTimelineItem(title: title, subtitle: subtitle, status: status)
        case .ref:
            AmeSkeleton()
        case .each:
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .shimmer()
        }
    }

    // MARK: - Layout Primitives

    @ViewBuilder
    private func renderCol(_ children: [AmeNode], align: Align) -> some View {
        VStack(alignment: mapHorizontalAlignment(align), spacing: 8) {
            ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                AmeRenderer(node: child, formState: formState, onAction: onAction, depth: depth + 1)
            }
        }
    }

    @ViewBuilder
    private func renderRow(_ children: [AmeNode], align: Align, gap: Int) -> some View {
        switch align {
        case .spaceBetween:
            // gap ignored when align is spaceBetween — matches Compose Arrangement.SpaceBetween
            HStack {
                ForEach(Array(children.enumerated()), id: \.offset) { index, child in
                    AmeRenderer(node: child, formState: formState, onAction: onAction, depth: depth + 1)
                    if index < children.count - 1 {
                        Spacer()
                    }
                }
            }
        case .spaceAround:
            // gap ignored when align is spaceAround — matches Compose Arrangement.SpaceAround
            HStack {
                Spacer()
                ForEach(Array(children.enumerated()), id: \.offset) { index, child in
                    AmeRenderer(node: child, formState: formState, onAction: onAction, depth: depth + 1)
                    if index < children.count - 1 {
                        Spacer()
                    }
                }
                Spacer()
            }
        default:
            HStack(alignment: .center, spacing: CGFloat(gap)) {
                ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                    AmeRenderer(node: child, formState: formState, onAction: onAction, depth: depth + 1)
                }
            }
            .frame(maxWidth: align == .end ? .infinity : nil, alignment: mapFrameAlignment(align))
        }
    }

    // MARK: - Content Primitives

    @ViewBuilder
    private func renderTxt(_ text: String, style: TxtStyle, maxLines: Int?, color: SemanticColor?) -> some View {
        if style == .overline {
            Text(text)
                .font(AmeTheme.font(style))
                .foregroundStyle(color.map { AmeTheme.semanticColor($0) } ?? .primary)
                .textCase(.uppercase)
                .lineLimit(maxLines)
        } else {
            Text(text)
                .font(AmeTheme.font(style))
                .foregroundStyle(color.map { AmeTheme.semanticColor($0) } ?? .primary)
                .lineLimit(maxLines)
        }
    }

    @ViewBuilder
    private func renderImg(_ url: String, height: Int?) -> some View {
        AsyncImage(url: URL(string: url)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                Image(systemName: "photo")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            case .empty:
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .shimmer()
            @unknown default:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height.map { CGFloat($0) })
        .clipped()
        .cornerRadius(4)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func renderIcon(_ name: String, size: Int) -> some View {
        Image(systemName: AmeIcons.resolve(name))
            .font(.system(size: CGFloat(size)))
            .accessibilityLabel(AmeIcons.contentDescription(name))
    }

    // MARK: - Semantic Primitives

    @ViewBuilder
    private func renderCard(_ children: [AmeNode], elevation: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                AmeRenderer(node: child, formState: formState, onAction: onAction, depth: depth + 1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        #if os(iOS)
        .background(Color(.systemBackground))
        #else
        .background(Color(.windowBackgroundColor))
        #endif
        .cornerRadius(12)
        .shadow(
            color: .black.opacity(0.1),
            radius: CGFloat(elevation * 2),
            x: 0,
            y: CGFloat(elevation)
        )
    }

    @ViewBuilder
    private func renderBadge(_ label: String, variant: BadgeVariant, color: SemanticColor?) -> some View {
        Text(label)
            .font(.caption2)
            .foregroundColor(color.map { AmeTheme.semanticColor($0) } ?? AmeTheme.badgeTextColor(variant))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.map { AmeTheme.semanticColor($0).opacity(0.2) } ?? AmeTheme.badgeColor(variant))
            .cornerRadius(4)
    }

    @ViewBuilder
    private func renderProgress(_ value: Float, label: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let label {
                Text(label)
                    .font(.caption)
            }
            ProgressView(value: Double(value))
        }
        .accessibilityValue("\(Int(value * 100)) percent")
    }

    // MARK: - Interactive Primitives

    @ViewBuilder
    private func renderBtn(_ label: String, action: AmeAction, style: BtnStyle, icon: String?) -> some View {
        Button {
            handleBtnAction(action)
        } label: {
            HStack(spacing: 4) {
                if let iconName = icon {
                    Image(systemName: AmeIcons.resolve(iconName))
                        .font(.system(size: 14))
                }
                Text(label)
            }
        }
        .applyBtnStyle(style)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
    }

    private func handleBtnAction(_ action: AmeAction) {
        switch action {
        case .submit(let toolName, let staticArgs):
            let collected = formState.collectValues()
            let resolved = formState.resolveInputReferences(staticArgs)
            let merged = collected.merging(resolved) { _, new in new }
            onAction(.callTool(name: toolName, args: merged))
        default:
            onAction(action)
        }
    }

    @ViewBuilder
    private func renderInput(_ id: String, label: String, type: InputType, options: [String]?) -> some View {
        switch type {
        case .text:
            TextField(label, text: formState.binding(for: id))
                .textFieldStyle(.roundedBorder)
        case .number:
            TextField(label, text: formState.binding(for: id))
                .textFieldStyle(.roundedBorder)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
        case .email:
            TextField(label, text: formState.binding(for: id))
                .textFieldStyle(.roundedBorder)
                #if os(iOS)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()
        case .phone:
            TextField(label, text: formState.binding(for: id))
                .textFieldStyle(.roundedBorder)
                #if os(iOS)
                .keyboardType(.phonePad)
                #endif
        case .date:
            DatePicker(
                label,
                selection: formState.dateBinding(for: id, format: "yyyy-MM-dd"),
                displayedComponents: .date
            )
        case .time:
            DatePicker(
                label,
                selection: formState.dateBinding(for: id, format: "HH:mm"),
                displayedComponents: .hourAndMinute
            )
        case .select:
            let opts = options ?? []
            Picker(label, selection: formState.binding(for: id, default: opts.first ?? "")) {
                ForEach(opts, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.menu)
        }
    }

    @ViewBuilder
    private func renderToggle(_ id: String, label: String, defaultValue: Bool) -> some View {
        Toggle(label, isOn: formState.toggleBinding(for: id, default: defaultValue))
    }

    // MARK: - Data Primitives

    @ViewBuilder
    private func renderDataList(_ children: [AmeNode], dividers: Bool) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(children.enumerated()), id: \.offset) { index, child in
                if dividers && index > 0 {
                    Divider()
                }
                AmeRenderer(node: child, formState: formState, onAction: onAction, depth: depth + 1)
            }
        }
    }

    @ViewBuilder
    private func renderTable(_ headers: [String], rows: [[String]]) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
            GridRow {
                ForEach(Array(headers.enumerated()), id: \.offset) { _, header in
                    Text(header)
                        .font(.caption)
                        .fontWeight(.bold)
                }
            }
            Divider()
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(0..<headers.count, id: \.self) { i in
                        Text(i < row.count ? row[i] : "")
                            .font(.caption)
                    }
                }
            }
        }
    }

    // MARK: - Visualization Primitives

    @ViewBuilder
    private func renderChart(type: ChartType, values: [Double]?, labels: [String]?,
                             series: [[Double]]?, height: Int, color: SemanticColor?) -> some View {
        let data = values ?? []
        let chartColor = color.map { AmeTheme.semanticColor($0) } ?? .accentColor
        if data.isEmpty && (series ?? []).isEmpty {
            Text("No chart data")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            switch type {
            case .bar:
                let resolvedLabels: [String]? = (labels?.count == data.count) ? labels : nil
                Chart {
                    ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                        BarMark(
                            x: .value("Index", index),
                            y: .value("Value", value)
                        )
                        .foregroundStyle(chartColor)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: Array(0..<data.count)) { axisValue in
                        AxisValueLabel {
                            if let i = axisValue.as(Int.self),
                               let resolvedLabels, i < resolvedLabels.count {
                                Text(resolvedLabels[i])
                            } else if let i = axisValue.as(Int.self) {
                                Text("\(i)")
                            }
                        }
                    }
                }
                .frame(height: CGFloat(height))

            case .line:
                let allSeries: [[Double]] = series ?? (data.isEmpty ? [] : [data])
                let xMax: Int = allSeries.map { $0.count }.max() ?? data.count
                let resolvedLabels: [String]? = (labels?.count == xMax) ? labels : nil
                Chart {
                    ForEach(Array(allSeries.enumerated()), id: \.offset) { seriesIdx, seriesData in
                        ForEach(Array(seriesData.enumerated()), id: \.offset) { index, value in
                            LineMark(
                                x: .value("Index", index),
                                y: .value("Value", value)
                            )
                            .foregroundStyle(by: .value("Series", "Series \(seriesIdx)"))
                        }
                    }
                }
                .chartForegroundStyleScale(range: [chartColor, chartColor.opacity(0.6)])
                .chartXAxis {
                    AxisMarks(values: Array(0..<xMax)) { axisValue in
                        AxisValueLabel {
                            if let i = axisValue.as(Int.self),
                               let resolvedLabels, i < resolvedLabels.count {
                                Text(resolvedLabels[i])
                            } else if let i = axisValue.as(Int.self) {
                                Text("\(i)")
                            }
                        }
                    }
                }
                .frame(height: CGFloat(height))

            case .pie:
                let resolvedLabels: [String]? = (labels?.count == data.count) ? labels : nil
                if #available(iOS 17.0, macOS 14.0, *) {
                    Chart {
                        ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                            let sliceName = resolvedLabels?[index] ?? "Slice \(index)"
                            SectorMark(
                                angle: .value("Value", value)
                            )
                            .foregroundStyle(by: .value("Slice", sliceName))
                        }
                    }
                    .frame(height: CGFloat(height))
                } else {
                    Chart {
                        ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                            let sliceName = resolvedLabels?[index] ?? "Slice \(index)"
                            BarMark(
                                x: .value("Slice", sliceName),
                                y: .value("Value", value)
                            )
                            .foregroundStyle(by: .value("Slice", sliceName))
                        }
                    }
                    .frame(height: CGFloat(height))
                }

            case .sparkline:
                // Sparkline intentionally ignores labels: axes are hidden per spec
                // (primitives.md "ignored for sparkline" + Compose AmeChartRenderer parity).
                Chart {
                    ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                        LineMark(
                            x: .value("Index", index),
                            y: .value("Value", value)
                        )
                        .foregroundStyle(chartColor)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: CGFloat(height))
            }
        }
    }

    // MARK: - Rich Content Primitives

    @ViewBuilder
    private func renderCode(language: String, content: String, title: String?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title ?? language)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    #if os(iOS)
                    UIPasteboard.general.string = content
                    #elseif os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(content, forType: .string)
                    #endif
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                Text(content)
                    .font(.system(.body, design: .monospaced))
                    #if os(iOS)
                    .foregroundStyle(Color(.label))
                    #else
                    .foregroundStyle(Color.primary)
                    #endif
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
        }
        #if os(iOS)
        .background(Color(.systemGray6))
        #else
        .background(Color.gray.opacity(0.1))
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Disclosure Primitives

    @ViewBuilder
    private func renderAccordion(title: String, children: [AmeNode], expanded: Bool) -> some View {
        AmeAccordionView(title: title, children: children, initialExpanded: expanded,
                         formState: formState, onAction: onAction, depth: depth)
    }

    @ViewBuilder
    private func renderCarousel(children: [AmeNode], peek: Int) -> some View {
        if children.isEmpty {
            EmptyView()
        } else {
            GeometryReader { geometry in
                let itemWidth = geometry.size.width * 0.85
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                            AmeRenderer(node: child, formState: formState, onAction: onAction, depth: depth + 1)
                                .frame(width: itemWidth)
                        }
                    }
                    // Mirrors Compose: PaddingValues(start = 16.dp, end = node.peek.dp).
                    // Trailing inset is the configured peek; no minimum clamp.
                    .padding(.leading, 16)
                    .padding(.trailing, CGFloat(peek))
                }
            }
            .frame(height: 200)
        }
    }

    // MARK: - Alert Primitives

    @ViewBuilder
    private func renderCallout(type: CalloutType, content: String, title: String?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: AmeTheme.calloutIcon(type))
                .foregroundStyle(AmeTheme.calloutTint(type))
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                if let title {
                    Text(title).font(.headline)
                }
                Text(content).font(.body)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(AmeTheme.calloutBackground(type))
        )
    }

    // MARK: - Sequence Primitives

    @ViewBuilder
    private func renderTimeline(children: [AmeNode]) -> some View {
        if children.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(children.enumerated()), id: \.offset) { index, child in
                    if case .timelineItem(let title, let subtitle, let status) = child {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(spacing: 0) {
                                Circle()
                                    .fill(AmeTheme.timelineCircleColor(status))
                                    .frame(width: 12, height: 12)
                                if index < children.count - 1 {
                                    if AmeTheme.timelineIsDashed(status) {
                                        Rectangle()
                                            .fill(.clear)
                                            .frame(width: 2)
                                            .overlay(
                                                GeometryReader { geo in
                                                    Path { path in
                                                        path.move(to: CGPoint(x: 1, y: 0))
                                                        path.addLine(to: CGPoint(x: 1, y: geo.size.height))
                                                    }
                                                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                                                    .foregroundStyle(AmeTheme.timelineLineColor(status))
                                                }
                                            )
                                    } else {
                                        Rectangle()
                                            .fill(AmeTheme.timelineLineColor(status))
                                            .frame(width: 2)
                                    }
                                }
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(title).font(.subheadline).fontWeight(.medium)
                                if let sub = subtitle, !sub.isEmpty {
                                    Text(sub).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .padding(.bottom, 16)
                        }
                    } else {
                        AmeRenderer(node: child, formState: formState, onAction: onAction, depth: depth + 1)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func renderTimelineItem(title: String, subtitle: String?, status: TimelineStatus) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.subheadline).fontWeight(.medium)
            if let sub = subtitle, !sub.isEmpty {
                Text(sub).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Alignment Helpers

    private func mapHorizontalAlignment(_ align: Align) -> HorizontalAlignment {
        switch align {
        case .start: return .leading
        case .center: return .center
        case .end: return .trailing
        case .spaceBetween, .spaceAround: return .leading
        }
    }

    private func mapFrameAlignment(_ align: Align) -> Alignment {
        switch align {
        case .start: return .leading
        case .center: return .center
        case .end: return .trailing
        case .spaceBetween, .spaceAround: return .leading
        }
    }
}

// MARK: - Accordion View (requires @State for expand/collapse)

/// Bug #18 (WP#5): the previous implementation captured `node.expanded`
/// only at first composition via `State(initialValue:)`, so server-pushed
/// updates were silently ignored. The fix mirrors the WP#4 Bug 5
/// separate-state pattern: a non-`@State` `nodeExpanded` field tracks the
/// latest external value, and `.onChange(of: nodeExpanded)` syncs the
/// `@State` snapshot when the host re-renders the parent with a new
/// AmeNode.Accordion. Local user taps still flip `isExpanded` immediately
/// and persist until the next external change.
private struct AmeAccordionView: View {
    let title: String
    let children: [AmeNode]
    let nodeExpanded: Bool
    @State var isExpanded: Bool
    let formState: AmeFormState
    let onAction: (AmeAction) -> Void
    let depth: Int

    init(title: String, children: [AmeNode], initialExpanded: Bool,
         formState: AmeFormState, onAction: @escaping (AmeAction) -> Void, depth: Int) {
        self.title = title
        self.children = children
        self.nodeExpanded = initialExpanded
        self._isExpanded = State(initialValue: initialExpanded)
        self.formState = formState
        self.onAction = onAction
        self.depth = depth
    }

    var body: some View {
        DisclosureGroup(title, isExpanded: $isExpanded) {
            ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                AmeRenderer(node: child, formState: formState, onAction: onAction, depth: depth + 1)
            }
        }
        .onChange(of: nodeExpanded) { newValue in
            isExpanded = newValue
        }
    }
}

// MARK: - Button Style Extension

private extension View {
    @ViewBuilder
    func applyBtnStyle(_ style: BtnStyle) -> some View {
        switch style {
        case .primary:
            self.buttonStyle(.borderedProminent)
        case .secondary:
            self.buttonStyle(.bordered)
                .tint(.secondary)
        case .outline:
            self.buttonStyle(.bordered)
        case .text:
            self.buttonStyle(.plain)
        case .destructive:
            self.buttonStyle(.borderedProminent)
                .tint(Color(.systemRed))
        }
    }
}

// MARK: - SwiftUI Previews

#Preview("Card with Children") {
    ScrollView {
        AmeRenderer(
            node: .card(children: [
                .row(children: [
                    .txt(text: "San Francisco", style: .title),
                    .icon(name: "partly_cloudy_day", size: 28)
                ], align: .spaceBetween),
                .txt(text: "62°", style: .display),
                .txt(text: "Partly Cloudy"),
                .row(children: [
                    .txt(text: "H:68° L:55°", style: .caption),
                    .txt(text: "Humidity: 72%", style: .caption)
                ], align: .spaceBetween)
            ]),
            formState: AmeFormState(),
            onAction: { _ in }
        )
        .padding()
    }
}

#Preview("Button Styles") {
    VStack(spacing: 12) {
        AmeRenderer(
            node: .btn(label: "Primary", action: .navigate(route: "test"), style: .primary),
            formState: AmeFormState(),
            onAction: { _ in }
        )
        AmeRenderer(
            node: .btn(label: "Secondary", action: .navigate(route: "test"), style: .secondary),
            formState: AmeFormState(),
            onAction: { _ in }
        )
        AmeRenderer(
            node: .btn(label: "Outline", action: .navigate(route: "test"), style: .outline),
            formState: AmeFormState(),
            onAction: { _ in }
        )
        AmeRenderer(
            node: .btn(label: "Text", action: .navigate(route: "test"), style: .text),
            formState: AmeFormState(),
            onAction: { _ in }
        )
        AmeRenderer(
            node: .btn(label: "Destructive", action: .navigate(route: "test"), style: .destructive),
            formState: AmeFormState(),
            onAction: { _ in }
        )
    }
    .padding()
}

#Preview("Input Types") {
    VStack(spacing: 12) {
        AmeRenderer(
            node: .input(id: "name", label: "Your Name", type: .text),
            formState: AmeFormState(),
            onAction: { _ in }
        )
        AmeRenderer(
            node: .input(id: "date", label: "Date", type: .date),
            formState: AmeFormState(),
            onAction: { _ in }
        )
        AmeRenderer(
            node: .input(id: "guests", label: "Guests", type: .select, options: ["1", "2", "3", "4"]),
            formState: AmeFormState(),
            onAction: { _ in }
        )
    }
    .padding()
}

#Preview("Badge Variants") {
    HStack(spacing: 8) {
        AmeRenderer(node: .badge(label: "Default"), formState: AmeFormState(), onAction: { _ in })
        AmeRenderer(node: .badge(label: "Success", variant: .success), formState: AmeFormState(), onAction: { _ in })
        AmeRenderer(node: .badge(label: "Warning", variant: .warning), formState: AmeFormState(), onAction: { _ in })
        AmeRenderer(node: .badge(label: "Error", variant: .error), formState: AmeFormState(), onAction: { _ in })
        AmeRenderer(node: .badge(label: "Info", variant: .info), formState: AmeFormState(), onAction: { _ in })
    }
    .padding()
}

#Preview("Progress") {
    VStack(spacing: 12) {
        AmeRenderer(
            node: .progress(value: 0.67, label: "67% complete"),
            formState: AmeFormState(),
            onAction: { _ in }
        )
        AmeRenderer(
            node: .progress(value: 0.3),
            formState: AmeFormState(),
            onAction: { _ in }
        )
    }
    .padding()
}

#Preview("Row SpaceBetween") {
    AmeRenderer(
        node: .row(children: [
            .txt(text: "Left"),
            .txt(text: "Center"),
            .txt(text: "Right")
        ], align: .spaceBetween),
        formState: AmeFormState(),
        onAction: { _ in }
    )
    .padding()
}

#Preview("Toggle") {
    AmeRenderer(
        node: .toggle(id: "notifications", label: "Enable notifications", default: true),
        formState: AmeFormState(),
        onAction: { _ in }
    )
    .padding()
}
