import Foundation

/// Line-oriented streaming parser that converts AME syntax text into an AmeNode tree.
///
/// Two modes:
/// - Batch: `parse(_:)` -> `AmeNode?` — parses entire document, returns resolved tree
/// - Streaming: `parseLine(_:)` -> `(String, AmeNode)?` — parses one line, may contain Ref nodes
///
/// Implements the EBNF grammar from syntax.md exactly. Handles all 7 error cases
/// without crashing. Never throws unrecoverable exceptions on any input.
public final class AmeParser {

    private var registry: [String: AmeNode] = [:]
    private var dataModel: [String: Any]?
    private var _warnings: [String] = []
    private var _errors: [String] = []

    public var warnings: [String] { _warnings }
    public var errors: [String] { _errors }

    public init() {}

    // MARK: - Batch Mode

    public func parse(_ input: String) -> AmeNode? {
        reset()
        let lines = input.components(separatedBy: .newlines)
        var inDataSection = false
        var dataLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == AmeKeywords.dataSeparator {
                if inDataSection {
                    _warnings.append("Multiple --- separators found; ignoring subsequent ones")
                } else {
                    inDataSection = true
                }
                continue
            }
            if inDataSection {
                dataLines.append(line)
            } else {
                let _ = parseLine(trimmed)
            }
        }

        if !dataLines.isEmpty {
            parseDataSection(dataLines.joined(separator: "\n"))
        }

        guard let root = registry["root"] else { return nil }
        return resolveTree(root)
    }

    // MARK: - Streaming Mode

    @discardableResult
    public func parseLine(_ line: String) -> (String, AmeNode)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return nil }
        if trimmed.hasPrefix("//") { return nil }
        if trimmed == AmeKeywords.dataSeparator { return nil }

        guard let equalsIndex = trimmed.firstIndex(of: "=") else {
            _errors.append("Malformed line (no '='): \(trimmed)")
            return nil
        }

        let identifier = String(trimmed[trimmed.startIndex..<equalsIndex]).trimmingCharacters(in: .whitespaces)
        let expression = String(trimmed[trimmed.index(after: equalsIndex)...]).trimmingCharacters(in: .whitespaces)

        guard !identifier.isEmpty, identifier.first?.isLetter == true else {
            _errors.append("Invalid identifier '\(identifier)' on line: \(trimmed)")
            return nil
        }

        if registry.keys.contains(identifier) {
            _warnings.append("Duplicate identifier '\(identifier)' — replacing previous definition")
        }

        do {
            let node = try parseExpression(expression)
            registry[identifier] = node
            return (identifier, node)
        } catch {
            _errors.append("Parse error on line '\(trimmed)': \(error.localizedDescription)")
            return nil
        }
    }

    public func reset() {
        registry.removeAll()
        dataModel = nil
        _warnings.removeAll()
        _errors.removeAll()
    }

    public func getResolvedTree() -> AmeNode? {
        guard let root = registry["root"] else { return nil }
        return resolveTree(root)
    }

    public func getRegistry() -> [String: AmeNode] {
        registry
    }

    public func getDataModel() -> [String: Any]? {
        dataModel
    }

    // MARK: - Expression Parsing (Recursive Descent)

    private func parseExpression(_ expr: String) throws -> AmeNode {
        let trimmed = expr.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return .txt(text: "", style: .body)
        }

        if trimmed.hasPrefix("\"") {
            return .txt(text: parseStringLiteral(trimmed))
        }

        if trimmed.hasPrefix("$") {
            return .txt(text: trimmed)
        }

        if trimmed.hasPrefix("[") {
            let items = parseArray(trimmed)
            let children = items.map { expressionToNode($0) }
            return .col(children: children)
        }

        let parenIndex = findTopLevelParen(trimmed)
        if parenIndex != nil {
            let idx = parenIndex!
            let name = String(trimmed[trimmed.startIndex..<trimmed.index(trimmed.startIndex, offsetBy: idx)])
                .trimmingCharacters(in: .whitespaces)
            let argsStr = extractParenContent(trimmed, openIndex: idx)
            return parseComponentCall(name, argsStr)
        }

        if trimmed == "true" || trimmed == "false" {
            return .txt(text: trimmed)
        }

        return .ref(id: trimmed)
    }

    // MARK: - Intermediate Parsed Value System

    private indirect enum ParsedValue {
        case str(String)
        case num(intVal: Int?, floatVal: Float?)
        case bool(Bool)
        case arr([String])
        case dataRef(String)
        case ident(String)
        case nodeValue(AmeNode)
        case actionValue(AmeAction)
        case namedArg(key: String, value: ParsedValue)

        var asInt: Int {
            switch self {
            case .num(let i, let f): return i ?? (f.map { Int($0) } ?? 0)
            default: return 0
            }
        }

        var asFloat: Float {
            switch self {
            case .num(let i, let f): return f ?? (i.map { Float($0) } ?? 0)
            default: return 0
            }
        }
    }

    private func parseArgValue(_ arg: String) -> ParsedValue {
        let trimmed = arg.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return .str("") }

        let namedEq = findNamedArgEquals(trimmed)
        if namedEq >= 0 {
            let keyEnd = trimmed.index(trimmed.startIndex, offsetBy: namedEq)
            let key = String(trimmed[trimmed.startIndex..<keyEnd]).trimmingCharacters(in: .whitespaces)
            let valStr = String(trimmed[trimmed.index(after: keyEnd)...]).trimmingCharacters(in: .whitespaces)
            return .namedArg(key: key, value: parseArgValue(valStr))
        }

        if trimmed.hasPrefix("\"") {
            return .str(parseStringLiteral(trimmed))
        }

        if trimmed.hasPrefix("$") {
            return .dataRef(String(trimmed.dropFirst()))
        }

        if trimmed.hasPrefix("[") {
            return .arr(parseArray(trimmed))
        }

        if trimmed == "true" { return .bool(true) }
        if trimmed == "false" { return .bool(false) }

        if let first = trimmed.first,
           first.isNumber || (first == "-" && trimmed.count > 1 && trimmed[trimmed.index(after: trimmed.startIndex)].isNumber) {
            return parseNumber(trimmed)
        }

        if let parenIdx = findTopLevelParen(trimmed) {
            let name = String(trimmed[trimmed.startIndex..<trimmed.index(trimmed.startIndex, offsetBy: parenIdx)])
                .trimmingCharacters(in: .whitespaces)
            let argsContent = extractParenContent(trimmed, openIndex: parenIdx)

            if AmeKeywords.actionNames.contains(name) {
                return .actionValue(parseActionCall(name, argsContent))
            }
            if AmeKeywords.standardPrimitives.contains(name) || name == "each" {
                return .nodeValue(parseComponentCall(name, argsContent))
            }
            return .nodeValue(parseComponentCall(name, argsContent))
        }

        return .ident(trimmed)
    }

    private func expressionToNode(_ exprStr: String) -> AmeNode {
        let parsed = parseArgValue(exprStr.trimmingCharacters(in: .whitespaces))
        switch parsed {
        case .nodeValue(let node): return node
        case .ident(let name): return .ref(id: name)
        case .str(let value): return .txt(text: value)
        case .dataRef(let path): return .txt(text: "$\(path)")
        case .num(let i, let f):
            return .txt(text: i.map { String($0) } ?? f.map { String($0) } ?? "0")
        case .bool(let v): return .txt(text: String(v))
        case .arr(let items):
            let children = items.map { expressionToNode($0) }
            return .col(children: children)
        case .actionValue(let action):
            return .txt(text: "action:\(action)")
        case .namedArg(let key, let value):
            return .txt(text: "\(key)=\(value)")
        }
    }

    // MARK: - Component Call Dispatch

    private func parseComponentCall(_ name: String, _ argsStr: String) -> AmeNode {
        let args = splitArgs(argsStr)
        var positional: [ParsedValue] = []
        var named: [String: ParsedValue] = [:]

        for argStr in args {
            let parsed = parseArgValue(argStr)
            if case .namedArg(let key, let value) = parsed {
                named[key] = value
            } else {
                positional.append(parsed)
            }
        }

        switch name {
        case "col": return buildCol(positional, named)
        case "row": return buildRow(positional, named)
        case "txt": return buildTxt(positional, named)
        case "img": return buildImg(positional, named)
        case "icon": return buildIcon(positional, named)
        case "divider": return .divider
        case "spacer": return buildSpacer(positional, named)
        case "card": return buildCard(positional, named)
        case "badge": return buildBadge(positional, named)
        case "progress": return buildProgress(positional, named)
        case "btn": return buildBtn(positional, named)
        case "input": return buildInput(positional, named)
        case "toggle": return buildToggle(positional, named)
        case "list": return buildList(positional, named)
        case "table": return buildTable(positional, named)
        case "each": return buildEach(positional, named)
        case "chart": return buildChart(positional, named)
        case "code": return buildCode(positional, named)
        case "accordion": return buildAccordion(positional, named)
        case "carousel": return buildCarousel(positional, named)
        case "callout": return buildCallout(positional, named)
        case "timeline": return buildTimeline(positional, named)
        case "timeline_item": return buildTimelineItem(positional, named)
        default:
            _warnings.append("Unknown component '\(name)'")
            return .txt(text: "\u{26A0} Unknown: \(name)", style: .caption)
        }
    }

    // MARK: - Builder Functions for Each Primitive

    private func buildCol(_ pos: [ParsedValue], _ named: [String: ParsedValue]) -> AmeNode {
        let children = resolveChildrenArg(pos.first)
        let align = resolveAlignArg(pos.safeGet(1)) ?? .start
        return .col(children: children, align: align)
    }

    private func buildRow(_ pos: [ParsedValue], _ named: [String: ParsedValue]) -> AmeNode {
        let children = resolveChildrenArg(pos.first)
        var align: Align = .start
        var gap = 8

        if let secondArg = pos.safeGet(1) {
            switch secondArg {
            case .num:
                gap = secondArg.asInt
            case .ident(let name):
                if let parsed = AmeKeywords.parseAlign(name) {
                    align = parsed
                } else {
                    _warnings.append("Unknown align value '\(name)', using default")
                }
            default:
                break
            }
        }

        if let thirdArg = pos.safeGet(2) {
            switch thirdArg {
            case .num:
                gap = thirdArg.asInt
            case .ident(let name):
                if let parsed = AmeKeywords.parseAlign(name) {
                    align = parsed
                }
            default:
                break
            }
        }

        return .row(children: children, align: align, gap: gap)
    }

    private func buildTxt(_ pos: [ParsedValue], _ named: [String: ParsedValue]) -> AmeNode {
        let text = resolveStringArg(pos.first)
        let style = resolveTxtStyleArg(pos.safeGet(1)) ?? .body
        let maxLines = named["max_lines"].flatMap { resolveIntArg($0) }
        let color: SemanticColor? = named["color"].flatMap { resolveSemanticColorArg($0) }
        return .txt(text: text, style: style, maxLines: maxLines, color: color)
    }

    private func buildImg(_ pos: [ParsedValue], _ named: [String: ParsedValue]) -> AmeNode {
        let url = resolveStringArg(pos.first)
        let height = pos.safeGet(1).flatMap { resolveIntArg($0) }
        return .img(url: url, height: height)
    }

    private func buildIcon(_ pos: [ParsedValue], _ named: [String: ParsedValue]) -> AmeNode {
        let iconName = resolveStringArg(pos.first)
        let size = pos.safeGet(1).flatMap { resolveIntArg($0) } ?? 20
        return .icon(name: iconName, size: size)
    }

    private func buildSpacer(_ pos: [ParsedValue], _ named: [String: ParsedValue]) -> AmeNode {
        let height = pos.first.flatMap { resolveIntArg($0) } ?? 8
        return .spacer(height: height)
    }

    private func buildCard(_ pos: [ParsedValue], _ named: [String: ParsedValue]) -> AmeNode {
        let children = resolveChildrenArg(pos.first)
        let elevation = pos.safeGet(1).flatMap { resolveIntArg($0) } ?? 1
        return .card(children: children, elevation: elevation)
    }

    private func buildBadge(_ pos: [ParsedValue], _ named: [String: ParsedValue]) -> AmeNode {
        let label = resolveStringArg(pos.first)
        let variant = pos.safeGet(1).flatMap { resolveBadgeVariantArg($0) } ?? .default
        let color: SemanticColor? = named["color"].flatMap { resolveSemanticColorArg($0) }
        return .badge(label: label, variant: variant, color: color)
    }

    private func buildProgress(_ pos: [ParsedValue], _ named: [String: ParsedValue]) -> AmeNode {
        let value = pos.first.flatMap { resolveFloatArg($0) } ?? 0
        let label = pos.safeGet(1).flatMap { resolveStringArgNullable($0) }
        return .progress(value: min(max(value, 0), 1), label: label)
    }

    private func buildBtn(_ pos: [ParsedValue], _ named: [String: ParsedValue]) -> AmeNode {
        let label = resolveStringArg(pos.first)
        let action = resolveActionArg(pos.safeGet(1)) ?? .navigate(route: "_error_no_action")
        let style = pos.safeGet(2).flatMap { resolveBtnStyleArg($0) } ?? .primary
        let icon = named["icon"].flatMap { resolveStringArgNullable($0) }
        return .btn(label: label, action: action, style: style, icon: icon)
    }

    private func buildInput(_ pos: [ParsedValue], _ named: [String: ParsedValue]) -> AmeNode {
        let id = resolveStringArg(pos.first)
        let label = resolveStringArg(pos.safeGet(1))
        let type = pos.safeGet(2).flatMap { resolveInputTypeArg($0) } ?? .text
        let options = named["options"].flatMap { resolveStringListArg($0) }
            ?? pos.safeGet(3).flatMap { resolveStringListArg($0) }
        return .input(id: id, label: label, type: type, options: options)
    }

    private func buildToggle(_ pos: [ParsedValue], _ named: [String: ParsedValue]) -> AmeNode {
        let id = resolveStringArg(pos.first)
        let label = resolveStringArg(pos.safeGet(1))
        let defaultVal = pos.safeGet(2).map { resolveBoolArg($0) } ?? false
        return .toggle(id: id, label: label, default: defaultVal)
    }

    private func buildList(_ pos: [ParsedValue], _ named: [String: ParsedValue]) -> AmeNode {
        let children = resolveChildrenArg(pos.first)
        let dividers = pos.safeGet(1).map { resolveBoolArg($0) } ?? true
        return .dataList(children: children, dividers: dividers)
    }

    private func buildTable(_ pos: [ParsedValue], _ named: [String: ParsedValue]) -> AmeNode {
        let headers = resolveStringListArg(pos.first) ?? []
        let rows = resolveNestedStringListArg(pos.safeGet(1))
        return .table(headers: headers, rows: rows)
    }

    private func buildEach(_ pos: [ParsedValue], _ named: [String: ParsedValue]) -> AmeNode {
        let dataPath: String
        switch pos.first {
        case .dataRef(let path): dataPath = path
        case .str(let value): dataPath = value.hasPrefix("$") ? String(value.dropFirst()) : value
        case .ident(let name): dataPath = name
        default: dataPath = ""
        }

        let templateId: String
        switch pos.safeGet(1) {
        case .ident(let name): templateId = name
        case .str(let value): templateId = value
        default: templateId = ""
        }

        return .each(dataPath: dataPath, templateId: templateId)
    }

    // MARK: - v1.1 Builder Functions

    private func buildChart(_ pos: [ParsedValue], _ named: [String: ParsedValue]) -> AmeNode {
        let type = pos.first.flatMap { resolveChartTypeArg($0) } ?? .bar

        var values: [Double]? = nil
        var valuesPath: String? = nil
        if let valuesArg = named["values"] ?? pos.safeGet(1) {
            switch valuesArg {
            case .dataRef(let path): valuesPath = path
            case .arr: values = resolveDoubleListArg(valuesArg)
            default: break
            }
        }

        var labels: [String]? = nil
        var labelsPath: String? = nil
        if let labelsArg = named["labels"] {
            switch labelsArg {
            case .dataRef(let path): labelsPath = path
            case .arr: labels = resolveStringListArg(labelsArg)
            default: break
            }
        }

        var series: [[Double]]? = nil
        var seriesPath: String? = nil
        if let seriesArg = named["series"] {
            switch seriesArg {
            case .dataRef(let path): seriesPath = path
            case .arr: series = resolveNestedDoubleListArg(seriesArg)
            default: break
            }
        }

        let height = named["height"].flatMap { resolveIntArg($0) } ?? 200
        let color: SemanticColor? = named["color"].flatMap { resolveSemanticColorArg($0) }

        return .chart(type: type, values: values, labels: labels, series: series,
                      height: height, color: color,
                      valuesPath: valuesPath, labelsPath: labelsPath, seriesPath: seriesPath)
    }

    private func buildCode(_ pos: [ParsedValue], _ named: [String: ParsedValue]) -> AmeNode {
        let language = resolveStringArg(pos.first)
        let content = resolveStringArg(pos.safeGet(1))
        let title = pos.safeGet(2).flatMap { resolveStringArgNullable($0) }
        return .code(language: language, content: content, title: title)
    }

    private func buildAccordion(_ pos: [ParsedValue], _ named: [String: ParsedValue]) -> AmeNode {
        let title = resolveStringArg(pos.first)
        let children = resolveChildrenArg(pos.safeGet(1))
        let expanded = pos.safeGet(2).map { resolveBoolArg($0) } ?? false
        return .accordion(title: title, children: children, expanded: expanded)
    }

    private func buildCarousel(_ pos: [ParsedValue], _ named: [String: ParsedValue]) -> AmeNode {
        let children = resolveChildrenArg(pos.first)
        let peek = named["peek"].flatMap { resolveIntArg($0) } ?? 24
        return .carousel(children: children, peek: peek)
    }

    private func buildCallout(_ pos: [ParsedValue], _ named: [String: ParsedValue]) -> AmeNode {
        let type = pos.first.flatMap { resolveCalloutTypeArg($0) } ?? .info
        let content = resolveStringArg(pos.safeGet(1))
        let title = pos.safeGet(2).flatMap { resolveStringArgNullable($0) }
        return .callout(type: type, content: content, title: title)
    }

    private func buildTimeline(_ pos: [ParsedValue], _ named: [String: ParsedValue]) -> AmeNode {
        let children = resolveChildrenArg(pos.first)
        return .timeline(children: children)
    }

    private func buildTimelineItem(_ pos: [ParsedValue], _ named: [String: ParsedValue]) -> AmeNode {
        let title = resolveStringArg(pos.first)
        let subtitle = pos.safeGet(1).flatMap { resolveStringArgNullable($0) }
        let status = pos.safeGet(2).flatMap { resolveTimelineStatusArg($0) } ?? .pending
        return .timelineItem(title: title, subtitle: subtitle, status: status)
    }

    // MARK: - Action Call Dispatch

    private func parseActionCall(_ name: String, _ argsStr: String) -> AmeAction {
        let args = splitArgs(argsStr)
        var positional: [ParsedValue] = []
        var named: [String: ParsedValue] = [:]

        for argStr in args {
            let parsed = parseArgValue(argStr)
            if case .namedArg(let key, let value) = parsed {
                named[key] = value
            } else {
                positional.append(parsed)
            }
        }

        switch name {
        case "tool": return buildToolAction(positional, named)
        case "uri": return buildUriAction(positional)
        case "nav": return buildNavAction(positional)
        case "copy": return buildCopyAction(positional)
        case "submit": return buildSubmitAction(positional, named)
        default:
            _warnings.append("Unknown action type '\(name)'")
            return .navigate(route: "_error_unknown_action")
        }
    }

    private func buildToolAction(_ pos: [ParsedValue], _ named: [String: ParsedValue]) -> AmeAction {
        let toolName = resolveIdentOrStringArg(pos.first)
        var argsMap: [String: String] = [:]
        for (key, value) in named {
            argsMap[key] = resolveStringArg(value)
        }
        return .callTool(name: toolName, args: argsMap)
    }

    private func buildUriAction(_ pos: [ParsedValue]) -> AmeAction {
        let uri = resolveStringArg(pos.first)
        return .openUri(uri: uri)
    }

    private func buildNavAction(_ pos: [ParsedValue]) -> AmeAction {
        let route = resolveStringArg(pos.first)
        return .navigate(route: route)
    }

    private func buildCopyAction(_ pos: [ParsedValue]) -> AmeAction {
        let text = resolveStringArg(pos.first)
        return .copyText(text: text)
    }

    private func buildSubmitAction(_ pos: [ParsedValue], _ named: [String: ParsedValue]) -> AmeAction {
        let toolName = resolveIdentOrStringArg(pos.first)
        var staticArgs: [String: String] = [:]
        for (key, value) in named {
            staticArgs[key] = resolveStringArg(value)
        }
        return .submit(toolName: toolName, staticArgs: staticArgs)
    }

    // MARK: - Argument Resolution Helpers

    private func resolveChildrenArg(_ arg: ParsedValue?) -> [AmeNode] {
        guard let arg else { return [] }
        switch arg {
        case .arr(let items): return items.map { expressionToNode($0) }
        case .nodeValue(let node):
            if case .col(let children, _) = node { return children }
            return [node]
        default: return []
        }
    }

    private func resolveStringArg(_ arg: ParsedValue?) -> String {
        guard let arg else { return "" }
        switch arg {
        case .str(let value): return value
        case .ident(let name): return name
        case .dataRef(let path): return "$\(path)"
        case .num(let i, let f): return i.map { String($0) } ?? f.map { String($0) } ?? "0"
        case .bool(let v): return String(v)
        default: return String(describing: arg)
        }
    }

    private func resolveStringArgNullable(_ arg: ParsedValue?) -> String? {
        guard let arg else { return nil }
        return resolveStringArg(arg)
    }

    /// Accepts both quoted strings and unquoted identifiers as string values (leniency).
    private func resolveIdentOrStringArg(_ arg: ParsedValue?) -> String {
        guard let arg else { return "" }
        switch arg {
        case .ident(let name): return name
        case .str(let value): return value
        case .dataRef(let path): return "$\(path)"
        default: return resolveStringArg(arg)
        }
    }

    private func resolveIntArg(_ arg: ParsedValue) -> Int? {
        switch arg {
        case .num(let i, let f): return i ?? f.map { Int($0) }
        case .str(let value): return Int(value)
        case .ident(let name): return Int(name)
        default: return nil
        }
    }

    private func resolveFloatArg(_ arg: ParsedValue) -> Float? {
        switch arg {
        case .num(_, let f) where f != nil: return f
        case .num(let i, _) where i != nil: return Float(i!)
        case .str(let value): return Float(value)
        case .ident(let name): return Float(name)
        default: return nil
        }
    }

    private func resolveBoolArg(_ arg: ParsedValue) -> Bool {
        switch arg {
        case .bool(let value): return value
        case .ident(let name): return name.lowercased() == "true"
        case .str(let value): return value.lowercased() == "true"
        default: return false
        }
    }

    private func resolveAlignArg(_ arg: ParsedValue?) -> Align? {
        guard let arg else { return nil }
        switch arg {
        case .ident(let name): return AmeKeywords.parseAlign(name)
        case .str(let value): return AmeKeywords.parseAlign(value)
        default: return nil
        }
    }

    private func resolveTxtStyleArg(_ arg: ParsedValue?) -> TxtStyle? {
        guard let arg else { return nil }
        switch arg {
        case .ident(let name): return AmeKeywords.parseTxtStyle(name)
        case .str(let value): return AmeKeywords.parseTxtStyle(value)
        default:
            _warnings.append("Unknown txt style: \(arg), using default")
            return nil
        }
    }

    private func resolveBtnStyleArg(_ arg: ParsedValue?) -> BtnStyle? {
        guard let arg else { return nil }
        switch arg {
        case .ident(let name): return AmeKeywords.parseBtnStyle(name)
        case .str(let value): return AmeKeywords.parseBtnStyle(value)
        default:
            _warnings.append("Unknown btn style: \(arg), using default")
            return nil
        }
    }

    private func resolveBadgeVariantArg(_ arg: ParsedValue?) -> BadgeVariant? {
        guard let arg else { return nil }
        switch arg {
        case .ident(let name): return AmeKeywords.parseBadgeVariant(name)
        case .str(let value): return AmeKeywords.parseBadgeVariant(value)
        default:
            _warnings.append("Unknown badge variant: \(arg), using default")
            return nil
        }
    }

    private func resolveInputTypeArg(_ arg: ParsedValue?) -> InputType? {
        guard let arg else { return nil }
        switch arg {
        case .ident(let name): return AmeKeywords.parseInputType(name)
        case .str(let value): return AmeKeywords.parseInputType(value)
        default:
            _warnings.append("Unknown input type: \(arg), using default")
            return nil
        }
    }

    private func resolveActionArg(_ arg: ParsedValue?) -> AmeAction? {
        guard let arg else { return nil }
        switch arg {
        case .actionValue(let action): return action
        case .ident(let name):
            _warnings.append("Expected action expression, got identifier '\(name)'")
            return nil
        default:
            _warnings.append("Expected action expression, got: \(arg)")
            return nil
        }
    }

    private func resolveStringListArg(_ arg: ParsedValue?) -> [String]? {
        guard let arg else { return nil }
        if case .arr(let items) = arg {
            return items.map { resolveStringArg(parseArgValue($0.trimmingCharacters(in: .whitespaces))) }
        }
        return nil
    }

    private func resolveNestedStringListArg(_ arg: ParsedValue?) -> [[String]] {
        guard let arg else { return [] }
        if case .arr(let items) = arg {
            return items.map { rowStr in
                let rowParsed = parseArgValue(rowStr.trimmingCharacters(in: .whitespaces))
                if case .arr(let cells) = rowParsed {
                    return cells.map { cellStr in
                        resolveStringArg(parseArgValue(cellStr.trimmingCharacters(in: .whitespaces)))
                    }
                }
                return [resolveStringArg(rowParsed)]
            }
        }
        return []
    }

    // MARK: - v1.1 Enum Resolution Helpers

    private func resolveChartTypeArg(_ arg: ParsedValue?) -> ChartType? {
        guard let arg else { return nil }
        switch arg {
        case .ident(let name): return AmeKeywords.parseChartType(name)
        case .str(let value): return AmeKeywords.parseChartType(value)
        default: return nil
        }
    }

    private func resolveCalloutTypeArg(_ arg: ParsedValue?) -> CalloutType? {
        guard let arg else { return nil }
        switch arg {
        case .ident(let name): return AmeKeywords.parseCalloutType(name)
        case .str(let value): return AmeKeywords.parseCalloutType(value)
        default: return nil
        }
    }

    private func resolveTimelineStatusArg(_ arg: ParsedValue?) -> TimelineStatus? {
        guard let arg else { return nil }
        switch arg {
        case .ident(let name): return AmeKeywords.parseTimelineStatus(name)
        case .str(let value): return AmeKeywords.parseTimelineStatus(value)
        default: return nil
        }
    }

    private func resolveSemanticColorArg(_ arg: ParsedValue?) -> SemanticColor? {
        guard let arg else { return nil }
        switch arg {
        case .ident(let name): return AmeKeywords.parseSemanticColor(name)
        case .str(let value): return AmeKeywords.parseSemanticColor(value)
        default: return nil
        }
    }

    // MARK: - Numeric Array Resolution Helpers

    private func resolveDoubleListArg(_ arg: ParsedValue?) -> [Double]? {
        guard case .arr(let items) = arg else { return nil }
        return items.compactMap { item -> Double? in
            Double(item.trimmingCharacters(in: .whitespaces))
        }
    }

    private func resolveNestedDoubleListArg(_ arg: ParsedValue?) -> [[Double]]? {
        guard case .arr(let items) = arg else { return nil }
        return items.compactMap { rowStr -> [Double]? in
            let rowParsed = parseArgValue(rowStr.trimmingCharacters(in: .whitespaces))
            guard case .arr(let cells) = rowParsed else { return nil }
            return cells.compactMap { cellStr -> Double? in
                Double(cellStr.trimmingCharacters(in: .whitespaces))
            }
        }
    }

    // MARK: - String Literal Parser

    private func parseStringLiteral(_ input: String) -> String {
        guard input.hasPrefix("\"") else { return input }

        var result = ""
        var i = input.index(after: input.startIndex)
        var escaped = false

        while i < input.endIndex {
            let c = input[i]
            if escaped {
                switch c {
                case "\"": result.append("\"")
                case "\\": result.append("\\")
                case "n": result.append("\n")
                case "t": result.append("\t")
                default:
                    result.append("\\")
                    result.append(c)
                }
                escaped = false
            } else {
                switch c {
                case "\\": escaped = true
                case "\"": return result
                default: result.append(c)
                }
            }
            i = input.index(after: i)
        }

        _warnings.append("Unclosed string literal, implicitly closing at end of line")
        return result
    }

    // MARK: - Number Parser

    private func parseNumber(_ input: String) -> ParsedValue {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        if trimmed.contains(".") {
            if let f = Float(trimmed) { return .num(intVal: nil, floatVal: f) }
            _warnings.append("Invalid number '\(trimmed)', treating as string")
            return .str(trimmed)
        }
        if let i = Int(trimmed) { return .num(intVal: i, floatVal: nil) }
        _warnings.append("Invalid number '\(trimmed)', treating as string")
        return .str(trimmed)
    }

    // MARK: - Array Parser

    private func parseArray(_ input: String) -> [String] {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("[") else { return [] }

        var depth = 0
        var endIdx: String.Index?
        for i in trimmed.indices {
            switch trimmed[i] {
            case "[": depth += 1
            case "]":
                depth -= 1
                if depth == 0 {
                    endIdx = i
                    break
                }
            default: break
            }
            if endIdx != nil { break }
        }

        let content: String
        if let end = endIdx, end > trimmed.index(after: trimmed.startIndex) {
            content = String(trimmed[trimmed.index(after: trimmed.startIndex)..<end])
                .trimmingCharacters(in: .whitespaces)
        } else {
            _warnings.append("Unclosed bracket in array, implicitly closing")
            var s = String(trimmed.dropFirst())
            if s.hasSuffix("]") { s = String(s.dropLast()) }
            content = s.trimmingCharacters(in: .whitespaces)
        }

        if content.isEmpty { return [] }
        return splitTopLevel(content, delimiter: ",")
    }

    // MARK: - Argument Splitter State Machine

    private func splitArgs(_ argsStr: String) -> [String] {
        let trimmed = argsStr.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return [] }
        return splitTopLevel(trimmed, delimiter: ",")
    }

    /// Splits a string on `delimiter` while respecting nesting in (), [], and "".
    /// This is the core state machine that prevents splitting inside nested
    /// component calls, arrays, or string literals.
    private func splitTopLevel(_ input: String, delimiter: Character) -> [String] {
        var result: [String] = []
        var current = ""
        var parenDepth = 0
        var bracketDepth = 0
        var inString = false
        var escaped = false

        for c in input {
            if escaped {
                current.append(c)
                escaped = false
                continue
            }

            if inString {
                current.append(c)
                switch c {
                case "\\": escaped = true
                case "\"": inString = false
                default: break
                }
                continue
            }

            switch c {
            case "\"":
                inString = true
                current.append(c)
            case "(":
                parenDepth += 1
                current.append(c)
            case ")":
                parenDepth -= 1
                current.append(c)
            case "[":
                bracketDepth += 1
                current.append(c)
            case "]":
                bracketDepth -= 1
                current.append(c)
            case delimiter:
                if parenDepth == 0 && bracketDepth == 0 {
                    result.append(current.trimmingCharacters(in: .whitespaces))
                    current = ""
                } else {
                    current.append(c)
                }
            default:
                current.append(c)
            }
        }

        let remaining = current.trimmingCharacters(in: .whitespaces)
        if !remaining.isEmpty {
            result.append(remaining)
        }

        return result
    }

    // MARK: - Named Argument Detection

    /// Find the '=' for a named argument (key=value).
    /// Returns -1 if this is not a named arg.
    private func findNamedArgEquals(_ input: String) -> Int {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.first?.isLetter == true else { return -1 }

        var i = trimmed.startIndex
        while i < trimmed.endIndex && (trimmed[i].isLetter || trimmed[i].isNumber || trimmed[i] == "_") {
            i = trimmed.index(after: i)
        }

        var j = i
        while j < trimmed.endIndex && trimmed[j] == " " {
            j = trimmed.index(after: j)
        }

        if j < trimmed.endIndex && trimmed[j] == "=" {
            let key = String(trimmed[trimmed.startIndex..<i]).trimmingCharacters(in: .whitespaces)
            if !key.isEmpty && key.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) {
                return trimmed.distance(from: trimmed.startIndex, to: j)
            }
        }

        return -1
    }

    // MARK: - Parenthesis Helpers

    /// Returns the character offset (Int) of the first top-level '(' in input, or nil.
    private func findTopLevelParen(_ input: String) -> Int? {
        var inString = false
        var escaped = false
        var offset = 0

        for c in input {
            if escaped { escaped = false; offset += 1; continue }
            if inString {
                switch c {
                case "\\": escaped = true
                case "\"": inString = false
                default: break
                }
                offset += 1
                continue
            }
            switch c {
            case "\"": inString = true
            case "(": return offset
            default: break
            }
            offset += 1
        }
        return nil
    }

    /// Extracts the content between matching parentheses starting at openIndex (character offset).
    private func extractParenContent(_ input: String, openIndex: Int) -> String {
        let startIdx = input.index(input.startIndex, offsetBy: openIndex)
        var depth = 0
        var closeIdx: String.Index?

        var i = startIdx
        while i < input.endIndex {
            switch input[i] {
            case "(": depth += 1
            case ")":
                depth -= 1
                if depth == 0 {
                    closeIdx = i
                    break
                }
            default: break
            }
            if closeIdx != nil { break }
            i = input.index(after: i)
        }

        if let close = closeIdx, close > input.index(after: startIdx) {
            return String(input[input.index(after: startIdx)..<close])
        } else if closeIdx == nil {
            _warnings.append("Unclosed parenthesis, implicitly closing at end of expression")
            var s = String(input[input.index(after: startIdx)...])
            if s.hasSuffix(")") { s = String(s.dropLast()) }
            return s
        } else {
            return ""
        }
    }

    // MARK: - Data Section Parsing

    private func parseDataSection(_ jsonText: String) {
        let trimmed = jsonText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return }

        guard let data = trimmed.data(using: .utf8) else {
            _errors.append("Data section is not valid UTF-8")
            return
        }

        do {
            let parsed = try JSONSerialization.jsonObject(with: data, options: [])
            if let dict = parsed as? [String: Any] {
                dataModel = dict
            } else {
                _errors.append("Data model must be a JSON object, got: \(type(of: parsed))")
            }
        } catch {
            _errors.append("Invalid JSON in data section: \(error.localizedDescription)")
        }
    }

    // MARK: - Tree Resolution (Forward Refs, $path, each() expansion)

    private func resolveTree(_ node: AmeNode, scope: [String: Any]? = nil) -> AmeNode {
        let effectiveScope = scope ?? dataModel
        switch node {
        case .col(let children, let align):
            return .col(children: resolveChildren(children, scope: effectiveScope), align: align)
        case .row(let children, let align, let gap):
            return .row(children: resolveChildren(children, scope: effectiveScope), align: align, gap: gap)
        case .card(let children, let elevation):
            return .card(children: resolveChildren(children, scope: effectiveScope), elevation: elevation)
        case .dataList(let children, let dividers):
            return .dataList(children: resolveChildren(children, scope: effectiveScope), dividers: dividers)
        case .accordion(let title, let children, let expanded):
            let resolvedTitle = effectiveScope.map { resolvePathInScope(title, scope: $0) } ?? title
            return .accordion(title: resolvedTitle, children: resolveChildren(children, scope: effectiveScope), expanded: expanded)
        case .carousel(let children, let peek):
            return .carousel(children: resolveChildren(children, scope: effectiveScope), peek: peek)
        case .timeline(let children):
            return .timeline(children: resolveChildren(children, scope: effectiveScope))
        case .ref(let id):
            if let resolved = registry[id] { return resolveTree(resolved, scope: effectiveScope) }
            return node
        case .each:
            guard let s = effectiveScope else { return node }
            let expanded = expandEach(node, parentScope: s)
            if expanded.count == 1 { return expanded[0] }
            return .col(children: expanded)
        case .txt(let text, let style, let maxLines, let color):
            guard let s = effectiveScope else { return node }
            return .txt(text: resolvePathInScope(text, scope: s), style: style, maxLines: maxLines, color: color)
        case .img(let url, let height):
            guard let s = effectiveScope else { return node }
            return .img(url: resolvePathInScope(url, scope: s), height: height)
        case .badge(let label, let variant, let color):
            guard let s = effectiveScope else { return node }
            return .badge(label: resolvePathInScope(label, scope: s), variant: variant, color: color)
        case .progress(let value, let label):
            guard let s = effectiveScope, let lbl = label else { return node }
            return .progress(value: value, label: resolvePathInScope(lbl, scope: s))
        case .btn(let label, let action, let style, let icon):
            guard let s = effectiveScope else { return node }
            return .btn(label: resolvePathInScope(label, scope: s), action: action, style: style, icon: icon)
        case .icon(let name, let size):
            guard let s = effectiveScope else { return node }
            return .icon(name: resolvePathInScope(name, scope: s), size: size)
        case .callout(let calloutType, let content, let title):
            guard let s = effectiveScope else { return node }
            return .callout(type: calloutType, content: resolvePathInScope(content, scope: s),
                            title: title.map { resolvePathInScope($0, scope: s) })
        case .code(let language, let content, let title):
            guard let s = effectiveScope else { return node }
            return .code(language: language, content: resolvePathInScope(content, scope: s),
                         title: title.map { resolvePathInScope($0, scope: s) })
        case .timelineItem(let title, let subtitle, let status):
            guard let s = effectiveScope else { return node }
            return .timelineItem(title: resolvePathInScope(title, scope: s),
                                 subtitle: subtitle.map { resolvePathInScope($0, scope: s) }, status: status)
        case .chart:
            return resolveChartPaths(node, scope: effectiveScope)
        default:
            return node
        }
    }

    private func resolveChildren(_ children: [AmeNode], scope: [String: Any]?) -> [AmeNode] {
        children.map { child in
            switch child {
            case .ref(let id):
                if let resolved = registry[id] { return resolveTree(resolved, scope: scope) }
                return child
            default:
                return resolveTree(child, scope: scope)
            }
        }
    }

    private func expandEach(_ node: AmeNode, parentScope: [String: Any]) -> [AmeNode] {
        guard case .each(let dataPath, let templateId) = node else { return [] }
        guard let array = resolveDataArray(dataPath, scope: parentScope) else { return [] }
        if array.isEmpty { return [] }

        guard let template = registry[templateId] else {
            _warnings.append("each() template '\(templateId)' not found in registry")
            return []
        }

        return array.compactMap { element in
            guard let dict = element as? [String: Any] else {
                _warnings.append("each() array element is not a JSON object")
                return nil
            }
            return resolveTree(template, scope: dict)
        }
    }

    private func resolveDataArray(_ path: String, scope: [String: Any]) -> [[String: Any]?]? {
        let segments = path.hasPrefix("$") ? String(path.dropFirst()).components(separatedBy: "/")
                                           : path.components(separatedBy: "/")
        var current: Any = scope
        for segment in segments {
            guard let dict = current as? [String: Any],
                  let next = dict[segment] else {
                _warnings.append("each() path segment '\(segment)' not found in data model")
                return nil
            }
            current = next
        }
        guard let array = current as? [Any] else {
            _warnings.append("each() path '\(path)' resolved to \(type(of: current)), expected Array")
            return nil
        }
        return array.map { $0 as? [String: Any] }
    }

    private func resolvePathInScope(_ value: String, scope: [String: Any]) -> String {
        guard value.hasPrefix("$") else { return value }
        let segments = String(value.dropFirst()).components(separatedBy: "/")
        var current: Any = scope
        for segment in segments {
            guard let dict = current as? [String: Any],
                  let next = dict[segment] else {
                return ""
            }
            current = next
        }
        if let s = current as? String { return s }
        if let n = current as? NSNumber { return n.stringValue }
        return ""
    }

    // MARK: - Chart $path Data Resolution

    private func resolveChartPaths(_ node: AmeNode, scope: [String: Any]?) -> AmeNode {
        guard case .chart(let type, let values, let labels, let series,
                          let height, let color, let valuesPath, let labelsPath, let seriesPath) = node else {
            return node
        }
        guard let s = scope else { return node }

        let resolvedValues = values ?? valuesPath.flatMap { resolveDoubleArrayFromData($0, scope: s) }
        let resolvedLabels = labels ?? labelsPath.flatMap { resolveStringArrayFromData($0, scope: s) }
        let resolvedSeries = series ?? seriesPath.flatMap { resolveNestedDoubleArrayFromData($0, scope: s) }

        return .chart(type: type, values: resolvedValues, labels: resolvedLabels, series: resolvedSeries,
                      height: height, color: color,
                      valuesPath: nil, labelsPath: nil, seriesPath: nil)
    }

    private func resolveDoubleArrayFromData(_ path: String, scope: [String: Any]) -> [Double]? {
        let element = navigateDataPath(path, scope: scope)
        guard let array = element as? [Any] else { return nil }
        return array.compactMap { item -> Double? in
            if let n = item as? NSNumber { return n.doubleValue }
            if let s = item as? String { return Double(s) }
            return nil
        }
    }

    private func resolveStringArrayFromData(_ path: String, scope: [String: Any]) -> [String]? {
        let element = navigateDataPath(path, scope: scope)
        guard let array = element as? [Any] else { return nil }
        return array.compactMap { item -> String? in
            if let s = item as? String { return s }
            if let n = item as? NSNumber { return n.stringValue }
            return nil
        }
    }

    private func resolveNestedDoubleArrayFromData(_ path: String, scope: [String: Any]) -> [[Double]]? {
        let element = navigateDataPath(path, scope: scope)
        guard let outerArray = element as? [Any] else { return nil }
        return outerArray.compactMap { inner -> [Double]? in
            guard let innerArray = inner as? [Any] else { return nil }
            return innerArray.compactMap { item -> Double? in
                if let n = item as? NSNumber { return n.doubleValue }
                if let s = item as? String { return Double(s) }
                return nil
            }
        }
    }

    private func navigateDataPath(_ path: String, scope: [String: Any]) -> Any? {
        let segments = path.hasPrefix("$") ? String(path.dropFirst()).components(separatedBy: "/")
                                           : path.components(separatedBy: "/")
        var current: Any = scope
        for segment in segments {
            guard let dict = current as? [String: Any],
                  let next = dict[segment] else {
                return nil
            }
            current = next
        }
        return current
    }

    // MARK: - Data Model Access

    /// Resolve a $path reference against the data model.
    /// Path segments are separated by '/'.
    public func resolveDataPath(_ path: String) -> String? {
        guard let model = dataModel else { return nil }
        let segments = path.hasPrefix("$") ? String(path.dropFirst()).components(separatedBy: "/")
                                           : path.components(separatedBy: "/")
        var current: Any = model

        for segment in segments {
            guard let dict = current as? [String: Any],
                  let next = dict[segment] else {
                return nil
            }
            current = next
        }

        if let s = current as? String { return s }
        if let n = current as? NSNumber { return n.stringValue }
        return nil
    }
}

// MARK: - Array Safe Access

private extension Array {
    func safeGet(_ index: Int) -> Element? {
        index < count ? self[index] : nil
    }
}
