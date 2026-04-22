import Foundation

/// Sealed type representing all AME UI node types.
///
/// 22 visual primitives (matching primitives.md exactly),
/// 1 streaming forward reference (ref),
/// 1 data iteration construct (each).
///
/// Children are `[AmeNode]` (resolved tree form). The parser converts
/// identifier strings to `.ref` nodes during parsing, then resolves ref -> real
/// node after all lines are processed.
///
/// Data references ($path) and each() iteration MAY be resolved at parse time
/// (when a data section is present) or deferred to the renderer at render time
/// (when streaming without a data model).
public indirect enum AmeNode: Equatable, Sendable {

    // MARK: Layout Primitives

    /// Vertical column layout.
    /// col supports align values: start, center, end.
    case col(children: [AmeNode] = [], align: Align = .start)

    /// Horizontal row layout.
    /// row supports align values: start, center, end, space_between, space_around.
    ///
    /// Parser disambiguation: when a numeric literal appears as the second positional
    /// argument, it is interpreted as `gap`, not `align`.
    ///
    /// Named-only optional fields:
    /// - `weights`: per-child flex weights for proportional width distribution.
    ///   nil = all children intrinsic. 0 = intrinsic. >0 = fill.
    /// - `crossAlign`: vertical alignment of children within the row.
    ///   nil = center. Valid: .top, .center, .bottom.
    ///
    /// Both default to nil. The Codable encoder omits nil fields, so
    /// conformance fixtures remain byte-identical.
    case row(children: [AmeNode] = [], align: Align = .start, gap: Int = 8,
             weights: [Int]? = nil, crossAlign: Align? = nil)

    // MARK: Content Primitives

    /// Text display with typographic style.
    case txt(text: String, style: TxtStyle = .body, maxLines: Int? = nil, color: SemanticColor? = nil)

    /// Image loaded from a URL. Width fills available space.
    case img(url: String, height: Int? = nil)

    /// Named icon from the platform icon set.
    case icon(name: String, size: Int = 20)

    /// Thin horizontal divider line. No arguments.
    case divider

    /// Vertical whitespace between elements.
    case spacer(height: Int = 8)

    // MARK: Semantic Primitives

    /// Elevated container grouping related content. Children arranged vertically.
    case card(children: [AmeNode] = [], elevation: Int = 1)

    /// Small colored label for status indicators, counts, or categories.
    case badge(label: String, variant: BadgeVariant = .default, color: SemanticColor? = nil)

    /// Horizontal progress bar with optional label. Value clamped to 0.0–1.0.
    case progress(value: Float, label: String? = nil)

    // MARK: Interactive Primitives

    /// Tappable button that triggers an action.
    case btn(label: String, action: AmeAction, style: BtnStyle = .primary, icon: String? = nil)

    /// Form input field. `id` provides a unique key for form data binding.
    /// When `type` is `.select`, `options` is required.
    case input(id: String, label: String, type: InputType = .text, options: [String]? = nil)

    /// Labeled toggle switch for boolean choices.
    case toggle(id: String, label: String, `default`: Bool = false)

    // MARK: Data Primitives

    /// Vertical list of children, optionally separated by dividers.
    /// Named `dataList` to avoid collision with Swift's `List` view type.
    /// Serializes as `_type: "list"` to avoid collision with language-level List types.
    case dataList(children: [AmeNode] = [], dividers: Bool = true)

    /// Grid of text values with a header row.
    case table(headers: [String], rows: [[String]])

    /// Structured single-row list entry with title, optional subtitle,
    /// optional leading and trailing nodes, and an optional whole-row tap action.
    ///
    /// Nested click target rule (NORMATIVE): when both `action` and `trailing`
    /// are present and `trailing` is itself an interactive node (.btn), the
    /// renderer MUST isolate the trailing tap so it does not also fire `action`.
    /// See `specification/v1.0/primitives.md` §list_item for the full rule.
    ///
    /// `action` is named-only in AME source: list_item("Title", action=nav("/x")).
    /// Positional slots are reserved for title, subtitle, leading, trailing.
    case listItem(title: String, subtitle: String? = nil, leading: AmeNode? = nil,
                  trailing: AmeNode? = nil, action: AmeAction? = nil)

    // MARK: Visualization Primitives

    /// Data visualization chart. Supports line, bar, pie, and sparkline types.
    /// `valuesPath`, `labelsPath`, `seriesPath`, and `seriesPaths` store unresolved
    /// $path references. After parse-time resolution against the data model, these
    /// are cleared to nil and `values`/`labels`/`series` are populated.
    ///
    /// `seriesPath` holds a single $path that resolves to a 2D array (the multi-series
    /// matrix lives at one location in the data model). `seriesPaths` holds an array
    /// of $path references where each path resolves to a 1D array (one series per
    /// path). Corresponds to the spec syntax `series=[$a, $b]`. Resolution is
    /// all-or-nothing: if any path fails to resolve, `series` stays nil so the
    /// renderer shows the empty state rather than a misleading partial chart.
    case chart(type: ChartType, values: [Double]? = nil, labels: [String]? = nil,
               series: [[Double]]? = nil, height: Int = 200, color: SemanticColor? = nil,
               valuesPath: String? = nil, labelsPath: String? = nil, seriesPath: String? = nil,
               seriesPaths: [String]? = nil)

    // MARK: Rich Content Primitives

    /// Syntax-highlighted code block with copy affordance.
    case code(language: String, content: String, title: String? = nil)

    // MARK: Disclosure Primitives

    /// Collapsible section. Header always visible; children toggle on tap.
    case accordion(title: String, children: [AmeNode] = [], expanded: Bool = false)

    /// Horizontally scrollable container. `peek` is dp of next item visible.
    case carousel(children: [AmeNode] = [], peek: Int = 24)

    // MARK: Alert Primitives

    /// Visually distinct alert/info box with type-specific icon and tint.
    /// `color` optionally overrides the type-derived tint with a SemanticColor.
    case callout(type: CalloutType, content: String, title: String? = nil, color: SemanticColor? = nil)

    // MARK: Sequence Primitives

    /// Ordered vertical event sequence with status connectors.
    case timeline(children: [AmeNode] = [])

    /// Single step in a timeline. Not rendered standalone.
    case timelineItem(title: String, subtitle: String? = nil, status: TimelineStatus = .pending)

    // MARK: Structural Types (non-visual)

    /// Unresolved forward reference during streaming.
    /// The renderer shows a skeleton placeholder.
    case ref(id: String)

    /// Data iteration construct. Instantiates a template once per element in a
    /// JSON array from the data model. When a data section is present, the parser
    /// expands each() at parse time, resolving $path references within the scoped
    /// data of each array element. When no data is available (e.g. streaming mode),
    /// the each node is preserved in the tree for deferred rendering.
    case each(dataPath: String, templateId: String)
}

// MARK: - Codable

extension AmeNode: Codable {

    private enum CodingKeys: String, CodingKey {
        case type = "_type"
        case children
        case align
        case gap
        case text
        case style
        case maxLines
        case url
        case height
        case name
        case size
        case elevation
        case label
        case variant
        case value
        case action
        case icon
        case id
        case inputType = "type"
        case options
        case `default`
        case dividers
        case headers
        case rows
        case dataPath
        case templateId
        case color
        case values
        case labels
        case series
        case valuesPath
        case labelsPath
        case seriesPath
        case seriesPaths
        case language
        case content
        case title
        case expanded
        case peek
        case subtitle
        case status
        case weights
        case crossAlign = "cross_align"
        case leading
        case trailing
    }

    // Separate CodingKeys for encoding to handle the _type vs type collision.
    // The "type" JSON key is used both for the discriminator (_type) and for
    // Input's type property. We use separate keys for each during encode/decode.
    //
    // Note: CodingKeys.type maps to "_type" (discriminator)
    //       CodingKeys.inputType maps to "type" (Input's InputType property)

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .col(let children, let align):
            try container.encode("col", forKey: .type)
            if !children.isEmpty { try container.encode(children, forKey: .children) }
            if align != .start { try container.encode(align, forKey: .align) }

        case .row(let children, let align, let gap, let weights, let crossAlign):
            try container.encode("row", forKey: .type)
            if !children.isEmpty { try container.encode(children, forKey: .children) }
            if align != .start { try container.encode(align, forKey: .align) }
            if gap != 8 { try container.encode(gap, forKey: .gap) }
            if let weights { try container.encode(weights, forKey: .weights) }
            if let crossAlign { try container.encode(crossAlign, forKey: .crossAlign) }

        case .txt(let text, let style, let maxLines, let color):
            try container.encode("txt", forKey: .type)
            try container.encode(text, forKey: .text)
            if style != .body { try container.encode(style, forKey: .style) }
            if let maxLines { try container.encode(maxLines, forKey: .maxLines) }
            if let color { try container.encode(color, forKey: .color) }

        case .img(let url, let height):
            try container.encode("img", forKey: .type)
            try container.encode(url, forKey: .url)
            if let height { try container.encode(height, forKey: .height) }

        case .icon(let name, let size):
            try container.encode("icon", forKey: .type)
            try container.encode(name, forKey: .name)
            if size != 20 { try container.encode(size, forKey: .size) }

        case .divider:
            try container.encode("divider", forKey: .type)

        case .spacer(let height):
            try container.encode("spacer", forKey: .type)
            if height != 8 { try container.encode(height, forKey: .height) }

        case .card(let children, let elevation):
            try container.encode("card", forKey: .type)
            if !children.isEmpty { try container.encode(children, forKey: .children) }
            if elevation != 1 { try container.encode(elevation, forKey: .elevation) }

        case .badge(let label, let variant, let color):
            try container.encode("badge", forKey: .type)
            try container.encode(label, forKey: .label)
            if variant != .default { try container.encode(variant, forKey: .variant) }
            if let color { try container.encode(color, forKey: .color) }

        case .progress(let value, let label):
            try container.encode("progress", forKey: .type)
            // Wrap in PreservedFloat so whole-number values (e.g. 1.0)
            // round-trip with the canonical `1.0` form. AmeSerializer.toJson
            // strips the sentinels.
            try container.encode(PreservedFloat(value), forKey: .value)
            if let label { try container.encode(label, forKey: .label) }

        case .btn(let label, let action, let style, let icon):
            try container.encode("btn", forKey: .type)
            try container.encode(label, forKey: .label)
            try container.encode(action, forKey: .action)
            if style != .primary { try container.encode(style, forKey: .style) }
            if let icon { try container.encode(icon, forKey: .icon) }

        case .input(let id, let label, let inputType, let options):
            try container.encode("input", forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(label, forKey: .label)
            if inputType != .text { try container.encode(inputType, forKey: .inputType) }
            if let options { try container.encode(options, forKey: .options) }

        case .toggle(let id, let label, let defaultValue):
            try container.encode("toggle", forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(label, forKey: .label)
            if defaultValue != false { try container.encode(defaultValue, forKey: .default) }

        case .dataList(let children, let dividers):
            try container.encode("list", forKey: .type)
            if !children.isEmpty { try container.encode(children, forKey: .children) }
            if dividers != true { try container.encode(dividers, forKey: .dividers) }

        case .table(let headers, let rows):
            try container.encode("table", forKey: .type)
            try container.encode(headers, forKey: .headers)
            try container.encode(rows, forKey: .rows)

        case .listItem(let itemTitle, let itemSubtitle, let leading, let trailing, let itemAction):
            try container.encode("list_item", forKey: .type)
            try container.encode(itemTitle, forKey: .title)
            if let itemSubtitle { try container.encode(itemSubtitle, forKey: .subtitle) }
            if let leading { try container.encode(leading, forKey: .leading) }
            if let trailing { try container.encode(trailing, forKey: .trailing) }
            if let itemAction { try container.encode(itemAction, forKey: .action) }

        case .chart(let chartType, let values, let labels, let series, let height, let color,
                    let valuesPath, let labelsPath, let seriesPath, let seriesPaths):
            try container.encode("chart", forKey: .type)
            try container.encode(chartType, forKey: .inputType)
            // Wrap Double-typed arrays in PreservedDouble so whole-number
            // values (e.g. [1, 2, 3]) round-trip with the canonical
            // `[1.0,2.0,3.0]` form. AmeSerializer.toJson strips the sentinels.
            if let values { try container.encode(values.map { PreservedDouble($0) }, forKey: .values) }
            if let labels { try container.encode(labels, forKey: .labels) }
            if let series { try container.encode(series.map { $0.map { PreservedDouble($0) } }, forKey: .series) }
            if height != 200 { try container.encode(height, forKey: .height) }
            if let color { try container.encode(color, forKey: .color) }
            if let valuesPath { try container.encode(valuesPath, forKey: .valuesPath) }
            if let labelsPath { try container.encode(labelsPath, forKey: .labelsPath) }
            if let seriesPath { try container.encode(seriesPath, forKey: .seriesPath) }
            if let seriesPaths { try container.encode(seriesPaths, forKey: .seriesPaths) }

        case .code(let language, let codeContent, let codeTitle):
            try container.encode("code", forKey: .type)
            try container.encode(language, forKey: .language)
            try container.encode(codeContent, forKey: .content)
            if let codeTitle { try container.encode(codeTitle, forKey: .title) }

        case .accordion(let accordionTitle, let children, let expanded):
            try container.encode("accordion", forKey: .type)
            try container.encode(accordionTitle, forKey: .title)
            if !children.isEmpty { try container.encode(children, forKey: .children) }
            if expanded != false { try container.encode(expanded, forKey: .expanded) }

        case .carousel(let children, let peek):
            try container.encode("carousel", forKey: .type)
            if !children.isEmpty { try container.encode(children, forKey: .children) }
            if peek != 24 { try container.encode(peek, forKey: .peek) }

        case .callout(let calloutType, let calloutContent, let calloutTitle, let calloutColor):
            try container.encode("callout", forKey: .type)
            try container.encode(calloutType, forKey: .inputType)
            try container.encode(calloutContent, forKey: .content)
            if let calloutTitle { try container.encode(calloutTitle, forKey: .title) }
            if let calloutColor { try container.encode(calloutColor, forKey: .color) }

        case .timeline(let children):
            try container.encode("timeline", forKey: .type)
            if !children.isEmpty { try container.encode(children, forKey: .children) }

        case .timelineItem(let itemTitle, let subtitle, let status):
            try container.encode("timeline_item", forKey: .type)
            try container.encode(itemTitle, forKey: .title)
            if let subtitle { try container.encode(subtitle, forKey: .subtitle) }
            if status != .pending { try container.encode(status, forKey: .status) }

        case .ref(let id):
            try container.encode("ref", forKey: .type)
            try container.encode(id, forKey: .id)

        case .each(let dataPath, let templateId):
            try container.encode("each", forKey: .type)
            try container.encode(dataPath, forKey: .dataPath)
            try container.encode(templateId, forKey: .templateId)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "col":
            let children = try container.decodeIfPresent([AmeNode].self, forKey: .children) ?? []
            let align = try container.decodeIfPresent(Align.self, forKey: .align) ?? .start
            self = .col(children: children, align: align)

        case "row":
            let children = try container.decodeIfPresent([AmeNode].self, forKey: .children) ?? []
            let align = try container.decodeIfPresent(Align.self, forKey: .align) ?? .start
            let gap = try container.decodeIfPresent(Int.self, forKey: .gap) ?? 8
            let weights = try container.decodeIfPresent([Int].self, forKey: .weights)
            let crossAlign = try container.decodeIfPresent(Align.self, forKey: .crossAlign)
            self = .row(children: children, align: align, gap: gap,
                        weights: weights, crossAlign: crossAlign)

        case "txt":
            let text = try container.decode(String.self, forKey: .text)
            let style = try container.decodeIfPresent(TxtStyle.self, forKey: .style) ?? .body
            let maxLines = try container.decodeIfPresent(Int.self, forKey: .maxLines)
            let color = try container.decodeIfPresent(SemanticColor.self, forKey: .color)
            self = .txt(text: text, style: style, maxLines: maxLines, color: color)

        case "img":
            let url = try container.decode(String.self, forKey: .url)
            let height = try container.decodeIfPresent(Int.self, forKey: .height)
            self = .img(url: url, height: height)

        case "icon":
            let name = try container.decode(String.self, forKey: .name)
            let size = try container.decodeIfPresent(Int.self, forKey: .size) ?? 20
            self = .icon(name: name, size: size)

        case "divider":
            self = .divider

        case "spacer":
            let height = try container.decodeIfPresent(Int.self, forKey: .height) ?? 8
            self = .spacer(height: height)

        case "card":
            let children = try container.decodeIfPresent([AmeNode].self, forKey: .children) ?? []
            let elevation = try container.decodeIfPresent(Int.self, forKey: .elevation) ?? 1
            self = .card(children: children, elevation: elevation)

        case "badge":
            let label = try container.decode(String.self, forKey: .label)
            let variant = try container.decodeIfPresent(BadgeVariant.self, forKey: .variant) ?? .default
            let color = try container.decodeIfPresent(SemanticColor.self, forKey: .color)
            self = .badge(label: label, variant: variant, color: color)

        case "progress":
            let value = try container.decode(Float.self, forKey: .value)
            let label = try container.decodeIfPresent(String.self, forKey: .label)
            self = .progress(value: value, label: label)

        case "btn":
            let label = try container.decode(String.self, forKey: .label)
            let action = try container.decode(AmeAction.self, forKey: .action)
            let style = try container.decodeIfPresent(BtnStyle.self, forKey: .style) ?? .primary
            let icon = try container.decodeIfPresent(String.self, forKey: .icon)
            self = .btn(label: label, action: action, style: style, icon: icon)

        case "input":
            let id = try container.decode(String.self, forKey: .id)
            let label = try container.decode(String.self, forKey: .label)
            let inputType = try container.decodeIfPresent(InputType.self, forKey: .inputType) ?? .text
            let options = try container.decodeIfPresent([String].self, forKey: .options)
            self = .input(id: id, label: label, type: inputType, options: options)

        case "toggle":
            let id = try container.decode(String.self, forKey: .id)
            let label = try container.decode(String.self, forKey: .label)
            let defaultValue = try container.decodeIfPresent(Bool.self, forKey: .default) ?? false
            self = .toggle(id: id, label: label, default: defaultValue)

        case "list":
            let children = try container.decodeIfPresent([AmeNode].self, forKey: .children) ?? []
            let dividers = try container.decodeIfPresent(Bool.self, forKey: .dividers) ?? true
            self = .dataList(children: children, dividers: dividers)

        case "table":
            let headers = try container.decode([String].self, forKey: .headers)
            let rows = try container.decode([[String]].self, forKey: .rows)
            self = .table(headers: headers, rows: rows)

        case "list_item":
            let itemTitle = try container.decode(String.self, forKey: .title)
            let itemSubtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
            let leading = try container.decodeIfPresent(AmeNode.self, forKey: .leading)
            let trailing = try container.decodeIfPresent(AmeNode.self, forKey: .trailing)
            let itemAction = try container.decodeIfPresent(AmeAction.self, forKey: .action)
            self = .listItem(title: itemTitle, subtitle: itemSubtitle,
                             leading: leading, trailing: trailing, action: itemAction)

        case "chart":
            let chartType = try container.decode(ChartType.self, forKey: .inputType)
            let values = try container.decodeIfPresent([Double].self, forKey: .values)
            let labels = try container.decodeIfPresent([String].self, forKey: .labels)
            let series = try container.decodeIfPresent([[Double]].self, forKey: .series)
            let height = try container.decodeIfPresent(Int.self, forKey: .height) ?? 200
            let color = try container.decodeIfPresent(SemanticColor.self, forKey: .color)
            let valuesPath = try container.decodeIfPresent(String.self, forKey: .valuesPath)
            let labelsPath = try container.decodeIfPresent(String.self, forKey: .labelsPath)
            let seriesPath = try container.decodeIfPresent(String.self, forKey: .seriesPath)
            let seriesPaths = try container.decodeIfPresent([String].self, forKey: .seriesPaths)
            self = .chart(type: chartType, values: values, labels: labels, series: series,
                          height: height, color: color,
                          valuesPath: valuesPath, labelsPath: labelsPath,
                          seriesPath: seriesPath, seriesPaths: seriesPaths)

        case "code":
            let language = try container.decode(String.self, forKey: .language)
            let codeContent = try container.decode(String.self, forKey: .content)
            let codeTitle = try container.decodeIfPresent(String.self, forKey: .title)
            self = .code(language: language, content: codeContent, title: codeTitle)

        case "accordion":
            let accordionTitle = try container.decode(String.self, forKey: .title)
            let children = try container.decodeIfPresent([AmeNode].self, forKey: .children) ?? []
            let expanded = try container.decodeIfPresent(Bool.self, forKey: .expanded) ?? false
            self = .accordion(title: accordionTitle, children: children, expanded: expanded)

        case "carousel":
            let children = try container.decodeIfPresent([AmeNode].self, forKey: .children) ?? []
            let peek = try container.decodeIfPresent(Int.self, forKey: .peek) ?? 24
            self = .carousel(children: children, peek: peek)

        case "callout":
            let calloutType = try container.decode(CalloutType.self, forKey: .inputType)
            let calloutContent = try container.decode(String.self, forKey: .content)
            let calloutTitle = try container.decodeIfPresent(String.self, forKey: .title)
            let calloutColor = try container.decodeIfPresent(SemanticColor.self, forKey: .color)
            self = .callout(type: calloutType, content: calloutContent, title: calloutTitle, color: calloutColor)

        case "timeline":
            let children = try container.decodeIfPresent([AmeNode].self, forKey: .children) ?? []
            self = .timeline(children: children)

        case "timeline_item":
            let itemTitle = try container.decode(String.self, forKey: .title)
            let subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
            let status = try container.decodeIfPresent(TimelineStatus.self, forKey: .status) ?? .pending
            self = .timelineItem(title: itemTitle, subtitle: subtitle, status: status)

        case "ref":
            let id = try container.decode(String.self, forKey: .id)
            self = .ref(id: id)

        case "each":
            let dataPath = try container.decode(String.self, forKey: .dataPath)
            let templateId = try container.decode(String.self, forKey: .templateId)
            self = .each(dataPath: dataPath, templateId: templateId)

        default:
            throw DecodingError.dataCorrupted(
                .init(codingPath: container.codingPath,
                      debugDescription: "Unknown AmeNode _type: \(type)")
            )
        }
    }
}
