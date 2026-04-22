package com.agenticmobile.ame.compose

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.agenticmobile.ame.AmeNode
import com.agenticmobile.ame.ChartType

/**
 * Pluggable chart rendering interface. Host apps can provide a custom
 * implementation (e.g. wrapping Vico, MPAndroidChart, or a custom library)
 * via [LocalAmeChartRenderer].
 */
fun interface AmeChartRenderer {
    @Composable
    fun RenderChart(chart: AmeNode.Chart, modifier: Modifier)
}

/**
 * CompositionLocal for chart renderer injection. Defaults to [CanvasChartRenderer].
 *
 * Usage:
 * ```
 * CompositionLocalProvider(LocalAmeChartRenderer provides MyChartRenderer()) {
 *     AmeRenderer(node, ...)
 * }
 * ```
 */
val LocalAmeChartRenderer = staticCompositionLocalOf<AmeChartRenderer> {
    CanvasChartRenderer()
}

/**
 * Zero-dependency chart renderer using Compose Canvas.
 * Supports bar, line, pie, and sparkline chart types.
 * Static rendering only — no touch interactions or animations.
 */
class CanvasChartRenderer : AmeChartRenderer {

    @Composable
    override fun RenderChart(chart: AmeNode.Chart, modifier: Modifier) {
        val data = chart.values ?: emptyList()
        if (data.isEmpty() && chart.series.isNullOrEmpty()) {
            Text(
                text = "No chart data",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = modifier.padding(16.dp)
            )
            return
        }

        val chartColor = chart.color?.let { AmeTheme.semanticColor(it) }
            ?: MaterialTheme.colorScheme.primary
        val textMeasurer = rememberTextMeasurer()
        val labelStyle = MaterialTheme.typography.labelSmall

        val chartModifier = modifier
            .fillMaxWidth()
            .height(chart.height.dp)

        when (chart.type) {
            ChartType.BAR -> BarChart(data, chart.labels, chartColor, textMeasurer, labelStyle, chartModifier)
            ChartType.LINE -> LineChart(data, chart.series, chart.labels, chartColor, textMeasurer, labelStyle, chartModifier)
            ChartType.PIE -> PieChart(data, chart.labels, chartColor, textMeasurer, labelStyle, chartModifier)
            ChartType.SPARKLINE -> SparklineChart(data, chartColor, chartModifier)
        }
    }
}

private val MULTI_SERIES_ALPHAS = floatArrayOf(1.0f, 0.75f, 0.55f, 0.4f, 0.3f)

// ── Chart Math (extracted for direct unit testing) ─────────────────────────

/**
 * Pure chart math utilities, lifted out of the @Composable layer so tests
 * can call production code directly. Coordinate convention: y=0 at the top,
 * y=1 at the bottom, in chart-relative units.
 *
 * Guarantees that charts with a mix of positive and negative values draw
 * against a visible baseline at value=0, and that multi-series charts share
 * an X stride so the same index of every series falls at the same x coordinate.
 */
internal object ChartMath {

    /**
     * Sign-aware data range. The bounds are clamped so the baseline at
     * value=0 is always present in chart-relative space, even for
     * all-positive or all-negative data sets.
     *
     * @property dataMin Lower bound of the data extent, clamped to <= 0.
     * @property dataMax Upper bound of the data extent, clamped to >= 0.
     * @property range dataMax - dataMin, never zero.
     * @property baselineY Y position of value=0 in chart-relative units
     *   (0=top, 1=bottom). All-positive data => 1.0; all-negative => 0.0;
     *   mixed-sign sits between.
     */
    data class Range(
        val dataMin: Double,
        val dataMax: Double,
        val range: Double,
        val baselineY: Float,
    )

    /** Returns a sign-aware [Range] that always includes 0 as the baseline. */
    fun computeRange(data: List<Double>): Range {
        if (data.isEmpty()) {
            return Range(0.0, 0.0, 1.0, 1f)
        }
        val dataMin = data.min().coerceAtMost(0.0)
        val dataMax = data.max().coerceAtLeast(0.0)
        val span = (dataMax - dataMin).coerceAtLeast(1e-9)
        val baselineY = (dataMax / span).toFloat()
        return Range(dataMin, dataMax, span, baselineY)
    }

    /**
     * Returns (yTop, height) for a sign-aware bar in chart-relative units.
     * Positive values rise from the baseline upward; negative values hang
     * below the baseline.
     */
    fun computeBar(value: Double, range: Range): Pair<Float, Float> {
        val valueY = ((range.dataMax - value) / range.range).toFloat()
        return if (value >= 0.0) {
            Pair(valueY, range.baselineY - valueY)
        } else {
            Pair(range.baselineY, valueY - range.baselineY)
        }
    }

    /** Returns Y position (0..1, 0=top) for a line-chart point. */
    fun computeLineY(value: Double, range: Range): Float {
        return ((range.dataMax - value) / range.range).toFloat()
    }

    /**
     * Shared X stride for multi-series charts. Using the LONGEST series'
     * length means index N of any series falls at the same X coordinate,
     * even when series lengths differ.
     */
    fun computeSharedStepX(width: Float, horizontalPadding: Float, maxPoints: Int): Float {
        val divisor = (maxPoints - 1).coerceAtLeast(1)
        return (width - horizontalPadding * 2) / divisor
    }
}

// ── Bar Chart ──────────────────────────────────────────────────────────────

@Composable
private fun BarChart(
    data: List<Double>,
    labels: List<String>?,
    color: Color,
    textMeasurer: TextMeasurer,
    labelStyle: TextStyle,
    modifier: Modifier,
) {
    if (data.isEmpty()) return
    val range = ChartMath.computeRange(data)
    val labelTexts = labels ?: emptyList()

    Canvas(modifier = modifier) {
        val bottomPadding = if (labelTexts.isNotEmpty()) 20f else 4f
        val chartHeight = size.height - bottomPadding
        val barSpacing = 8.dp.toPx()
        val totalSpacing = barSpacing * (data.size + 1)
        val barWidth = ((size.width - totalSpacing) / data.size).coerceAtLeast(4f)

        drawGridLines(chartHeight, size.width, color.copy(alpha = 0.1f))

        data.forEachIndexed { index, value ->
            val (yTopFrac, heightFrac) = ChartMath.computeBar(value, range)
            val y = yTopFrac * chartHeight
            val barHeight = (heightFrac * chartHeight).coerceAtLeast(2f)
            val x = barSpacing + index * (barWidth + barSpacing)

            drawRect(
                color = color,
                topLeft = Offset(x, y),
                size = Size(barWidth, barHeight)
            )

            if (index < labelTexts.size) {
                val labelResult = textMeasurer.measure(
                    text = labelTexts[index],
                    style = labelStyle,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    constraints = androidx.compose.ui.unit.Constraints(maxWidth = barWidth.toInt().coerceAtLeast(1))
                )
                drawText(
                    textLayoutResult = labelResult,
                    topLeft = Offset(
                        x + (barWidth - labelResult.size.width) / 2f,
                        chartHeight + 4f
                    )
                )
            }
        }
    }
}

// ── Line Chart ─────────────────────────────────────────────────────────────

@Composable
private fun LineChart(
    data: List<Double>,
    series: List<List<Double>>?,
    labels: List<String>?,
    color: Color,
    textMeasurer: TextMeasurer,
    labelStyle: TextStyle,
    modifier: Modifier,
) {
    val allSeries = if (!series.isNullOrEmpty()) series else if (data.isNotEmpty()) listOf(data) else return

    // A line chart needs at least one series with >= 2 points to
    // draw anything meaningful. If every series is too short (e.g. a single
    // point), render the documented empty-state instead of the previous
    // silent blank canvas.
    if (allSeries.none { it.size >= 2 }) {
        Text(
            text = "No chart data",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = modifier.padding(16.dp)
        )
        return
    }

    val range = ChartMath.computeRange(allSeries.flatten())
    val maxPoints = allSeries.maxOf { it.size }
    val labelTexts = labels ?: emptyList()

    Canvas(modifier = modifier) {
        val bottomPadding = if (labelTexts.isNotEmpty()) 20f else 4f
        val chartHeight = size.height - bottomPadding
        val horizontalPadding = 16f
        // Stride is computed from the LONGEST series so index N of
        // every series maps to the same x coordinate. Series shorter than
        // maxPoints simply end earlier in the chart width.
        val stepX = ChartMath.computeSharedStepX(size.width, horizontalPadding, maxPoints)

        drawGridLines(chartHeight, size.width, color.copy(alpha = 0.1f))

        allSeries.forEachIndexed { seriesIdx, seriesData ->
            if (seriesData.size < 2) return@forEachIndexed
            val seriesColor = color.copy(alpha = MULTI_SERIES_ALPHAS.getOrElse(seriesIdx) { 0.3f })

            val path = Path()
            seriesData.forEachIndexed { i, value ->
                val x = horizontalPadding + i * stepX
                val y = ChartMath.computeLineY(value, range) * chartHeight
                if (i == 0) path.moveTo(x, y) else path.lineTo(x, y)
            }
            drawPath(path, seriesColor, style = Stroke(width = 2.dp.toPx()))

            seriesData.forEachIndexed { i, value ->
                val x = horizontalPadding + i * stepX
                val y = ChartMath.computeLineY(value, range) * chartHeight
                drawCircle(seriesColor, radius = 3.dp.toPx(), center = Offset(x, y))
            }
        }

        if (labelTexts.isNotEmpty() && maxPoints > 0) {
            labelTexts.take(maxPoints).forEachIndexed { i, label ->
                val x = horizontalPadding + i * stepX
                val labelResult = textMeasurer.measure(
                    text = label,
                    style = labelStyle,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    constraints = androidx.compose.ui.unit.Constraints(maxWidth = stepX.toInt().coerceAtLeast(1))
                )
                drawText(
                    textLayoutResult = labelResult,
                    topLeft = Offset(x - labelResult.size.width / 2f, chartHeight + 4f)
                )
            }
        }
    }
}

// ── Pie Chart ──────────────────────────────────────────────────────────────

@Composable
private fun PieChart(
    data: List<Double>,
    labels: List<String>?,
    color: Color,
    textMeasurer: TextMeasurer,
    labelStyle: TextStyle,
    modifier: Modifier,
) {
    if (data.isEmpty()) return
    val total = data.sum().coerceAtLeast(1.0)

    Canvas(modifier = modifier) {
        val diameter = minOf(size.width, size.height) * 0.8f
        val radius = diameter / 2f
        val centerX = size.width / 2f
        val centerY = size.height / 2f
        val topLeft = Offset(centerX - radius, centerY - radius)
        val arcSize = Size(diameter, diameter)

        var startAngle = -90f
        data.forEachIndexed { index, value ->
            val sweep = (value / total * 360f).toFloat()
            val segmentColor = color.copy(
                alpha = MULTI_SERIES_ALPHAS.getOrElse(index % MULTI_SERIES_ALPHAS.size) { 0.5f }
            )
            drawArc(
                color = segmentColor,
                startAngle = startAngle,
                sweepAngle = sweep,
                useCenter = true,
                topLeft = topLeft,
                size = arcSize
            )

            val labelTexts = labels ?: emptyList()
            if (index < labelTexts.size && sweep > 15f) {
                val midAngle = Math.toRadians((startAngle + sweep / 2f).toDouble())
                val labelRadius = radius * 0.65f
                val lx = centerX + (labelRadius * kotlin.math.cos(midAngle)).toFloat()
                val ly = centerY + (labelRadius * kotlin.math.sin(midAngle)).toFloat()
                val labelResult = textMeasurer.measure(
                    text = labelTexts[index],
                    style = labelStyle,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    constraints = androidx.compose.ui.unit.Constraints(maxWidth = (radius * 0.6f).toInt().coerceAtLeast(1))
                )
                drawText(
                    textLayoutResult = labelResult,
                    topLeft = Offset(lx - labelResult.size.width / 2f, ly - labelResult.size.height / 2f)
                )
            }

            startAngle += sweep
        }
    }
}

// ── Sparkline Chart ────────────────────────────────────────────────────────

@Composable
private fun SparklineChart(
    data: List<Double>,
    color: Color,
    modifier: Modifier,
) {
    if (data.size < 2) return
    val maxVal = data.max().coerceAtLeast(1.0)
    val minVal = data.min()
    val range = (maxVal - minVal).coerceAtLeast(1.0)

    Canvas(modifier = modifier) {
        val padding = 2.dp.toPx()
        val chartWidth = size.width - padding * 2
        val chartHeight = size.height - padding * 2
        val stepX = chartWidth / (data.size - 1).coerceAtLeast(1)

        val path = Path()
        data.forEachIndexed { i, value ->
            val x = padding + i * stepX
            val y = padding + chartHeight - ((value - minVal) / range * chartHeight).toFloat()
            if (i == 0) path.moveTo(x, y) else path.lineTo(x, y)
        }
        drawPath(path, color, style = Stroke(width = 1.5.dp.toPx()))
    }
}

// ── Shared Utilities ───────────────────────────────────────────────────────

private fun DrawScope.drawGridLines(chartHeight: Float, chartWidth: Float, color: Color) {
    for (i in 0..3) {
        val y = chartHeight * i / 4f
        drawLine(
            color = color,
            start = Offset(0f, y),
            end = Offset(chartWidth, y),
            strokeWidth = 1f
        )
    }
}
