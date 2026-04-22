import 'ame_action.dart';
import 'ame_types.dart';

/// Sealed class representing all AME UI node types.
///
/// 25 subtypes total: 22 visual primitives + Divider + Ref + Each.
///
/// Children are List<AmeNode> (resolved tree form). The parser converts
/// identifier strings to Ref nodes during parsing, then resolves Ref -> real
/// node after all lines are processed.
sealed class AmeNode {
  const AmeNode();

  Map<String, dynamic> toJson();

  static AmeNode? fromJson(Map<String, dynamic> json) {
    switch (json['_type']) {
      case 'col':
        return AmeCol.fromJson(json);
      case 'row':
        return AmeRow.fromJson(json);
      case 'txt':
        return AmeTxt.fromJson(json);
      case 'img':
        return AmeImg.fromJson(json);
      case 'icon':
        return AmeIcon.fromJson(json);
      case 'divider':
        return const AmeDivider();
      case 'spacer':
        return AmeSpacer.fromJson(json);
      case 'card':
        return AmeCard.fromJson(json);
      case 'badge':
        return AmeBadge.fromJson(json);
      case 'progress':
        return AmeProgress.fromJson(json);
      case 'btn':
        return AmeBtn.fromJson(json);
      case 'input':
        return AmeInput.fromJson(json);
      case 'toggle':
        return AmeToggle.fromJson(json);
      case 'list':
        return AmeDataList.fromJson(json);
      case 'list_item':
        return AmeListItem.fromJson(json);
      case 'table':
        return AmeTable.fromJson(json);
      case 'chart':
        return AmeChart.fromJson(json);
      case 'code':
        return AmeCode.fromJson(json);
      case 'accordion':
        return AmeAccordion.fromJson(json);
      case 'carousel':
        return AmeCarousel.fromJson(json);
      case 'callout':
        return AmeCallout.fromJson(json);
      case 'timeline':
        return AmeTimeline.fromJson(json);
      case 'timeline_item':
        return AmeTimelineItem.fromJson(json);
      case 'ref':
        return AmeRef.fromJson(json);
      case 'each':
        return AmeEach.fromJson(json);
      default:
        return null;
    }
  }
}

// ── Layout Primitives ────────────────────────────────────────────────────

/// Vertical column layout.
final class AmeCol extends AmeNode {
  final List<AmeNode> children;
  final Align align;

  const AmeCol({this.children = const [], this.align = Align.start});

  factory AmeCol.fromJson(Map<String, dynamic> json) {
    return AmeCol(
      children: _childrenFromJson(json['children']),
      align: Align.fromString(json['align'] as String? ?? '') ?? Align.start,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'_type': 'col'};
    if (children.isNotEmpty) {
      map['children'] = children.map((c) => c.toJson()).toList();
    }
    if (align != Align.start) map['align'] = align.value;
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AmeCol &&
          _listsEqual(children, other.children) &&
          align == other.align;

  @override
  int get hashCode => Object.hash(Object.hashAll(children), align);

  @override
  String toString() => 'AmeCol(children: $children, align: $align)';
}

/// Horizontal row layout.
///
/// Named-only optional fields:
/// - [weights]: per-child flex weights for proportional width distribution.
///   null = all children intrinsic. 0 = intrinsic. >0 = fill.
/// - [crossAlign]: vertical alignment of children within the row.
///   null = center. Valid: Align.top, Align.center, Align.bottom.
///
/// Both default to null and are omitted from JSON when unset, so
/// conformance fixtures remain byte-identical.
final class AmeRow extends AmeNode {
  final List<AmeNode> children;
  final Align align;
  final int gap;
  final List<int>? weights;
  final Align? crossAlign;

  const AmeRow({
    this.children = const [],
    this.align = Align.start,
    this.gap = 8,
    this.weights,
    this.crossAlign,
  });

  factory AmeRow.fromJson(Map<String, dynamic> json) {
    final weightsRaw = json['weights'];
    final weights = weightsRaw is List
        ? weightsRaw.map((e) => (e as num).toInt()).toList()
        : null;
    return AmeRow(
      children: _childrenFromJson(json['children']),
      align: Align.fromString(json['align'] as String? ?? '') ?? Align.start,
      gap: (json['gap'] as num?)?.toInt() ?? 8,
      weights: weights,
      crossAlign: Align.fromString(json['cross_align'] as String? ?? ''),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'_type': 'row'};
    if (children.isNotEmpty) {
      map['children'] = children.map((c) => c.toJson()).toList();
    }
    if (align != Align.start) map['align'] = align.value;
    if (gap != 8) map['gap'] = gap;
    if (weights != null) map['weights'] = weights;
    if (crossAlign != null) map['cross_align'] = crossAlign!.value;
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AmeRow &&
          _listsEqual(children, other.children) &&
          align == other.align &&
          gap == other.gap &&
          _intListsEqual(weights, other.weights) &&
          crossAlign == other.crossAlign;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(children),
        align,
        gap,
        weights == null ? null : Object.hashAll(weights!),
        crossAlign,
      );

  @override
  String toString() =>
      'AmeRow(children: $children, align: $align, gap: $gap, weights: $weights, crossAlign: $crossAlign)';
}

// ── Content Primitives ───────────────────────────────────────────────────

/// Text display with typographic style.
final class AmeTxt extends AmeNode {
  final String text;
  final TxtStyle style;
  final int? maxLines;
  final SemanticColor? color;

  const AmeTxt({
    required this.text,
    this.style = TxtStyle.body,
    this.maxLines,
    this.color,
  });

  factory AmeTxt.fromJson(Map<String, dynamic> json) {
    return AmeTxt(
      text: json['text'] as String? ?? '',
      style:
          TxtStyle.fromString(json['style'] as String? ?? '') ?? TxtStyle.body,
      maxLines: (json['maxLines'] as num?)?.toInt(),
      color: json['color'] != null
          ? SemanticColor.fromString(json['color'] as String)
          : null,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'_type': 'txt'};
    if (color != null) map['color'] = color!.value;
    if (maxLines != null) map['maxLines'] = maxLines;
    if (style != TxtStyle.body) map['style'] = style.value;
    map['text'] = text;
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AmeTxt &&
          text == other.text &&
          style == other.style &&
          maxLines == other.maxLines &&
          color == other.color;

  @override
  int get hashCode => Object.hash(text, style, maxLines, color);

  @override
  String toString() =>
      'AmeTxt(text: $text, style: $style, maxLines: $maxLines, color: $color)';
}

/// Image loaded from a URL. Width fills available space.
final class AmeImg extends AmeNode {
  final String url;
  final int? height;

  const AmeImg({required this.url, this.height});

  factory AmeImg.fromJson(Map<String, dynamic> json) {
    return AmeImg(
      url: json['url'] as String? ?? '',
      height: (json['height'] as num?)?.toInt(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'_type': 'img'};
    if (height != null) map['height'] = height;
    map['url'] = url;
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AmeImg && url == other.url && height == other.height;

  @override
  int get hashCode => Object.hash(url, height);

  @override
  String toString() => 'AmeImg(url: $url, height: $height)';
}

/// Named Material icon.
final class AmeIcon extends AmeNode {
  final String name;
  final int size;

  const AmeIcon({required this.name, this.size = 20});

  factory AmeIcon.fromJson(Map<String, dynamic> json) {
    return AmeIcon(
      name: json['name'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 20,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'_type': 'icon', 'name': name};
    if (size != 20) map['size'] = size;
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AmeIcon && name == other.name && size == other.size;

  @override
  int get hashCode => Object.hash(name, size);

  @override
  String toString() => 'AmeIcon(name: $name, size: $size)';
}

/// Thin horizontal divider line. No arguments.
final class AmeDivider extends AmeNode {
  const AmeDivider();

  @override
  Map<String, dynamic> toJson() => {'_type': 'divider'};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AmeDivider;

  @override
  int get hashCode => 'divider'.hashCode;

  @override
  String toString() => 'AmeDivider()';
}

/// Vertical whitespace between elements.
final class AmeSpacer extends AmeNode {
  final int height;

  const AmeSpacer({this.height = 8});

  factory AmeSpacer.fromJson(Map<String, dynamic> json) {
    return AmeSpacer(height: (json['height'] as num?)?.toInt() ?? 8);
  }

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'_type': 'spacer'};
    if (height != 8) map['height'] = height;
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AmeSpacer && height == other.height;

  @override
  int get hashCode => height.hashCode;

  @override
  String toString() => 'AmeSpacer(height: $height)';
}

// ── Semantic Primitives ──────────────────────────────────────────────────

/// Elevated container grouping related content.
final class AmeCard extends AmeNode {
  final List<AmeNode> children;
  final int elevation;

  const AmeCard({this.children = const [], this.elevation = 1});

  factory AmeCard.fromJson(Map<String, dynamic> json) {
    return AmeCard(
      children: _childrenFromJson(json['children']),
      elevation: (json['elevation'] as num?)?.toInt() ?? 1,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'_type': 'card'};
    if (children.isNotEmpty) {
      map['children'] = children.map((c) => c.toJson()).toList();
    }
    if (elevation != 1) map['elevation'] = elevation;
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AmeCard &&
          _listsEqual(children, other.children) &&
          elevation == other.elevation;

  @override
  int get hashCode => Object.hash(Object.hashAll(children), elevation);

  @override
  String toString() =>
      'AmeCard(children: $children, elevation: $elevation)';
}

/// Small colored label for status indicators, counts, or categories.
final class AmeBadge extends AmeNode {
  final String label;
  final BadgeVariant variant;
  final SemanticColor? color;

  const AmeBadge({
    required this.label,
    this.variant = BadgeVariant.defaultVariant,
    this.color,
  });

  factory AmeBadge.fromJson(Map<String, dynamic> json) {
    return AmeBadge(
      label: json['label'] as String? ?? '',
      variant: BadgeVariant.fromString(json['variant'] as String? ?? '') ??
          BadgeVariant.defaultVariant,
      color: json['color'] != null
          ? SemanticColor.fromString(json['color'] as String)
          : null,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'_type': 'badge'};
    if (color != null) map['color'] = color!.value;
    map['label'] = label;
    if (variant != BadgeVariant.defaultVariant) map['variant'] = variant.value;
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AmeBadge &&
          label == other.label &&
          variant == other.variant &&
          color == other.color;

  @override
  int get hashCode => Object.hash(label, variant, color);

  @override
  String toString() =>
      'AmeBadge(label: $label, variant: $variant, color: $color)';
}

/// Horizontal progress bar with optional label. Value clamped to 0.0–1.0.
final class AmeProgress extends AmeNode {
  final double value;
  final String? label;

  const AmeProgress({required this.value, this.label});

  factory AmeProgress.fromJson(Map<String, dynamic> json) {
    return AmeProgress(
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      label: json['label'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'_type': 'progress'};
    if (label != null) map['label'] = label;
    map['value'] = value;
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AmeProgress && value == other.value && label == other.label;

  @override
  int get hashCode => Object.hash(value, label);

  @override
  String toString() => 'AmeProgress(value: $value, label: $label)';
}

// ── Interactive Primitives ───────────────────────────────────────────────

/// Tappable button that triggers an action.
final class AmeBtn extends AmeNode {
  final String label;
  final AmeAction action;
  final BtnStyle style;
  final String? icon;

  const AmeBtn({
    required this.label,
    required this.action,
    this.style = BtnStyle.primary,
    this.icon,
  });

  factory AmeBtn.fromJson(Map<String, dynamic> json) {
    return AmeBtn(
      label: json['label'] as String? ?? '',
      action: AmeAction.fromJson(json['action'] as Map<String, dynamic>? ?? {})
          ?? const AmeNavigate(route: '_error_no_action'),
      style:
          BtnStyle.fromString(json['style'] as String? ?? '') ?? BtnStyle.primary,
      icon: json['icon'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'_type': 'btn', 'action': action.toJson()};
    if (icon != null) map['icon'] = icon;
    map['label'] = label;
    if (style != BtnStyle.primary) map['style'] = style.value;
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AmeBtn &&
          label == other.label &&
          action == other.action &&
          style == other.style &&
          icon == other.icon;

  @override
  int get hashCode => Object.hash(label, action, style, icon);

  @override
  String toString() =>
      'AmeBtn(label: $label, action: $action, style: $style, icon: $icon)';
}

/// Form input field.
final class AmeInput extends AmeNode {
  final String id;
  final String label;
  final InputType type;
  final List<String>? options;

  const AmeInput({
    required this.id,
    required this.label,
    this.type = InputType.text,
    this.options,
  });

  factory AmeInput.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    final List<String>? options;
    if (rawOptions is List) {
      options = rawOptions.map((e) => e.toString()).toList();
    } else {
      options = null;
    }
    return AmeInput(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      type: InputType.fromString(json['type'] as String? ?? '') ??
          InputType.text,
      options: options,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'_type': 'input', 'id': id, 'label': label};
    if (options != null) map['options'] = options;
    if (type != InputType.text) map['type'] = type.value;
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AmeInput &&
          id == other.id &&
          label == other.label &&
          type == other.type &&
          _nullableStringListsEqual(options, other.options);

  @override
  int get hashCode =>
      Object.hash(id, label, type, options == null ? null : Object.hashAll(options!));

  @override
  String toString() =>
      'AmeInput(id: $id, label: $label, type: $type, options: $options)';
}

/// Labeled toggle switch for boolean choices.
/// Field is named [defaultValue] because `default` is reserved in Dart.
/// Serializes as "default" in JSON.
final class AmeToggle extends AmeNode {
  final String id;
  final String label;
  final bool defaultValue;

  const AmeToggle({
    required this.id,
    required this.label,
    this.defaultValue = false,
  });

  factory AmeToggle.fromJson(Map<String, dynamic> json) {
    return AmeToggle(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      defaultValue: json['default'] as bool? ?? false,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'_type': 'toggle'};
    if (defaultValue != false) map['default'] = defaultValue;
    map['id'] = id;
    map['label'] = label;
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AmeToggle &&
          id == other.id &&
          label == other.label &&
          defaultValue == other.defaultValue;

  @override
  int get hashCode => Object.hash(id, label, defaultValue);

  @override
  String toString() =>
      'AmeToggle(id: $id, label: $label, defaultValue: $defaultValue)';
}

// ── Data Primitives ──────────────────────────────────────────────────────

/// Vertical list of children, optionally separated by dividers.
final class AmeDataList extends AmeNode {
  final List<AmeNode> children;
  final bool dividers;

  const AmeDataList({this.children = const [], this.dividers = true});

  factory AmeDataList.fromJson(Map<String, dynamic> json) {
    return AmeDataList(
      children: _childrenFromJson(json['children']),
      dividers: json['dividers'] as bool? ?? true,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'_type': 'list'};
    if (children.isNotEmpty) {
      map['children'] = children.map((c) => c.toJson()).toList();
    }
    if (dividers != true) map['dividers'] = dividers;
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AmeDataList &&
          _listsEqual(children, other.children) &&
          dividers == other.dividers;

  @override
  int get hashCode => Object.hash(Object.hashAll(children), dividers);

  @override
  String toString() =>
      'AmeDataList(children: $children, dividers: $dividers)';
}

/// Grid of text values with a header row.
final class AmeTable extends AmeNode {
  final List<String> headers;
  final List<List<String>> rows;

  const AmeTable({required this.headers, required this.rows});

  factory AmeTable.fromJson(Map<String, dynamic> json) {
    final rawHeaders = json['headers'];
    final List<String> headers;
    if (rawHeaders is List) {
      headers = rawHeaders.map((e) => e.toString()).toList();
    } else {
      headers = const [];
    }
    final rawRows = json['rows'];
    final List<List<String>> rows;
    if (rawRows is List) {
      rows = rawRows.map((row) {
        if (row is List) {
          return row.map((e) => e.toString()).toList();
        }
        return <String>[];
      }).toList();
    } else {
      rows = const [];
    }
    return AmeTable(headers: headers, rows: rows);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      '_type': 'table',
      'headers': headers,
      'rows': rows,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AmeTable &&
          _stringListsEqual(headers, other.headers) &&
          _nestedStringListsEqual(rows, other.rows);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(headers), Object.hashAll(rows.map(Object.hashAll)));

  @override
  String toString() => 'AmeTable(headers: $headers, rows: $rows)';
}

/// Structured single-row list entry with title, optional subtitle, optional
/// leading and trailing nodes, and an optional whole-row tap action.
///
/// Nested click target rule (NORMATIVE): when both [action] and [trailing]
/// are present and [trailing] is itself an interactive node (AmeBtn), the
/// renderer MUST isolate the trailing tap so it does not also fire [action].
/// See `specification/v1.0/primitives.md` §list_item for the full rule and
/// platform-specific guidance.
///
/// [action] is named-only in AME source: list_item("Title", action=nav("/x")).
/// Positional slots are reserved for title, subtitle, leading, trailing.
final class AmeListItem extends AmeNode {
  final String title;
  final String? subtitle;
  final AmeNode? leading;
  final AmeNode? trailing;
  final AmeAction? action;

  const AmeListItem({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.action,
  });

  factory AmeListItem.fromJson(Map<String, dynamic> json) {
    final leadingJson = json['leading'];
    final trailingJson = json['trailing'];
    final actionJson = json['action'];
    return AmeListItem(
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      leading: leadingJson is Map<String, dynamic>
          ? AmeNode.fromJson(leadingJson)
          : null,
      trailing: trailingJson is Map<String, dynamic>
          ? AmeNode.fromJson(trailingJson)
          : null,
      action: actionJson is Map<String, dynamic>
          ? AmeAction.fromJson(actionJson)
          : null,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'_type': 'list_item', 'title': title};
    if (subtitle != null) map['subtitle'] = subtitle;
    if (leading != null) map['leading'] = leading!.toJson();
    if (trailing != null) map['trailing'] = trailing!.toJson();
    if (action != null) map['action'] = action!.toJson();
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AmeListItem &&
          title == other.title &&
          subtitle == other.subtitle &&
          leading == other.leading &&
          trailing == other.trailing &&
          action == other.action;

  @override
  int get hashCode =>
      Object.hash(title, subtitle, leading, trailing, action);

  @override
  String toString() =>
      'AmeListItem(title: $title, subtitle: $subtitle, leading: $leading, trailing: $trailing, action: $action)';
}

// ── Visualization Primitives ─────────────────────────────────────────────

/// Data visualization chart. Supports line, bar, pie, and sparkline types.
///
/// [values] is the primary data series. [series] overrides [values] for
/// multi-series charts. Both accept `$path` references to data model arrays.
///
/// [valuesPath], [labelsPath], [seriesPath], [seriesPaths] store
/// unresolved `$path` references when data binding is deferred. After
/// `_resolveTree`, these are null and the resolved data populates
/// [values], [labels], [series].
///
/// [seriesPath] holds a single `$path` that resolves to a 2D array (the
/// multi-series matrix lives at one location in the data model).
/// [seriesPaths] holds an array of `$path` references where each path
/// resolves to a 1D array (one series per path). This corresponds to the
/// spec syntax `series=[$a, $b]`. Resolution is all-or-nothing: if any
/// path fails to resolve, [series] stays null so the renderer shows the
/// empty state rather than a misleading partial chart.
final class AmeChart extends AmeNode {
  final ChartType type;
  final List<double>? values;
  final List<String>? labels;
  final List<List<double>>? series;
  final int height;
  final SemanticColor? color;
  final String? valuesPath;
  final String? labelsPath;
  final String? seriesPath;
  final List<String>? seriesPaths;

  const AmeChart({
    required this.type,
    this.values,
    this.labels,
    this.series,
    this.height = 200,
    this.color,
    this.valuesPath,
    this.labelsPath,
    this.seriesPath,
    this.seriesPaths,
  });

  AmeChart copyWith({
    ChartType? type,
    List<double>? Function()? values,
    List<String>? Function()? labels,
    List<List<double>>? Function()? series,
    int? height,
    SemanticColor? Function()? color,
    String? Function()? valuesPath,
    String? Function()? labelsPath,
    String? Function()? seriesPath,
    List<String>? Function()? seriesPaths,
  }) {
    return AmeChart(
      type: type ?? this.type,
      values: values != null ? values() : this.values,
      labels: labels != null ? labels() : this.labels,
      series: series != null ? series() : this.series,
      height: height ?? this.height,
      color: color != null ? color() : this.color,
      valuesPath: valuesPath != null ? valuesPath() : this.valuesPath,
      labelsPath: labelsPath != null ? labelsPath() : this.labelsPath,
      seriesPath: seriesPath != null ? seriesPath() : this.seriesPath,
      seriesPaths: seriesPaths != null ? seriesPaths() : this.seriesPaths,
    );
  }

  factory AmeChart.fromJson(Map<String, dynamic> json) {
    return AmeChart(
      type: ChartType.fromString(json['type'] as String? ?? '') ??
          ChartType.bar,
      values: _doubleListFromJson(json['values']),
      labels: _stringListFromJson(json['labels']),
      series: _nestedDoubleListFromJson(json['series']),
      height: (json['height'] as num?)?.toInt() ?? 200,
      color: json['color'] != null
          ? SemanticColor.fromString(json['color'] as String)
          : null,
      valuesPath: json['valuesPath'] as String?,
      labelsPath: json['labelsPath'] as String?,
      seriesPath: json['seriesPath'] as String?,
      seriesPaths: _stringListFromJson(json['seriesPaths']),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'_type': 'chart'};
    if (color != null) map['color'] = color!.value;
    if (height != 200) map['height'] = height;
    if (labels != null) map['labels'] = labels;
    if (labelsPath != null) map['labelsPath'] = labelsPath;
    if (series != null) map['series'] = series;
    if (seriesPath != null) map['seriesPath'] = seriesPath;
    if (seriesPaths != null) map['seriesPaths'] = seriesPaths;
    map['type'] = type.value;
    if (values != null) map['values'] = values;
    if (valuesPath != null) map['valuesPath'] = valuesPath;
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AmeChart &&
          type == other.type &&
          _nullableDoubleListsEqual(values, other.values) &&
          _nullableStringListsEqual(labels, other.labels) &&
          _nullableNestedDoubleListsEqual(series, other.series) &&
          height == other.height &&
          color == other.color &&
          valuesPath == other.valuesPath &&
          labelsPath == other.labelsPath &&
          seriesPath == other.seriesPath &&
          _nullableStringListsEqual(seriesPaths, other.seriesPaths);

  @override
  int get hashCode => Object.hash(
        type,
        values == null ? null : Object.hashAll(values!),
        labels == null ? null : Object.hashAll(labels!),
        series == null ? null : Object.hashAll(series!.map(Object.hashAll)),
        height,
        color,
        valuesPath,
        labelsPath,
        seriesPath,
        seriesPaths == null ? null : Object.hashAll(seriesPaths!),
      );

  @override
  String toString() =>
      'AmeChart(type: $type, values: $values, labels: $labels, series: $series, height: $height, color: $color)';
}

// ── Rich Content Primitives ──────────────────────────────────────────────

/// Syntax-highlighted code block with copy affordance.
final class AmeCode extends AmeNode {
  final String language;
  final String content;
  final String? title;

  const AmeCode({
    required this.language,
    required this.content,
    this.title,
  });

  factory AmeCode.fromJson(Map<String, dynamic> json) {
    return AmeCode(
      language: json['language'] as String? ?? '',
      content: json['content'] as String? ?? '',
      title: json['title'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      '_type': 'code',
      'content': content,
      'language': language,
    };
    if (title != null) map['title'] = title;
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AmeCode &&
          language == other.language &&
          content == other.content &&
          title == other.title;

  @override
  int get hashCode => Object.hash(language, content, title);

  @override
  String toString() =>
      'AmeCode(language: $language, content: $content, title: $title)';
}

// ── Disclosure Primitives ────────────────────────────────────────────────

/// Collapsible section.
final class AmeAccordion extends AmeNode {
  final String title;
  final List<AmeNode> children;
  final bool expanded;

  const AmeAccordion({
    required this.title,
    this.children = const [],
    this.expanded = false,
  });

  factory AmeAccordion.fromJson(Map<String, dynamic> json) {
    return AmeAccordion(
      title: json['title'] as String? ?? '',
      children: _childrenFromJson(json['children']),
      expanded: json['expanded'] as bool? ?? false,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'_type': 'accordion'};
    if (children.isNotEmpty) {
      map['children'] = children.map((c) => c.toJson()).toList();
    }
    if (expanded != false) map['expanded'] = expanded;
    map['title'] = title;
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AmeAccordion &&
          title == other.title &&
          _listsEqual(children, other.children) &&
          expanded == other.expanded;

  @override
  int get hashCode => Object.hash(title, Object.hashAll(children), expanded);

  @override
  String toString() =>
      'AmeAccordion(title: $title, children: $children, expanded: $expanded)';
}

/// Horizontally scrollable container.
final class AmeCarousel extends AmeNode {
  final List<AmeNode> children;
  final int peek;

  const AmeCarousel({this.children = const [], this.peek = 24});

  factory AmeCarousel.fromJson(Map<String, dynamic> json) {
    return AmeCarousel(
      children: _childrenFromJson(json['children']),
      peek: (json['peek'] as num?)?.toInt() ?? 24,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'_type': 'carousel'};
    if (children.isNotEmpty) {
      map['children'] = children.map((c) => c.toJson()).toList();
    }
    if (peek != 24) map['peek'] = peek;
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AmeCarousel &&
          _listsEqual(children, other.children) &&
          peek == other.peek;

  @override
  int get hashCode => Object.hash(Object.hashAll(children), peek);

  @override
  String toString() => 'AmeCarousel(children: $children, peek: $peek)';
}

// ── Alert Primitives ─────────────────────────────────────────────────────

/// Visually distinct alert/info box with type-specific icon and tint.
///
/// [color] is an optional [SemanticColor] override per primitives.md.
/// When non-null it overrides the type-derived tint at render time.
/// Omitted from JSON when null to preserve byte-equality on existing
/// fixtures.
final class AmeCallout extends AmeNode {
  final CalloutType type;
  final String content;
  final String? title;
  final SemanticColor? color;

  const AmeCallout({
    required this.type,
    required this.content,
    this.title,
    this.color,
  });

  factory AmeCallout.fromJson(Map<String, dynamic> json) {
    return AmeCallout(
      type: CalloutType.fromString(json['type'] as String? ?? '') ??
          CalloutType.info,
      content: json['content'] as String? ?? '',
      title: json['title'] as String?,
      color: json['color'] != null
          ? SemanticColor.fromString(json['color'] as String)
          : null,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'_type': 'callout', 'content': content};
    if (color != null) map['color'] = color!.value;
    if (title != null) map['title'] = title;
    map['type'] = type.value;
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AmeCallout &&
          type == other.type &&
          content == other.content &&
          title == other.title &&
          color == other.color;

  @override
  int get hashCode => Object.hash(type, content, title, color);

  @override
  String toString() =>
      'AmeCallout(type: $type, content: $content, title: $title, color: $color)';
}

// ── Sequence Primitives ──────────────────────────────────────────────────

/// Ordered vertical event sequence with status connectors.
final class AmeTimeline extends AmeNode {
  final List<AmeNode> children;

  const AmeTimeline({this.children = const []});

  factory AmeTimeline.fromJson(Map<String, dynamic> json) {
    return AmeTimeline(children: _childrenFromJson(json['children']));
  }

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'_type': 'timeline'};
    if (children.isNotEmpty) {
      map['children'] = children.map((c) => c.toJson()).toList();
    }
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AmeTimeline && _listsEqual(children, other.children);

  @override
  int get hashCode => Object.hashAll(children);

  @override
  String toString() => 'AmeTimeline(children: $children)';
}

/// Single step in a timeline.
final class AmeTimelineItem extends AmeNode {
  final String title;
  final String? subtitle;
  final TimelineStatus status;

  const AmeTimelineItem({
    required this.title,
    this.subtitle,
    this.status = TimelineStatus.pending,
  });

  factory AmeTimelineItem.fromJson(Map<String, dynamic> json) {
    return AmeTimelineItem(
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      status: TimelineStatus.fromString(json['status'] as String? ?? '') ??
          TimelineStatus.pending,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'_type': 'timeline_item'};
    if (status != TimelineStatus.pending) map['status'] = status.value;
    if (subtitle != null) map['subtitle'] = subtitle;
    map['title'] = title;
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AmeTimelineItem &&
          title == other.title &&
          subtitle == other.subtitle &&
          status == other.status;

  @override
  int get hashCode => Object.hash(title, subtitle, status);

  @override
  String toString() =>
      'AmeTimelineItem(title: $title, subtitle: $subtitle, status: $status)';
}

// ── Structural Types (non-visual) ────────────────────────────────────────

/// Unresolved forward reference during streaming.
final class AmeRef extends AmeNode {
  final String id;

  const AmeRef({required this.id});

  factory AmeRef.fromJson(Map<String, dynamic> json) {
    return AmeRef(id: json['id'] as String? ?? '');
  }

  @override
  Map<String, dynamic> toJson() => {'_type': 'ref', 'id': id};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AmeRef && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AmeRef(id: $id)';
}

/// Data iteration construct.
final class AmeEach extends AmeNode {
  final String dataPath;
  final String templateId;

  const AmeEach({required this.dataPath, required this.templateId});

  factory AmeEach.fromJson(Map<String, dynamic> json) {
    return AmeEach(
      dataPath: json['dataPath'] as String? ?? '',
      templateId: json['templateId'] as String? ?? '',
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        '_type': 'each',
        'dataPath': dataPath,
        'templateId': templateId,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AmeEach &&
          dataPath == other.dataPath &&
          templateId == other.templateId;

  @override
  int get hashCode => Object.hash(dataPath, templateId);

  @override
  String toString() =>
      'AmeEach(dataPath: $dataPath, templateId: $templateId)';
}

// ── Private Helpers ──────────────────────────────────────────────────────

List<AmeNode> _childrenFromJson(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map<String, dynamic>>()
      .map((e) => AmeNode.fromJson(e))
      .whereType<AmeNode>()
      .toList();
}

List<double>? _doubleListFromJson(dynamic raw) {
  if (raw is! List) return null;
  return raw.map((e) => (e as num).toDouble()).toList();
}

List<String>? _stringListFromJson(dynamic raw) {
  if (raw is! List) return null;
  return raw.map((e) => e.toString()).toList();
}

List<List<double>>? _nestedDoubleListFromJson(dynamic raw) {
  if (raw is! List) return null;
  return raw.map((inner) {
    if (inner is! List) return <double>[];
    return inner.map((e) => (e as num).toDouble()).toList();
  }).toList();
}

bool _listsEqual(List<AmeNode> a, List<AmeNode> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _stringListsEqual(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _intListsEqual(List<int>? a, List<int>? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _nullableStringListsEqual(List<String>? a, List<String>? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  return _stringListsEqual(a, b);
}

bool _nestedStringListsEqual(List<List<String>> a, List<List<String>> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!_stringListsEqual(a[i], b[i])) return false;
  }
  return true;
}

bool _nullableDoubleListsEqual(List<double>? a, List<double>? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _nullableNestedDoubleListsEqual(
    List<List<double>>? a, List<List<double>>? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!_nullableDoubleListsEqual(a[i], b[i])) return false;
  }
  return true;
}
