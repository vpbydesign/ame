package com.agenticmobile.ame

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Horizontal/vertical alignment for layout primitives.
 * col supports: start, center, end
 * row main-axis (align): start, center, end, space_between, space_around
 * row cross-axis (crossAlign): top, center, bottom
 */
@Serializable
enum class Align {
    @SerialName("start") START,
    @SerialName("center") CENTER,
    @SerialName("end") END,
    @SerialName("space_between") SPACE_BETWEEN,
    @SerialName("space_around") SPACE_AROUND,
    @SerialName("top") TOP,
    @SerialName("bottom") BOTTOM
}

/** Typographic style for txt primitive. */
@Serializable
enum class TxtStyle {
    @SerialName("display") DISPLAY,
    @SerialName("headline") HEADLINE,
    @SerialName("title") TITLE,
    @SerialName("body") BODY,
    @SerialName("caption") CAPTION,
    @SerialName("mono") MONO,
    @SerialName("label") LABEL,
    @SerialName("overline") OVERLINE
}

/** Visual style for btn primitive. */
@Serializable
enum class BtnStyle {
    @SerialName("primary") PRIMARY,
    @SerialName("secondary") SECONDARY,
    @SerialName("outline") OUTLINE,
    @SerialName("text") TEXT,
    @SerialName("destructive") DESTRUCTIVE
}

/** Color variant for badge primitive. */
@Serializable
enum class BadgeVariant {
    @SerialName("default") DEFAULT,
    @SerialName("success") SUCCESS,
    @SerialName("warning") WARNING,
    @SerialName("error") ERROR,
    @SerialName("info") INFO
}

/** Input field type for input primitive. */
@Serializable
enum class InputType {
    @SerialName("text") TEXT,
    @SerialName("number") NUMBER,
    @SerialName("email") EMAIL,
    @SerialName("phone") PHONE,
    @SerialName("date") DATE,
    @SerialName("time") TIME,
    @SerialName("select") SELECT
}

/** Chart visualization type. */
@Serializable
enum class ChartType {
    @SerialName("line") LINE,
    @SerialName("bar") BAR,
    @SerialName("pie") PIE,
    @SerialName("sparkline") SPARKLINE
}

/** Callout alert type — determines icon and background tint. */
@Serializable
enum class CalloutType {
    @SerialName("info") INFO,
    @SerialName("warning") WARNING,
    @SerialName("error") ERROR,
    @SerialName("success") SUCCESS,
    @SerialName("tip") TIP
}

/** Timeline step status — determines circle style and connector line. */
@Serializable
enum class TimelineStatus {
    @SerialName("done") DONE,
    @SerialName("active") ACTIVE,
    @SerialName("pending") PENDING,
    @SerialName("error") ERROR
}

/** Semantic color token for platform-consistent coloring. */
@Serializable
enum class SemanticColor {
    @SerialName("primary") PRIMARY,
    @SerialName("secondary") SECONDARY,
    @SerialName("error") ERROR,
    @SerialName("success") SUCCESS,
    @SerialName("warning") WARNING
}

/**
 * Reserved keywords and parser lookup utilities.
 * All sets match the Reserved Keywords section of syntax.md exactly.
 */
object AmeKeywords {
    val STANDARD_PRIMITIVES: Set<String> = setOf(
        "col", "row", "txt", "btn", "card", "badge", "icon", "img",
        "input", "toggle", "list", "list_item", "table", "divider", "spacer",
        "progress", "chart", "code", "accordion", "carousel", "callout",
        "timeline", "timeline_item"
    )

    val ACTION_NAMES: Set<String> = setOf("tool", "uri", "nav", "copy", "submit")

    val STRUCTURAL_KEYWORDS: Set<String> = setOf("each", "root")

    val BOOLEAN_LITERALS: Set<String> = setOf("true", "false")

    const val DATA_SEPARATOR: String = "---"

    /**
     * True when [identifier] is one of the four genuine reserved-token classes:
     * standard primitive names, action names, structural keywords (`each`,
     * `root`), or boolean literals.
     *
     * Enum-value tokens (`title`, `primary`, `done`, etc.) are intentionally
     * NOT reserved; the parser disambiguates by argument position per syntax.md.
     */
    fun isReserved(identifier: String): Boolean =
        identifier in STANDARD_PRIMITIVES ||
            identifier in ACTION_NAMES ||
            identifier in STRUCTURAL_KEYWORDS ||
            identifier in BOOLEAN_LITERALS

    fun parseAlign(value: String): Align? =
        Align.entries.find { it.name.equals(value, ignoreCase = true) }

    fun parseTxtStyle(value: String): TxtStyle? =
        TxtStyle.entries.find { it.name.equals(value, ignoreCase = true) }

    fun parseBtnStyle(value: String): BtnStyle? =
        BtnStyle.entries.find { it.name.equals(value, ignoreCase = true) }

    fun parseBadgeVariant(value: String): BadgeVariant? =
        BadgeVariant.entries.find { it.name.equals(value, ignoreCase = true) }

    fun parseInputType(value: String): InputType? =
        InputType.entries.find { it.name.equals(value, ignoreCase = true) }

    fun parseChartType(value: String): ChartType? =
        ChartType.entries.find { it.name.equals(value, ignoreCase = true) }

    fun parseCalloutType(value: String): CalloutType? =
        CalloutType.entries.find { it.name.equals(value, ignoreCase = true) }

    fun parseTimelineStatus(value: String): TimelineStatus? =
        TimelineStatus.entries.find { it.name.equals(value, ignoreCase = true) }

    fun parseSemanticColor(value: String): SemanticColor? =
        SemanticColor.entries.find { it.name.equals(value, ignoreCase = true) }
}
