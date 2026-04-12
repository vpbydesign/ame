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
    val maxVal = data.max().coerceAtLeast(1.0)
    val labelTexts = labels ?: emptyList()

    Canvas(modifier = modifier) {
        val bottomPadding = if (labelTexts.isNotEmpty()) 20f else 4f
        val chartHeight = size.height - bottomPadding
        val barSpacing = 8.dp.toPx()
        val totalSpacing = barSpacing * (data.size + 1)
        val barWidth = ((size.width - totalSpacing) / data.size).coerceAtLeast(4f)

        drawGridLines(chartHeight, size.width, color.copy(alpha = 0.1f))

        data.forEachIndexed { index, value ->
            val barHeight = (value / maxVal * chartHeight).toFloat().coerceAtLeast(2f)
            val x = barSpacing + index * (barWidth + barSpacing)
            val y = chartHeight - barHeight

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
    val globalMax = allSeries.flatten().maxOrNull()?.coerceAtLeast(1.0) ?: return
    val maxPoints = allSeries.maxOf { it.size }
    val labelTexts = labels ?: emptyList()

    Canvas(modifier = modifier) {
        val bottomPadding = if (labelTexts.isNotEmpty()) 20f else 4f
        val chartHeight = size.height - bottomPadding
        val horizontalPadding = 16f

        drawGridLines(chartHeight, size.width, color.copy(alpha = 0.1f))

        allSeries.forEachIndexed { seriesIdx, seriesData ->
            if (seriesData.size < 2) return@forEachIndexed
            val seriesColor = color.copy(alpha = MULTI_SERIES_ALPHAS.getOrElse(seriesIdx) { 0.3f })
            val stepX = (size.width - horizontalPadding * 2) / (seriesData.size - 1).coerceAtLeast(1)

            val path = Path()
            seriesData.forEachIndexed { i, value ->
                val x = horizontalPadding + i * stepX
                val y = chartHeight - (value / globalMax * chartHeight).toFloat()
                if (i == 0) path.moveTo(x, y) else path.lineTo(x, y)
            }
            drawPath(path, seriesColor, style = Stroke(width = 2.dp.toPx()))

            seriesData.forEachIndexed { i, value ->
                val x = horizontalPadding + i * stepX
                val y = chartHeight - (value / globalMax * chartHeight).toFloat()
                drawCircle(seriesColor, radius = 3.dp.toPx(), center = Offset(x, y))
            }
        }

        if (labelTexts.isNotEmpty() && maxPoints > 0) {
            val stepX = (size.width - horizontalPadding * 2) / (maxPoints - 1).coerceAtLeast(1)
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
