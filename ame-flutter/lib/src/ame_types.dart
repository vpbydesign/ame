/// Horizontal/vertical alignment for layout primitives.
/// col supports: start, center, end
/// row main-axis (align): start, center, end, space_between, space_around
/// row cross-axis (crossAlign): top, center, bottom
enum Align {
  start('start'),
  center('center'),
  end('end'),
  spaceBetween('space_between'),
  spaceAround('space_around'),
  top('top'),
  bottom('bottom');

  const Align(this.value);
  final String value;

  static Align? fromString(String s) {
    for (final e in Align.values) {
      if (e.value.toLowerCase() == s.toLowerCase()) return e;
    }
    return null;
  }
}

/// Typographic style for txt primitive.
enum TxtStyle {
  display('display'),
  headline('headline'),
  title('title'),
  body('body'),
  caption('caption'),
  mono('mono'),
  label('label'),
  overline('overline');

  const TxtStyle(this.value);
  final String value;

  static TxtStyle? fromString(String s) {
    for (final e in TxtStyle.values) {
      if (e.value.toLowerCase() == s.toLowerCase()) return e;
    }
    return null;
  }
}

/// Visual style for btn primitive.
enum BtnStyle {
  primary('primary'),
  secondary('secondary'),
  outline('outline'),
  text('text'),
  destructive('destructive');

  const BtnStyle(this.value);
  final String value;

  static BtnStyle? fromString(String s) {
    for (final e in BtnStyle.values) {
      if (e.value.toLowerCase() == s.toLowerCase()) return e;
    }
    return null;
  }
}

/// Color variant for badge primitive.
/// [defaultVariant] serializes as "default" in JSON — Dart reserves the word.
enum BadgeVariant {
  defaultVariant('default'),
  success('success'),
  warning('warning'),
  error('error'),
  info('info');

  const BadgeVariant(this.value);
  final String value;

  static BadgeVariant? fromString(String s) {
    for (final e in BadgeVariant.values) {
      if (e.value.toLowerCase() == s.toLowerCase()) return e;
    }
    return null;
  }
}

/// Input field type for input primitive.
enum InputType {
  text('text'),
  number('number'),
  email('email'),
  phone('phone'),
  date('date'),
  time('time'),
  select('select');

  const InputType(this.value);
  final String value;

  static InputType? fromString(String s) {
    for (final e in InputType.values) {
      if (e.value.toLowerCase() == s.toLowerCase()) return e;
    }
    return null;
  }
}

/// Chart visualization type.
enum ChartType {
  line('line'),
  bar('bar'),
  pie('pie'),
  sparkline('sparkline');

  const ChartType(this.value);
  final String value;

  static ChartType? fromString(String s) {
    for (final e in ChartType.values) {
      if (e.value.toLowerCase() == s.toLowerCase()) return e;
    }
    return null;
  }
}

/// Callout alert type — determines icon and background tint.
enum CalloutType {
  info('info'),
  warning('warning'),
  error('error'),
  success('success'),
  tip('tip');

  const CalloutType(this.value);
  final String value;

  static CalloutType? fromString(String s) {
    for (final e in CalloutType.values) {
      if (e.value.toLowerCase() == s.toLowerCase()) return e;
    }
    return null;
  }
}

/// Timeline step status — determines circle style and connector line.
enum TimelineStatus {
  done('done'),
  active('active'),
  pending('pending'),
  error('error');

  const TimelineStatus(this.value);
  final String value;

  static TimelineStatus? fromString(String s) {
    for (final e in TimelineStatus.values) {
      if (e.value.toLowerCase() == s.toLowerCase()) return e;
    }
    return null;
  }
}

/// Semantic color token for platform-consistent coloring.
enum SemanticColor {
  primary('primary'),
  secondary('secondary'),
  error('error'),
  success('success'),
  warning('warning');

  const SemanticColor(this.value);
  final String value;

  static SemanticColor? fromString(String s) {
    for (final e in SemanticColor.values) {
      if (e.value.toLowerCase() == s.toLowerCase()) return e;
    }
    return null;
  }
}
