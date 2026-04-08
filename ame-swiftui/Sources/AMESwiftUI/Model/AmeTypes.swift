import Foundation

// MARK: - Align

/// Horizontal/vertical alignment for layout primitives.
/// col supports: start, center, end
/// row supports: start, center, end, space_between, space_around
public enum Align: String, Codable, Equatable, CaseIterable, Sendable {
    case start
    case center
    case end
    case spaceBetween = "space_between"
    case spaceAround = "space_around"
}

// MARK: - TxtStyle

/// Typographic style for the txt primitive.
public enum TxtStyle: String, Codable, Equatable, CaseIterable, Sendable {
    case display
    case headline
    case title
    case body
    case caption
    case mono
    case label
    case overline
}

// MARK: - BtnStyle

/// Visual style for the btn primitive.
public enum BtnStyle: String, Codable, Equatable, CaseIterable, Sendable {
    case primary
    case secondary
    case outline
    case text
    case destructive
}

// MARK: - BadgeVariant

/// Color variant for the badge primitive.
public enum BadgeVariant: String, Codable, Equatable, CaseIterable, Sendable {
    case `default`
    case success
    case warning
    case error
    case info
}

// MARK: - InputType

/// Input field type for the input primitive.
public enum InputType: String, Codable, Equatable, CaseIterable, Sendable {
    case text
    case number
    case email
    case phone
    case date
    case time
    case select
}

// MARK: - AmeKeywords

/// Reserved keywords and parser lookup utilities.
/// Matches the Reserved Keywords section of syntax.md exactly.
public struct AmeKeywords {

    public static let standardPrimitives: Set<String> = [
        "col", "row", "txt", "btn", "card", "badge", "icon", "img",
        "input", "toggle", "list", "table", "divider", "spacer", "progress"
    ]

    public static let actionNames: Set<String> = ["tool", "uri", "nav", "copy", "submit"]

    public static let structuralKeywords: Set<String> = ["each", "root"]

    public static let booleanLiterals: Set<String> = ["true", "false"]

    public static let dataSeparator: String = "---"

    public static func isReserved(_ identifier: String) -> Bool {
        standardPrimitives.contains(identifier) ||
        actionNames.contains(identifier) ||
        structuralKeywords.contains(identifier) ||
        booleanLiterals.contains(identifier)
    }

    public static func parseAlign(_ value: String) -> Align? {
        Align.allCases.first { $0.rawValue.caseInsensitiveCompare(value) == .orderedSame }
    }

    public static func parseTxtStyle(_ value: String) -> TxtStyle? {
        TxtStyle.allCases.first { $0.rawValue.caseInsensitiveCompare(value) == .orderedSame }
    }

    public static func parseBtnStyle(_ value: String) -> BtnStyle? {
        BtnStyle.allCases.first { $0.rawValue.caseInsensitiveCompare(value) == .orderedSame }
    }

    public static func parseBadgeVariant(_ value: String) -> BadgeVariant? {
        BadgeVariant.allCases.first { $0.rawValue.caseInsensitiveCompare(value) == .orderedSame }
    }

    public static func parseInputType(_ value: String) -> InputType? {
        InputType.allCases.first { $0.rawValue.caseInsensitiveCompare(value) == .orderedSame }
    }
}
