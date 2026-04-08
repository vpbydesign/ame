import SwiftUI

/// Recursive SwiftUI View that renders any AmeNode tree as native iOS UI.
///
/// This is the main entry point for the AME SwiftUI renderer. It dispatches
/// to type-specific private views via an exhaustive `switch` over all 17
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
                .foregroundColor(.red)
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
        case .txt(let text, let style, let maxLines):
            renderTxt(text, style: style, maxLines: maxLines)
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
        case .badge(let label, let variant):
            renderBadge(label, variant: variant)
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
        case .ref:
            AmeSkeleton()
        // Streaming fallback: when a data section is present, the parser expands
        // each() at parse time and this case is never reached. This path is only hit
        // during streaming mode when the data model has not yet arrived.
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
    private func renderTxt(_ text: String, style: TxtStyle, maxLines: Int?) -> some View {
        if style == .overline {
            Text(text)
                .font(AmeTheme.font(style))
                .textCase(.uppercase)
                .lineLimit(maxLines)
        } else {
            Text(text)
                .font(AmeTheme.font(style))
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
    private func renderBadge(_ label: String, variant: BadgeVariant) -> some View {
        Text(label)
            .font(.caption2)
            .foregroundColor(AmeTheme.badgeTextColor(variant))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(AmeTheme.badgeColor(variant))
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
                .tint(.red)
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
