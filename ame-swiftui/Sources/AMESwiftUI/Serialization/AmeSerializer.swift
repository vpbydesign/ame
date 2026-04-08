import Foundation

/// Serializes and deserializes AmeNode trees and AmeAction objects to/from JSON.
///
/// Uses Swift's Codable with custom encode/decode implementations that match
/// the Kotlin kotlinx.serialization output format:
/// - Class discriminator key: `"_type"`
/// - Default values omitted (matching `encodeDefaults = false`)
/// - Forward-compatible deserialization (unknown keys ignored via Codable defaults)
public struct AmeSerializer {

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let prettyEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        JSONDecoder()
    }()

    // MARK: - Node Serialization

    public static func toJson(_ node: AmeNode) -> String? {
        guard let data = try? encoder.encode(node) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func fromJson(_ jsonString: String) -> AmeNode? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? decoder.decode(AmeNode.self, from: data)
    }

    public static func treeToJson(_ node: AmeNode, prettyPrint: Bool = false) -> String? {
        let enc = prettyPrint ? prettyEncoder : encoder
        guard let data = try? enc.encode(node) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Action Serialization

    public static func actionToJson(_ action: AmeAction) -> String? {
        guard let data = try? encoder.encode(action) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func actionFromJson(_ jsonString: String) -> AmeAction? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? decoder.decode(AmeAction.self, from: data)
    }
}
