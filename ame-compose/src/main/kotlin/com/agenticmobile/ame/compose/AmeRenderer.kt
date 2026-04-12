@file:OptIn(ExperimentalMaterial3Api::class)

package com.agenticmobile.ame.compose

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.gestures.snapping.rememberSnapFlingBehavior
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.MenuAnchorType
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TimePicker
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import com.agenticmobile.ame.Align
import com.agenticmobile.ame.AmeAction
import com.agenticmobile.ame.AmeNode
import com.agenticmobile.ame.BtnStyle
import com.agenticmobile.ame.InputType
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * Recursive Composable that renders any [AmeNode] tree as native Material 3 UI.
 *
 * This is the main entry point for the AME Compose renderer. It dispatches
 * to type-specific private composables via an exhaustive `when` over all 24
 * [AmeNode] sealed subtypes (21 visual + Ref, Each, TimelineItem).
 * The Kotlin compiler enforces exhaustiveness — adding a new subtype to
 * [AmeNode] will cause a compile error here until a rendering branch is added.
 *
 * @param node The AME node tree to render.
 * @param formState Manages form input/toggle values for this rendering scope.
 *   Created and owned by the host app (e.g., scoped per message in a ViewModel).
 * @param onAction Callback for dispatching user-triggered actions to the host app.
 *   Per actions.md, [AmeAction.Submit] is resolved to [AmeAction.CallTool] before
 *   this callback is invoked — the host never sees Submit.
 * @param modifier Optional modifier applied to the root node.
 * @param depth Current nesting depth for stack overflow protection.
 */
@Composable
fun AmeRenderer(
    node: AmeNode,
    formState: AmeFormState = remember { AmeFormState() },
    onAction: (AmeAction) -> Unit,
    modifier: Modifier = Modifier,
    depth: Int = 0,
) {
    if (depth > MAX_DEPTH) {
        Text(
            text = "\u26A0 Max nesting depth exceeded",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.error,
        )
        return
    }

    when (node) {
        is AmeNode.Col -> AmeCol(node, formState, onAction, modifier, depth)
        is AmeNode.Row -> AmeRow(node, formState, onAction, modifier, depth)
        is AmeNode.Txt -> AmeTxt(node, modifier)
        is AmeNode.Img -> AmeImg(node, modifier)
        is AmeNode.Icon -> AmeIcon(node, modifier)
        AmeNode.Divider -> HorizontalDivider(modifier)
        is AmeNode.Spacer -> {
            androidx.compose.foundation.layout.Spacer(
                modifier = modifier.height(node.height.dp)
            )
        }
        is AmeNode.Card -> AmeCard(node, formState, onAction, modifier, depth)
        is AmeNode.Badge -> AmeBadge(node, modifier)
        is AmeNode.Progress -> AmeProgress(node, modifier)
        is AmeNode.Btn -> AmeBtn(node, formState, onAction, modifier)
        is AmeNode.Input -> AmeInput(node, formState, modifier)
        is AmeNode.Toggle -> AmeToggle(node, formState, modifier)
        is AmeNode.DataList -> AmeDataList(node, formState, onAction, modifier, depth)
        is AmeNode.Table -> AmeTable(node, modifier)
        is AmeNode.Chart -> AmeChart(node, modifier)
        is AmeNode.Code -> AmeCode(node, modifier)
        is AmeNode.Accordion -> AmeAccordion(node, formState, onAction, modifier, depth)
        is AmeNode.Carousel -> AmeCarousel(node, formState, onAction, modifier, depth)
        is AmeNode.Callout -> AmeCallout(node, modifier)
        is AmeNode.Timeline -> AmeTimeline(node, formState, onAction, modifier, depth)
        is AmeNode.TimelineItem -> AmeTimelineItemStandalone(node, modifier)
        is AmeNode.Ref -> AmeSkeleton(node.id, modifier)
        is AmeNode.Each -> AmeEach(node, modifier)
    }
}

private const val MAX_DEPTH = 12

// ── Layout Primitives ──────────────────────────────────────────────────────

/**
 * Vertical column layout. Children are arranged top-to-bottom with 8dp spacing.
 * Horizontal alignment is determined by [AmeNode.Col.align].
 */
@Composable
private fun AmeCol(
    node: AmeNode.Col,
    formState: AmeFormState,
    onAction: (AmeAction) -> Unit,
    modifier: Modifier,
    depth: Int,
) {
    Column(
        horizontalAlignment = when (node.align) {
            Align.START -> Alignment.Start
            Align.CENTER -> Alignment.CenterHorizontally
            Align.END -> Alignment.End
            Align.SPACE_BETWEEN, Align.SPACE_AROUND -> Alignment.Start
        },
        verticalArrangement = Arrangement.spacedBy(8.dp),
        modifier = modifier,
    ) {
        node.children.forEach { child ->
            AmeRenderer(child, formState, onAction, depth = depth + 1)
        }
    }
}

/**
 * Horizontal row layout. Children are arranged left-to-right.
 * Spacing and distribution are determined by [AmeNode.Row.align] and [AmeNode.Row.gap].
 */
@Composable
private fun AmeRow(
    node: AmeNode.Row,
    formState: AmeFormState,
    onAction: (AmeAction) -> Unit,
    modifier: Modifier,
    depth: Int,
) {
    Row(
        horizontalArrangement = when (node.align) {
            Align.START -> Arrangement.spacedBy(node.gap.dp)
            Align.CENTER -> Arrangement.spacedBy(node.gap.dp, Alignment.CenterHorizontally)
            Align.END -> Arrangement.spacedBy(node.gap.dp, Alignment.End)
            Align.SPACE_BETWEEN -> Arrangement.SpaceBetween
            Align.SPACE_AROUND -> Arrangement.SpaceAround
        },
        verticalAlignment = Alignment.CenterVertically,
        modifier = modifier,
    ) {
        node.children.forEach { child ->
            AmeRenderer(child, formState, onAction, depth = depth + 1)
        }
    }
}

// ── Content Primitives ─────────────────────────────────────────────────────

/** Text display with AME typographic style mapping and optional semantic color. */
@Composable
private fun AmeTxt(node: AmeNode.Txt, modifier: Modifier) {
    Text(
        text = node.text,
        style = AmeTheme.textStyle(node.style),
        color = node.color?.let { AmeTheme.semanticColor(it) } ?: Color.Unspecified,
        maxLines = node.maxLines ?: Int.MAX_VALUE,
        overflow = TextOverflow.Ellipsis,
        modifier = modifier,
    )
}

/**
 * Image loaded from a URL via Coil 3.
 * Width fills available space; height is optionally fixed.
 */
@Composable
private fun AmeImg(node: AmeNode.Img, modifier: Modifier) {
    val heightDp = node.height
    AsyncImage(
        model = node.url,
        contentDescription = null,
        modifier = modifier
            .fillMaxWidth()
            .then(if (heightDp != null) Modifier.height(heightDp.dp) else Modifier)
            .clip(RoundedCornerShape(4.dp)),
        contentScale = ContentScale.Crop,
    )
}

/** Named Material icon resolved via [AmeIcons] registry. */
@Composable
private fun AmeIcon(node: AmeNode.Icon, modifier: Modifier) {
    androidx.compose.material3.Icon(
        imageVector = AmeIcons.resolve(node.name),
        contentDescription = AmeIcons.contentDescription(node.name),
        modifier = modifier.size(node.size.dp),
    )
}

// ── Semantic Primitives ────────────────────────────────────────────────────

/**
 * Elevated card container. Children are arranged vertically with 12dp padding
 * and 8dp vertical spacing.
 */
@Composable
private fun AmeCard(
    node: AmeNode.Card,
    formState: AmeFormState,
    onAction: (AmeAction) -> Unit,
    modifier: Modifier,
    depth: Int,
) {
    Card(
        elevation = CardDefaults.cardElevation(defaultElevation = node.elevation.dp),
        modifier = modifier.fillMaxWidth(),
    ) {
        Column(
            modifier = Modifier.padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            node.children.forEach { child ->
                AmeRenderer(child, formState, onAction, depth = depth + 1)
            }
        }
    }
}

/** Small colored label for status indicators. SemanticColor overrides variant when present. */
@Composable
private fun AmeBadge(node: AmeNode.Badge, modifier: Modifier) {
    val bgColor = node.color?.let { AmeTheme.semanticColor(it) }
        ?: AmeTheme.badgeColor(node.variant)
    Surface(
        shape = RoundedCornerShape(4.dp),
        color = bgColor,
        modifier = modifier.padding(horizontal = 2.dp),
    ) {
        Text(
            text = node.label,
            style = MaterialTheme.typography.labelSmall,
            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
        )
    }
}

/** Horizontal progress bar with optional label above. */
@Composable
private fun AmeProgress(node: AmeNode.Progress, modifier: Modifier) {
    val progressLabel = node.label
    Column(modifier = modifier) {
        if (progressLabel != null) {
            Text(
                text = progressLabel,
                style = MaterialTheme.typography.labelSmall,
            )
            androidx.compose.foundation.layout.Spacer(Modifier.height(4.dp))
        }
        LinearProgressIndicator(
            progress = { node.value.coerceIn(0f, 1f) },
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

// ── Interactive Primitives ─────────────────────────────────────────────────

/**
 * Tappable button that dispatches an [AmeAction].
 *
 * Handles [AmeAction.Submit] → [AmeAction.CallTool] conversion per actions.md:
 * 1. Collects all form input/toggle values
 * 2. Resolves `${input.fieldId}` references in static args
 * 3. Merges: collected values first, then resolved static args (static wins on conflict)
 * 4. Dispatches as CallTool
 *
 * Icon rendering is applied to all button styles when [AmeNode.Btn.icon] is non-null.
 */
@Composable
private fun AmeBtn(
    node: AmeNode.Btn,
    formState: AmeFormState,
    onAction: (AmeAction) -> Unit,
    modifier: Modifier,
) {
    val onClick: () -> Unit = {
        when (val action = node.action) {
            is AmeAction.Submit -> {
                val collected = formState.collectValues()
                val resolved = formState.resolveInputReferences(action.staticArgs)
                onAction(AmeAction.CallTool(action.toolName, collected + resolved))
            }
            else -> onAction(node.action)
        }
    }

    val colors = AmeTheme.btnColors(node.style)

    when (node.style) {
        BtnStyle.PRIMARY -> Button(onClick = onClick, colors = colors, modifier = modifier) {
            AmeBtnContent(node.label, node.icon)
        }
        BtnStyle.SECONDARY -> FilledTonalButton(onClick = onClick, colors = colors, modifier = modifier) {
            AmeBtnContent(node.label, node.icon)
        }
        BtnStyle.OUTLINE -> OutlinedButton(onClick = onClick, colors = colors, modifier = modifier) {
            AmeBtnContent(node.label, node.icon)
        }
        BtnStyle.TEXT -> TextButton(onClick = onClick, colors = colors, modifier = modifier) {
            AmeBtnContent(node.label, node.icon)
        }
        BtnStyle.DESTRUCTIVE -> Button(onClick = onClick, colors = colors, modifier = modifier) {
            AmeBtnContent(node.label, node.icon)
        }
    }
}

/** Renders optional icon + label text inside a button's content slot. */
@Composable
private fun AmeBtnContent(label: String, icon: String?) {
    if (icon != null) {
        androidx.compose.material3.Icon(
            imageVector = AmeIcons.resolve(icon),
            contentDescription = null,
            modifier = Modifier.size(16.dp),
        )
        androidx.compose.foundation.layout.Spacer(Modifier.width(4.dp))
    }
    Text(label)
}

/**
 * Form input field. Dispatches to type-specific UI:
 * - TEXT, NUMBER, EMAIL, PHONE → [OutlinedTextField] with appropriate keyboard
 * - DATE → read-only field + [DatePickerDialog]
 * - TIME → read-only field + time picker dialog
 * - SELECT → [ExposedDropdownMenuBox] with [AmeNode.Input.options]
 */
@Composable
private fun AmeInput(
    node: AmeNode.Input,
    formState: AmeFormState,
    modifier: Modifier,
) {
    when (node.type) {
        InputType.TEXT, InputType.NUMBER, InputType.EMAIL, InputType.PHONE ->
            AmeInputTextField(node, formState, modifier)
        InputType.DATE -> AmeInputDatePicker(node, formState, modifier)
        InputType.TIME -> AmeInputTimePicker(node, formState, modifier)
        InputType.SELECT -> AmeInputSelect(node, formState, modifier)
    }
}

@Composable
private fun AmeInputTextField(
    node: AmeNode.Input,
    formState: AmeFormState,
    modifier: Modifier,
) {
    val inputState = formState.registerInput(node.id)
    var value by inputState

    OutlinedTextField(
        value = value,
        onValueChange = { value = it },
        label = { Text(node.label) },
        keyboardOptions = KeyboardOptions(
            keyboardType = when (node.type) {
                InputType.NUMBER -> KeyboardType.Number
                InputType.EMAIL -> KeyboardType.Email
                InputType.PHONE -> KeyboardType.Phone
                else -> KeyboardType.Text
            }
        ),
        singleLine = true,
        modifier = modifier.fillMaxWidth(),
    )
}

@Composable
private fun AmeInputDatePicker(
    node: AmeNode.Input,
    formState: AmeFormState,
    modifier: Modifier,
) {
    val inputState = formState.registerInput(node.id)
    var showPicker by remember { mutableStateOf(false) }
    val datePickerState = rememberDatePickerState()
    val dateFormatter = remember {
        SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }
    }

    Box(
        modifier = modifier
            .fillMaxWidth()
            .clickable { showPicker = true },
    ) {
        OutlinedTextField(
            value = inputState.value,
            onValueChange = {},
            readOnly = true,
            enabled = false,
            label = { Text(node.label) },
            modifier = Modifier.fillMaxWidth(),
            colors = OutlinedTextFieldDefaults.colors(
                disabledTextColor = MaterialTheme.colorScheme.onSurface,
                disabledBorderColor = MaterialTheme.colorScheme.outline,
                disabledLabelColor = MaterialTheme.colorScheme.onSurfaceVariant,
            ),
        )
    }

    if (showPicker) {
        DatePickerDialog(
            onDismissRequest = { showPicker = false },
            confirmButton = {
                TextButton(
                    onClick = {
                        datePickerState.selectedDateMillis?.let { millis ->
                            inputState.value = dateFormatter.format(Date(millis))
                        }
                        showPicker = false
                    }
                ) { Text("OK") }
            },
            dismissButton = {
                TextButton(onClick = { showPicker = false }) { Text("Cancel") }
            },
        ) {
            DatePicker(state = datePickerState)
        }
    }
}

@Composable
private fun AmeInputTimePicker(
    node: AmeNode.Input,
    formState: AmeFormState,
    modifier: Modifier,
) {
    val inputState = formState.registerInput(node.id)
    var showPicker by remember { mutableStateOf(false) }
    val timePickerState = rememberTimePickerState()

    Box(
        modifier = modifier
            .fillMaxWidth()
            .clickable { showPicker = true },
    ) {
        OutlinedTextField(
            value = inputState.value,
            onValueChange = {},
            readOnly = true,
            enabled = false,
            label = { Text(node.label) },
            modifier = Modifier.fillMaxWidth(),
            colors = OutlinedTextFieldDefaults.colors(
                disabledTextColor = MaterialTheme.colorScheme.onSurface,
                disabledBorderColor = MaterialTheme.colorScheme.outline,
                disabledLabelColor = MaterialTheme.colorScheme.onSurfaceVariant,
            ),
        )
    }

    if (showPicker) {
        AmeTimePickerDialog(
            onDismissRequest = { showPicker = false },
            onConfirm = {
                inputState.value = String.format(
                    Locale.getDefault(),
                    "%02d:%02d",
                    timePickerState.hour,
                    timePickerState.minute,
                )
                showPicker = false
            },
        ) {
            TimePicker(state = timePickerState)
        }
    }
}

/**
 * Custom time picker dialog wrapper.
 * Material 3 [TimePickerDialog] composable is not available in BOM 2024.12.01
 * (Material 3 ~1.3.x). This wraps [AlertDialog] with [TimePicker] content.
 */
@Composable
private fun AmeTimePickerDialog(
    onDismissRequest: () -> Unit,
    onConfirm: () -> Unit,
    content: @Composable () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismissRequest,
        confirmButton = {
            TextButton(onClick = onConfirm) { Text("OK") }
        },
        dismissButton = {
            TextButton(onClick = onDismissRequest) { Text("Cancel") }
        },
        text = { content() },
    )
}

@Composable
private fun AmeInputSelect(
    node: AmeNode.Input,
    formState: AmeFormState,
    modifier: Modifier,
) {
    val inputState = formState.registerInput(node.id)
    var value by inputState
    var expanded by remember { mutableStateOf(false) }
    val options = node.options ?: emptyList()

    ExposedDropdownMenuBox(
        expanded = expanded,
        onExpandedChange = { expanded = it },
        modifier = modifier,
    ) {
        OutlinedTextField(
            value = value,
            onValueChange = {},
            readOnly = true,
            label = { Text(node.label) },
            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
            modifier = Modifier
                .menuAnchor(MenuAnchorType.PrimaryNotEditable)
                .fillMaxWidth(),
        )
        ExposedDropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
        ) {
            options.forEach { option ->
                DropdownMenuItem(
                    text = { Text(option) },
                    onClick = {
                        value = option
                        expanded = false
                    },
                    contentPadding = ExposedDropdownMenuDefaults.ItemContentPadding,
                )
            }
        }
    }
}

/** Labeled toggle switch for boolean form values. */
@Composable
private fun AmeToggle(
    node: AmeNode.Toggle,
    formState: AmeFormState,
    modifier: Modifier,
) {
    val toggleState = formState.registerToggle(node.id, node.default)
    var checked by toggleState

    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = node.label,
            style = MaterialTheme.typography.bodyMedium,
        )
        Switch(
            checked = checked,
            onCheckedChange = { checked = it },
        )
    }
}

// ── Data Primitives ────────────────────────────────────────────────────────

/** Vertical list with optional dividers between children. */
@Composable
private fun AmeDataList(
    node: AmeNode.DataList,
    formState: AmeFormState,
    onAction: (AmeAction) -> Unit,
    modifier: Modifier,
    depth: Int,
) {
    Column(modifier = modifier.fillMaxWidth()) {
        node.children.forEachIndexed { index, child ->
            if (node.dividers && index > 0) {
                HorizontalDivider()
            }
            AmeRenderer(child, formState, onAction, depth = depth + 1)
        }
    }
}

/** Grid of text values with a bold header row. */
@Composable
private fun AmeTable(node: AmeNode.Table, modifier: Modifier) {
    Column(modifier = modifier.fillMaxWidth()) {
        Row(modifier = Modifier.fillMaxWidth()) {
            node.headers.forEach { header ->
                Text(
                    text = header,
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.weight(1f),
                )
            }
        }
        HorizontalDivider()
        node.rows.forEach { row ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 4.dp),
            ) {
                node.headers.indices.forEach { i ->
                    Text(
                        text = row.getOrElse(i) { "" },
                        style = MaterialTheme.typography.bodySmall,
                        modifier = Modifier.weight(1f),
                    )
                }
            }
        }
    }
}

// ── v1.1 Primitives ────────────────────────────────────────────────────────

/** Delegates to the pluggable [AmeChartRenderer] via [LocalAmeChartRenderer]. */
@Composable
private fun AmeChart(node: AmeNode.Chart, modifier: Modifier) {
    val renderer = LocalAmeChartRenderer.current
    renderer.RenderChart(node, modifier)
}

/** Syntax-highlighted code block with copy affordance. Dark background is intentional (v1.1). */
@Composable
private fun AmeCode(node: AmeNode.Code, modifier: Modifier) {
    Surface(
        color = Color(0xFF1E1E1E),
        shape = RoundedCornerShape(8.dp),
        modifier = modifier.fillMaxWidth()
    ) {
        Column {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = node.title ?: node.language,
                    style = MaterialTheme.typography.labelSmall,
                    color = Color.Gray
                )
                val clipboardManager = LocalClipboardManager.current
                IconButton(
                    onClick = { clipboardManager.setText(AnnotatedString(node.content)) },
                    modifier = Modifier.size(24.dp)
                ) {
                    Icon(
                        Icons.Filled.ContentCopy,
                        contentDescription = "Copy code",
                        tint = Color.Gray,
                        modifier = Modifier.size(16.dp)
                    )
                }
            }
            SelectionContainer {
                Text(
                    text = node.content,
                    fontFamily = FontFamily.Monospace,
                    style = MaterialTheme.typography.bodySmall,
                    color = Color(0xFFD4D4D4),
                    modifier = Modifier
                        .horizontalScroll(rememberScrollState())
                        .padding(start = 12.dp, end = 12.dp, bottom = 12.dp)
                )
            }
        }
    }
}

/** Collapsible section with animated chevron and expand/shrink transition. */
@Composable
private fun AmeAccordion(
    node: AmeNode.Accordion,
    formState: AmeFormState,
    onAction: (AmeAction) -> Unit,
    modifier: Modifier,
    depth: Int,
) {
    var isExpanded by remember { mutableStateOf(node.expanded) }
    val chevronRotation by animateFloatAsState(
        targetValue = if (isExpanded) 180f else 0f,
        animationSpec = tween(200),
        label = "chevron"
    )
    Column(modifier = modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable { isExpanded = !isExpanded }
                .padding(12.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = node.title,
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.weight(1f)
            )
            Icon(
                imageVector = Icons.Filled.ExpandMore,
                contentDescription = if (isExpanded) "Collapse" else "Expand",
                modifier = Modifier.rotate(chevronRotation)
            )
        }
        AnimatedVisibility(
            visible = isExpanded,
            enter = expandVertically(animationSpec = tween(200)),
            exit = shrinkVertically(animationSpec = tween(200))
        ) {
            Column(
                modifier = Modifier.padding(start = 12.dp, end = 12.dp, bottom = 12.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                node.children.forEach { child ->
                    AmeRenderer(child, formState, onAction, depth = depth + 1)
                }
            }
        }
    }
}

/** Horizontally scrollable container with snap-to-item fling behavior. */
@Composable
private fun AmeCarousel(
    node: AmeNode.Carousel,
    formState: AmeFormState,
    onAction: (AmeAction) -> Unit,
    modifier: Modifier,
    depth: Int,
) {
    if (node.children.isEmpty()) return
    val state = rememberLazyListState()
    LazyRow(
        state = state,
        flingBehavior = rememberSnapFlingBehavior(lazyListState = state),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        contentPadding = PaddingValues(start = 16.dp, end = node.peek.dp),
        modifier = modifier.fillMaxWidth()
    ) {
        items(node.children.size) { index ->
            Box(modifier = Modifier.fillParentMaxWidth(0.85f)) {
                AmeRenderer(node.children[index], formState, onAction, depth = depth + 1)
            }
        }
    }
}

/** Visually distinct alert/info box with type-specific icon and tint from [AmeTheme]. */
@Composable
private fun AmeCallout(node: AmeNode.Callout, modifier: Modifier) {
    val style = AmeTheme.calloutStyle(node.type)
    Surface(
        shape = RoundedCornerShape(8.dp),
        color = style.backgroundColor,
        modifier = modifier.fillMaxWidth()
    ) {
        Row(
            modifier = Modifier.padding(12.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Icon(
                imageVector = style.icon,
                contentDescription = null,
                tint = style.iconTint,
                modifier = Modifier.size(24.dp)
            )
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                if (node.title != null) {
                    Text(
                        text = node.title!!,
                        style = MaterialTheme.typography.labelLarge
                    )
                }
                Text(
                    text = node.content,
                    style = MaterialTheme.typography.bodyMedium
                )
            }
        }
    }
}

/**
 * Ordered vertical event sequence. Timeline items render with status circles
 * and connector lines. Connectors use [IntrinsicSize.Min] + weight(1f) to
 * stretch to match text height. Dashed lines use [PathEffect.dashPathEffect].
 */
@Composable
private fun AmeTimeline(
    node: AmeNode.Timeline,
    formState: AmeFormState,
    onAction: (AmeAction) -> Unit,
    modifier: Modifier,
    depth: Int,
) {
    if (node.children.isEmpty()) return
    Column(modifier = modifier) {
        node.children.forEachIndexed { index, child ->
            if (child is AmeNode.TimelineItem) {
                val style = AmeTheme.timelineStyle(child.status)
                Row(modifier = Modifier.height(IntrinsicSize.Min)) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier.fillMaxHeight()
                    ) {
                        Box(
                            modifier = Modifier
                                .size(12.dp)
                                .clip(CircleShape)
                                .background(style.circleColor)
                        )
                        if (index < node.children.lastIndex) {
                            if (style.isDashed) {
                                Canvas(modifier = Modifier.width(2.dp).weight(1f)) {
                                    drawLine(
                                        color = style.lineColor,
                                        start = Offset(size.width / 2, 0f),
                                        end = Offset(size.width / 2, size.height),
                                        strokeWidth = 2.dp.toPx(),
                                        pathEffect = PathEffect.dashPathEffect(floatArrayOf(6f, 4f))
                                    )
                                }
                            } else {
                                Box(
                                    modifier = Modifier
                                        .width(2.dp)
                                        .weight(1f)
                                        .background(style.lineColor)
                                )
                            }
                        }
                    }
                    androidx.compose.foundation.layout.Spacer(Modifier.width(12.dp))
                    Column(modifier = Modifier.padding(bottom = 16.dp)) {
                        Text(
                            text = child.title,
                            style = MaterialTheme.typography.titleSmall
                        )
                        if (!child.subtitle.isNullOrEmpty()) {
                            Text(
                                text = child.subtitle!!,
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            } else {
                AmeRenderer(child, formState, onAction, depth = depth + 1)
            }
        }
    }
}

/** Standalone fallback when [AmeNode.TimelineItem] appears outside a timeline container. */
@Composable
private fun AmeTimelineItemStandalone(node: AmeNode.TimelineItem, modifier: Modifier) {
    Column(modifier = modifier.padding(8.dp)) {
        Text(text = node.title, style = MaterialTheme.typography.titleSmall)
        if (!node.subtitle.isNullOrEmpty()) {
            Text(
                text = node.subtitle!!,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

// ── Structural Types ───────────────────────────────────────────────────────

/**
 * Streaming fallback for [AmeNode.Each] data iteration construct.
 *
 * When a data section is present, the parser expands each() at parse time and
 * this composable is never reached. This path is only hit during streaming mode
 * when the data model has not yet arrived — renders a list-shaped skeleton
 * placeholder (120dp per streaming.md) until the tree is re-resolved with data.
 */
@Composable
private fun AmeEach(node: AmeNode.Each, modifier: Modifier) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(120.dp)
            .clip(RoundedCornerShape(8.dp))
            .shimmerEffect(),
    )
}
