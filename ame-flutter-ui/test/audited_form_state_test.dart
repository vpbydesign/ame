import 'package:ame_flutter_ui/ame_flutter_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// Audit regression tests — Flutter form-state collision warnings.
///
/// Bug 33 (Flutter analog of v1.2 Bug 12) is split between two files:
///
/// 1. `audited_ui_bug_regression_test.dart` carries a source-structural
///    sentinel that always compiles and asserts the production
///    `AmeFormState` declares a `warnings` field/getter.
/// 2. This file (`audited_form_state_test.dart`) calls `collectValues`
///    and asserts the warning surfaces with the canonical message text,
///    mirroring `AmeFormStateTest.testInputToggleIdCollisionDoesNotSilentlyOverwrite`
///    in Compose and `AuditedSwiftUIBugTests.testInputToggleIdCollisionDetected`
///    in SwiftUI.
///
/// Pre-Phase-F this file fails to load because `state.warnings` does not
/// exist yet — that load-time failure IS the per-test pre-fix signal.
/// Post-fix every assertion passes.
///
/// See `specification/v1.0/regression-protocol.md` for the lifecycle rules.
void main() {
  /// Audit Bug #33: when the same id is registered as both an input and
  /// a toggle, `collectValues()` silently overwrites the input value
  /// with the toggle value. Hosts cannot detect the data-loss class.
  /// The fix preserves the merge order (toggle wins per WP#4 Bug 5
  /// contract) AND surfaces a `warnings` list with the canonical
  /// collision message.
  ///
  /// Spec section: specification/v1.0/integration.md (Form state)
  /// Audit reference: AUDIT_VERDICTS.md#bug-33
  /// Pre-fix expected: FAIL — `state.warnings` getter does not exist.
  /// Post-fix expected: PASS — warnings contains a collision message
  ///   referencing the colliding id; merge order still puts toggle wins.
  test('input toggle id collision detected', () {
    final state = AmeFormState();
    state.setInput('x', 'input-value');
    state.setToggle('x', true);

    final collected = state.collectValues();

    expect(
      collected['x'],
      equals('true'),
      reason:
          'Bug #33 fix preserves merge order (toggle wins) per WP#4 Bug 5 contract.',
    );
    expect(
      state.warnings.any(
          (w) => w.contains("'x'") && w.contains('collision')),
      isTrue,
      reason:
          'BUG #33: collision must surface in state.warnings. '
          'Today warnings=${state.warnings}',
    );
  });

  /// Idempotence guard: a subsequent collectValues() call without a
  /// new collision must not retain the prior warning. Mirrors WP#5
  /// Compose test's "warnings cleared on re-collect" pattern (implicit
  /// in `collectValues()` clearing the list at the start).
  test('warnings cleared between collect calls', () {
    final state = AmeFormState();
    state.setInput('x', 'input-value');
    state.setToggle('x', true);
    state.collectValues();
    expect(state.warnings, isNotEmpty,
        reason: 'collision should produce a warning the first time');

    final freshState = AmeFormState();
    freshState.setInput('y', 'only-input');
    freshState.collectValues();
    expect(freshState.warnings, isEmpty,
        reason:
            'A non-colliding state must have no warnings after collect.');
  });

  /// Non-collision case: an input id and a toggle id with different
  /// names must not produce a warning. Guards against an over-eager
  /// regex/string-comparison fix that would flag every (input, toggle)
  /// pair as a collision.
  test('distinct ids do not produce collision warning', () {
    final state = AmeFormState();
    state.setInput('a', 'one');
    state.setToggle('b', true);
    state.collectValues();
    expect(state.warnings, isEmpty,
        reason: 'Distinct input/toggle ids must not warn.');
  });
}
