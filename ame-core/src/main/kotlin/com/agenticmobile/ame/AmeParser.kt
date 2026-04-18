package com.agenticmobile.ame

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull

/**
 * Line-oriented streaming parser that converts AME syntax text into an AmeNode tree.
 *
 * Two modes:
 * - Batch: parse(input) -> AmeNode? — parses entire document, returns resolved tree
 * - Streaming: parseLine(line) -> Pair<String, AmeNode>? — parses one line, may contain Ref nodes
 *
 * Implements the EBNF grammar from syntax.md exactly. Handles all 7 error cases
 * without crashing. Never throws unrecoverable exceptions on any input.
 */
class AmeParser {

    private val registry = mutableMapOf<String, AmeNode>()
    private var dataModel: JsonObject? = null
    private val _warnings = mutableListOf<String>()
    private val _errors = mutableListOf<String>()

    // Streaming-mode data section state (Bug 8). When parseLine() is the only
    // ingest API in use, calling parseLine("---") flips streamingDataMode on,
    // and subsequent parseLine() calls accumulate into streamingDataBuffer
    // until getResolvedTree() finalizes by parsing the buffer through
    // parseDataSection. streamingDataApplied guards idempotence so repeated
    // getResolvedTree() calls do not re-parse the buffer. The batch parse(
    // input: String) entry path manages its own dataLines accumulator and
    // never trips this state machine.
    private var streamingDataMode: Boolean = false
    private val streamingDataBuffer: StringBuilder = StringBuilder()
    private var streamingDataApplied: Boolean = false

    val warnings: List<String> get() = _warnings.toList()
    val errors: List<String> get() = _errors.toList()

    // ── Batch Mode ─────────────────────────────────────────────────────

    fun parse(input: String): AmeNode? {
        reset()
        val lines = input.lines()
        var inDataSection = false
        val dataLines = mutableListOf<String>()

        for (line in lines) {
            val trimmed = line.trim()
            if (trimmed == AmeKeywords.DATA_SEPARATOR) {
                if (inDataSection) {
                    _warnings.add("Multiple --- separators found; ignoring subsequent ones")
                } else {
                    inDataSection = true
                }
                continue
            }
            if (inDataSection) {
                dataLines.add(line)
            } else {
                parseLine(trimmed)
            }
        }

        if (dataLines.isNotEmpty()) {
            parseDataSection(dataLines.joinToString("\n"))
        }

        return registry["root"]?.let { resolveTree(it) }
    }

    // ── Streaming Mode ─────────────────────────────────────────────────

    fun parseLine(line: String): Pair<String, AmeNode>? {
        val trimmed = line.trim()
        if (trimmed.isEmpty()) return null
        if (trimmed.startsWith("//")) return null
        if (trimmed == AmeKeywords.DATA_SEPARATOR) {
            // Bug 8: flip streaming-mode data accumulator on. Subsequent
            // parseLine() calls feed streamingDataBuffer until the next
            // reset(). Mirrors the batch parse() warning when the separator
            // is seen twice on the same parser lifetime.
            if (streamingDataMode) {
                _warnings.add("Multiple --- separators found; ignoring subsequent ones")
            } else {
                streamingDataMode = true
                streamingDataApplied = false
            }
            return null
        }
        if (streamingDataMode) {
            // Disambiguate JSON content from AME identifier definitions in
            // streaming mode. AME identifiers are required to start with a
            // letter (see the identifier-shape check below at parseLine
            // body), so a letter-prefixed line is AME and anything else
            // (`{`, `}`, `[`, `]`, `"`, digit, sign, whitespace) accumulates
            // into the JSON buffer. This lets streaming consumers emit
            // either order: AME-then-`---`-then-JSON (mirrors batch parse()),
            // or `---`-then-JSON-then-AME (the audit test's contract).
            val firstChar = trimmed.first()
            if (!firstChar.isLetter()) {
                streamingDataBuffer.append(line).append('\n')
                return null
            }
            // Falls through to AME identifier handling below.
        }

        val equalsIndex = trimmed.indexOf('=')
        if (equalsIndex == -1) {
            _errors.add("Malformed line (no '='): $trimmed")
            return null
        }

        val identifier = trimmed.substring(0, equalsIndex).trim()
        val expression = trimmed.substring(equalsIndex + 1).trim()

        if (identifier.isEmpty() || !identifier[0].isLetter()) {
            _errors.add("Invalid identifier '$identifier' on line: $trimmed")
            return null
        }

        // Bug 9 (v1.2 resolution): syntax.md previously listed every enum value
        // token (TxtStyle, BtnStyle, BadgeVariant, InputType, ChartType,
        // CalloutType, TimelineStatus, SemanticColor, plus Align) as reserved.
        // Path D of WP#3 retracts that over-aggressive rule because the parser
        // already disambiguates by argument position: `title` on the LHS of
        // `=` is always a registry key, while `title` as a positional argument
        // to `txt(...)` is always evaluated against the TxtStyle enum first.
        // Common identifiers like `title`, `label`, `body`, `text`, `default`
        // are now legal as user-defined identifiers without restriction.
        // The remaining reserved tokens (primitives, action names, structural
        // keywords, boolean literals) ARE genuine collisions that would
        // shadow RHS constructs, but we leave their enforcement to a separate
        // future WP if and when the audit demonstrates a real impact.

        if (registry.containsKey(identifier)) {
            _warnings.add("Duplicate identifier '$identifier' — replacing previous definition")
        }

        return try {
            val node = parseExpression(expression)
            registry[identifier] = node
            identifier to node
        } catch (e: Exception) {
            _errors.add("Parse error on line '$trimmed': ${e.message}")
            null
        }
    }

    fun reset() {
        registry.clear()
        dataModel = null
        _warnings.clear()
        _errors.clear()
        streamingDataMode = false
        streamingDataBuffer.clear()
        streamingDataApplied = false
    }

    fun getResolvedTree(): AmeNode? {
        // Bug 8: finalize the streaming data buffer (if any) before resolving.
        // Guarded by `dataModel == null` so a prior batch parse() that already
        // populated dataModel takes precedence (mixed-mode safety, per the
        // streaming.md contract). Guarded by `!streamingDataApplied` so
        // repeated getResolvedTree() calls are idempotent.
        if (streamingDataBuffer.isNotEmpty() && dataModel == null && !streamingDataApplied) {
            parseDataSection(streamingDataBuffer.toString())
            streamingDataApplied = true
        }
        return registry["root"]?.let { resolveTree(it) }
    }

    fun getRegistry(): Map<String, AmeNode> = registry.toMap()

    // ── Expression Parsing (Recursive Descent) ─────────────────────────

    private fun parseExpression(expr: String): AmeNode {
        val trimmed = expr.trim()
        if (trimmed.isEmpty()) {
            return AmeNode.Txt("", TxtStyle.BODY)
        }

        // String literal -> Txt with body style
        if (trimmed.startsWith("\"")) {
            return AmeNode.Txt(parseStringLiteral(trimmed))
        }

        // Data reference
        if (trimmed.startsWith("$")) {
            return AmeNode.Txt("\$$trimmed".removePrefix("\$\$").let { trimmed })
        }

        // Array
        if (trimmed.startsWith("[")) {
            val items = parseArray(trimmed)
            val children = items.map { expressionToNode(it) }
            return AmeNode.Col(children = children)
        }

        // Component or action call: name(...)
        val parenIndex = findTopLevelParen(trimmed)
        if (parenIndex != -1) {
            val name = trimmed.substring(0, parenIndex).trim()
            val argsStr = extractParenContent(trimmed, parenIndex)
            return parseComponentCall(name, argsStr)
        }

        // Boolean, number, or identifier reference
        if (trimmed == "true" || trimmed == "false") {
            return AmeNode.Txt(trimmed)
        }

        // Identifier reference -> Ref
        return AmeNode.Ref(trimmed)
    }

    // ── Intermediate Parsed Value System ───────────────────────────────

    private sealed class ParsedValue {
        data class Str(val value: String) : ParsedValue()
        data class Num(val intVal: Int?, val floatVal: Float?) : ParsedValue() {
            val asInt: Int get() = intVal ?: floatVal?.toInt() ?: 0
            val asFloat: Float get() = floatVal ?: intVal?.toFloat() ?: 0f
        }
        data class Bool(val value: Boolean) : ParsedValue()
        data class Arr(val items: List<String>) : ParsedValue()
        data class DataRef(val path: String) : ParsedValue()
        data class Ident(val name: String) : ParsedValue()
        data class NodeValue(val node: AmeNode) : ParsedValue()
        data class ActionValue(val action: AmeAction) : ParsedValue()
        data class NamedArg(val key: String, val value: ParsedValue) : ParsedValue()
    }

    private fun parseArgValue(arg: String): ParsedValue {
        val trimmed = arg.trim()
        if (trimmed.isEmpty()) return ParsedValue.Str("")

        // Named argument: key=value
        val namedEq = findNamedArgEquals(trimmed)
        if (namedEq != -1) {
            val key = trimmed.substring(0, namedEq).trim()
            val valStr = trimmed.substring(namedEq + 1).trim()
            return ParsedValue.NamedArg(key, parseArgValue(valStr))
        }

        // String literal
        if (trimmed.startsWith("\"")) {
            return ParsedValue.Str(parseStringLiteral(trimmed))
        }

        // Data reference
        if (trimmed.startsWith("$")) {
            return ParsedValue.DataRef(trimmed.removePrefix("$"))
        }

        // Array
        if (trimmed.startsWith("[")) {
            return ParsedValue.Arr(parseArray(trimmed))
        }

        // Boolean
        if (trimmed == "true") return ParsedValue.Bool(true)
        if (trimmed == "false") return ParsedValue.Bool(false)

        // Number
        if (trimmed[0].isDigit() || (trimmed[0] == '-' && trimmed.length > 1 && trimmed[1].isDigit())) {
            return parseNumber(trimmed)
        }

        // Component/action call: name(...)
        val parenIdx = findTopLevelParen(trimmed)
        if (parenIdx != -1) {
            val name = trimmed.substring(0, parenIdx).trim()
            val argsContent = extractParenContent(trimmed, parenIdx)

            if (name in AmeKeywords.ACTION_NAMES) {
                return ParsedValue.ActionValue(parseActionCall(name, argsContent))
            }
            if (name in AmeKeywords.STANDARD_PRIMITIVES || name == "each") {
                return ParsedValue.NodeValue(parseComponentCall(name, argsContent))
            }
            // Unknown call — could be custom component or action
            return ParsedValue.NodeValue(parseComponentCall(name, argsContent))
        }

        // Bare identifier
        return ParsedValue.Ident(trimmed)
    }

    private fun expressionToNode(exprStr: String): AmeNode {
        val parsed = parseArgValue(exprStr.trim())
        return when (parsed) {
            is ParsedValue.NodeValue -> parsed.node
            is ParsedValue.Ident -> AmeNode.Ref(parsed.name)
            is ParsedValue.Str -> AmeNode.Txt(parsed.value)
            is ParsedValue.DataRef -> AmeNode.Txt("\$${parsed.path}")
            is ParsedValue.Num -> AmeNode.Txt(parsed.intVal?.toString() ?: parsed.floatVal?.toString() ?: "0")
            is ParsedValue.Bool -> AmeNode.Txt(parsed.value.toString())
            is ParsedValue.Arr -> {
                val children = parsed.items.map { expressionToNode(it) }
                AmeNode.Col(children = children)
            }
            is ParsedValue.ActionValue -> AmeNode.Txt("action:${parsed.action}")
            is ParsedValue.NamedArg -> AmeNode.Txt("${parsed.key}=${parsed.value}")
        }
    }

    // ── Component Call Dispatch ─────────────────────────────────────────

    private fun parseComponentCall(name: String, argsStr: String): AmeNode {
        val args = splitArgs(argsStr)
        val positional = mutableListOf<ParsedValue>()
        val named = mutableMapOf<String, ParsedValue>()

        for (argStr in args) {
            val parsed = parseArgValue(argStr)
            if (parsed is ParsedValue.NamedArg) {
                named[parsed.key] = parsed.value
            } else {
                positional.add(parsed)
            }
        }

        return when (name) {
            "col" -> buildCol(positional, named)
            "row" -> buildRow(positional, named)
            "txt" -> buildTxt(positional, named)
            "img" -> buildImg(positional, named)
            "icon" -> buildIcon(positional, named)
            "divider" -> AmeNode.Divider
            "spacer" -> buildSpacer(positional, named)
            "card" -> buildCard(positional, named)
            "badge" -> buildBadge(positional, named)
            "progress" -> buildProgress(positional, named)
            "btn" -> buildBtn(positional, named)
            "input" -> buildInput(positional, named)
            "toggle" -> buildToggle(positional, named)
            "list" -> buildList(positional, named)
            "table" -> buildTable(positional, named)
            "each" -> buildEach(positional, named)
            "chart" -> buildChart(positional, named)
            "code" -> buildCode(positional, named)
            "accordion" -> buildAccordion(positional, named)
            "carousel" -> buildCarousel(positional, named)
            "callout" -> buildCallout(positional, named)
            "timeline" -> buildTimeline(positional, named)
            "timeline_item" -> buildTimelineItem(positional, named)
            else -> {
                _warnings.add("Unknown component '$name'")
                AmeNode.Txt("\u26A0 Unknown: $name", TxtStyle.CAPTION)
            }
        }
    }

    // ── Builder Functions for Each Primitive ────────────────────────────

    private fun buildCol(pos: List<ParsedValue>, named: Map<String, ParsedValue>): AmeNode.Col {
        val children = resolveChildrenArg(pos.getOrNull(0))
        val align = resolveAlignArg(pos.getOrNull(1)) ?: Align.START
        return AmeNode.Col(children = children, align = align)
    }

    private fun buildRow(pos: List<ParsedValue>, named: Map<String, ParsedValue>): AmeNode.Row {
        val children = resolveChildrenArg(pos.getOrNull(0))
        var align = Align.START
        var gap = 8

        // Disambiguation: numeric second arg = gap, enum second arg = align
        val secondArg = pos.getOrNull(1)
        if (secondArg != null) {
            when (secondArg) {
                is ParsedValue.Num -> gap = secondArg.asInt
                is ParsedValue.Ident -> {
                    val parsed = AmeKeywords.parseAlign(secondArg.name)
                    if (parsed != null) align = parsed
                    else _warnings.add("Unknown align value '${secondArg.name}', using default")
                }
                else -> {}
            }
        }

        val thirdArg = pos.getOrNull(2)
        if (thirdArg is ParsedValue.Num) {
            gap = thirdArg.asInt
        } else if (thirdArg is ParsedValue.Ident) {
            val parsed = AmeKeywords.parseAlign(thirdArg.name)
            if (parsed != null) align = parsed
        }

        return AmeNode.Row(children = children, align = align, gap = gap)
    }

    private fun buildTxt(pos: List<ParsedValue>, named: Map<String, ParsedValue>): AmeNode.Txt {
        val text = resolveStringArg(pos.getOrNull(0))
        val style = resolveTxtStyleArg(pos.getOrNull(1)) ?: TxtStyle.BODY
        val maxLines = named["max_lines"]?.let { resolveIntArg(it) }
        val color = named["color"]?.let { resolveSemanticColorArg(it) }
        return AmeNode.Txt(text = text, style = style, maxLines = maxLines, color = color)
    }

    private fun buildImg(pos: List<ParsedValue>, named: Map<String, ParsedValue>): AmeNode.Img {
        val url = resolveStringArg(pos.getOrNull(0))
        val height = pos.getOrNull(1)?.let { resolveIntArg(it) }
        return AmeNode.Img(url = url, height = height)
    }

    private fun buildIcon(pos: List<ParsedValue>, named: Map<String, ParsedValue>): AmeNode.Icon {
        val iconName = resolveStringArg(pos.getOrNull(0))
        val size = pos.getOrNull(1)?.let { resolveIntArg(it) } ?: 20
        return AmeNode.Icon(name = iconName, size = size)
    }

    private fun buildSpacer(pos: List<ParsedValue>, named: Map<String, ParsedValue>): AmeNode.Spacer {
        val height = pos.getOrNull(0)?.let { resolveIntArg(it) } ?: 8
        return AmeNode.Spacer(height = height)
    }

    private fun buildCard(pos: List<ParsedValue>, named: Map<String, ParsedValue>): AmeNode.Card {
        val children = resolveChildrenArg(pos.getOrNull(0))
        val elevation = pos.getOrNull(1)?.let { resolveIntArg(it) } ?: 1
        return AmeNode.Card(children = children, elevation = elevation)
    }

    private fun buildBadge(pos: List<ParsedValue>, named: Map<String, ParsedValue>): AmeNode.Badge {
        val label = resolveStringArg(pos.getOrNull(0))
        val variant = pos.getOrNull(1)?.let { resolveBadgeVariantArg(it) } ?: BadgeVariant.DEFAULT
        val color = named["color"]?.let { resolveSemanticColorArg(it) }
        return AmeNode.Badge(label = label, variant = variant, color = color)
    }

    private fun buildProgress(pos: List<ParsedValue>, named: Map<String, ParsedValue>): AmeNode.Progress {
        val value = pos.getOrNull(0)?.let { resolveFloatArg(it) } ?: 0f
        val label = pos.getOrNull(1)?.let { resolveStringArgNullable(it) }
        return AmeNode.Progress(value = value.coerceIn(0f, 1f), label = label)
    }

    private fun buildBtn(pos: List<ParsedValue>, named: Map<String, ParsedValue>): AmeNode.Btn {
        val label = resolveStringArg(pos.getOrNull(0))
        val action = resolveActionArg(pos.getOrNull(1))
            ?: AmeAction.Navigate("_error_no_action")
        val style = pos.getOrNull(2)?.let { resolveBtnStyleArg(it) } ?: BtnStyle.PRIMARY
        val icon = named["icon"]?.let { resolveStringArgNullable(it) }
        return AmeNode.Btn(label = label, action = action, style = style, icon = icon)
    }

    private fun buildInput(pos: List<ParsedValue>, named: Map<String, ParsedValue>): AmeNode.Input {
        val id = resolveStringArg(pos.getOrNull(0))
        val label = resolveStringArg(pos.getOrNull(1))
        val type = pos.getOrNull(2)?.let { resolveInputTypeArg(it) } ?: InputType.TEXT
        val options = named["options"]?.let { resolveStringListArg(it) }
            ?: pos.getOrNull(3)?.let { resolveStringListArg(it) }
        return AmeNode.Input(id = id, label = label, type = type, options = options)
    }

    private fun buildToggle(pos: List<ParsedValue>, named: Map<String, ParsedValue>): AmeNode.Toggle {
        val id = resolveStringArg(pos.getOrNull(0))
        val label = resolveStringArg(pos.getOrNull(1))
        val default = pos.getOrNull(2)?.let { resolveBoolArg(it) } ?: false
        return AmeNode.Toggle(id = id, label = label, default = default)
    }

    private fun buildList(pos: List<ParsedValue>, named: Map<String, ParsedValue>): AmeNode.DataList {
        val children = resolveChildrenArg(pos.getOrNull(0))
        val dividers = pos.getOrNull(1)?.let { resolveBoolArg(it) } ?: true
        return AmeNode.DataList(children = children, dividers = dividers)
    }

    private fun buildTable(pos: List<ParsedValue>, named: Map<String, ParsedValue>): AmeNode.Table {
        val headers = resolveStringListArg(pos.getOrNull(0)) ?: emptyList()
        val rows = resolveNestedStringListArg(pos.getOrNull(1))
        return AmeNode.Table(headers = headers, rows = rows)
    }

    private fun buildEach(pos: List<ParsedValue>, named: Map<String, ParsedValue>): AmeNode.Each {
        val dataPath = when (val arg0 = pos.getOrNull(0)) {
            is ParsedValue.DataRef -> arg0.path
            is ParsedValue.Str -> arg0.value.removePrefix("$")
            is ParsedValue.Ident -> arg0.name
            else -> ""
        }
        val templateId = when (val arg1 = pos.getOrNull(1)) {
            is ParsedValue.Ident -> arg1.name
            is ParsedValue.Str -> arg1.value
            else -> ""
        }
        return AmeNode.Each(dataPath = dataPath, templateId = templateId)
    }

    private fun buildChart(pos: List<ParsedValue>, named: Map<String, ParsedValue>): AmeNode.Chart {
        val type = pos.getOrNull(0)?.let { resolveChartTypeArg(it) } ?: ChartType.BAR

        var values: List<Double>? = null
        var valuesPath: String? = null
        val valuesArg = named["values"] ?: pos.getOrNull(1)
        when (valuesArg) {
            is ParsedValue.DataRef -> valuesPath = valuesArg.path
            is ParsedValue.Arr -> values = resolveDoubleListArg(valuesArg)
            else -> {}
        }

        var labels: List<String>? = null
        var labelsPath: String? = null
        val labelsArg = named["labels"]
        when (labelsArg) {
            is ParsedValue.DataRef -> labelsPath = labelsArg.path
            is ParsedValue.Arr -> labels = resolveStringListArg(labelsArg)
            else -> {}
        }

        var series: List<List<Double>>? = null
        var seriesPath: String? = null
        var seriesPaths: List<String>? = null
        val seriesArg = named["series"]
        when (seriesArg) {
            is ParsedValue.DataRef -> seriesPath = seriesArg.path
            is ParsedValue.Arr -> {
                // Disambiguate: if every element parses to a $path reference,
                // treat as array-of-paths (Bug 7); otherwise fall back to the
                // existing literal nested-numeric-array handling.
                val parsedItems = seriesArg.items.map { parseArgValue(it.trim()) }
                val allDataRefs = parsedItems.isNotEmpty() && parsedItems.all { it is ParsedValue.DataRef }
                if (allDataRefs) {
                    seriesPaths = parsedItems.map { (it as ParsedValue.DataRef).path }
                } else {
                    series = resolveNestedDoubleListArg(seriesArg)
                }
            }
            else -> {}
        }

        val height = named["height"]?.let { resolveIntArg(it) } ?: 200
        val color = named["color"]?.let { resolveSemanticColorArg(it) }

        return AmeNode.Chart(
            type = type, values = values, labels = labels, series = series,
            height = height, color = color,
            valuesPath = valuesPath, labelsPath = labelsPath,
            seriesPath = seriesPath, seriesPaths = seriesPaths
        )
    }

    private fun buildCode(pos: List<ParsedValue>, named: Map<String, ParsedValue>): AmeNode.Code {
        val language = resolveStringArg(pos.getOrNull(0))
        val content = resolveStringArg(pos.getOrNull(1))
        val title = pos.getOrNull(2)?.let { resolveStringArgNullable(it) }
        return AmeNode.Code(language = language, content = content, title = title)
    }

    private fun buildAccordion(pos: List<ParsedValue>, named: Map<String, ParsedValue>): AmeNode.Accordion {
        val title = resolveStringArg(pos.getOrNull(0))
        val children = resolveChildrenArg(pos.getOrNull(1))
        val expanded = pos.getOrNull(2)?.let { resolveBoolArg(it) } ?: false
        return AmeNode.Accordion(title = title, children = children, expanded = expanded)
    }

    private fun buildCarousel(pos: List<ParsedValue>, named: Map<String, ParsedValue>): AmeNode.Carousel {
        val children = resolveChildrenArg(pos.getOrNull(0))
        val peek = named["peek"]?.let { resolveIntArg(it) } ?: 24
        return AmeNode.Carousel(children = children, peek = peek)
    }

    private fun buildCallout(pos: List<ParsedValue>, named: Map<String, ParsedValue>): AmeNode.Callout {
        val type = pos.getOrNull(0)?.let { resolveCalloutTypeArg(it) } ?: CalloutType.INFO
        val content = resolveStringArg(pos.getOrNull(1))
        val title = pos.getOrNull(2)?.let { resolveStringArgNullable(it) }
        val color = named["color"]?.let { resolveSemanticColorArg(it) }
        return AmeNode.Callout(type = type, content = content, title = title, color = color)
    }

    private fun buildTimeline(pos: List<ParsedValue>, named: Map<String, ParsedValue>): AmeNode.Timeline {
        val children = resolveChildrenArg(pos.getOrNull(0))
        return AmeNode.Timeline(children = children)
    }

    private fun buildTimelineItem(pos: List<ParsedValue>, named: Map<String, ParsedValue>): AmeNode.TimelineItem {
        val title = resolveStringArg(pos.getOrNull(0))
        val subtitle = pos.getOrNull(1)?.let { resolveStringArgNullable(it) }
        val status = pos.getOrNull(2)?.let { resolveTimelineStatusArg(it) } ?: TimelineStatus.PENDING
        return AmeNode.TimelineItem(title = title, subtitle = subtitle, status = status)
    }

    // ── Action Call Dispatch ───────────────────────────────────────────

    private fun parseActionCall(name: String, argsStr: String): AmeAction {
        val args = splitArgs(argsStr)
        val positional = mutableListOf<ParsedValue>()
        val named = mutableMapOf<String, ParsedValue>()

        for (argStr in args) {
            val parsed = parseArgValue(argStr)
            if (parsed is ParsedValue.NamedArg) {
                named[parsed.key] = parsed.value
            } else {
                positional.add(parsed)
            }
        }

        return when (name) {
            "tool" -> buildToolAction(positional, named)
            "uri" -> buildUriAction(positional)
            "nav" -> buildNavAction(positional)
            "copy" -> buildCopyAction(positional)
            "submit" -> buildSubmitAction(positional, named)
            else -> {
                _warnings.add("Unknown action type '$name'")
                AmeAction.Navigate("_error_unknown_action")
            }
        }
    }

    private fun buildToolAction(pos: List<ParsedValue>, named: Map<String, ParsedValue>): AmeAction.CallTool {
        val toolName = resolveIdentOrStringArg(pos.getOrNull(0))
        val argsMap = mutableMapOf<String, String>()
        for ((key, value) in named) {
            argsMap[key] = resolveStringArg(value)
        }
        return AmeAction.CallTool(name = toolName, args = argsMap)
    }

    private fun buildUriAction(pos: List<ParsedValue>): AmeAction.OpenUri {
        val uri = resolveStringArg(pos.getOrNull(0))
        return AmeAction.OpenUri(uri = uri)
    }

    private fun buildNavAction(pos: List<ParsedValue>): AmeAction.Navigate {
        val route = resolveStringArg(pos.getOrNull(0))
        return AmeAction.Navigate(route = route)
    }

    private fun buildCopyAction(pos: List<ParsedValue>): AmeAction.CopyText {
        val text = resolveStringArg(pos.getOrNull(0))
        return AmeAction.CopyText(text = text)
    }

    private fun buildSubmitAction(pos: List<ParsedValue>, named: Map<String, ParsedValue>): AmeAction.Submit {
        val toolName = resolveIdentOrStringArg(pos.getOrNull(0))
        val staticArgs = mutableMapOf<String, String>()
        for ((key, value) in named) {
            staticArgs[key] = resolveStringArg(value)
        }
        return AmeAction.Submit(toolName = toolName, staticArgs = staticArgs)
    }

    // ── Argument Resolution Helpers ────────────────────────────────────

    private fun resolveChildrenArg(arg: ParsedValue?): List<AmeNode> {
        if (arg == null) return emptyList()
        return when (arg) {
            is ParsedValue.Arr -> arg.items.map { expressionToNode(it) }
            is ParsedValue.NodeValue -> {
                when (val node = arg.node) {
                    is AmeNode.Col -> node.children
                    else -> listOf(node)
                }
            }
            else -> emptyList()
        }
    }

    private fun resolveStringArg(arg: ParsedValue?): String {
        if (arg == null) return ""
        return when (arg) {
            is ParsedValue.Str -> arg.value
            is ParsedValue.Ident -> arg.name
            is ParsedValue.DataRef -> "\$${arg.path}"
            is ParsedValue.Num -> arg.intVal?.toString() ?: arg.floatVal?.toString() ?: "0"
            is ParsedValue.Bool -> arg.value.toString()
            else -> arg.toString()
        }
    }

    private fun resolveStringArgNullable(arg: ParsedValue?): String? {
        if (arg == null) return null
        return resolveStringArg(arg)
    }

    /** Accepts both quoted strings and unquoted identifiers as string values (leniency). */
    private fun resolveIdentOrStringArg(arg: ParsedValue?): String {
        if (arg == null) return ""
        return when (arg) {
            is ParsedValue.Ident -> arg.name
            is ParsedValue.Str -> arg.value
            is ParsedValue.DataRef -> "\$${arg.path}"
            else -> resolveStringArg(arg)
        }
    }

    private fun resolveIntArg(arg: ParsedValue): Int? {
        return when (arg) {
            is ParsedValue.Num -> arg.asInt
            is ParsedValue.Str -> arg.value.toIntOrNull()
            is ParsedValue.Ident -> arg.name.toIntOrNull()
            else -> null
        }
    }

    private fun resolveFloatArg(arg: ParsedValue): Float? {
        return when (arg) {
            is ParsedValue.Num -> arg.asFloat
            is ParsedValue.Str -> arg.value.toFloatOrNull()
            is ParsedValue.Ident -> arg.name.toFloatOrNull()
            else -> null
        }
    }

    private fun resolveBoolArg(arg: ParsedValue): Boolean {
        return when (arg) {
            is ParsedValue.Bool -> arg.value
            is ParsedValue.Ident -> arg.name.equals("true", ignoreCase = true)
            is ParsedValue.Str -> arg.value.equals("true", ignoreCase = true)
            else -> false
        }
    }

    private fun resolveAlignArg(arg: ParsedValue?): Align? {
        if (arg == null) return null
        return when (arg) {
            is ParsedValue.Ident -> AmeKeywords.parseAlign(arg.name)
            is ParsedValue.Str -> AmeKeywords.parseAlign(arg.value)
            else -> null
        }
    }

    private fun resolveTxtStyleArg(arg: ParsedValue?): TxtStyle? {
        if (arg == null) return null
        return when (arg) {
            is ParsedValue.Ident -> AmeKeywords.parseTxtStyle(arg.name)
            is ParsedValue.Str -> AmeKeywords.parseTxtStyle(arg.value)
            else -> {
                _warnings.add("Unknown txt style: $arg, using default")
                null
            }
        }
    }

    private fun resolveBtnStyleArg(arg: ParsedValue?): BtnStyle? {
        if (arg == null) return null
        return when (arg) {
            is ParsedValue.Ident -> AmeKeywords.parseBtnStyle(arg.name)
            is ParsedValue.Str -> AmeKeywords.parseBtnStyle(arg.value)
            else -> {
                _warnings.add("Unknown btn style: $arg, using default")
                null
            }
        }
    }

    private fun resolveBadgeVariantArg(arg: ParsedValue?): BadgeVariant? {
        if (arg == null) return null
        return when (arg) {
            is ParsedValue.Ident -> AmeKeywords.parseBadgeVariant(arg.name)
            is ParsedValue.Str -> AmeKeywords.parseBadgeVariant(arg.value)
            else -> {
                _warnings.add("Unknown badge variant: $arg, using default")
                null
            }
        }
    }

    private fun resolveInputTypeArg(arg: ParsedValue?): InputType? {
        if (arg == null) return null
        return when (arg) {
            is ParsedValue.Ident -> AmeKeywords.parseInputType(arg.name)
            is ParsedValue.Str -> AmeKeywords.parseInputType(arg.value)
            else -> {
                _warnings.add("Unknown input type: $arg, using default")
                null
            }
        }
    }

    private fun resolveChartTypeArg(arg: ParsedValue?): ChartType? {
        if (arg == null) return null
        return when (arg) {
            is ParsedValue.Ident -> AmeKeywords.parseChartType(arg.name)
            is ParsedValue.Str -> AmeKeywords.parseChartType(arg.value)
            else -> null
        }
    }

    private fun resolveCalloutTypeArg(arg: ParsedValue?): CalloutType? {
        if (arg == null) return null
        return when (arg) {
            is ParsedValue.Ident -> AmeKeywords.parseCalloutType(arg.name)
            is ParsedValue.Str -> AmeKeywords.parseCalloutType(arg.value)
            else -> null
        }
    }

    private fun resolveTimelineStatusArg(arg: ParsedValue?): TimelineStatus? {
        if (arg == null) return null
        return when (arg) {
            is ParsedValue.Ident -> AmeKeywords.parseTimelineStatus(arg.name)
            is ParsedValue.Str -> AmeKeywords.parseTimelineStatus(arg.value)
            else -> null
        }
    }

    private fun resolveSemanticColorArg(arg: ParsedValue?): SemanticColor? {
        if (arg == null) return null
        return when (arg) {
            is ParsedValue.Ident -> AmeKeywords.parseSemanticColor(arg.name)
            is ParsedValue.Str -> AmeKeywords.parseSemanticColor(arg.value)
            else -> null
        }
    }

    private fun resolveActionArg(arg: ParsedValue?): AmeAction? {
        if (arg == null) return null
        return when (arg) {
            is ParsedValue.ActionValue -> arg.action
            is ParsedValue.Ident -> {
                _warnings.add("Expected action expression, got identifier '${arg.name}'")
                null
            }
            else -> {
                _warnings.add("Expected action expression, got: $arg")
                null
            }
        }
    }

    private fun resolveStringListArg(arg: ParsedValue?): List<String>? {
        if (arg == null) return null
        return when (arg) {
            is ParsedValue.Arr -> arg.items.map { parseArgValue(it.trim()).let { pv -> resolveStringArg(pv) } }
            else -> null
        }
    }

    private fun resolveNestedStringListArg(arg: ParsedValue?): List<List<String>> {
        if (arg == null) return emptyList()
        return when (arg) {
            is ParsedValue.Arr -> {
                arg.items.map { rowStr ->
                    val rowParsed = parseArgValue(rowStr.trim())
                    when (rowParsed) {
                        is ParsedValue.Arr -> rowParsed.items.map { cellStr ->
                            resolveStringArg(parseArgValue(cellStr.trim()))
                        }
                        else -> listOf(resolveStringArg(rowParsed))
                    }
                }
            }
            else -> emptyList()
        }
    }

    private fun resolveDoubleListArg(arg: ParsedValue?): List<Double>? {
        if (arg == null) return null
        return when (arg) {
            is ParsedValue.Arr -> arg.items.mapNotNull { item ->
                item.trim().toDoubleOrNull()
            }
            else -> null
        }
    }

    private fun resolveNestedDoubleListArg(arg: ParsedValue?): List<List<Double>>? {
        if (arg == null) return null
        return when (arg) {
            is ParsedValue.Arr -> arg.items.mapNotNull { rowStr ->
                val rowParsed = parseArgValue(rowStr.trim())
                when (rowParsed) {
                    is ParsedValue.Arr -> rowParsed.items.mapNotNull { cellStr ->
                        cellStr.trim().toDoubleOrNull()
                    }
                    else -> null
                }
            }
            else -> null
        }
    }

    // ── String Literal Parser ──────────────────────────────────────────

    private fun parseStringLiteral(input: String): String {
        if (!input.startsWith("\"")) return input

        val sb = StringBuilder()
        var i = 1
        var escaped = false

        while (i < input.length) {
            val c = input[i]
            if (escaped) {
                when (c) {
                    '"' -> sb.append('"')
                    '\\' -> sb.append('\\')
                    'n' -> sb.append('\n')
                    't' -> sb.append('\t')
                    else -> {
                        sb.append('\\')
                        sb.append(c)
                    }
                }
                escaped = false
            } else {
                when (c) {
                    '\\' -> escaped = true
                    '"' -> return sb.toString()
                    else -> sb.append(c)
                }
            }
            i++
        }

        // Unclosed string — implicitly close at end of line (error recovery)
        _warnings.add("Unclosed string literal, implicitly closing at end of line")
        return sb.toString()
    }

    // ── Number Parser ──────────────────────────────────────────────────

    private fun parseNumber(input: String): ParsedValue {
        val trimmed = input.trim()
        if (trimmed.contains('.')) {
            val f = trimmed.toFloatOrNull()
            if (f != null) return ParsedValue.Num(null, f)
            _warnings.add("Invalid number '$trimmed', treating as string")
            return ParsedValue.Str(trimmed)
        }
        val i = trimmed.toIntOrNull()
        if (i != null) return ParsedValue.Num(i, null)
        _warnings.add("Invalid number '$trimmed', treating as string")
        return ParsedValue.Str(trimmed)
    }

    // ── Array Parser ───────────────────────────────────────────────────

    private fun parseArray(input: String): List<String> {
        val trimmed = input.trim()
        if (!trimmed.startsWith("[")) return emptyList()

        // Find matching ] respecting string literals so a `]` inside a `"..."`
        // value does not prematurely close the array (Bug 3b).
        var depth = 0
        var endIdx = -1
        var inString = false
        var escaped = false
        for (i in trimmed.indices) {
            val c = trimmed[i]
            if (escaped) {
                escaped = false
                continue
            }
            if (inString) {
                when (c) {
                    '\\' -> escaped = true
                    '"' -> inString = false
                }
                continue
            }
            when (c) {
                '"' -> inString = true
                '[' -> depth++
                ']' -> {
                    depth--
                    if (depth == 0) {
                        endIdx = i
                        break
                    }
                }
            }
        }

        val content = if (endIdx > 1) {
            trimmed.substring(1, endIdx).trim()
        } else {
            _warnings.add("Unclosed bracket in array, implicitly closing")
            trimmed.substring(1).trimEnd(']').trim()
        }

        if (content.isEmpty()) return emptyList()
        return splitTopLevel(content, ',')
    }

    // ── Argument Splitter State Machine ────────────────────────────────

    private fun splitArgs(argsStr: String): List<String> {
        val trimmed = argsStr.trim()
        if (trimmed.isEmpty()) return emptyList()
        return splitTopLevel(trimmed, ',')
    }

    /**
     * Splits a string on [delimiter] while respecting nesting in (), [], and "".
     * This is the core state machine that prevents splitting inside nested
     * component calls, arrays, or string literals.
     */
    private fun splitTopLevel(input: String, delimiter: Char): List<String> {
        val result = mutableListOf<String>()
        val current = StringBuilder()
        var parenDepth = 0
        var bracketDepth = 0
        var inString = false
        var escaped = false

        for (c in input) {
            if (escaped) {
                current.append(c)
                escaped = false
                continue
            }

            if (inString) {
                current.append(c)
                when (c) {
                    '\\' -> escaped = true
                    '"' -> inString = false
                }
                continue
            }

            when (c) {
                '"' -> {
                    inString = true
                    current.append(c)
                }
                '(' -> {
                    parenDepth++
                    current.append(c)
                }
                ')' -> {
                    parenDepth--
                    current.append(c)
                }
                '[' -> {
                    bracketDepth++
                    current.append(c)
                }
                ']' -> {
                    bracketDepth--
                    current.append(c)
                }
                delimiter -> {
                    if (parenDepth == 0 && bracketDepth == 0) {
                        result.add(current.toString().trim())
                        current.clear()
                    } else {
                        current.append(c)
                    }
                }
                else -> current.append(c)
            }
        }

        val remaining = current.toString().trim()
        if (remaining.isNotEmpty()) {
            result.add(remaining)
        }

        return result
    }

    // ── Named Argument Detection ───────────────────────────────────────

    /**
     * Find the '=' for a named argument (key=value).
     * Returns -1 if this is not a named arg.
     * Must distinguish from '=' inside strings, inside nested calls, etc.
     * A named arg has the form: simple_identifier = expression
     */
    private fun findNamedArgEquals(input: String): Int {
        val trimmed = input.trim()

        // Must start with a letter (identifier for the key)
        if (trimmed.isEmpty() || !trimmed[0].isLetter()) return -1

        // Find the first '=' that isn't inside quotes or parens
        var i = 0
        while (i < trimmed.length && (trimmed[i].isLetterOrDigit() || trimmed[i] == '_')) {
            i++
        }

        // Skip whitespace between key and '='
        while (i < trimmed.length && trimmed[i] == ' ') i++

        if (i < trimmed.length && trimmed[i] == '=') {
            val key = trimmed.substring(0, i).trim()
            // Reject if the key looks like a component call (followed by more '=' or '(')
            if (key.isNotEmpty() && key.all { it.isLetterOrDigit() || it == '_' }) {
                // Make sure this isn't just "identifier" followed by "= expression" at top level
                // of a line (which would be handled by parseLine). Named args appear inside
                // component call argument lists.
                return i
            }
        }

        return -1
    }

    // ── Parenthesis Helpers ────────────────────────────────────────────

    private fun findTopLevelParen(input: String): Int {
        var inString = false
        var escaped = false

        for (i in input.indices) {
            val c = input[i]
            if (escaped) { escaped = false; continue }
            if (inString) {
                when (c) {
                    '\\' -> escaped = true
                    '"' -> inString = false
                }
                continue
            }
            when (c) {
                '"' -> inString = true
                '(' -> return i
            }
        }
        return -1
    }

    private fun extractParenContent(input: String, openIndex: Int): String {
        var depth = 0
        var closeIndex = -1
        var inString = false
        var escaped = false

        for (i in openIndex until input.length) {
            val c = input[i]
            if (escaped) {
                escaped = false
                continue
            }
            if (inString) {
                when (c) {
                    '\\' -> escaped = true
                    '"' -> inString = false
                }
                continue
            }
            when (c) {
                '"' -> inString = true
                '(' -> depth++
                ')' -> {
                    depth--
                    if (depth == 0) {
                        closeIndex = i
                        break
                    }
                }
            }
        }

        return if (closeIndex > openIndex + 1) {
            input.substring(openIndex + 1, closeIndex)
        } else if (closeIndex == -1) {
            // Unclosed parenthesis — error recovery: use rest of string
            _warnings.add("Unclosed parenthesis, implicitly closing at end of expression")
            input.substring(openIndex + 1).trimEnd(')')
        } else {
            ""
        }
    }

    // ── Data Section Parsing ───────────────────────────────────────────

    private fun parseDataSection(jsonText: String) {
        val trimmed = jsonText.trim()
        if (trimmed.isEmpty()) return

        try {
            val element = Json.parseToJsonElement(trimmed)
            if (element is JsonObject) {
                dataModel = element
            } else {
                _errors.add("Data model must be a JSON object, got: ${element::class.simpleName}")
            }
        } catch (e: Exception) {
            _errors.add("Invalid JSON in data section: ${e.message}")
        }
    }

    // ── Tree Resolution (Forward Refs, $path, each() expansion) ────────

    /**
     * Resolves Ref nodes against the registry and `$path` data references
     * against `scope`. The [visited] set carries the chain of ref ids that
     * are currently being dereferenced down a single branch of the tree;
     * when a Ref's id appears in [visited] we treat it as a cycle and leave
     * the node unresolved (Bug 11). The set is immutable per call so sibling
     * branches and diamond-ref patterns (`a -> c, b -> c`) resolve
     * independently rather than poisoning each other.
     */
    private fun resolveTree(
        node: AmeNode,
        scope: JsonObject? = dataModel,
        visited: Set<String> = emptySet()
    ): AmeNode {
        return when (node) {
            is AmeNode.Col -> node.copy(children = resolveChildren(node.children, scope, visited))
            is AmeNode.Row -> node.copy(children = resolveChildren(node.children, scope, visited))
            is AmeNode.Card -> node.copy(children = resolveChildren(node.children, scope, visited))
            is AmeNode.DataList -> node.copy(children = resolveChildren(node.children, scope, visited))
            is AmeNode.Ref -> {
                if (node.id in visited) {
                    _warnings.add("Ref cycle detected at '${node.id}'; leaving unresolved")
                    node
                } else {
                    registry[node.id]?.let { resolveTree(it, scope, visited + node.id) } ?: node
                }
            }
            is AmeNode.Each -> {
                if (scope == null) node
                else {
                    val expanded = expandEach(node, scope, visited)
                    if (expanded.size == 1) expanded[0]
                    else AmeNode.Col(children = expanded)
                }
            }
            is AmeNode.Txt -> if (scope != null) node.copy(text = resolvePathInScope(node.text, scope)) else node
            is AmeNode.Img -> if (scope != null) node.copy(url = resolvePathInScope(node.url, scope)) else node
            is AmeNode.Badge -> if (scope != null) node.copy(label = resolvePathInScope(node.label, scope)) else node
            is AmeNode.Progress -> if (scope != null && node.label != null) node.copy(label = resolvePathInScope(node.label, scope)) else node
            is AmeNode.Btn -> if (scope != null) node.copy(label = resolvePathInScope(node.label, scope)) else node
            is AmeNode.Icon -> if (scope != null) node.copy(name = resolvePathInScope(node.name, scope)) else node
            is AmeNode.Accordion -> node.copy(
                children = resolveChildren(node.children, scope, visited),
                title = if (scope != null) resolvePathInScope(node.title, scope) else node.title
            )
            is AmeNode.Carousel -> node.copy(children = resolveChildren(node.children, scope, visited))
            is AmeNode.Timeline -> node.copy(children = resolveChildren(node.children, scope, visited))
            is AmeNode.Callout -> if (scope != null) node.copy(
                content = resolvePathInScope(node.content, scope),
                title = node.title?.let { resolvePathInScope(it, scope) }
            ) else node
            is AmeNode.Code -> if (scope != null) node.copy(
                content = resolvePathInScope(node.content, scope),
                title = node.title?.let { resolvePathInScope(it, scope) }
            ) else node
            is AmeNode.TimelineItem -> if (scope != null) node.copy(
                title = resolvePathInScope(node.title, scope),
                subtitle = node.subtitle?.let { resolvePathInScope(it, scope) }
            ) else node
            is AmeNode.Chart -> if (scope != null) {
                node.copy(
                    values = node.values ?: node.valuesPath?.let { resolveDoubleArrayInScope(it, scope) },
                    labels = node.labels ?: node.labelsPath?.let { resolveStringArrayInScope(it, scope) },
                    series = node.series
                        ?: node.seriesPath?.let { resolveNestedDoubleArrayInScope(it, scope) }
                        ?: node.seriesPaths?.let { paths ->
                            // All-or-nothing: every path must resolve. Mismatched array
                            // lengths within successfully-resolved paths are preserved
                            // verbatim (matches existing literal-series behavior).
                            paths.mapNotNull { resolveDoubleArrayInScope(it, scope) }
                                .takeIf { it.size == paths.size }
                        },
                    valuesPath = null,
                    labelsPath = null,
                    seriesPath = null,
                    seriesPaths = null
                )
            } else node
            else -> node
        }
    }

    private fun resolveChildren(
        children: List<AmeNode>,
        scope: JsonObject?,
        visited: Set<String> = emptySet()
    ): List<AmeNode> {
        return children.map { child ->
            when (child) {
                is AmeNode.Ref -> {
                    if (child.id in visited) {
                        _warnings.add("Ref cycle detected at '${child.id}'; leaving unresolved")
                        child
                    } else {
                        val resolved = registry[child.id]
                        if (resolved != null) resolveTree(resolved, scope, visited + child.id) else child
                    }
                }
                else -> resolveTree(child, scope, visited)
            }
        }
    }

    private fun expandEach(
        node: AmeNode.Each,
        parentScope: JsonObject?,
        visited: Set<String> = emptySet()
    ): List<AmeNode> {
        val array = resolveDataArray(node.dataPath, parentScope)
            ?: return emptyList()
        if (array.isEmpty()) return emptyList()

        val template = registry[node.templateId]
        if (template == null) {
            _warnings.add("each() template '${node.templateId}' not found in registry")
            return emptyList()
        }

        return array.mapNotNull { element ->
            when (element) {
                is JsonObject -> resolveTree(template, element, visited)
                else -> {
                    _warnings.add("each() array element is not a JSON object")
                    null
                }
            }
        }
    }

    private fun resolveDataArray(path: String, scope: JsonObject?): JsonArray? {
        val model = scope ?: dataModel ?: return null
        val segments = path.removePrefix("$").split("/")
        var current: JsonElement = model
        for (segment in segments) {
            when (current) {
                is JsonObject -> current = current[segment] ?: run {
                    _warnings.add("each() path segment '$segment' not found in data model")
                    return null
                }
                else -> return null
            }
        }
        if (current !is JsonArray) {
            _warnings.add("each() path '$path' resolved to ${current::class.simpleName}, expected JsonArray")
            return null
        }
        return current
    }

    private fun resolvePathInScope(value: String, scope: JsonObject): String {
        if (!value.startsWith("$")) return value
        val segments = value.removePrefix("$").split("/")
        var current: JsonElement = scope
        for (segment in segments) {
            when (current) {
                is JsonObject -> current = current[segment] ?: return ""
                else -> return ""
            }
        }
        return when (current) {
            is JsonPrimitive -> current.contentOrNull ?: ""
            is JsonNull -> ""
            else -> ""
        }
    }

    // ── Chart Array Resolution Helpers ─────────────────────────────────

    private fun resolveDoubleArrayInScope(path: String, scope: JsonObject): List<Double>? {
        val segments = path.removePrefix("$").split("/")
        var current: JsonElement = scope
        for (segment in segments) {
            when (current) {
                is JsonObject -> current = current[segment] ?: return null
                else -> return null
            }
        }
        return (current as? JsonArray)?.mapNotNull {
            (it as? JsonPrimitive)?.contentOrNull?.toDoubleOrNull()
        }
    }

    private fun resolveStringArrayInScope(path: String, scope: JsonObject): List<String>? {
        val segments = path.removePrefix("$").split("/")
        var current: JsonElement = scope
        for (segment in segments) {
            when (current) {
                is JsonObject -> current = current[segment] ?: return null
                else -> return null
            }
        }
        return (current as? JsonArray)?.mapNotNull {
            (it as? JsonPrimitive)?.contentOrNull
        }
    }

    private fun resolveNestedDoubleArrayInScope(path: String, scope: JsonObject): List<List<Double>>? {
        val segments = path.removePrefix("$").split("/")
        var current: JsonElement = scope
        for (segment in segments) {
            when (current) {
                is JsonObject -> current = current[segment] ?: return null
                else -> return null
            }
        }
        return (current as? JsonArray)?.mapNotNull { inner ->
            (inner as? JsonArray)?.mapNotNull { (it as? JsonPrimitive)?.contentOrNull?.toDoubleOrNull() }
        }
    }

    // ── Data Model Access ──────────────────────────────────────────────

    fun getDataModel(): JsonObject? = dataModel

    /**
     * Resolve a $path reference against the data model.
     * Path segments are separated by '/'.
     * Returns null if the path cannot be resolved.
     */
    fun resolveDataPath(path: String): String? {
        val model = dataModel ?: return null
        val segments = path.removePrefix("$").split("/")
        var current: JsonElement = model

        for (segment in segments) {
            when (current) {
                is JsonObject -> {
                    current = current[segment] ?: return null
                }
                else -> return null
            }
        }

        return when (current) {
            is JsonPrimitive -> current.contentOrNull
            else -> null
        }
    }
}
