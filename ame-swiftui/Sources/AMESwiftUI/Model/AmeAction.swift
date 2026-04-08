import Foundation

/// Actions define what happens when a user interacts with an AME element.
/// They appear as arguments to interactive primitives (primarily btn).
///
/// The renderer dispatches all actions to the host app via AmeActionHandler.
/// The renderer MUST NOT execute actions directly.
///
/// See actions.md for the complete specification.
public enum AmeAction: Equatable, Sendable {

    /// Invoke a named tool through the host app's tool execution pipeline.
    /// `args` values may contain `${input.fieldId}` references as literal strings —
    /// these are resolved by the renderer at dispatch time, NOT by the parser.
    case callTool(name: String, args: [String: String] = [:])

    /// Open a URI using the platform's default handler (geo:, tel:, mailto:, https:, etc.).
    case openUri(uri: String)

    /// Navigate to a screen/route within the host application. Route names are app-defined.
    case navigate(route: String)

    /// Copy a text string to the system clipboard.
    case copyText(text: String)

    /// Collect all input/toggle values from the current card's subtree,
    /// merge with `staticArgs`, and dispatch as a CallTool action.
    ///
    /// The renderer converts Submit to CallTool at dispatch time — the host
    /// app's AmeActionHandler never sees Submit directly.
    case submit(toolName: String, staticArgs: [String: String] = [:])
}

// MARK: - Codable

extension AmeAction: Codable {

    private enum CodingKeys: String, CodingKey {
        case type = "_type"
        case name, args
        case uri
        case route
        case text
        case toolName, staticArgs
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .callTool(let name, let args):
            try container.encode("tool", forKey: .type)
            try container.encode(name, forKey: .name)
            if !args.isEmpty {
                try container.encode(args, forKey: .args)
            }

        case .openUri(let uri):
            try container.encode("uri", forKey: .type)
            try container.encode(uri, forKey: .uri)

        case .navigate(let route):
            try container.encode("nav", forKey: .type)
            try container.encode(route, forKey: .route)

        case .copyText(let text):
            try container.encode("copy", forKey: .type)
            try container.encode(text, forKey: .text)

        case .submit(let toolName, let staticArgs):
            try container.encode("submit", forKey: .type)
            try container.encode(toolName, forKey: .toolName)
            if !staticArgs.isEmpty {
                try container.encode(staticArgs, forKey: .staticArgs)
            }
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "tool":
            let name = try container.decode(String.self, forKey: .name)
            let args = try container.decodeIfPresent([String: String].self, forKey: .args) ?? [:]
            self = .callTool(name: name, args: args)

        case "uri":
            let uri = try container.decode(String.self, forKey: .uri)
            self = .openUri(uri: uri)

        case "nav":
            let route = try container.decode(String.self, forKey: .route)
            self = .navigate(route: route)

        case "copy":
            let text = try container.decode(String.self, forKey: .text)
            self = .copyText(text: text)

        case "submit":
            let toolName = try container.decode(String.self, forKey: .toolName)
            let staticArgs = try container.decodeIfPresent([String: String].self, forKey: .staticArgs) ?? [:]
            self = .submit(toolName: toolName, staticArgs: staticArgs)

        default:
            throw DecodingError.dataCorrupted(
                .init(codingPath: container.codingPath,
                      debugDescription: "Unknown AmeAction _type: \(type)")
            )
        }
    }
}
