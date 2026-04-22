import SwiftUI

/// Maps AME style enums to SwiftUI styling objects.
///
/// Host apps can replace this with a custom theme by providing their own
/// static functions or by wrapping AmeRenderer with environment overrides.
public struct AmeTheme {

    // MARK: - Text Style Mapping

    /// Maps TxtStyle enum values to SwiftUI Font objects.
    /// Mappings follow primitives.md typographic hierarchy.
    public static func font(_ style: TxtStyle) -> Font {
        switch style {
        case .display:  return .system(size: 34, weight: .bold)
        case .headline: return .title2
        case .title:    return .headline
        case .body:     return .body
        case .caption:  return .caption
        case .mono:     return .system(.body, design: .monospaced)
        case .label:    return .subheadline
        case .overline: return .caption2
        }
    }

    // MARK: - Badge Color Mapping

    /// Maps BadgeVariant enum values to background Color objects.
    ///
    /// Semantic system colors (`Color(.systemGreen)`
    /// etc.) automatically adapt to the user's appearance setting per
    /// Apple HIG, with no `@Environment(\.colorScheme)` plumbing required.
    public static func badgeColor(_ variant: BadgeVariant) -> Color {
        switch variant {
        #if os(iOS)
        case .default: return Color(.systemGray5)
        #else
        case .default: return Color.gray.opacity(0.15)
        #endif
        case .success: return Color(.systemGreen).opacity(0.2)
        case .warning: return Color(.systemOrange).opacity(0.2)
        case .error:   return Color(.systemRed).opacity(0.2)
        case .info:    return Color(.systemBlue).opacity(0.2)
        }
    }

    // MARK: - Badge Text Color Mapping

    /// Maps BadgeVariant to a foreground text color for contrast.
    public static func badgeTextColor(_ variant: BadgeVariant) -> Color {
        switch variant {
        case .default: return .primary
        case .success: return Color(.systemGreen)
        case .warning: return Color(.systemOrange)
        case .error:   return Color(.systemRed)
        case .info:    return Color(.systemBlue)
        }
    }

    // MARK: - Callout Style Mapping

    /// Maps CalloutType to an SF Symbol name for the callout icon.
    public static func calloutIcon(_ type: CalloutType) -> String {
        switch type {
        case .info:    return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error:   return "xmark.circle"
        case .success: return "checkmark.circle"
        case .tip:     return "lightbulb"
        }
    }

    /// Maps CalloutType to a foreground tint color.
    public static func calloutTint(_ type: CalloutType) -> Color {
        switch type {
        case .info:    return Color(.systemBlue)
        case .warning: return Color(.systemOrange)
        case .error:   return Color(.systemRed)
        case .success: return Color(.systemGreen)
        case .tip:     return Color(.systemPurple)
        }
    }

    /// Maps CalloutType to a subtle background fill color.
    public static func calloutBackground(_ type: CalloutType) -> Color {
        calloutTint(type).opacity(0.1)
    }

    // MARK: - Timeline Style Mapping

    /// Maps TimelineStatus to a circle fill color.
    public static func timelineCircleColor(_ status: TimelineStatus) -> Color {
        switch status {
        case .done:    return .accentColor
        case .active:  return .accentColor
        #if os(iOS)
        case .pending: return Color(.systemGray3)
        #else
        case .pending: return Color.gray.opacity(0.4)
        #endif
        case .error:   return Color(.systemRed)
        }
    }

    /// Maps TimelineStatus to a connector line color.
    public static func timelineLineColor(_ status: TimelineStatus) -> Color {
        switch status {
        case .done:    return .accentColor
        #if os(iOS)
        case .active:  return Color(.systemGray3)
        case .pending: return Color(.systemGray3)
        #else
        case .active:  return Color.gray.opacity(0.4)
        case .pending: return Color.gray.opacity(0.4)
        #endif
        case .error:   return Color(.systemRed)
        }
    }

    /// Whether the connector line after this status should be dashed.
    public static func timelineIsDashed(_ status: TimelineStatus) -> Bool {
        switch status {
        case .done:    return false
        case .active:  return true
        case .pending: return true
        case .error:   return false
        }
    }

    // MARK: - Semantic Color Mapping

    /// Maps SemanticColor to a platform-appropriate SwiftUI color.
    ///
    /// Adaptive system semantic colors. Apple's
    /// `Color(.systemGreen)` etc. automatically resolve to mode-appropriate
    /// values per HIG, with no `@Environment(\.colorScheme)` plumbing
    /// required. SUCCESS stays recognizably green and WARNING stays
    /// recognizably orange across light and dark mode, preserving the
    /// semantic vocabulary AME callouts depend on.
    public static func semanticColor(_ color: SemanticColor) -> Color {
        switch color {
        case .primary:   return .accentColor
        case .secondary: return .secondary
        case .error:     return Color(.systemRed)
        case .success:   return Color(.systemGreen)
        case .warning:   return Color(.systemOrange)
        }
    }
}
