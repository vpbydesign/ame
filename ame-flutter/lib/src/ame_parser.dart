import 'dart:convert';

import 'ame_action.dart';
import 'ame_keywords.dart';
import 'ame_node.dart';
import 'ame_types.dart';

/// Line-oriented streaming parser that converts AME syntax text into an AmeNode tree.
///
/// Two modes:
/// - Batch: parse(input) -> AmeNode? — parses entire document, returns resolved tree
/// - Streaming: parseLine(line) -> (String, AmeNode)? — parses one line, may contain Ref nodes
///
/// Implements the EBNF grammar from syntax.md exactly. Handles all 7 error cases
/// without crashing. Never throws unrecoverable exceptions on any input.
class AmeParser {
  final Map<String, AmeNode> _registry = {};
  Map<String, dynamic>? _dataModel;
  final List<String> _warnings = [];
  final List<String> _errors = [];

  // Streaming-mode data section state (Bug 32, Flutter analog of v1.2 Bug 8).
  //
  // When `parseLine()` is the only ingest API in use, calling
  // `parseLine("---")` flips `_streamingDataMode` on, and subsequent
  // `parseLine()` calls accumulate non-letter-prefixed lines (JSON
  // content) into `_streamingDataBuffer` until `getResolvedTree()`
  // finalizes by parsing the buffer through `_parseDataSection`.
  // `_streamingDataApplied` guards idempotence so repeated
  // `getResolvedTree()` calls do not re-parse the buffer.
  //
  // The batch `parse()` entry path manages its own `dataLines`
  // accumulator and never trips this state machine.
  bool _streamingDataMode = false;
  final StringBuffer _streamingDataBuffer = StringBuffer();
  bool _streamingDataApplied = false;

  List<String> get warnings => List.unmodifiable(_warnings);
  List<String> get errors => List.unmodifiable(_errors);

  // ── Batch Mode ─────────────────────────────────────────────────────

  AmeNode? parse(String input) {
    reset();
    final lines = input.split('\n');
    var inDataSection = false;
    final dataLines = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed == AmeKeywords.dataSeparator) {
        if (inDataSection) {
          _warnings
              .add('Multiple --- separators found; ignoring subsequent ones');
        } else {
          inDataSection = true;
        }
        continue;
      }
      if (inDataSection) {
        dataLines.add(line);
      } else {
        parseLine(trimmed);
      }
    }

    if (dataLines.isNotEmpty) {
      _parseDataSection(dataLines.join('\n'));
    }

    final root = _registry['root'];
    if (root == null) return null;
    return _resolveTree(root);
  }

  // ── Streaming Mode ─────────────────────────────────────────────────

  (String, AmeNode)? parseLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('//')) return null;
    if (trimmed == AmeKeywords.dataSeparator) {
      // Bug 32 fix (Flutter analog of v1.2 Bug 8): flip streaming-mode
      // data accumulator on. Subsequent parseLine() calls feed
      // _streamingDataBuffer until the next reset(). Mirrors the batch
      // parse() warning when the separator appears twice on the same
      // parser lifetime.
      if (_streamingDataMode) {
        _warnings.add('Multiple --- separators found; ignoring subsequent ones');
      } else {
        _streamingDataMode = true;
        _streamingDataApplied = false;
      }
      return null;
    }
    if (_streamingDataMode) {
      // Disambiguate JSON content from AME identifier definitions in
      // streaming mode. AME identifiers are required to start with a
      // letter (see the identifier-shape check below), so a letter-prefixed
      // line is AME and anything else (`{`, `}`, `[`, `]`, `"`, digit,
      // sign, whitespace) accumulates into the JSON buffer. This lets
      // streaming consumers emit either order: AME-then-`---`-then-JSON
      // (mirrors batch parse()) or `---`-then-JSON-then-AME (the audit
      // test's contract).
      final firstChar = trimmed.codeUnitAt(0);
      if (!_isLetter(firstChar)) {
        _streamingDataBuffer.write(line);
        _streamingDataBuffer.write('\n');
        return null;
      }
      // Falls through to AME identifier handling below.
    }

    final equalsIndex = trimmed.indexOf('=');
    if (equalsIndex == -1) {
      _errors.add("Malformed line (no '='): $trimmed");
      return null;
    }

    final identifier = trimmed.substring(0, equalsIndex).trim();
    final expression = trimmed.substring(equalsIndex + 1).trim();

    if (identifier.isEmpty || !_isLetter(identifier.codeUnitAt(0))) {
      _errors.add("Invalid identifier '$identifier' on line: $trimmed");
      return null;
    }

    if (_registry.containsKey(identifier)) {
      _warnings.add(
          "Duplicate identifier '$identifier' \u2014 replacing previous definition");
    }

    try {
      final node = _parseExpression(expression);
      _registry[identifier] = node;
      return (identifier, node);
    } catch (e) {
      _errors.add("Parse error on line '$trimmed': $e");
      return null;
    }
  }

  void reset() {
    _registry.clear();
    _dataModel = null;
    _warnings.clear();
    _errors.clear();
    _streamingDataMode = false;
    _streamingDataBuffer.clear();
    _streamingDataApplied = false;
  }

  AmeNode? getResolvedTree() {
    // Bug 32 fix: finalize the streaming data buffer (if any) before
    // resolving. Guarded by `_dataModel == null` so a prior batch
    // parse() that already populated _dataModel takes precedence
    // (mixed-mode safety, per the streaming.md contract). Guarded by
    // `!_streamingDataApplied` so repeated getResolvedTree() calls are
    // idempotent.
    if (_streamingDataBuffer.isNotEmpty &&
        _dataModel == null &&
        !_streamingDataApplied) {
      _parseDataSection(_streamingDataBuffer.toString());
      _streamingDataApplied = true;
    }
    final root = _registry['root'];
    if (root == null) return null;
    return _resolveTree(root);
  }

  Map<String, AmeNode> getRegistry() => Map.unmodifiable(_registry);

  Map<String, dynamic>? getDataModel() => _dataModel;

  String? resolveDataPath(String path) {
    final model = _dataModel;
    if (model == null) return null;
    final segments = path.replaceFirst('\$', '').split('/');
    dynamic current = model;
    for (final segment in segments) {
      if (current is Map<String, dynamic>) {
        if (!current.containsKey(segment)) return null;
        current = current[segment];
      } else {
        return null;
      }
    }
    if (current is String) return current;
    if (current is num) return current.toString();
    if (current is bool) return current.toString();
    return null;
  }

  // ── Expression Parsing (Recursive Descent) ─────────────────────────

  AmeNode _parseExpression(String expr) {
    final trimmed = expr.trim();
    if (trimmed.isEmpty) {
      return const AmeTxt(text: '');
    }

    if (trimmed.startsWith('"')) {
      return AmeTxt(text: _parseStringLiteral(trimmed));
    }

    if (trimmed.startsWith('\$')) {
      return AmeTxt(text: trimmed);
    }

    if (trimmed.startsWith('[')) {
      final items = _parseArray(trimmed);
      final children = items.map(_expressionToNode).toList();
      return AmeCol(children: children);
    }

    final parenIndex = _findTopLevelParen(trimmed);
    if (parenIndex != -1) {
      final name = trimmed.substring(0, parenIndex).trim();
      final argsStr = _extractParenContent(trimmed, parenIndex);
      return _parseComponentCall(name, argsStr);
    }

    if (trimmed == 'true' || trimmed == 'false') {
      return AmeTxt(text: trimmed);
    }

    return AmeRef(id: trimmed);
  }

  // ── Intermediate Parsed Value System ───────────────────────────────

  _ParsedValue _parseArgValue(String arg) {
    final trimmed = arg.trim();
    if (trimmed.isEmpty) return const _PvStr('');

    final namedEq = _findNamedArgEquals(trimmed);
    if (namedEq != -1) {
      final key = trimmed.substring(0, namedEq).trim();
      final valStr = trimmed.substring(namedEq + 1).trim();
      return _PvNamedArg(key, _parseArgValue(valStr));
    }

    if (trimmed.startsWith('"')) {
      return _PvStr(_parseStringLiteral(trimmed));
    }

    if (trimmed.startsWith('\$')) {
      return _PvDataRef(trimmed.substring(1));
    }

    if (trimmed.startsWith('[')) {
      return _PvArr(_parseArray(trimmed));
    }

    if (trimmed == 'true') return const _PvBool(true);
    if (trimmed == 'false') return const _PvBool(false);

    if (_isDigit(trimmed.codeUnitAt(0)) ||
        (trimmed.codeUnitAt(0) == 0x2D &&
            trimmed.length > 1 &&
            _isDigit(trimmed.codeUnitAt(1)))) {
      return _parseNumber(trimmed);
    }

    final parenIdx = _findTopLevelParen(trimmed);
    if (parenIdx != -1) {
      final name = trimmed.substring(0, parenIdx).trim();
      final argsContent = _extractParenContent(trimmed, parenIdx);

      if (AmeKeywords.actionNames.contains(name)) {
        return _PvActionValue(_parseActionCall(name, argsContent));
      }
      if (AmeKeywords.standardPrimitives.contains(name) || name == 'each') {
        return _PvNodeValue(_parseComponentCall(name, argsContent));
      }
      return _PvNodeValue(_parseComponentCall(name, argsContent));
    }

    return _PvIdent(trimmed);
  }

  AmeNode _expressionToNode(String exprStr) {
    final parsed = _parseArgValue(exprStr.trim());
    return switch (parsed) {
      _PvNodeValue(node: final n) => n,
      _PvIdent(name: final n) => AmeRef(id: n),
      _PvStr(value: final v) => AmeTxt(text: v),
      _PvDataRef(path: final p) => AmeTxt(text: '\$$p'),
      _PvNum(intVal: final i, floatVal: final f) =>
        AmeTxt(text: i?.toString() ?? f?.toString() ?? '0'),
      _PvBool(value: final v) => AmeTxt(text: v.toString()),
      _PvArr(items: final items) =>
        AmeCol(children: items.map(_expressionToNode).toList()),
      _PvActionValue(action: final a) => AmeTxt(text: 'action:$a'),
      _PvNamedArg(key: final k, value: final v) => AmeTxt(text: '$k=$v'),
    };
  }

  // ── Component Call Dispatch ─────────────────────────────────────────

  AmeNode _parseComponentCall(String name, String argsStr) {
    final args = _splitArgs(argsStr);
    final positional = <_ParsedValue>[];
    final named = <String, _ParsedValue>{};

    for (final argStr in args) {
      final parsed = _parseArgValue(argStr);
      if (parsed is _PvNamedArg) {
        named[parsed.key] = parsed.value;
      } else {
        positional.add(parsed);
      }
    }

    return switch (name) {
      'col' => _buildCol(positional, named),
      'row' => _buildRow(positional, named),
      'txt' => _buildTxt(positional, named),
      'img' => _buildImg(positional, named),
      'icon' => _buildIcon(positional, named),
      'divider' => const AmeDivider(),
      'spacer' => _buildSpacer(positional, named),
      'card' => _buildCard(positional, named),
      'badge' => _buildBadge(positional, named),
      'progress' => _buildProgress(positional, named),
      'btn' => _buildBtn(positional, named),
      'input' => _buildInput(positional, named),
      'toggle' => _buildToggle(positional, named),
      'list' => _buildList(positional, named),
      'table' => _buildTable(positional, named),
      'each' => _buildEach(positional, named),
      'chart' => _buildChart(positional, named),
      'code' => _buildCode(positional, named),
      'accordion' => _buildAccordion(positional, named),
      'carousel' => _buildCarousel(positional, named),
      'callout' => _buildCallout(positional, named),
      'timeline' => _buildTimeline(positional, named),
      'timeline_item' => _buildTimelineItem(positional, named),
      _ => () {
          _warnings.add("Unknown component '$name'");
          return AmeTxt(text: '\u26A0 Unknown: $name', style: TxtStyle.caption);
        }(),
    };
  }

  // ── Builder Functions for Each Primitive ────────────────────────────

  AmeCol _buildCol(List<_ParsedValue> pos, Map<String, _ParsedValue> named) {
    final children = _resolveChildrenArg(pos.elementAtOrNull(0));
    final align = _resolveAlignArg(pos.elementAtOrNull(1)) ?? Align.start;
    return AmeCol(children: children, align: align);
  }

  AmeRow _buildRow(List<_ParsedValue> pos, Map<String, _ParsedValue> named) {
    final children = _resolveChildrenArg(pos.elementAtOrNull(0));
    var align = Align.start;
    var gap = 8;

    final secondArg = pos.elementAtOrNull(1);
    if (secondArg != null) {
      if (secondArg is _PvNum) {
        gap = secondArg.asInt;
      } else if (secondArg is _PvIdent) {
        final parsed = AmeKeywords.parseAlign(secondArg.name);
        if (parsed != null) {
          align = parsed;
        } else {
          _warnings
              .add("Unknown align value '${secondArg.name}', using default");
        }
      }
    }

    final thirdArg = pos.elementAtOrNull(2);
    if (thirdArg is _PvNum) {
      gap = thirdArg.asInt;
    } else if (thirdArg is _PvIdent) {
      final parsed = AmeKeywords.parseAlign(thirdArg.name);
      if (parsed != null) align = parsed;
    }

    return AmeRow(children: children, align: align, gap: gap);
  }

  AmeTxt _buildTxt(List<_ParsedValue> pos, Map<String, _ParsedValue> named) {
    final text = _resolveStringArg(pos.elementAtOrNull(0));
    final style = _resolveTxtStyleArg(pos.elementAtOrNull(1)) ?? TxtStyle.body;
    final maxLines =
        named['max_lines'] != null ? _resolveIntArg(named['max_lines']!) : null;
    final color = named['color'] != null
        ? _resolveSemanticColorArg(named['color']!)
        : null;
    return AmeTxt(text: text, style: style, maxLines: maxLines, color: color);
  }

  AmeImg _buildImg(List<_ParsedValue> pos, Map<String, _ParsedValue> named) {
    final url = _resolveStringArg(pos.elementAtOrNull(0));
    final height =
        pos.elementAtOrNull(1) != null
            ? _resolveIntArg(pos.elementAtOrNull(1)!)
            : null;
    return AmeImg(url: url, height: height);
  }

  AmeIcon _buildIcon(List<_ParsedValue> pos, Map<String, _ParsedValue> named) {
    final iconName = _resolveStringArg(pos.elementAtOrNull(0));
    final size =
        pos.elementAtOrNull(1) != null
            ? _resolveIntArg(pos.elementAtOrNull(1)!)
            : null;
    return AmeIcon(name: iconName, size: size ?? 20);
  }

  AmeSpacer _buildSpacer(
      List<_ParsedValue> pos, Map<String, _ParsedValue> named) {
    final height =
        pos.elementAtOrNull(0) != null
            ? _resolveIntArg(pos.elementAtOrNull(0)!)
            : null;
    return AmeSpacer(height: height ?? 8);
  }

  AmeCard _buildCard(List<_ParsedValue> pos, Map<String, _ParsedValue> named) {
    final children = _resolveChildrenArg(pos.elementAtOrNull(0));
    final elevation =
        pos.elementAtOrNull(1) != null
            ? _resolveIntArg(pos.elementAtOrNull(1)!)
            : null;
    return AmeCard(children: children, elevation: elevation ?? 1);
  }

  AmeBadge _buildBadge(
      List<_ParsedValue> pos, Map<String, _ParsedValue> named) {
    final label = _resolveStringArg(pos.elementAtOrNull(0));
    final variant =
        pos.elementAtOrNull(1) != null
            ? _resolveBadgeVariantArg(pos.elementAtOrNull(1)!)
            : null;
    final color = named['color'] != null
        ? _resolveSemanticColorArg(named['color']!)
        : null;
    return AmeBadge(
        label: label,
        variant: variant ?? BadgeVariant.defaultVariant,
        color: color);
  }

  AmeProgress _buildProgress(
      List<_ParsedValue> pos, Map<String, _ParsedValue> named) {
    final value =
        pos.elementAtOrNull(0) != null
            ? _resolveDoubleArg(pos.elementAtOrNull(0)!)
            : null;
    final label = pos.elementAtOrNull(1) != null
        ? _resolveStringArgNullable(pos.elementAtOrNull(1)!)
        : null;
    final clamped = (value ?? 0.0).clamp(0.0, 1.0);
    return AmeProgress(value: clamped, label: label);
  }

  AmeBtn _buildBtn(List<_ParsedValue> pos, Map<String, _ParsedValue> named) {
    final label = _resolveStringArg(pos.elementAtOrNull(0));
    final action = _resolveActionArg(pos.elementAtOrNull(1)) ??
        const AmeNavigate(route: '_error_no_action');
    final style =
        pos.elementAtOrNull(2) != null
            ? _resolveBtnStyleArg(pos.elementAtOrNull(2)!)
            : null;
    final icon = named['icon'] != null
        ? _resolveStringArgNullable(named['icon']!)
        : null;
    return AmeBtn(
        label: label, action: action, style: style ?? BtnStyle.primary,
        icon: icon);
  }

  AmeInput _buildInput(
      List<_ParsedValue> pos, Map<String, _ParsedValue> named) {
    final id = _resolveStringArg(pos.elementAtOrNull(0));
    final label = _resolveStringArg(pos.elementAtOrNull(1));
    final type =
        pos.elementAtOrNull(2) != null
            ? _resolveInputTypeArg(pos.elementAtOrNull(2)!)
            : null;
    final options = named['options'] != null
        ? _resolveStringListArg(named['options']!)
        : (pos.elementAtOrNull(3) != null
            ? _resolveStringListArg(pos.elementAtOrNull(3)!)
            : null);
    return AmeInput(
        id: id, label: label, type: type ?? InputType.text, options: options);
  }

  AmeToggle _buildToggle(
      List<_ParsedValue> pos, Map<String, _ParsedValue> named) {
    final id = _resolveStringArg(pos.elementAtOrNull(0));
    final label = _resolveStringArg(pos.elementAtOrNull(1));
    final defaultVal =
        pos.elementAtOrNull(2) != null
            ? _resolveBoolArg(pos.elementAtOrNull(2)!)
            : false;
    return AmeToggle(id: id, label: label, defaultValue: defaultVal);
  }

  AmeDataList _buildList(
      List<_ParsedValue> pos, Map<String, _ParsedValue> named) {
    final children = _resolveChildrenArg(pos.elementAtOrNull(0));
    final dividers =
        pos.elementAtOrNull(1) != null
            ? _resolveBoolArg(pos.elementAtOrNull(1)!)
            : true;
    return AmeDataList(children: children, dividers: dividers);
  }

  AmeTable _buildTable(
      List<_ParsedValue> pos, Map<String, _ParsedValue> named) {
    final headers =
        _resolveStringListArg(pos.elementAtOrNull(0)) ?? const [];
    final rows = _resolveNestedStringListArg(pos.elementAtOrNull(1));
    return AmeTable(headers: headers, rows: rows);
  }

  AmeEach _buildEach(List<_ParsedValue> pos, Map<String, _ParsedValue> named) {
    final arg0 = pos.elementAtOrNull(0);
    final String dataPath;
    if (arg0 is _PvDataRef) {
      dataPath = arg0.path;
    } else if (arg0 is _PvStr) {
      dataPath = arg0.value.replaceFirst('\$', '');
    } else if (arg0 is _PvIdent) {
      dataPath = arg0.name;
    } else {
      dataPath = '';
    }

    final arg1 = pos.elementAtOrNull(1);
    final String templateId;
    if (arg1 is _PvIdent) {
      templateId = arg1.name;
    } else if (arg1 is _PvStr) {
      templateId = arg1.value;
    } else {
      templateId = '';
    }

    return AmeEach(dataPath: dataPath, templateId: templateId);
  }

  AmeChart _buildChart(
      List<_ParsedValue> pos, Map<String, _ParsedValue> named) {
    final type =
        pos.elementAtOrNull(0) != null
            ? _resolveChartTypeArg(pos.elementAtOrNull(0)!)
            : null;

    List<double>? values;
    String? valuesPath;
    final valuesArg = named['values'] ?? pos.elementAtOrNull(1);
    if (valuesArg is _PvDataRef) {
      valuesPath = valuesArg.path;
    } else if (valuesArg is _PvArr) {
      values = _resolveDoubleListArg(valuesArg);
    }

    List<String>? labels;
    String? labelsPath;
    final labelsArg = named['labels'];
    if (labelsArg is _PvDataRef) {
      labelsPath = labelsArg.path;
    } else if (labelsArg is _PvArr) {
      labels = _resolveStringListArg(labelsArg);
    }

    List<List<double>>? series;
    String? seriesPath;
    List<String>? seriesPaths;
    final seriesArg = named['series'];
    if (seriesArg is _PvDataRef) {
      seriesPath = seriesArg.path;
    } else if (seriesArg is _PvArr) {
      // Bug 31 fix (Flutter analog of v1.2 Bug 7): if every item in the
      // array parses as a DataRef ($path), treat as array-of-paths and
      // store in `seriesPaths` for all-or-nothing resolution. Otherwise
      // fall through to the existing literal nested-numeric-array
      // handling. Mirrors Kotlin `AmeParser.kt::buildChart` v1.2.
      final parsedItems =
          seriesArg.items.map((item) => _parseArgValue(item.trim())).toList();
      final allDataRefs =
          parsedItems.isNotEmpty && parsedItems.every((p) => p is _PvDataRef);
      if (allDataRefs) {
        seriesPaths = parsedItems.cast<_PvDataRef>().map((p) => p.path).toList();
      } else {
        series = _resolveNestedDoubleListArg(seriesArg);
      }
    }

    final height =
        named['height'] != null ? _resolveIntArg(named['height']!) : null;
    final color = named['color'] != null
        ? _resolveSemanticColorArg(named['color']!)
        : null;

    return AmeChart(
      type: type ?? ChartType.bar,
      values: values,
      labels: labels,
      series: series,
      height: height ?? 200,
      color: color,
      valuesPath: valuesPath,
      labelsPath: labelsPath,
      seriesPath: seriesPath,
      seriesPaths: seriesPaths,
    );
  }

  AmeCode _buildCode(List<_ParsedValue> pos, Map<String, _ParsedValue> named) {
    final language = _resolveStringArg(pos.elementAtOrNull(0));
    final content = _resolveStringArg(pos.elementAtOrNull(1));
    final title = pos.elementAtOrNull(2) != null
        ? _resolveStringArgNullable(pos.elementAtOrNull(2)!)
        : null;
    return AmeCode(language: language, content: content, title: title);
  }

  AmeAccordion _buildAccordion(
      List<_ParsedValue> pos, Map<String, _ParsedValue> named) {
    final title = _resolveStringArg(pos.elementAtOrNull(0));
    final children = _resolveChildrenArg(pos.elementAtOrNull(1));
    final expanded =
        pos.elementAtOrNull(2) != null
            ? _resolveBoolArg(pos.elementAtOrNull(2)!)
            : false;
    return AmeAccordion(title: title, children: children, expanded: expanded);
  }

  AmeCarousel _buildCarousel(
      List<_ParsedValue> pos, Map<String, _ParsedValue> named) {
    final children = _resolveChildrenArg(pos.elementAtOrNull(0));
    final peek =
        named['peek'] != null ? _resolveIntArg(named['peek']!) : null;
    return AmeCarousel(children: children, peek: peek ?? 24);
  }

  AmeCallout _buildCallout(
      List<_ParsedValue> pos, Map<String, _ParsedValue> named) {
    final type =
        pos.elementAtOrNull(0) != null
            ? _resolveCalloutTypeArg(pos.elementAtOrNull(0)!)
            : null;
    final content = _resolveStringArg(pos.elementAtOrNull(1));
    final title = pos.elementAtOrNull(2) != null
        ? _resolveStringArgNullable(pos.elementAtOrNull(2)!)
        : null;
    // Bug 30 fix: read optional `color=` named arg and store on the AST so
    // the spec-promised `callout(... color=)` round-trips through parse +
    // serialize. Mirrors Kotlin `AmeParser.kt::buildCallout` v1.2.
    final color = named['color'] != null
        ? _resolveSemanticColorArg(named['color']!)
        : null;
    return AmeCallout(
      type: type ?? CalloutType.info,
      content: content,
      title: title,
      color: color,
    );
  }

  AmeTimeline _buildTimeline(
      List<_ParsedValue> pos, Map<String, _ParsedValue> named) {
    final children = _resolveChildrenArg(pos.elementAtOrNull(0));
    return AmeTimeline(children: children);
  }

  AmeTimelineItem _buildTimelineItem(
      List<_ParsedValue> pos, Map<String, _ParsedValue> named) {
    final title = _resolveStringArg(pos.elementAtOrNull(0));
    final subtitle = pos.elementAtOrNull(1) != null
        ? _resolveStringArgNullable(pos.elementAtOrNull(1)!)
        : null;
    final status =
        pos.elementAtOrNull(2) != null
            ? _resolveTimelineStatusArg(pos.elementAtOrNull(2)!)
            : null;
    return AmeTimelineItem(
        title: title,
        subtitle: subtitle,
        status: status ?? TimelineStatus.pending);
  }

  // ── Action Call Dispatch ───────────────────────────────────────────

  AmeAction _parseActionCall(String name, String argsStr) {
    final args = _splitArgs(argsStr);
    final positional = <_ParsedValue>[];
    final named = <String, _ParsedValue>{};

    for (final argStr in args) {
      final parsed = _parseArgValue(argStr);
      if (parsed is _PvNamedArg) {
        named[parsed.key] = parsed.value;
      } else {
        positional.add(parsed);
      }
    }

    return switch (name) {
      'tool' => _buildToolAction(positional, named),
      'uri' => _buildUriAction(positional),
      'nav' => _buildNavAction(positional),
      'copy' => _buildCopyAction(positional),
      'submit' => _buildSubmitAction(positional, named),
      _ => () {
          _warnings.add("Unknown action type '$name'");
          return const AmeNavigate(route: '_error_unknown_action');
        }(),
    };
  }

  AmeCallTool _buildToolAction(
      List<_ParsedValue> pos, Map<String, _ParsedValue> named) {
    final toolName = _resolveIdentOrStringArg(pos.elementAtOrNull(0));
    final argsMap = <String, String>{};
    for (final entry in named.entries) {
      argsMap[entry.key] = _resolveStringArg(entry.value);
    }
    return AmeCallTool(name: toolName, args: argsMap);
  }

  AmeOpenUri _buildUriAction(List<_ParsedValue> pos) {
    final uri = _resolveStringArg(pos.elementAtOrNull(0));
    return AmeOpenUri(uri: uri);
  }

  AmeNavigate _buildNavAction(List<_ParsedValue> pos) {
    final route = _resolveStringArg(pos.elementAtOrNull(0));
    return AmeNavigate(route: route);
  }

  AmeCopyText _buildCopyAction(List<_ParsedValue> pos) {
    final text = _resolveStringArg(pos.elementAtOrNull(0));
    return AmeCopyText(text: text);
  }

  AmeSubmit _buildSubmitAction(
      List<_ParsedValue> pos, Map<String, _ParsedValue> named) {
    final toolName = _resolveIdentOrStringArg(pos.elementAtOrNull(0));
    final staticArgs = <String, String>{};
    for (final entry in named.entries) {
      staticArgs[entry.key] = _resolveStringArg(entry.value);
    }
    return AmeSubmit(toolName: toolName, staticArgs: staticArgs);
  }

  // ── Argument Resolution Helpers ────────────────────────────────────

  List<AmeNode> _resolveChildrenArg(_ParsedValue? arg) {
    if (arg == null) return const [];
    if (arg is _PvArr) {
      return arg.items.map(_expressionToNode).toList();
    }
    if (arg is _PvNodeValue) {
      final node = arg.node;
      if (node is AmeCol) return node.children;
      return [node];
    }
    return const [];
  }

  String _resolveStringArg(_ParsedValue? arg) {
    if (arg == null) return '';
    return switch (arg) {
      _PvStr(value: final v) => v,
      _PvIdent(name: final n) => n,
      _PvDataRef(path: final p) => '\$$p',
      _PvNum(intVal: final i, floatVal: final f) =>
        i?.toString() ?? f?.toString() ?? '0',
      _PvBool(value: final v) => v.toString(),
      _ => arg.toString(),
    };
  }

  String? _resolveStringArgNullable(_ParsedValue? arg) {
    if (arg == null) return null;
    return _resolveStringArg(arg);
  }

  String _resolveIdentOrStringArg(_ParsedValue? arg) {
    if (arg == null) return '';
    return switch (arg) {
      _PvIdent(name: final n) => n,
      _PvStr(value: final v) => v,
      _PvDataRef(path: final p) => '\$$p',
      _ => _resolveStringArg(arg),
    };
  }

  int? _resolveIntArg(_ParsedValue arg) {
    return switch (arg) {
      _PvNum(intVal: final i, floatVal: final f) => i ?? f?.toInt(),
      _PvStr(value: final v) => int.tryParse(v),
      _PvIdent(name: final n) => int.tryParse(n),
      _ => null,
    };
  }

  double? _resolveDoubleArg(_ParsedValue arg) {
    return switch (arg) {
      _PvNum(intVal: final i, floatVal: final f) =>
        f ?? i?.toDouble(),
      _PvStr(value: final v) => double.tryParse(v),
      _PvIdent(name: final n) => double.tryParse(n),
      _ => null,
    };
  }

  bool _resolveBoolArg(_ParsedValue arg) {
    return switch (arg) {
      _PvBool(value: final v) => v,
      _PvIdent(name: final n) => n.toLowerCase() == 'true',
      _PvStr(value: final v) => v.toLowerCase() == 'true',
      _ => false,
    };
  }

  Align? _resolveAlignArg(_ParsedValue? arg) {
    if (arg == null) return null;
    return switch (arg) {
      _PvIdent(name: final n) => AmeKeywords.parseAlign(n),
      _PvStr(value: final v) => AmeKeywords.parseAlign(v),
      _ => null,
    };
  }

  TxtStyle? _resolveTxtStyleArg(_ParsedValue? arg) {
    if (arg == null) return null;
    return switch (arg) {
      _PvIdent(name: final n) => AmeKeywords.parseTxtStyle(n),
      _PvStr(value: final v) => AmeKeywords.parseTxtStyle(v),
      _ => () {
          _warnings.add('Unknown txt style: $arg, using default');
          return null;
        }(),
    };
  }

  BtnStyle? _resolveBtnStyleArg(_ParsedValue? arg) {
    if (arg == null) return null;
    return switch (arg) {
      _PvIdent(name: final n) => AmeKeywords.parseBtnStyle(n),
      _PvStr(value: final v) => AmeKeywords.parseBtnStyle(v),
      _ => () {
          _warnings.add('Unknown btn style: $arg, using default');
          return null;
        }(),
    };
  }

  BadgeVariant? _resolveBadgeVariantArg(_ParsedValue? arg) {
    if (arg == null) return null;
    return switch (arg) {
      _PvIdent(name: final n) => AmeKeywords.parseBadgeVariant(n),
      _PvStr(value: final v) => AmeKeywords.parseBadgeVariant(v),
      _ => () {
          _warnings.add('Unknown badge variant: $arg, using default');
          return null;
        }(),
    };
  }

  InputType? _resolveInputTypeArg(_ParsedValue? arg) {
    if (arg == null) return null;
    return switch (arg) {
      _PvIdent(name: final n) => AmeKeywords.parseInputType(n),
      _PvStr(value: final v) => AmeKeywords.parseInputType(v),
      _ => () {
          _warnings.add('Unknown input type: $arg, using default');
          return null;
        }(),
    };
  }

  ChartType? _resolveChartTypeArg(_ParsedValue? arg) {
    if (arg == null) return null;
    return switch (arg) {
      _PvIdent(name: final n) => AmeKeywords.parseChartType(n),
      _PvStr(value: final v) => AmeKeywords.parseChartType(v),
      _ => null,
    };
  }

  CalloutType? _resolveCalloutTypeArg(_ParsedValue? arg) {
    if (arg == null) return null;
    return switch (arg) {
      _PvIdent(name: final n) => AmeKeywords.parseCalloutType(n),
      _PvStr(value: final v) => AmeKeywords.parseCalloutType(v),
      _ => null,
    };
  }

  TimelineStatus? _resolveTimelineStatusArg(_ParsedValue? arg) {
    if (arg == null) return null;
    return switch (arg) {
      _PvIdent(name: final n) => AmeKeywords.parseTimelineStatus(n),
      _PvStr(value: final v) => AmeKeywords.parseTimelineStatus(v),
      _ => null,
    };
  }

  SemanticColor? _resolveSemanticColorArg(_ParsedValue? arg) {
    if (arg == null) return null;
    return switch (arg) {
      _PvIdent(name: final n) => AmeKeywords.parseSemanticColor(n),
      _PvStr(value: final v) => AmeKeywords.parseSemanticColor(v),
      _ => null,
    };
  }

  AmeAction? _resolveActionArg(_ParsedValue? arg) {
    if (arg == null) return null;
    if (arg is _PvActionValue) return arg.action;
    if (arg is _PvIdent) {
      _warnings.add("Expected action expression, got identifier '${arg.name}'");
      return null;
    }
    _warnings.add('Expected action expression, got: $arg');
    return null;
  }

  List<String>? _resolveStringListArg(_ParsedValue? arg) {
    if (arg == null) return null;
    if (arg is _PvArr) {
      return arg.items.map((item) => _resolveStringArg(_parseArgValue(item.trim()))).toList();
    }
    return null;
  }

  List<List<String>> _resolveNestedStringListArg(_ParsedValue? arg) {
    if (arg == null) return const [];
    if (arg is _PvArr) {
      return arg.items.map((rowStr) {
        final rowParsed = _parseArgValue(rowStr.trim());
        if (rowParsed is _PvArr) {
          return rowParsed.items
              .map((cellStr) =>
                  _resolveStringArg(_parseArgValue(cellStr.trim())))
              .toList();
        }
        return [_resolveStringArg(rowParsed)];
      }).toList();
    }
    return const [];
  }

  List<double>? _resolveDoubleListArg(_ParsedValue? arg) {
    if (arg == null) return null;
    if (arg is _PvArr) {
      final result = <double>[];
      for (final item in arg.items) {
        final d = double.tryParse(item.trim());
        if (d != null) result.add(d);
      }
      return result;
    }
    return null;
  }

  List<List<double>>? _resolveNestedDoubleListArg(_ParsedValue? arg) {
    if (arg == null) return null;
    if (arg is _PvArr) {
      final result = <List<double>>[];
      for (final rowStr in arg.items) {
        final rowParsed = _parseArgValue(rowStr.trim());
        if (rowParsed is _PvArr) {
          final row = <double>[];
          for (final cellStr in rowParsed.items) {
            final d = double.tryParse(cellStr.trim());
            if (d != null) row.add(d);
          }
          result.add(row);
        }
      }
      return result;
    }
    return null;
  }

  // ── String Literal Parser ──────────────────────────────────────────

  String _parseStringLiteral(String input) {
    if (!input.startsWith('"')) return input;

    final sb = StringBuffer();
    var i = 1;
    var escaped = false;

    while (i < input.length) {
      final c = input[i];
      if (escaped) {
        switch (c) {
          case '"':
            sb.write('"');
          case '\\':
            sb.write('\\');
          case 'n':
            sb.write('\n');
          case 't':
            sb.write('\t');
          default:
            sb.write('\\');
            sb.write(c);
        }
        escaped = false;
      } else {
        switch (c) {
          case '\\':
            escaped = true;
          case '"':
            return sb.toString();
          default:
            sb.write(c);
        }
      }
      i++;
    }

    _warnings.add('Unclosed string literal, implicitly closing at end of line');
    return sb.toString();
  }

  // ── Number Parser ──────────────────────────────────────────────────

  _ParsedValue _parseNumber(String input) {
    final trimmed = input.trim();
    if (trimmed.contains('.')) {
      final f = double.tryParse(trimmed);
      if (f != null) return _PvNum(null, f);
      _warnings.add("Invalid number '$trimmed', treating as string");
      return _PvStr(trimmed);
    }
    final i = int.tryParse(trimmed);
    if (i != null) return _PvNum(i, null);
    _warnings.add("Invalid number '$trimmed', treating as string");
    return _PvStr(trimmed);
  }

  // ── Array Parser ───────────────────────────────────────────────────

  /// Finds the matching `]` for an array literal while respecting string
  /// literals and escapes, so a `]` inside a `"..."` value does not
  /// prematurely close the array (Bug 26b, Flutter analog of v1.2 Bug 3).
  ///
  /// Mirrors the Kotlin canonical implementation in
  /// `ame-core/.../AmeParser.kt::parseArray` (v1.2 fix).
  List<String> _parseArray(String input) {
    final trimmed = input.trim();
    if (!trimmed.startsWith('[')) return const [];

    var depth = 0;
    var endIdx = -1;
    var inString = false;
    var escaped = false;
    for (var i = 0; i < trimmed.length; i++) {
      final c = trimmed[i];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (inString) {
        if (c == r'\') {
          escaped = true;
        } else if (c == '"') {
          inString = false;
        }
        continue;
      }
      switch (c) {
        case '"':
          inString = true;
        case '[':
          depth++;
        case ']':
          depth--;
          if (depth == 0) {
            endIdx = i;
            break;
          }
      }
      if (endIdx != -1) break;
    }

    final String content;
    if (endIdx > 1) {
      content = trimmed.substring(1, endIdx).trim();
    } else {
      _warnings.add('Unclosed bracket in array, implicitly closing');
      content = trimmed.substring(1).replaceAll(']', '').trim();
    }

    if (content.isEmpty) return const [];
    return _splitTopLevel(content, ',');
  }

  // ── Argument Splitter State Machine ────────────────────────────────

  List<String> _splitArgs(String argsStr) {
    final trimmed = argsStr.trim();
    if (trimmed.isEmpty) return const [];
    return _splitTopLevel(trimmed, ',');
  }

  List<String> _splitTopLevel(String input, String delimiter) {
    final result = <String>[];
    final current = StringBuffer();
    var parenDepth = 0;
    var bracketDepth = 0;
    var inString = false;
    var escaped = false;

    for (var i = 0; i < input.length; i++) {
      final c = input[i];

      if (escaped) {
        current.write(c);
        escaped = false;
        continue;
      }

      if (inString) {
        current.write(c);
        if (c == '\\') {
          escaped = true;
        } else if (c == '"') {
          inString = false;
        }
        continue;
      }

      switch (c) {
        case '"':
          inString = true;
          current.write(c);
        case '(':
          parenDepth++;
          current.write(c);
        case ')':
          parenDepth--;
          current.write(c);
        case '[':
          bracketDepth++;
          current.write(c);
        case ']':
          bracketDepth--;
          current.write(c);
        default:
          if (c == delimiter[0] && parenDepth == 0 && bracketDepth == 0) {
            result.add(current.toString().trim());
            current.clear();
          } else {
            current.write(c);
          }
      }
    }

    final remaining = current.toString().trim();
    if (remaining.isNotEmpty) {
      result.add(remaining);
    }

    return result;
  }

  // ── Named Argument Detection ───────────────────────────────────────

  int _findNamedArgEquals(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty || !_isLetter(trimmed.codeUnitAt(0))) return -1;

    var i = 0;
    while (i < trimmed.length &&
        (_isLetterOrDigit(trimmed.codeUnitAt(i)) ||
            trimmed.codeUnitAt(i) == 0x5F)) {
      i++;
    }

    while (i < trimmed.length && trimmed[i] == ' ') {
      i++;
    }

    if (i < trimmed.length && trimmed[i] == '=') {
      final key = trimmed.substring(0, i).trim();
      if (key.isNotEmpty &&
          key.codeUnits.every(
              (c) => _isLetterOrDigit(c) || c == 0x5F)) {
        return i;
      }
    }

    return -1;
  }

  // ── Parenthesis Helpers ────────────────────────────────────────────

  int _findTopLevelParen(String input) {
    var inString = false;
    var escaped = false;

    for (var i = 0; i < input.length; i++) {
      final c = input[i];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (inString) {
        if (c == '\\') {
          escaped = true;
        } else if (c == '"') {
          inString = false;
        }
        continue;
      }
      if (c == '"') {
        inString = true;
      } else if (c == '(') {
        return i;
      }
    }
    return -1;
  }

  /// Finds the matching `)` for a parenthesized region while respecting
  /// string literals and escapes, so a `)` inside a `"..."` value does
  /// not prematurely close the region (Bug 26a, Flutter analog of v1.2
  /// Bug 3). The `escaped` state correctly keeps `inString` across `\"`
  /// so an escaped quote followed by `)` stays inside the string.
  ///
  /// Mirrors the Kotlin canonical implementation in
  /// `ame-core/.../AmeParser.kt::extractParenContent` (v1.2 fix).
  String _extractParenContent(String input, int openIndex) {
    var depth = 0;
    var closeIndex = -1;
    var inString = false;
    var escaped = false;

    for (var i = openIndex; i < input.length; i++) {
      final c = input[i];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (inString) {
        if (c == r'\') {
          escaped = true;
        } else if (c == '"') {
          inString = false;
        }
        continue;
      }
      switch (c) {
        case '"':
          inString = true;
        case '(':
          depth++;
        case ')':
          depth--;
          if (depth == 0) {
            closeIndex = i;
            break;
          }
      }
      if (closeIndex != -1) break;
    }

    if (closeIndex > openIndex + 1) {
      return input.substring(openIndex + 1, closeIndex);
    } else if (closeIndex == -1) {
      _warnings.add(
          'Unclosed parenthesis, implicitly closing at end of expression');
      return input.substring(openIndex + 1).replaceAll(')', '');
    }
    return '';
  }

  // ── Data Section Parsing ───────────────────────────────────────────

  void _parseDataSection(String jsonText) {
    final trimmed = jsonText.trim();
    if (trimmed.isEmpty) return;

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        _dataModel = decoded;
      } else {
        _errors.add(
            'Data model must be a JSON object, got: ${decoded.runtimeType}');
      }
    } catch (e) {
      _errors.add('Invalid JSON in data section: $e');
    }
  }

  // ── Tree Resolution (Forward Refs, $path, each() expansion) ────────

  /// Resolves Ref nodes against the registry and `$path` data references
  /// against `scope`. The [visited] set carries the chain of ref ids that
  /// are currently being dereferenced down a single branch of the tree;
  /// when a Ref's id appears in [visited] we treat it as a cycle and leave
  /// the node unresolved (Bug 27, Flutter analog of v1.2 Bug 11). The set
  /// is rebuilt per call (`{...visited, id}`) so sibling branches and
  /// diamond-ref patterns (`a -> c, b -> c`) resolve independently rather
  /// than poisoning each other.
  ///
  /// Mirrors the Kotlin canonical implementation in
  /// `ame-core/.../AmeParser.kt::resolveTree` (v1.2 fix), including the
  /// per-WP#3 immutable visited propagation for diamond correctness.
  AmeNode _resolveTree(
    AmeNode node, [
    Map<String, dynamic>? scope,
    Set<String> visited = const {},
  ]) {
    scope ??= _dataModel;
    return switch (node) {
      AmeCol(children: final ch, align: final a) =>
        AmeCol(children: _resolveChildren(ch, scope, visited), align: a),
      AmeRow(children: final ch, align: final a, gap: final g) =>
        AmeRow(
            children: _resolveChildren(ch, scope, visited),
            align: a,
            gap: g),
      AmeCard(children: final ch, elevation: final e) =>
        AmeCard(
            children: _resolveChildren(ch, scope, visited), elevation: e),
      AmeDataList(children: final ch, dividers: final d) =>
        AmeDataList(
            children: _resolveChildren(ch, scope, visited), dividers: d),
      AmeRef(id: final id) => () {
          if (visited.contains(id)) {
            _warnings.add("Ref cycle detected at '$id'; leaving unresolved");
            return node;
          }
          final resolved = _registry[id];
          if (resolved == null) return node;
          return _resolveTree(resolved, scope, {...visited, id});
        }(),
      AmeEach() => scope == null
          ? node
          : () {
              final expanded = _expandEach(node, scope, visited);
              if (expanded.length == 1) return expanded[0];
              return AmeCol(children: expanded);
            }(),
      AmeTxt(
        text: final t,
        style: final s,
        maxLines: final ml,
        color: final c
      ) =>
        scope != null
            ? AmeTxt(
                text: _resolvePathInScope(t, scope),
                style: s,
                maxLines: ml,
                color: c)
            : node,
      AmeImg(url: final u, height: final h) =>
        scope != null ? AmeImg(url: _resolvePathInScope(u, scope), height: h) : node,
      AmeBadge(label: final l, variant: final v, color: final c) =>
        scope != null
            ? AmeBadge(
                label: _resolvePathInScope(l, scope), variant: v, color: c)
            : node,
      AmeProgress(value: final v, label: final l) =>
        scope != null && l != null
            ? AmeProgress(value: v, label: _resolvePathInScope(l, scope))
            : node,
      AmeBtn(label: final l, action: final a, style: final s, icon: final i) =>
        scope != null
            ? AmeBtn(
                label: _resolvePathInScope(l, scope),
                action: a,
                style: s,
                icon: i)
            : node,
      AmeIcon(name: final n, size: final s) =>
        scope != null ? AmeIcon(name: _resolvePathInScope(n, scope), size: s) : node,
      AmeAccordion(title: final t, children: final ch, expanded: final e) =>
        AmeAccordion(
          title: scope != null ? _resolvePathInScope(t, scope) : t,
          children: _resolveChildren(ch, scope, visited),
          expanded: e,
        ),
      AmeCarousel(children: final ch, peek: final p) =>
        AmeCarousel(children: _resolveChildren(ch, scope, visited), peek: p),
      AmeTimeline(children: final ch) =>
        AmeTimeline(children: _resolveChildren(ch, scope, visited)),
      AmeCallout(
        type: final tp,
        content: final c,
        title: final t,
        color: final col,
      ) =>
        scope != null
            ? AmeCallout(
                type: tp,
                content: _resolvePathInScope(c, scope),
                title: t != null ? _resolvePathInScope(t, scope) : null,
                color: col,
              )
            : node,
      AmeCode(language: final l, content: final c, title: final t) =>
        scope != null
            ? AmeCode(
                language: l,
                content: _resolvePathInScope(c, scope),
                title: t != null ? _resolvePathInScope(t, scope) : null,
              )
            : node,
      AmeTimelineItem(title: final t, subtitle: final s, status: final st) =>
        scope != null
            ? AmeTimelineItem(
                title: _resolvePathInScope(t, scope),
                subtitle:
                    s != null ? _resolvePathInScope(s, scope) : null,
                status: st,
              )
            : node,
      AmeChart() => scope != null
          ? node.copyWith(
              values: () =>
                  node.values ??
                  (node.valuesPath != null
                      ? _resolveDoubleArrayInScope(node.valuesPath!, scope!)
                      : null),
              labels: () =>
                  node.labels ??
                  (node.labelsPath != null
                      ? _resolveStringArrayInScope(node.labelsPath!, scope!)
                      : null),
              series: () {
                // Resolution priority: literal series wins (preserved
                // from buildChart), then single-path matrix, then
                // array-of-paths (Bug 31, all-or-nothing per Kotlin
                // canonical). The all-or-nothing guard preserves the
                // empty-state contract — a partial resolution produces
                // misleading multi-series rendering.
                if (node.series != null) return node.series;
                if (node.seriesPath != null) {
                  return _resolveNestedDoubleArrayInScope(
                      node.seriesPath!, scope!);
                }
                final paths = node.seriesPaths;
                if (paths == null) return null;
                final resolvedPerPath = <List<double>>[];
                for (final path in paths) {
                  final arr = _resolveDoubleArrayInScope(path, scope!);
                  if (arr == null) {
                    return null;
                  }
                  resolvedPerPath.add(arr);
                }
                return resolvedPerPath;
              },
              valuesPath: () => null,
              labelsPath: () => null,
              seriesPath: () => null,
              seriesPaths: () => null,
            )
          : node,
      _ => node,
    };
  }

  /// Resolves an inline children list, handling AmeRef cycle detection
  /// at the same depth as `_resolveTree` (Bug 27). The [visited] set is
  /// passed through verbatim because each child starts a new branch.
  List<AmeNode> _resolveChildren(
    List<AmeNode> children,
    Map<String, dynamic>? scope, [
    Set<String> visited = const {},
  ]) {
    return children.map((child) {
      if (child is AmeRef) {
        if (visited.contains(child.id)) {
          _warnings
              .add("Ref cycle detected at '${child.id}'; leaving unresolved");
          return child;
        }
        final resolved = _registry[child.id];
        if (resolved != null) {
          return _resolveTree(resolved, scope, {...visited, child.id});
        }
        return child;
      }
      return _resolveTree(child, scope, visited);
    }).toList();
  }

  /// Expands an AmeEach by resolving its template against each element of
  /// the bound array. The [visited] set is passed through to detect ref
  /// cycles inside the template body (Bug 27).
  List<AmeNode> _expandEach(
    AmeEach node,
    Map<String, dynamic>? parentScope, [
    Set<String> visited = const {},
  ]) {
    final array = _resolveDataArray(node.dataPath, parentScope);
    if (array == null || array.isEmpty) return const [];

    final template = _registry[node.templateId];
    if (template == null) {
      _warnings
          .add("each() template '${node.templateId}' not found in registry");
      return const [];
    }

    final result = <AmeNode>[];
    for (final element in array) {
      if (element is Map<String, dynamic>) {
        result.add(_resolveTree(template, element, visited));
      } else {
        _warnings.add('each() array element is not a JSON object');
      }
    }
    return result;
  }

  List<dynamic>? _resolveDataArray(
      String path, Map<String, dynamic>? scope) {
    final model = scope ?? _dataModel;
    if (model == null) return null;
    final segments = path.replaceFirst('\$', '').split('/');
    dynamic current = model;
    for (final segment in segments) {
      if (current is Map<String, dynamic>) {
        if (!current.containsKey(segment)) {
          _warnings
              .add("each() path segment '$segment' not found in data model");
          return null;
        }
        current = current[segment];
      } else {
        return null;
      }
    }
    if (current is! List) {
      _warnings.add(
          "each() path '$path' resolved to ${current.runtimeType}, expected List");
      return null;
    }
    return current;
  }

  String _resolvePathInScope(String value, Map<String, dynamic> scope) {
    if (!value.startsWith('\$')) return value;
    final segments = value.substring(1).split('/');
    dynamic current = scope;
    for (final segment in segments) {
      if (current is Map<String, dynamic>) {
        if (!current.containsKey(segment)) return '';
        current = current[segment];
      } else {
        return '';
      }
    }
    if (current is String) return current;
    if (current is num) return current.toString();
    if (current is bool) return current.toString();
    return '';
  }

  // ── Chart Array Resolution Helpers ─────────────────────────────────

  List<double>? _resolveDoubleArrayInScope(
      String path, Map<String, dynamic> scope) {
    final segments = path.replaceFirst('\$', '').split('/');
    dynamic current = scope;
    for (final segment in segments) {
      if (current is Map<String, dynamic>) {
        if (!current.containsKey(segment)) return null;
        current = current[segment];
      } else {
        return null;
      }
    }
    if (current is! List) return null;
    return current
        .whereType<num>()
        .map((e) => e.toDouble())
        .toList();
  }

  List<String>? _resolveStringArrayInScope(
      String path, Map<String, dynamic> scope) {
    final segments = path.replaceFirst('\$', '').split('/');
    dynamic current = scope;
    for (final segment in segments) {
      if (current is Map<String, dynamic>) {
        if (!current.containsKey(segment)) return null;
        current = current[segment];
      } else {
        return null;
      }
    }
    if (current is! List) return null;
    return current.map((e) => e.toString()).toList();
  }

  List<List<double>>? _resolveNestedDoubleArrayInScope(
      String path, Map<String, dynamic> scope) {
    final segments = path.replaceFirst('\$', '').split('/');
    dynamic current = scope;
    for (final segment in segments) {
      if (current is Map<String, dynamic>) {
        if (!current.containsKey(segment)) return null;
        current = current[segment];
      } else {
        return null;
      }
    }
    if (current is! List) return null;
    final result = <List<double>>[];
    for (final inner in current) {
      if (inner is List) {
        result.add(inner.whereType<num>().map((e) => e.toDouble()).toList());
      }
    }
    return result;
  }

  // ── Character Helpers ──────────────────────────────────────────────

  static bool _isLetter(int c) =>
      (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A);

  static bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

  static bool _isLetterOrDigit(int c) => _isLetter(c) || _isDigit(c);
}

// ── ParsedValue Sealed Hierarchy (file-private) ──────────────────────

sealed class _ParsedValue {
  const _ParsedValue();
}

final class _PvStr extends _ParsedValue {
  final String value;
  const _PvStr(this.value);
  @override
  String toString() => 'PvStr($value)';
}

final class _PvNum extends _ParsedValue {
  final int? intVal;
  final double? floatVal;
  const _PvNum(this.intVal, this.floatVal);
  int get asInt => intVal ?? floatVal?.toInt() ?? 0;
  double get asDouble => floatVal ?? intVal?.toDouble() ?? 0.0;
  @override
  String toString() => 'PvNum(${intVal ?? floatVal})';
}

final class _PvBool extends _ParsedValue {
  final bool value;
  const _PvBool(this.value);
  @override
  String toString() => 'PvBool($value)';
}

final class _PvArr extends _ParsedValue {
  final List<String> items;
  const _PvArr(this.items);
  @override
  String toString() => 'PvArr($items)';
}

final class _PvDataRef extends _ParsedValue {
  final String path;
  const _PvDataRef(this.path);
  @override
  String toString() => 'PvDataRef($path)';
}

final class _PvIdent extends _ParsedValue {
  final String name;
  const _PvIdent(this.name);
  @override
  String toString() => 'PvIdent($name)';
}

final class _PvNodeValue extends _ParsedValue {
  final AmeNode node;
  const _PvNodeValue(this.node);
  @override
  String toString() => 'PvNodeValue($node)';
}

final class _PvActionValue extends _ParsedValue {
  final AmeAction action;
  const _PvActionValue(this.action);
  @override
  String toString() => 'PvActionValue($action)';
}

final class _PvNamedArg extends _ParsedValue {
  final String key;
  final _ParsedValue value;
  const _PvNamedArg(this.key, this.value);
  @override
  String toString() => 'PvNamedArg($key=$value)';
}

extension _ListElementAtOrNull<T> on List<T> {
  T? elementAtOrNull(int index) =>
      index >= 0 && index < length ? this[index] : null;
}
