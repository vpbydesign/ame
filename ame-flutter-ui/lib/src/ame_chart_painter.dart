import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart';
import 'package:ame_flutter/ame_flutter.dart';
import 'ame_theme.dart';

/// Pluggable chart rendering interface. Host apps can provide a custom
/// implementation (e.g., wrapping fl_chart or a custom library).
abstract class AmeChartRenderer {
  const AmeChartRenderer();
  Widget renderChart(BuildContext context, AmeChart chart);
}

/// Zero-dependency chart renderer using Flutter [CustomPaint].
/// Supports bar, line, pie, and sparkline chart types.
/// Static rendering only — no touch interactions or animations.
class CanvasChartRenderer extends AmeChartRenderer {
  const CanvasChartRenderer();

  @override
  Widget renderChart(BuildContext context, AmeChart chart) {
    final data = chart.values ?? const [];

    // Empty-state handling. The first branch covers the case where there is
    // no data at all (bar/pie/sparkline included). The second branch is
    // line-specific: a line chart
    // whose every series has fewer than two points cannot render a stroke,
    // so the documented empty state replaces the silent no-op that the
    // pre-fix painter produced.
    final allSeriesForCheck = (chart.series != null && chart.series!.isNotEmpty)
        ? chart.series!
        : (data.isNotEmpty ? [data] : <List<double>>[]);
    if (allSeriesForCheck.isEmpty) {
      return _emptyState(context);
    }
    if (chart.type == ChartType.line &&
        allSeriesForCheck.every((s) => s.length < 2)) {
      return _emptyState(context);
    }

    final chartColor = chart.color != null
        ? AmeTheme.semanticColor(context, chart.color!)
        : Theme.of(context).colorScheme.primary;
    final labelStyle = Theme.of(context).textTheme.labelSmall ?? const TextStyle(fontSize: 10);

    return SizedBox(
      width: double.infinity,
      height: chart.height.toDouble(),
      child: _buildChart(chart, data, chartColor, labelStyle),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        'No chart data',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }

  Widget _buildChart(
      AmeChart chart, List<double> data, Color color, TextStyle labelStyle) {
    return switch (chart.type) {
      ChartType.bar => CustomPaint(
          painter: _BarChartPainter(data, chart.labels, color, labelStyle),
        ),
      ChartType.line => CustomPaint(
          painter: _LineChartPainter(
              data, chart.series, chart.labels, color, labelStyle),
        ),
      ChartType.pie => CustomPaint(
          painter: _PieChartPainter(data, chart.labels, color, labelStyle),
        ),
      ChartType.sparkline => CustomPaint(
          painter: _SparklinePainter(data, color),
        ),
    };
  }
}

const _multiSeriesAlphas = [1.0, 0.75, 0.55, 0.4, 0.3];

// ── ChartMath (extracted for direct unit testing) ──────────────────────────

/// Sign-aware data range computed by [ChartMath.computeRange]. Bounds are
/// clamped so the baseline at value=0 is always present in chart-relative
/// space, even for all-positive or all-negative datasets.
///
/// Coordinate convention matches Flutter Canvas: y=0 at the top, y=1 at the
/// bottom, in chart-relative units.
@visibleForTesting
class ChartRange {
  /// Lower bound of the data extent, clamped to <= 0.
  final double dataMin;

  /// Upper bound of the data extent, clamped to >= 0.
  final double dataMax;

  /// `dataMax - dataMin`, never zero.
  final double range;

  /// Y position of value=0 in chart-relative units (0=top, 1=bottom).
  /// All-positive data produces 1.0, all-negative produces 0.0; mixed-sign
  /// sits between.
  final double baselineY;

  const ChartRange({
    required this.dataMin,
    required this.dataMax,
    required this.range,
    required this.baselineY,
  });

  @override
  String toString() =>
      'ChartRange(dataMin: $dataMin, dataMax: $dataMax, '
      'range: $range, baselineY: $baselineY)';
}

/// Pure chart math utilities, lifted out of the painter layer so tests can
/// call production code directly instead of mirroring formulas.
///
/// Guarantees that charts with a mix of positive and negative values draw
/// against a visible baseline at value=0, that line charts with fewer than
/// two points per series produce the documented empty state at the renderer
/// level, and that multi-series charts share an X stride so the same index
/// of every series falls at the same x coordinate.
@visibleForTesting
class ChartMath {
  ChartMath._();

  /// Returns a sign-aware [ChartRange] that always includes 0 as the
  /// baseline. Empty input returns an inert range with baselineY at the
  /// bottom (1.0) so callers can short-circuit safely.
  static ChartRange computeRange(List<double> data) {
    if (data.isEmpty) {
      return const ChartRange(
        dataMin: 0.0,
        dataMax: 0.0,
        range: 1.0,
        baselineY: 1.0,
      );
    }
    final rawMin = data.reduce(math.min);
    final rawMax = data.reduce(math.max);
    final dataMin = math.min(rawMin, 0.0);
    final dataMax = math.max(rawMax, 0.0);
    final span = math.max(dataMax - dataMin, 1e-9);
    final baselineY = dataMax / span;
    return ChartRange(
      dataMin: dataMin,
      dataMax: dataMax,
      range: span,
      baselineY: baselineY,
    );
  }

  /// Returns `(yTop, height)` for a sign-aware bar in chart-relative
  /// units. Positive values rise from the baseline upward; negative
  /// values hang below the baseline.
  static (double, double) computeBar(double value, ChartRange range) {
    final valueY = (range.dataMax - value) / range.range;
    if (value >= 0.0) {
      return (valueY, range.baselineY - valueY);
    } else {
      return (range.baselineY, valueY - range.baselineY);
    }
  }

  /// Returns Y position (0..1, 0=top) for a line-chart point.
  static double computeLineY(double value, ChartRange range) {
    return (range.dataMax - value) / range.range;
  }

  /// Shared X stride for multi-series charts. Using the LONGEST series'
  /// length means index N of any series falls at the same X coordinate,
  /// even when series lengths differ.
  static double computeSharedStepX(
    double width,
    double horizontalPadding,
    int maxPoints,
  ) {
    final divisor = math.max(maxPoints - 1, 1);
    return (width - horizontalPadding * 2) / divisor;
  }
}

// ── Bar Chart ──────────────────────────────────────────────────────────────

class _BarChartPainter extends CustomPainter {
  final List<double> data;
  final List<String>? labels;
  final Color color;
  final TextStyle labelStyle;

  _BarChartPainter(this.data, this.labels, this.color, this.labelStyle);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final range = ChartMath.computeRange(data);
    final labelTexts = labels ?? const [];

    final bottomPadding = labelTexts.isNotEmpty ? 20.0 : 4.0;
    final chartHeight = size.height - bottomPadding;
    const barSpacing = 8.0;
    final totalSpacing = barSpacing * (data.length + 1);
    final barWidth =
        ((size.width - totalSpacing) / data.length).clamp(4.0, double.infinity);

    _drawGridLines(canvas, chartHeight, size.width, color.withOpacity(0.1));

    final barPaint = Paint()..color = color;

    for (var i = 0; i < data.length; i++) {
      // ChartMath.computeBar produces sign-aware (yTop, height)
      // in chart-relative units; multiplying by chartHeight maps it into
      // pixel space. Positive bars rise from the baseline, negative bars
      // hang from it. Minimum visible height of 2.0px preserves the
      // pre-fix "always something to look at" affordance for tiny values.
      final (relYTop, relHeight) = ChartMath.computeBar(data[i], range);
      final pixelHeight = (relHeight * chartHeight).clamp(2.0, chartHeight);
      final pixelTop = relYTop * chartHeight;
      final x = barSpacing + i * (barWidth + barSpacing);

      canvas.drawRect(
        Rect.fromLTWH(x, pixelTop, barWidth, pixelHeight),
        barPaint,
      );

      if (i < labelTexts.length) {
        _drawLabel(canvas, labelTexts[i], labelStyle,
            x + barWidth / 2, chartHeight + 4, barWidth);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter old) =>
      data != old.data || labels != old.labels || color != old.color;
}

// ── Line Chart ─────────────────────────────────────────────────────────────

class _LineChartPainter extends CustomPainter {
  final List<double> data;
  final List<List<double>>? series;
  final List<String>? labels;
  final Color color;
  final TextStyle labelStyle;

  _LineChartPainter(
      this.data, this.series, this.labels, this.color, this.labelStyle);

  @override
  void paint(Canvas canvas, Size size) {
    // The renderer's empty-state branch handles the
    // "no series with >= 2 points" case before the painter is invoked, so
    // here we may safely assume at least one series with >= 2 points
    // exists. The defensive empty checks below are belt-and-braces in
    // case a host wires the painter directly.
    final allSeries = (series != null && series!.isNotEmpty)
        ? series!
        : (data.isNotEmpty ? [data] : <List<double>>[]);
    if (allSeries.isEmpty) return;

    final allValues = allSeries.expand((s) => s).toList();
    if (allValues.isEmpty) return;

    // A single ChartRange spans the union of all series so negative-only
    // data stays in [0, chartHeight] and ChartMath returns Y in
    // chart-relative units. A shared stepX keyed to the longest series
    // guarantees that index N of every series lands at the same X coordinate.
    final range = ChartMath.computeRange(allValues);
    final maxPoints = allSeries.map((s) => s.length).reduce(math.max);
    final labelTexts = labels ?? const [];

    final bottomPadding = labelTexts.isNotEmpty ? 20.0 : 4.0;
    final chartHeight = size.height - bottomPadding;
    const horizontalPadding = 16.0;
    final stepX = ChartMath.computeSharedStepX(
        size.width, horizontalPadding, maxPoints);

    _drawGridLines(canvas, chartHeight, size.width, color.withOpacity(0.1));

    for (var seriesIdx = 0; seriesIdx < allSeries.length; seriesIdx++) {
      final seriesData = allSeries[seriesIdx];
      if (seriesData.length < 2) continue;

      final alpha = seriesIdx < _multiSeriesAlphas.length
          ? _multiSeriesAlphas[seriesIdx]
          : 0.3;
      final seriesColor = color.withOpacity(alpha);

      final path = Path();
      for (var i = 0; i < seriesData.length; i++) {
        final x = horizontalPadding + i * stepX;
        final y = ChartMath.computeLineY(seriesData[i], range) * chartHeight;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = seriesColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );

      final dotPaint = Paint()..color = seriesColor;
      for (var i = 0; i < seriesData.length; i++) {
        final x = horizontalPadding + i * stepX;
        final y = ChartMath.computeLineY(seriesData[i], range) * chartHeight;
        canvas.drawCircle(Offset(x, y), 3, dotPaint);
      }
    }

    if (labelTexts.isNotEmpty && maxPoints > 0) {
      for (var i = 0; i < labelTexts.length && i < maxPoints; i++) {
        final x = horizontalPadding + i * stepX;
        _drawLabel(canvas, labelTexts[i], labelStyle, x, chartHeight + 4, stepX);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) =>
      data != old.data ||
      series != old.series ||
      labels != old.labels ||
      color != old.color;
}

// ── Pie Chart ──────────────────────────────────────────────────────────────

class _PieChartPainter extends CustomPainter {
  final List<double> data;
  final List<String>? labels;
  final Color color;
  final TextStyle labelStyle;

  _PieChartPainter(this.data, this.labels, this.color, this.labelStyle);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final total = data.fold(0.0, (a, b) => a + b).clamp(1.0, double.infinity);

    final diameter = math.min(size.width, size.height) * 0.8;
    final radius = diameter / 2;
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final rect = Rect.fromCenter(
        center: Offset(centerX, centerY), width: diameter, height: diameter);

    var startAngle = -math.pi / 2;
    final labelTexts = labels ?? const [];

    for (var i = 0; i < data.length; i++) {
      final sweep = data[i] / total * 2 * math.pi;
      final alpha = _multiSeriesAlphas[i % _multiSeriesAlphas.length];
      final segmentColor = color.withOpacity(alpha);

      canvas.drawArc(
        rect,
        startAngle,
        sweep,
        true,
        Paint()..color = segmentColor,
      );

      final sweepDegrees = data[i] / total * 360;
      if (i < labelTexts.length && sweepDegrees > 15) {
        final midAngle = startAngle + sweep / 2;
        final labelRadius = radius * 0.65;
        final lx = centerX + labelRadius * math.cos(midAngle);
        final ly = centerY + labelRadius * math.sin(midAngle);
        _drawLabel(canvas, labelTexts[i], labelStyle, lx, ly - 6,
            radius * 0.6);
      }

      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter old) =>
      data != old.data || labels != old.labels || color != old.color;
}

// ── Sparkline Chart ────────────────────────────────────────────────────────

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _SparklinePainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final maxVal = data.reduce(math.max).clamp(1.0, double.infinity);
    final minVal = data.reduce(math.min);
    final range = (maxVal - minVal).clamp(1.0, double.infinity);

    const padding = 2.0;
    final chartWidth = size.width - padding * 2;
    final chartHeight = size.height - padding * 2;
    final stepX = chartWidth / (data.length - 1).clamp(1, data.length);

    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final x = padding + i * stepX;
      final y = padding + chartHeight - ((data[i] - minVal) / range * chartHeight);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      data != old.data || color != old.color;
}

// ── Shared Utilities ───────────────────────────────────────────────────────

void _drawGridLines(Canvas canvas, double chartHeight, double chartWidth, Color color) {
  final paint = Paint()
    ..color = color
    ..strokeWidth = 1;
  for (var i = 0; i <= 3; i++) {
    final y = chartHeight * i / 4;
    canvas.drawLine(Offset(0, y), Offset(chartWidth, y), paint);
  }
}

void _drawLabel(Canvas canvas, String text, TextStyle style, double centerX,
    double top, double maxWidth) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: ui.TextDirection.ltr,
    maxLines: 1,
    ellipsis: '\u2026',
  );
  painter.layout(maxWidth: maxWidth.clamp(1, double.infinity));
  painter.paint(canvas, Offset(centerX - painter.width / 2, top));
}
