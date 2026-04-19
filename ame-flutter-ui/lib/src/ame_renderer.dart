import 'package:flutter/material.dart' hide Align;
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ame_flutter/ame_flutter.dart';

import 'ame_chart_painter.dart';
import 'ame_form_state.dart';
import 'ame_icons.dart';
import 'ame_skeletons.dart';
import 'ame_theme.dart';

/// Recursive widget that renders any [AmeNode] tree as native Material 3 UI.
///
/// This is the main entry point for the AME Flutter renderer. It dispatches
/// to type-specific private builders via an exhaustive `switch` over all 24
/// [AmeNode] sealed subtypes. The Dart compiler enforces exhaustiveness —
/// adding a new subtype to [AmeNode] will cause a compile error here.
class AmeRenderer extends StatelessWidget {
  final AmeNode node;
  final AmeFormState formState;
  final void Function(AmeAction action) onAction;
  final AmeChartRenderer chartRenderer;
  final int depth;

  static const _maxDepth = 12;

  const AmeRenderer({
    super.key,
    required this.node,
    required this.onAction,
    required this.formState,
    this.chartRenderer = const CanvasChartRenderer(),
    this.depth = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (depth > _maxDepth) {
      return Text(
        '\u26A0 Max nesting depth exceeded',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.error),
      );
    }
    return _renderNode(context, node);
  }

  Widget _renderNode(BuildContext context, AmeNode node) {
    return switch (node) {
      AmeCol() => _renderCol(context, node),
      AmeRow() => _renderRow(context, node),
      AmeTxt() => _renderTxt(context, node),
      AmeImg() => _renderImg(context, node),
      AmeIcon() => _renderIcon(context, node),
      AmeDivider() => const Divider(),
      AmeSpacer() => SizedBox(height: node.height.toDouble()),
      AmeCard() => _renderCard(context, node),
      AmeBadge() => _renderBadge(context, node),
      AmeProgress() => _renderProgress(context, node),
      AmeBtn() => _renderBtn(context, node),
      AmeInput() => _renderInput(context, node),
      AmeToggle() => _renderToggle(context, node),
      AmeDataList() => _renderDataList(context, node),
      AmeTable() => _renderTable(context, node),
      AmeChart() => chartRenderer.renderChart(context, node),
      AmeCode() => _renderCode(context, node),
      AmeAccordion() => _AmeAccordionWidget(
          node: node,
          formState: formState,
          onAction: onAction,
          chartRenderer: chartRenderer,
          depth: depth,
        ),
      AmeCarousel() => _renderCarousel(context, node),
      AmeCallout() => _renderCallout(context, node),
      AmeTimeline() => _renderTimeline(context, node),
      AmeTimelineItem() => _renderTimelineItemStandalone(context, node),
      AmeRef() => const AmeSkeleton(height: 48),
      AmeEach() => const AmeSkeleton(height: 120),
    };
  }

  Widget _child(AmeNode child) {
    return AmeRenderer(
      node: child,
      onAction: onAction,
      formState: formState,
      chartRenderer: chartRenderer,
      depth: depth + 1,
    );
  }

  // ── Layout Primitives ──────────────────────────────────────────────

  Widget _renderCol(BuildContext context, AmeCol node) {
    final crossAlign = switch (node.align) {
      Align.start => CrossAxisAlignment.start,
      Align.center => CrossAxisAlignment.center,
      Align.end => CrossAxisAlignment.end,
      Align.spaceBetween || Align.spaceAround => CrossAxisAlignment.start,
    };

    final children = <Widget>[];
    for (var i = 0; i < node.children.length; i++) {
      if (i > 0) children.add(const SizedBox(height: 8));
      children.add(_child(node.children[i]));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAlign,
      children: children,
    );
  }

  Widget _renderRow(BuildContext context, AmeRow node) {
    final mainAlign = switch (node.align) {
      Align.start => MainAxisAlignment.start,
      Align.center => MainAxisAlignment.center,
      Align.end => MainAxisAlignment.end,
      Align.spaceBetween => MainAxisAlignment.spaceBetween,
      Align.spaceAround => MainAxisAlignment.spaceAround,
    };

    final children = <Widget>[];
    final useGap =
        node.align != Align.spaceBetween && node.align != Align.spaceAround;
    for (var i = 0; i < node.children.length; i++) {
      if (i > 0 && useGap) {
        children.add(SizedBox(width: node.gap.toDouble()));
      }
      children.add(_child(node.children[i]));
    }

    return Row(
      mainAxisAlignment: mainAlign,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: children,
    );
  }

  // ── Content Primitives ─────────────────────────────────────────────

  Widget _renderTxt(BuildContext context, AmeTxt node) {
    var style = AmeTheme.textStyle(context, node.style);
    if (node.color != null) {
      style = style.copyWith(color: AmeTheme.semanticColor(context, node.color!));
    }
    return Text(
      node.text,
      style: style,
      maxLines: node.maxLines,
      overflow: node.maxLines != null ? TextOverflow.ellipsis : null,
    );
  }

  Widget _renderImg(BuildContext context, AmeImg node) {
    Widget image = CachedNetworkImage(
      imageUrl: node.url,
      width: double.infinity,
      height: node.height?.toDouble(),
      fit: BoxFit.cover,
      placeholder: (context, url) => const AmeSkeleton(height: 120),
      errorWidget: (context, url, error) => SizedBox(
        height: node.height?.toDouble() ?? 120,
        child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: image,
    );
  }

  Widget _renderIcon(BuildContext context, AmeIcon node) {
    return Icon(
      AmeIcons.resolve(node.name),
      size: node.size.toDouble(),
      semanticLabel: AmeIcons.contentDescription(node.name),
    );
  }

  // ── Semantic Primitives ────────────────────────────────────────────

  Widget _renderCard(BuildContext context, AmeCard node) {
    final children = <Widget>[];
    for (var i = 0; i < node.children.length; i++) {
      if (i > 0) children.add(const SizedBox(height: 8));
      children.add(_child(node.children[i]));
    }

    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: node.elevation.toDouble(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _renderBadge(BuildContext context, AmeBadge node) {
    final bgColor = node.color != null
        ? AmeTheme.semanticColor(context, node.color!)
        : AmeTheme.badgeColor(context, node.variant);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        node.label,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }

  Widget _renderProgress(BuildContext context, AmeProgress node) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (node.label != null) ...[
          Text(
            node.label!,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 4),
        ],
        SizedBox(
          width: double.infinity,
          child: LinearProgressIndicator(
            value: node.value.clamp(0.0, 1.0),
          ),
        ),
      ],
    );
  }

  // ── Interactive Primitives ─────────────────────────────────────────

  Widget _renderBtn(BuildContext context, AmeBtn node) {
    void handleTap() {
      final action = node.action;
      if (action is AmeSubmit) {
        final collected = formState.collectValues();
        final resolved = formState.resolveInputReferences(action.staticArgs);
        final merged = <String, String>{...collected, ...resolved};
        onAction(AmeCallTool(name: action.toolName, args: merged));
      } else {
        onAction(action);
      }
    }

    Widget content = _BtnContent(label: node.label, icon: node.icon);

    return switch (node.style) {
      BtnStyle.primary => ElevatedButton(onPressed: handleTap, child: content),
      BtnStyle.secondary =>
        FilledButton.tonal(onPressed: handleTap, child: content),
      BtnStyle.outline =>
        OutlinedButton(onPressed: handleTap, child: content),
      BtnStyle.text => TextButton(onPressed: handleTap, child: content),
      BtnStyle.destructive => ElevatedButton(
          onPressed: handleTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          child: content,
        ),
    };
  }

  Widget _renderInput(BuildContext context, AmeInput node) {
    return switch (node.type) {
      InputType.text ||
      InputType.number ||
      InputType.email ||
      InputType.phone =>
        _AmeInputTextField(node: node, formState: formState),
      InputType.date => _AmeInputDatePicker(node: node, formState: formState),
      InputType.time => _AmeInputTimePicker(node: node, formState: formState),
      InputType.select => _AmeInputSelect(node: node, formState: formState),
    };
  }

  Widget _renderToggle(BuildContext context, AmeToggle node) {
    return _AmeToggleWidget(node: node, formState: formState);
  }

  // ── Data Primitives ────────────────────────────────────────────────

  Widget _renderDataList(BuildContext context, AmeDataList node) {
    final children = <Widget>[];
    for (var i = 0; i < node.children.length; i++) {
      if (node.dividers && i > 0) children.add(const Divider());
      children.add(_child(node.children[i]));
    }
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Widget _renderTable(BuildContext context, AmeTable node) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: node.headers
                .map((h) => Expanded(
                      child: Text(
                        h,
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ))
                .toList(),
          ),
          const Divider(),
          ...node.rows.map((row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: List.generate(
                    node.headers.length,
                    (i) => Expanded(
                      child: Text(
                        i < row.length ? row[i] : '',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  // ── Rich Content Primitives ────────────────────────────────────────

  Widget _renderCode(BuildContext context, AmeCode node) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    node.title ?? node.language,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: Colors.grey),
                  ),
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 16,
                      icon: const Icon(Icons.content_copy, color: Colors.grey),
                      tooltip: 'Copy code',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: node.content));
                      },
                    ),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding:
                    const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                child: SelectableText(
                  node.content,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: const Color(0xFFD4D4D4),
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Carousel ───────────────────────────────────────────────────────

  Widget _renderCarousel(BuildContext context, AmeCarousel node) {
    if (node.children.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.only(left: 16, right: node.peek.toDouble()),
        itemCount: node.children.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            child: _child(node.children[index]),
          );
        },
      ),
    );
  }

  // ── Callout ────────────────────────────────────────────────────────

  Widget _renderCallout(BuildContext context, AmeCallout node) {
    final style = AmeTheme.calloutStyle(context, node.type);
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          color: style.backgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(style.icon, color: style.iconTint, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (node.title != null) ...[
                    Text(
                      node.title!,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    node.content,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Timeline ───────────────────────────────────────────────────────

  Widget _renderTimeline(BuildContext context, AmeTimeline node) {
    if (node.children.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(node.children.length, (index) {
        final child = node.children[index];
        if (child is! AmeTimelineItem) return _child(child);

        final style = AmeTheme.timelineStyle(context, child.status);
        final isLast = index == node.children.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 24,
                child: Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: style.circleColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: style.isDashed
                            ? CustomPaint(
                                painter: _DashedLinePainter(style.lineColor),
                                child: const SizedBox(width: 2),
                              )
                            : Container(width: 2, color: style.lineColor),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        child.title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (child.subtitle != null && child.subtitle!.isNotEmpty)
                        Text(
                          child.subtitle!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _renderTimelineItemStandalone(
      BuildContext context, AmeTimelineItem node) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(node.title, style: Theme.of(context).textTheme.titleSmall),
          if (node.subtitle != null && node.subtitle!.isNotEmpty)
            Text(
              node.subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
        ],
      ),
    );
  }
}

// ── Stateful Subwidgets ──────────────────────────────────────────────────

class _BtnContent extends StatelessWidget {
  final String label;
  final String? icon;

  const _BtnContent({required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AmeIcons.resolve(icon!), size: 16),
          const SizedBox(width: 4),
          Text(label),
        ],
      );
    }
    return Text(label);
  }
}

class _AmeAccordionWidget extends StatefulWidget {
  final AmeAccordion node;
  final AmeFormState formState;
  final void Function(AmeAction action) onAction;
  final AmeChartRenderer chartRenderer;
  final int depth;

  const _AmeAccordionWidget({
    required this.node,
    required this.formState,
    required this.onAction,
    required this.chartRenderer,
    required this.depth,
  });

  @override
  State<_AmeAccordionWidget> createState() => _AmeAccordionWidgetState();
}

class _AmeAccordionWidgetState extends State<_AmeAccordionWidget>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _chevronController;
  late Animation<double> _chevronAnimation;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.node.expanded;
    _chevronController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: _isExpanded ? 1.0 : 0.0,
    );
    _chevronAnimation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _chevronController, curve: Curves.easeInOut),
    );
  }

  /// Bug 36 fix (Flutter analog of v1.2 Bug 18): the previous
  /// implementation captured `widget.node.expanded` once in `initState`,
  /// so server-pushed updates to the accordion's expanded state were
  /// silently ignored. This override syncs `_isExpanded` and the
  /// chevron animation when the parent re-renders with a different
  /// `node.expanded`. Local user taps still flip `_isExpanded`
  /// immediately and persist until the next external change. Mirrors
  /// Compose `LaunchedEffect(node.expanded)` semantics from v1.2 WP#5.
  @override
  void didUpdateWidget(covariant _AmeAccordionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.node.expanded != oldWidget.node.expanded &&
        widget.node.expanded != _isExpanded) {
      setState(() {
        _isExpanded = widget.node.expanded;
        if (_isExpanded) {
          _chevronController.forward();
        } else {
          _chevronController.reverse();
        }
      });
    }
  }

  @override
  void dispose() {
    _chevronController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _chevronController.forward();
      } else {
        _chevronController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.node.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  RotationTransition(
                    turns: _chevronAnimation,
                    child: const Icon(Icons.expand_more),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _isExpanded
                ? Padding(
                    padding:
                        const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: () {
                        final children = <Widget>[];
                        for (var i = 0;
                            i < widget.node.children.length;
                            i++) {
                          if (i > 0) children.add(const SizedBox(height: 8));
                          children.add(AmeRenderer(
                            node: widget.node.children[i],
                            onAction: widget.onAction,
                            formState: widget.formState,
                            chartRenderer: widget.chartRenderer,
                            depth: widget.depth + 1,
                          ));
                        }
                        return children;
                      }(),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _AmeInputTextField extends StatefulWidget {
  final AmeInput node;
  final AmeFormState formState;

  const _AmeInputTextField({required this.node, required this.formState});

  @override
  State<_AmeInputTextField> createState() => _AmeInputTextFieldState();
}

class _AmeInputTextFieldState extends State<_AmeInputTextField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.formState.getInput(widget.node.id),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardType = switch (widget.node.type) {
      InputType.number => TextInputType.number,
      InputType.email => TextInputType.emailAddress,
      InputType.phone => TextInputType.phone,
      _ => TextInputType.text,
    };

    return SizedBox(
      width: double.infinity,
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          labelText: widget.node.label,
          border: const OutlineInputBorder(),
        ),
        keyboardType: keyboardType,
        onChanged: (value) => widget.formState.setInput(widget.node.id, value),
      ),
    );
  }
}

/// Bug 38 fix (WP#7 Phase D discovery): the pre-fix StatelessWidget
/// constructed a fresh [TextEditingController] inside `build()`, which
/// (1) lost cursor/selection state on every `formState.notifyListeners()`,
/// (2) generated GC churn from per-build allocation, and
/// (3) broke IME composition on Android.
///
/// The post-fix StatefulWidget hoists the controller into `initState`,
/// disposes in `dispose`, and synchronizes the controller text via a
/// [ChangeNotifier] listener on [formState] plus `didUpdateWidget` for
/// the rare case where the host swaps a different node into the same
/// position. Pattern mirrors `_AmeInputTextField` which already follows
/// the correct lifecycle.
class _AmeInputDatePicker extends StatefulWidget {
  final AmeInput node;
  final AmeFormState formState;

  const _AmeInputDatePicker({required this.node, required this.formState});

  @override
  State<_AmeInputDatePicker> createState() => _AmeInputDatePickerState();
}

class _AmeInputDatePickerState extends State<_AmeInputDatePicker> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.formState.getInput(widget.node.id),
    );
    widget.formState.addListener(_syncFromFormState);
  }

  @override
  void didUpdateWidget(covariant _AmeInputDatePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.formState != widget.formState) {
      oldWidget.formState.removeListener(_syncFromFormState);
      widget.formState.addListener(_syncFromFormState);
    }
    _syncFromFormState();
  }

  @override
  void dispose() {
    widget.formState.removeListener(_syncFromFormState);
    _controller.dispose();
    super.dispose();
  }

  void _syncFromFormState() {
    final next = widget.formState.getInput(widget.node.id);
    if (_controller.text != next) {
      _controller.text = next;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (date != null) {
            final formatted =
                '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            widget.formState.setInput(widget.node.id, formatted);
          }
        },
        child: AbsorbPointer(
          child: TextField(
            decoration: InputDecoration(
              labelText: widget.node.label,
              border: const OutlineInputBorder(),
            ),
            controller: _controller,
          ),
        ),
      ),
    );
  }
}

/// Bug 38 fix (WP#7 Phase D discovery): see [_AmeInputDatePicker] for the
/// rationale; `_AmeInputTimePicker` follows the identical lifecycle
/// pattern with `showTimePicker` instead of `showDatePicker`.
class _AmeInputTimePicker extends StatefulWidget {
  final AmeInput node;
  final AmeFormState formState;

  const _AmeInputTimePicker({required this.node, required this.formState});

  @override
  State<_AmeInputTimePicker> createState() => _AmeInputTimePickerState();
}

class _AmeInputTimePickerState extends State<_AmeInputTimePicker> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.formState.getInput(widget.node.id),
    );
    widget.formState.addListener(_syncFromFormState);
  }

  @override
  void didUpdateWidget(covariant _AmeInputTimePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.formState != widget.formState) {
      oldWidget.formState.removeListener(_syncFromFormState);
      widget.formState.addListener(_syncFromFormState);
    }
    _syncFromFormState();
  }

  @override
  void dispose() {
    widget.formState.removeListener(_syncFromFormState);
    _controller.dispose();
    super.dispose();
  }

  void _syncFromFormState() {
    final next = widget.formState.getInput(widget.node.id);
    if (_controller.text != next) {
      _controller.text = next;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: () async {
          final time = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.now(),
          );
          if (time != null) {
            final formatted =
                '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
            widget.formState.setInput(widget.node.id, formatted);
          }
        },
        child: AbsorbPointer(
          child: TextField(
            decoration: InputDecoration(
              labelText: widget.node.label,
              border: const OutlineInputBorder(),
            ),
            controller: _controller,
          ),
        ),
      ),
    );
  }
}

class _AmeInputSelect extends StatefulWidget {
  final AmeInput node;
  final AmeFormState formState;

  const _AmeInputSelect({required this.node, required this.formState});

  @override
  State<_AmeInputSelect> createState() => _AmeInputSelectState();
}

class _AmeInputSelectState extends State<_AmeInputSelect> {
  @override
  Widget build(BuildContext context) {
    final options = widget.node.options ?? const [];
    final currentValue = widget.formState.getInput(widget.node.id);

    return SizedBox(
      width: double.infinity,
      child: DropdownButtonFormField<String>(
        value: options.contains(currentValue) ? currentValue : null,
        decoration: InputDecoration(
          labelText: widget.node.label,
          border: const OutlineInputBorder(),
        ),
        items: options
            .map((o) => DropdownMenuItem(value: o, child: Text(o)))
            .toList(),
        onChanged: (value) {
          if (value != null) {
            widget.formState.setInput(widget.node.id, value);
            setState(() {});
          }
        },
      ),
    );
  }
}

class _AmeToggleWidget extends StatelessWidget {
  final AmeToggle node;
  final AmeFormState formState;

  const _AmeToggleWidget({required this.node, required this.formState});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: formState,
      builder: (context, _) {
        return SizedBox(
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  node.label,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Switch(
                value: formState.getToggle(node.id, node.defaultValue),
                onChanged: (value) => formState.setToggle(node.id, value),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Dashed Line Painter ──────────────────────────────────────────────────

class _DashedLinePainter extends CustomPainter {
  final Color color;

  _DashedLinePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;

    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, (y + 6).clamp(0, size.height)),
        paint,
      );
      y += 10;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter old) => color != old.color;
}
