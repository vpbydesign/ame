package com.agenticmobile.ame

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Horizontal/vertical alignment for layout primitives.
 * col supports: start, center, end
 * row supports: start, center, end, space_between, space_around
 */
@Serializable
enum class Align {
    @SerialName("start") START,
    @SerialName("center") CENTER,
    @SerialName("end") END,
    @SerialName("space_between") SPACE_BETWEEN,
    @SerialName("space_around") SPACE_AROUND
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

/**
 * Reserved keywords and parser lookup utilities.
 * All sets match the Reserved Keywords section of syntax.md exactly.
 */
object AmeKeywords {
    val STANDARD_PRIMITIVES: Set<String> = setOf(
        "col", "row", "txt", "btn", "card", "badge", "icon", "img",
        "input", "toggle", "list", "table", "divider", "spacer", "progress"
    )

    val ACTION_NAMES: Set<String> = setOf("tool", "uri", "nav", "copy", "submit")

    val STRUCTURAL_KEYWORDS: Set<String> = setOf("each", "root")

    val BOOLEAN_LITERALS: Set<String> = setOf("true", "false")

    const val DATA_SEPARATOR: String = "---"

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
}
