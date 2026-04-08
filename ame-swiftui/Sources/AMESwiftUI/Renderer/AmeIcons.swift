import Foundation

/// Maps Material icon name strings (snake_case) to SF Symbols system names.
///
/// The AME Icon node carries a string `name` property (e.g., "star", "email").
/// This registry resolves those strings to SF Symbols names at render time.
///
/// All 57 SF Symbol names verified available on iOS 16+ (SF Symbols 4.0).
/// Unknown names return a fallback question-mark icon.
public struct AmeIcons {

    /// Resolves a Material icon name to an SF Symbols system name.
    public static func resolve(_ name: String) -> String {
        registry[name] ?? fallbackIcon
    }

    /// Derives a human-readable content description from an icon name
    /// by replacing underscores with spaces.
    public static func contentDescription(_ name: String) -> String {
        name.replacingOccurrences(of: "_", with: " ")
    }

    /// The number of registered icon mappings.
    public static var registryCount: Int { registry.count }

    // MARK: - Private

    static let fallbackIcon = "questionmark.circle"

    private static let registry: [String: String] = [
        // Navigation
        "arrow_back":       "chevron.left",
        "arrow_forward":    "chevron.right",
        "close":            "xmark",
        "menu":             "line.3.horizontal",
        "home":             "house",

        // Actions
        "check":            "checkmark",
        "check_circle":     "checkmark.circle.fill",
        "add":              "plus",
        "delete":           "trash",
        "edit":             "pencil",
        "search":           "magnifyingglass",
        "share":            "square.and.arrow.up",
        "bookmark":         "bookmark",
        "favorite":         "heart.fill",
        "content_copy":     "doc.on.doc",
        "send":             "paperplane",

        // Communication
        "email":            "envelope",
        "phone":            "phone",
        "message":          "message",
        "chat":             "bubble.left",
        "notifications":    "bell",

        // Content
        "star":             "star.fill",
        "star_outline":     "star",
        "info":             "info.circle",
        "warning":          "exclamationmark.triangle",
        "error":            "xmark.circle",

        // Places
        "place":            "mappin",
        "location_on":      "location.fill",
        "directions":       "arrow.triangle.turn.up.right.diamond",
        "map":              "map",
        "restaurant":       "fork.knife",

        // Time & Calendar
        "event":            "calendar",
        "schedule":         "clock",
        "access_time":      "clock",
        "today":            "calendar.circle",
        "calendar_month":   "calendar",

        // Media
        "play_arrow":       "play.fill",
        "pause":            "pause.fill",
        "skip_next":        "forward.fill",
        "music_note":       "music.note",
        "volume_up":        "speaker.wave.3",

        // Files & Data
        "description":      "doc.text",
        "folder":           "folder",
        "cloud":            "cloud",
        "download":         "arrow.down.circle",
        "upload":           "arrow.up.circle",

        // People
        "person":           "person",
        "group":            "person.2",
        "account_circle":   "person.circle",

        // Weather
        "partly_cloudy_day": "cloud.sun",
        "sunny":            "sun.max",
        "wb_sunny":         "sun.max",

        // Misc
        "settings":         "gear",
        "help":             "questionmark.circle",
        "visibility":       "eye",
        "lock":             "lock",
        "list":             "list.bullet",
    ]
}
