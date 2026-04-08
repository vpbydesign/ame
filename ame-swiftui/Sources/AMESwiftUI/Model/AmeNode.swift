import Foundation

/// Sealed type representing all AME UI node types.
///
/// 15 visual primitives (matching primitives.md exactly),
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
    case row(children: [AmeNode] = [], align: Align = .start, gap: Int = 8)

    // MARK: Content Primitives

    /// Text display with typographic style.
    case txt(text: String, style: TxtStyle = .body, maxLines: Int? = nil)

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
    case badge(label: String, variant: BadgeVariant = .default)

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
    /// Serializes as `_type: "list"` matching the Kotlin @SerialName.
    case dataList(children: [AmeNode] = [], dividers: Bool = true)

    /// Grid of text values with a header row.
    case table(headers: [String], rows: [[String]])

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

        case .row(let children, let align, let gap):
            try container.encode("row", forKey: .type)
            if !children.isEmpty { try container.encode(children, forKey: .children) }
            if align != .start { try container.encode(align, forKey: .align) }
            if gap != 8 { try container.encode(gap, forKey: .gap) }

        case .txt(let text, let style, let maxLines):
            try container.encode("txt", forKey: .type)
            try container.encode(text, forKey: .text)
            if style != .body { try container.encode(style, forKey: .style) }
            if let maxLines { try container.encode(maxLines, forKey: .maxLines) }

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

        case .badge(let label, let variant):
            try container.encode("badge", forKey: .type)
            try container.encode(label, forKey: .label)
            if variant != .default { try container.encode(variant, forKey: .variant) }

        case .progress(let value, let label):
            try container.encode("progress", forKey: .type)
            try container.encode(value, forKey: .value)
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
            self = .row(children: children, align: align, gap: gap)

        case "txt":
            let text = try container.decode(String.self, forKey: .text)
            let style = try container.decodeIfPresent(TxtStyle.self, forKey: .style) ?? .body
            let maxLines = try container.decodeIfPresent(Int.self, forKey: .maxLines)
            self = .txt(text: text, style: style, maxLines: maxLines)

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
            self = .badge(label: label, variant: variant)

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
