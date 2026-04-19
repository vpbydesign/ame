import 'package:ame_flutter_ui/ame_flutter_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// Audit regression tests — Flutter ChartMath unit tests.
///
/// Bug 28 (Flutter analog of v1.2 Bug 4) is split between two files:
///
/// 1. `audited_ui_bug_regression_test.dart` carries a source-structural
///    sentinel that always compiles and asserts the production
///    `ChartMath` class is declared with the four required methods.
/// 2. This file (`audited_chart_math_test.dart`) calls `ChartMath`
///    directly with the same assertion shape as Compose's
///    `AuditedBugRegressionTest` for `ChartMath`. Pre-Phase-E this file
///    fails to load because `ChartMath`/`ChartRange` do not exist yet —
///    that load-time failure IS the per-test pre-fix signal. Post-fix
///    every assertion passes.
///
/// See `specification/v1.0/regression-protocol.md` for the lifecycle rules.
/// See `ame-compose/.../AmeChartRenderer.kt::ChartMath` for the canonical
/// Kotlin implementation that this file mirrors verbatim.
void main() {
  // ════════════════════════════════════════════════════════════════════
  // Bug 28a — sign-aware bar geometry.
  // ════════════════════════════════════════════════════════════════════

  /// Audit Bug #28a: bar chart math previously divided by max with no
  /// sign awareness, so all-negative datasets either rendered upside-down
  /// or clamped to zero height. The fix's `ChartMath.computeRange` always
  /// includes zero as the baseline, and `computeBar(value, range)`
  /// returns sign-aware (yTop, height) pairs in chart-relative units.
  ///
  /// Spec section: specification/v1.0/primitives.md (Chart bar)
  /// Audit reference: AUDIT_VERDICTS.md#bug-28
  /// Pre-fix expected: FAIL — ChartMath does not exist.
  /// Post-fix expected: PASS — Range.dataMax = 0 for all-negative data;
  ///   computeBar returns positive height measured from baseline.
  test('bar chart math handles all negative values', () {
    final range = ChartMath.computeRange(const [-3.0, -1.0, -2.0]);
    expect(range.dataMin, lessThanOrEqualTo(-3.0),
        reason: 'dataMin must include the most negative value');
    expect(range.dataMax, equals(0.0),
        reason: 'dataMax must clamp to zero so baseline is visible');
    expect(range.range, greaterThan(0.0),
        reason: 'range span must never be zero');

    final (yTop, height) = ChartMath.computeBar(-3.0, range);
    expect(height, greaterThan(0.0),
        reason: 'BUG #28a: negative bar must have a positive height');
    expect(yTop, equals(range.baselineY),
        reason: 'BUG #28a: negative bar must hang FROM the baseline');
  });

  // ════════════════════════════════════════════════════════════════════
  // Bug 28b — line chart Y stays in [0, 1] for any input.
  // ════════════════════════════════════════════════════════════════════

  /// Audit Bug #28b: line chart math previously used only `globalMax`
  /// without `globalMin`, so a series of negative values would draw
  /// outside the canvas (negative Y). `ChartMath.computeLineY` returns
  /// Y in `[0, 1]` chart-relative units for any input given a Range
  /// produced by `computeRange` (which clamps min/max around zero).
  ///
  /// Spec section: specification/v1.0/primitives.md (Chart line)
  /// Audit reference: AUDIT_VERDICTS.md#bug-28
  /// Pre-fix expected: FAIL — ChartMath does not exist.
  /// Post-fix expected: PASS — y in [0, 1] for negative-only series.
  test('line chart Y stays in bounds for negative values', () {
    final range = ChartMath.computeRange(const [-5.0, -2.0, -3.0]);
    for (final v in [-5.0, -2.0, -3.0, 0.0]) {
      final y = ChartMath.computeLineY(v, range);
      expect(y, inInclusiveRange(0.0, 1.0),
          reason: 'BUG #28b: line Y must stay in [0, 1] chart-relative units '
              'for value $v; got $y');
    }
  });

  // ════════════════════════════════════════════════════════════════════
  // Bug 28d — multi-series shared X stride.
  // ════════════════════════════════════════════════════════════════════

  /// Audit Bug #28d: multi-series charts previously computed `stepX` per
  /// series, so index N of two unequal-length series rendered at
  /// different X coordinates. `ChartMath.computeSharedStepX` returns a
  /// stride keyed to the LONGEST series so identical indices align across
  /// series.
  ///
  /// Spec section: specification/v1.0/primitives.md (Chart line, multi-series)
  /// Audit reference: AUDIT_VERDICTS.md#bug-28
  /// Pre-fix expected: FAIL — ChartMath does not exist.
  /// Post-fix expected: PASS — single stepX value applies to every series.
  test('multi series X axis alignment', () {
    const width = 320.0;
    const horizontalPadding = 16.0;
    const maxPoints = 6;
    final stepX =
        ChartMath.computeSharedStepX(width, horizontalPadding, maxPoints);
    expect(stepX, greaterThan(0.0),
        reason: 'shared stepX must be a positive stride');
    final expected = (width - horizontalPadding * 2) / (maxPoints - 1);
    expect(stepX, closeTo(expected, 0.001),
        reason:
            'BUG #28d: shared stepX must be (width - 2*pad) / (maxPoints - 1) '
            'so identical indices align across series of different lengths.');

    // Single-point edge case: divisor must clamp to 1 to avoid div-by-zero.
    final stepXSingle =
        ChartMath.computeSharedStepX(width, horizontalPadding, 1);
    expect(stepXSingle, greaterThan(0.0),
        reason: 'maxPoints=1 must still produce a positive stepX, '
            'not divide by zero.');
  });

  // ════════════════════════════════════════════════════════════════════
  // Bug 28 Q4 invariant — mixed-sign Range always brackets zero.
  // ════════════════════════════════════════════════════════════════════

  /// Audit Bug #28 Q4 hardening (mirrors Compose WP#5 permanent guard):
  /// for a mixed-sign dataset, the Range must always include 0 within
  /// `[dataMin, dataMax]` so the baseline is always visible. This
  /// permanent invariant prevents future regressions that would optimize
  /// the range to skip zero for mixed-sign data.
  ///
  /// Spec section: specification/v1.0/primitives.md (Chart, mixed-sign data)
  /// Audit reference: AUDIT_VERDICTS.md#bug-28
  /// Pre-fix expected: FAIL — ChartMath does not exist.
  /// Post-fix expected: PASS — for any mixed-sign data, dataMin <= 0 <= dataMax.
  test('chart math range includes zero for mixed sign', () {
    for (final data in <List<double>>[
      const [1.0, -1.0],
      const [-3.0, 2.0, -1.0, 4.0],
      const [10.0, 20.0, -5.0],
    ]) {
      final range = ChartMath.computeRange(data);
      expect(range.dataMin, lessThanOrEqualTo(0.0),
          reason: 'BUG #28 Q4 invariant: mixed-sign dataMin must be <= 0; '
              'data: $data, range: $range');
      expect(range.dataMax, greaterThanOrEqualTo(0.0),
          reason: 'BUG #28 Q4 invariant: mixed-sign dataMax must be >= 0; '
              'data: $data, range: $range');
    }
  });

  // ════════════════════════════════════════════════════════════════════
  // ChartMath.computeRange edge case — empty input.
  // ════════════════════════════════════════════════════════════════════

  /// Empty data must return an inert range with non-zero span (safe
  /// divisor) so callers can short-circuit safely. Mirrors Compose
  /// `ChartMath.computeRange` empty-list handling.
  test('computeRange tolerates empty input', () {
    final range = ChartMath.computeRange(const []);
    expect(range.dataMin, equals(0.0));
    expect(range.dataMax, equals(0.0));
    expect(range.range, equals(1.0),
        reason: 'span must be non-zero for safe divisor reuse');
  });
}
