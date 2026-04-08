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
}
