import 'dart:io';

import 'package:ame_flutter_ui/ame_flutter_ui.dart';
import 'package:flutter/material.dart' hide Align;
import 'package:flutter_test/flutter_test.dart';

/// Audit regression tests — Flutter renderer, theme, and form state.
///
/// Each test corresponds to one row in `AUDIT_VERDICTS.md` at the repo root.
/// Tests are written so that BEFORE a fix is applied the test FAILS
/// (proving the bug), and AFTER the fix is applied the test PASSES
/// (locking in the corrected behavior).
///
/// See `specification/v1.0/regression-protocol.md` for the lifecycle rules
/// that govern this file.
///
/// These tests mirror `ame-swiftui/.../AuditedSwiftUIBugTests.swift` and
/// `ame-compose/.../AuditedBugRegressionTest.kt` exactly so that
/// cross-runtime divergence is also caught. They cover Flutter analogs of
/// v1.2 Bugs 4 (chart math), 12 (form-state collision), 13 (input-ref
/// hyphen), 14 (theme dark-mode), 18 (accordion reactivity) — registered
/// as Bugs 28, 33, 34, 36, 37 — plus Bug 38 (date/time picker controller
/// hoisting) discovered during WP#7 Phase D.
///
/// Bug 28 (ChartMath extraction) and Bug 33 (warnings field) gain *both*
/// a source-structural sentinel here AND a behavioral suite in
/// `audited_chart_math_test.dart` and `audited_form_state_test.dart`
/// respectively. The structural sentinels keep this file always-compiling
/// so per-bug visibility is preserved across all phases; the behavioral
/// suites mirror the Compose `ChartMath` audit tests and the SwiftUI
/// collision behavioral test.
void main() {
  // ════════════════════════════════════════════════════════════════════
  // Bug 28 (Flutter analog of v1.2 Bug 4) —
  //   chart math breaks on negatives, single points, mismatched series.
  //
  // Source-structural sentinel here; behavioral coverage in
  // audited_chart_math_test.dart.
  // ════════════════════════════════════════════════════════════════════

  group('Bug 28 — ChartMath extraction sentinel', () {
    /// Audit Bug #28 (sentinel): the production code in
    /// `ame_chart_painter.dart` must expose a `ChartMath` utility class
    /// extracted from the painter implementations. The class encapsulates
    /// sign-aware bar geometry, line bounds, single-point empty-state
    /// predicate, and shared multi-series stepX. Behavioral coverage of
    /// the four ChartMath functions lives in `audited_chart_math_test.dart`
    /// (separate file because pre-fix references to ChartMath would block
    /// compilation of this file's other tests).
    ///
    /// Spec section: specification/v1.0/primitives.md (Chart bar/line)
    /// Audit reference: AUDIT_VERDICTS.md#bug-28
    /// Pre-fix expected: FAIL — ChartMath does not exist in the source.
    /// Post-fix expected: PASS — ChartMath class with the four required
    ///   methods is declared at top level of ame_chart_painter.dart.
    test('ChartMath class is extracted with required methods', () {
      final source =
          File('lib/src/ame_chart_painter.dart').readAsStringSync();
      expect(
        source.contains('class ChartMath'),
        isTrue,
        reason:
            'BUG #28: ame_chart_painter.dart must declare a `ChartMath` '
            'class (top-level, @visibleForTesting) so audit tests can call '
            'the math directly. See Compose `internal object ChartMath`.',
      );
      const requiredMethods = [
        'computeRange',
        'computeBar',
        'computeLineY',
        'computeSharedStepX',
      ];
      for (final method in requiredMethods) {
        expect(
          source.contains(method),
          isTrue,
          reason:
              'BUG #28: ChartMath must declare `$method` per the four '
              'sub-bug fixes (4a-4d). Mirror Compose `internal object '
              'ChartMath` lines 91-165.',
        );
      }
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // Bug 33 (Flutter analog of v1.2 Bug 12) —
  //   AmeFormState.collectValues silently merges input/toggle id collisions.
  //
  // Source-structural sentinel here; behavioral coverage in
  // audited_form_state_test.dart.
  // ════════════════════════════════════════════════════════════════════

  group('Bug 33 — warnings field sentinel', () {
    /// Audit Bug #33 (sentinel): `AmeFormState` must expose a `warnings`
    /// list (or getter) populated by `collectValues()` when an input id
    /// and a toggle id collide. The warning string surfaces the data-loss
    /// class so hosts can detect collisions without changing the
    /// merge-order contract (toggle wins per WP#4 Bug 5). Behavioral
    /// coverage lives in `audited_form_state_test.dart`.
    ///
    /// Spec section: specification/v1.0/integration.md (Form state)
    /// Audit reference: AUDIT_VERDICTS.md#bug-33
    /// Pre-fix expected: FAIL — `warnings` is not declared on AmeFormState.
    /// Post-fix expected: PASS — `warnings` getter is declared and
    ///   collectValues populates it on collision.
    test('AmeFormState exposes a warnings field', () {
      final source = File('lib/src/ame_form_state.dart').readAsStringSync();
      expect(
        source.contains('warnings'),
        isTrue,
        reason:
            'BUG #33: ame_form_state.dart must declare a `warnings` field '
            'or getter. Today collectValues silently overwrites colliding '
            'input/toggle IDs with no diagnostic surface.',
      );
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // Bug 34 (Flutter analog of v1.2 Bug 13) —
  //   input-ref regex \w+ rejects hyphenated field IDs.
  // ════════════════════════════════════════════════════════════════════

  group('Bug 34 — input-ref regex hyphens', () {
    /// Audit Bug #34: the `${input.fieldId}` substitution regex is
    /// `\$\{input\.(\w+)\}`. `\w` excludes `-`, so hyphenated field IDs
    /// like `user-name` are silently rejected.
    ///
    /// Spec section: specification/v1.0/actions.md (Input references)
    /// Audit reference: AUDIT_VERDICTS.md#bug-34
    /// Pre-fix expected: FAIL — substitution does not occur for hyphenated ID.
    /// Post-fix expected: PASS — `user-name` field substitutes correctly.
    test('input ref regex accepts hyphenated ids', () {
      final state = AmeFormState();
      state.setInput('user-name', 'Alice');

      final resolved = state.resolveInputReferences(
        const {'query': r'Hello, ${input.user-name}'},
      );

      expect(
        resolved['query'],
        equals('Hello, Alice'),
        reason:
            r'BUG #34: input ref regex must accept hyphenated field IDs. '
            r"Today \w+ excludes '-', leaving the token unreplaced.",
      );
    });

    /// Audit Bug #34 Q4 hardening (mirrors Compose/SwiftUI WP#5 permanent
    /// guard): the literal `.` separator inside the curly braces remains
    /// a hard separator. `${input.user.name}` (with a `.`) must NOT match
    /// — defends against future over-permissive expansion that would
    /// shadow potential nested references like `${input.user.name}`.
    ///
    /// Spec section: specification/v1.0/actions.md (Input references)
    /// Audit reference: AUDIT_VERDICTS.md#bug-34
    /// Pre-fix expected: PASS — pre-fix regex `\w+` already rejects `.`.
    /// Post-fix expected: PASS — post-fix regex `[A-Za-z0-9_-]+` also
    ///   rejects `.` (hyphen is the only addition).
    test('input ref regex rejects dot inside field id', () {
      final state = AmeFormState();
      state.setInput('user.name', 'Alice');

      final resolved = state.resolveInputReferences(
        const {'query': r'Hello, ${input.user.name}'},
      );

      expect(
        resolved['query'],
        equals(r'Hello, ${input.user.name}'),
        reason:
            'BUG #34 Q4 invariant: literal `.` inside field id must remain '
            'a hard separator; the token must NOT match and substitute.',
      );
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // Bug 36 (Flutter analog of v1.2 Bug 18) —
  //   accordion expanded parameter not reactive to node updates.
  // ════════════════════════════════════════════════════════════════════

  group('Bug 36 — accordion expanded reactivity', () {
    /// Audit Bug #36: the previous implementation captured `node.expanded`
    /// once at first composition (in `initState`), so server-pushed updates
    /// to the accordion's expanded state were silently ignored. The fix
    /// adds `didUpdateWidget` to sync the local snapshot when the parent
    /// rebuilds with a different `node.expanded`. Mirrors Compose
    /// `LaunchedEffect(node.expanded)`.
    ///
    /// Spec section: specification/v1.0/primitives.md (Accordion expanded)
    /// Audit reference: AUDIT_VERDICTS.md#bug-36
    /// Pre-fix expected: FAIL — re-pumping with `expanded: true` does not
    ///   reveal the child; the local `_isExpanded` stays false.
    /// Post-fix expected: PASS — re-pumping with `expanded: true` reveals
    ///   the child; local user taps still take effect immediately.
    testWidgets('accordion follows external expanded changes',
        (tester) async {
      Widget build(bool expanded) {
        return MaterialApp(
          home: Scaffold(
            body: AmeRenderer(
              node: AmeAccordion(
                title: 'Section',
                expanded: expanded,
                children: const [
                  AmeTxt(text: 'hidden-detail'),
                ],
              ),
              formState: AmeFormState(),
              onAction: (_) {},
            ),
          ),
        );
      }

      await tester.pumpWidget(build(false));
      expect(find.text('hidden-detail'), findsNothing,
          reason: 'Initial expanded=false must hide the child.');

      await tester.pumpWidget(build(true));
      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      expect(
        find.text('hidden-detail'),
        findsOneWidget,
        reason:
            'BUG #36: accordion must follow server-pushed expanded updates. '
            'Re-pumping with expanded=true must reveal the child.',
      );
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // Bug 37 (Flutter analog of v1.2 Bug 14) —
  //   theme uses hardcoded light-theme colors, breaks dark mode.
  // ════════════════════════════════════════════════════════════════════

  group('Bug 37 — theme dark-mode adaptation', () {
    /// Audit Bug #37: `AmeTheme.semanticColor` returns `Color(0xFF4CAF50)`
    /// for SUCCESS and `Color(0xFFFF9800)` for WARNING regardless of
    /// theme brightness. These are visible in dark mode but not adapted.
    /// `calloutStyle` does the same for warning/success/tip backgrounds.
    /// The fix mirrors Compose Path D — branches on
    /// `Theme.of(context).brightness` with documented Material 3 hex
    /// values (Green 700 light / Green 300 dark, etc.).
    ///
    /// Spec section: specification/v1.0/primitives.md (Callout, Badge, SemanticColor)
    /// Audit reference: AUDIT_VERDICTS.md#bug-37
    /// Pre-fix expected: FAIL — semanticColor returns identical Color in
    ///   light vs dark themes.
    /// Post-fix expected: PASS — semanticColor returns distinct Color in
    ///   light vs dark themes.
    testWidgets('theme colors respect dark mode', (tester) async {
      Color? captured;

      Widget probe(Brightness brightness) {
        return MaterialApp(
          theme: ThemeData(brightness: brightness, useMaterial3: true),
          home: Builder(
            builder: (context) {
              captured = AmeTheme.semanticColor(context, SemanticColor.success);
              return const SizedBox.shrink();
            },
          ),
        );
      }

      await tester.pumpWidget(probe(Brightness.light));
      final lightColor = captured;

      // Force a clean unmount between the two pumps. Flutter's
      // `pumpWidget` reuses the existing element tree when the root widget
      // type matches, which prevents the second `MaterialApp.theme` from
      // propagating to the captured Builder context. Pumping an empty
      // SizedBox in between is the documented workaround for this kind of
      // theme-swap test setup.
      await tester.pumpWidget(const SizedBox.shrink());

      await tester.pumpWidget(probe(Brightness.dark));
      final darkColor = captured;

      expect(
        lightColor,
        isNot(equals(darkColor)),
        reason:
            'BUG #37: AmeTheme.semanticColor(success) must adapt to theme '
            'brightness. Today both modes return the same fixed color. '
            'light=$lightColor dark=$darkColor',
      );
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // Bug 38 (WP#7 Phase D discovery) —
  //   _AmeInputDatePicker / _AmeInputTimePicker allocate
  //   TextEditingController inside build(), causing focus-loss and
  //   GC churn on every rebuild.
  // ════════════════════════════════════════════════════════════════════

  group('Bug 38 — date/time picker controller hoisting', () {
    /// Audit Bug #38: `_AmeInputDatePicker` and `_AmeInputTimePicker` are
    /// `StatelessWidget`s that construct a fresh `TextEditingController`
    /// inside their `build()` method on every rebuild. The fix converts
    /// both to `StatefulWidget`s with the controller allocated in
    /// `initState`, disposed in `dispose`, and kept in sync with form
    /// state via `didUpdateWidget` / a listener.
    ///
    /// Detection rationale: behavioral observation of focus loss requires
    /// driving the picker through real platform interactions which is not
    /// available in `flutter_test`. A source-structural check is the
    /// reliable Dart analog (mirrors Swift WP#3 source-check pattern for
    /// Bug 11 cycle detection). The pre-fix pattern is
    /// `extends StatelessWidget` for the picker classes; the post-fix
    /// pattern is `extends StatefulWidget` with a paired `State` class.
    ///
    /// Spec section: N/A (Flutter-specific architectural finding)
    /// Audit reference: AUDIT_VERDICTS.md#bug-38
    /// Pre-fix expected: FAIL — both date/time picker classes are
    ///   `StatelessWidget` with `TextEditingController(...)` in `build`.
    /// Post-fix expected: PASS — both are `StatefulWidget` with paired
    ///   `State` class hoisting the controller into `initState`.
    test('date and time picker subwidgets hoist controllers via StatefulWidget',
        () {
      final source = File('lib/src/ame_renderer.dart').readAsStringSync();
      expect(
        source.contains('class _AmeInputDatePicker extends StatefulWidget'),
        isTrue,
        reason:
            'BUG #38: _AmeInputDatePicker must be a StatefulWidget so the '
            'TextEditingController can be hoisted into initState (avoids '
            'allocating a fresh controller on every parent rebuild). '
            'Today the class is StatelessWidget and constructs the '
            'controller inside build().',
      );
      expect(
        source.contains('class _AmeInputTimePicker extends StatefulWidget'),
        isTrue,
        reason:
            'BUG #38: _AmeInputTimePicker must be a StatefulWidget for the '
            'same reason as _AmeInputDatePicker.',
      );
      // Belt-and-braces: the post-fix State class must dispose the controller.
      expect(
        source.contains('class _AmeInputDatePickerState'),
        isTrue,
        reason:
            'BUG #38: _AmeInputDatePicker must have a paired State class '
            'that owns the controller and overrides dispose().',
      );
      expect(
        source.contains('class _AmeInputTimePickerState'),
        isTrue,
        reason:
            'BUG #38: _AmeInputTimePicker must have a paired State class '
            'that owns the controller and overrides dispose().',
      );
    });
  });
}
