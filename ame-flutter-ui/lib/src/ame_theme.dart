import 'package:flutter/material.dart';
import 'package:ame_flutter/ame_flutter.dart';

/// Composite style for callout rendering.
class CalloutStyle {
  final Color backgroundColor;
  final Color iconTint;
  final IconData icon;
  const CalloutStyle({
    required this.backgroundColor,
    required this.iconTint,
    required this.icon,
  });
}

/// Composite style for timeline step rendering.
class TimelineStyle {
  final Color circleColor;
  final Color lineColor;
  final bool isDashed;
  const TimelineStyle({
    required this.circleColor,
    required this.lineColor,
    required this.isDashed,
  });
}

/// Maps AME enum values to Material 3 styles.
///
/// All mappings follow primitives.md tables. Uses [BuildContext] to access
/// the current [ThemeData] and [ColorScheme].
///
/// SUCCESS and WARNING semantic tokens (and the warning/success/tip callout
/// styles) branch on brightness using documented Material green and orange
/// swatches: 700 (richer, higher contrast) for light mode and 300 (lighter,
/// lower saturation) for dark mode.
class AmeTheme {
  AmeTheme._();

  // Material 3 Green / Orange palette anchors.
  static const Color _successLight = Color(0xFF388E3C); // Green 700
  static const Color _successDark = Color(0xFF81C784); // Green 300
  static const Color _warningLight = Color(0xFFF57C00); // Orange 700
  static const Color _warningDark = Color(0xFFFFB74D); // Orange 300

  // Callout container/tint pairs (light / dark).
  static const Color _calloutWarningBgLight = Color(0xFFFFF3E0);
  static const Color _calloutWarningBgDark = Color(0xFF3E2D1E);
  static const Color _calloutSuccessBgLight = Color(0xFFE8F5E9);
  static const Color _calloutSuccessBgDark = Color(0xFF1B3A1F);
  static const Color _calloutTipBgLight = Color(0xFFF3E5F5);
  static const Color _calloutTipBgDark = Color(0xFF2E1A33);
  static const Color _calloutTipTintLight = Color(0xFF7B1FA2);
  static const Color _calloutTipTintDark = Color(0xFFCE93D8);

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  // ── Text Style ─────────────────────────────────────────────────────

  static TextStyle textStyle(BuildContext context, TxtStyle style) {
    final theme = Theme.of(context).textTheme;
    return switch (style) {
      TxtStyle.display => theme.displayMedium!,
      TxtStyle.headline => theme.headlineSmall!,
      TxtStyle.title => theme.titleMedium!,
      TxtStyle.body => theme.bodyMedium!,
      TxtStyle.caption => theme.bodySmall!,
      TxtStyle.mono => theme.bodyMedium!.copyWith(fontFamily: 'monospace'),
      TxtStyle.label => theme.labelMedium!,
      TxtStyle.overline => theme.labelSmall!,
    };
  }

  // ── Badge Color ────────────────────────────────────────────────────

  static Color badgeColor(BuildContext context, BadgeVariant variant) {
    final scheme = Theme.of(context).colorScheme;
    final dark = _isDark(context);
    return switch (variant) {
      BadgeVariant.defaultVariant => scheme.surfaceContainerHighest,
      BadgeVariant.success => dark ? _successDark : _successLight,
      BadgeVariant.warning => dark ? _warningDark : _warningLight,
      BadgeVariant.error => scheme.error,
      BadgeVariant.info => scheme.primary,
    };
  }

  // ── Button Style ───────────────────────────────────────────────────

  static ButtonStyle? btnStyle(BuildContext context, BtnStyle style) {
    final scheme = Theme.of(context).colorScheme;
    return switch (style) {
      BtnStyle.primary => ElevatedButton.styleFrom(),
      BtnStyle.secondary => FilledButton.styleFrom(),
      BtnStyle.outline => OutlinedButton.styleFrom(),
      BtnStyle.text => TextButton.styleFrom(),
      BtnStyle.destructive => ElevatedButton.styleFrom(
          backgroundColor: scheme.error,
          foregroundColor: scheme.onError,
        ),
    };
  }

  // ── Callout Style ──────────────────────────────────────────────────

  static CalloutStyle calloutStyle(BuildContext context, CalloutType type) {
    final scheme = Theme.of(context).colorScheme;
    final dark = _isDark(context);
    return switch (type) {
      CalloutType.info => CalloutStyle(
          backgroundColor: scheme.primaryContainer.withValues(alpha: 0.3),
          iconTint: scheme.primary,
          icon: Icons.info,
        ),
      CalloutType.warning => CalloutStyle(
          backgroundColor:
              dark ? _calloutWarningBgDark : _calloutWarningBgLight,
          iconTint: dark ? _warningDark : _warningLight,
          icon: Icons.warning,
        ),
      CalloutType.error => CalloutStyle(
          backgroundColor: scheme.errorContainer.withValues(alpha: 0.3),
          iconTint: scheme.error,
          icon: Icons.error,
        ),
      CalloutType.success => CalloutStyle(
          backgroundColor:
              dark ? _calloutSuccessBgDark : _calloutSuccessBgLight,
          iconTint: dark ? _successDark : _successLight,
          icon: Icons.check_circle,
        ),
      CalloutType.tip => CalloutStyle(
          backgroundColor: dark ? _calloutTipBgDark : _calloutTipBgLight,
          iconTint: dark ? _calloutTipTintDark : _calloutTipTintLight,
          icon: Icons.lightbulb,
        ),
    };
  }

  // ── Timeline Style ─────────────────────────────────────────────────

  static TimelineStyle timelineStyle(
      BuildContext context, TimelineStatus status) {
    final scheme = Theme.of(context).colorScheme;
    return switch (status) {
      TimelineStatus.done => TimelineStyle(
          circleColor: scheme.primary,
          lineColor: scheme.primary,
          isDashed: false,
        ),
      TimelineStatus.active => TimelineStyle(
          circleColor: scheme.primary,
          lineColor: scheme.outline,
          isDashed: true,
        ),
      TimelineStatus.pending => TimelineStyle(
          circleColor: scheme.outline,
          lineColor: scheme.outline,
          isDashed: true,
        ),
      TimelineStatus.error => TimelineStyle(
          circleColor: scheme.error,
          lineColor: scheme.error,
          isDashed: false,
        ),
    };
  }

  // ── Semantic Color ─────────────────────────────────────────────────

  static Color semanticColor(BuildContext context, SemanticColor color) {
    final scheme = Theme.of(context).colorScheme;
    final dark = _isDark(context);
    return switch (color) {
      SemanticColor.primary => scheme.primary,
      SemanticColor.secondary => scheme.secondary,
      SemanticColor.error => scheme.error,
      SemanticColor.success => dark ? _successDark : _successLight,
      SemanticColor.warning => dark ? _warningDark : _warningLight,
    };
  }
}
