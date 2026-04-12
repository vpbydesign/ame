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
    public static func badgeColor(_ variant: BadgeVariant) -> Color {
        switch variant {
        #if os(iOS)
        case .default: return Color(.systemGray5)
        #else
        case .default: return Color.gray.opacity(0.15)
        #endif
        case .success: return Color.green.opacity(0.2)
        case .warning: return Color.orange.opacity(0.2)
        case .error:   return Color.red.opacity(0.2)
        case .info:    return Color.blue.opacity(0.2)
        }
    }

    // MARK: - Badge Text Color Mapping

    /// Maps BadgeVariant to a foreground text color for contrast.
    public static func badgeTextColor(_ variant: BadgeVariant) -> Color {
        switch variant {
        case .default: return .primary
        case .success: return Color.green
        case .warning: return Color.orange
        case .error:   return Color.red
        case .info:    return Color.blue
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
        case .info:    return .blue
        case .warning: return .orange
        case .error:   return .red
        case .success: return .green
        case .tip:     return .purple
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
        case .error:   return .red
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
        case .error:   return .red
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
    public static func semanticColor(_ color: SemanticColor) -> Color {
        switch color {
        case .primary:   return .accentColor
        case .secondary: return .secondary
        case .error:     return .red
        case .success:   return .green
        case .warning:   return .orange
        }
    }
}
