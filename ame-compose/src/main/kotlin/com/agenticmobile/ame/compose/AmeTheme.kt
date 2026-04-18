package com.agenticmobile.ame.compose

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.ButtonColors
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import com.agenticmobile.ame.BadgeVariant
import com.agenticmobile.ame.BtnStyle
import com.agenticmobile.ame.CalloutType
import com.agenticmobile.ame.SemanticColor
import com.agenticmobile.ame.TimelineStatus
import com.agenticmobile.ame.TxtStyle

/** Composite style for callout rendering — icon, tint, and background. */
data class CalloutStyle(
    val backgroundColor: Color,
    val iconTint: Color,
    val icon: ImageVector
)

/** Composite style for timeline step rendering — circle, connector, and dash. */
data class TimelineStyle(
    val circleColor: Color,
    val lineColor: Color,
    val isDashed: Boolean
)

/**
 * Configuration holder for all AME style mappings.
 *
 * Host apps provide a custom [AmeThemeConfig] via [LocalAmeTheme] to
 * override default Material 3 style mappings. Each lambda receives the
 * AME enum value and returns the corresponding Compose styling object.
 */
data class AmeThemeConfig(
    val textStyles: @Composable (TxtStyle) -> TextStyle = { defaultTextStyle(it) },
    val badgeColors: @Composable (BadgeVariant) -> Color = { defaultBadgeColor(it) },
    val btnColors: @Composable (BtnStyle) -> ButtonColors = { defaultBtnColors(it) },
    val calloutStyles: @Composable (CalloutType) -> CalloutStyle = { defaultCalloutStyle(it) },
    val timelineStyles: @Composable (TimelineStatus) -> TimelineStyle = { defaultTimelineStyle(it) },
    val semanticColors: @Composable (SemanticColor) -> Color = { defaultSemanticColor(it) },
)

/**
 * CompositionLocal for host app theme overrides. Provide a custom
 * [AmeThemeConfig] to change how AME primitives are styled.
 *
 * Usage:
 * ```
 * CompositionLocalProvider(LocalAmeTheme provides myConfig) {
 *     AmeRenderer(node, ...)
 * }
 * ```
 */
val LocalAmeTheme = staticCompositionLocalOf { AmeThemeConfig() }

/**
 * Convenience accessor for the current [AmeThemeConfig].
 * All AME composables read styles through this object.
 */
object AmeTheme {

    val config: AmeThemeConfig
        @Composable get() = LocalAmeTheme.current

    @Composable
    fun textStyle(style: TxtStyle): TextStyle = config.textStyles(style)

    @Composable
    fun badgeColor(variant: BadgeVariant): Color = config.badgeColors(variant)

    @Composable
    fun btnColors(style: BtnStyle): ButtonColors = config.btnColors(style)

    @Composable
    fun calloutStyle(type: CalloutType): CalloutStyle = config.calloutStyles(type)

    @Composable
    fun timelineStyle(status: TimelineStatus): TimelineStyle = config.timelineStyles(status)

    @Composable
    fun semanticColor(color: SemanticColor): Color = config.semanticColors(color)
}

// ── Default Mapping Functions ──────────────────────────────────────────────

/**
 * Maps [TxtStyle] enum values to Material 3 [TextStyle] objects.
 * Mappings follow primitives.md § txt Compose Mapping.
 */
@Composable
internal fun defaultTextStyle(style: TxtStyle): TextStyle = when (style) {
    TxtStyle.DISPLAY -> MaterialTheme.typography.displayMedium
    TxtStyle.HEADLINE -> MaterialTheme.typography.headlineSmall
    TxtStyle.TITLE -> MaterialTheme.typography.titleMedium
    TxtStyle.BODY -> MaterialTheme.typography.bodyMedium
    TxtStyle.CAPTION -> MaterialTheme.typography.bodySmall
    TxtStyle.MONO -> MaterialTheme.typography.bodyMedium.copy(fontFamily = FontFamily.Monospace)
    TxtStyle.LABEL -> MaterialTheme.typography.labelMedium
    TxtStyle.OVERLINE -> MaterialTheme.typography.labelSmall
}

/**
 * Maps [BadgeVariant] enum values to background [Color] objects.
 * Mappings follow primitives.md § badge Compose Mapping.
 *
 * Bug #14 (WP#5, Path D): SUCCESS and WARNING tokens are mode-aware.
 * Material 3's standard ColorScheme has no built-in success/warning roles,
 * so AME branches on [isSystemInDarkTheme] using documented Material green
 * and orange swatches: 700 (richer, higher contrast) for light mode and
 * 300 (lighter, lower saturation) for dark mode. See Bug 25 (deferred to
 * v1.3) for the proper AmeThemeConfig role-family extension.
 */
@Composable
internal fun defaultBadgeColor(variant: BadgeVariant): Color = when (variant) {
    BadgeVariant.DEFAULT -> MaterialTheme.colorScheme.surfaceVariant
    BadgeVariant.SUCCESS -> if (isSystemInDarkTheme()) Color(0xFF81C784) else Color(0xFF388E3C)
    BadgeVariant.WARNING -> if (isSystemInDarkTheme()) Color(0xFFFFB74D) else Color(0xFFF57C00)
    BadgeVariant.ERROR -> MaterialTheme.colorScheme.error
    BadgeVariant.INFO -> MaterialTheme.colorScheme.primary
}

/**
 * Maps [BtnStyle] enum values to Material 3 [ButtonColors].
 * The actual button composable type (Button, OutlinedButton, etc.) is
 * selected by the renderer — this function only provides colors.
 * Mappings follow primitives.md § btn Compose Mapping.
 */
@Composable
internal fun defaultBtnColors(style: BtnStyle): ButtonColors = when (style) {
    BtnStyle.PRIMARY -> ButtonDefaults.buttonColors()
    BtnStyle.SECONDARY -> ButtonDefaults.filledTonalButtonColors()
    BtnStyle.OUTLINE -> ButtonDefaults.outlinedButtonColors()
    BtnStyle.TEXT -> ButtonDefaults.textButtonColors()
    BtnStyle.DESTRUCTIVE -> ButtonDefaults.buttonColors(
        containerColor = MaterialTheme.colorScheme.error,
        contentColor = MaterialTheme.colorScheme.onError,
    )
}

/**
 * Maps [CalloutType] to a composite [CalloutStyle] with background, icon, and tint.
 *
 * Bug #14 (WP#5, Path D): WARNING / SUCCESS / TIP are mode-aware. Light
 * mode uses the Material 3 700-weight tints with their canonical pastel
 * containers; dark mode uses the Material 3 300-weight tints with desaturated
 * deep-tone containers tuned for legibility on Material 3 dark surfaces.
 * INFO and ERROR continue to derive from MaterialTheme.colorScheme so they
 * inherit the host's dynamic palette unchanged.
 */
@Composable
internal fun defaultCalloutStyle(type: CalloutType): CalloutStyle = when (type) {
    CalloutType.INFO -> CalloutStyle(
        backgroundColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.3f),
        iconTint = MaterialTheme.colorScheme.primary,
        icon = Icons.Filled.Info
    )
    CalloutType.WARNING -> CalloutStyle(
        backgroundColor = if (isSystemInDarkTheme()) Color(0xFF3E2D1E) else Color(0xFFFFF3E0),
        iconTint = if (isSystemInDarkTheme()) Color(0xFFFFB74D) else Color(0xFFF57C00),
        icon = Icons.Filled.Warning
    )
    CalloutType.ERROR -> CalloutStyle(
        backgroundColor = MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.3f),
        iconTint = MaterialTheme.colorScheme.error,
        icon = Icons.Filled.Error
    )
    CalloutType.SUCCESS -> CalloutStyle(
        backgroundColor = if (isSystemInDarkTheme()) Color(0xFF1B3A1F) else Color(0xFFE8F5E9),
        iconTint = if (isSystemInDarkTheme()) Color(0xFF81C784) else Color(0xFF388E3C),
        icon = Icons.Filled.CheckCircle
    )
    CalloutType.TIP -> CalloutStyle(
        backgroundColor = if (isSystemInDarkTheme()) Color(0xFF2E1A33) else Color(0xFFF3E5F5),
        iconTint = if (isSystemInDarkTheme()) Color(0xFFCE93D8) else Color(0xFF7B1FA2),
        icon = Icons.Filled.Lightbulb
    )
}

/**
 * Maps [TimelineStatus] to a composite [TimelineStyle] with circle color,
 * connector line color, and dashed flag.
 */
@Composable
internal fun defaultTimelineStyle(status: TimelineStatus): TimelineStyle = when (status) {
    TimelineStatus.DONE -> TimelineStyle(
        circleColor = MaterialTheme.colorScheme.primary,
        lineColor = MaterialTheme.colorScheme.primary,
        isDashed = false
    )
    TimelineStatus.ACTIVE -> TimelineStyle(
        circleColor = MaterialTheme.colorScheme.primary,
        lineColor = MaterialTheme.colorScheme.outline,
        isDashed = true
    )
    TimelineStatus.PENDING -> TimelineStyle(
        circleColor = MaterialTheme.colorScheme.outline,
        lineColor = MaterialTheme.colorScheme.outline,
        isDashed = true
    )
    TimelineStatus.ERROR -> TimelineStyle(
        circleColor = MaterialTheme.colorScheme.error,
        lineColor = MaterialTheme.colorScheme.error,
        isDashed = false
    )
}

/**
 * Maps [SemanticColor] to Material 3 [Color] objects.
 *
 * Bug #14 (WP#5, Path D): SUCCESS and WARNING are mode-aware via
 * [isSystemInDarkTheme] using the same Material 700/300 swatches as
 * [defaultBadgeColor] for cross-primitive consistency. PRIMARY, SECONDARY,
 * and ERROR continue to derive from the host's MaterialTheme.colorScheme.
 */
@Composable
internal fun defaultSemanticColor(color: SemanticColor): Color = when (color) {
    SemanticColor.PRIMARY -> MaterialTheme.colorScheme.primary
    SemanticColor.SECONDARY -> MaterialTheme.colorScheme.secondary
    SemanticColor.ERROR -> MaterialTheme.colorScheme.error
    SemanticColor.SUCCESS -> if (isSystemInDarkTheme()) Color(0xFF81C784) else Color(0xFF388E3C)
    SemanticColor.WARNING -> if (isSystemInDarkTheme()) Color(0xFFFFB74D) else Color(0xFFF57C00)
}
