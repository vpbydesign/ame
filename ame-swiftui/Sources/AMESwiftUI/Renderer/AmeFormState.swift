import SwiftUI
import Foundation

/// Manages form input values for AME Input and Toggle nodes within a rendered
/// AME document.
///
/// The host app creates AmeFormState instances and passes them to AmeRenderer.
/// The host is responsible for scoping form state lifetime (e.g., keyed by
/// message ID in a ViewModel).
///
/// Thread safety: all access is expected to occur on the main/UI thread
/// as part of SwiftUI view updates.
public final class AmeFormState: ObservableObject {

    @Published public var values: [String: String] = [:]
    @Published public var toggles: [String: Bool] = [:]

    /// Non-published default storage. Mutating these maps does NOT fire
    /// `objectWillChange`, so default registration during view body is safe.
    /// Reads fall through `values` -> `inputDefaults` (and `toggles` -> `toggleDefaults`).
    private var inputDefaults: [String: String] = [:]
    private var toggleDefaults: [String: Bool] = [:]

    /// Diagnostic surface populated by `collectValues()` when an input id and
    /// a toggle id collide (Bug #12). Soft-warn only: the merge order is
    /// preserved (toggle wins) so that the input/toggle contract documented
    /// in WP#4 Bug 5 stays stable; this list lets hosts detect the
    /// data-loss class instead of silently shipping bad form payloads.
    ///
    /// Cleared and recomputed on every `collectValues()` call so the
    /// warnings always reflect the current registration set.
    private var collisionWarnings: [String] = []

    /// Snapshot of collision warnings produced by the most recent
    /// `collectValues()` call. Empty until `collectValues()` has been
    /// called at least once. Hosts can route this to a logger, telemetry
    /// sink, or a developer-mode debug overlay.
    public var warnings: [String] { collisionWarnings }

    public init() {}

    /// Returns a binding for a text input field value.
    /// Records `defaultValue` in non-published `inputDefaults`. The first user
    /// edit promotes the value into `@Published values`. Until then, `collectValues()`
    /// falls back to the default so unedited fields remain in form submissions.
    public func binding(for id: String, default defaultValue: String = "") -> Binding<String> {
        inputDefaults[id] = defaultValue
        return Binding(
            get: { self.values[id] ?? self.inputDefaults[id] ?? "" },
            set: { self.values[id] = $0 }
        )
    }

    /// Returns a binding for a toggle field value.
    /// Same pattern as `binding(for:default:)`: defaults stored in
    /// non-published `toggleDefaults`; user edits promoted into `@Published toggles`.
    public func toggleBinding(for id: String, default defaultValue: Bool = false) -> Binding<Bool> {
        toggleDefaults[id] = defaultValue
        return Binding(
            get: { self.toggles[id] ?? self.toggleDefaults[id] ?? false },
            set: { self.toggles[id] = $0 }
        )
    }

    /// Returns a binding for a Date input field.
    /// The date is stored as a formatted string in `values` using the specified format.
    /// Format: "yyyy-MM-dd" for date, "HH:mm" for time — matching Kotlin renderer output.
    public func dateBinding(for id: String, format: String) -> Binding<Date> {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        if format == "yyyy-MM-dd" {
            formatter.timeZone = TimeZone(identifier: "UTC")
        }

        return Binding(
            get: {
                if let stored = self.values[id], let date = formatter.date(from: stored) {
                    return date
                }
                return Date()
            },
            set: { newDate in
                self.values[id] = formatter.string(from: newDate)
            }
        )
    }

    /// Collects all current form values into a flat map.
    ///
    /// Merge order: `inputDefaults` -> `values` (user input edits override) ->
    /// `toggleDefaults` -> `toggles` (user toggle edits override). This
    /// preserves the pre-Bug-5 invariant that fields the user never touched
    /// still appear in form submissions with their default value, and
    /// preserves the documented contract that toggle wins on id collision.
    ///
    /// Bug #12 (WP#5) adds visibility without changing behavior: any id
    /// that appears in BOTH the input layer (defaults+values) AND the
    /// toggle layer (toggleDefaults+toggles) produces an entry in
    /// `warnings`. Hosts can route warnings to a logger or developer
    /// overlay to detect the silent-data-loss class. Warnings are
    /// recomputed on every call (clear-then-recompute) so the snapshot
    /// always matches the current registration set.
    ///
    /// Input values are included as-is. Toggle boolean values are
    /// converted to "true" or "false" strings.
    public func collectValues() -> [String: String] {
        collisionWarnings.removeAll(keepingCapacity: true)

        let inputKeys = Set(inputDefaults.keys).union(values.keys)
        let toggleKeys = Set(toggleDefaults.keys).union(toggles.keys)
        for id in inputKeys.intersection(toggleKeys).sorted() {
            collisionWarnings.append(
                "Form field id collision: '\(id)' is registered as both input and toggle; toggle value used."
            )
        }

        var result = inputDefaults
        for (key, val) in values {
            result[key] = val
        }
        for (key, val) in toggleDefaults {
            result[key] = val ? "true" : "false"
        }
        for (key, val) in toggles {
            result[key] = val ? "true" : "false"
        }
        return result
    }

    /// Resolves `${input.fieldId}` references in action argument values
    /// against the current form state.
    ///
    /// The pattern `${input.(\w+)}` is matched in each value string.
    /// If the referenced field ID exists in the form state, the token is
    /// replaced with the current value. If not found, the token is left
    /// as-is per actions.md.
    public func resolveInputReferences(_ args: [String: String]) -> [String: String] {
        let collected = collectValues()
        // Bug #13: the original `\w+` excluded `-`, so `${input.user-name}`
        // was silently left unsubstituted. The character class below accepts
        // letters, digits, underscores, and hyphens. The hyphen is placed at
        // the end of the class to avoid being parsed as a range. The literal
        // `.` separator is preserved so `${input.user.name}` (with a `.`)
        // remains a non-match — defends against future over-permissive
        // expansion that would shadow nested references.
        let regex = try! NSRegularExpression(pattern: #"\$\{input\.([a-zA-Z0-9_-]+)\}"#)

        return args.mapValues { value in
            let range = NSRange(value.startIndex..., in: value)
            var result = value

            let matches = regex.matches(in: value, range: range)
            for match in matches.reversed() {
                guard let fullRange = Range(match.range, in: value),
                      let groupRange = Range(match.range(at: 1), in: value) else {
                    continue
                }
                let fieldId = String(value[groupRange])
                if let replacement = collected[fieldId] {
                    result = result.replacingCharacters(in: fullRange, with: replacement)
                }
            }
            return result
        }
    }
}
