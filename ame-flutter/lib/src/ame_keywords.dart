import 'ame_types.dart';

/// Reserved keywords and parser lookup utilities.
/// All sets match the Reserved Keywords section of syntax.md exactly.
class AmeKeywords {
  AmeKeywords._();

  static const standardPrimitives = <String>{
    'col', 'row', 'txt', 'btn', 'card', 'badge', 'icon', 'img',
    'input', 'toggle', 'list', 'list_item', 'table', 'divider', 'spacer',
    'progress', 'chart', 'code', 'accordion', 'carousel', 'callout',
    'timeline', 'timeline_item',
  };

  static const actionNames = <String>{
    'tool', 'uri', 'nav', 'copy', 'submit',
  };

  static const structuralKeywords = <String>{'each', 'root'};

  static const booleanLiterals = <String>{'true', 'false'};

  static const dataSeparator = '---';

  static bool isReserved(String identifier) =>
      standardPrimitives.contains(identifier) ||
      actionNames.contains(identifier) ||
      structuralKeywords.contains(identifier) ||
      booleanLiterals.contains(identifier);

  static Align? parseAlign(String value) => Align.fromString(value);
  static TxtStyle? parseTxtStyle(String value) => TxtStyle.fromString(value);
  static BtnStyle? parseBtnStyle(String value) => BtnStyle.fromString(value);
  static BadgeVariant? parseBadgeVariant(String value) =>
      BadgeVariant.fromString(value);
  static InputType? parseInputType(String value) =>
      InputType.fromString(value);
  static ChartType? parseChartType(String value) =>
      ChartType.fromString(value);
  static CalloutType? parseCalloutType(String value) =>
      CalloutType.fromString(value);
  static TimelineStatus? parseTimelineStatus(String value) =>
      TimelineStatus.fromString(value);
  static SemanticColor? parseSemanticColor(String value) =>
      SemanticColor.fromString(value);
}
