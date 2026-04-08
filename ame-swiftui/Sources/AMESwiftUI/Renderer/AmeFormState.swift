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

    public init() {}

    /// Returns a binding for a text input field value.
    /// If the field has not been registered yet, initializes it with `defaultValue`.
    public func binding(for id: String, default defaultValue: String = "") -> Binding<String> {
        if values[id] == nil {
            values[id] = defaultValue
        }
        return Binding(
            get: { self.values[id, default: defaultValue] },
            set: { self.values[id] = $0 }
        )
    }

    /// Returns a binding for a toggle field value.
    /// If the field has not been registered yet, initializes it with `defaultValue`.
    public func toggleBinding(for id: String, default defaultValue: Bool = false) -> Binding<Bool> {
        if toggles[id] == nil {
            toggles[id] = defaultValue
        }
        return Binding(
            get: { self.toggles[id, default: defaultValue] },
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
    /// Input values are included as-is. Toggle boolean values are
    /// converted to "true" or "false" strings.
    public func collectValues() -> [String: String] {
        var result = values
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
        let regex = try! NSRegularExpression(pattern: #"\$\{input\.(\w+)\}"#)

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
