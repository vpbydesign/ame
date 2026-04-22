import Foundation

/// Serializes and deserializes AmeNode trees and AmeAction objects to/from JSON.
///
/// Uses Swift's Codable with custom encode/decode implementations that match
/// the canonical AME JSON format:
/// - Class discriminator key: `"_type"`
/// - Default values omitted (matching `encodeDefaults = false`)
/// - Forward-compatible deserialization (unknown keys ignored via Codable defaults)
/// - Whole-number Double / Float values preserve the `.0` suffix
///   (canonical form per `regression-protocol.md` §7). Foundation's
///   `JSONEncoder` strips trailing zeros (`Double(1.0)` -> `1`), breaking
///   cross-runtime byte-equality.
///   AME wraps the affected fields (`Chart.values`, `Chart.series`,
///   `Progress.value`) in `PreservedDouble` / `PreservedFloat`, which encodes
///   the value as a sentinel-bracketed string and `toJson(_:)` strips the
///   sentinels post-encode to leave raw JSON numbers with `.0` preserved.
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
        guard let raw = String(data: data, encoding: .utf8) else { return nil }
        return PreservedNumberSentinel.strip(raw)
    }

    /// Decodes [jsonString] into an `AmeNode`. Returns `nil` on any failure
    /// for backward compatibility. Hosts that need failure diagnostics
    /// should call ``fromJsonOrError(_:)`` instead.
    public static func fromJson(_ jsonString: String) -> AmeNode? {
        guard case .success(let node) = fromJsonOrError(jsonString) else { return nil }
        return node
    }

    /// Diagnostic-bearing counterpart to ``fromJson(_:)``. Returns
    /// `.success` with the decoded node on success, or `.failure` with the
    /// underlying decoding `Error` so hosts can distinguish invalid JSON,
    /// schema mismatch, and unexpected runtime failures.
    ///
    /// The previous nullable ``fromJson(_:)`` swallowed
    /// every failure into a single `nil` return. This API is additive; the
    /// legacy nullable function stays unchanged for backward compatibility.
    public static func fromJsonOrError(_ jsonString: String) -> Result<AmeNode, Error> {
        guard let data = jsonString.data(using: .utf8) else {
            return .failure(NSError(
                domain: "AmeSerializer",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid UTF-8 in AME JSON string"]
            ))
        }
        do {
            let node = try decoder.decode(AmeNode.self, from: data)
            return .success(node)
        } catch {
            return .failure(error)
        }
    }

    public static func treeToJson(_ node: AmeNode, prettyPrint: Bool = false) -> String? {
        let enc = prettyPrint ? prettyEncoder : encoder
        guard let data = try? enc.encode(node) else { return nil }
        guard let raw = String(data: data, encoding: .utf8) else { return nil }
        return PreservedNumberSentinel.strip(raw)
    }

    // MARK: - Action Serialization

    public static func actionToJson(_ action: AmeAction) -> String? {
        guard let data = try? encoder.encode(action) else { return nil }
        guard let raw = String(data: data, encoding: .utf8) else { return nil }
        // Action payloads do not currently carry Double/Float fields, but the
        // strip is idempotent and cheap when no sentinels are present, so we
        // apply it here for forward-safety.
        return PreservedNumberSentinel.strip(raw)
    }

    /// Decodes [jsonString] into an `AmeAction`. Returns `nil` on any
    /// failure for backward compatibility. See ``actionFromJsonOrError(_:)``
    /// for the diagnostic variant.
    public static func actionFromJson(_ jsonString: String) -> AmeAction? {
        guard case .success(let action) = actionFromJsonOrError(jsonString) else { return nil }
        return action
    }

    /// Diagnostic-bearing counterpart to ``actionFromJson(_:)``. Mirrors
    /// ``fromJsonOrError(_:)`` for action payloads so cross-runtime hosts
    /// can use a single failure-handling pattern for both nodes and actions.
    public static func actionFromJsonOrError(_ jsonString: String) -> Result<AmeAction, Error> {
        guard let data = jsonString.data(using: .utf8) else {
            return .failure(NSError(
                domain: "AmeSerializer",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid UTF-8 in AME action JSON string"]
            ))
        }
        do {
            let action = try decoder.decode(AmeAction.self, from: data)
            return .success(action)
        } catch {
            return .failure(error)
        }
    }
}

// MARK: - Preserved-Double / Preserved-Float wrappers

/// Encoder-side wrapper that forces a Double to round-trip through JSON with
/// the canonical representation (e.g., `1.0` instead of `1`). Wraps
/// the value into a sentinel-bracketed string at encode time;
/// `AmeSerializer.toJson(_:)` strips the sentinels post-encode, leaving a
/// raw JSON number. Decode is intentionally unimplemented: the JSON wire
/// form is a plain number, and `Codable` consumers decode `[Double]`
/// directly.
struct PreservedDouble: Encodable {
    let value: Double

    init(_ value: Double) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(PreservedNumberSentinel.wrap(Self.canonicalString(value)))
    }

    /// Canonical Double formatting: whole numbers always carry the `.0`
    /// suffix; fractional values use Swift's shortest round-trip
    /// representation (which already matches the canonical form for the
    /// patterns AME data normally contains, e.g., `10.5`, `3.14`, `0.75`).
    static func canonicalString(_ value: Double) -> String {
        // Pre-condition: Doubles in AME must be finite (NaN / Inf are not
        // valid JSON numbers and would have failed JSONEncoder anyway).
        // Whole-number test guards against floating-point fuzz on enormous
        // values where `.rounded()` is not informative.
        if value.isFinite && value == value.rounded() && abs(value) < 1e16 {
            // Integer-valued Double -> force the `.0` suffix.
            // Use Int64 cast to avoid `1e10` style for medium-large values.
            let asInt = Int64(value)
            return "\(asInt).0"
        }
        return String(value)
    }
}

/// Float counterpart of `PreservedDouble`, used for `Progress.value` which
/// is `Float` in the Swift AST.
struct PreservedFloat: Encodable {
    let value: Float

    init(_ value: Float) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(PreservedNumberSentinel.wrap(Self.canonicalString(value)))
    }

    static func canonicalString(_ value: Float) -> String {
        if value.isFinite && value == value.rounded() && abs(value) < 1e7 {
            let asInt = Int64(value)
            return "\(asInt).0"
        }
        return String(value)
    }
}

/// Sentinel scheme used by `PreservedDouble` / `PreservedFloat` to round-trip
/// a numeric value as a string through `JSONEncoder` and then back to a raw
/// JSON number via post-encode string surgery in `AmeSerializer.toJson`.
///
/// The sentinel is intentionally non-empty and non-numeric so the strip
/// regex cannot collide with legitimate user content; the leading/trailing
/// sentinels also guarantee that the surrounding `"` quotes are removed in
/// the same pass (the pattern matches `"<start>NUMBER<end>"` and emits
/// `NUMBER`).
enum PreservedNumberSentinel {
    static let start = "__AMENUM_START__"
    static let end = "__AMENUM_END__"

    static func wrap(_ numericString: String) -> String {
        "\(start)\(numericString)\(end)"
    }

    /// Replace every `"<start>NUM<end>"` occurrence in `json` with `NUM`.
    /// The number capture class permits the characters that legitimately
    /// appear in `String(Double)` / `String(Float)` output: digits, the
    /// decimal point, signs, and exponent markers. Underscores never appear
    /// in those representations, so the surrounding sentinel substrings
    /// cannot collide with the captured payload.
    static func strip(_ json: String) -> String {
        // Fast path: no sentinel present, no work to do (most action payloads
        // and any node tree without chart/progress takes this path).
        if json.range(of: start) == nil { return json }
        let pattern = "\"\(start)([0-9eE.+\\-]+)\(end)\""
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return json }
        let range = NSRange(json.startIndex..., in: json)
        return regex.stringByReplacingMatches(in: json, options: [], range: range, withTemplate: "$1")
    }
}
