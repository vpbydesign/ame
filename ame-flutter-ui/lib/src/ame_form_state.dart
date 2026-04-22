import 'package:flutter/foundation.dart';

/// Manages form input values for AME Input and Toggle nodes within a
/// rendered AME document.
///
/// The host app creates [AmeFormState] instances and passes them to
/// [AmeRenderer]. The host is responsible for scoping form state lifetime
/// (e.g., keyed by message ID in a ViewModel / Provider).
///
/// All access is expected to occur on the main/UI thread.
class AmeFormState extends ChangeNotifier {
  final Map<String, String> _inputValues = {};
  final Map<String, bool> _toggleValues = {};

  /// Diagnostic surface populated by [collectValues] when an input id
  /// and a toggle id collide. Soft-warn only: the merge order is preserved
  /// (toggle wins); this list lets hosts detect the data-loss class instead
  /// of silently shipping bad form payloads.
  final List<String> _collisionWarnings = [];

  /// Read-only snapshot of warnings recorded during the last
  /// [collectValues] call. Empty until [collectValues] is invoked at
  /// least once. Cleared at the start of each [collectValues] call so
  /// hosts always see the diagnostics for the most recent collection.
  List<String> get warnings => List.unmodifiable(_collisionWarnings);

  /// Returns the current value for an input field, or [defaultValue] if unset.
  String getInput(String id, [String defaultValue = '']) =>
      _inputValues[id] ?? defaultValue;

  /// Sets the value for an input field and notifies listeners.
  void setInput(String id, String value) {
    _inputValues[id] = value;
    notifyListeners();
  }

  /// Returns the current value for a toggle field, or [defaultValue] if unset.
  bool getToggle(String id, [bool defaultValue = false]) =>
      _toggleValues[id] ?? defaultValue;

  /// Sets the value for a toggle field and notifies listeners.
  void setToggle(String id, bool value) {
    _toggleValues[id] = value;
    notifyListeners();
  }

  /// Collects all current form values into a flat map.
  ///
  /// Input values are included as-is. Toggle boolean values are
  /// converted to `"true"` or `"false"` strings.
  ///
  /// When an id is registered as both an input and a toggle, the toggle
  /// value wins and a warning is recorded in [warnings] for host visibility.
  Map<String, String> collectValues() {
    _collisionWarnings.clear();
    final result = <String, String>{};
    _inputValues.forEach((id, value) {
      result[id] = value;
    });
    _toggleValues.forEach((id, value) {
      if (result.containsKey(id)) {
        _collisionWarnings.add(
          "Form field id collision: '$id' is registered as both input and "
          'toggle; toggle value used.',
        );
      }
      result[id] = value.toString();
    });
    return result;
  }

  /// Resolves `${input.fieldId}` references in action argument values
  /// against the current form state.
  ///
  /// If the referenced field ID exists in the form state, the token is
  /// replaced with the current value. If not found, the token is left
  /// as-is (unreplaced) per actions.md Form Data Resolution.
  Map<String, String> resolveInputReferences(Map<String, String> args) {
    final collected = collectValues();
    return args.map((key, value) => MapEntry(
          key,
          value.replaceAllMapped(_inputRefRegex, (match) {
            final fieldId = match.group(1)!;
            return collected[fieldId] ?? match.group(0)!;
          }),
        ));
  }

  // Accepts letters, digits, underscores, and hyphens. The hyphen sits
  // at the end of the class to avoid being parsed as a range. The literal
  // `.` separator inside the curly braces is preserved as a hard separator
  // so `${input.user.name}` remains a non-match.
  static final _inputRefRegex =
      RegExp(r'\$\{input\.([a-zA-Z0-9_-]+)\}');
}
