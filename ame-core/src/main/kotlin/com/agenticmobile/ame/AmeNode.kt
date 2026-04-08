package com.agenticmobile.ame

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Sealed interface representing all AME UI node types.
 *
 * 15 visual primitives (matching primitives.md exactly),
 * 1 streaming forward reference (Ref),
 * 1 data iteration construct (Each).
 *
 * Children are List<AmeNode> (resolved tree form). The parser converts
 * identifier strings to Ref nodes during parsing, then resolves Ref -> real
 * node after all lines are processed.
 *
 * Data references ($path) and each() iteration MAY be resolved at parse time
 * (when a data section is present) or deferred to the renderer at render time
 * (when streaming without a data model).
 */
@Serializable
sealed interface AmeNode {

    // ── Layout Primitives ──────────────────────────────────────────────

    /**
     * Vertical column layout.
     * col supports align values: start, center, end.
     */
    @Serializable
    @SerialName("col")
    data class Col(
        val children: List<AmeNode> = emptyList(),
        val align: Align = Align.START
    ) : AmeNode

    /**
     * Horizontal row layout.
     * row supports align values: start, center, end, space_between, space_around.
     *
     * Parser disambiguation: when a numeric literal appears as the second positional
     * argument, it is interpreted as [gap], not [align].
     */
    @Serializable
    @SerialName("row")
    data class Row(
        val children: List<AmeNode> = emptyList(),
        val align: Align = Align.START,
        val gap: Int = 8
    ) : AmeNode

    // ── Content Primitives ─────────────────────────────────────────────

    /** Text display with typographic style. */
    @Serializable
    @SerialName("txt")
    data class Txt(
        val text: String,
        val style: TxtStyle = TxtStyle.BODY,
        val maxLines: Int? = null
    ) : AmeNode

    /** Image loaded from a URL. Width fills available space. */
    @Serializable
    @SerialName("img")
    data class Img(
        val url: String,
        val height: Int? = null
    ) : AmeNode

    /** Named Material icon from the Material Icons set. */
    @Serializable
    @SerialName("icon")
    data class Icon(
        val name: String,
        val size: Int = 20
    ) : AmeNode

    /** Thin horizontal divider line. No arguments. */
    @Serializable
    @SerialName("divider")
    data object Divider : AmeNode

    /** Vertical whitespace between elements. */
    @Serializable
    @SerialName("spacer")
    data class Spacer(
        val height: Int = 8
    ) : AmeNode

    // ── Semantic Primitives ────────────────────────────────────────────

    /** Elevated container grouping related content. Children arranged vertically. */
    @Serializable
    @SerialName("card")
    data class Card(
        val children: List<AmeNode> = emptyList(),
        val elevation: Int = 1
    ) : AmeNode

    /** Small colored label for status indicators, counts, or categories. */
    @Serializable
    @SerialName("badge")
    data class Badge(
        val label: String,
        val variant: BadgeVariant = BadgeVariant.DEFAULT
    ) : AmeNode

    /** Horizontal progress bar with optional label. Value clamped to 0.0–1.0. */
    @Serializable
    @SerialName("progress")
    data class Progress(
        val value: Float,
        val label: String? = null
    ) : AmeNode

    // ── Interactive Primitives ─────────────────────────────────────────

    /**
     * Tappable button that triggers an action.
     * [action] is an AmeAction sealed interface subtype, constructed by the
     * parser from inline action expressions (tool(...), uri(...), etc.).
     */
    @Serializable
    @SerialName("btn")
    data class Btn(
        val label: String,
        val action: AmeAction,
        val style: BtnStyle = BtnStyle.PRIMARY,
        val icon: String? = null
    ) : AmeNode

    /**
     * Form input field. [id] provides a unique key for form data binding.
     * When [type] is SELECT, [options] is required.
     */
    @Serializable
    @SerialName("input")
    data class Input(
        val id: String,
        val label: String,
        val type: InputType = InputType.TEXT,
        val options: List<String>? = null
    ) : AmeNode

    /** Labeled toggle switch for boolean choices. */
    @Serializable
    @SerialName("toggle")
    data class Toggle(
        val id: String,
        val label: String,
        val default: Boolean = false
    ) : AmeNode

    // ── Data Primitives ────────────────────────────────────────────────

    /**
     * Vertical list of children, optionally separated by dividers.
     * Named DataList to avoid collision with kotlin.collections.List.
     */
    @Serializable
    @SerialName("list")
    data class DataList(
        val children: List<AmeNode> = emptyList(),
        val dividers: Boolean = true
    ) : AmeNode

    /** Grid of text values with a header row. */
    @Serializable
    @SerialName("table")
    data class Table(
        val headers: List<String>,
        val rows: List<List<String>>
    ) : AmeNode

    // ── Structural Types (non-visual) ──────────────────────────────────

    /**
     * Unresolved forward reference during streaming.
     * Created when a child identifier is referenced before its defining
     * statement has been parsed. The renderer shows a skeleton placeholder.
     * In batch mode, Ref nodes are resolved to real nodes after all lines
     * are processed.
     */
    @Serializable
    @SerialName("ref")
    data class Ref(val id: String) : AmeNode

    /**
     * Data iteration construct. Instantiates a template once per element in a
     * JSON array from the data model.
     *
     * [dataPath] is the $path reference (without the $ prefix) that resolves
     * to a JSON array in the data model.
     * [templateId] is the identifier of a component defined elsewhere in the
     * document that serves as the template.
     *
     * each() is a control-flow construct, not a visual primitive. When a data
     * section is present, the parser expands each() at parse time, resolving
     * $path references within the scoped data of each array element. When no
     * data is available (e.g. streaming mode), the Each node is preserved in
     * the tree for deferred rendering.
     */
    @Serializable
    @SerialName("each")
    data class Each(
        val dataPath: String,
        val templateId: String
    ) : AmeNode
}
