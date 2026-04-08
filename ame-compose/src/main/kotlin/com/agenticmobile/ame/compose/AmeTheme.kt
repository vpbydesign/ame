package com.agenticmobile.ame.compose

import androidx.compose.material3.ButtonColors
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import com.agenticmobile.ame.BadgeVariant
import com.agenticmobile.ame.BtnStyle
import com.agenticmobile.ame.TxtStyle

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
 */
@Composable
internal fun defaultBadgeColor(variant: BadgeVariant): Color = when (variant) {
    BadgeVariant.DEFAULT -> MaterialTheme.colorScheme.surfaceVariant
    BadgeVariant.SUCCESS -> Color(0xFF4CAF50)
    BadgeVariant.WARNING -> Color(0xFFFF9800)
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
