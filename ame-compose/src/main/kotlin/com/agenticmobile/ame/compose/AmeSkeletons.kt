package com.agenticmobile.ame.compose

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp

/**
 * Shimmer placeholder composable for unresolved [Ref][com.agenticmobile.ame.AmeNode.Ref]
 * nodes during streaming.
 *
 * Per streaming.md:
 * - MUST occupy the layout slot where the resolved component will appear
 * - SHOULD render as a shimmer rectangle (animated sweeping gradient)
 * - SHOULD use default height of 48dp and full available width
 * - MUST NOT be interactive
 *
 * @param id The unresolved reference identifier (retained for debugging).
 * @param modifier Optional modifier applied to the placeholder box.
 */
@Composable
fun AmeSkeleton(
    @Suppress("UNUSED_PARAMETER") id: String,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(48.dp)
            .clip(RoundedCornerShape(8.dp))
            .shimmerEffect()
    )
}

/**
 * Modifier that applies a sweeping shimmer gradient animation.
 *
 * The gradient sweeps horizontally across the composable in a 1-second
 * loop with linear easing, creating the standard Material skeleton
 * loading indicator appearance.
 */
fun Modifier.shimmerEffect(): Modifier = composed {
    var size by remember { mutableStateOf(IntSize.Zero) }
    val transition = rememberInfiniteTransition(label = "shimmer")
    val startOffsetX by transition.animateFloat(
        initialValue = -2f * size.width.toFloat(),
        targetValue = 2f * size.width.toFloat(),
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 1000, easing = LinearEasing)
        ),
        label = "shimmer_offset",
    )

    background(
        brush = Brush.linearGradient(
            colors = listOf(
                Color.LightGray.copy(alpha = 0.3f),
                Color.LightGray.copy(alpha = 0.1f),
                Color.LightGray.copy(alpha = 0.3f),
            ),
            start = Offset(startOffsetX, 0f),
            end = Offset(startOffsetX + size.width.toFloat(), size.height.toFloat()),
        )
    ).onGloballyPositioned { coordinates ->
        size = coordinates.size
    }
}
